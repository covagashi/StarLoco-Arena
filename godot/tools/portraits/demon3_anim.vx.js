// S38b: the overlays of Demon III's idle loop (animated in AniCraft like
// Nilo's, owner 2026-11-13). Each is a 170 x 200 layer laid exactly over
// demon3_fable.vx.js's portrait (same palette, same coordinates, the same
// 0.94 head transform): the shut eyes of the blink, the hot core of the
// glowing eyes and the hourglass's sand, and a sparkle on the hourglass's
// gold cap.
//   node <vex>/bin/vex.js build tools/portraits/demon3_anim.vx.js --scales 1,2
// The portrait is a 164 x 194 box + a 3-unit outline with its drawing shifted
// -3, so its export is 170 x 200 and these plain 170 x 200 sprites use the
// portrait's raw coordinates (the shift and the outline cancel).

pal({
  k: "#1c2030",
  f0: "#102a36", f1: "#1d4655", f2: "#2f6879", f3: "#3f8a97",   // the mask face
  i1: "#7fbcc4",                                                 // the muzzle
  q0: "#2e6472", q1: "#4f8f9c", q2: "#7ab8c2", q3: "#a7d8de",   // the face plate
  e0: "#7ef0c6", e1: "#d9fff0", e2: "#ffffff",                  // the glowing eyes
  h0: "#b8ffe4", h1: "#f0fff8",                                  // the eyes' hot core
  y1: "#f2bd3a", y2: "#ffe68a",                                  // gold
  sg0: "#f7d679", sg1: "#fff1b8", sg2: "#fffbe6",                // the sand, lit
  w2: "#ffffff",
})

const EDGE = (sw = 1.8) => ({ fill: "none", stroke: "k", sw, join: "round" })
const INK = (w = 2, taper = 0.45) => ({ ink: { c: "k", w, taper, wobble: 0, vary: 0.25 } })
const sh = (pts, dx, dy) => pts.map((v, i) => v + (i % 2 ? dy : dx))
const S = (st, extra) => ({ ...extra, ...(typeof st === "string" ? { fill: st } : st) })

// the head group of the portrait is scaled 0.94 about [85, 118]: every eye
// and hourglass shape here goes through the same transform
const HEAD = (...items) => tf({ scale: 0.94, origin: [85, 118] }, ...items)

// --- copied from demon3_fable.vx.js so the blink's cover re-paints the face
// --- under the eyes pixel for pixel (same cel stack, same shapes) ----------
function cel(mk, [c0, c1, c2, cr], { sd = 4, hd = 5, rim = 0, hi = true } = {}) {
  const out = []
  if (rim > 0) { out.push(mk(0, 0, cr || c2)); out.push(clip(mk(-rim, -rim * 0.6, "k"), mk(0, 0, c0))) }
  else out.push(mk(0, 0, c0))
  out.push(clip(mk(-sd, -sd * 0.8, "k"), mk(0, 0, c1)))
  if (hi) out.push(clip(mk(-sd, -sd * 0.8, "k"), clip(mk(0, 0, "k"), mk(0, 0, c2), mk(hd, hd * 0.9, c1))))
  return out
}
const HEAD_P = [85, 60, 108, 64, 124, 78, 129, 98, 124, 118, 108, 132, 85, 138, 62, 132, 46, 118, 41, 98, 46, 78, 62, 64]
const head = (dx, dy, st) => blob(sh(HEAD_P, dx, dy), st)
const PLATE = [85, 72, 104, 74, 122, 82, 126, 104, 114, 128, 85, 136, 56, 128, 44, 104, 48, 82, 66, 74]
const plate = (dx, dy, st) => blob(sh(PLATE, dx, dy), S(st, { smooth: 0.55 }))
const face = () => [
  ...cel(head, ["f0", "f1", "f2", "f3"], { sd: 7, hd: 8, rim: 2 }),
  clip(head(0, 0, "k"),
    ...cel(plate, ["q0", "q1", "q2", "q3"], { sd: 6, hd: 7, rim: 1.6 }),
    clip(plate(0, 0, "k"),
      blob([64, 110, 85, 105, 106, 110, 110, 124, 85, 134, 60, 124], { fill: "i1", smooth: 0.7, opacity: 0.7 }),
      sym(85, blob([44, 86, 60, 80, 70, 92, 60, 100, 46, 98], { fill: "q0", smooth: 0.5, opacity: 0.35 })),
    ),
    plate(0, 0, EDGE(1.6)),
  ),
]
const browItems = (P) => [
  blob(P, { fill: "f0", smooth: 0.35 }),
  clip(blob(P, { fill: "k", smooth: 0.35 }), blob(sh(P, 2, -2.5), { fill: "f2", smooth: 0.35, opacity: 0.7 })),
  blob(P, { smooth: 0.35, ...EDGE(1.5) }),
]
const BROW_L = [46, 93, 52, 85, 64, 80.5, 78, 84, 85, 91, 78, 89, 64, 87, 52, 90.5]
const BROW_R = [89, 87, 95, 75, 106, 68.5, 116, 70, 124, 81, 118, 79.5, 108, 76, 97, 82]

