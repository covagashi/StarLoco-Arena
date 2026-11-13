// S38b: the overlays of Aldebrán's idle loop (animated in AniCraft like Nilo's,
// nilo_anim.vx.js). Each is a 170 x 200 layer laid exactly over
// aldebran_fable.vx.js's portrait (same palette, same coordinates: the
// portrait's -3 shift and its 3-unit outline cancel out, so the numbers below
// land on the same pixels): the closed lids of the blink, the light inside the
// floating glyph over his open hand, and a sparkle beside the glyph.
//   node <vex>/bin/vex.js build tools/portraits/aldebran_anim.vx.js --scales 1,2

pal({
  k: "#1c2030",
  m0: "#6e3a0c", m1: "#b5661c",                                 // the mop hat's back fringe
  w0: "#a9c6da", w1: "#eef6fb", w2: "#ffffff",                  // white fur
  r1: "#f0a6b0",                                                // the blush
  g0: "#55e6ff", g1: "#dffbff",                                 // the glyph
  w3: "#f4ffff",
})

const INK = (w = 2, taper = 0.45) => ({ ink: { c: "k", w, taper, wobble: 0, vary: 0.25 } })

// --- the same helpers and shapes as aldebran_fable.vx.js (face, hat fringe) --
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
function furPts(cx, cy, rx, ry, n, dip, phase = 0) {
  const P = []
  for (let i = 0; i < n; i++) {
    const a = ((i / n) * 360 + phase) * Math.PI / 180, k = i % 2 ? 1 - dip : 1
    P.push(cx + rx * k * Math.cos(a), cy + ry * k * Math.sin(a))
  }
  return P
}
const FACE = furPts(85, 136, 35, 31, 22, 0.07, 8)
const face = (dx, dy, st) => blob(sh(FACE, dx, dy), S(st, { smooth: 0.8 }))
const HAT_C = [85, 82], HAT_R = [76, 52]
function domePts(dx = 0, dy = 0, bump = 1) {
  const P = []
  for (let a = 184; a <= 356; a += 8) {
    const r = (a * Math.PI) / 180, k = 1 + bump * (0.035 * Math.sin(r * 3 + 0.8) + 0.02 * Math.sin(r * 7))
    P.push(HAT_C[0] + HAT_R[0] * k * Math.cos(r) + dx, HAT_C[1] + HAT_R[1] * k * Math.sin(r) + dy)
  }
  return P
}
const TUFTS = [[158, 14, 5], [147, 34, 6.5], [134, 16, 5.5], [121, 19, 6.5], [108, 15, 6], [95, 21, 7], [81, 17, 6.5], [68, 22, 7], [55, 16, 6], [42, 19, 6.5], [30, 20, 5.5], [19, 38, 6], [10, 16, 4.5]]
const HAT_BACK = (() => {
  const P = domePts()
  for (const [x, len, hw] of TUFTS) {
    const xb = x - 6.5, yb = 95 + 10 * (1 - ((xb - 85) / 76) ** 2), l = len * 0.95 + 2
    P.push(xb + hw, yb, xb + hw * 0.5, yb + l * 0.8, xb - 1, yb + l, xb - hw * 0.6, yb + l * 0.7, xb - hw, yb + 1)
  }
  return P
})()
const hatBack = (dx, dy, st) => blob(sh(HAT_BACK, dx, dy), S(st, { smooth: 0.75 }))

// --- the blink ---------------------------------------------------------------
// Each open eye (a 9.6 x 10.4 white ellipse with an inked upper lid) is covered
// by a patch of the face painted exactly as the portrait paints it (its cel
// tones, the hat's cast shadow, the blush), the lid is drawn shut as a heavy
// downward arch with the faint lower lid kept, and the back fringe's tuft tips
// that hang over the eyes are painted back on top.
const EYES = [[69, 133], [102, 132]]
const patch = (cx, cy) => (st) => ellipse(cx + 0.3, cy - 0.2, 12, 12.6, st)
sprite("aldebran_blink", { w: 170, h: 200 },
  ...EYES.flatMap(([cx, cy]) => {
    const P = patch(cx, cy)
    return [
      clip(P("k"),
        ...cel(face, ["w0", "w1", "w2"], { sd: 6, hd: 7, rim: 0 }),
        clip(face(0, 0, "k"),
          blob([44, 96, 85, 100, 126, 96, 126, 122, 85, 126, 44, 122], { fill: "w0", opacity: 0.8 }),
          sym(85, ellipse(61, 146, 8, 4.5, { fill: "r1", opacity: 0.35 })),
        ),
      ),
      // the closed lid: an arch through the middle of the eye, a little crease at the outer corner
      curve([cx - 9.8, cy + 2.6, cx - 4.5, cy - 3, cx + 3, cy - 3.6, cx + 10.2, cy + 1.4], INK(2.6, 0.3)),
      curve([cx - 7.5, cy + 7.8, cx, cy + 10.4, cx + 8, cy + 7], { ink: { c: "k", w: 1.2, taper: 0.5, wobble: 0 }, opacity: 0.7 }),
      // the hat's back fringe hangs over the eye tops in the portrait, so it is drawn back over the patch
      clip(P("k"),
        hatBack(0, 0, "m0"),
        clip(hatBack(0, 0, "k"), ...TUFTS.map(([x]) => curve([x - 4, 108, x - 7, 120], { stroke: "m1", sw: 1.4, opacity: 0.35 }))),
      ),
    ]
  }))

// --- the glyph's glow (its alpha pulses in the loop) --------------------------
// Clipped just inside the four-point glyph and its two motes, so the light
// stays on what emits it: a soft halo over the ink and the blue sleeve turned
// them muddy on Nilo (AniCraft blends without premultiplying).
sprite("aldebran_glow", { w: 170, h: 200 },
  clip(star(150, 150, 4, 6.3, 2.15, "k"),
    circle(150, 150, 7, { fill: rad(["#ffffff", "#f4ffffee", "#dffbffaa"], { cx: 0.5, cy: 0.5, r: 0.6 }) })),
  clip(circle(140, 158, 1.05, "k"), circle(140, 158, 1.2, "w3")),
  clip(circle(159, 142, 0.85, "k"), circle(159, 142, 1, "w2")))

// --- a four-point sparkle beside the glyph ----------------------------------
// (its own small sprite so AniCraft scales and turns it about its centre;
// placed on the empty canvas above the glyph, continuing the motes' rising trail)
// SPARK_C = [158, 129]
sprite("aldebran_spark", { w: 28, h: 28 },
  star(14, 14, 4, 10, 2.2, { fill: "w2", glow: { r: 5, color: "g0" } }))
