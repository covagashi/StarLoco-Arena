// S38b: Demon III's talk-window portrait, drawn in vex. No retail art exists
// for him, so he is designed as a sibling of Demon I (the retail portrait:
// a bat-like demon, dark mask face, glowing eyes, high collar, white bib with
// the numeral, misty base) in the screens' style B: a heavy ink silhouette,
// lighter inner ink, three cel tones per material from one top-left light, a
// rim light on the shadow side. He is the examiner of newcomers: deep teal
// instead of Demon I's indigo, three plume-horns for "III", a stern raised
// brow, an hourglass on the crown where his brother wears a skull.
// 170 x 200 px = talk_panel.gd FACE_SIZE (the box is 164 x 194 + the 3-unit
// outline on every side).
//   node <vex>/bin/vex.js build tools/portraits/demon3_fable.vx.js --scales 1,2

pal({
  k: "#1c2030",                                                 // style B ink
  f0: "#102a36", f1: "#1d4655", f2: "#2f6879", f3: "#3f8a97",   // the mask face, deep teal
  i0: "#4a8a96", i1: "#7fbcc4",                                 // the ears' inside, the muzzle
  q0: "#2e6472", q1: "#4f8f9c", q2: "#7ab8c2", q3: "#a7d8de",   // the mask-like face plate
  r0: "#1a5462", r1: "#2a7d8f", r2: "#55aab8", r3: "#8ed2db",   // the teal collar (Demon I's is purple)
  p0: "#4f9a94", p1: "#9fd9cf", p2: "#d6f3ec", p3: "#f4fffb",   // the plume horns, seafoam
  e0: "#7ef0c6", e1: "#d9fff0", e2: "#ffffff",                  // the glowing eyes
  c0: "#3f4f78", c1: "#6a7aa6", c2: "#9eaccf", c3: "#c8d2ea",   // the robe and collar, dusky blue
  w0: "#b3bfd3", w1: "#edf1f8", w2: "#ffffff",                  // the white bib
  n0: "#1f5f6e", n1: "#2f8597",                                 // the numeral
  d0: "#1a1c33", d1: "#2e3156", d2: "#4a4e7e",                  // the claws
  y0: "#b27a12", y1: "#f2bd3a", y2: "#ffe68a",                  // gold
  g0: "#9fc9d6", g1: "#e2f5fa",                                 // the hourglass' glass
  s0: "#d9a84a", s1: "#f6d98a",                                 // sand
  m0: "#8ea9c2", m1: "#c9dbea", m2: "#eef5fb",                  // the mist
  t0: "#c26b7a",                                                // the tongue / inner mouth
})

const LIGHT = 315
const EDGE = (sw = 1.8) => ({ fill: "none", stroke: "k", sw, join: "round" })
const INK = (w = 2, taper = 0.45) => ({ ink: { c: "k", w, taper, wobble: 0, vary: 0.25 } })

// --- helpers (shared with nilo_fable.vx.js) ---------------------------------
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
// one closed polygon with a rounded tip. For horns, curls, arms.
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
    const [x, y] = spine[n - 1], [ax, ay] = spine[n - 2]
    const w = width(n - 1, 1) / 2, a0 = Math.atan2(y - ay, x - ax) + Math.PI / 2
    for (let j = 1; j < 6; j++) { const a = a0 - (Math.PI * j) / 6; L.push(x + w * Math.cos(a), y + w * Math.sin(a)) }
  }
  return [...L, ...R]
}
const flat = (sp) => sp.flat()
// a smooth spine through control points, n samples (Catmull-Rom)
function spine(ctrl, n = 24) {
  const P = ctrl, out = []
  for (let s = 0; s < n; s++) {
    const t = s / (n - 1) * (P.length - 1), i = Math.min(P.length - 2, Math.floor(t)), u = t - i
    const p0 = P[Math.max(0, i - 1)], p1 = P[i], p2 = P[i + 1], p3 = P[Math.min(P.length - 1, i + 2)]
    const f = (a, b, c, d) => 0.5 * (2 * b + (-a + c) * u + (2 * a - 5 * b + 4 * c - d) * u * u + (-a + 3 * b - 3 * c + d) * u * u * u)
    out.push([f(p0[0], p1[0], p2[0], p3[0]), f(p0[1], p1[1], p2[1], p3[1])])
  }
  return out
}
// ridges across a band: short lines perpendicular to the spine, for the plumes' puffy segments
function ridges(sp, width, idx, st, grow = 2) {
  return idx.map((i) => {
    const [x, y] = sp[i], [ax, ay] = sp[i - 1], [bx, by] = sp[i + 1]
    let nx = -(by - ay), ny = bx - ax; const m = Math.hypot(nx, ny) || 1; nx /= m; ny /= m
    const w = width(i, i / (sp.length - 1)) / 2 + grow
    return curve([x + nx * w, y + ny * w, x + nx * w * 0.2, y + ny * w * 0.2 + 2.2, x - nx * w, y - ny * w], st)
  })
}

