#!/usr/bin/env bash
# S35b-marketing, tanda 3: every render the posts need, into $T3_RAW
# (default ~/codigo/marketing/_fuentes/raw3). Then tanda3.py composes them.
#   tools/promo/tanda3_render.sh [step …]   (before 30 31 32 33 34 35 36 38; none = all)
# Run from godot/. The game's GLBs are only read; the "before" builds go
# to $T3_RAW/before (old meshy_fighter.py from git, or options taken out).
set -euo pipefail
cd "$(dirname "$0")/../.."
RAW=${T3_RAW:-$HOME/codigo/marketing/_fuentes/raw3}
M=$HOME/codigo/capturas/s35/meshy
CH=tools/blender/characters
OUTG=art/characters/out
B=$RAW/before
mkdir -p "$RAW"
log() { grep -E "^\[(promo|meshy)|rror" | cut -c1-160 || true; }
bones() { blender -b -P $CH/promo_bones.py -- "$@" 2>&1 | log; }
want() { [ $# -eq 0 ] && return 0; for s in "${STEPS[@]}"; do [ "$s" = "$1" ] && return 0; done; return 1; }
STEPS=("$@")
[ ${#STEPS[@]} -eq 0 ] && STEPS=(before 30 31 32 33 34 35 36 37 38)

# full-body framing for 9:16 under the title
TALL="--dist=4.9 --target_z=0.98 --cam_z=1.25"

if want before; then
  # the meshy_fighter.py of the commit before each fix, with its tools
  mkdir -p "$B"
  for c in 0707e479 0bf034df e0154778 4901cb3f; do
    [ -d "$B/src-$c" ] || { mkdir -p "$B/src-$c"; git -C .. archive $c godot/tools/blender/characters | tar -x -C "$B/src-$c"; }
  done
  old() {  # commit name folder [options]
    local c=$1 n=$2 f=$3; shift 3
    blender -b -P "$B/src-$c/godot/$CH/meshy_fighter.py" -- "$M/$f/$f.glb" "$B/$n.glb" "$@" 2>&1 | log
  }
  old 0707e479 aniripsa_m 07_aniripsa_m --joints=$M/07_aniripsa_m/joints.json          # wings taken for arms
  old 0bf034df sacrogrito_m 11_sacrogrito_m --joints=$M/11_sacrogrito_m/joints.json --arm_slack=0.06  # scarf
  old e0154778 aniripsa_f 07_aniripsa_f --joints=$M/07_aniripsa_f/joints.json          # shoulder near the elbow
  old 4901cb3f yopuka_f 08_yopuka_f --joints=$M/08_yopuka_f/joints.json                # sword left behind
  # options taken out of today's script
  blender -b -P $CH/meshy_fighter.py -- $M/04_sram_f/04_sram_f.glb "$B/sram_f.glb" 2>&1 | log           # no hand_tip: thumbs
  blender -b -P $CH/meshy_fighter.py -- $M/05_xelor_m/05_xelor_m.glb "$B/xelor_m.glb" \
    --joints=$M/05_xelor_m/joints.json 2>&1 | log                                                      # no --arm_slack: fins
fi

if want 30; then
  bones $OUTG/feca_f.glb "$RAW/r30a" --frames=75 --yaw0=-40 --yaw1=0 --layers=grey $TALL
  bones $OUTG/feca_f.glb "$RAW/r30b" --frames=1 $TALL
  bones $OUTG/feca_f.glb "$RAW/r30c" --anim=walk_loop --frames=96 --yaw0=0 --yaw1=50 --layers=tex,ghost $TALL
fi

if want 31; then
  for f in 01_feca_f 02_osamodas_f 09_ocra_m 06_zurcarak_m; do
    j=(); [ -f $M/$f/joints.json ] && j=(--joints=$M/$f/joints.json)
    blender -b -P $CH/promo_slices.py -- $M/$f/$f.glb "$RAW/s31/${f#*_}" "${j[@]}" 2>&1 | log
  done
fi

if want 32; then
  W32="--anim=celebrate --frames=58 --step=0.5 --layers=weights,tex --wmode=arms --yaw0=15 --yaw1=15 $TALL"
  bones $OUTG/feca_f.glb "$RAW/r32/feca" $W32
  bones $OUTG/feca_f.glb "$RAW/r32/feca-rest" --frames=1 --layers=weights,tex --wmode=arms --yaw0=15 --yaw1=15 $TALL
  bones "$B/sacrogrito_m.glb" "$RAW/r32/scarf-before" $W32
  bones $OUTG/sacrogrito_m.glb "$RAW/r32/scarf-after" $W32
fi

if want 33; then
  for n in yopuka_f sram_f sacrogrito_m aniripsa_m aniripsa_f; do
    for v in before after; do
      g=$OUTG/$n.glb; [ $v = before ] && g=$B/$n.glb
      bones "$g" "$RAW/r33/$n-$v" --anim=celebrate --frames=1 --start=11 --layers=tex,ghost \
        --yaw0=20 --yaw1=20 --size=540x960 --dist=4.3 --target_z=0.8 --cam_z=1.05
    done
  done
  bones "$B/sacrogrito_m.glb" "$RAW/r33/cover" --anim=celebrate --frames=1 --start=11 --layers=tex \
    --yaw0=20 --yaw1=20 --size=1080x1350 --dist=4.2 --target_z=1.2 --cam_z=1.25
fi

FIGHTERS="feca_f feca_m osamodas_f osamodas_m anutrof_f anutrof_m sram_f sram_m xelor_f xelor_m zurcarak_f zurcarak_m
  aniripsa_f aniripsa_m yopuka_f yopuka_m ocra_f ocra_m sadida_f sadida_m sacrogrito_f sacrogrito_m pandawa_f pandawa_m"
if want 34; then
  for n in $FIGHTERS; do
    xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s tools/art/anim_sheet.gd -- --model=$OUTG/$n.glb \
      --out="$RAW/r34/$n" --video --dirs=S --anims=celebrate,melee --size=270x300 --zoom=2.6 --focus=0.6 --bg=1d1c19 2>&1 \
      | grep -E "anim_sheet\]|ERROR" || true
  done
fi
if want 34; then  # the close-up the grid zooms into
  xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s tools/art/anim_sheet.gd -- --model=$OUTG/yopuka_f.glb \
    --out="$RAW/r34/_close" --video --dirs=S --anims=melee --size=1080x1200 --zoom=10.4 --focus=0.6 --bg=1d1c19 2>&1 \
    | grep -E "anim_sheet\]|ERROR" || true
fi

if want 35; then  # creatures and the golem: x-ray, weights and a step of the walk
  SQ="--size=1080x1350 --dist=4.6 --target_z=0.95 --cam_z=1.5"
  for n in 8005 8006 8004 8007; do
    y=30; [ $n = 8006 ] && y=55; [ $n = 8004 ] && y=50
    bones $OUTG/summon_$n.glb "$RAW/r35/$n-rest" --frames=1 --layers=ghost,weights,tex --yaw0=$y --yaw1=$y $SQ
    bones $OUTG/summon_$n.glb "$RAW/r35/$n-walk" --anim=walk_loop --frames=1 --start=5 --layers=tex,ghost --yaw0=$y --yaw1=$y $SQ
  done
  bones $OUTG/summon_8007.glb "$RAW/r35/8007-cel" --anim=celebrate --frames=1 --start=11 --layers=weights,tex --yaw0=30 --yaw1=30 $SQ
fi

if want 36; then
  blender -b -P $CH/promo_crystal.py -- "$RAW/r36/build" 2>&1 | log
  xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s tools/art/anim_sheet.gd -- --model=$OUTG/summon_8010.glb \
    --out="$RAW/r36/game" --video --dirs=S --anims=idle_loop,celebrate --size=1080x1200 --zoom=9 --focus=0.6 --bg=1d1c19 2>&1 \
    | grep -E "anim_sheet\]|ERROR" || true
fi

if want 37; then  # the build log line of one fighter, and how long it takes
  mkdir -p "$RAW/r37"
  s=$(date +%s.%N)
  blender -b -P $CH/meshy_fighter.py -- $M/01_feca_f/01_feca_f.glb "$RAW/r37/feca_f.glb" 2>&1 | grep "^\[meshy\]" > "$RAW/r37/meshy_line.txt"
  python3 -c "import time; print(round(time.time() - $s, 2))" > "$RAW/r37/seconds.txt"
fi

if want 38; then  # a staged fight, 3D figures only, arena 5, under the movie maker (portrait)
  [ -e override.cfg ] && { echo "godot/override.cfg already exists — not overwriting it" >&2; exit 1; }
  rm -rf "$RAW/r38"; mkdir -p "$RAW/r38"
  trap 'rm -f override.cfg' EXIT
  printf '[display]\n\nwindow/size/viewport_width=1080\nwindow/size/viewport_height=1920\n' > override.cfg
  PROMO_MAP=5 PROMO_ZOOM=2.9 xvfb-run -a -s "-screen 0 1200x2000x24" godot --accessibility disabled --path . \
    --write-movie "$RAW/r38/f.png" --fixed-fps 30 res://tools/promo/fight_promo.tscn 2>&1 | grep -E "SCRIPT|ERROR" || true
  rm -f override.cfg
  echo "[fight_promo] $(ls "$RAW/r38" | wc -l) frames"
fi
