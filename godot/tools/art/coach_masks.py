#!/usr/bin/env python3
"""S35: skin and hair masks for the Meshy coaches (coach_7000 / coach_7001).

The coaches come from Meshy with one baked texture, so the materials can't
carry the skin* / hair* tint channels the built fighters have (toon.gd).
This paints them instead: every triangle votes by the colour of its texels
(skin is the peach anywhere; hair the white above the neck, grown over the
mesh through white triangles to a ponytail), each texel keeps its own
colour test inside its triangle's class, and the result is saved
beside the GLB as <name>_mask.png (R = skin, G = hair) with <name>_mask.json (each
mask's mean brightness). toon.gdshader
recolours those texels to the picked tint, keeping the texture's shading.

    python3 tools/art/coach_masks.py [--sheet=out.png] coach_7000 coach_7001
"""
import json
import struct
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parents[2] / "art/characters/out"
## Above this share of the figure's height a pale, unsaturated texel is hair
## (the neck of both coaches sits at ~0.82; the white armour starts below).
HAIR_FROM = 0.84
## Above this share the face: a pale texel there may be the white of an eye.
FACE_FROM = 0.8
## The face band where the eyes are: a triangle there with this share of
## iris texels (strongly coloured, not skin: the amber and the blue irises;
## dark texels alone are not enough, the hair's ink lines are dark too) is
## an eye, and neither it nor its neighbours (the white around it) can be
## hair.
EYE_BAND = (0.74, 0.93)
EYE_SHARE = 0.04


def read_glb(path):
    b = path.read_bytes()
    n = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + n])
    off = 20 + n
    size = struct.unpack("<I", b[off:off + 4])[0]
    blob = b[off + 8:off + 8 + size]

    def acc(i):
        a = j["accessors"][i]
        v = j["bufferViews"][a["bufferView"]]
        comps = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
        dt = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}[a["componentType"]]
        start = v.get("byteOffset", 0) + a.get("byteOffset", 0)
        stride = v.get("byteStride", 0)
        item = np.dtype(dt).itemsize * comps
        if stride and stride != item:
            raw = np.frombuffer(blob, np.uint8, a["count"] * stride, start).reshape(-1, stride)[:, :item]
            return np.frombuffer(raw.tobytes(), dt).reshape(a["count"], comps)
        return np.frombuffer(blob, dt, a["count"] * comps, start).reshape(a["count"], comps)

    prim = j["meshes"][0]["primitives"][0]
    pos = acc(prim["attributes"]["POSITION"])
    uv = acc(prim["attributes"]["TEXCOORD_0"])
    idx = acc(prim["indices"]).reshape(-1, 3)
    # the albedo: the base colour's image (S47: a newer Meshy export puts
    # its normal map first)
    mat = j["materials"][prim.get("material", 0)]
    tex_i = mat.get("pbrMetallicRoughness", {}).get("baseColorTexture", {}).get("index", 0)
    im = j["images"][j["textures"][tex_i]["source"]]
    v = j["bufferViews"][im["bufferView"]]
    data = blob[v.get("byteOffset", 0):v.get("byteOffset", 0) + v["byteLength"]]
    from io import BytesIO
    tex = Image.open(BytesIO(data)).convert("RGB")
    return pos, uv, idx, tex


def tri_map(uv, idx, size):
    """Per texel, the index + 1 of the triangle on it (0: none)."""
    t = Image.new("I", size, 0)
    d = ImageDraw.Draw(t)
    w, h = size
    for i, f in enumerate(idx):
        d.polygon([(float(uv[k, 0]) * w, float(uv[k, 1]) * h) for k in f], fill=i + 1)
    return np.asarray(t, np.int64)


def neighbours(pos, idx):
    """Triangles sharing a corner, welded by position (UV seams split them)."""
    key = {}
    weld = np.empty(len(pos), np.int64)
    for i, p in enumerate(np.round(pos, 4).tolist()):
        weld[i] = key.setdefault(tuple(p), len(key))
    by_vert = {}
    for i, f in enumerate(idx):
        for v in weld[f]:
            by_vert.setdefault(int(v), []).append(i)
    return [sorted({n for v in weld[f] for n in by_vert[int(v)]} - {i}) for i, f in enumerate(idx)]


