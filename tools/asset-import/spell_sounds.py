#!/usr/bin/env python3
"""spell_sounds.py — retail SFX/FX maps for the Godot fight view.

The retail client runs a Lua script per spell cast (data.jar scripts/<id>.lua).
Those scripts fire `Sound.playSound(<id>, stopOnChange)` at script scope
(cast whoosh) and inside `invoke(<ms>, 1, "fn")` callbacks (impact booms).
This extracts, per spell, the timed sound ids — [[t_ms, soundId], ...] —
and copies the referenced oggs out of sounds.jar.

It also handles the anm-frame channel: `pb_1` runScript parts on .anm frames
execute `scripts/anm/<id>.lua`, which are boilerplate locals feeding
`playLocalSound(preset, stop, soundFileId, gain)` / `playLocalRandomSound`
/ `playBark`. Those map into `anm_scripts.json`:
  {scriptId: {"s": [[soundId, gain], ...], "stop": bool}} — multi-entry "s"
  is a uniform-random set (playLocalRandomSound); Godot picks one per play.

And the particle channel: `Particle.addParticleSystem(id, x, y, z)` bursts
plus `Particle.addTweenParticleSystem(id, sx,sy,sz, dx,dy,dz, angle, type,
coef)` ballistic projectiles (avw_0: v0 = sqrt(g*dist/sin 2a), flight ms =
2*v0*sin(a)/g * 1000/coef — the `type` arg is parsed but unused by 2.70).
The scripts are real programs — direction-keyed ids under
`if startMobileDirection == N`, constant tables (APS_*), scheduling through
`invoke(expr, 1, "fn", args...)` incl. `time`/`time+k` (when the preceding
tween lands), and direct `displayEffect()` calls — so extraction is a small
scoped evaluator, not a regex.

spell_fx.json rows, per spell:
  [t_ms, xpsId, anchor]            burst; anchor = caster|target (aimed cell)
  [t_ms, xpsId, "tw", angle, coef] projectile — flies caster -> aimed cell
  ["tw#i+k", xpsId, anchor]        k ms after tween row i lands
xpsId may be {"1":a,"3":b,"5":c,"7":d,"_":def} — picked by caster Direction8.

Usage:
  go run ./server/cmd/dumpspells server/data-dist /tmp/spells_raw.json
  python3 tools/asset-import/spell_sounds.py /tmp/spells_raw.json \
      client/compiled/game/contents/data.jar \
      client/compiled/game/contents/sounds.jar \
      godot/assets/gamedata/spell_sfx.json godot/assets/sounds \
      godot/assets/gamedata/anm_scripts.json godot/assets/gamedata/spell_fx.json
"""

from __future__ import annotations

import json
import re
import sys
import zipfile

PLAY = re.compile(r"Sound\.playSound\(\s*(\d+)")
# weighted variant: playLocalRandomSound(rollOff, stop, id1, w1, id2, w2, ...)
RAND = re.compile(r"Sound\.playLocalRandomSound\(([^)]*)\)")

# ---------------------------------------------------------------------------
# Lua mini-evaluator
# ---------------------------------------------------------------------------

_COMMENT = re.compile(r"--.*$")
_STRING = re.compile(r"'[^']*'|\"[^\"]*\"")
_FUNCDEF = re.compile(r"^\s*function\s+(\w+)\s*\(([^)]*)\)")
_OPENS = re.compile(r"\b(function|then|do|repeat)\b")
_CLOSES = re.compile(r"\b(end|until)\b")
_THEN = re.compile(r"\bthen\b")
_ELSEIF_KW = re.compile(r"\belseif\b")
_ASSIGN = re.compile(
    r"^\s*(?:local\s+)?([\w\s,]+?)\s*=\s*(.+?)\s*;?\s*$")
_INVOKE = re.compile(
    r'invoke\s*\(\s*([^,]+?)\s*,\s*[^,]+?,\s*"(\w+)"\s*(?:,(.*?))?\s*\)')
