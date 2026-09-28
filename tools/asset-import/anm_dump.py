#!/usr/bin/env python3
"""Exploratory .anm (Ankama Anm2) parser — dumps container structure.

Reference: decompiled client classes in client/decompiled/core/
  Anm.b(acf):        header bs_2 → [aek_0 colors] → textures vk_2 →
                    regions ana_1 → actions ju_2 → labels hn_2 → strings
  aca.o(acf):        transform union: i16 fL + u8 type + per-type payload
  xc_2.b(acf):       frame: transforms + jw_1 parts + RLE repeat
All little-endian (acf = ByteBuffer LITTLE_ENDIAN).
"""

import struct
import sys
import zlib
import zipfile


class Reader:
    def __init__(self, data: bytes, base: str = ""):
        self.d = data
        self.p = 0
        self.base = base

    def u8(self):
        v = self.d[self.p]; self.p += 1; return v

    def i8(self):
        v = self.u8(); return v - 256 if v >= 128 else v

    def u16(self):
        v = struct.unpack_from("<H", self.d, self.p)[0]; self.p += 2; return v

    def i16(self):
        v = struct.unpack_from("<h", self.d, self.p)[0]; self.p += 2; return v

    def u32(self):
        v = struct.unpack_from("<I", self.d, self.p)[0]; self.p += 4; return v

    def i32(self):
        v = struct.unpack_from("<i", self.d, self.p)[0]; self.p += 4; return v

    def f32(self):
        v = struct.unpack_from("<f", self.d, self.p)[0]; self.p += 4; return v

    def cstr(self):
        e = self.d.index(0, self.p)
        s = self.d[self.p:e].decode("utf-8", "replace")
        self.p = e + 1
        return s

    def remaining(self):
        return len(self.d) - self.p


# ---- transform payload layouts keyed by aca.o() type byte -------------------
# Inheritance chains from the decompiled subclasses — each level appends
# fields to its parent's b(). Payload EXCLUDES the [i16 fL][u8 type] header
# already read by aca.o().
def _s4(r):  # ui_2: aqM..aqP (4×i16)
    return {"s4": [r.i16(), r.i16(), r.i16(), r.i16()]}

def _f2(r):  # uh_2: acB/acC (2×f32)
    return {"f2": [r.f32(), r.f32()]}

def _e4(r):  # ub_1/aoB..aoE (4×i16)
    return {"e4": [r.i16(), r.i16(), r.i16(), r.i16()]}

def _b4(r):  # lf..li / cJP..cJS (4×u8)
    return {"b4": [r.u8(), r.u8(), r.u8(), r.u8()]}

def _chain(*fns):
    def go(r):
        out = {}
        for fn in fns:
            out.update(fn(r))
        return out
    return go

TRANSFORMS = {
    0:   ("abd_0", None),
    1:   ("ui_2",  _s4),
    2:   ("uh_2",  _f2),
    3:   ("aoN",   _chain(_s4, _f2)),
    4:   ("ub_1",  _e4),
    5:   ("aoa_0", _chain(_s4, _e4)),
    6:   ("aoq",   _chain(_f2, _e4)),
    7:   ("aLt",   _chain(_s4, _f2, _e4)),
    8:   ("uf_2",  _b4),
    9:   ("aoz_0", _chain(_s4, _b4)),
    10:  ("aia",   _chain(_f2, _b4)),
    11:  ("aLl",   _chain(_s4, _f2, _b4)),
    12:  ("xp_2",  _chain(_e4, _b4)),
    13:  ("ato",   _chain(_s4, _e4, _b4)),
    14:  ("dh",    _chain(_f2, _e4, _b4)),
    15:  ("azU",   _chain(_s4, _f2, _e4, _b4)),
    49:  ("ang_2", _b4),
    82:  ("anj_1", lambda r: {"cJVW": [r.i16(), r.i16()]}),
    179: ("ih_2",  _chain(_b4, lambda r: {"xPQ": [r.u8(), r.u8()]})),  # -77 byte
}


def parse_transform(r: Reader):
    off = r.p
    fl = r.i16()
    t = r.u8()
    name, fields = TRANSFORMS.get(t, (None, None))
    rec = {"fL": fl, "type": t, "kind": name, "off": off}
    if name is None:
        raise ValueError(f"unknown transform type {t} @{off:#x}"
                         f" (ctx: {r.d[max(0,off-8):off+8].hex(' ')})")
    if fields is not None:
        rec["data"] = fields(r)
    return rec


def parse_action(r: Reader):
    a = {"off": r.p, "fL": r.i16(), "flags": r.u8()}
    if a["flags"] & 0x40:
        a["name"] = r.cstr()
    a["crc"] = r.i32()
    a["parent"] = r.i32()
    a["shape_defs"] = [parse_transform(r) for _ in range(r.u8())]
    a["shape_defs2"] = [parse_transform(r) for _ in range(r.u8())]
    nframes = r.u16()
    # Two on-disk frame grammars exist in the wild: decompiled xc_2.b reads a
    # trailing u16 "repeat" (RLE — repeated frames are virtual), but some files
    # (e.g. animations/gui/lvlUp.anm) have no such field and every action's
    # frames chain directly into the next action. Try RLE first; if it
    # desyncs, fall back to the flat grammar.
    start = r.p
    try:
        a["frames"] = _frames_rle(r, nframes)
    except Exception:
        r.p = start
        a["frames"] = [parse_frame(r, fi, rle=False) for fi in range(nframes)]
    a["logical_frames"] = nframes
    return a