def masks(name):
    pos, uv, idx, tex = read_glb(OUT / f"{name}.glb")
    rgb = np.asarray(tex, np.float32) / 255.0
    tri = tri_map(uv, idx, tex.size)
    covered = tri > 0
    y = pos[:, 1]
    share = (y[idx].mean(axis=1) - y.min()) / (y.max() - y.min())   # per triangle
    tshare = np.where(covered, share[np.maximum(tri - 1, 0)], 0)
    mx = rgb.max(axis=2)
    mn = rgb.min(axis=2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    # skin: any warm hue (r > g >= b), from the cream of a baked highlight to
    # the peach, not dark (eyes, leather). The white armour and the grey hair
    # are neutral or cool, so the hue keeps them out. (Until 2026-11-15 the
    # cream and the pale peach were left out: a dark skin showed white
    # blotches wherever Meshy baked a highlight.)
    warm = covered & (r > g) & (g >= b) & (sat > 0.07) & (sat < 0.62) & (mx > 0.42) & ((r - b) > 0.06)
    warm &= ~((mx < 0.7) & (sat > 0.45))   # the leather and the belt: darker, browner
    pale = covered & (sat < 0.16) & (mx > 0.45)
    # each triangle votes by its texels: a baked highlight inside a skin
    # triangle is skin, a strap or an eye inside it keeps its colour
    n = len(idx) + 1
    cnt = np.bincount(tri.ravel(), minlength=n).astype(np.float32)
    t_warm = np.bincount(tri.ravel(), warm.ravel(), n) / np.maximum(cnt, 1)
    t_pale = np.bincount(tri.ravel(), pale.ravel(), n) / np.maximum(cnt, 1)
    # hair: pale triangles from the top of the head, grown over the mesh
    # through pale triangles (a ponytail, the nape) — never through skin
    near = neighbours(pos, idx)
    inky = covered & (sat > 0.5) & (mx > 0.35) & ~warm
    t_inky = np.bincount(tri.ravel(), inky.ravel(), n) / np.maximum(cnt, 1)
    eye_t = (share > EYE_BAND[0]) & (share < EYE_BAND[1]) & (t_inky[1:] >= EYE_SHARE) & (t_warm[1:] < 0.5)
    # the white of the eye: very bright and neutral (a grey lock of hair
    # beside the eye is darker and stays hair)
    bright = covered & (mx > 0.85) & (sat < 0.12)
    t_bright = np.bincount(tri.ravel(), bright.ravel(), n) / np.maximum(cnt, 1)
    no_hair = eye_t.copy()
    for i in np.nonzero(eye_t)[0]:
        for j in near[i]:
            if share[j] < EYE_BAND[1] and t_bright[j + 1] >= 0.3:
                no_hair[j] = True
    hair_t = np.zeros(len(idx), bool)
    # S47 (owner: "al cambiar el color del pelo cambia el de los ojos"):
    # the white of an eye was a pale triangle above the neck, so it seeded
    # hair and took the hair colour; the eyes and their rim never do now
    todo = [i for i in range(len(idx)) if share[i] > HAIR_FROM and t_pale[i + 1] >= 0.5 and not no_hair[i]]
    for i in todo:
        hair_t[i] = True
    while todo:
        i = todo.pop()
        for j in near[i]:
            if not hair_t[j] and not no_hair[j] and t_pale[j + 1] >= 0.5 and t_warm[j + 1] < 0.3:
                hair_t[j] = True
                todo.append(j)
    skin_t = (t_warm[1:] >= 0.5) & ~hair_t
    # S53 (A4, owner: "pelo junto a la oreja"): Meshy shades the lowest
    # lock tips warm, so they voted skin and took the skin colour (cream
    # specks in brown hair). Skin hanging in the hair is hair: a skin patch
    # whose border is mostly hair, and, from the neck up, a skin triangle
    # with most of its neighbours hair (again, as the hair closes in); the
    # eyes and their rim never (S47); so is, from the neck up, a triangle
    # of neither (a mixed lock tip left white)
    flipped = 0
    seen = np.zeros(len(idx), bool)
    for i in np.nonzero(skin_t)[0]:
        if seen[i]:
            continue
        comp, st = [], [i]
        seen[i] = True
        while st:
            k = st.pop()
            comp.append(k)
            for j in near[k]:
                if skin_t[j] and not seen[j]:
                    seen[j] = True
                    st.append(j)
        border = {j for k in comp for j in near[k] if not skin_t[j]}
        if border and sum(hair_t[j] for j in border) >= 0.6 * len(border) and not no_hair[comp].any():
            skin_t[comp] = False
            hair_t[comp] = True
            flipped += len(comp)
    for _ in range(4):
        grow = [i for i in np.nonzero(~hair_t & (share > EYE_BAND[0]) & ~no_hair)[0]
                if near[i] and sum(hair_t[j] for j in near[i]) * 3 >= 2 * len(near[i])]
        if not grow:
            break
        skin_t[grow] = False
        hair_t[grow] = True
        flipped += len(grow)
    T_hair = np.concatenate([[False], hair_t])[tri]
    T_skin = np.concatenate([[False], skin_t])[tri]
    # (and inside a hair triangle a warm texel is hair too, not skin)
    hair = T_hair & (pale | (sat < 0.25) | warm)
    # below the face a pale texel in a skin triangle is a highlight; in the
    # face it may be the white of an eye
    skin = (warm | (T_skin & pale & (tshare < FACE_FROM))) & ~hair
    skin &= ~(~T_skin & ~warm)
    m = np.zeros(rgb.shape, np.uint8)
    m[..., 0] = skin * 255
    m[..., 1] = hair * 255
    # close the specks left by the colour test, never past the covered texels
    img = Image.fromarray(m).filter(ImageFilter.MedianFilter(3))
    img = img.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5))
    m = np.asarray(img).copy()
    m[~covered] = 0
    m[..., 0][m[..., 1] > 127] = 0
    # bleed the masks a few texels past each island: the texture is sampled
    # with filtering, and a zero right at the edge left a fine untinted seam
    grown = np.asarray(Image.fromarray(m).filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MaxFilter(5)))
    m[~covered] = grown[~covered]
    img = Image.fromarray(m)
    img.save(OUT / f"{name}_mask.png")
    # the brightness toon.gdshader divides by, in linear light as the shader
    # samples the texture: a high percentile, not the mean, so the lit side
    # stays at the picked colour instead of washing out to white
    lin = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    lum = lin @ np.array([0.299, 0.587, 0.114], np.float32)
    refs = {"skin_ref": float(np.percentile(lum[(m[..., 0] > 127) & covered], 80)),
            "hair_ref": float(np.percentile(lum[(m[..., 1] > 127) & covered], 80))}
    (OUT / f"{name}_mask.json").write_text(json.dumps(refs) + "\n")
    print(f"{name}: skin {int((m[..., 0] > 127).sum())} px, hair {int((m[..., 1] > 127).sum())} px "
          f"({int(hair_t.sum())} hair triangles, {flipped} of them out of the skin, "
          f"{int(eye_t.sum())} eye triangles kept out), {refs}")
    return tex, img


def main():
    sheet = None
    names = []
    for a in sys.argv[1:]:
        if a.startswith("--sheet="):
            sheet = a.split("=", 1)[1]
        else:
            names.append(a)
    names = names or ["coach_7000", "coach_7001"]
    tiles = []
    for n in names:
        tex, m = masks(n)
        over = Image.composite(Image.new("RGB", tex.size, (255, 0, 255)), tex, m.getchannel("R").point(lambda v: 160 if v else 0))
        over = Image.composite(Image.new("RGB", tex.size, (0, 255, 255)), over, m.getchannel("G").point(lambda v: 160 if v else 0))
        tiles += [tex.resize((512, 512)), over.resize((512, 512))]
    if sheet:
        s = Image.new("RGB", (1024, 512 * len(names)))
        for i, t in enumerate(tiles):
            s.paste(t, ((i % 2) * 512, (i // 2) * 512))
        s.save(sheet)


if __name__ == "__main__":
    main()