_CALLFN = re.compile(r"^\s*(\w+)\s*\((.*)\)\s*;?\s*$")
_PARTCALL = re.compile(
    r"Particle\.add(Tween)?ParticleSystem\s*\((.*)\)")
_GETWEEN = re.compile(r"Particle\.getTweenParticleSystemTime\s*\(")
_GETDIR = re.compile(r"Mobile\.getMobileDirection")
_IF = re.compile(r"^\s*if\s+(.+?)\s+then\s*$")
_ELSEIF = re.compile(r"^\s*elseif\s+(.+?)\s+then\s*$")
_ELSE = re.compile(r"^\s*else\s*$")
_END = re.compile(r"^\s*end\s*;?\s*$")
_RETURN = re.compile(r"^\s*return\b")
_DIRCOND = re.compile(r"startMobileDirection\s*==\s*(\d+)")
_INTEGERS = re.compile(r"^-?\d+$")
_NUMBER = re.compile(r"^-?\d+(?:\.\d+)?$")
_VAR = re.compile(r"^\w+$")
_TAG = re.compile(r"^tw#(\d+)([+-]\d+)?$")

UNKNOWN = object()          # unresolvable expression
TWEEN = object()            # variable holding a tween flight duration


def _clean(line: str) -> str:
    return _COMMENT.sub("", line).strip()


def _depth_delta(line: str) -> int:
    s = _STRING.sub('""', line)
    d = len(_OPENS.findall(s)) - len(_CLOSES.findall(s))
    # elseif's 'then' opens no new block
    d -= len(_ELSEIF_KW.findall(s))
    return d


def _split_args(s: str) -> list:
    """Top-level comma split (paren/brace aware)."""
    out, depth, cur = [], 0, []
    for ch in s:
        if ch in "({[":
            depth += 1
        elif ch in ")}]":
            depth -= 1
        if ch == "," and depth == 0:
            out.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
    tail = "".join(cur).strip()
    if tail or out:
        out.append(tail)
    return [a.strip() for a in out if a.strip()]


def _split_funcs(src: str):
    """{name: (params, body)} + top-level lines.

    Depth-aware so a nested `function particles()` registers on its own
    instead of swallowing the enclosing function's tail.
    """
    funcs, top = {}, []
    lines = src.split("\n")
    i = 0
    while i < len(lines):
        m = _FUNCDEF.match(lines[i])
        if not m:
            top.append(lines[i])
            i += 1
            continue
        name, body, d = _take_func(lines, i, m)
        funcs[name] = body
        i = d
    return funcs, top


def _take_func(lines: list, i: int, m):
    """Consume function at lines[i]; nested named funcs register in _NESTED."""
    name = m.group(1)
    params = [p.strip() for p in m.group(2).split(",") if p.strip()]
    body = []
    d = _depth_delta(lines[i])
    i += 1
    while i < len(lines) and d > 0:
        nm = _FUNCDEF.match(lines[i])
        if nm:
            nname, nbody, i = _take_func(lines, i, nm)
            _NESTED[nname] = nbody
            continue
        d += _depth_delta(lines[i])
        body.append(lines[i])
        i += 1
    return name, (params, body), i


_NESTED: dict = {}


def _outer_parens(e: str) -> bool:
    if not e.startswith("("):
        return False
    depth = 0
    for i, ch in enumerate(e):
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return i == len(e) - 1
    return False


def _split_top(e: str, op: str):
    """Split e at the FIRST top-level `op`; returns (left, idx) or None."""
    depth = 0
    for i in range(len(e)):
        ch = e[i]
        if ch in "([":
            depth += 1
        elif ch in ")]":
            depth -= 1
        elif depth == 0 and e.startswith(op, i):
            if op in ("<", ">") and e[i:i + 2] == op + "=":
                continue
            if op in ("<", ">") and i > 0 and e[i - 1] in "<>~":
                continue
            return e[:i], i
    return None