def _frames_rle(r: Reader, nframes: int):
    frames = []
    fi = 0
    while fi < nframes:
        f = parse_frame(r, fi)
        if 1 + f["repeat"] > nframes - fi:
            raise ValueError("repeat overshoots frame count")
        frames.append(f)
        fi += 1 + f["repeat"]
    return frames


def parse_frame(r: Reader, idx: int, rle: bool = True):
    f = {"idx": idx, "transforms": [parse_transform(r) for _ in range(r.u16())]}
    f["parts"] = [parse_part(r) for _ in range(r.u8())]
    f["repeat"] = r.u16() if rle else 0
    return f


def parse_part(r: Reader):
    """jw_1 frame part — u8 actionId + u8 paramCount + per-type payload.
    Layouts from tj_1.java factory (ids 5/6/7 consume zero bytes)."""
    off = r.p
    tid = r.u8()
    nparams = r.u8()
    part = {"type": tid, "nparams": nparams, "off": off}
    if tid == 1:          # cm_2 — play anim, optional probability
        part["anim"] = r.cstr()
        if nparams == 2:
            part["pct"] = r.u8()
    elif tid == 2:        # od_2 — replay current anim (no payload)
        pass
    elif tid == 3:        # pb_1 — external script id (numeric cstr)
        part["script"] = r.cstr()
    elif tid == 4:        # bf_0 — weighted anim picker: paramCount cstrs
        part["opts"] = [r.cstr() for _ in range(nparams)]
    elif tid == 8:        # als_0 — match→anim pairs + optional fallback
        n = (nparams - 1) // 2
        part["pairs"] = [(r.cstr(), r.cstr()) for _ in range(n)]
        if nparams % 2:
            part["fallback"] = r.cstr()
    elif tid == 9:        # awe_0 — attach particle system
        part["ps"] = r.i32()
        if nparams == 3:
            part["dx"] = r.i16(); part["dy"] = r.i16()
    elif tid == 10:       # rj_1 — secondary scale factor
        part["scale"] = r.i8()
    elif tid in (5, 6, 7):  # null factory — zero payload bytes
        pass
    else:
        raise ValueError(f"jw_1 part type {tid} nparams={nparams} @{off:#x}")
    return part


def parse_colors(r: Reader):
    """aek_0 — optional part-color/skin table (header flag bit1)."""
    cz = r.u8()
    c = {"flags": cz}
    if cz & 1:
        c["Gx"] = r.f32()
    if cz & 8:
        c["cpB"] = r.f32()
    if cz & 2:
        c["part_names"] = [r.cstr() for _ in range(r.u16())]
    if cz & 4:
        c["pairs"] = [{"a": r.i32(), "b": r.i32()} for _ in range(r.u8())]
    if cz & 0x40:
        c["ze"] = [{"name": r.cstr(), "v": r.i32()} for _ in range(r.u8())]
    c["skins"] = [{"name": r.cstr(), "crc": r.i32(), "aUs": r.i16()}
                  for _ in range(r.u16())]
    return c


def parse_anm(data: bytes):
    r = Reader(data)
    out = {}
    flags = r.u8()
    out["header"] = {"flags": flags, "u16": r.i16(), "fps": r.u8()}
    if flags & 0x2:  # cJ — color transform table
        out["colors"] = parse_colors(r)
    out["textures"] = [{"name": r.cstr(), "crc": r.i32()} for _ in range(r.u16())]
    out["regions"] = []
    for _ in range(r.u16()):
        out["regions"].append({
            "id": r.i16(), "dZA": r.i16(),
            "uv": [r.u16() / 65535.0 for _ in range(4)],
            "adE": r.i16(), "adF": r.i16(),
            "Gv": r.f32(), "Gw": r.f32(),
        })
    out["actions"] = [parse_action(r) for _ in range(r.u16())]
    out["labels"] = [{"id": r.i16(), "name": r.cstr(), "crc": r.i32()}
                     for _ in range(r.u16())]
    out["strings"] = [r.cstr() for _ in range(r.u16())]
    out["trailing"] = r.remaining()
    return out


def summarize(out, name):
    h = out["header"]
    print(f"== {name}: flags={h['flags']:#04x} unk16={h['u16']} fps={h['fps']}")
    print(f"   textures: {[t['name'] for t in out['textures']]}")
    print(f"   regions: {len(out['regions'])}")
    for a in out["actions"]:
        nf = len(a["frames"])
        print(f"   action {a['fL']:4} '{a.get('name','')}' crc={a['crc']:#x}"
              f" parent={a['parent']} defs={len(a['shape_defs'])}"
              f" defs2={len(a['shape_defs2'])} frames={nf}"
              f"/{a['logical_frames']}")
    print(f"   labels: {len(out['labels'])}  strings: {len(out['strings'])}"
          f"  trailing: {out['trailing']}B")


def main():
    if len(sys.argv) < 2:
        print("usage: anm_dump.py <file.anm|animations.jar[:entry]>")
        return 1
    src = sys.argv[1]
    if src.endswith(".jar"):
        with zipfile.ZipFile(src) as z:
            names = [n for n in z.namelist() if n.endswith(".anm")]
            sel = sys.argv[2] if len(sys.argv) > 2 else None
            for n in names:
                if sel and sel not in n:
                    continue
                try:
                    out = parse_anm(z.read(n))
                    summarize(out, n)
                except Exception as e:
                    print(f"== {n}: PARSE FAIL — {e}")
        return 0
    data = open(src, "rb").read()
    try:
        summarize(parse_anm(data), src)
    except Exception as e:
        print(f"PARSE FAIL @{src}: {e}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