// the eyes of the portrait: eye(66, 96, -1, 0) and eye(104, 96, 1, 2)
const EYES = [[66, 96, -1, 0], [104, 96, 1, 2]]
const almond = (cx, cy, dir, tilt, st) => blob(
  [cx - 15 * dir, cy + 1 - tilt, cx - 7 * dir, cy - 6, cx + 4 * dir, cy - 7, cx + 14 * dir, cy - 2 + tilt * 0.3, cx + 7 * dir, cy + 6, cx - 6 * dir, cy + 7],
  S(st, { smooth: 0.55 }))
// the almond grown by ~7 units: what the eye's glow halo reaches
const cover = (cx, cy, dir, tilt, st) => blob(
  [cx - 23 * dir, cy + 1 - tilt, cx - 11 * dir, cy - 13, cx + 4 * dir, cy - 14, cx + 22 * dir, cy - 4 + tilt * 0.3, cx + 13 * dir, cy + 12, cx - 7 * dir, cy + 14],
  S(st, { smooth: 0.55 }))

// the blink: both eyes covered by the face re-painted, the brows drawn back
// over it, and the shut eye as a firm ink line sagging under the brow (an
// examiner closing his eyes, unimpressed), a thin fold above it
sprite("demon3_blink", { w: 170, h: 200 }, HEAD(
  ...EYES.map(([cx, cy, dir, tilt]) => clip(cover(cx, cy, dir, tilt, "k"), ...face())),
  ...browItems(BROW_L), ...browItems(BROW_R),
  curve([84, 93, 86, 87], INK(1.4, 0.5)),
  ...EYES.flatMap(([cx, cy, dir, tilt]) => [
    curve([cx - 13 * dir, cy - 3.5 - tilt * 0.7, cx - 3 * dir, cy - 5.5, cx + 11 * dir, cy - 3.5 + tilt * 0.3], INK(1.1, 0.6)),   // the fold of the lid
    curve([cx - 16 * dir, cy + 1 - tilt, cx - 4 * dir, cy + 4.5, cx + 15 * dir, cy - 0.5 + tilt * 0.3], INK(2.6, 0.25)),        // the shut lids
    curve([cx + 15 * dir, cy - 0.5 + tilt * 0.3, cx + 18 * dir, cy + 2 + tilt * 0.3], INK(1.3, 0.6)),                            // a lash at the inner corner
  ]),
))

// the glow (its alpha pulses in the loop), clipped to what emits light: the
// eyes, a hot white-mint core filling the almond, and the hourglass's sand.
// Nothing spreads over the ink: a soft halo turned it muddy in AniCraft.
const GLASS = [77, 48, 93, 48, 86.5, 60, 93, 72, 77, 72, 83.5, 60]
sprite("demon3_glow", { w: 170, h: 200 }, HEAD(
  ...EYES.map(([cx, cy, dir, tilt]) => clip(almond(cx, cy, dir, tilt, "k"),
    almond(cx, cy, dir, tilt, { fill: rad(["e2", "h1", "h0", "e0"], { cx: 0.5 + 0.05 * dir, cy: 0.5, r: 0.62 }) }),
    ellipse(cx + 1.5 * dir, cy + 0.5, 7.5, 4.6, "w2"),   // a mint rim stays round the hot core
  )),
  tf({ scale: 1.18, origin: [85, 60] },
    clip(poly(GLASS, "k"),
      poly([79, 54, 91, 54, 85, 60], "sg1"), poly([85, 60, 92, 72, 78, 72], "sg0"),
      poly([80, 64, 90, 64, 92, 72, 78, 72], "sg1"),
      poly([82, 55, 88, 55, 85, 59.5], "sg2"), poly([82, 66, 88, 66, 89, 71, 81, 71], "sg2"),   // the hottest grains
    )),
))

// a four-point sparkle, white over gold, as its own small sprite so AniCraft
// scales and turns it about its centre; it sits on the top-left corner of
// the hourglass's upper gold cap, where the top-left light catches the metal
// SPARK_C = [74, 47]
sprite("demon3_spark", { w: 28, h: 28 },
  star(14, 14, 4, 10, 2.2, { fill: "w2", glow: { r: 5, color: "y1" } }))
