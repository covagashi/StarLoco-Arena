#!/usr/bin/env bash
## S37: the effect library's grid (vfx_sheet.gd) → <out>.mp4 plus
## screen-sized frame pages <out>-<shape>.png (owner: no tall strips).
##
##   tools/fx/vfx_sheet.sh <out prefix> [vfx_sheet.gd args…]
##   e.g. tools/fx/vfx_sheet.sh ~/codigo/capturas/s37/vfx
##
## Without $DISPLAY it runs under gamescope (headless) or xvfb. Needs ffmpeg and python3 + PIL.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
out="$1"
shift
GODOT="${GODOT:-godot}"
if [[ -e override.cfg ]]; then
	echo "godot/override.cfg already exists — not overwriting it" >&2
	exit 1
fi
frames="$(mktemp -d)"
trap 'rm -rf "$frames"; rm -f override.cfg' EXIT
printf '[display]\n\nwindow/size/viewport_width=1870\nwindow/size/viewport_height=876\n' > override.cfg
wrap=()
## Without a display: gamescope's headless backend renders on the GPU (the
## Ally's radeonsi, not xvfb's software GL); xvfb otherwise.
if [[ -z "${DISPLAY:-}" ]]; then
	if command -v gamescope >/dev/null 2>&1; then
		wrap=(gamescope --backend headless -W 1870 -H 876 --)
	else
		wrap=(xvfb-run -a -s "-screen 0 1920x1080x24")
	fi
fi
${wrap[@]+"${wrap[@]}"} "$GODOT" --accessibility disabled \
	--path . --write-movie "$frames/f.png" --fixed-fps 30 \
	-s tools/fx/vfx_sheet.gd -- "$@"
mkdir -p "$(dirname "$out")"
ffmpeg -loglevel error -y -framerate 30 -i "$frames/f%08d.png" \
	-c:v libx264 -pix_fmt yuv420p -crf 18 -movflags +faststart "$out.mp4"
python3 -I tools/fx/vfx_pages.py "$frames" "$out"
echo "[vfx] $out.mp4 ($(ls "$frames" | wc -l) frames)"
