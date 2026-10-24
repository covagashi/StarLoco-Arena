#!/usr/bin/env bash
## Replay → vertical mp4 (S11). Renders tools/reel/render.gd under Godot's
## movie maker at 540x960, 30 fps, then ffmpeg scales it to 1080x1920
## and encodes H.264.
##
##   tools/reel/make_reel.sh <replay.slr> <out.mp4> [render args…]
##   e.g. tools/reel/make_reel.sh ~/.local/share/godot/app_userdata/StarLoco\ Arena/replays/x.slr \
##        ~/codigo/capturas/s11/reel.mp4 --speed=1.5 --hud=banner
##
## No display needed: without $DISPLAY it runs under xvfb. Needs ffmpeg.
## A fight is recorded with tools/reel/record.gd (AI vs AI) or in the game.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

replay="$(realpath "$1")"
out="$2"
shift 2
GODOT="${GODOT:-godot}"

## The movie maker records at the project's window size, read at startup:
## neither --resolution nor a resize from the script changes it. So the
## portrait size goes in through a throwaway override.cfg (Godot reads it
## next to project.godot), removed again on exit.
if [[ -e override.cfg ]]; then
	echo "godot/override.cfg already exists — not overwriting it" >&2
	exit 1
fi
frames="$(mktemp -d)"
trap 'rm -rf "$frames"; rm -f override.cfg' EXIT
printf '[display]\n\nwindow/size/viewport_width=540\nwindow/size/viewport_height=960\n' > override.cfg
wrap=()
if [[ -z "${DISPLAY:-}" ]]; then
	wrap=(xvfb-run -a -s "-screen 0 1200x1200x24")
fi
${wrap[@]+"${wrap[@]}"} "$GODOT" --accessibility disabled \
	--path . --write-movie "$frames/f.png" --fixed-fps 30 \
	-s tools/reel/render.gd -- --replay="$replay" "$@"
mkdir -p "$(dirname "$out")"
ffmpeg -loglevel error -y -framerate 30 -i "$frames/f%08d.png" \
	-vf "scale=1080:1920:flags=lanczos" -c:v libx264 -pix_fmt yuv420p \
	-crf 18 -movflags +faststart "$out"
echo "[reel] $out ($(ls "$frames" | wc -l) frames)"
