// S38b: Aldebrán's talk-window portrait, drawn in vex. Our own drawing after the
// retail portrait's shape (the dimension wanderer: a small white-furred face
// under an enormous shaggy golden mop of a hat with wooden sticks poking out
// of it, a blue traveller's garment with a strap and an orange pouch) in the
// screens' style B: a heavy ink silhouette, lighter inner ink, three cel tones
// per material from one top-left light, a rim light on the shadow side. Same
// shading helpers and canvas as nilo_fable.vx.js so the set reads as one.
// 170 x 200 px = talk_panel.gd FACE_SIZE (the box is 164 x 194 + the 3-unit
// outline on every side).
//   node <vex>/bin/vex.js build tools/portraits/aldebran_fable.vx.js --scales 1,2

pal({
  k: "#1c2030",                                                 // style B ink
  m0: "#6e3a0c", m1: "#b5661c", m2: "#e39a33", m3: "#f8cf6e",   // the mop hat
  w0: "#a9c6da", w1: "#eef6fb", w2: "#ffffff",                  // white fur
  d0: "#2a170c", d1: "#4d2d16", d2: "#7b4b27", d3: "#a97a4e",   // the sticks
  b0: "#22538f", b1: "#3b82c9", b2: "#7fbdf0", b3: "#bfe4ff",   // blue garment
  o0: "#a8420f", o1: "#ef8a28", o2: "#ffc466", o3: "#fff0c4",   // the pouch
  l0: "#5a3714", l1: "#8e5a2a", l2: "#c08a55",                  // the leather strap
  y0: "#b27a12", y1: "#f2bd3a", y2: "#ffe68a",                  // the buckle
  e0: "#2f2170", e1: "#5b49c0", e2: "#9fd4ff",                  // eyes: deep violet, a dimensional ring
  g0: "#55e6ff", g1: "#dffbff",                                 // the floating glyph
  n0: "#3a2a3e",                                                // nose
  r1: "#f0a6b0",                                                // a faint blush
})

const LIGHT = 315
const EDGE = (sw = 1.8) => ({ fill: "none", stroke: "k", sw, join: "round" })
const INK = (w = 2, taper = 0.45) => ({ ink: { c: "k", w, taper, wobble: 0, vary: 0.25 } })

// --- helpers (shared with nilo_fable.vx.js) ----------------------------------
const sh = (pts, dx, dy) => pts.map((v, i) => v + (i % 2 ? dy : dx))
const mir = (pts) => pts.map((v, i) => (i % 2 ? v : 170 - v))   // mirror about the face axis
const S = (st, extra) => ({ ...extra, ...(typeof st === "string" ? { fill: st } : st) })   // style + options

// Cel shading from one shape factory mk(dx, dy, style): the base in its main
// tone, a shadow crescent away from the light, a light crescent toward it and
// (rim > 0) a thin rim light just inside the shadow edge. All clipped to the
// shape, so the asset outline stays clean.
function cel(mk, [c0, c1, c2, cr], { sd = 4, hd = 5, rim = 0, hi = true } = {}) {
  const out = []
  if (rim > 0) { out.push(mk(0, 0, cr || c2)); out.push(clip(mk(-rim, -rim * 0.6, "k"), mk(0, 0, c0))) }
  else out.push(mk(0, 0, c0))
  out.push(clip(mk(-sd, -sd * 0.8, "k"), mk(0, 0, c1)))
  if (hi) out.push(clip(mk(-sd, -sd * 0.8, "k"), clip(mk(0, 0, "k"), mk(0, 0, c2), mk(hd, hd * 0.9, c1))))
  return out
}

// A tapered band along a spine (list of [x, y]) with a width per index →
// one closed polygon with a rounded tip. For sticks, arms, the strap.
function band(spine, width, cap = true) {
  const L = [], R = [], n = spine.length
  for (let i = 0; i < n; i++) {
    const [x, y] = spine[i]
    const [ax, ay] = spine[Math.max(0, i - 1)], [bx, by] = spine[Math.min(n - 1, i + 1)]
    let nx = -(by - ay), ny = bx - ax
    const m = Math.hypot(nx, ny) || 1
    nx /= m; ny /= m
    const w = width(i, i / (n - 1)) / 2
    L.push(x + nx * w, y + ny * w)
    R.unshift(x - nx * w, y - ny * w)
  }
  if (cap) {
    // a half circle around the last point, from L's side to R's side
    const [x, y] = spine[n - 1], [ax, ay] = spine[n - 2]
    const w = width(n - 1, 1) / 2, a0 = Math.atan2(y - ay, x - ax) + Math.PI / 2
    for (let j = 1; j < 6; j++) { const a = a0 - (Math.PI * j) / 6; L.push(x + w * Math.cos(a), y + w * Math.sin(a)) }
  }
  return [...L, ...R]
}
const flat = (sp) => sp.flat()

