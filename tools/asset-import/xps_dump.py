#!/usr/bin/env python3
"""xps_dump.py — decode retail .xps particle systems (sfx.jar) to JSON.

Wire layout follows alo_2 / ParticleSystemLoader (2.70 uses tag bytes, not the
minLevel/maxLevel/dataOffset skip block). Field names match wakfu-src
EmitterDefinition / ParticleModel / affector RW semantics.

Usage:
  python3 tools/asset-import/xps_dump.py \\
      client/compiled/game/contents/sfx.jar \\
      godot/assets/gamedata/xps godot/assets/fx
"""

from __future__ import annotations

import json
import struct
import sys
import zipfile

MAGIC = 0x5001
LEVEL = 100  # lerp at max level (retail default for fight FX)

# gg_0 affector tag -> wakfu-style name (arena ids differ from wakfu 1.14 set)
AFF_NAMES = {
    1: "LinearForce",
    2: "BoostForce",
    3: "CirclePath",
    4: "ColorFader",
    5: "Deformer",
    6: "DirectionFollower",
    7: "FrictionalForce",
    8: "LinearForceEx",
    9: "RotationInterpolation",
    10: "Rebound",
    11: "Curve",
}
COND_NAMES = {1: "TimeCondition", 2: "ValueCondition"}


class Reader:
    """acf + aij_1 bit booleans (MSB-first), align before multi-byte reads."""

    __slots__ = ("data", "pos", "_bb", "_bc")

    def __init__(self, data: bytes):
        self.data = data
        self.pos = 0
        self._bb = 0
        self._bc = 0

    def remaining(self) -> int:
        return len(self.data) - self.pos

    def align(self) -> None:
        self._bb = 0
        self._bc = 0

    def bool_bit(self) -> bool:
        if self._bc == 0:
            self._bb = self.data[self.pos]
            self.pos += 1
            self._bc = 8
        self._bc -= 1
        return bool((self._bb >> self._bc) & 1)

    def u8(self) -> int:
        self.align()
        v = self.data[self.pos]
        self.pos += 1
        return v

    def u16(self) -> int:
        self.align()
        v = struct.unpack_from("<H", self.data, self.pos)[0]
        self.pos += 2
        return v

    def i32(self) -> int:
        self.align()
        v = struct.unpack_from("<i", self.data, self.pos)[0]
        self.pos += 4
        return v

    def i64(self) -> int:
        self.align()
        v = struct.unpack_from("<q", self.data, self.pos)[0]
        self.pos += 8
        return v

    def f32(self) -> float:
        self.align()
        v = struct.unpack_from("<f", self.data, self.pos)[0]
        self.pos += 4
        return v

    def leveled_u16(self, leveled: bool, t: float) -> int:
        a = self.u16()
        if not leveled:
            return a
        b = self.u16()
        return int(round(a + (b - a) * t)) & 0xFFFF

    def leveled_i32(self, leveled: bool, t: float) -> int:
        a = self.i32()
        if not leveled:
            return a
        b = self.i32()
        return int(round(a + (b - a) * t))

    def leveled_f32(self, leveled: bool, t: float) -> float:
        a = self.f32()
        if not leveled:
            return a
        b = self.f32()
        return a + (b - a) * t


