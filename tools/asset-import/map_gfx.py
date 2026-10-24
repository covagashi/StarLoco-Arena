#!/usr/bin/env python3
"""Export a map's painted gfx layer to Godot-consumable JSON+PNG.

Chain (all verified against client/decompiled):
  maps/gfx/<world>.jar chunk "<cx>_<cy>"  (kC.load, acf little-endian)
    header: [i32 ER][i32 ES][i16 ET][i32 EU][i32 EV][i16 EW]
            [i32 baseX][i32 baseY][u16 regionCount]
    region: [u8 dx0][u8 dx1][u8 dy0][u8 dy1]   cell range = base+delta, x end exclusive
    cell:   [u8 elemCount]
    elem:   [u8 type][i16 cto][i8 aba][i8 cts][i32 bpm][i8 coF][i32 aoq]
            [u8 ctt][i32 elemId][colorBytes by type]
      color bytes (ScreenElement.kw):
        g = (3 if t&2 else 0) + (1 if t&8 else 0); g *= 2 if t&0x10
        tail = g + (3 if t&1 else 0) + (3 if t&4 else 0)

  maps/data.jar!/elements.lib  (UF.load — LITTLE endian)
    [i32 count]{zl_1 record}
    zl_1: [i32 id][i16 origX][i16 origY][i16 w][i16 h][i32 gfxId][u8 flags]
          [u8 visH][u8 cdY][u8 cdZ][afd_0 anim][u8 cec]
    afd_0: [u8 nFrames; 0=null][i32 totalDur][i16 atlasW][i16 atlasH]
           [i16 frameW][i16 frameH][i16 dur*n][i16 uvs*2n]  (uv = pixel coords)

  elementId -> zl_1.gfxId -> contents/gfx.jar!/gfx/<gfxId>.tgam

  screen pos (anx_0/kC): sx = (x - y) * 43 - origX
                         sy_godot = (x + y) * 21.5 - (cto - aba) * 10 - origY
  draw order key (kC): zkey = ((y+131071) << 32) | ((x+131071) << 14) | intra
                        where intra = int(cts * 16) + 8191 (cts is a byte)

  colour (S04/S07, client/analysis/MAP-LIGHT.md): each sprite carries "c",
  the multiplier 2·tint × light the retail draws it with — the element's 0x02
  tint and its maps/light/<world>.jar record — when it is not neutral.

Usage: map_gfx.py <world_id> <out_dir>
  writes <out_dir>/<world>.json + <out_dir>/tex/<gfxId>.png atlases used.
"""
import json
import os
import re
import struct
import sys
import zipfile

ROOT = os.path.dirname(os.path.abspath(__file__)) + "/../../client/compiled/game/contents"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from anm_render import load_tgam, write_png  # noqa: E402


def parse_elements_lib(path):
    """elements.lib -> {elemId: {ox,oy,w,h,gfx,frames:[{u,v,dur}],fw,fh}}"""
    z = zipfile.ZipFile(path)
    d = z.read("elements.lib")
    count = struct.unpack_from("<i", d, 0)[0]
    off = 4
    lib = {}
    for _ in range(count):
        eid, ox, oy, w, h, gfx = struct.unpack_from("<ihhhhi", d, off)
        flags = d[off + 16]
        vis_h, cdY, cdZ = d[off + 17], d[off + 18], d[off + 19]
        off += 20
        nf = d[off]; off += 1
        elem = {"ox": ox, "oy": oy, "w": w, "h": h, "gfx": gfx,
                "vis_h": vis_h, "flags": flags}
        if nf:
            dur, fw, fh, aw, ah = struct.unpack_from("<ihhhh", d, off)
            off += 12
            durs = struct.unpack_from("<%dh" % nf, d, off); off += 2 * nf
            uvs = struct.unpack_from("<%dh" % (2 * nf), d, off); off += 4 * nf
            elem["frames"] = [{"u": uvs[2 * i], "v": uvs[2 * i + 1],
                               "dur": durs[i]} for i in range(nf)]
            elem["fw"], elem["fh"], elem["aw"], elem["ah"] = fw, fh, aw, ah
        # cea == null → zl_1.d(): the whole texture, stretched to w×h
        lib[eid] = elem
        cec = d[off]; off += 1
    return lib


def parse_gfx_jar(path):
    """-> [{'x','y','z','elemId','zkey'}] with absolute cell coords."""
    z = zipfile.ZipFile(path)
    out = []
    for name in z.namelist():
        if "_" not in name:
            continue
        d = z.read(name)
        (_er, _es, _et, _eu, _ev, _ew, bx, by, nreg) = \
            struct.unpack_from("<iihiihiiH", d, 0)
        off = 30
        for _ in range(nreg):
            x0, x1, y0, y1 = struct.unpack_from("<BBBB", d, off); off += 4
            x0 += bx; x1 += bx; y0 += by; y1 += by
            for x in range(x0, x1):
                for y in range(y0, y1):
                    n = d[off]; off += 1
                    for _e in range(n):
                        etype = d[off]; off += 1
                        cto, aba, cts, _bpm, cof, _aoq, _ctt, eid = \
                            struct.unpack_from("<hbbib iBi".replace(" ", ""),
                                               d, off)
                        off += 18
                        # colour bytes, in ScreenElement.a order: 0x01, then
                        # the 0x02 tint (signed byte/255 + 0.5, 0.5 neutral),
                        # 0x04, 0x08 alpha, then the 0x10 gradient pair
                        tail = off
                        if etype & 1:
                            tail += 3
                        tint = None
                        if etype & 2:
                            tint = [b / 255.0 + 0.5 for b in
                                    struct.unpack_from("<bbb", d, tail)]
                        g = (3 if etype & 2 else 0) + (1 if etype & 8 else 0)
                        if etype & 0x10:
                            g *= 2
                        off += g + (3 if etype & 1 else 0) + \
                            (3 if etype & 4 else 0)
                        intra = (cts * 16 + 8191) & 0x3FFF
                        zkey = ((y + 131071) << 32) | ((x + 131071) << 14) | intra
                        out.append({"x": x, "y": y, "z": cto - aba,
                                    "e": eid, "zkey": zkey, "layer": cof,
                                    "tint": tint})
    return out


