#!/usr/bin/env python3
"""S35c: review sheets for the equipment pieces (art/equipment), as screen-
sized pages (no long strips).

    python3 tools/art/equip_sheet.py figures <slot> <out.png> [--table=fighter|coach]
        [--dirs=SE,E] [--only=12,34] [anim_sheet args, e.g. --zoom=2.6 --focus=0.78]
    python3 tools/art/equip_sheet.py pieces <out.png> <piece> [<piece> ...]

figures: every card of the table whose piece is a <slot>_ one, worn by a
different figure (coach_7000 / coach_7001 for the coach table), one tile per
card with its views side by side and "<card> <piece> (<figure>)" under them,
4 tiles a row, 3 rows a page (<out>-1.png, -2.png … when it takes more).
pieces: the kiln previews (out/_preview/<piece>.png), 6 a page.
Run from godot/, after building the pieces (tools/art/build.py equipment).
Needs xvfb-run and Godot (GODOT or PATH) for figures, Pillow for both.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

FIGHTERS = ["feca_m", "osamodas_f", "anutrof_m", "sram_f", "xelor_m", "zurcarak_f", "aniripsa_m", "yopuka_f",
            "ocra_m", "sadida_f", "sacrogrito_m", "pandawa_f", "feca_f", "osamodas_m", "sram_m", "zurcarak_m"]
COACHES = ["coach_7000", "coach_7001"]
FONT = "/usr/share/fonts/google-noto/NotoSans-Regular.ttf"


def pages(tiles, out, cols, rows):
    """Save tiles as pages of cols × rows; returns the files written."""
    tw, th = tiles[0].size
    per = cols * rows
    files = []
    for p in range(0, len(tiles), per):
        page = tiles[p:p + per]
        r = (len(page) + cols - 1) // cols
        m = Image.new("RGB", (tw * min(cols, len(page)), th * r), (60, 60, 60))
        for i, t in enumerate(page):
            m.paste(t, ((i % cols) * tw, (i // cols) * th))
        name = out if len(tiles) <= per else out.replace(".png", f"-{p // per + 1}.png")
        m.save(name)
        files.append(name)
    return files


def figures(slot, out, opts, extra):
    table = opts.get("table", "fighter")
    dirs = opts.get("dirs", "SE,E").split(",")
    with open("art/equipment/pieces.json") as f:
        pieces = json.load(f)[table]
    items = sorted((int(k), v) for k, v in pieces.items() if v.startswith(slot + "_"))
    if opts.get("only"):
        only = set(opts["only"].split(","))
        items = [it for it in items if str(it[0]) in only]
    if not items:
        sys.exit(f"no {slot}_ pieces in the {table} table")
    figs = [f for f in (COACHES if table == "coach" else FIGHTERS) if os.path.exists(f"art/characters/out/{f}.glb")]
    godot = os.environ.get("GODOT") or shutil.which("godot")
    font = ImageFont.truetype(FONT, 18) if os.path.exists(FONT) else ImageFont.load_default()
    tiles = []
    with tempfile.TemporaryDirectory() as tmp:
        for n, (cid, piece) in enumerate(items):
            fig = figs[n % len(figs)]
            d = os.path.join(tmp, piece)
            subprocess.run(["xvfb-run", "-a", "-s", "-screen 0 1280x720x24", godot, "--path", ".",
                            "-s", "tools/art/anim_sheet.gd", "--", f"--model=art/characters/out/{fig}.glb",
                            f"--out={d}", "--frames=1", "--anims=idle_loop", f"--dirs={','.join(dirs)}",
                            f"--pieces={'weapon' if slot in ('staff', 'banner') else slot}:{piece}", *extra],
                           capture_output=True, check=False)
            ims = [Image.open(f"{d}/idle_loop/{x}_00.png").convert("RGB") for x in dirs]
            w, h = ims[0].size
            t = Image.new("RGB", (w * len(ims), h + 28), (60, 60, 60))
            for i, im in enumerate(ims):
                t.paste(im, (i * w, 0))
            ImageDraw.Draw(t).text((6, h + 4), f"{cid} {piece[len(slot) + 1:]} ({fig})", fill=(235, 235, 235), font=font)
            tiles.append(t)
    return pages(tiles, out, 4, 3)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = [a for a in sys.argv[1:] if a.startswith("--")]
    opts, extra = {}, []
    for f in flags:
        k, _, v = f[2:].partition("=")
        if k in ("table", "dirs", "only"):
            opts[k] = v
        else:
            extra.append(f)
    if len(args) >= 3 and args[0] == "figures":
        files = figures(args[1], args[2], opts, extra)
    elif len(args) >= 3 and args[0] == "pieces":
        files = pages([Image.open(f"art/equipment/out/_preview/{p}.png").convert("RGB") for p in args[2:]], args[1], 3, 2)
    else:
        sys.exit(__doc__)
    print("\n".join(files))


if __name__ == "__main__":
    main()
