#!/usr/bin/env bash
# portraits.sh — the faces of the NPCs who talk (S23): export their retail
# animations into godot/assets/anims/portrait_<who>/, which talk_panel.gd
# shows next to what they say. Run from the repo root, after the client is
# extracted to client/compiled/game/ (see README.md).
#
#   tools/asset-import/portraits.sh [assets_root]   (default godot/assets)
#
# The retail talk window (npcTalkDialog) showed a GUI animation per speaker:
# bob_interface (Baan → Nilo), demon1, and the gostofos. Adamai's own GUI
# animation (gui.jar, 2008) is an older .anm layout the parser does not
# read, so Aldebrán takes his map actor instead (gfx 2500, scripts/scenario/
# 0.lua: Actor.createActor(m_emisaryId, 2500, …)), which has a talk loop.
set -euo pipefail
ROOT="${1:-godot/assets}/anims"
JAR=client/compiled/game/contents/animations.jar
R=tools/asset-import/anm_render.py
mkdir -p "$ROOT"
export_one() {   # <entry> <portrait name> [actions to keep…] (default: all)
	local tmp entry=$1 name=$2
	shift 2
	tmp=$(mktemp -d)
	python3 "$R" "$JAR" "$entry" --export "$tmp" > /dev/null
	rm -rf "$ROOT/portrait_$name"
	mkdir -p "$ROOT/portrait_$name"
	if [ $# -eq 0 ]; then
		cp -r "$tmp"/* "$ROOT/portrait_$name"/
	else
		for a in "$@"; do cp -r "$tmp/$a" "$ROOT/portrait_$name"/; done
	fi
	rm -rf "$tmp"
	echo "portrait_$name: $(ls "$ROOT/portrait_$name" | wc -l) actions"
}
# only what talk_panel plays: the idle (and the talk loop where there is one)
export_one animations/gui/bob_interface.anm nilo 1_AnimStatique
export_one animations/gui/demon1.anm demon1
export_one animations/NPCs/2500.anm aldebran 1_AnimParle 1_AnimStatique
for g in gostIop gostSacri gostEnu gostSramette; do
	export_one "animations/gui/$g.anm" "$(echo "$g" | tr '[:upper:]' '[:lower:]')"
done
