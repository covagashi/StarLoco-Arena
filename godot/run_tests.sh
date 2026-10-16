#!/usr/bin/env bash
## Single entry point for the Godot client's two test lanes.
##
##   --headless   Lint + unit lane: the B-173 path guard, then
##                res://test/unit/unit_runner.tscn under --headless. No
##                git-ignored assets required — this is the CI lane.
##   --visual     Windowed preview lane only: test/ui_review_preview.tscn and
##                test/fight_ui_preview.tscn, each at 1280x720 and 800x600,
##                plus the fight preview in the 1-bit style when its map art
##                is converted (assets/mapgfx_1bit).
##                Needs assets/anims (coach_7000) + the appSkin atlases, so
##                it can only ever run locally.
##   (no flag)    Headless lane, then the visual lane too — but only if
##                assets/anims exists. If it doesn't (a fresh checkout — see
##                AGENTS.md, assets/ is git-ignored except assets/ui and
##                assets/i18n), the visual lane is skipped with a notice
##                instead of failing.
##
## GODOT overrides the binary. Otherwise: `godot` on PATH (Linux, CI), then
## the usual macOS install path.
##
## The visual lane needs a display. With no $DISPLAY (a headless Linux box)
## it runs under xvfb-run, on Mesa's software GL — slow but real pixels.
## --headless would not do: it swaps in the dummy renderer, which draws nothing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ -z "${GODOT:-}" ]]; then
	if command -v godot >/dev/null 2>&1; then
		GODOT="$(command -v godot)"
	else
		GODOT=/Applications/Godot.app/Contents/MacOS/Godot
	fi
fi

## Empty on macOS; expanded with ${a[@]+...} below because bash 3.2 (macOS)
## treats an empty array as unbound under set -u.
DISPLAY_WRAP=()
if [[ "$(uname -s)" != Darwin && -z "${DISPLAY:-}" ]]; then
	DISPLAY_WRAP=(xvfb-run -a -s "-screen 0 1920x1080x24")
fi

## sprints/BACKLOG.md §7's cleanup convention: the real argv never carries
## --headless, just "--path ." — so this one pattern catches a leftover
## process from either lane, as ".../Contents/MacOS/Godot --path ." on macOS
## or ".../godot --path ." on Linux.
cleanup_godot() {
	# Anchored at the start of the command line: only a process whose
	# executable IS Godot matches. Unanchored, it also matched any shell whose
	# own command text contained "godot --path ." and killed the caller.
	pkill -f "^[^ ]*[Gg]odot[^ /]* --path \." >/dev/null 2>&1 || true
}

## B-173 guard. Every raw asset read must go through AssetPaths, because a
## hardcoded "res://assets/…" works in the editor and silently reads nothing
## from an exported .pck. Comment lines are exempt, and so is asset_paths.gd
## itself — it owns the PREFIX constant. Pure grep, so it needs no Godot and
## runs even on a machine that has never installed it.
run_lint() {
	echo "=== lint: no hardcoded res://assets in src/ (B-173) ==="
	local offenders
	offenders=$(grep -rn 'res://assets' src --include='*.gd' \
		| grep -v '^src/util/asset_paths.gd:' \
		| grep -vE ':[0-9]+:[[:space:]]*#' || true)
	if [[ -n "$offenders" ]]; then
		echo "$offenders"
		echo
		echo "Those paths cannot be read from an exported build (B-173)."
		echo "Route them through AssetPaths instead, e.g.:"
		echo '  AssetPaths.read_json("gamedata/spells.json")'
		echo '  AssetPaths.load_image("ui/lobby_bg.png")'
		echo '  AssetPaths.resolve("gui/fonts/TAHOMA.TTF")'
		return 1
	fi
	echo "ok"
	return 0
}

run_headless() {
	echo "=== headless unit lane ==="
	local rc=0
	"$GODOT" --headless --path . res://test/unit/unit_runner.tscn || rc=$?
	return "$rc"
}

run_visual() {
	echo "=== visual preview lane ==="
	local rc=0
	local scene res scene_rc
	for scene in test/ui_review_preview.tscn test/fight_ui_preview.tscn; do
		for res in 1280x720 800x600; do
			echo "--- $scene @ $res ---"
			scene_rc=0
			${DISPLAY_WRAP[@]+"${DISPLAY_WRAP[@]}"} "$GODOT" --path . -w --resolution "$res" "res://$scene" || scene_rc=$?
			# Clean up before checking this run's result so a hung/crashed
			# window never lingers, but don't let the cleanup's own exit
			# status (e.g. "no process found") clobber scene_rc.
			cleanup_godot
			if [[ "$scene_rc" -ne 0 ]]; then
				rc=$scene_rc
			fi
		done
	done
	# The fight HUD again in the 1-bit style (sprints/S04, S17): its own
	# theme and the converted map art. Skipped when the art isn't converted.
	if [[ -e assets/mapgfx_1bit/10.json ]]; then   # the preview's map, converted
		for res in 1280x720 800x600; do
			echo "--- test/fight_ui_preview.tscn @ $res (1-bit) ---"
			scene_rc=0
			ARENA_ART_STYLE=onebit FIGHT_UI_SHOT=/tmp/fight-ui-onebit.png \
				${DISPLAY_WRAP[@]+"${DISPLAY_WRAP[@]}"} "$GODOT" --path . -w --resolution "$res" \
				res://test/fight_ui_preview.tscn || scene_rc=$?
			cleanup_godot
			if [[ "$scene_rc" -ne 0 ]]; then
				rc=$scene_rc
			fi
		done
	else
		echo "--- 1-bit fight preview: SKIPPED (assets/mapgfx_1bit missing, see tools/asset-import/onebit.py) ---"
	fi
	return "$rc"
}

skip_visual_notice() {
	cat <<'EOF'
=== visual preview lane: SKIPPED ===
assets/anims/coach_7000 is not present. The art is git-ignored on purpose (redistribution
constraint on converted retail art — see AGENTS.md / sprints/BACKLOG.md),
so a fresh checkout never has it, and the windowed previews (coach_7000
anims + appSkin atlases) can't run without it.

Regenerate it with the asset-import pipeline — see the commands in
sprints/BACKLOG.md §6.
EOF
}

mode="${1:-}"

case "$mode" in
	--headless)
		rc=0
		run_lint || rc=$?
		run_headless || rc=$?
		exit "$rc"
		;;
	--visual)
		rc=0
		run_visual || rc=$?
		exit "$rc"
		;;
	"")
		headless_rc=0
		run_lint || headless_rc=$?
		run_headless || headless_rc=$?

		visual_rc=0
		# coach_7000, not the folder itself: assets/anims/ exists in every
		# checkout because its .gdignore is tracked.
		if [[ -d assets/anims/coach_7000 ]]; then
			run_visual || visual_rc=$?
		else
			skip_visual_notice
		fi

		if [[ "$headless_rc" -ne 0 || "$visual_rc" -ne 0 ]]; then
			exit 1
		fi
		exit 0
		;;
	*)
		echo "usage: $(basename "$0") [--headless|--visual]" >&2
		exit 2
		;;
esac
