#!/usr/bin/env python3
"""
gen_messages.py — generate the GDScript message layer for the Godot client.

Inputs:
  client/analysis/payloads.csv      field-level layouts (opcode,obf,real,dir,…)
  client/analysis/opcode_map.csv    opcode -> class/direction map
  client/decompiled/core/*.java     mined for the C2S archTarget byte
  tools/proto-gen/overrides.json    hand-curated annotations (win over CSV)

Outputs (committed — the Godot project builds without re-running this):
  godot/src/net/generated/opcodes.gd       OPCODE_* consts, NAMES, ARCH
  godot/src/net/generated/message_defs.gd  opcode -> field schema DEFS

Classification (mirrors the audit of payloads.csv):
  flat    — all scalar rows            -> emitted
  empty   — "(no fields / empty)"      -> emitted with fields=[]
  bytes   — contains i8/bytes rows     -> unresolved unless overridden
  loop    — 'contains loop/collection' -> unresolved unless overridden
  hand    — overrides.json handler     -> routed to codec_overrides.gd
Unresolved C2S messages get NO encoder (never emit silently-wrong bytes);
unresolved S2C messages decode to {} — under-reading is safe since each
message is decoded on a payload-scoped reader.
"""

import csv, json, re, sys
from pathlib import Path
from collections import defaultdict

ROOT = Path(__file__).resolve().parent.parent.parent
ANALYSIS = ROOT / "client" / "analysis"
DECOMPILED = ROOT / "client" / "decompiled" / "core"
OUT_DIR = ROOT / "godot" / "src" / "net" / "generated"
OVERRIDES = Path(__file__).parent / "overrides.json"

SCALAR_TYPES = {"i8", "u8", "i16", "u16", "i32", "i64", "f32", "f64"}
# arch byte senders: `this.a((byte)N, …)` literal, or conditional `(byte)(x ? A : B)`
RE_ARCH_NUM = re.compile(r"\.a\(\s*\(byte\)\s*(\d+)\s*,")
RE_ARCH_COND = re.compile(r"\.a\(\s*\(byte\)\s*\(")


def load_csv(path):
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def snake(name: str) -> str:
    s = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", "_", name).upper()
    return re.sub(r"[^A-Z0-9]", "_", s)


def mine_arch(obf_file: str):
    """Return (arch:int|None, conditional:bool) from the class's encode()."""
    src = DECOMPILED / f"{obf_file}.java"
    if not src.exists():
        return None, False
    text = src.read_text(encoding="utf-8", errors="replace")
    m = RE_ARCH_NUM.search(text)
    if m:
        return int(m.group(1)), False
    return None, bool(RE_ARCH_COND.search(text))


