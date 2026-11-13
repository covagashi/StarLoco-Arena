// S38b: Nilo's talk-window portrait, drawn in vex. Our own drawing after the
// retail portrait's shape (blue spirit-elder: ram horns, two scroll curls,
// round purple glasses, jagged white brows, long moustache, the egg staff) in
// the screens' style B: a heavy ink silhouette, lighter inner ink, three cel
// tones per material from one top-left light, a rim light on the shadow side.
// 170 x 200 px = talk_panel.gd FACE_SIZE (the box is 164 x 194 + the 3-unit
// outline on every side).
//   node <vex>/bin/vex.js build tools/portraits/nilo_fable.vx.js --scales 1,2

pal({
  k: "#1c2030",                                   // style B ink
  s0: "#4a8fc4", s1: "#8ccfee", s2: "#c9ecfb", s3: "#eafaff",   // blue skin
  c0: "#8cc6e4", c1: "#d9f1fb", c2: "#ffffff",                  // the crest's ice
  w0: "#a9c6da", w1: "#eef6fb", w2: "#ffffff",                  // white hair
  h0: "#4e2810", h1: "#935321", h2: "#c6823f", h3: "#e3a95e",   // horn
  y0: "#b27a12", y1: "#f2bd3a", y2: "#ffe68a",                  // gold
  p0: "#4b2572", p1: "#7e3fa0", p2: "#b07fd0",                  // the glasses' rim
  l0: "#d4c6ea", l1: "#f1ebfa", l2: "#ffffff",                  // lenses
  o0: "#a8420f", o1: "#ef8a28", o2: "#ffc466", o3: "#fff0c4",   // the staff's stone
  d0: "#2a170c", d1: "#4d2d16", d2: "#7b4b27",                  // dark wood
  e0: "#6a3aa0",                                                // eyes
  r1: "#b48ad0",                                                // a faint blush
})

const LIGHT = 315
const EDGE = (sw = 1.8) => ({ fill: "none", stroke: "k", sw, join: "round" })
const INK = (w = 2, taper = 0.45) => ({ ink: { c: "k", w, taper, wobble: 0, vary: 0.25 } })

// --- helpers ----------------------------------------------------------------
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
// one closed polygon with a rounded tip. For horns, curls, moustache, arms.
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

// a spiral spine around (cx, cy), angle a0 → a1 (degrees, screen clockwise), radius r0 → r1
function spiral(cx, cy, a0, a1, r0, r1, n = 30, pow = 1) {
  return Array.from({ length: n }, (_, i) => {
    const t = i / (n - 1), a = (a0 + (a1 - a0) * t) * Math.PI / 180, r = r0 + (r1 - r0) * t ** pow
    return [cx + r * Math.cos(a), cy + r * Math.sin(a)]
  })
}
const flat = (sp) => sp.flat()

// --- geometry ---------------------------------------------------------------
const HEAD = [85, 56, 110, 60, 126, 74, 131, 96, 127, 120, 112, 138, 85, 146, 58, 138, 43, 120, 39, 96, 44, 74, 60, 60]
const head = (dx, dy, st) => blob(sh(HEAD, dx, dy), st)

// the left crest curl: rises from the crown, scrolls outward
const CREST = [[78, 70], [76, 61], [73, 52], [70, 44], [68, 38], ...spiral(50, 28, 25, -240, 19, 7, 34)]
const crestW = (i) => (i < 5 ? 15.5 - i * 1.2 : 10 - 8.6 * ((i - 5) / (CREST.length - 6)) ** 0.9)
const crestPts = band(CREST, crestW)
const crest = (dx, dy, st) => poly(sh(crestPts, dx, dy), st)

// the left horn: a ram's spiral, thick at the root (hidden in the head), the tip curling to the cheek
const HORN = spiral(42, 90, -30, -262, 30, 9.5, 40, 1)
const hornW = (i, t) => 24 - 19 * t ** 0.85
const hornPts = band(HORN, hornW)
const horn = (dx, dy, st) => poly(sh(hornPts, dx, dy), st)