def _split_top_all(e: str, op: str) -> list | None:
    parts, rest = [], e
    while True:
        r = _split_top(rest, op)
        if r is None:
            break
        left, idx = r
        parts.append(left.strip())
        rest = rest[idx + len(op):]
    if not parts:
        return None
    parts.append(rest.strip())
    return parts


def _find_addsub(e: str) -> int | None:
    """Rightmost top-level binary +/- index (keeps left-assoc)."""
    depth = 0
    for i in range(len(e) - 1, -1, -1):
        ch = e[i]
        if ch in ")]":
            depth += 1
        elif ch in "([":
            depth -= 1
        elif depth == 0 and ch in "+-" and i > 0:
            j = i - 1
            while j >= 0 and e[j] == " ":
                j -= 1
            if j < 0 or e[j] in "(,=<>~+-*/%":
                continue            # unary sign
            return i
    return None


def _truthy(v) -> bool:
    return v is not False and v is not None and v is not UNKNOWN


def _eval(e: str, env: dict):
    """Tiny Lua expression eval -> num | bool | list | UNKNOWN | TWEEN |
    ("tw+", k) when a tween-duration var carries an offset."""
    e = e.strip().rstrip(";").strip()
    if not e:
        return UNKNOWN
    while _outer_parens(e):
        e = e[1:-1].strip()
    if _NUMBER.match(e):
        return float(e) if "." in e else int(e)
    if e in ("true", "false"):
        return e == "true"
    if e == "nil":
        return UNKNOWN
    if e.startswith("{") and e.endswith("}"):
        inner = e[1:-1].strip()
        return [_eval(a, env) for a in _split_args(inner)] if inner else []
    for op in (" or ", " and "):
        parts = _split_top_all(e, op)
        if parts:
            vals = [_eval(p, env) for p in parts]
            if op == " or ":
                if any(v is True for v in vals):
                    return True
                return False if all(v is False for v in vals) else UNKNOWN
            if any(v is False for v in vals):
                return False
            return True if all(v is True for v in vals) else UNKNOWN
    if e.startswith("not "):
        v = _eval(e[4:], env)
        return (not _truthy(v)) if v is not UNKNOWN else UNKNOWN
    for op in ("~=", "==", "<=", ">=", "<", ">"):
        r = _split_top(e, op)
        if r:
            a = _eval(r[0], env)
            b = _eval(e[r[1] + len(op):], env)
            if a is UNKNOWN or b is UNKNOWN or \
                    isinstance(a, (list, dict)) or isinstance(b, (list, dict)):
                return UNKNOWN
            return {"~=": a != b, "==": a == b, "<=": a <= b,
                    ">=": a >= b, "<": a < b, ">": a > b}[op]
    idx = _find_addsub(e)
    if idx is not None:
        a = _eval(e[:idx], env)
        b = _eval(e[idx + 1:], env)
        if a is TWEEN or b is TWEEN:
            other = b if a is TWEEN else a
            if isinstance(other, (int, float)):
                return ("tw+", other if e[idx] == "+" else -other)
            return TWEEN
        if isinstance(a, (int, float)) and isinstance(b, (int, float)):
            return a + b if e[idx] == "+" else a - b
        return UNKNOWN
    for op in ("*", "/", "%"):
        r = _split_top(e, op)
        if r:
            a = _eval(r[0], env)
            b = _eval(e[r[1] + 1:], env)
            if isinstance(a, (int, float)) and isinstance(b, (int, float)):
                if op == "*":
                    return a * b
                if b == 0:
                    return UNKNOWN
                return a / b if op == "/" else a % b
            return UNKNOWN
    m = re.match(r"^#(\w+)$", e)
    if m:
        v = env.get(m.group(1))
        return len(v) if isinstance(v, list) else UNKNOWN
    m = re.match(r"^(\w+)\s*\[\s*(.+?)\s*\]$", e)
    if m:
        t = env.get(m.group(1))
        k = _eval(m.group(2), env)
        if isinstance(t, list) and isinstance(k, (int, float)) \
                and 1 <= int(k) <= len(t):
            return t[int(k) - 1]
        return UNKNOWN
    if _VAR.match(e):
        return env.get(e, UNKNOWN)
    if _STRING.fullmatch(e):
        return e[1:-1]
    return UNKNOWN     # calls, method calls, math.random, multi-retvals