// --- geometry ---------------------------------------------------------------
// The hat: a bulging dome (a few bumps so it is not a perfect ellipse) whose
// lower edge hangs in fat drooping tufts, longer toward the middle, like a
// wet mop. The fringe is drawn twice: a dark back layer and a lit front one.
const HAT_C = [85, 82], HAT_R = [76, 52]
function domePts(dx = 0, dy = 0, bump = 1) {
  const P = []
  for (let a = 184; a <= 356; a += 8) {                        // left → right over the top
    const r = (a * Math.PI) / 180, k = 1 + bump * (0.035 * Math.sin(r * 3 + 0.8) + 0.02 * Math.sin(r * 7))
    P.push(HAT_C[0] + HAT_R[0] * k * Math.cos(r) + dx, HAT_C[1] + HAT_R[1] * k * Math.sin(r) + dy)
  }
  return P
}
// tufts: [x of the tuft's root, its length, its half width]
const TUFTS = [[158, 14, 5], [147, 34, 6.5], [134, 16, 5.5], [121, 19, 6.5], [108, 15, 6], [95, 21, 7], [81, 17, 6.5], [68, 22, 7], [55, 16, 6], [42, 19, 6.5], [30, 20, 5.5], [19, 38, 6], [10, 16, 4.5]]
function hatPts(tuftScale = 1) {
  const P = domePts()
  for (const [x, len, hw] of TUFTS) {                           // the fringe, right → left
    const yb = 95 + 10 * (1 - ((x - 85) / 76) ** 2)            // the brim sags in the middle
    const l = len * tuftScale
    P.push(x + hw, yb, x + hw * 0.55, yb + l * 0.8, x - 0.5, yb + l, x - hw * 0.6, yb + l * 0.75, x - hw, yb + 1)
  }
  return P
}
const HAT = hatPts(0.72)
const hat = (dx, dy, st) => blob(sh(HAT, dx, dy), S(st, { smooth: 0.75 }))
// the back fringe: the same tufts, offset half a tuft and longer, in shadow
const HAT_BACK = (() => {
  const P = domePts()
  for (const [x, len, hw] of TUFTS) {
    const xb = x - 6.5, yb = 95 + 10 * (1 - ((xb - 85) / 76) ** 2), l = len * 0.95 + 2
    P.push(xb + hw, yb, xb + hw * 0.5, yb + l * 0.8, xb - 1, yb + l, xb - hw * 0.6, yb + l * 0.7, xb - hw, yb + 1)
  }
  return P
})()
const hatBack = (dx, dy, st) => blob(sh(HAT_BACK, dx, dy), S(st, { smooth: 0.75 }))

// strands over the mop: wavy clumps from the crown down to the brim
const strands = []
for (let i = 0; i < 9; i++) {
  const t = i / 8, x1 = 18 + 134 * t, bend = (t - 0.5) * 34, wv = (i % 2 ? 1 : -1) * 4
  strands.push([85 + bend * 0.25, 36, 85 + bend * 1.1 + wv, 54, 85 + bend * 1.9 - wv, 72, x1 + (0.5 - t) * 14 + wv * 0.5, 90, x1, 106])
}

// the sticks: two big branches on top, a stump on the hat's face, twigs on the sides
const STICK_L = band([[64, 56], [57, 40], [49, 24], [42, 8]], (i, t) => 10.5 - 3 * t)
const STICK_R = band([[108, 52], [112, 34], [113, 18], [112, 4]], (i, t) => 11 - 3 * t)
const STICK_RB = band([[112, 22], [120, 14], [126, 9]], (i, t) => 5.5 - 2 * t)      // a side shoot on the right stick
const STUMP = band([[124, 82], [131, 70], [135, 62]], (i, t) => 8 - 2 * t)
const TWIG_L = band([[22, 84], [12, 74], [6, 64]], (i, t) => 6.5 - 2 * t)
const TWIG_R = band([[152, 88], [160, 82], [164, 74]], (i, t) => 6 - 2 * t)
const stick = (P) => (dx, dy, st) => poly(sh(P, dx, dy), st)