// the left ear, pointing out
const EAR = [46, 88, 24, 86, 4, 100, 22, 112, 46, 116]
const ear = (dx, dy, st) => blob(sh(EAR, dx, dy), S(st, { smooth: 0.35 }))

// the left brow, jagged like frost, hanging over the lens
const BROW = [45, 98, 48, 86, 55, 90, 60, 81, 66, 89, 71, 80, 76, 88, 80, 84, 82, 95, 78, 103, 72, 97, 66, 105, 59, 98, 52, 105]
const browItems = (P) => [
  poly(P, "w1"),
  clip(poly(P, "k"), poly(sh(P, 0, -8), "w2"), poly(sh(P, -3, -3), "w1"), blob(sh([44, 98, 60, 100, 84, 96, 82, 108, 60, 110], P[0] - 45, P[1] - 98), { fill: "w0", opacity: 0.85 })),
  ...[2, 4, 6].map((i) => curve([P[2 * i], P[2 * i + 1] + 1, P[2 * i] + 2, P[2 * i + 1] + 6], INK(1.4, 0.5))),
  poly(P, EDGE(1.8)),
]

// the left moustache, a long tapered band with a flick at the end
const MOU = [[82, 127], [73, 129], [64, 136], [58, 148], [56, 162], [57, 176], [62, 186], [70, 191]]
const mouW = (i, t) => 13 - 10.5 * t
const mouPts = band(MOU, mouW)
const mou = (dx, dy, st) => poly(sh(mouPts, dx, dy), st)

// the beard down the middle
const BEARD = [75, 134, 95, 134, 100, 150, 96, 166, 99, 182, 88, 200, 82, 200, 71, 182, 74, 166, 70, 150]
const beard = (dx, dy, st) => blob(sh(BEARD, dx, dy), st)

// body and arms
const BODY = [67, 138, 103, 138, 116, 154, 121, 200, 49, 200, 54, 154]
const body = (dx, dy, st) => blob(sh(BODY, dx, dy), S(st, { smooth: 0.5 }))
const ARM_L = band([[60, 156], [52, 166], [48, 178]], (i, t) => 11 - 2 * t, false)
const ARM_R = band([[110, 157], [122, 157], [133, 152]], (i, t) => 10 - 1.5 * t, false)

// the staff: a slightly curved pole, the claw setting, the egg stone
const STAFF = band([[157, 200], [152, 170], [148.5, 142], [147, 128]], () => 7.5, false)
const STONE = [147, 93, 156, 101, 159, 116, 154, 128, 147, 131, 140, 128, 135, 116, 138, 101]
const stone = (dx, dy, st) => blob(sh(STONE, dx, dy), st)

