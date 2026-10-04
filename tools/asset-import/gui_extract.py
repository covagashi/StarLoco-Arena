#!/usr/bin/env python3
"""Extract the retail GUI layer (gui.jar + i18n.jar) into godot/assets/gui/.

Layout mirrors the jar so theme XML `path="images/foo.tga"` and dialog
includes resolve with the same relative lookups the retail client performs:

    assets/gui/
      xml/            all *.xml (theme/, dialogs/, components/, templates/)
      images/         *.tga -> .png (same relative path, extension swapped)
      fonts/          *.TTF as-is, *.fnt/*.tab raw (bitmap-metric variants)
      cursors/        *.png cursors as-is
      i18n_<lang>.json   i18n/texts_<lang>.properties -> JSON string table
      index.json      {images: n, xmls: n, fonts: [..], langs: [..]}

DDS skins (a handful of compressed textures) are converted too — PIL reads
them. .aps/.xps theme particles are copied raw for the xps layer.
"""
import json, os, sys, zipfile
from PIL import Image

KEEP_RAW = (".TTF", ".fnt", ".tab", ".png", ".aps", ".xps", ".MF")
CONVERT  = (".tga", ".dds", ".DDS", ".TGA")


def _dest(rel: str, out: str) -> str:
    """Jar path -> extracted path. gui/x.tga -> images/x.png, etc."""
    parts = rel.split("/")
    assert parts[0] == "gui", rel
    rel2 = "/".join(parts[1:])
    stem, ext = os.path.splitext(rel2)
    if ext in CONVERT:
        return os.path.join(out, "images", stem + ".png")
    if rel2.startswith("theme/fonts/"):
        return os.path.join(out, "fonts", rel2[len("theme/fonts/"):])
    if rel2.startswith("theme/cursors/"):
        return os.path.join(out, "cursors", rel2[len("theme/cursors/"):])
    if ext == ".xml":
        return os.path.join(out, "xml", rel2)
    return os.path.join(out, "misc", rel2)


def _unescape(s: str) -> str:
    """Java .properties escapes: \\uXXXX \\n \\t \\r \\\\ — nothing else."""
    out, i = [], 0
    while i < len(s):
        if s[i] == "\\" and i + 1 < len(s):
            c = s[i + 1]
            if c == "u" and i + 5 < len(s) + 1:
                try:
                    out.append(chr(int(s[i + 2:i + 6], 16)))
                    i += 6
                    continue
                except ValueError:
                    pass
            out.append({"n": "\n", "t": "\t", "r": "\r",
                        "\\": "\\", "'": "'", '"': '"',
                        " ": " ", "=": "=", ":": ":"}.get(c, "\\" + c))
            i += 2
        else:
            out.append(s[i])
            i += 1
    return "".join(out)


def _props(src: bytes) -> dict:
    """Minimal .properties reader — retail files are latin-1, \\uXXXX escapes."""
    out = {}
    line = ""
    for raw in src.decode("latin-1").splitlines():
        s = raw.rstrip("\r")
        if not s or s[0] in "#!":
            continue
        line = line[:-1] + s.lstrip() if line.endswith("\\") else s
        if not s.endswith("\\"):
            if "=" in line or ":" in line:
                k, _, v = line.partition("=" if "=" in line else ":")
                out[k.strip()] = _unescape(v.strip())
            line = ""
    return out


def main(jar: str, i18n: str, out: str) -> None:
    n_img = n_xml = n_raw = n_skip = 0
    with zipfile.ZipFile(jar) as z:
        for name in z.namelist():
            if name.endswith("/") or name.startswith("META-INF"):
                continue
            ext = os.path.splitext(name)[1]
            if ext in (".anm",):
                n_skip += 1          # skeletal anms handled by anm_render.py
                continue
            dest = _dest(name, out)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            data = z.read(name)
            if ext in CONVERT:
                try:
                    Image.open(__import__("io").BytesIO(data)).save(dest)
                except Exception as e:
                    print("  ! convert failed %s: %s" % (name, e))
                    n_skip += 1
                    continue
                n_img += 1
            elif ext == ".xml":
                open(dest, "wb").write(data)
                n_xml += 1
            elif ext in KEEP_RAW or ext == ".png":
                open(dest, "wb").write(data)
                n_raw += 1
            else:
                n_skip += 1

    langs = []
    if os.path.exists(i18n):
        with zipfile.ZipFile(i18n) as z:
            for name in z.namelist():
                if not name.endswith(".properties"):
                    continue
                lang = name.split("_")[-1].split(".")[0]
                tbl = _props(z.read(name))
                p = os.path.join(out, "i18n_%s.json" % lang)
                os.makedirs(os.path.dirname(p), exist_ok=True)
                json.dump(tbl, open(p, "w"), ensure_ascii=False,
                          indent=0, sort_keys=True)
                langs.append((lang, len(tbl)))

    idx = {"images": n_img, "xmls": n_xml, "raw": n_raw,
           "skipped": n_skip, "langs": {l: c for l, c in langs}}
    json.dump(idx, open(os.path.join(out, "index.json"), "w"), indent=1)
    print("images %d | xml %d | raw %d | skipped %d | langs %s"
          % (n_img, n_xml, n_raw, n_skip, idx["langs"]))


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit("usage: gui_extract.py <gui.jar> <i18n.jar> <out_dir>")
    main(sys.argv[1], sys.argv[2], sys.argv[3])