# ---------------------------------------------------------------------------
# Script scan — emits fx + sfx rows in one pass
# ---------------------------------------------------------------------------

class _Scan:
    """Scoped walk of one cast script.

    fx : (t, id, anchor) | (t, id, "tw", angle, coef) | (tag, id, anchor)
    sfx: (t, soundId)

    `t` is absolute ms; a `tag` is "tw#<i>[+k]" = k ms after the i-th tween
    row lands (i = ordinal among "tw" rows in this spell's output).
    `id` may become a {"1":..,"3":..,"5":..,"7":..,"_":def} dict when the
    script picks the system by startMobileDirection.
    """

    def __init__(self, src: str):
        global _NESTED
        _NESTED = {}
        self.funcs, self.top = _split_funcs(src)
        self.funcs.update(_NESTED)
        self.fx: list = []
        self.sfx: list = []
        self.tween_rows = 0
        self._ifs: list = []

    # -- id / anchor / delay resolution -----------------------------------
    def _resolve_id(self, e: str, env: dict):
        e = e.strip()
        if _INTEGERS.match(e):
            return int(e)
        return self._id_of(_eval(e, env))

    def _id_of(self, v):
        if isinstance(v, bool):
            return None
        if isinstance(v, (int, float)):
            return int(v)
        if isinstance(v, dict):            # direction-keyed pick
            out = {}
            for k, x in v.get("dirs", {}).items():
                r = self._id_of(x)
                if r is not None:
                    out[str(k)] = r
            d = self._id_of(v.get("def"))
            if d is not None:
                out["_"] = d
            return out or None
        return None

    @staticmethod
    def _anchor(e: str) -> str:
        e = e.strip()
        if re.match(r"(?i)^(start|caster|sx\b|lanceur)", e):
            return "caster"
        return "target"        # dest/cible/dx/… — impact FX hit the aimed cell

    def _assign(self, lhs: str, v, env: dict) -> None:
        """`var = v` honouring an active startMobileDirection branch."""
        frame = next((f for f in reversed(self._ifs)
                      if f.get("dir") is not None), None)
        cur = env.get(lhs)
        if frame is not None:
            d = frame["dir"]
            if not isinstance(cur, dict):
                cur = {"dirs": {}, "def": cur}
            if d == "_":
                cur["def"] = v               # else-branch of a dir chain
            else:
                cur["dirs"][d] = v
            env[lhs] = cur
        elif isinstance(cur, dict):
            cur["def"] = v
        else:
            env[lhs] = v

    def _bind_tween_lhs(self, lhs: list, env: dict) -> None:
        """addTween returns (systemId, movementDuration)."""
        if not lhs:
            return
        env[lhs[0]] = UNKNOWN                       # system id: not a delay
        for nm in lhs[1:]:
            env[nm] = TWEEN
            env.setdefault("__src", {})[nm] = self.tween_rows  # row about to emit

    def _eval_delay(self, e: str, env: dict):
        e = e.strip()
        v = _eval(e, env)
        if v is TWEEN:
            src = env.get("__src", {}).get(e, self.tween_rows - 1)
            return "tw#%d" % max(src, 0)
        if isinstance(v, tuple) and v[0] == "tw+":
            # <timeVar>+k — find the tween var inside the expression
            var = re.sub(r"[+\-]?\d+(?:\.\d+)?", "", e).strip()
            var = re.sub(r"[+\-\s]", "", var)
            src = env.get("__src", {}).get(var, self.tween_rows - 1)
            k = int(v[1])
            return "tw#%d%s" % (max(src, 0), "%+d" % k if k else "")
        if isinstance(v, bool):
            return 0
        if isinstance(v, (int, float)):
            return int(v)
        return 0                     # unresolvable: fire with the cast

    @staticmethod
    def _add_delay(base_t, delay):
        if isinstance(base_t, int) and isinstance(delay, int):
            return base_t + delay
        if isinstance(delay, str):
            return delay                     # rebinds to the newer tween
        if isinstance(base_t, str):
            m = _TAG.match(base_t)
            if m:
                k = int(m.group(2) or 0) + delay
                return "tw#%d%s" % (int(m.group(1)),
                                    "%+d" % k if k else "")
            return base_t
        return 0

    # -- particle emission --------------------------------------------------
    def _particle_call(self, call, t, env, lhs: list | None) -> None:
        args = _split_args(call.group(2))
        if not args:
            return
        tween = bool(call.group(1))
        pid = self._resolve_id(args[0], env)
        if pid is None:
            return
        if tween and lhs:
            self._bind_tween_lhs(lhs, env)
        if tween:
            angle = _eval(args[7], env) if len(args) > 7 else UNKNOWN
            coef = _eval(args[9], env) if len(args) > 9 else UNKNOWN
            if not isinstance(angle, (int, float)) or isinstance(angle, bool):
                angle = 45
            if not isinstance(coef, (int, float)) or isinstance(coef, bool) \
                    or coef == 0:
                coef = 1
            self.fx.append((t, pid, "tw", angle, coef))
            self.tween_rows += 1
        else:
            self.fx.append((t, pid,
                            self._anchor(args[1]) if len(args) > 1
                            else "target"))

    # -- body scan ----------------------------------------------------------
    def scan(self, body: list, base_t, env: dict, seen: frozenset) -> None:
        for raw in body:
            ln = _clean(raw)
            if not ln:
                continue
            m = _IF.match(ln)
            if m:
                self._ifs.append(self._cond_frame(m.group(1), env))
                continue
            m = _ELSEIF.match(ln)
            if m:
                if not self._ifs:
                    continue
                f = self._ifs[-1]
                dm = _DIRCOND.search(m.group(1))
                if f["dir"] is not None:
                    if dm:
                        f["dir"] = int(dm.group(1))   # next dir in the chain
                    else:
                        f["dir"], f["active"] = "_", True
                    continue
                if f["seen"]:
                    f["active"] = False
                    continue
                if dm:
                    f["dir"], f["active"], f["seen"] = \
                        int(dm.group(1)), True, True
                    continue
                v = _eval(m.group(1), env)
                f["active"] = _truthy(v) if v is not UNKNOWN else True
                f["seen"] = f["seen"] or (v is not UNKNOWN and _truthy(v))
                continue
            if _ELSE.match(ln):
                if self._ifs:
                    f = self._ifs[-1]
                    if f["dir"] is not None:
                        f["dir"] = "_"                # dir-chain fallback
                    elif f["seen"]:
                        f["active"] = False
                    else:
                        f["active"] = True
                continue
            if _END.match(ln):
                if self._ifs:
                    self._ifs.pop()
                continue
            if not all(f["active"] for f in self._ifs):
                continue
            if _RETURN.match(ln):
                return

            m = _ASSIGN.match(ln)
            if m and not ln.startswith(("if ", "elseif ", "while ",
                                        "for ")):
                lhs = [x.strip() for x in m.group(1).split(",")]
                rhs = _split_args(m.group(2))
                if len(lhs) == len(rhs) == 1:
                    self._assign_expr(lhs[0], rhs[0], base_t, env)
                    continue
                if len(rhs) == 1 and (_PARTCALL.search(rhs[0]) or
                                      _GETWEEN.search(rhs[0])):
                    self._multi_ret(lhs, rhs[0], base_t, env)
                    continue
                for name, expr in zip(lhs, rhs):
                    if _VAR.match(name):
                        self._assign(name, _eval(expr, env), env)
                continue
            self._statement(ln, base_t, env, seen)

    def _cond_frame(self, cond: str, env: dict) -> dict:
        dm = _DIRCOND.search(cond)
        if dm:
            # scan every branch; assignments accumulate keyed by direction
            return {"dir": int(dm.group(1)), "active": True, "seen": True}
        v = _eval(cond, env)
        if v is UNKNOWN:
            return {"dir": None, "active": True, "seen": False}
        return {"dir": None, "active": _truthy(v), "seen": _truthy(v)}

    def _assign_expr(self, name: str, expr: str, base_t, env: dict) -> None:
        if not _VAR.match(name):
            return
        for m in PLAY.finditer(expr):
            self.sfx.append((base_t, int(m.group(1))))
        call = _PARTCALL.search(expr)
        if call:
            self._particle_call(call, base_t, env, [name])
            return
        if _GETWEEN.search(expr):
            env[name] = TWEEN
            env.setdefault("__src", {})[name] = self.tween_rows - 1
            return
        if _GETDIR.search(expr):
            env[name] = UNKNOWN            # runtime direction value
            return
        self._assign(name, _eval(expr, env), env)

    def _multi_ret(self, lhs: list, expr: str, base_t, env: dict) -> None:
        call = _PARTCALL.search(expr)
        if call:
            self._particle_call(call, base_t, env,
                                [n for n in lhs if _VAR.match(n)])
            return
        if _GETWEEN.search(expr):
            for nm in lhs:
                if _VAR.match(nm):
                    env[nm] = TWEEN
                    env.setdefault("__src", {})[nm] = self.tween_rows - 1
            return
        for nm in lhs:
            if _VAR.match(nm):
                env[nm] = UNKNOWN

    def _statement(self, ln: str, base_t, env: dict,
                   seen: frozenset) -> None:
        for m in _INVOKE.finditer(ln):
            delay = self._eval_delay(m.group(1), env)
            self._call_fn(m.group(2), m.group(3) or "",
                          self._add_delay(base_t, delay), env, seen)
        call = _PARTCALL.search(ln)
        if call:
            self._particle_call(call, base_t, env, None)
        for m in PLAY.finditer(ln):
            self.sfx.append((base_t, int(m.group(1))))
        for m in RAND.finditer(ln):
            ids = [int(x) for x in
                   re.findall(r"\d+", m.group(1))][2::2]
            for sid in ids:
                self.sfx.append((base_t, sid))
        m = _CALLFN.match(ln)
        if m:
            self._call_fn(m.group(1), m.group(2), base_t, env, seen)

    def _call_fn(self, fn: str, argstr: str, base_t, env: dict,
                 seen: frozenset) -> None:
        if fn not in self.funcs:
            return
        params, body = self.funcs[fn]
        args = _split_args(argstr)
        key = (fn, tuple(args))
        if key in seen or len(seen) > 128:
            return
        sub = dict(env)
        for i, p in enumerate(params):
            sub[p] = _eval(args[i], env) if i < len(args) else UNKNOWN
        saved, self._ifs = self._ifs, []
        self.scan(body, base_t, sub, seen | {key})
        self._ifs = saved

    def run(self) -> None:
        self.scan(self.top, 0, {}, frozenset())


