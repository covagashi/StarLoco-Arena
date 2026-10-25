#!/usr/bin/env bash
# make_assets.sh — the whole Godot assets tree from a player's own retail
# client, in one command (sprints/S15). The art, audio and tables the Godot
# client reads are never redistributed: every player builds them from the
# retail DofusArena 2.70 client they own.
#
#   tools/make_assets.sh <retail_game_dir> <out_assets_dir> [options]
#
#   <retail_game_dir>  the retail client's game/ folder (the one holding
#                      contents/*.jar), or that contents/ folder itself
#   <out_assets_dir>   where to write: godot/assets for a dev checkout, or
#                      the assets/ folder next to an exported client
#
# Options:
#   --only a,b     run only these stages
#   --skip a,b     run every stage but these
#   --sets p,q     anims stage: only the sets matching these shell patterns
#                  (e.g. 'fighter_-110,npc_8*,portraits'); default every set
#   --jobs N       anims stage: render N sets at once (default 1; each job
#                  is one Python process, ~50 MB, one CPU core)
#   --resume       anims stage: keep sets an earlier run already finished
#
# Stages, in order (each is skippable; later ones read earlier outputs):
#   gamedata  server/cmd/dump* over server/data-dist + the i18n merge scripts
#             → gamedata/*.json (spells, cards, cardsets, fusionlabs,
#             elements, spheres, npcdialogs, effects, areas, fightercards,
#             spell_sfx, anm_scripts, spell_fx)
#   fx        xps_dump.py → fx/<id>.png, gamedata/xps/, gamedata/xps_index.json
#   gui       gui_extract.py → gui/ (xml, images, fonts, cursors, i18n_*.json)
#   musics    musics.py → musics/*.ogg
#   mapgfx    map_gfx.py for every world in maps/gfx/ → mapgfx/
#   anims     anm_render.py --export / --composite → anims/<set>/, and
#             portraits.sh → anims/portrait_*/ (the long one: ~40 min)
#   sounds    sounds.py → sounds/<id>.ogg for every id the tables and the
#             anim sets name (run after gamedata and anims)
#   pack      anm_pack.py → one atlas.png (+ atlas_m.png) per anim action
#             instead of one PNG per frame: ~17x fewer files and ~4x less
#             disk; AnmSprite reads either layout (skip it to keep frames)
#
# Needs: bash, python3 (+ Pillow for the gui stage), Go (gamedata stage).
# Re-running is safe: every stage rewrites its own outputs in place, and an
# anim set is rendered aside and swapped in whole, so an interrupted run
# never leaves a half set behind.
set -euo pipefail

STAGES=(gamedata fx gui musics mapgfx anims sounds pack)
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
AI="$HERE/asset-import"
DATA_DIST="${ARENA_DATA_DIST:-$REPO/server/data-dist}"
PY="${PYTHON:-python3}"

die() { echo "make_assets: $*" >&2; exit 1; }
usage() { sed -n '2,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit "${1:-0}"; }

# ---- arguments -------------------------------------------------------------
[ $# -ge 1 ] && case $1 in -h | --help) usage ;; esac
[ $# -ge 2 ] || usage 2
RETAIL=$1 OUT=$2
shift 2
ONLY="" SKIP="" SETS="" JOBS=1 RESUME=0
while [ $# -gt 0 ]; do
	case $1 in
	--only) ONLY=${2:?--only needs a list}; shift 2 ;;
	--skip) SKIP=${2:?--skip needs a list}; shift 2 ;;
	--sets) SETS=${2:?--sets needs a list}; shift 2 ;;
	--jobs) JOBS=${2:?--jobs needs a number}; shift 2 ;;
	--resume) RESUME=1; shift ;;
	-h | --help) usage ;;
	*) die "unknown option: $1 (see --help)" ;;
	esac