// --- geometry ---------------------------------------------------------------
// the three plume horns: a tall one in the middle, two leaning out
const puff = (t) => 1 + 0.24 * Math.abs(Math.sin(t * Math.PI * 4.5))   // scalloped edge: the plume's puffy segments
const PL_C = spine([[85, 112], [85, 80], [86, 50], [85, 24], [85, 8]], 60)
const plcW = (i, t) => (36 - 26 * t ** 0.85) * puff(t)
const plC = (dx, dy, st) => blob(sh(band(PL_C, plcW), dx, dy), S(st, { smooth: 0.5 }))
const PL_L = spine([[66, 114], [58, 88], [47, 62], [36, 40], [27, 22]], 60)
const pllW = (i, t) => (32 - 23 * t ** 0.85) * puff(t)
const plL = (dx, dy, st) => blob(sh(band(PL_L, pllW), dx, dy), S(st, { smooth: 0.5 }))

// the ears: tall, bat-like, pointing up and out
const EAR = [66, 86, 50, 56, 36, 40, 34, 64, 42, 90, 56, 102]
const ear = (dx, dy, st) => blob(sh(EAR, dx, dy), S(st, { smooth: 0.3 }))
const EAR_IN = [60, 88, 50, 64, 40, 52, 40, 72, 46, 88]

// the head: a wide mask, pointed cheeks, a short chin
const HEAD = [85, 60, 108, 64, 124, 78, 129, 98, 124, 118, 108, 132, 85, 138, 62, 132, 46, 118, 41, 98, 46, 78, 62, 64]
const head = (dx, dy, st) => blob(sh(HEAD, dx, dy), st)
const PLATE = [85, 72, 104, 74, 122, 82, 126, 104, 114, 128, 85, 136, 56, 128, 44, 104, 48, 82, 66, 74]
const plate = (dx, dy, st) => blob(sh(PLATE, dx, dy), S(st, { smooth: 0.55 }))

// the collar: a high ruff around the neck, open at the front
const COLLAR = [36, 144, 52, 126, 70, 134, 85, 130, 100, 134, 118, 126, 134, 144, 128, 156, 85, 152, 42, 156]
const collar = (dx, dy, st) => blob(sh(COLLAR, dx, dy), S(st, { smooth: 0.45 }))

// the robe: shoulders falling to the base
const BODY = [36, 150, 85, 146, 134, 150, 152, 172, 158, 200, 12, 200, 18, 172]
const body = (dx, dy, st) => blob(sh(BODY, dx, dy), S(st, { smooth: 0.5 }))

// the white bib down the front
const BIB = [62, 150, 85, 154, 108, 150, 116, 200, 54, 200]
const bib = (dx, dy, st) => blob(sh(BIB, dx, dy), S(st, { smooth: 0.35 }))

