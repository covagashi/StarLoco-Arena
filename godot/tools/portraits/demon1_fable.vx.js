// S38b: Demon I's talk-window portrait, drawn in vex. Our own drawing after the
// retail portrait's shape (the Demon of the Hours who hosts the great
// tournament: a dark indigo bat head with pointed ears, glowing pink eyes, a
// wide fanged showman's grin, a small skull with ghost flames on the crown, two
// huge ribbed lavender horns rising to the top edge, a high purple collar, a
// white bib with the roman "I", lavender sleeves ending in dark claws) in the
// screens' style B, matching nilo_fable.vx.js: a heavy ink silhouette, lighter
// inner ink, three cel tones per material from one top-left light, a rim light
// on the shadow side. 170 x 200 px = talk_panel.gd FACE_SIZE (the box is
// 164 x 194 + the 3-unit outline on every side).
//   node <vex>/bin/vex.js build tools/portraits/demon1_fable.vx.js --scales 1,2
// Demon family palette (shared with Demon III): i* skin, n* horns, p* collar,
// w* bib, v* sleeves, d* claws, e* eye glow, b* bone, g* ghost flame, r* numeral.

pal({
  k: "#1c2030",                                                 // style B ink
  i0: "#2a1b4e", i1: "#4f3888", i2: "#7558b0", i3: "#a088d4",   // indigo skin
  m0: "#5a4a8c", m1: "#8577b8", m2: "#aa9fd4",                  // the mask-like face plate
  n0: "#8a7fa8", n1: "#bcb2d2", n2: "#dcd5ea", n3: "#f3effa",   // lavender-grey horns
  p0: "#4b2572", p1: "#7e3fa0", p2: "#b07fd0",                  // purple collar (Nilo's glasses purple)
  w0: "#a9b4d0", w1: "#eef0fb", w2: "#ffffff",                  // white bib, fangs
  v0: "#7d6a9c", v1: "#b3a3cc", v2: "#d9cfe8", v3: "#f0eaf8",   // lavender sleeves
  d0: "#1f1a33", d1: "#3b3158", d2: "#6a5c8c",                  // dark claws
  e0: "#ff7ac8", e1: "#ffc2e6", e2: "#ffffff",                  // pink eye glow
  b0: "#b9ad8c", b1: "#e8e0c4", b2: "#fbf7ea",                  // bone
  g0: "#4fd3e6", g1: "#b8f3fa",                                 // ghost flame cyan
  r0: "#352270", r1: "#5a3fa8",                                 // the numeral's indigo
  x0: "#120b22",                                                // mouth interior
})

const LIGHT = 315
const EDGE = (sw = 1.8) => ({ fill: "none", stroke: "k", sw, join: "round" })
const INK = (w = 2, taper = 0.45) => ({ ink: { c: "k", w, taper, wobble: 0, vary: 0.25 } })

// --- helpers (same as nilo_fable.vx.js) --------------------------------------
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
// one closed polygon with a rounded tip. For horns, sleeves, ears.
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
// the unit normal of a spine at index i
function normal(spine, i) {
  const [ax, ay] = spine[Math.max(0, i - 1)], [bx, by] = spine[Math.min(spine.length - 1, i + 1)]
  let nx = -(by - ay), ny = bx - ax; const m = Math.hypot(nx, ny) || 1
  return [nx / m, ny / m]
}
const flat = (sp) => sp.flat()

// --- geometry ---------------------------------------------------------------
// the left horn: rises from behind the head, leans in, the tip almost meets its twin at the top edge
const HORN = [[44, 138], [40, 112], [44, 84], [52, 58], [62, 34], [71, 16], [77, 5]]
const HORNW = [42, 46, 42, 36, 27, 19, 12]
const hornW = (i) => HORNW[i]
const hornPts = band(HORN, hornW)
const horn = (dx, dy, st) => blob(sh(hornPts, dx, dy), S(st, { smooth: 0.45 }))