done
[[ $JOBS =~ ^[1-9][0-9]*$ ]] || die "--jobs wants a positive number, got '$JOBS'"
for s in ${ONLY//,/ } ${SKIP//,/ }; do
	[[ " ${STAGES[*]} " == *" $s "* ]] || die "unknown stage '$s' (stages: ${STAGES[*]})"
done
want() { # <stage>: is it selected?
	if [ -n "$ONLY" ]; then [[ ",$ONLY," == *",$1,"* ]]; else [[ ",$SKIP," != *",$1,"* ]]; fi
}

# ---- the retail client -----------------------------------------------------
[ -d "$RETAIL" ] || die "no such folder: $RETAIL"
if [ -d "$RETAIL/contents" ]; then C="$(cd "$RETAIL/contents" && pwd)"; else C="$(cd "$RETAIL" && pwd)"; fi
need_jar() { # <stage> <jar under contents/>…
	local st=$1 j
	shift
	for j in "$@"; do
		[ -f "$C/$j" ] || die "stage $st needs $j, but $C/$j is missing — is '$RETAIL' the retail game/ folder (the one with contents/)?"
	done
}
want gamedata && need_jar gamedata i18n.jar data.jar sounds.jar
want fx && need_jar fx sfx.jar
want gui && need_jar gui gui.jar i18n.jar
want musics && need_jar musics musics.jar
want mapgfx && need_jar mapgfx maps/data.jar gfx.jar
want anims && need_jar anims animations.jar
want sounds && need_jar sounds sounds.jar animations.jar
if want mapgfx && ! ls "$C"/maps/gfx/*.jar > /dev/null 2>&1; then
	die "stage mapgfx needs the world jars in $C/maps/gfx/, there are none"
fi

command -v "$PY" > /dev/null || die "python3 not found (set PYTHON=… to pick one)"
if want gui; then "$PY" -c 'import PIL' 2> /dev/null || die "stage gui needs Pillow: $PY -m pip install pillow"; fi
if want gamedata; then
	command -v go > /dev/null || die "stage gamedata needs Go (https://go.dev/dl/) on PATH"
	[ -f "$DATA_DIST/data.bdat" ] || die "no $DATA_DIST/data.bdat (set ARENA_DATA_DIST=…)"
fi

mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/make_assets.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
LOGS="$OUT/.make_assets"   # per-stage logs + the anims resume stamps
mkdir -p "$LOGS"

gdignore() { # <folder>: create it, with the .gdignore the dev tree has
	mkdir -p "$OUT/$1"
	[ -f "$OUT/$1/.gdignore" ] ||
		echo "# Raw art read through AssetPaths, never imported. See /.gitignore." > "$OUT/$1/.gdignore"
}

stage() { # <stage> <function>: run it, one line per stage
	local st=$1 t0=$SECONDS
	if ! want "$st"; then
		echo "[$st] skipped"
		return 0
	fi
	echo "[$st] …"
	# in the background, not under the `if`: bash ignores set -e inside a
	# function called as a condition, so a failing tool would go unnoticed
	"$2" > "$LOGS/$st.log" 2>&1 &
	if wait $!; then
		echo "[$st] done in $((SECONDS - t0))s — $(tail -n 1 "$LOGS/$st.log")"
	else
		echo "[$st] FAILED after $((SECONDS - t0))s — last lines of $LOGS/$st.log:" >&2
		tail -n 15 "$LOGS/$st.log" >&2
		exit 1
	fi
}

# ---- gamedata --------------------------------------------------------------
do_gamedata() {
	local g="$OUT/gamedata" raw="$WORK/raw" bin="$WORK/bin"
	gdignore gamedata
	mkdir -p "$raw" "$bin"
	(cd "$REPO/server" && go build -o "$bin/" ./cmd/dumpspells ./cmd/dumpelements \
		./cmd/dumpcards ./cmd/dumpspheres ./cmd/dumpnpcdialogs ./cmd/dumpeffects \
		./cmd/dumpfightercards)
	"$bin/dumpspells" "$DATA_DIST" "$raw/spells.json"
	"$PY" "$AI/spell_names.py" "$raw/spells.json" "$C/i18n.jar" "$g/spells.json"
	"$bin/dumpelements" "$DATA_DIST" "$g/elements.json"
	"$bin/dumpcards" "$DATA_DIST" "$raw/cards.json" "$g/fusionlabs.json"
	"$PY" "$AI/card_names.py" "$raw/cards.json" "$C/i18n.jar" "$g/cards.json" # + cardsets.json
	"$bin/dumpspheres" "$DATA_DIST" "$g/spheres.json"
	"$bin/dumpnpcdialogs" "$DATA_DIST" "$raw/npcdialogs.json"
	"$PY" "$AI/npc_dialogs.py" "$raw/npcdialogs.json" "$C/i18n.jar" "$g/npcdialogs.json"
	"$bin/dumpeffects" "$DATA_DIST" "$g/effects.json" # + areas.json
	"$bin/dumpfightercards" "$DATA_DIST" "$g/fightercards.json"
	# the oggs it copies go to the sounds stage's own pass, not here
	mkdir -p "$WORK/sfx"
	"$PY" "$AI/spell_sounds.py" "$raw/spells.json" "$C/data.jar" "$C/sounds.jar" \
		"$g/spell_sfx.json" "$WORK/sfx" "$g/anm_scripts.json" "$g/spell_fx.json"
	echo "$(ls "$g"/*.json | wc -l) tables -> $g"
}

# ---- fx --------------------------------------------------------------------
do_fx() {
	gdignore fx
	gdignore gamedata
	"$PY" "$AI/xps_dump.py" "$C/sfx.jar" "$OUT/gamedata/xps" "$OUT/fx" "$OUT/gamedata/xps_index.json"
	echo "$(ls "$OUT/fx" | wc -l) textures, $(ls "$OUT/gamedata/xps" | wc -l) systems -> $OUT/fx"
}

# ---- gui -------------------------------------------------------------------
do_gui() {
	gdignore gui
	"$PY" "$AI/gui_extract.py" "$C/gui.jar" "$C/i18n.jar" "$OUT/gui"
}

# ---- musics ----------------------------------------------------------------
do_musics() {
	gdignore musics
	"$PY" "$AI/musics.py" "$C/musics.jar" "$OUT/musics"
}

# ---- mapgfx ----------------------------------------------------------------
do_mapgfx() {
	local j n=0
	gdignore mapgfx
	for j in "$C"/maps/gfx/*.jar; do
		ARENA_CONTENTS="$C" "$PY" "$AI/map_gfx.py" "$(basename "$j" .jar)" "$OUT/mapgfx"
		n=$((n + 1))
	done
	echo "$n worlds, $(ls "$OUT/mapgfx/tex" | wc -l) atlases -> $OUT/mapgfx"
}

# ---- anims -----------------------------------------------------------------
# Every set the Godot client loads, and the anm_render.py runs that make it.
# An --export/--composite filter is a substring of the action name.
#   animsort_<b>   AnimSort_<b>.anm's own cast actions, raw (a fallback: they
#                  are skeletal tracks and mostly render empty standalone)
#   coach_700<s>   the coach paper-doll: Players/700<s>.anm idles + the
#                  AnimCommunes gestures composited over it (s: 0 male, 1 female)
#   coach_805      the old coach stand-in (an NPC bird); nothing loads it now,
#                  kept because the dev tree still has it
#   fighter_<f>    a breed's body, Players/<f>.anm with f = -(100+breed*10+sex):
#                  its idles + AnimCommunes, AnimCombat, AnimEmotes<Male|Femele>,
#                  AnimSort_<breed*10> and the weapon banks' AnimStatique03
#                  armed poses composited over it; breed 2 also gets
#                  AnimSort_120's carry poses (Porte), which carry_smoke uses
#   npc_<id>       the summon creatures — every positive type-300 look in
#                  data-dist that animations.jar has (8110 has no anm)
#   portraits      portrait_<who>, the faces of the NPCs who talk (portraits.sh)
FIGHTERS="-110 -111 -120 -121 -130 -131 -140 -141 -150 -151 -160 -161 -170 -171
-180 -181 -190 -191 -1100 -1101 -1110 -1111 -1120 -1121"
NPCS="2000 8001 8002 8003 8004 8005 8006 8007 8008 8009 8010 8013 8014 8015
8100 8101 8102 8103 8104 8105 8106 8107 8108 8109"
WEAPONS="Epee1 Dague1 Arc Baguette Marteau Pelle Poings"

all_sets() {
	local x
	for x in 10 20 30 40 50 60 70 80 90 100 110 120 130; do echo "animsort_$x"; done
	echo coach_7000
	echo coach_7001
	echo coach_805
	for x in $FIGHTERS; do echo "fighter_$x"; done
	for x in $NPCS; do echo "npc_$x"; done
	echo portraits
}

render() { # anm_render.py <entry> --export <dir> [filter]
	local entry=$1 dir=$2
	shift 2
	"$PY" "$AI/anm_render.py" "$C/animations.jar" "animations/$entry" --export "$dir" "$@"
}
composite() { # anm_render.py <gesture> --composite <body> --export <dir> [filter]
	local gesture=$1 body=$2 dir=$3
	shift 3
	"$PY" "$AI/anm_render.py" "$C/animations.jar" "animations/$gesture" \
		--composite "animations/$body" --export "$dir" "$@"
}

make_set() { # <set> <dir>: render one set into <dir>
	local set=$1 d=$2 x f n breed sex
	case $set in
	animsort_*) render "Players/AnimSort_${set#animsort_}.anm" "$d" AnimSort ;;
	coach_805) render equipments/coachs/805.anm "$d" ;;
	coach_700?)
		render "Players/${set#coach_}.anm" "$d" AnimStatique
		composite Players/AnimCommunes.anm "Players/${set#coach_}.anm" "$d"
		;;
	fighter_*)
		# Players/-1<breed><sex>.anm: -110 breed 1 male … -1121 breed 12 female
		f=${set#fighter_} n=${set#fighter_-1}
		breed=$((n / 10)) sex=$((n % 10))
		render "Players/$f.anm" "$d" AnimStatique
		composite Players/AnimCommunes.anm "Players/$f.anm" "$d"
		composite Players/AnimCombat.anm "Players/$f.anm" "$d"
		composite "Players/AnimSort_$((breed * 10)).anm" "Players/$f.anm" "$d"
		if [ "$breed" = 2 ]; then
			composite Players/AnimSort_120.anm "Players/$f.anm" "$d" Porte
		fi
		# after AnimSort: both carry a LienClip part, the emotes' one wins
		if [ "$sex" = 0 ]; then x=Male; else x=Femele; fi
		composite "Players/AnimEmotes$x.anm" "Players/$f.anm" "$d"
		for x in $WEAPONS; do
			composite "Players/Anim$x.anm" "Players/$f.anm" "$d" AnimStatique03
		done
		;;
	npc_2000) render NPCs/2000.anm "$d" _Anim ;; # its gestures, not its 400 parts
	npc_*) render "NPCs/${set#npc_}.anm" "$d" ;;
	*) echo "unknown anim set $set" >&2; return 1 ;;
	esac
}

one_set() { # <set>: render aside, then swap in whole
	local set=$1 part="$OUT/anims/.$1.part" t0=$SECONDS
	rm -rf "$part"
	if [ "$set" = portraits ]; then
		mkdir -p "$part/anims"
		ANIMATIONS_JAR="$C/animations.jar" bash "$AI/portraits.sh" "$part" > "$LOGS/anims.portraits.log" 2>&1
		for x in "$part"/anims/portrait_*; do
			rm -rf "$OUT/anims/$(basename "$x")"
			mv "$x" "$OUT/anims/"
		done
		rm -rf "$part"
	else
		make_set "$set" "$part" > "$LOGS/anims.$set.log" 2>&1
		rm -rf "${OUT:?}/anims/$set"
		mv "$part" "$OUT/anims/$set"
	fi
	touch "$LOGS/anims.done.$set"
	echo "  $set: $((SECONDS - t0))s"
}

do_anims() {
	local set p sel=() running=0 failed=0
	gdignore anims
	while IFS= read -r set; do
		if [ -n "$SETS" ]; then
			local hit=0
			for p in ${SETS//,/ }; do
				# shellcheck disable=SC2053 # $p is a pattern on purpose
				[[ $set == $p ]] && hit=1
			done
			[ $hit = 1 ] || continue
		fi
		if [ $RESUME = 1 ] && [ -f "$LOGS/anims.done.$set" ]; then
			echo "  $set: kept (--resume)"
			continue
		fi
		sel+=("$set")
	done < <(all_sets)
	[ ${#sel[@]} -gt 0 ] || { echo "no anim set matches --sets '$SETS'"; return 0; }
	for set in "${sel[@]}"; do
		rm -f "$LOGS/anims.done.$set"
		one_set "$set" &
		running=$((running + 1))
		if [ $running -ge "$JOBS" ]; then
			wait -n || failed=$((failed + 1))
			running=$((running - 1))
		fi
	done
	while [ $running -gt 0 ]; do
		wait -n || failed=$((failed + 1))
		running=$((running - 1))
	done
	[ $failed = 0 ] || { echo "$failed set(s) failed — see $LOGS/anims.*.log"; return 1; }
	echo "${#sel[@]} sets -> $OUT/anims"
}

# ---- sounds ----------------------------------------------------------------
do_sounds() {
	gdignore sounds
	"$PY" "$AI/sounds.py" "$C/sounds.jar" "$OUT" "$C/animations.jar"
}

# ---- pack ------------------------------------------------------------------
do_pack() {
	"$PY" "$AI/anm_pack.py" "$OUT/anims" | tail -1
}

echo "make_assets: $C -> $OUT"
for st in "${STAGES[@]}"; do stage "$st" "do_$st"; done
echo "make_assets: done in ${SECONDS}s (logs in $LOGS)"
