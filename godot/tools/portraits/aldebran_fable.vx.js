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
// The hat: a dome whose lower edge hangs in shaggy tufts. The top is an arc,
// the bottom a zigzag of tufts (longer toward the middle, like a wet mop).
const HAT_C = [85, 84], HAT_R = [76, 50]
function hatPts() {
  const P = []
  for (let a = 182; a <= 358; a += 11) {                       // the dome, left → right over the top
    const r = (a * Math.PI) / 180
    P.push(HAT_C[0] + HAT_R[0] * Math.cos(r), HAT_C[1] + HAT_R[1] * Math.sin(r))
  }
  const tufts = [4, 9, 6, 11, 8, 12, 7, 13, 9, 14, 8, 12, 10, 13, 7, 11, 9, 12, 6, 10, 8, 5]
  const n = tufts.length
  for (let i = 0; i < n; i++) {                                 // the fringe, right → left
    const t = i / (n - 1), x = 160 - 150 * t
    const yb = 98 + 12 * (1 - ((x - 85) / 76) ** 2)            // the brim sags in the middle
    P.push(x, yb, x - 3.4, yb + tufts[i])
  }
  return P
}
const HAT = hatPts()
const hat = (dx, dy, st) => blob(sh(HAT, dx, dy), S(st, { smooth: 0.55 }))

// strands over the mop: curves from the crown down to the brim
const strands = []
for (let i = 0; i < 11; i++) {
  const t = i / 10, x1 = 16 + 138 * t, bend = (t - 0.5) * 30
  strands.push([85 + bend * 0.3, 40, 85 + bend * 1.6, 62, x1 + (0.5 - t) * 10, 90, x1, 108])
}

// the sticks: two big branches on top, a stump on the hat's face, twigs on the sides
const STICK_L = band([[64, 56], [57, 40], [49, 24], [42, 8]], (i, t) => 10.5 - 3 * t)
const STICK_R = band([[108, 52], [112, 34], [113, 18], [112, 4]], (i, t) => 11 - 3 * t)
const STICK_RB = band([[112, 22], [120, 14], [126, 9]], (i, t) => 5.5 - 2 * t)      // a side shoot on the right stick
const STUMP = band([[124, 82], [131, 70], [135, 62]], (i, t) => 8 - 2 * t)
const TWIG_L = band([[22, 84], [12, 74], [6, 64]], (i, t) => 6.5 - 2 * t)
const TWIG_R = band([[152, 86], [162, 80], [167, 72]], (i, t) => 6 - 2 * t)
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
const FACE = furPts(85, 134, 37, 32, 22, 0.07, 8)
const face = (dx, dy, st) => blob(sh(FACE, dx, dy), S(st, { smooth: 0.8 }))