// the face: a scalloped oval of white fur, the top hidden by the hat's fringe
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

// cheek tufts sticking out of the fur, left side (mirrored)
const TUFT = [54, 124, 44, 120, 37, 126, 32, 135, 35, 146, 44, 153, 56, 150]
const tuft = (dx, dy, st) => blob(sh(TUFT, dx, dy), S(st, { smooth: 0.7 }))

// body, collar, arms, hands
const BODY = [60, 160, 110, 160, 122, 174, 126, 200, 44, 200, 48, 174]
const body = (dx, dy, st) => blob(sh(BODY, dx, dy), S(st, { smooth: 0.5 }))
const COLLAR = furPts(85, 163, 30, 9, 18, 0.14, 0)
const collar = (dx, dy, st) => blob(sh(COLLAR, dx, dy), S(st, { smooth: 0.8 }))
const ARM_L = band([[54, 176], [44, 184], [36, 196]], (i, t) => 13 - 2 * t, false)
const ARM_R = band([[118, 176], [132, 180], [142, 176]], (i, t) => 12 - 2 * t, false)
const HAND_L = furPts(31, 200, 9, 7, 12, 0.12, 0)
const HAND_R = furPts(148, 170, 9, 7.5, 12, 0.12, 15)
const hand = (P) => (dx, dy, st) => blob(sh(P, dx, dy), S(st, { smooth: 0.8 }))

// the strap across the chest and the pouch hanging from it
const STRAP = band([[62, 162], [78, 176], [96, 188], [118, 200]], () => 9, false)
const POUCH = [88, 178, 108, 178, 112, 190, 108, 200, 88, 200, 84, 190]
const pouch = (dx, dy, st) => blob(sh(POUCH, dx, dy), S(st, { smooth: 0.5 }))
const FLAP = [86, 176, 110, 176, 112, 186, 98, 190, 84, 186]
const flap = (dx, dy, st) => blob(sh(FLAP, dx, dy), S(st, { smooth: 0.5 }))

// the stick's wood: base tones, a dark side, a light edge, bark lines, an ink edge
const wood = (P, dir = 1, rim = 1.2) => [
  ...cel(stick(P), ["d1", "d2", "d3", "d3"], { sd: 3, hd: 3, rim }),
  clip(poly(P, "k"), poly(sh(P, 2.5 * dir, 1), { fill: "d0", opacity: 0.55 })),
  poly(P, EDGE(1.7)),
]