def scan_script(src: str):
    """-> (fx_rows, sfx_rows) for one retail cast script."""
    sc = _Scan(src)
    sc.run()
    return sc.fx, sc.sfx


def _dedup(rows: list) -> list:
    """Exact-dup removal that never drops "tw" rows — "tw#i" tags index the
    tween sequence, so tween order/count must be preserved verbatim."""
    seen, out = set(), []
    for r in rows:
        if len(r) > 2 and r[2] == "tw":
            out.append(list(r))
            continue
        k = json.dumps(list(r), sort_keys=True, default=str)
        if k not in seen:
            seen.add(k)
            out.append(list(r))
    return out


def script_fx(src: str) -> list:
    return _dedup(scan_script(src)[0])


def script_sounds(src: str) -> list:
    return [[t, i] for t, i in _dedup(scan_script(src)[1])]


# ---------------------------------------------------------------------------
# anm boilerplate scripts (separate format — unchanged)
# ---------------------------------------------------------------------------

def anm_script_sounds(src: str):
    """Parse one scripts/anm/<id>.lua boilerplate.

    -> {"s": [[soundId, gain], ...], "stop": bool} or None.
    playLocalSound feeds soundFileId/gain/stopOnAnimationChange locals;
    playLocalRandomSound takes literal (id, gain) pairs picked UNIFORMLY
    (agO.java: ej_0.n — the second number is gain, not a weight).
    playBark/playGroundSound resolve through tables we don't ship -> None.
    """
    stop = re.search(r"stopOnAnimationChange\s*=\s*(\w+)", src)
    stop = stop.group(1) == "true" if stop else False
    sid = re.search(r"soundFileId\s*=\s*(\d+)", src)
    if sid:
        g = re.search(r"gain\s*=\s*([\d.]+)", src)
        return {"s": [[int(sid.group(1)),
                       float(g.group(1)) if g else 100.0]],
                "stop": stop}
    m = RAND.search(src)
    if m:
        nums = [int(x) for x in re.findall(r"\d+", m.group(1))]
        # var-name args carry no digits, so nums is exactly id,gain,id,gain…
        return {"s": [[nums[i], float(nums[i + 1])]
                      for i in range(0, len(nums) - 1, 2)],
                "stop": stop}
    return None  # playBark (npc voice table we don't ship) / silence