def main() -> int:
    overrides = json.loads(OVERRIDES.read_text(encoding="utf-8"))
    ov_opcodes = {int(k): v for k, v in overrides["opcodes"].items()}
    arch_fixes = {int(k): v for k, v in overrides["arch_fixes"].items()
                  if not k.startswith("_")}
    hand_coded = set(overrides["hand_coded"]["list"])

    # opcode_map.csv is the master opcode list (opcode may repeat per class).
    opmap = load_csv(ANALYSIS / "opcode_map.csv")
    meta = {}  # (opcode, obf) -> {real, dir, base}
    for row in opmap:
        if row["direction"] not in ("C2S", "S2C"):
            continue
        key = (int(row["opcode"]), row["obf_file"])
        meta[key] = {"real": row["real_class"], "dir": row["direction"],
                     "base": row["base"]}

    # payloads.csv rows grouped by entry (opcode, obf).
    entries = defaultdict(list)  # key -> field rows
    for row in load_csv(ANALYSIS / "payloads.csv"):
        key = (int(row["opcode"]), row["obf"])
        entries[key].append(row)

    defs = {}      # opcode -> {"name","dir","fields"|"handler"}
    names = {}     # opcode -> display name (first entry wins)
    arch_map = {}  # C2S opcode -> arch byte
    report = defaultdict(list)

    for (opcode, obf), info in sorted(meta.items()):
        base = info["base"] or ""
        if base.startswith("axX"):
            report["admin_channel_skipped"].append(opcode)
            continue

        ov = ov_opcodes.get(opcode)
        rows = entries.get((opcode, obf), [])
        name = (ov or {}).get("name") or info["real"] or f"Msg{opcode}"
        names.setdefault(opcode, name)

        # --- direction ---
        direction = (ov or {}).get("dir") or info["dir"]

        # --- arch mining for C2S ---
        if direction == "C2S" and opcode not in arch_map:
            arch, cond = mine_arch(obf)
            ov_arch = (ov or {}).get("arch", arch_fixes.get(opcode))
            if ov_arch is not None:
                arch_map[opcode] = ov_arch if not isinstance(ov_arch, str) else -1
            elif arch is not None:
                arch_map[opcode] = arch
            elif cond:
                arch_map[opcode] = arch_fixes.get(opcode, -1)
                report["arch_conditional"].append(opcode)
            else:
                report["arch_unknown"].append(opcode)

        # --- fields ---
        if ov and "handler" in ov:
            defs.setdefault(opcode, {"name": name, "dir": direction,
                                     "handler": ov["handler"]})
            report["hand"].append(opcode)
            continue
        if opcode in hand_coded:
            defs.setdefault(opcode, {"name": name, "dir": direction,
                                     "handler": "hand"})
            report["hand"].append(opcode)
            continue

        if ov and "fields" in ov:
            fields = ov["fields"]
            kind = "override"
        elif not rows or all(r["field_name"] == "(no fields / empty)"
                             or not r["type"] for r in rows):
            fields, kind = [], "empty"
        else:
            types = [r["type"] for r in rows]
            loop = any("loop" in (r["note"] or "") for r in rows)
            has_bytes = any(t == "i8/bytes" for t in types)
            if loop or has_bytes or any(t not in SCALAR_TYPES for t in types):
                defs.setdefault(opcode, {"name": name, "dir": direction,
                                         "handler": "unresolved"})
                report["unresolved"].append(opcode)
                continue
            fields = [{"n": r["field_name"] or f"f{r['field_idx']}",
                       "t": r["type"]} for r in rows]
            kind = "flat"

        defs.setdefault(opcode, {"name": name, "dir": direction,
                                 "fields": fields})
        report[kind].append(opcode)

    # Opcodes absent from opcode_map.csv entirely (503/505/515…) — overrides
    # are the only source of truth for them.
    known_opcodes = {op for op, _ in meta}
    for opcode, ov in sorted(ov_opcodes.items()):
        if opcode in known_opcodes:
            continue
        names.setdefault(opcode, ov.get("name", f"Msg{opcode}"))
        if "arch" in ov and isinstance(ov["arch"], int):
            arch_map[opcode] = ov["arch"]
        if "handler" in ov:
            defs[opcode] = {"name": ov["name"], "dir": ov.get("dir", "S2C"),
                            "handler": ov["handler"]}
        else:
            defs[opcode] = {"name": ov["name"], "dir": ov.get("dir", "S2C"),
                            "fields": ov.get("fields", [])}
        report["override_only"].append(opcode)

    # --- emit ---
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    _emit_opcodes(defs, names, arch_map)
    _emit_defs(defs)

    # --- report ---
    print(f"entries in opcode_map: {len(meta)}")
    for k in ("flat", "empty", "override", "override_only", "hand", "unresolved",
              "admin_channel_skipped", "arch_conditional", "arch_unknown"):
        v = report[k]
        print(f"  {k:22} {len(v):4}  {sorted(set(v))[:14]}"
              + ("…" if len(set(v)) > 14 else ""))
    print(f"arch mined: {len(arch_map)} C2S opcodes")
    print(f"emitted: {OUT_DIR.relative_to(ROOT)}")
    return 0


def _gd_name(opcode: int, name: str) -> str:
    base = snake(name)
    return f"OP_{base}" if base else f"OP_{opcode}"


def _emit_opcodes(defs, names, arch_map):
    lines = [
        "extends RefCounted",
        "",
        "## AUTO-GENERATED by tools/proto-gen/gen_messages.py — do not edit.",
        "",
    ]
    used = set()
    for opcode in sorted(names):
        cname = _gd_name(opcode, names[opcode])
        if cname in used:
            cname = f"{cname}_{opcode}"
        used.add(cname)
        lines.append(f"const {cname} := {opcode}")
    lines += ["", "const NAMES := {"]
    for opcode in sorted(names):
        lines.append(f'\t{opcode}: "{names[opcode]}",')
    lines += ["}", "", "## C2S archTarget per opcode (-1 = conditional/unknown;",
            "## the Go server ignores it, emitted for capture parity)",
            "const ARCH := {"]
    for opcode in sorted(arch_map):
        lines.append(f"\t{opcode}: {arch_map[opcode]},")
    lines += ["}", ""]
    (OUT_DIR / "opcodes.gd").write_text("\n".join(lines), encoding="utf-8")


def _emit_defs(defs):
    lines = [
        "extends RefCounted",
        "",
        "## AUTO-GENERATED by tools/proto-gen/gen_messages.py — do not edit.",
        "## opcode -> {name, dir, fields[]|handler}",
        "",
        "const DEFS := {",
    ]
    for opcode in sorted(defs):
        d = defs[opcode]
        if "handler" in d:
            lines.append(f'\t{opcode}: {{"name": "{d["name"]}", "dir": "{d["dir"]}", '
                         f'"handler": "{d["handler"]}"}},')
        else:
            ftxt = ", ".join(
                f'{{"n": "{f["n"]}", "t": "{f["t"]}"'
                + (f', "enc": "{f["enc"]}"' if f.get("enc") else "")
                + "}" for f in d["fields"])
            lines.append(f'\t{opcode}: {{"name": "{d["name"]}", "dir": "{d["dir"]}", '
                         f'"fields": [{ftxt}]}},')
    lines += ["}", ""]
    (OUT_DIR / "message_defs.gd").write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())