SENTINEL = 0xFF808080


def parse_light_jar(path):
    """maps/light/<world>.jar -> {(x, y, layer): (r, g, b) multiplier}.

    client/analysis/MAP-LIGHT.md §1: per record base' = base/255*2, day' =
    day/255; at the default light factor f = 1 the colour is base' * day' * 2,
    clamped to 0..2. Night terms are additive at f < 0 only, never in a fight.
    """
    out = {}
    if not os.path.exists(path):
        return out
    z = zipfile.ZipFile(path)
    for name in z.namelist():
        if not re.fullmatch(r"-?\d+_-?\d+", name):
            continue   # META-INF/ and the manifest ride in the jar too
        d = z.read(name)
        if len(d) < 6:
            continue
        _cx, _cy, n = struct.unpack_from("<hhH", d, 0)
        off = 6
        for _ in range(n):
            key, _flag, base, day, _night = struct.unpack_from("<qBIII", d, off)
            off += 21
            x = ((key >> 48) & 0xFFFF) - 32768
            y = ((key >> 32) & 0xFFFF) - 32768
            layer = key & 0xFFFFFFFF
            b = [((base >> s) & 0xFF) / 255.0 * 2 for s in (0, 8, 16)]
            if day != SENTINEL:
                dy = [((day >> s) & 0xFF) / 255.0 for s in (0, 8, 16)]
                c = [min(max(b[i] * dy[i] * 2, 0.0), 2.0) for i in range(3)]
            else:
                c = b
            out[(x, y, layer)] = c
    return out


def sprite_colour(e, light):
    """The multiplier the retail draws this element with: texel x 2·tint x
    light (bu_0 sets GL_COMBINE modulate with GL_RGB_SCALE 2; GeometryMesh
    multiplies the vertex tint by the material = light colour). None when it
    is within 1 % of neutral."""
    tint = e["tint"] or [0.5, 0.5, 0.5]
    lc = light.get((e["x"], e["y"], e["layer"]), [1.0, 1.0, 1.0])
    m = [round(2 * tint[i] * lc[i], 3) for i in range(3)]
    if all(abs(v - 1.0) < 0.01 for v in m):
        return None
    return m


def export_world(world_id, out_dir):
    lib = parse_elements_lib(f"{ROOT}/maps/data.jar")
    gjar = f"{ROOT}/maps/gfx/{world_id}.jar"
    if not os.path.exists(gjar):
        print(f"no gfx jar for world {world_id}")
        return
    elems = parse_gfx_jar(gjar)
    light = parse_light_jar(f"{ROOT}/maps/light/{world_id}.jar")
    used_gfx = {}
    sprites = []
    for e in elems:
        d = lib.get(e["e"])
        if d is None:
            continue
        gfx = d["gfx"]
        used_gfx[gfx] = True
        frames = d.get("frames")
        uv = [frames[0]["u"], frames[0]["v"], d["fw"], d["fh"]] \
            if frames else None   # None → whole texture (zl_1.d)
        sprite = {
            "tex": gfx,
            "sx": (e["x"] - e["y"]) * 43.0 - d["ox"],
            "sy": (e["x"] + e["y"]) * 21.5 - e["z"] * 10.0 - d["oy"],
            "w": d["w"], "h": d["h"],
            "uv": uv,
            "z": e["zkey"],
        }
        c = sprite_colour(e, light)
        if c is not None:
            sprite["c"] = c   # retail colour multiplier (map_gfx.gd modulate)
        sprites.append(sprite)
    os.makedirs(f"{out_dir}/tex", exist_ok=True)
    gz = zipfile.ZipFile(f"{ROOT}/gfx.jar")
    tex_meta = {}
    for gfx in used_gfx:
        try:
            w, h, rgba = load_tgam(gz.read(f"gfx/{gfx}.tgam"))
        except KeyError:
            continue
        write_png(f"{out_dir}/tex/{gfx}.png", w, h, rgba)
        tex_meta[gfx] = {"w": w, "h": h}
    meta = {"world": world_id, "tex": tex_meta, "sprites": sprites}
    with open(f"{out_dir}/{world_id}.json", "w") as f:
        json.dump(meta, f, separators=(",", ":"))
    print(f"world {world_id}: {len(sprites)} sprites, "
          f"{len(tex_meta)} atlases -> {out_dir}/{world_id}.json")


if __name__ == "__main__":
    export_world(int(sys.argv[1]), sys.argv[2])