def _read_affector(r: Reader, t: float) -> dict:
    tag = r.u8()
    name = AFF_NAMES.get(tag, f"Unknown{tag}")
    leveled = r.bool_bit()
    out: dict = {"type": tag, "name": name, "leveled": leveled}

    if tag == 1:  # ku_1 LinearForce
        out["forceX"] = r.leveled_f32(leveled, t)
        out["forceY"] = r.leveled_f32(leveled, t)
        out["forceZ"] = r.leveled_f32(leveled, t)
        out["forceW"] = r.leveled_f32(leveled, t)
        out["mode"] = r.u8()
        out["keyframed"] = True
    elif tag == 2:  # BoostForce
        out["x"] = r.leveled_f32(leveled, t)
        out["y"] = r.leveled_f32(leveled, t)
        out["z"] = r.leveled_f32(leveled, t)
    elif tag == 3:  # CirclePath
        out["radius"] = r.leveled_f32(leveled, t)
    elif tag == 4:  # ColorFader
        for k in ("r", "g", "b", "a", "speed"):
            out[k] = r.leveled_f32(leveled, t)
    elif tag == 5:  # Deformer
        for k in ("p0", "p1", "p2", "p3", "p4", "p5"):
            out[k] = r.leveled_f32(leveled, t)
        out["keyframed"] = True
    elif tag == 6:  # DirectionFollower — no payload
        pass
    elif tag == 7:  # FrictionalForce
        out["friction"] = r.leveled_f32(leveled, t)
    elif tag == 8:  # LinearForceEx
        out["geocentric"] = r.bool_bit()
        out["x"] = r.leveled_f32(leveled, t)
        out["y"] = r.leveled_f32(leveled, t)
        out["z"] = r.leveled_f32(leveled, t)
    elif tag == 9:  # RotationInterpolation
        for i in range(12):
            out[f"f{i}"] = r.leveled_f32(leveled, t)
    elif tag == 10:  # Rebound
        out["restitution"] = r.leveled_f32(leveled, t)
    elif tag == 11:  # Curve
        out["value"] = r.leveled_f32(leveled, t)
        out["keyframed"] = True
    else:
        raise ValueError(f"unknown affector type {tag}")

    ncond = r.u8()
    conds = []
    for _ in range(ncond):
        ct = r.u8()
        cn = COND_NAMES.get(ct, f"Cond{ct}")
        clev = r.bool_bit()
        if ct == 1:
            conds.append({
                "type": ct, "name": cn,
                "minTime": r.leveled_f32(clev, t),
                "maxTime": r.leveled_f32(clev, t),
            })
        elif ct == 2:
            conds.append({
                "type": ct, "name": cn,
                "invert": r.bool_bit(),
                "kind": r.u8(),
                "threshold": r.leveled_i32(clev, t),
            })
        else:
            raise ValueError(f"unknown condition type {ct}")
    if conds:
        out["conditions"] = conds
    return out


def _read_affectors(r: Reader, t: float) -> tuple[list, list]:
    normal, key = [], []
    n = r.u8()
    for _ in range(n):
        aff = _read_affector(r, t)
        (key if aff.get("keyframed") else normal).append(aff)
    return normal, key


def _read_anim_curve(r: Reader) -> dict | None:
    n = r.u8()
    if n == 0:
        return None
    duration_ms = r.i32()
    s0, s1, s2, s3 = (r.u16() for _ in range(4))
    frame_dur = [r.u16() for _ in range(n)]
    uv = [r.u16() for _ in range(n * 2)]
    return {
        "durationMs": duration_ms,
        "origin": [s0, s1, s2, s3],
        "frameDurMs": frame_dur,
        "uvCells": uv,
    }


_BITMAP_FLOATS = [
    "hotX", "hotY", "scaleX", "scaleY", "scaleRandomX", "scaleRandomY",
    "rotation", "rotationRandom",
    "red", "green", "blue", "alpha",
    "redRandom", "greenRandom", "blueRandom", "alphaRandom",
    "textureTop", "textureLeft", "textureBottom", "textureRight",
    "halfWidth", "halfHeight",
    "rotationX", "rotationY", "rotationZ",
]

_SEQUENCE_FLOATS = [
    "hotX", "hotY", "scaleX", "scaleY", "scaleRandomX", "scaleRandomY",
    "rotation", "rotationRandom",
    "red", "green", "blue", "alpha",
    "redRandom", "greenRandom", "blueRandom", "alphaRandom",
    "halfWidth", "halfHeight",
]


def _read_particle_model(r: Reader, t: float) -> dict:
    tag = r.u8()
    if tag == 1:  # ParticleBitmapModelAttributesRW / bk_0
        leveled = r.bool_bit()
        scale_random_keep_ratio = r.bool_bit()
        tex_index = r.i32()
        vals = [r.leveled_f32(leveled, t) for _ in _BITMAP_FLOATS]
        m = dict(zip(_BITMAP_FLOATS, vals))
        m["type"] = 1
        m["name"] = "ParticleBitmapModel"
        m["scaleRandomKeepRatio"] = scale_random_keep_ratio
        m["textureIndex"] = tex_index
        return m
    if tag == 2:  # ParticleBitmapSequenceModelAttributesRW / amc_2
        leveled = r.bool_bit()
        scale_random_keep_ratio = r.bool_bit()
        tex_index = r.i32()
        vals = [r.leveled_f32(leveled, t) for _ in _SEQUENCE_FLOATS]
        m = dict(zip(_SEQUENCE_FLOATS, vals))
        m["type"] = 2
        m["name"] = "ParticleBitmapSequenceModel"
        m["scaleRandomKeepRatio"] = scale_random_keep_ratio
        m["textureIndex"] = tex_index
        m["anim"] = _read_anim_curve(r)
        m["speed"] = r.leveled_f32(leveled, t)
        m["loopCount"] = r.leveled_i32(leveled, t)
        for k in ("rotationX", "rotationY", "rotationZ"):
            m[k] = r.leveled_f32(leveled, t)
        return m
    raise ValueError(f"unknown particle model tag {tag}")


