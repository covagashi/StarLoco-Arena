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
_LEGACY_XPS = b"XPS"  # particles/81.xps — zlib payload, not 0x5001 wire (sole sfx.jar outlier)


def _unwrap_xps(data: bytes) -> bytes | None:
    """Return particle bytes for parse_xps, or None if legacy XPS wrapper."""
    if len(data) >= 2 and data[0] == 0x01 and data[1] == 0x50:
        return data
    if data[:3] == _LEGACY_XPS:
        return None
    return data

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
    out: dict = {"type": tag, "name": name}
    # lo_0.j (DirectionFollower) reads no bits after the tag byte.
    if tag == 6:
        leveled = False
        out["leveled"] = leveled
    else:
        leveled = r.bool_bit()
        out["leveled"] = leveled

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
        out["skipped"] = True

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
            # auw_0.t: unknown condition tag — tag byte only (matches retail loader).
            conds.append({"type": ct, "name": cn, "skipped": True})
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


# bk_0.i: f2..f23 (22 leveled floats) — 2.70 has no trailing rotationX/Y/Z.
_BITMAP_FLOATS = [
    "hotX", "hotY", "scaleX", "scaleY", "scaleRandomX", "scaleRandomY",
    "rotation", "rotationRandom",
    "red", "green", "blue", "alpha",
    "redRandom", "greenRandom", "blueRandom", "alphaRandom",
    "textureTop", "textureLeft", "textureBottom", "textureRight",
    "halfWidth", "halfHeight",
]

_SEQUENCE_FLOATS = [
    "hotX", "hotY", "scaleX", "scaleY", "scaleRandomX", "scaleRandomY",
    "rotation", "rotationRandom",
    "red", "green", "blue", "alpha",
    "redRandom", "greenRandom", "blueRandom", "alphaRandom",
    "halfWidth", "halfHeight",
]


def _read_particle_model(r: Reader, t: float) -> dict | None:
    tag = r.u8()
    if tag not in (1, 2):
        return None
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
        return m
    raise ValueError(f"unreachable model tag")


def _read_light(r: Reader, t: float) -> dict | None:
    if r.u8() != 2:
        return None
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
    if tag != 1:
        # cZ.a: unknown tags consume only the tag byte.
        return None
    leveled = r.bool_bit()
    geocentric = r.bool_bit()
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
        m = _read_particle_model(r, t)
        if m is not None:
            em["models"].append(m)
    aff, key = _read_affectors(r, t)
    em["affectors"] = aff
    em["keyframedAffectors"] = key
    nl = r.u8()
    for _ in range(nl):
        light = _read_light(r, t)
        if light is None:
            continue
        laff, lkey = _read_affectors(r, t)
        light["affectors"] = laff
        light["keyframedAffectors"] = lkey
        em["lights"].append(light)
    ns = r.u8()
    for _ in range(ns):
        em["subEmitters"].append(_read_emitter(r, t))
    return em


def _read_system_block(r: Reader, t: float) -> dict:
    """alo_2 system block; dst==0 non-geocentric omits the i64 texture field."""
    leveled = r.bool_bit()
    geocentric = r.bool_bit()
    behind_mobile = r.bool_bit()
    src_blend = r.i32()
    dst_blend = r.i32()
    # When dst blend is 0 the on-disk header drops the i64 texture id (see 10000.xps).
    compact = dst_blend == 0
    if compact:
        texture_id = 0
        duration_ms = r.leveled_u16(leveled, t)
        render_radius = r.u8()
    else:
        texture_id = r.i64()
        duration_ms = r.leveled_u16(leveled, t)
        render_radius = r.u8()
    return {
        "leveled": leveled,
        "geocentric": geocentric,
        "behindMobile": behind_mobile,
        "srcBlend": src_blend,
        "dstBlend": dst_blend,
        "textureId": texture_id,
        "durationMs": duration_ms,
        "renderRadius": render_radius,
        "compactHeader": compact,
    }


def parse_xps_header(data: bytes, level: int = LEVEL) -> dict:
    """System block only — enough for texture + duration + blend."""
    raw = _unwrap_xps(data)
    if raw is None:
        raise ValueError("legacy XPS wrapper")
    r = Reader(raw)
    if r.u16() != MAGIC:
        raise ValueError("bad magic")
    t = 0.0 if level <= 1 else min(level, 100) / 100.0
    blk = _read_system_block(r, t)
    blk.pop("compactHeader", None)
    return blk


def parse_xps(data: bytes, level: int = LEVEL) -> dict:
    raw = _unwrap_xps(data)
    if raw is None:
        raise ValueError("legacy XPS wrapper")
    r = Reader(raw)
    if r.u16() != MAGIC:
        raise ValueError("bad magic")
    t = 0.0 if level <= 1 else min(level, 100) / 100.0
    sysd = _read_system_block(r, t)
    sysd["emitters"] = []
    ne = r.u8()
    for _ in range(ne):
        em = _read_emitter(r, t)
        if em is not None:
            sysd["emitters"].append(em)
    # Retail loader stops after ne emitters; extra bytes are ignored (alo_2.close).
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
            except ValueError as e:
                if "legacy XPS" in str(e):
                    print(f"SKIP {xid}: legacy XPS wrapper")
                    continue
                print(f"FAIL {xid}: {e}")
                fail += 1
                continue
            except Exception as e:
                print(f"FAIL {xid}: {e}")
                fail += 1
                continue
            tid = int(doc["textureId"])
            if tid == 0 and doc.get("compactHeader"):
                tid = int(xid)
                doc["textureId"] = tid
            textures.add(tid)
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
