#!/usr/bin/env python3
"""Parse every particles/*.xps in sfx.jar — skip if jar absent."""

import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from xps_dump import parse_xps, parse_xps_header  # noqa: E402

JAR = Path(__file__).resolve().parents[2] / (
    "client/compiled/game/contents/sfx.jar")


def main() -> None:
    if not JAR.is_file():
        print("skip: no sfx.jar")
        return
    ok = hdr = fail = skip = 0
    with zipfile.ZipFile(JAR) as z:
        names = [n for n in z.namelist() if n.endswith(".xps")]
        for nm in names:
            data = z.read(nm)
            if data[:3] == b"XPS":
                skip += 1
                continue
            try:
                parse_xps_header(data)
                hdr += 1
            except Exception:
                pass
            try:
                parse_xps(data)
                ok += 1
            except Exception:
                fail += 1
    wire = len(names) - skip
    print(f"xps: {ok}/{wire} full, {hdr}/{wire} header, {skip} legacy, {fail} fail")
    if ok != wire:
        sys.exit(1)


if __name__ == "__main__":
    main()