def main() -> None:
    spells_path, data_jar, sounds_jar, out_json, out_sounds = sys.argv[1:6]
    anm_json = sys.argv[6] if len(sys.argv) > 6 else None
    fx_json = sys.argv[7] if len(sys.argv) > 7 else None
    spells = json.load(open(spells_path))

    # spell -> scriptId (dedup across breeds)
    script_of = {}
    for lst in spells.values():
        for s in lst:
            if s.get("script"):
                script_of[s["id"]] = s["script"]

    result = {}
    fx_result = {}
    wanted = set()
    anm_result = {}
    barks = 0
    with zipfile.ZipFile(data_jar) as z:
        for sid, script in sorted(script_of.items()):
            try:
                src = z.read(f"scripts/{script}.lua").decode("latin-1")
            except KeyError:
                continue
            fx, sfx = scan_script(src)
            if sfx:
                result[str(sid)] = [[t, i] for t, i in _dedup(sfx)]
                wanted.update(i for _, i in sfx)
            if fx_json and fx:
                fx_result[str(sid)] = _dedup(fx)
        if anm_json:
            for nm in z.namelist():
                m = re.match(r"scripts/anm/(\d+)\.lua$", nm)
                if not m:
                    continue
                parsed = anm_script_sounds(
                    z.read(nm).decode("latin-1"))
                if parsed is None:
                    barks += 1
                    continue
                anm_result[m.group(1)] = parsed
                wanted.update(p[0] for p in parsed["s"])

    copied = 0
    with zipfile.ZipFile(sounds_jar) as z:
        for sid in sorted(wanted):
            try:
                data = z.read(f"sounds/{sid}.ogg")
            except KeyError:
                continue
            with open(f"{out_sounds}/{sid}.ogg", "wb") as f:
                f.write(data)
            copied += 1

    json.dump(result, open(out_json, "w"), separators=(",", ":"))
    print(f"spell sfx: {len(result)} spells, {len(wanted)} ids, "
          f"{copied} oggs -> {out_sounds}")
    if anm_json:
        json.dump(anm_result, open(anm_json, "w"), separators=(",", ":"))
        print(f"anm script sfx: {len(anm_result)} scripts, {barks} skipped "
              f"(bark/none) -> {anm_json}")
    if fx_json:
        json.dump(fx_result, open(fx_json, "w"), separators=(",", ":"))
        print(f"spell fx: {len(fx_result)} spells -> {fx_json}")


if __name__ == "__main__":
    main()