def _read_light(r: Reader, t: float) -> dict:
    assert r.u8() == 2
    leveled = r.bool_bit()
    return {
        "name": "LightDefinition",
        "intensity": r.leveled_f32(leveled, t),
        "radius": r.leveled_f32(leveled, t),
        "r": r.leveled_f32(leveled, t),
        "g": r.leveled_f32(leveled, t),
        "b": r.leveled_f32(leveled, t),
    }


def _read_emitter(r: Reader, t: float) -> dict | None:
    tag = r.u8()
    if tag == 0:
        return None
    assert tag == 1
    fb = r.pos
    leveled = r.bool_bit()
    geocentric = r.bool_bit()
    # Retail files sometimes store leveled=1 as a bare 0x01 flag byte (bit0
    # set, MSB leveled/geo bits clear) — alo_2 still expects leveled data.
    if r.data[fb] == 1 and not leveled:
        leveled = True
    em = {
        "name": "EmitterDefinition",
        "geocentric": geocentric,
        "maxParticles": r.leveled_u16(leveled, t),
        "maxPerSpawn": r.leveled_u16(leveled, t),
        "spawnFrequency": r.leveled_f32(leveled, t),
        "particleLifeTime": r.leveled_f32(leveled, t),
        "spawnFrequencyRandom": r.leveled_f32(leveled, t),
        "particleLifeTimeRandom": r.leveled_f32(leveled, t),
        "offsetX": r.leveled_f32(leveled, t),
        "offsetY": r.leveled_f32(leveled, t),
        "offsetZ": r.leveled_f32(leveled, t),
        "offsetRandX": r.leveled_f32(leveled, t),
        "offsetRandY": r.leveled_f32(leveled, t),
        "offsetRandZ": r.leveled_f32(leveled, t),
        "velocityX": r.leveled_f32(leveled, t),
        "velocityY": r.leveled_f32(leveled, t),
        "velocityZ": r.leveled_f32(leveled, t),
        "velocityRandX": r.leveled_f32(leveled, t),
        "velocityRandY": r.leveled_f32(leveled, t),
        "velocityRandZ": r.leveled_f32(leveled, t),
        "startSpawnTime": r.leveled_f32(leveled, t),
        "endSpawnTime": r.leveled_f32(leveled, t),
        "models": [],
        "affectors": [],
        "keyframedAffectors": [],
        "lights": [],
        "subEmitters": [],
    }
    nm = r.u8()
    for _ in range(nm):
        em["models"].append(_read_particle_model(r, t))
    aff, key = _read_affectors(r, t)
    em["affectors"] = aff
    em["keyframedAffectors"] = key
    nl = r.u8()
    for _ in range(nl):
        light = _read_light(r, t)
        laff, lkey = _read_affectors(r, t)
        light["affectors"] = laff
        light["keyframedAffectors"] = lkey
        em["lights"].append(light)
    ns = r.u8()
    for _ in range(ns):
        em["subEmitters"].append(_read_emitter(r, t))
    return em


def parse_xps_header(data: bytes, level: int = LEVEL) -> dict:
    """System block only — enough for texture + duration + blend."""
    r = Reader(data)
    if r.u16() != MAGIC:
        raise ValueError("bad magic")
    t = 0.0 if level <= 1 else min(level, 100) / 100.0
    leveled = r.bool_bit()
    geocentric = r.bool_bit()
    behind_mobile = r.bool_bit()
    return {
        "leveled": leveled,
        "geocentric": geocentric,
        "behindMobile": behind_mobile,
        "srcBlend": r.i32(),
        "dstBlend": r.i32(),
        "textureId": r.i64(),
        "durationMs": r.leveled_u16(leveled, t),
        "renderRadius": r.u8(),
    }


def parse_xps(data: bytes, level: int = LEVEL) -> dict:
    r = Reader(data)
    if r.u16() != MAGIC:
        raise ValueError("bad magic")
    t = 0.0 if level <= 1 else min(level, 100) / 100.0
    leveled = r.bool_bit()
    geocentric = r.bool_bit()
    behind_mobile = r.bool_bit()
    sysd = {
        "leveled": leveled,
        "geocentric": geocentric,
        "behindMobile": behind_mobile,
        "srcBlend": r.i32(),
        "dstBlend": r.i32(),
        "textureId": r.i64(),
        "durationMs": r.leveled_u16(leveled, t),
        "renderRadius": r.u8(),
        "emitters": [],
    }
    ne = r.u8()
    for _ in range(ne):
        em = _read_emitter(r, t)
        if em is not None:
            sysd["emitters"].append(em)
    tail = r.data[r.pos:]
    if tail and any(b != 0 for b in tail):
        raise ValueError(f"trailing {len(tail)} non-zero bytes at {r.pos}")
    r.pos = len(r.data)
    return sysd