// the head: a bat's, wide at the cheeks, a short pointed chin
const HEAD = [85, 74, 104, 78, 118, 92, 121, 112, 115, 132, 100, 146, 85, 152, 70, 146, 55, 132, 49, 112, 52, 92, 66, 78]
const head = (dx, dy, st) => blob(sh(HEAD, dx, dy), st)

// the left ear: a tall point rising out and up from the temple
const EAR = [66, 82, 52, 64, 38, 44, 41, 70, 50, 96]
const ear = (dx, dy, st) => blob(sh(EAR, dx, dy), S(st, { smooth: 0.3 }))
const EARIN = [60, 86, 50, 70, 43, 54, 46, 74, 52, 92]

// the mask-like face plate around the eyes and muzzle
const MASK = [85, 97, 97, 90, 111, 97, 118, 112, 114, 132, 100, 146, 85, 150, 70, 146, 56, 132, 52, 112, 59, 97, 73, 90]
const mask = (dx, dy, st) => blob(sh(MASK, dx, dy), st)

// the collar: high, flared, behind the chin
const COLLAR = [34, 158, 38, 118, 60, 138, 85, 146, 110, 138, 132, 118, 136, 158, 130, 174, 40, 174]
const collar = (dx, dy, st) => blob(sh(COLLAR, dx, dy), S(st, { smooth: 0.3 }))

// the bib: a white tunic front
const BIB = [58, 156, 85, 150, 112, 156, 120, 200, 50, 200]
const bib = (dx, dy, st) => blob(sh(BIB, dx, dy), S(st, { smooth: 0.4 }))

// the left sleeve, a wide band from the shoulder out and down
const SLEEVE = [[64, 160], [52, 163], [42, 170], [34, 180]]
const sleeveW = (i, t) => 22 + 12 * t
const sleevePts = band(SLEEVE, sleeveW, false)
const sleeve = (dx, dy, st) => blob(sh(sleevePts, dx, dy), S(st, { smooth: 0.4 }))

// three claws fanning out of the sleeve's end
const CLAW = (x, y, a, len) => {
  const r = (a * Math.PI) / 180, tx = Math.cos(r), ty = Math.sin(r), nx = -ty, ny = tx
  return [x + nx * 4, y + ny * 4, x + tx * len * 0.5 + nx * 2.4, y + ty * len * 0.5 + ny * 2.4, x + tx * len * 0.95 + nx * 2, y + ty * len * 0.95 + ny * 2, x + tx * len, y + ty * len + 1, x + tx * len * 0.55 - nx * 2.6, y + ty * len * 0.55 - ny * 2.6, x - nx * 4, y - ny * 4]
}
const CLAWS = [[30, 172, 222, 22], [28, 178, 190, 23], [30, 184, 158, 21]]

// the skull on the crown
const SKULL = [85, 56, 92, 58, 96, 64, 95, 72, 91, 78, 85, 79, 79, 78, 75, 72, 74, 64, 78, 58]
const skull = (dx, dy, st) => blob(sh(SKULL, dx, dy), st)

// the numeral I: a serifed bar
const NUM = [74, 164, 96, 164, 96, 169, 89, 170, 89, 189, 96, 190, 96, 195, 74, 195, 74, 190, 81, 189, 81, 170, 74, 169]

