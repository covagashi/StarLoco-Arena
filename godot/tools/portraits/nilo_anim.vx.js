// S38b: the overlays of Nilo's idle loop (animated in AniCraft, owner
// 2026-11-13). Each is a 170 x 200 layer laid exactly over nilo_fable.vx.js's
// portrait (same palette, same coordinates): the closed lids of the blink,
// the warm halo behind the staff's stone, and a sparkle by the stone.
//   node <vex>/bin/vex.js build tools/portraits/nilo_anim.vx.js --scales 1
// tools/portraits/npc_anim.py then builds the loop in AniCraft.

pal({
  k: "#1c2030",
  l1: "#f1ebfa", l0: "#d4c6ea",
  o2: "#ffc466", o3: "#fff0c4",
  w2: "#ffffff",
})

const INK = (w = 2, taper = 0.45) => ({ ink: { c: "k", w, taper, wobble: 0, vary: 0.25 } })

// the blink: the eyes (glancing right, nilo_fable.vx.js) covered by the
// lens and drawn shut as a smiling curve under the heavy lid
sprite("nilo_blink", { w: 170, h: 200 },
  ...[[64, 111], [106, 111]].flatMap(([cx, cy]) => [
    ellipse(cx + 3, cy + 2.5, 9, 7.4, "l1"),
    clip(ellipse(cx + 3, cy + 2.5, 9, 7.4, "k"), ellipse(cx + 8, cy + 8, 10, 5, { fill: "l0", opacity: 0.7 })),
    curve([cx - 5, cy - 1, cx + 2, cy - 4, cx + 10.5, cy - 0.5], INK(2.4, 0.3)),
    curve([cx - 4, cy + 2, cx + 3, cy + 5.5, cx + 10, cy + 2.5], INK(2.2, 0.35)),
  ]))

// the stone's glow (its alpha pulses in the loop), clipped to the stone: a
// soft halo over the figure turned the ink and the dark wood round it brown
const STONE = [147, 93, 156, 101, 159, 116, 154, 128, 147, 131, 140, 128, 135, 116, 138, 101]
sprite("nilo_glow", { w: 170, h: 200 },
  clip(blob(STONE, "k"),
    ellipse(145, 108, 13, 18, { fill: rad(["#fffbe8", "#ffd88aee", "#ffc46600"], { cx: 0.45, cy: 0.4, r: 0.55 }) })))

// a four-point sparkle by the stone
// SPARK_C = [131, 94]
// (its own small sprite, centred at SPARK_C on the portrait, so AniCraft
// scales and turns it about its centre)
sprite("nilo_spark", { w: 28, h: 28 },
  star(14, 14, 4, 10, 2.2, { fill: "w2", glow: { r: 5, color: "o2" } }))
