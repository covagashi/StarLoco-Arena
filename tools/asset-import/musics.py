#!/usr/bin/env python3
"""musics.py — the retail music tracks for the Godot client (sprints/S06).

musics.jar holds three oggs: loading, island and fight. The retail plays
"island" outside a fight and "fight" during one (client sk_2 / nk_0.ce);
"loading" is never asked for, but it is copied too so the folder mirrors the
jar. Godot reads them raw from assets/musics/ (godot/src/audio/audio.gd).

Usage:
  python3 tools/asset-import/musics.py \
      client/compiled/game/contents/musics.jar godot/assets/musics
"""
import os
import sys
import zipfile


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    jar, out = sys.argv[1:3]
    os.makedirs(out, exist_ok=True)
    n = 0
    with zipfile.ZipFile(jar) as z:
        for name in z.namelist():
            if not (name.startswith("musics/") and name.endswith(".ogg")):
                continue
            with open(os.path.join(out, os.path.basename(name)), "wb") as f:
                f.write(z.read(name))
            n += 1
    print(f"{n} tracks -> {out}")


if __name__ == "__main__":
    main()