sprite("demon1", { w: 164, h: 194, scale: 1, outline: "k", ow: 3 }, tf({ x: -3, y: -3 },
  // ---- behind everything: the horns ----
  sym(85,
    ...cel(horn, ["n0", "n1", "n2", "n3"], { sd: 6, hd: 7, rim: 2 }),
    // ribs across the horn, the twisted-feather look: arcs sagging between the edges
    clip(horn(0, 0, "k"), ...[1, 2, 3, 4, 5].map((i) => {
      const [x, y] = HORN[i], [nx, ny] = normal(HORN, i), w = hornW(i) / 2 + 3, [tx, ty] = [-ny, nx]
      const sag = 11 - i * 1.2
      return [
        curve([x + nx * w, y + ny * w, x - tx * sag, y - ty * sag, x - nx * w, y - ny * w], { stroke: "n0", sw: 2, opacity: 0.6, cap: "round" }),
        curve([x + nx * w, y + ny * w + 3, x - tx * sag, y - ty * sag + 3, x - nx * w, y - ny * w + 3], { stroke: "n3", sw: 1.6, opacity: 0.55, cap: "round" }),
      ]
    })),
    // a long light stroke along the lit edge
    clip(horn(0, 0, "k"), curve(flat(HORN.slice(1, 7).map(([x, y], j) => { const [nx, ny] = normal(HORN, j + 1); return [x + nx * 9, y + ny * 9] })), { stroke: "n3", sw: 3, opacity: 0.55, cap: "round" })),
    horn(0, 0, EDGE(2)),
  ),
  // ---- the body: collar, sleeves, claws, bib ----
  ...cel(collar, ["p0", "p1", "p2"], { sd: 5, hd: 6, rim: 0 }),
  collar(0, 0, EDGE(2)),
  sym(85,
    ...CLAWS.map(([x, y, a, l]) => [
      blob(CLAW(x, y, a, l), { fill: "d1", smooth: 0.5 }),
      clip(blob(CLAW(x, y, a, l), { fill: "k", smooth: 0.5 }), blob(sh(CLAW(x, y, a, l), 2, 2), { fill: "d0", smooth: 0.5 }), blob(sh(CLAW(x, y, a, l), -2.5, -2), { fill: "d2", opacity: 0.6, smooth: 0.5 })),
      blob(CLAW(x, y, a, l), { smooth: 0.5, ...EDGE(1.6) }),
    ]),
    ...cel(sleeve, ["v0", "v1", "v2", "v3"], { sd: 6, hd: 6, rim: 1.6 }),
    // folds along the sleeve
    clip(sleeve(0, 0, "k"),
      curve([58, 172, 50, 178, 44, 188], { stroke: "v0", sw: 1.6, opacity: 0.6, cap: "round" }),
      curve([62, 156, 52, 160, 46, 166], { stroke: "v0", sw: 1.3, opacity: 0.5, cap: "round" }),
      // the cuff's dark band
      poly([36, 166, 22, 172, 24, 198, 44, 198], { fill: "d1", opacity: 0.9 }),
    ),
    sleeve(0, 0, EDGE(2)),
  ),
  ...cel(bib, ["w0", "w1", "w2"], { sd: 7, hd: 8, rim: 0 }),
  clip(bib(0, 0, "k"), blob([56, 150, 85, 158, 114, 150, 114, 166, 85, 170, 56, 166], { fill: "w0", opacity: 0.5 })),
  // the numeral
  poly(NUM, "r1"),
  clip(poly(NUM, "k"), poly(sh(NUM, 2, 2), "r0")),
  poly(NUM, EDGE(1.4)),
  bib(0, 0, EDGE(2)),
  // ---- the ears, then the skull and its ghost flames behind the head ----
  sym(85,
    ...cel(ear, ["i0", "i1", "i2", "i3"], { sd: 5, hd: 5, rim: 1.6 }),
    blob(EARIN, { fill: "m2", smooth: 0.3, opacity: 0.55 }),
    clip(blob(EARIN, { fill: "k", smooth: 0.3 }), blob(sh(EARIN, 4, 6), { fill: "m0", smooth: 0.3, opacity: 0.6 })),
    ear(0, 0, EDGE(2)),
  ),
  // ghost flames beside the skull
  sym(85,
    blob([70, 74, 62, 66, 58, 56, 61, 46, 58, 39, 66, 44, 67, 36, 71, 48, 75, 56, 77, 68], { fill: "g0", smooth: 0.6, opacity: 0.7, glow: { r: 4, color: "g0" } }),
    blob([70, 72, 65, 64, 63, 56, 66, 49, 69, 56, 73, 61, 75, 68], { fill: "g1", smooth: 0.6, opacity: 0.75 }),
  ),
  ...cel(skull, ["b0", "b1", "b2"], { sd: 3.5, hd: 4, rim: 0 }),
  // eye sockets, nose, teeth
  sym(85, ellipse(80.5, 67.5, 3.6, 3.2, "x0"), circle(80, 67, 1.1, { fill: "g0", opacity: 0.9 })),
  poly([85, 70, 83, 74, 87, 74], "x0"),
  ...[79, 82, 85, 88].map((x) => line([x, 75, x, 78], { stroke: "b0", sw: 0.9 })),
  skull(0, 0, EDGE(1.6)),
  // ---- the head ----
  ...cel(head, ["i0", "i1", "i2", "i3"], { sd: 7, hd: 8, rim: 2 }),
  // the face plate
  ...cel(mask, ["m0", "m1", "m2"], { sd: 6, hd: 6, rim: 0 }),
  clip(head(0, 0, "k"),
    // cast shadow under the brow ridge and the chin
    sym(85, blob([54, 104, 70, 102, 84, 106, 84, 114, 70, 116, 56, 114], { fill: "i0", opacity: 0.45 })),
    blob([66, 138, 85, 134, 104, 138, 100, 150, 70, 150], { fill: "i0", opacity: 0.45 }),
  ),
  mask(0, 0, { fill: "none", stroke: "i0", sw: 1.4, opacity: 0.7 }),
  head(0, 0, EDGE(2.2)),
  // ---- the eyes: glowing pink, slanted, sly ----
  sym(85,
    blob([58, 112, 66, 102, 80, 108, 79, 116, 68, 119, 60, 118], { fill: "e0", smooth: 0.55, glow: { r: 5, color: "e0", strength: 2 } }),
    clip(blob([58, 112, 66, 102, 80, 108, 79, 116, 68, 119, 60, 118], { fill: "k", smooth: 0.55 }),
      blob([62, 114, 70, 106, 80, 110, 79, 118, 66, 120], { fill: "e1", smooth: 0.55 }),
      ellipse(72, 113, 5, 3.5, "e2"),
    ),
    // the heavy lid: a slanted brow line
    curve([56, 112, 66, 100, 82, 107], INK(2.6, 0.3)),
    curve([60, 119, 70, 121, 80, 117], INK(1.4, 0.5)),
  ),
  // the nose: two small slits
  sym(85, curve([81.5, 125, 83, 128], INK(1.4, 0.5))),
  // ---- the grin: ear to ear, the corners curling up ----
  blob([54, 122, 66, 131, 85, 137, 104, 131, 116, 122, 114, 136, 102, 146, 85, 149, 68, 146, 56, 136], { fill: "x0", smooth: 0.5 }),
  clip(blob([54, 122, 66, 131, 85, 137, 104, 131, 116, 122, 114, 136, 102, 146, 85, 149, 68, 146, 56, 136], { fill: "k", smooth: 0.5 }),
    // the fangs: two big at the corners, small teeth between
    sym(85, poly([58, 126, 68, 131, 65, 145], "w2"), poly([71, 132, 78, 134, 75, 141], "w1"), poly([80, 134, 85, 135, 82.5, 139], "w1")),
    // the lower teeth
    sym(85, poly([66, 146, 73, 147, 70, 141], "w1"), poly([77, 148, 82, 148.5, 79.5, 144], "w1")),
    // the tongue's shadow
    ellipse(85, 150, 16, 5, { fill: "i0", opacity: 0.6 }),
  ),
  curve([52, 120, 66, 131, 85, 137, 104, 131, 118, 120], INK(2.6, 0.3)),
  curve([56, 136, 68, 146, 85, 149, 102, 146, 114, 136], INK(1.8, 0.4)),
  // grin creases at the corners
  sym(85, curve([51, 114, 49, 121, 52, 128], INK(1.4, 0.5))),
))