// the sleeves: the left arm falling out and down, the hand turning in
const ARM = band(spine([[46, 158], [34, 166], [26, 178], [30, 190]], 16), (i, t) => 24 - 6 * t, false)
const arm = (dx, dy, st) => poly(sh(ARM, dx, dy), st)
const HAND = [16, 176, 32, 171, 48, 175, 55, 185, 48, 194, 30, 197, 15, 190]
const hand = (dx, dy, st) => blob(sh(HAND, dx, dy), S(st, { smooth: 0.5 }))
const CLAWS = [[17, 188, 9, 204, 28, 193], [29, 193, 30, 210, 41, 193], [42, 192, 53, 205, 52, 186]]

// the mist at the base
const MIST = [0, 194, 12, 188, 26, 193, 44, 186, 66, 192, 85, 186, 104, 192, 122, 186, 140, 192, 156, 187, 170, 194, 170, 200, 0, 200]
const mist = (dx, dy, st) => blob(sh(MIST, dx, dy), S(st, { smooth: 0.7 }))

// roman numeral III: three bars with serifs
function numeral(st) {
  const out = []
  for (const x of [71, 85, 99]) {
    out.push(poly([x - 3, 160, x + 3, 160, x + 3, 192, x - 3, 192], st))
    out.push(rect(x - 5.5, 160, 11, 2.8, S(st, { r: 0.6 })))
    out.push(rect(x - 5.5, 189.2, 11, 2.8, S(st, { r: 0.6 })))
  }
  return out
}

// a brow tuft: lighter fur, shaded, inked
const browItems = (P) => [
  blob(P, { fill: "f0", smooth: 0.35 }),
  clip(blob(P, { fill: "k", smooth: 0.35 }), blob(sh(P, 2, -2.5), { fill: "f2", smooth: 0.35, opacity: 0.7 })),
  blob(P, { smooth: 0.35, ...EDGE(1.5) }),
]

// an eye: a slanted almond of pure glow, no pupil (the family's eyes), a hot
// white core; the heavy lid is an ink line. (cx, cy) its center, dir -1 for
// the left eye, tilt lifts the outer corner
function eye(cx, cy, dir, tilt) {
  const P = [cx - 15 * dir, cy + 1 - tilt, cx - 7 * dir, cy - 6, cx + 4 * dir, cy - 7, cx + 14 * dir, cy - 2 + tilt * 0.3, cx + 7 * dir, cy + 6, cx - 6 * dir, cy + 7]
  const e = (st) => blob(P, S(st, { smooth: 0.55 }))
  return [
    e({ fill: "e0", glow: { r: 5, color: "e0", strength: 2 } }),
    clip(e("k"),
      blob([cx - 11 * dir, cy + 2 - tilt * 0.6, cx - 4 * dir, cy - 4, cx + 6 * dir, cy - 4.5, cx + 12 * dir, cy - 1, cx + 6 * dir, cy + 5, cx - 5 * dir, cy + 6], { fill: "e1", smooth: 0.55 }),
      ellipse(cx + 1.5 * dir, cy + 0.5, 6, 3.8, "e2"),
    ),
    curve([cx - 16 * dir, cy + 1 - tilt, cx - 5 * dir, cy - 7.5, cx + 15 * dir, cy - 2 + tilt * 0.3], INK(2.2, 0.3)),   // the heavy lid
    curve([cx - 9 * dir, cy + 7.5, cx + 2 * dir, cy + 8.5, cx + 12 * dir, cy + 5.5], INK(1.3, 0.5)),
  ]
}

