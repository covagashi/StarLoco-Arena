// S38b: the overlays of Demon I's idle loop (animated in AniCraft like Nilo's,
// nilo_anim.vx.js). Each is a 170 x 200 layer laid exactly over
// demon1_fable.vx.js's portrait (same palette, same coordinates: the portrait's
// 164 x 194 box + 3-unit outline and its -3 shift cancel out): the shut eyes of
// the blink, the brighter light inside the pink eyes and the ghost flames, and
// a sparkle on a fang.
//   node <vex>/bin/vex.js build tools/portraits/demon1_anim.vx.js --scales 1,2
// The blink repaints the face plate under the eyes (the eyes' pink halo spills
// onto it), so it re-draws the mask's cel shading, brow shadow and ink lines
// from demon1_fable.vx.js clipped to a patch round each eye.

pal({
  k: "#1c2030",
  i0: "#2a1b4e", i1: "#4f3888", i2: "#7558b0", i3: "#a088d4",
  m0: "#5a4a8c", m1: "#8577b8", m2: "#aa9fd4",
  e0: "#ff7ac8", e1: "#ffc2e6", e2: "#ffffff",
  g0: "#4fd3e6", g1: "#b8f3fa", g2: "#eefdff",
})

const INK = (w = 2, taper = 0.45) => ({ ink: { c: "k", w, taper, wobble: 0, vary: 0.25 } })
const sh = (pts, dx, dy) => pts.map((v, i) => v + (i % 2 ? dy : dx))
const S = (st, extra) => ({ ...extra, ...(typeof st === "string" ? { fill: st } : st) })
function cel(mk, [c0, c1, c2, cr], { sd = 4, hd = 5, rim = 0, hi = true } = {}) {
  const out = []
  if (rim > 0) { out.push(mk(0, 0, cr || c2)); out.push(clip(mk(-rim, -rim * 0.6, "k"), mk(0, 0, c0))) }
  else out.push(mk(0, 0, c0))
  out.push(clip(mk(-sd, -sd * 0.8, "k"), mk(0, 0, c1)))
  if (hi) out.push(clip(mk(-sd, -sd * 0.8, "k"), clip(mk(0, 0, "k"), mk(0, 0, c2), mk(hd, hd * 0.9, c1))))
  return out
}

// the same head and face plate as the portrait
const HEAD = [85, 74, 104, 78, 118, 92, 121, 112, 115, 132, 100, 146, 85, 152, 70, 146, 55, 132, 49, 112, 52, 92, 66, 78]
const head = (dx, dy, st) => blob(sh(HEAD, dx, dy), st)
const MASK = [85, 97, 97, 90, 111, 97, 118, 112, 114, 132, 100, 146, 85, 150, 70, 146, 56, 132, 52, 112, 59, 97, 73, 90]
const mask = (dx, dy, st) => blob(sh(MASK, dx, dy), st)
// the open eye (left; sym mirrors it) and its brow shadow
const EYE = [58, 112, 66, 102, 80, 108, 79, 116, 68, 119, 60, 118]
const BROW = [54, 104, 70, 102, 84, 106, 84, 114, 70, 116, 56, 114]
// the patch the blink repaints: the eye plus its halo, inside the face plate
const PATCH = [50, 112, 56, 96, 70, 94, 86, 102, 88, 116, 84, 124, 66, 127, 52, 122]

// the blink: the glowing eyes covered by the face plate, drawn shut as a
// heavy slanted line under the brow (a sly showman's squint)
sprite("demon1_blink", { w: 170, h: 200 },
  sym(85,
    clip(blob(PATCH, { fill: "k", smooth: 0.5 }),
      ...cel(head, ["i0", "i1", "i2", "i3"], { sd: 7, hd: 8, rim: 2 }),
      ...cel(mask, ["m0", "m1", "m2"], { sd: 6, hd: 6, rim: 0 }),
      clip(head(0, 0, "k"), sym(85, blob(BROW, { fill: "i0", opacity: 0.45 }))),
      mask(0, 0, { fill: "none", stroke: "i0", sw: 1.4, opacity: 0.7 }),
      head(0, 0, { fill: "none", stroke: "k", sw: 2.2, join: "round" }),
    ),
    // a dark crease where the lids meet, a thread of pink light left in the slit
    blob([59, 113, 67, 107, 80, 111, 79, 115, 68, 117, 61, 117], { fill: "i0", smooth: 0.5, opacity: 0.6 }),
    curve([60, 114.5, 69, 110.5, 79, 112.5], { stroke: "e0", sw: 1.1, opacity: 0.55, cap: "round" }),
    // the brow line (as the portrait's) and the shut eye under it
    curve([56, 112, 66, 100, 82, 107], INK(2.6, 0.3)),
    curve([58, 115, 68, 109, 80, 112], INK(2.6, 0.3)),
    curve([60, 119, 70, 121, 80, 117], INK(1.4, 0.5)),
  ))

// the glow (its alpha pulses in the loop), kept inside what emits light: a
// hot white-pink core in each eye and a brighter tongue in each ghost flame
// (a halo over the dark ink would turn muddy in AniCraft)
const FLAME = [70, 74, 62, 66, 58, 56, 61, 46, 58, 39, 66, 44, 67, 36, 71, 48, 75, 56, 77, 68]
const FLAMEIN = [70, 72, 65, 64, 63, 56, 66, 49, 69, 56, 73, 61, 75, 68]
sprite("demon1_glow", { w: 170, h: 200 },
  sym(85,
    clip(blob(EYE, { fill: "k", smooth: 0.55 }),
      ellipse(71, 112, 12, 8, { fill: rad(["e2", "e1", "e0", "#ff7ac800"], { cx: 0.5, cy: 0.5, r: 0.6 }) })),
    clip(blob(FLAME, { fill: "k", smooth: 0.6 }),
      blob(FLAMEIN, { fill: "g1", smooth: 0.6, opacity: 0.6 }),
      ellipse(68, 58, 4, 9, { fill: rad(["g2", "g1", "#b8f3fa00"], { cx: 0.5, cy: 0.55, r: 0.55 }) })),
    circle(80, 67, 1.3, "g1"),
  ))

// a four-point sparkle, a glint on the tip of the right fang
// (its own small sprite, centred on the portrait at SPARK_C, so AniCraft
// scales and turns it about its centre)
// SPARK_C = [105, 143]
sprite("demon1_spark", { w: 28, h: 28 },
  star(14, 14, 4, 10, 2.2, { fill: "e2", glow: { r: 5, color: "e0" } }))
