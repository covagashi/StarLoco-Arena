#!/usr/bin/env python3
"""Builds assets/ui/fonts/PippopSymbols.ttf and PippopSymbols2.ttf (S44): the arrows, triangles,
check, cross, dot and maths signs the interface draws as text and that our
three fonts lack. On a desktop the system's fonts fill them in; a browser
has none for the game, so without this they come out as boxes. UiStyle
gives every font these two as its fallbacks.

Cut from Noto Sans Math and Noto Sans Symbols 2 (SIL OFL 1.1, the Noto
Project Authors), so only these glyphs ship (a few KB):
    python3 -m pip install fonttools   (in a venv)
    python3 tools/fonts/make_symbols.py [noto dir]
The default noto dir is Fedora's /usr/share/fonts/google-noto.
"""
import os
import sys

from fontTools import subset
from fontTools.ttLib import TTFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONTS = os.path.join(HERE, "..", "..", "assets", "ui", "fonts")
# Noto file -> (our cut, the characters taken from it). Two files: fontTools
# can't merge these two, and a fallback list takes both anyway.
PICK = {
    "NotoSansMath-Regular.ttf": (os.path.join(FONTS, "PippopSymbols.ttf"), "←→↔∞≤≥▲▶▸▼◀◉●✓"),
    "NotoSansSymbols2-Regular.ttf": (os.path.join(FONTS, "PippopSymbols2.ttf"), "✕"),
}


def cut(path, chars, out):
    opts = subset.Options()
    opts.layout_features = []
    opts.name_IDs = [0, 1, 2, 3, 4, 5, 6]
    opts.notdef_outline = True
    font = TTFont(path)
    s = subset.Subsetter(opts)
    s.populate(text=chars)
    s.subset(font)
    if "MATH" in font:   # its constants mean nothing for a fallback
        del font["MATH"]
    font.save(out)


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "/usr/share/fonts/google-noto"
    bad = 0
    for name, (out, chars) in PICK.items():
        cut(os.path.join(src, name), chars, out)
        font = TTFont(out)
        for rec in font["name"].names:   # our name, so it is not mistaken for Noto
            if rec.nameID in (1, 4, 6):
                rec.string = os.path.basename(out)[:-4]
        font.save(out)
        missing = [c for c in chars if ord(c) not in font.getBestCmap()]
        bad += len(missing)
        print("%s: %d bytes%s" % (out, os.path.getsize(out), ", MISSING " + "".join(missing) if missing else ""))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
