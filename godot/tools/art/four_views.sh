#!/usr/bin/env bash
## Four views of one model as the game draws it (front, right, top, game
## camera) on one labelled sheet, so a piece is checked from every side
## before it is shown (owner, 2026-11-03: "¿por qué no usas las 4 vistas?").
##
##   tools/art/four_views.sh <model.glb or res://…glb> <out.png> [label] [size]
set -euo pipefail
model=$1; out=$2; label=${3:-$(basename "$model" .glb)}; size=${4:-480}
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp=$(mktemp -d)
shot() {  # name yaw pitch view
	DISPLAY= xvfb-run -a -s "-screen 0 ${size}x${size}x24" godot --path "$here" -s tools/promo/promo.gd -- \
		--mode=spin --model="$model" --view="$4" --yaw="$2" --pitch="$3" --size="${size}x${size}" \
		--out="$tmp/$1.png" >/dev/null 2>&1
}
shot front 0 6 persp
shot right 90 6 persp
shot top 0 88 persp
shot game 45 30 game
python3 - "$tmp" "$out" "$label" "$size" <<'PY'
import sys
from PIL import Image, ImageDraw
tmp, out, label, n = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
W = Image.new("RGB", (n * 2, n * 2))
d = ImageDraw.Draw(W)
for i, v in enumerate(["front", "right", "top", "game"]):
    W.paste(Image.open(f"{tmp}/{v}.png"), ((i % 2) * n, (i // 2) * n))
    d.text(((i % 2) * n + 8, (i // 2) * n + 8), f"{label} · {v}", fill="white")
W.save(out)
PY
rm -rf "$tmp"