// cheek tufts sticking out of the fur, left side (mirrored)
const TUFT = [52, 126, 36, 122, 28, 132, 34, 146, 48, 152, 56, 142]
const tuft = (dx, dy, st) => blob(sh(TUFT, dx, dy), S(st, { smooth: 0.55 }))

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
    curve([40, 128, 34, 134], INK(1.3, 0.5)), curve([38, 140, 44, 147], INK(1.3, 0.5)),
    tuft(0, 0, EDGE(1.8)),
  ),
  ...cel(face, ["w0", "w1", "w2"], { sd: 6, hd: 7, rim: 0 }),
  clip(face(0, 0, "k"),
    // the hat's cast shadow over the brow, the blush
    blob([44, 96, 85, 100, 126, 96, 126, 118, 85, 122, 44, 118], { fill: "w0", opacity: 0.8 }),
    sym(85, ellipse(62, 142, 8, 4.5, { fill: "r1", opacity: 0.35 })),
  ),
  // a few fur strokes on the cheeks
  sym(85, curve([54, 150, 58, 156], INK(1.2, 0.5)), curve([60, 156, 65, 160], INK(1.2, 0.5))),
  face(0, 0, EDGE(2.2)),
  // ---- the eyes: wide and curious, a violet iris with a pale ring, a star catch-light ----
  ...[[70, 128, 1], [101, 127, -1]].map(([cx, cy, s]) => [
    ellipse(cx, cy, 8.8, 9.6, "w2"),
    circle(cx + 1.2, cy + 1.2, 6.2, "e0"),
    circle(cx + 1.2, cy + 1.2, 6.2, { fill: "none", stroke: "e1", sw: 1.6, opacity: 0.9 }),
    circle(cx + 1.2, cy + 1.2, 4.6, { fill: "none", stroke: "e2", sw: 0.9, opacity: 0.55 }),
    circle(cx + 1.5, cy + 1.6, 3.2, "k"),
    star(cx - 1.4, cy - 1.6, 4, 3.2, 1.1, "w2"),
    circle(cx + 4, cy + 4.5, 1.1, { fill: "w2", opacity: 0.8 }),
    curve([cx - 9, cy - 2, cx - 3, cy - 9.5, cx + 6, cy - 9, cx + 9.5, cy - 3], INK(2.3, 0.3)),   // the upper lid
    curve([cx - 7, cy + 7, cx, cy + 9.6, cx + 7.5, cy + 6.5], { ink: { c: "k", w: 1.2, taper: 0.5, wobble: 0 }, opacity: 0.7 }),
  ]),
  // the brows peek from under the fringe: his left one lifts (our right)
  curve([60, 114, 68, 111, 76, 113], INK(1.9, 0.4)),
  curve([95, 110, 103, 106, 110, 109], INK(1.9, 0.4)),
  // the nose, the mouth
  blob([81.5, 139, 88.5, 139, 85, 144], { fill: "n0", smooth: 0.5 }),
  circle(83.5, 140, 1, { fill: "w2", opacity: 0.6 }),
  curve([85, 144, 85, 147], INK(1.3, 0.4)),
  curve([77, 149, 85, 152, 93, 148], INK(1.9, 0.45)),
  // ---- the hat, over the face: the mop, its strands, the stump ----
  ...cel(hat, ["m0", "m1", "m2", "m3"], { sd: 8, hd: 9, rim: 2 }),
  clip(hat(0, 0, "k"),
    // the fringe falls into shadow at its tips
    blob([6, 100, 85, 108, 164, 100, 164, 125, 85, 128, 6, 125], { fill: "m0", opacity: 0.55 }),
    ...strands.map((p, i) => curve(p, { stroke: "m0", sw: 1.5 + (i % 3) * 0.3, opacity: 0.45, cap: "round" })),
    ...strands.filter((_, i) => i < 6).map((p) => curve(sh(p, -2.5, -1), { stroke: "m3", sw: 1.2, opacity: 0.5, cap: "round" })),
    // a sheen along the crown
    blob([40, 46, 70, 38, 100, 40, 90, 50, 62, 54, 44, 56], { fill: "m3", opacity: 0.6, smooth: 0.8 }),
  ),
  // the tufts' own ink lines so the fringe reads as hanging strands
  ...Array.from({ length: 10 }, (_, i) => { const x = 24 + i * 13.5; return curve([x, 106 - Math.abs(x - 85) * 0.08, x - 2, 114 - Math.abs(x - 85) * 0.08], INK(1.3, 0.5)) }),
  hat(0, 0, EDGE(2.2)),
  // the stump on the hat's face and the roots of the sticks sunk in the mop
  ...wood(STUMP, 1, 0.9),
  ellipse(135, 61.5, 3.3, 2, { fill: "d3" }), ellipse(135, 61.5, 3.3, 2, EDGE(1.1)),
  // ---- the floating glyph over the open hand: subtle, dimensional ----
  star(150, 150, 4, 7, 2.4, { fill: "g0", opacity: 0.9, glow: { r: 4, color: "g0", strength: 2 } }),
  star(150, 150, 4, 3.4, 1.2, { fill: "g1" }),
  circle(141, 158, 1.4, { fill: "g0", opacity: 0.8, glow: { r: 2, color: "g0" } }),
  circle(158, 143, 1.1, { fill: "g0", opacity: 0.7, glow: { r: 2, color: "g0" } }),
  circle(150, 150, 10, { fill: "none", stroke: "g0", sw: 0.8, opacity: 0.4 }),
))
