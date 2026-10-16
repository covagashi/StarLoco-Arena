"""Contact sheet for the 1-bit art passes (sprints/S04).

Tiles PNG renders into one grid image, each with its label on a black bar, so
several variants can be compared on a phone screen at a glance.

    python3 tools/contact_sheet.py OUT.png [--cols=2] [--width=640] \
        [--crop=x,y,w,h] LABEL=path.png [LABEL=path.png ...]

Each tile is scaled to --width with nearest-neighbour. For 1-bit renders
prefer --crop: it cuts the same window out of every image at 1:1 (and then
--width is ignored). Scaling a dither pattern down drops whole rows of dots,
so darkness reads as solid black and fine detail disappears.
"""

import sys

from PIL import Image, ImageDraw, ImageFont

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
BAR = 34


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    out, cols, width, crop, tiles = argv[0], 2, 640, None, []
    for a in argv[1:]:
        if a.startswith("--cols="):
            cols = int(a.split("=", 1)[1])
        elif a.startswith("--width="):
            width = int(a.split("=", 1)[1])
        elif a.startswith("--crop="):
            x, y, w, h = (int(v) for v in a.split("=", 1)[1].split(","))
            crop = (x, y, x + w, y + h)
        elif "=" in a:
            label, path = a.split("=", 1)
            tiles.append((label, path))
        else:
            print(f"bad argument: {a}", file=sys.stderr)
            return 2
    if not tiles:
        print("no tiles given", file=sys.stderr)
        return 2

    imgs = []
    for label, path in tiles:
        im = Image.open(path).convert("RGB")
        if crop is not None:
            imgs.append((label, im.crop(crop)))
            continue
        h = round(im.height * width / im.width)
        imgs.append((label, im.resize((width, h), Image.NEAREST)))
    width = imgs[0][1].width
    tile_h = max(im.height for _, im in imgs) + BAR
    rows = (len(imgs) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * width, rows * tile_h), "black")
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype(FONT, 20)
    except OSError:
        font = ImageFont.load_default()
    for i, (label, im) in enumerate(imgs):
        x, y = (i % cols) * width, (i // cols) * tile_h
        draw.text((x + 10, y + 6), label, fill="white", font=font)
        sheet.paste(im, (x, y + BAR))
    sheet.save(out)
    print(f"[sheet] {out} {sheet.width}x{sheet.height}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