sprite("demon3", { w: 164, h: 194, scale: 1, outline: "k", ow: 3 }, tf({ x: -3, y: -3 },
  // ---- the mist, behind everything that is not the robe ----
  // ---- the plume horns, behind the head ----
  sym(85,
    ...cel(plL, ["p0", "p1", "p2", "p3"], { sd: 5, hd: 5.5, rim: 1.6 }),
    clip(plL(0, 0, "k"), ...ridges(PL_L, pllW, [13, 26, 39, 52], { stroke: "p0", sw: 2.2, opacity: 0.75 })),
    clip(plL(0, 0, "k"), curve(flat(PL_L.slice(8, 54).map(([x, y]) => [x - 5, y - 1])), { stroke: "p3", sw: 2.2, opacity: 0.7, cap: "round" })),
    plL(0, 0, EDGE(2)),
  ),
  ...cel(plC, ["p0", "p1", "p2", "p3"], { sd: 5.5, hd: 6, rim: 1.6 }),
  clip(plC(0, 0, "k"), ...ridges(PL_C, plcW, [13, 26, 39, 52], { stroke: "p0", sw: 2.2, opacity: 0.75 })),
  clip(plC(0, 0, "k"), curve(flat(PL_C.slice(6, 54).map(([x, y]) => [x - 6.5, y])), { stroke: "p3", sw: 2.4, opacity: 0.7, cap: "round" })),
  plC(0, 0, EDGE(2)),
  // ---- the robe, the collar, the bib ----
  ...cel(body, ["c0", "c1", "c2", "c3"], { sd: 7, hd: 8, rim: 1.8 }),
  clip(body(0, 0, "k"), ...[52, 118].map((x) => curve([x, 160, x - (x < 85 ? 8 : -8), 200], { stroke: "c0", sw: 1.6, opacity: 0.5 }))),
  body(0, 0, EDGE(2)),
  ...cel(bib, ["w0", "w1", "w2"], { sd: 6, hd: 7, rim: 0 }),
  ...numeral({ fill: "n0" }),
  clip(bib(0, 0, "k"), ...numeral({ fill: "n1", opacity: 0.55 }).map((s) => tf({ x: -1.2, y: -1.2 }, s))),
  bib(0, 0, EDGE(2)),
  ...cel(collar, ["r0", "r1", "r2", "r3"], { sd: 5, hd: 5, rim: 1.6 }),
  clip(collar(0, 0, "k"), blob([44, 150, 85, 138, 126, 150, 124, 160, 46, 160], { fill: "r0", opacity: 0.55 })),   // the chin's shadow in the ruff
  curve([52, 128, 56, 140, 54, 152], { stroke: "r0", sw: 1.3, opacity: 0.6 }), curve([118, 128, 114, 140, 116, 152], { stroke: "r0", sw: 1.3, opacity: 0.6 }),
  collar(0, 0, EDGE(2)),
  // ---- the mist over the robe's hem, the claws in front of it ----
  ...cel(mist, ["m0", "m1", "m2"], { sd: 5, hd: 6, rim: 0 }),
  clip(mist(0, 0, "k"), ...[22, 60, 100, 140].map((x) => ellipse(x, 202, 14, 7, { fill: "m0", opacity: 0.35 }))),
  mist(0, 0, EDGE(2)),
  // ---- the arms, the claws ----
  sym(85,
    ...cel(arm, ["c0", "c1", "c2", "c3"], { sd: 5, hd: 5, rim: 1.4 }),
    arm(0, 0, EDGE(1.8)),
    ...cel(hand, ["c0", "c1", "c2", "c3"], { sd: 4, hd: 4.5, rim: 1.2 }),
    hand(0, 0, EDGE(1.8)),
    ...CLAWS.map((c) => [poly(c, "d1"), clip(poly(c, "k"), poly(sh(c, 2.5, 0), "d0")), poly(c, EDGE(1.5))]),
  ),
  // ---- the head group (ears, head, hourglass, eyes, mouth), a touch smaller so the plumes rule ----
  tf({ scale: 0.94, origin: [85, 118] },
  // ---- the ears ----
  sym(85,
    ...cel(ear, ["f0", "f1", "f2", "f3"], { sd: 4, hd: 4, rim: 1.4 }),
    blob(EAR_IN, { fill: "i0", smooth: 0.35 }),
    clip(blob(EAR_IN, { fill: "k", smooth: 0.35 }), blob(sh(EAR_IN, 3, 4), { fill: "i1", smooth: 0.35, opacity: 0.8 })),
    curve([58, 86, 48, 66, 40, 54], INK(1.3, 0.5)),
    ear(0, 0, EDGE(2)),
  ),
  // ---- the head ----
  ...cel(head, ["f0", "f1", "f2", "f3"], { sd: 7, hd: 8, rim: 2 }),
  clip(head(0, 0, "k"),
    // the muzzle, a little lighter; a dark mask band across the eyes
    // the face plate: a lighter mask from the brows to the chin, pointed at the temples
    ...cel(plate, ["q0", "q1", "q2", "q3"], { sd: 6, hd: 7, rim: 1.6 }),
    clip(plate(0, 0, "k"),
      blob([64, 110, 85, 105, 106, 110, 110, 124, 85, 134, 60, 124], { fill: "i1", smooth: 0.7, opacity: 0.7 }),
      blob([58, 128, 85, 131, 114, 125, 116, 134, 85, 142, 54, 134], { fill: "q0", smooth: 0.6, opacity: 0.6 }),
      sym(85, blob([44, 86, 60, 80, 70, 92, 60, 100, 46, 98], { fill: "q0", smooth: 0.5, opacity: 0.35 })),   // the eye sockets
    ),
    plate(0, 0, EDGE(1.6)),
    // cheek fur, lighter tufts at the jaw
    sym(85, blob([44, 112, 56, 112, 62, 124, 54, 130], { fill: "f3", smooth: 0.4, opacity: 0.45 })),
  ),
  head(0, 0, EDGE(2.2)),
  // ---- the hourglass on the crown ----
  tf({ scale: 1.18, origin: [85, 60] },
  poly([77, 48, 93, 48, 86.5, 60, 93, 72, 77, 72, 83.5, 60], { fill: "g1", opacity: 0.9 }),
  clip(poly([77, 48, 93, 48, 86.5, 60, 93, 72, 77, 72, 83.5, 60], "k"),
    poly([88, 48, 93, 48, 86.5, 60, 93, 72, 88, 72, 85, 60], { fill: "g0", opacity: 0.8 }),
    poly([79, 54, 91, 54, 85, 60], "s1"), poly([85, 60, 92, 72, 78, 72], "s0"),
    poly([80, 64, 90, 64, 92, 72, 78, 72], "s1"),
  ),
  poly([77, 48, 93, 48, 86.5, 60, 93, 72, 77, 72, 83.5, 60], EDGE(1.4)),
  ...[[46], [69.5]].map(([y]) => [rect(74, y, 22, 3.6, { fill: "y1", r: 1.2 }), rect(74, y + 1.8, 22, 1.8, { fill: "y0", r: 0.8, opacity: 0.7 }), rect(74, y, 22, 3.6, { fill: "none", stroke: "k", sw: 1.2, r: 1.2 })]),
  ),
  // ---- the eyes: his left brow (our right) raised, the examiner's look ----
  ...eye(66, 96, -1, 0),
  ...eye(104, 96, 1, 2),
  // brows: tufts of lighter fur; the left one flat and low, the right one arched high
  ...browItems([46, 93, 52, 85, 64, 80.5, 78, 84, 85, 91, 78, 89, 64, 87, 52, 90.5]),
  ...browItems([89, 87, 95, 75, 106, 68.5, 116, 70, 124, 81, 118, 79.5, 108, 76, 97, 82]),
  // a frown crease between
  curve([84, 93, 86, 87], INK(1.4, 0.5)),
  // ---- the nose, the mouth ----
  curve([81, 112, 85, 115, 89, 112], INK(1.5, 0.45)),
  curve([64, 120, 74, 124.5, 85, 125.5, 97, 123.5, 109, 117], INK(2.4, 0.3)),
  curve([109, 117, 113, 113], INK(1.8, 0.5)),
  poly([98, 123, 101.5, 131.5, 105, 121.5], "w1"), poly([98, 123, 101.5, 131.5, 105, 121.5], EDGE(1.2)),   // the big fang
  poly([68, 121.5, 70, 127, 73, 123.5], "w1"), poly([68, 121.5, 70, 127, 73, 123.5], EDGE(1.1)),            // a small one
  ),
))
