#!/usr/bin/env python3
"""Regression test for the .anm/.tgam pipeline.

Requires the extracted retail client at client/compiled/game/ (git-ignored).
Skips cleanly when it is absent, mirroring the repo convention for local data.

  python3 tools/asset-import/test_anm.py
"""

import os
import sys
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from anm_dump import parse_anm          # noqa: E402
from anm_render import (FrameRenderer, PQ_IDENTITY,  # noqa: E402
                        load_anm_and_textures)

JAR = "client/compiled/game/contents/animations.jar"

# entry, action name (None = longest), frame, min quads, min nonzero-alpha px
RENDER_CASES = [
    ("animations/NPCs/2001.anm", "1_AnimHit", 0, 3, 2000),
    ("animations/NPCs/2001.anm", "1_AnimHit", 12, 3, 2000),
    ("animations/equipments/coachs/805.anm", "5_AnimStatique", 0, 9, 200),
]


def _alpha_px(rgba):
    return sum(1 for i in range(3, len(rgba), 4) if rgba[i] > 8)


def main():
    if not os.path.exists(JAR):
        print(f"[skip] {JAR} not present — extract the retail client first")
        return 0
    z = zipfile.ZipFile(JAR)

    # 1. whole-archive parse sweep
    entries = [n for n in z.namelist()
               if n.endswith(".anm") and not n.startswith("META")]
    bad = []
    for n in entries:
        try:
            parse_anm(z.read(n))
        except Exception as e:  # noqa: BLE001
            bad.append((n, str(e)))
    print(f"[parse] {len(entries) - len(bad)}/{len(entries)} anm parsed")
    for n, e in bad[:10]:
        print(f"  FAIL {n}: {e}")

    # 2. render checks on known assets
    fails = 0
    for entry, act_name, frame, min_quads, min_px in RENDER_CASES:
        anm, tex = load_anm_and_textures(z, entry)
        act = None
        for a in anm["actions"]:
            if act_name and act_name in a.get("name", ""):
                act = a
                break
        if act is None:
            act = max(anm["actions"], key=lambda a: a["logical_frames"])
        fr = FrameRenderer(anm, tex)
        fr.draw_action(act, frame, PQ_IDENTITY)
        out = fr.rasterize()
        tag = f"{entry} {act_name or act['fL']} f{frame}"
        if out is None or len(fr.quads) < min_quads:
            print(f"  FAIL {tag}: quads={len(fr.quads)} out={out is not None}")
            fails += 1
            continue
        W, H, rgba, off = out
        px = _alpha_px(rgba)
        ok = px >= min_px
        print(f"  {'ok' if ok else 'FAIL'} {tag}: "
              f"{W}x{H} quads={len(fr.quads)} alpha_px={px}")
        fails += 0 if ok else 1

    if bad or fails:
        print(f"[test] FAILED — {len(bad)} parse error(s), "
              f"{fails} render failure(s)")
        return 1
    print("[test] all checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