# ---------------------------------------------------------------- TGA ----
def decode_tga(data: bytes) -> tuple[int, int, bytes]:
    """Standard Targa type 2/10, 24/32 bpp (matches server/cmd/studio/tga.go)."""
    if len(data) < 18:
        raise ValueError("tga too short")
    id_len = data[0]
    if data[1] != 0:
        raise ValueError("color-mapped tga unsupported")
    img_type = data[2]
    w = struct.unpack_from("<H", data, 12)[0]
    h = struct.unpack_from("<H", data, 14)[0]
    depth = data[16]
    desc = data[17]
    if img_type not in (2, 10) or depth not in (24, 32):
        raise ValueError(f"unsupported tga type={img_type} depth={depth}")
    bpp = depth // 8
    off = 18 + id_len
    n = w * h * bpp
    raw = bytearray(n)
    if img_type == 2:
        raw[:] = data[off:off + n]
    else:
        si = di = 0
        src = data[off:]
        while di < n:
            packet = src[si]
            si += 1
            count = (packet & 0x7F) + 1
            if packet & 0x80:
                pix = src[si:si + bpp]
                si += bpp
                for _ in range(count):
                    raw[di:di + bpp] = pix
                    di += bpp
            else:
                run = count * bpp
                raw[di:di + run] = src[si:si + run]
                si += run
                di += run
    top = bool(desc & 0x20)
    rgba = bytearray(w * h * 4)
    for i in range(w * h):
        b = raw[i * bpp]
        g = raw[i * bpp + 1]
        r = raw[i * bpp + 2]
        a = raw[i * bpp + 3] if bpp == 4 else 255
        x = i % w
        row = i // w
        y = row if top else h - 1 - row
        j = (y * w + x) * 4
        rgba[j:j + 4] = (r, g, b, a)
    return w, h, bytes(rgba)


def write_png(path: str, w: int, h: int, rgba: bytes) -> None:
    import zlib

    def chunk(tag: bytes, payload: bytes) -> bytes:
        c = struct.pack(">I", len(payload)) + tag + payload
        return c + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)

    raw = b"".join(
        b"\x00" + rgba[y * w * 4:(y + 1) * w * 4] for y in range(h))
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 9))
           + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(png)


def main() -> None:
    sfx_jar, out_json_dir, out_tex_dir = sys.argv[1:4]
    out_index = sys.argv[4] if len(sys.argv) > 4 else None
    import os
    os.makedirs(out_json_dir, exist_ok=True)
    os.makedirs(out_tex_dir, exist_ok=True)

    textures: set[int] = set()
    index: dict[str, dict] = {}
    ok = fail = 0
    with zipfile.ZipFile(sfx_jar) as z:
        names = sorted(n for n in z.namelist()
                       if n.startswith("particles/") and n.endswith(".xps"))
        for nm in names:
            xid = nm.rsplit("/", 1)[-1][:-4]
            data = z.read(nm)
            try:
                hdr = parse_xps_header(data)
                index[xid] = hdr
            except Exception as e:
                print(f"HDR {xid}: {e}")
            try:
                doc = parse_xps(data)
            except Exception as e:
                print(f"FAIL {xid}: {e}")
                fail += 1
                continue
            textures.add(int(doc["textureId"]))
            index[xid] = {**index.get(xid, {}), "full": True}
            with open(f"{out_json_dir}/{xid}.json", "w") as f:
                json.dump(doc, f, separators=(",", ":"))
            ok += 1

        for xid, ent in index.items():
            textures.add(int(ent["textureId"]))

        copied = 0
        for tid in sorted(textures):
            tga = None
            for ent in (f"particles/{tid}.tga", f"{tid}.tga"):
                try:
                    tga = z.read(ent)
                    break
                except KeyError:
                    continue
            if tga is None:
                continue
            try:
                w, h, rgba = decode_tga(tga)
                write_png(f"{out_tex_dir}/{tid}.png", w, h, rgba)
                copied += 1
            except Exception as e:
                print(f"tga {tid}: {e}")

    print(f"xps: {ok} ok, {fail} fail -> {out_json_dir}")
    print(f"textures: {copied}/{len(textures)} png -> {out_tex_dir}")
    if out_index:
        json.dump(index, open(out_index, "w"), separators=(",", ":"))
        print(f"index: {len(index)} entries -> {out_index}")


if __name__ == "__main__":
    main()