sprite("aldebran", { w: 164, h: 194, scale: 1, outline: "k", ow: 3 }, tf({ x: -3, y: -3 },
  // ---- behind everything: the sticks that rise out of the hat ----
  ...wood(STICK_L, 1),
  curve([44, 12, 47, 20, 46, 28], { stroke: "d0", sw: 1.1, opacity: 0.6 }),
  curve([53, 30, 55, 38], { stroke: "d0", sw: 1.1, opacity: 0.6 }),
  ...wood(STICK_RB, 1, 0.9),
  ...wood(STICK_R, 1),
  curve([114, 10, 116, 18, 115, 26], { stroke: "d0", sw: 1.1, opacity: 0.6 }),
  curve([109, 36, 110, 44], { stroke: "d0", sw: 1.1, opacity: 0.6 }),
  // cut ends: a pale ring of fresh wood at the tips
  ellipse(42, 8.5, 4.2, 2.2, { fill: "d3" }), ellipse(42, 8.5, 4.2, 2.2, EDGE(1.2)),
  ellipse(112, 4.5, 4.4, 2.2, { fill: "d3" }), ellipse(112, 4.5, 4.4, 2.2, EDGE(1.2)),
  ...wood(TWIG_L, -1, 0.9),
  ...wood(TWIG_R, 1, 0.9),
  // ---- the body, the arms ----
  ...cel(body, ["b0", "b1", "b2", "b3"], { sd: 6, hd: 7, rim: 1.6 }),
  clip(body(0, 0, "k"), blob([60, 160, 110, 160, 116, 170, 85, 176, 54, 170], { fill: "b0", opacity: 0.5 })),   // under the collar
  body(0, 0, EDGE(2)),
  poly(ARM_L, "b1"), clip(poly(ARM_L, "k"), poly(sh(ARM_L, 4, 2), "b0"), poly(sh(ARM_L, -6, -4), "b2")), poly(ARM_L, EDGE(1.8)),
  poly(ARM_R, "b1"), clip(poly(ARM_R, "k"), poly(sh(ARM_R, 0, 4), "b0"), poly(sh(ARM_R, -2, -5), "b2")), poly(ARM_R, EDGE(1.8)),
  // the strap, the buckle
  poly(STRAP, "l1"),
  clip(poly(STRAP, "k"), poly(sh(STRAP, 3, 0), "l0"), poly(sh(STRAP, -6, -1), "l2")),
  line(flat([[64, 164], [80, 178], [98, 190], [118, 200]].map(([x, y]) => [x + 1, y - 3])), { stroke: "l0", sw: 0.9, opacity: 0.5, dash: [2, 2] }),
  poly(STRAP, EDGE(1.6)),
  tf({ rot: 40, origin: [76, 170] },
    rect(72, 166, 8, 8, { fill: "y1", r: 1.5 }), rect(72, 166, 8, 8, { fill: "none", stroke: "y0", sw: 1, r: 1.5 }),
    rect(72, 166, 8, 8, { fill: "none", stroke: "k", sw: 1.1, r: 1.5 })),
  // the pouch
  ...cel(pouch, ["o0", "o1", "o2", "o3"], { sd: 4, hd: 4, rim: 1.4 }),
  pouch(0, 0, EDGE(1.8)),
  ...cel(flap, ["o0", "o1", "o2"], { sd: 3, hd: 3.5, rim: 0 }),
  flap(0, 0, EDGE(1.6)),
  circle(98, 187, 2, "y1"), circle(98, 187, 2, EDGE(1)),
  // the hands: white fur, the right one open with a glyph floating above it
  ...cel(hand(HAND_L), ["w0", "w1", "w2"], { sd: 3, hd: 3, rim: 0 }), hand(HAND_L)(0, 0, EDGE(1.7)),
  ...cel(hand(HAND_R), ["w0", "w1", "w2"], { sd: 3, hd: 3, rim: 0 }), hand(HAND_R)(0, 0, EDGE(1.7)),
  curve([144, 166, 148, 168], INK(1.2, 0.5)), curve([150, 165, 153, 168], INK(1.2, 0.5)),
  // ---- the collar of fur, then the face and its cheek tufts ----
  ...cel(collar, ["w0", "w1", "w2"], { sd: 4, hd: 4, rim: 0 }),
  collar(0, 0, EDGE(1.8)),
  sym(85,
    ...cel(tuft, ["w0", "w1", "w2"], { sd: 3.5, hd: 4, rim: 0 }),
    curve([42, 124, 38, 130], INK(1.3, 0.5)), curve([38, 136, 40, 143], INK(1.3, 0.5)), curve([44, 148, 50, 152], INK(1.2, 0.5)),
    tuft(0, 0, EDGE(1.8)),
  ),
  ...cel(face, ["w0", "w1", "w2"], { sd: 6, hd: 7, rim: 0 }),
  clip(face(0, 0, "k"),
    // the hat's cast shadow over the brow, the blush
    blob([44, 96, 85, 100, 126, 96, 126, 122, 85, 126, 44, 122], { fill: "w0", opacity: 0.8 }),
    sym(85, ellipse(61, 146, 8, 4.5, { fill: "r1", opacity: 0.35 })),
  ),
  // a few fur strokes on the cheeks
  sym(85, curve([54, 150, 58, 156], INK(1.2, 0.5)), curve([60, 156, 65, 160], INK(1.2, 0.5))),
  face(0, 0, EDGE(2.2)),
  // ---- the eyes: wide and curious, a violet iris with a pale ring, a star catch-light ----
  ...[[69, 133, 1], [102, 132, -1]].map(([cx, cy, s]) => [
    ellipse(cx, cy, 9.6, 10.4, "w2"),
    circle(cx + 1.2, cy + 1.4, 7, "e0"),
    clip(circle(cx + 1.2, cy + 1.4, 7, "k"), circle(cx - 1, cy - 1, 7, "e1")),
    circle(cx + 1.2, cy + 1.4, 5.1, { fill: "none", stroke: "e2", sw: 1, opacity: 0.6 }),
    circle(cx + 1.5, cy + 1.8, 3.6, "k"),
    star(cx - 1.6, cy - 1.6, 4, 3.6, 1.2, "w2"),
    circle(cx + 4.4, cy + 5, 1.2, { fill: "w2", opacity: 0.85 }),
    curve([cx - 10, cy - 2, cx - 3.5, cy - 10.4, cx + 6, cy - 9.8, cx + 10.5, cy - 3], INK(2.4, 0.3)),   // the upper lid
    curve([cx - 7.5, cy + 7.8, cx, cy + 10.4, cx + 8, cy + 7], { ink: { c: "k", w: 1.2, taper: 0.5, wobble: 0 }, opacity: 0.7 }),
  ]),
  // the brows peek from under the fringe: his left one lifts (our right)
  curve([59, 119, 68, 116, 77, 118], INK(1.9, 0.4)),
  curve([95, 116, 103, 112, 111, 115], INK(1.9, 0.4)),
  // the nose, the mouth
  blob([81, 143, 89, 143, 85, 148.5], { fill: "n0", smooth: 0.5 }),
  circle(83.5, 144, 1, { fill: "w2", opacity: 0.6 }),
  curve([85, 148.5, 85, 151.5], INK(1.3, 0.4)),
  curve([76, 152, 85, 157, 95, 151.5], INK(2, 0.4)),
  curve([94, 151.5, 96.5, 149], INK(1.4, 0.5)),
  // ---- the hat, over the face: the back fringe, the mop, its strands ----
  hatBack(0, 0, "m0"),
  clip(hatBack(0, 0, "k"), blob(sh(domePts(0, 0, 0), 0, 0), { fill: "m1", opacity: 0.0 }),
    ...TUFTS.map(([x]) => curve([x - 4, 108, x - 7, 120], { stroke: "m1", sw: 1.4, opacity: 0.35 }))),
  ...cel(hat, ["m1", "m2", "m3", "m3"], { sd: 8, hd: 9, rim: 2 }),
  clip(hat(0, 0, "k"),
    // the fringe falls into shadow at its tips, the bottom of the dome too
    blob([0, 104, 85, 110, 170, 104, 170, 140, 85, 145, 0, 140], { fill: "m0", opacity: 0.5 }),
    blob([0, 90, 85, 100, 170, 90, 170, 140, 85, 145, 0, 140], { fill: "m1", opacity: 0.55 }),
    blob([118, 36, 150, 48, 166, 80, 164, 112, 140, 124, 128, 100, 126, 70], { fill: "m0", opacity: 0.3, smooth: 0.8 }),
    ...strands.map((p, i) => curve(p, { stroke: "m1", sw: 1.5 + (i % 3) * 0.4, opacity: 0.42, cap: "round" })),
    ...strands.filter((_, i) => i < 5).map((p) => curve(sh(p, -2.5, -1), { stroke: "m3", sw: 1.3, opacity: 0.6, cap: "round" })),
    // short clumps of hair on the dome
    ...[[30, 70], [50, 58], [70, 50], [96, 48], [118, 56], [140, 70], [60, 84], [112, 86], [86, 72]].map(([x, y], i) =>
      curve([x - 3, y - 6, x + 1, y, x - 2, y + 7], { stroke: i < 5 ? "m3" : "m0", sw: 1.3, opacity: 0.45, cap: "round" })),
    // a sheen along the crown
    blob([36, 48, 64, 36, 98, 36, 88, 46, 60, 52, 40, 58], { fill: "m3", opacity: 0.65, smooth: 0.8 }),
  ),
  // ink lines splitting the tufts so the fringe reads as hanging strands
  ...TUFTS.slice(1, -1).map(([x, len]) => { const yb = 95 + 10 * (1 - ((x - 85) / 76) ** 2); return curve([x + 2.5, yb + 1, x + 1, yb + len * 0.42], INK(1.3, 0.5)) }),
  hat(0, 0, EDGE(2.2)),
  // the stump on the hat's face and the roots of the sticks sunk in the mop
  ...wood(STUMP, 1, 0.9),
  ellipse(135, 61.5, 3.3, 2, { fill: "d3" }), ellipse(135, 61.5, 3.3, 2, EDGE(1.1)),
  // ---- the floating glyph over the open hand: subtle, dimensional ----
  star(150, 150, 4, 7, 2.4, { fill: "g0" }),
  star(150, 150, 4, 3.4, 1.2, { fill: "g1" }),
  star(150, 150, 4, 7, 2.4, { fill: "none", stroke: "k", sw: 1.2, join: "round" }),
  circle(140, 158, 1.5, { fill: "g0" }), circle(140, 158, 1.5, EDGE(1)),
  circle(159, 142, 1.2, { fill: "g1" }), circle(159, 142, 1.2, EDGE(1)),
))