sprite("nilo", { w: 164, h: 194, scale: 1, outline: "k", ow: 3 }, tf({ x: -3, y: -3 },
  // ---- behind everything: the staff, the body, the arms ----
  poly(STAFF, "d1"),
  clip(poly(STAFF, "k"), poly(sh(STAFF, 2.2, 0), "d0"), poly(sh(STAFF, -5.5, 0), "d2")),
  line([157, 200, 152, 170, 148.5, 142, 147, 130], { stroke: "d0", sw: 1, opacity: 0.6 }),
  poly(STAFF, EDGE(1.6)),
  // the body
  ...cel(body, ["s0", "s1", "s2", "s3"], { sd: 6, hd: 7, rim: 1.6 }),
  body(0, 0, EDGE(2)),
  // the arms
  poly(ARM_L, "s1"), clip(poly(ARM_L, "k"), poly(sh(ARM_L, 3.5, 2), "s0")), poly(ARM_L, EDGE(1.8)),
  blob([40, 176, 52, 174, 58, 180, 56, 190, 46, 192, 39, 186], "s1"),
  clip(blob([40, 176, 52, 174, 58, 180, 56, 190, 46, 192, 39, 186], "k"), ellipse(56, 190, 10, 8, "s0"), ellipse(46, 178, 5, 2.5, "s2")),
  blob([40, 176, 52, 174, 58, 180, 56, 190, 46, 192, 39, 186], EDGE(1.8)),
  curve([46, 180, 54, 182], INK(1.4)), curve([46, 184, 54, 186], INK(1.4)),
  poly(ARM_R, "s1"), clip(poly(ARM_R, "k"), poly(sh(ARM_R, 0, 4), "s0")), poly(ARM_R, EDGE(1.8)),
  // the hand gripping the staff
  blob([132, 147, 142, 144, 150, 146, 155, 151, 154, 158, 150, 163, 140, 163, 133, 158], "s1"),
  clip(blob([132, 147, 142, 144, 150, 146, 155, 151, 154, 158, 150, 163, 140, 163, 133, 158], "k"),
    ellipse(150, 162, 13, 8, "s0"), ellipse(140, 148, 6, 3, "s2")),
  blob([132, 147, 142, 144, 150, 146, 155, 151, 154, 158, 150, 163, 140, 163, 133, 158], EDGE(1.8)),
  curve([143, 150, 154, 152], INK(1.5)), curve([143, 154, 154, 156], INK(1.5)), curve([144, 158, 153, 159.5], INK(1.4)),
  // ---- the ears, then the horns and crest behind the head ----
  sym(85,
    ...cel(ear, ["s0", "s1", "s2", "s3"], { sd: 4, hd: 4, rim: 1.4 }),
    blob([44, 96, 28, 94, 14, 101, 28, 109, 44, 112], { fill: "s0", smooth: 0.4, opacity: 0.7 }),
    curve([40, 93, 28, 97, 16, 102], INK(1.4, 0.5)),
    ear(0, 0, EDGE(2)),
  ),
  // the gold ring on his left ear
  circle(26, 112, 3.6, { fill: "none", stroke: "y1", sw: 2.2 }),
  circle(26, 112, 3.6, { fill: "none", stroke: "y0", sw: 0.8, opacity: 0.6 }),
  // horns
  sym(85,
    ...cel(horn, ["h0", "h1", "h2", "h3"], { sd: 4, hd: 4.5, rim: 1.6 }),
    // ridges across the horn
    clip(horn(0, 0, "k"), ...HORN.slice(8, 30).filter((_, j) => j % 3 === 0).map(([x, y], j) => {
      const i = 8 + j * 3, w = hornW(i, i / (HORN.length - 1)) / 2 + 2
      const [ax, ay] = HORN[i - 1], [bx, by] = HORN[i + 1]
      let nx = -(by - ay), ny = bx - ax; const m = Math.hypot(nx, ny) || 1; nx /= m; ny /= m
      return line([x + nx * w, y + ny * w, x - nx * w, y - ny * w], { stroke: "h0", sw: 1.5, opacity: 0.7 })
    })),
    // gold triangles along the outer edge
    ...[9, 13, 17, 21, 25].map((i) => {
      const [x, y] = HORN[i], [ax, ay] = HORN[i - 1], [bx, by] = HORN[i + 1]
      let nx = -(by - ay), ny = bx - ax; const m = Math.hypot(nx, ny) || 1; nx /= m; ny /= m
      const tx = (bx - ax) / Math.hypot(bx - ax, by - ay), ty = (by - ay) / Math.hypot(bx - ax, by - ay)
      const w = hornW(i, i / (HORN.length - 1)) / 2, s = 2.3 + (25 - i) * 0.1
      const ox = x + nx * (w - 3.2), oy = y + ny * (w - 3.2)      // sits just inside the outer edge
      return [
        poly([ox + tx * s, oy + ty * s, ox - tx * s, oy - ty * s, ox - nx * s * 1.7, oy - ny * s * 1.7], { fill: "y1", stroke: "y0", sw: 0.8, join: "round" }),
        poly([ox + tx * s * 0.5, oy + ty * s * 0.5, ox - tx * s * 0.5, oy - ty * s * 0.5, ox - nx * s * 0.6, oy - ny * s * 0.6], { fill: "y2", opacity: 0.8 }),
      ]
    }),
    clip(horn(0, 0, "k"), curve(flat(HORN.slice(8, 24).map(([x, y]) => [x - 2, y - 3.5])), { stroke: "h3", sw: 2.2, opacity: 0.6, cap: "round" })),
    horn(0, 0, EDGE(2)),
  ),
  // the crest curls and the tuft between them
  sym(85,
    ...cel(crest, ["c0", "c1", "c2"], { sd: 3.5, hd: 4, rim: 0 }),
    // a ridge line following the curl, for the scroll feel
    curve(flat(CREST.slice(2).map(([x, y], j) => [x - 1.5, y + 0.5])), { stroke: "c0", sw: 1.4, opacity: 0.55, cap: "round" }),
    crest(0, 0, EDGE(2)),
  ),
  blob([85, 42, 89, 52, 88, 62, 82, 62, 81, 52], { fill: "c1", smooth: 0.7 }),
  clip(blob([85, 42, 89, 52, 88, 62, 82, 62, 81, 52], { fill: "k", smooth: 0.7 }), ellipse(90, 58, 5, 9, "c0")),
  blob([85, 42, 89, 52, 88, 62, 82, 62, 81, 52], { smooth: 0.7, ...EDGE(1.8) }),
  // ---- the head ----
  ...cel(head, ["s0", "s1", "s2", "s3"], { sd: 7, hd: 8, rim: 2 }),
  clip(head(0, 0, "k"),
    // cast shadows: under the brows, under the moustache, the chin
    sym(85, blob([44, 100, 62, 104, 84, 98, 84, 112, 62, 114, 46, 110], { fill: "s0", opacity: 0.45 })),
    blob([66, 136, 85, 128, 106, 136, 104, 148, 66, 148], { fill: "s0", opacity: 0.5 }),
    // a faint blush on the cheeks
    sym(85, ellipse(56, 126, 9, 5, { fill: "r1", opacity: 0.22 })),
  ),
  head(0, 0, EDGE(2.2)),
  // the swirl on the forehead
  curve(flat(spiral(85.6, 80.6, 0, 420, 1, 8.5, 26)), { stroke: "s0", sw: 2.8, cap: "round", opacity: 0.5 }),
  curve(flat(spiral(85, 80, 0, 420, 1, 8.5, 26)), { stroke: "s3", sw: 1.9, cap: "round" }),
  // ---- the glasses, the eyes ----
  sym(85,
    circle(64, 111, 16.5, { fill: "l1", opacity: 0.93 }),
    clip(circle(64, 111, 16.5, "k"),
      ellipse(70, 118, 17, 11, { fill: "l0", opacity: 0.9 }),
      poly([47, 114, 63, 93, 71, 93, 50, 126], { fill: "l2", opacity: 0.85 }),
      poly([54, 127, 76, 97, 79, 98, 58, 128], { fill: "l2", opacity: 0.5 }),
    ),
  ),
  // the eyes glance to his left (our right), toward the staff
  ...[[64, 111], [106, 111]].map(([cx, cy]) => [
    ellipse(cx + 3, cy + 2.5, 7.5, 6, "w2"),
    circle(cx + 6, cy + 3, 3.9, "e0"), circle(cx + 6, cy + 3, 2.1, "k"),
    circle(cx + 4.6, cy + 1.4, 1.2, "w2"),
    curve([cx - 5, cy - 1, cx + 2, cy - 4, cx + 10.5, cy - 0.5], INK(2.4, 0.3)),   // a heavy, half-closed lid
    curve([cx - 2, cy + 8.5, cx + 4, cy + 9.2, cx + 10, cy + 7], { ink: { c: "e0", w: 1.1, taper: 0.5, wobble: 0 } }),
  ]),
  sym(85,
    circle(64, 111, 16.5, { fill: "none", stroke: "p1", sw: 4.6 }),
    clip(circle(64, 111, 18.8, "k"), clip(circle(64, 111, 16.5, "k"), circle(64, 111, 18.8, { fill: "none", stroke: "p0", sw: 2.2 })),
      arc(64, 111, 16.5, 285, 355, { stroke: "p2", sw: 1.8 })),
    circle(64, 111, 18.8, { fill: "none", stroke: "k", sw: 1.3 }),
    circle(64, 111, 14.2, { fill: "none", stroke: "k", sw: 1 }),
  ),
  rect(80, 109, 10, 4.4, { fill: "p1", r: 2 }), rect(80, 109, 10, 4.4, { fill: "none", stroke: "k", sw: 1, r: 2 }),
  // the nose, the mouth
  curve([82, 121, 85, 125, 89, 122], INK(1.8, 0.4)),
  curve([78, 131.5, 85, 133, 93, 129.5], INK(2, 0.45)),
  // ---- the brows ----
  ...browItems(sh(BROW, 0, 1)),
  ...browItems(sh(mir(BROW), 0, -4)),
  // ---- the moustache and the beard ----
  ...cel(beard, ["w0", "w1", "w2"], { sd: 5, hd: 6, rim: 0 }),
  curve([84, 148, 80, 166, 83, 186], { stroke: "w0", sw: 1.3, opacity: 0.6 }), curve([92, 150, 90, 168, 92, 184], { stroke: "w0", sw: 1.1, opacity: 0.5 }),
  beard(0, 0, EDGE(2)),
  sym(85,
    ...cel(mou, ["w0", "w1", "w2"], { sd: 3, hd: 3.5, rim: 0 }),
    curve([76, 133, 66, 145, 61, 162], { stroke: "w0", sw: 1.1, opacity: 0.6 }), curve([80, 130, 72, 136, 67, 146], { stroke: "w0", sw: 0.9, opacity: 0.5 }),
    mou(0, 0, EDGE(2)),
  ),
  // ---- the staff's head: the claw setting, the egg stone, the pendant ----
  ...cel(stone, ["o0", "o1", "o2", "o3"], { sd: 5, hd: 5, rim: 1.6 }),
  clip(stone(0, 0, "k"), ellipse(142, 102, 4, 6.5, { fill: "o3", opacity: 0.85 })),
  curve(flat(spiral(147, 113, 0, 400, 1.5, 8, 24)), { stroke: "o0", sw: 2.2, cap: "round" }),
  stone(0, 0, EDGE(2)),
  blob([136, 117, 140, 126, 144, 116, 147, 127, 150, 116, 154, 126, 158, 117, 158, 134, 136, 134], { fill: "d1", smooth: 0.25 }),
  clip(blob([136, 117, 140, 126, 144, 116, 147, 127, 150, 116, 154, 126, 158, 117, 158, 134, 136, 134], { fill: "k", smooth: 0.25 }),
    rect(149, 110, 12, 30, { fill: "d0", opacity: 0.7 }), rect(134, 110, 5, 30, { fill: "d2", opacity: 0.6 })),
  blob([136, 117, 140, 126, 144, 116, 147, 127, 150, 116, 154, 126, 158, 117, 158, 134, 136, 134], { smooth: 0.25, ...EDGE(1.6) }),
  line([153, 136, 160, 148], { stroke: "y0", sw: 1.4 }),
  blob([160, 148, 164, 152, 162, 159, 158, 159, 156, 152], { fill: "y1", smooth: 0.6 }),
  clip(blob([160, 148, 164, 152, 162, 159, 158, 159, 156, 152], { fill: "k", smooth: 0.6 }), ellipse(163, 158, 5, 5, "y0"), circle(159, 151, 1.6, "y2")),
  blob([160, 148, 164, 152, 162, 159, 158, 159, 156, 152], { smooth: 0.6, ...EDGE(1.4) }),
))
