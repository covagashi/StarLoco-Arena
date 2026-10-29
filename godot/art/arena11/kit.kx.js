// Arena 11 (retail world 42: a jungle of carnivorous plants) — the pieces it
// doesn't share with the other kits, each in three looms: <name> (a),
// <name>_b, <name>_c. The ruin stones use arena 6's stoneMoss loom (build its
// kit.tx.js first); everything else is palette colours. Its cracked paving is
// in the arena 9 kit. Retail gfx in brackets.
include("../common/shapes.kx.js")

const LOOMS = ["", "_b", "_c"]
// palette looms: [a, b, c] per key
const SET = (o, rough = 0.8, extra = {}) =>
  pal(Object.fromEntries(LOOMS.flatMap((s, i) => Object.entries(o).map(([k, v]) => [k + s, { color: v[i], rough, ...(extra[k] || {}) }]))))
// the fine grass: lime yellow (retail), deep green, autumn gold
const FINE = {
  fineD: ["#6e7c08", "#2c5a24", "#7a5618"], fine: ["#94a406", "#3a7a2c", "#a87a18"], fineL: ["#bccc1a", "#68a440", "#cca23a"],
  // 2784's broad blades: olive brown in front, a fresh green, a pale green
  oliveD: ["#5a5018", "#3a3418", "#4e2e14"], olive: ["#8e8030", "#6e6436", "#9a5e2a"], oliveL: ["#b4a444", "#8e8650", "#c08040"],
  sappy: ["#7ab01c", "#2e7a3a", "#9aa01e"], sappyL: ["#b4dc48", "#62b066", "#cccc52"],
}
SET(FINE, 0.75)
// the green climbers and ferns: lime (retail), deep green, yellow-green;
// their flowers white (pink, cream) and teal (violet, orange); the pebbles
const GREEN = {
  leafD: ["#4e8414", "#2a5e2a", "#6a7414"], leaf: ["#8cc01c", "#4a9438", "#a8b02a"], leafL: ["#b8da30", "#80bc54", "#d0cc4a"],
  leafX: ["#2e7a3a", "#1e4a2e", "#4a6a1e"], stem: ["#78a418", "#3e7a2c", "#8a8a20"], stemD: ["#4a6a10", "#2a4e22", "#5a5614"],
  petal: ["#f4f2dc", "#f6dce6", "#faf0c4"], petalD: ["#c8ceb0", "#d8aabc", "#dcca8e"], pistil: ["#d8d070", "#e0c060", "#e0a040"],
  bloom: ["#22b4b0", "#8a62d4", "#e8742c"], bloomD: ["#14787a", "#5a3a9a", "#a8481a"],
  pebble: ["#c4b088", "#a8a294", "#bc9c78"],
}
SET(GREEN, 0.7)
// the dark jungle palms: rust, brown, black-brown, olive and pale leaves
// (retail), a deep green jungle, a crimson one; their stalks; the snapping
// pods (olive, red, violet), their dark mouths, ivory teeth and brown horns;
// the dead leaves under them; the callas' spathe and blue spadix
const DARK = {
  rust: ["#6e3c20", "#36602a", "#7a2626"], rustL: ["#9e5e32", "#4e7e36", "#9a4034"], brown: ["#5e3820", "#2a4a24", "#5a1e22"],
  umber: ["#2e2018", "#1a2a1a", "#2a1418"], dolive: ["#5e5a22", "#4a5a22", "#6a3a2a"], doliveL: ["#86803a", "#6a7a34", "#8a5038"],
  pale: ["#a49474", "#8a9a72", "#a8807a"], paleL: ["#c8b894", "#aab890", "#c8a098"],
  palmStem: ["#3a2418", "#2a2a1a", "#3a1a1a"], palmStemL: ["#6a4430", "#4a4a2e", "#6a3430"],
  pod: ["#8c8a52", "#9a4a3a", "#7a5a8a"], podL: ["#b6b47c", "#c4786a", "#a888b4"], podD: ["#5e5c34", "#6a2a22", "#4e3a5e"],
  mouth: ["#2c3c1e", "#3a1414", "#2a1a30"], fang: ["#d4dae6", "#e8e2d0", "#e0d8e8"], podHorn: ["#7a3a26", "#5a2a1a", "#5a2a3a"],
  litter: ["#5a2e1a", "#5a4e26", "#58201a"], litterL: ["#744028", "#76683a", "#722e24"], litterD: ["#3e1e10", "#3e341a", "#3a1410"],
  spathe: ["#3e5a30", "#2e4a2a", "#5a2e3a"], spatheL: ["#5e7e44", "#4a6a3e", "#7a4458"], spadix: ["#6aa8e8", "#e8d870", "#f0f0f0"],
}
SET(DARK, 0.75)
const SKINNED = [...Object.keys(FINE), ...Object.keys(GREEN), ...Object.keys(DARK)]
const looms = (name) => threeLooms(name, SKINNED)

// Screen terms, as in the arena 8 and 9 kits: u along the screen's
// horizontal (world (1, 0, -1)), v towards the camera (world (1, 0, 1)), in
// metres (61 px a metre along u, 52.7 px a metre up, at 1×).
const R2 = Math.SQRT1_2
const at = (u, v) => [(u + v) * R2, (v - u) * R2]
const rnd = (i, k, seed) => ((Math.sin((i + 1) * 12.9898 * k + seed * 78.233) * 43758.5453) % 1 + 1) % 1

// --- fine grass (group «hierba fina»: 1751, 1752, 1753, 2784) ----------------
// like arena 5's grass tuft, but long thin blades that arc to one side as
// they rise. A blade in its own XY plane: h tall, w wide near the foot,
// drifting `arc` metres sideways at the tip; cut at `cut` of its height into
// a darker foot and a lighter tip
// one half of the blade (side -1 left, 1 right): the midline, then that
// edge back down
const bladeHalf = (h, w, arc, t0, t1, side, n) => {
  const M = [], E = []
  for (let k = 0; k <= n; k++) {
    const t = t0 + (t1 - t0) * k / n, x = arc * t * t, y = h * t
    // lanceolate: half as wide at the foot, widest a little below the middle
    const hw = t >= 0.999 ? 0 : w / 2 * Math.pow(Math.sin(Math.PI * (0.12 + 0.88 * t)), 0.7)
    M.push(x, y); E.push(x + side * hw, y)
  }
  // a pointed tip is one point, not two
  const pts = side > 0 ? [...M] : [...E.slice(0, t1 >= 0.999 ? -2 : E.length)]
  const back = side > 0 ? E.slice(0, t1 >= 0.999 ? -2 : E.length) : M
  for (let k = back.length - 2; k >= 0; k -= 2) pts.push(back[k], back[k + 1])
  return pts
}
// a blade folded a little along its midrib, each half its own tone (the
// retail paints one half lighter): mats [foot, left half, right half]
const fineBlade = (h, w, arc, mats, cut = 0.22, fold = 16) => [-1, 1].map((sd) => tf({ rot: [0, sd * fold, 0] },
  extrude(bladeHalf(h, w, arc, 0, cut, sd, 2), 0.005, { mat: mats[0] }),
  extrude(bladeHalf(h, w, arc, cut, 1, sd, 7), 0.005, { mat: sd < 0 ? mats[1] : mats[2], pos: [0, 0, 0.001] })))
// a tuft: n blades bunched round a few centres (screen terms), heights
// lo..hi, each turned to face the camera give or take 40°, leaning lean0..lean1
// degrees and arcing left or right. mats picks [foot, tip] per blade
function fineTuft(n, centres, spread, lo, hi, w, lean0, lean1, seed, mats, tallMid = 0) {
  return Array.from({ length: n }, (_, i) => {
    const r = (k) => rnd(i, k, seed)
    const [cu, cv] = centres[i % centres.length]
    const u = cu + (r(1) - 0.5) * spread[0], v = cv + (r(2) - 0.5) * spread[1]
    const side = r(4) > 0.5 ? 1 : -1
    // a fan: the further a blade stands from its centre, the more it leans
    // out, and it arcs out the same way
    const off = Math.min(1, Math.abs(u - cu) / (spread[0] / 2))
    // tallMid: the blades in the middle of the tuft the tallest
    const h = lo + r(3) * (hi - lo) * (1 - tallMid * off)
    const arc = h * (0.04 + r(5) * 0.16) * (r(10) > 0.3 ? 1 : -1), lean = lean0 + (off * 0.7 + r(6) * 0.3) * (lean1 - lean0)
    const out = Math.sign(u - cu) || side
    const [x, z] = at(u, v)
    return tf({ pos: [x, 0, z], rot: [0, 45 + (r(7) - 0.5) * 80, 0] }, tf({ rot: [0, 0, -out * lean] },
      fineBlade(h, w * (0.8 + r(8) * 0.4), out * arc, mats(i, r(9), v))))
  })
}
// the tips lighter towards the camera
const fineMats = (i, r, v) => r < 0.2 ? ["fineD", "fine", "fineD"] : ["fine", v > 0.05 || r > 0.55 ? "fineL" : "fine", "fine"]
// fine grass (1751): a broad tuft, the tall blades in the middle
model("grass_fine",
  fineTuft(30, [[-0.3, 0.0], [0.05, -0.1], [0.38, 0.05]], [0.5, 0.25], 0.45, 1.2, 0.085, 0, 22, 11, fineMats))
// tall fine grass (1752): taller and denser
model("grass_fine_tall",
  fineTuft(44, [[-0.4, 0.05], [0.05, -0.1], [0.45, 0.05]], [0.6, 0.25], 0.6, 1.55, 0.1, 0, 26, 21, fineMats))
// low fine grass (1753): short, sparse, thin
model("grass_fine_low",
  fineTuft(26, [[-0.3, 0.0], [0.05, -0.05], [0.35, 0.02]], [0.45, 0.2], 0.3, 0.72, 0.065, 0, 22, 31, fineMats))
// broad fine grass (2784): fewer, broader blades standing up, the olive ones
// in front bowing out, fresh and pale green ones behind
const broadMats = (i, r, v) => i % 2 && r > 0.35 ? ["oliveD", "oliveL", "olive"] : r > 0.5 ? ["sappy", "sappyL", "sappy"] : ["sappy", "sappy", "oliveD"]
model("grass_fine_broad",
  fineTuft(22, [[0, -0.04], [0, 0.04]], [0.36, 0.16], 0.8, 2.3, 0.17, 0, 40, 41, broadMats, 0.6))
for (const n of ["grass_fine", "grass_fine_tall", "grass_fine_low", "grass_fine_broad"]) looms(n)

// --- green climbers (group «planta»: 2768, 2769, 1788, 1791) -----------------
// lime jungle climbers: thin stems twining up, spiral tendrils, heart-shaped
// leaves folded along their midrib (one half lighter), white three-petal
// flowers and, on 2769, big teal ones. Retail sizes: 2768 is 3 m tall, 1788
// 4.4 m.
// a leaf half (arena 6's helper): the outline of one side along +y, from the
// midrib out, as [halfwidth, y] pairs; side mirrors it
const halfLeaf = (prof, side) => {
  const pts = [0, 0, ...prof.flatMap(([w, y]) => [-side * w, y])], [wl, yl] = prof[prof.length - 1]
  if (wl > 0) pts.push(0, yl)
  if (side < 0) { const r = []; for (let i = pts.length - 2; i >= 0; i -= 2) r.push(pts[i], pts[i + 1]); return r }
  return pts
}
const foldPiece = (prof, matL, matR, fold = 14) => [
  extrude(halfLeaf(prof, 1), 0.008, { mat: matL, rot: [0, -fold, 0] }),
  extrude(halfLeaf(prof, -1), 0.008, { mat: matR, rot: [0, fold, 0] })]
// a heart leaf, 1 long: two round lobes either side of the stalk, a point
const HEART = [[0.22, -0.12], [0.42, -0.02], [0.5, 0.18], [0.44, 0.42], [0.26, 0.7], [0, 1]]
// an arrow leaf: narrower, its lobes pointed
const ARROW = [[0.3, -0.14], [0.3, 0.04], [0.32, 0.22], [0.24, 0.48], [0.1, 0.78], [0, 1]]
// a lance leaf: no lobes
const LANCE = [[0.1, 0.06], [0.2, 0.25], [0.22, 0.45], [0.15, 0.7], [0, 1]]
// a leaf of size s at p, its stalk end there, pointing `yaw` in screen
// degrees (0 the screen's right, 90 away from the camera, 180 left, -90
// towards it) and rising `up` degrees from flat; rolled about its own
// midrib so its face turns to the camera (face 1) or the sky (face 0)
const DEG = 180 / Math.PI
const CAM = [0.866 * R2, 0.5, 0.866 * R2]
function leafAt([x, y, z], yaw, up, s, prof = HEART, mats = ["leafL", "leaf"], fold = 18, face = 0.7) {
  const a = (yaw + 45) / DEG, e = up / DEG
  const A = [Math.cos(e) * Math.cos(a), Math.sin(e), -Math.cos(e) * Math.sin(a)]
  const th = Math.acos(A[1]), ph = Math.atan2(A[0], A[2])
  // the face we want: between the sky and the camera, square to the midrib
  let N = [CAM[0] * face, CAM[1] * face + (1 - face), CAM[2] * face]
  const d = N[0] * A[0] + N[1] * A[1] + N[2] * A[2]
  N = [N[0] - d * A[0], N[1] - d * A[1], N[2] - d * A[2]]
  // into the frame Ry(ph) Rx(th): undo the yaw, then the tilt
  const nx = N[0] * Math.cos(ph) - N[2] * Math.sin(ph), nz0 = N[0] * Math.sin(ph) + N[2] * Math.cos(ph)
  const ny = N[1] * Math.cos(th) + nz0 * Math.sin(th), nz = -N[1] * Math.sin(th) + nz0 * Math.cos(th)
  const ro = Math.atan2(nx, nz) * DEG
  void ny
  return tf({ pos: [x, y, z], rot: [0, ph * DEG, 0] }, tf({ rot: [th * DEG, 0, 0] }, tf({ rot: [0, ro, 0], scale: s },
    foldPiece(prof, mats[0], mats[1], fold))))
}
// a stem through [x, y, z, r] points: tapering cylinders, a joint ball at each bend
function stem(pts, mat = "stem", sides = 5) {
  const out = []
  for (let i = 0; i < pts.length - 1; i++) {
    const [x0, y0, z0, r0] = pts[i], [x1, y1, z1, r1] = pts[i + 1]
    const dx = x1 - x0, dy = y1 - y0, dz = z1 - z0, len = Math.hypot(dx, dy, dz)
    out.push(tf({ pos: [x0, y0, z0], rot: [0, Math.atan2(-dz, dx) * DEG, 0] },
      lathe([r0, 0, r1, len], { mat, sides, rot: [0, 0, -Math.acos(dy / len) * DEG] })))
    if (i) out.push(sphere(r0 * 1.0, { mat, detail: r0 > 0.03 ? 1 : 0, pos: [x0, y0, z0] }))
  }
  return out
}
// a stem by a path function t -> [x, y, z] (t 0..1), r0 at the foot to r1
const path = (f, r0, r1, n = 8) => Array.from({ length: n + 1 }, (_, i) => [...f(i / n), r0 + (r1 - r0) * i / n])
// a spiral tendril at p, in the plane facing the camera, curling `dir`
// (1 right, -1 left), R across, `turns` turns, rising first by `rise`
const tendril = ([x, y, z], R, dir, turns = 1.4, rise = 0, mat = "stem") => {
  const n = 18, pts = []
  for (let i = 0; i <= n; i++) {
    const t = i / n, a = t * turns * Math.PI * 2, r = R * (1 - t * 0.8)
    // screen terms: u right, up y
    const u = dir * (R - Math.cos(a) * r) , yy = rise * Math.min(1, t * 3) + Math.sin(a) * r
    pts.push([x + u * R2, y + yy, z - u * R2, 0.012 * (1 - t * 0.6)])
  }
  return stem(pts, mat, 4)
}
// a white three-petal flower facing the camera, a little up; s across
const whiteFlower = ([x, y, z], s = 0.2) => tf({ pos: [x, y, z], rot: [0, 45, 0] }, tf({ rot: [-25, 0, 0], scale: s },
  [0, 120, 240].map((a, i) => tf({ rot: [0, 0, a + 30] }, sphere(0.28, { mat: i ? "petal" : "petalD", detail: 1, pos: [0, 0.27, 0], scale: [0.85, 1, 0.3] }))),
  sphere(0.1, { mat: "pistil", detail: 1, pos: [0, 0, 0.08] })))
// a teal five-petal flower, petals pointed
const tealFlower = ([x, y, z], s = 0.4, tilt = -25) => tf({ pos: [x, y, z], rot: [0, 45, 0] }, tf({ rot: [tilt, 0, 0], scale: s },
  [0, 72, 144, 216, 288].map((a, i) => tf({ rot: [0, 0, a] }, sphere(0.25, { mat: i % 2 ? "bloom" : "bloomD", detail: 1, pos: [0, 0.26, 0], scale: [0.8, 1, 0.25] }))),
  sphere(0.08, { mat: "petal", detail: 1, pos: [0, 0, 0.07] })))
// screen point: u right, y up, v towards the camera
const sp = (u, y, v) => { const [x, z] = at(u, v); return [x, y, z] }
// a low rosette of lance leaves round the foot
const footLeaves = (n, len, seed, mats = ["leaf", "leafD"]) => Array.from({ length: n }, (_, i) =>
  leafAt([0, 0.02, 0], (i * 137.5 + rnd(i, 3, seed) * 30) % 360, 35 + rnd(i, 4, seed) * 35, len * (0.75 + rnd(i, 5, seed) * 0.5), LANCE, mats, 22))

// a leaf on its own stalk: from the stem at (u, y) the stalk reaches out
// `reach` metres towards screen yaw, rising a little, the leaf at its end
const sprig = ([u, y, reach, yaw, up, size], i, prof, mats) => {
  const a = yaw / DEG, end = [u + Math.cos(a) * reach, y + reach * 0.35, Math.sin(a) * -reach + 0.04]
  return [stem([[...sp(u, y, 0.02), 0.012], [...sp(...end), 0.008]], "stem", 4),
    leafAt(sp(...end), yaw + (i % 2 ? 15 : -15), up, size, prof, mats)]
}
const tone = (i) => i % 3 === 0 ? ["leaf", "leafD"] : ["leafL", "leaf"]

// vine with heart leaves (2768): a twined stalk up to 2.6 m crowned by a
// tilted heart leaf, a thin dark stalk on the right with small dark leaves,
// arrow leaves on stalks reaching out to the left, broad leaves round the
// foot and pebbles
model("vine_heart",
  stem(path((t) => sp(0.05 * Math.sin(t * 7), t * 2.5, 0.04 * Math.cos(t * 7)), 0.04, 0.02)),
  stem(path((t) => sp(-0.05 * Math.sin(t * 7), t * 2.3, -0.04 * Math.cos(t * 7)), 0.035, 0.016), "stemD"),
  leafAt(sp(0.0, 2.45, 0), 60, 50, 0.6, HEART, ["leafL", "leaf"]),
  stem(path((t) => sp(0.3 + t * 0.12, t * 2.6, -0.05), 0.016, 0.008), "stemD", 4),
  [[2.5, 0.42, 0.2], [2.25, 0.36, 0.22], [1.95, 0.44, 0.2], [1.6, 0.37, 0.2], [1.3, 0.42, 0.18]].map(([y, u, s], i) =>
    leafAt(sp(u, y, -0.05), i % 2 ? 160 : 10, 40, s, LANCE, ["leafX", "leafX"])),
  [[0, 0.9, 0.45, 175, 40, 0.42], [0, 1.4, 0.55, 165, 45, 0.4], [0, 1.9, 0.4, 150, 50, 0.38], [0, 2.2, 0.5, 170, 45, 0.34], [0, 2.0, 0.3, 30, 50, 0.42]].map((l, i) =>
    sprig(l, i, i % 2 ? ARROW : HEART, tone(i))),
  tendril(sp(0.06, 1.2, 0.04), 0.08, -1), tendril(sp(0.0, 1.7, 0.04), 0.07, 1),
  footLeaves(8, 0.55, 5),
  [[0.15, 0.3, 0.06], [-0.2, 0.25, 0.05], [0.35, 0.15, 0.045], [-0.05, 0.38, 0.03]].map(([u, v, r], i) =>
    rock(r, { mat: "pebble", seed: 50 + i, pos: sp(u, r * 0.5, v), scale: [1, 1.3, 1] })))

// flowering vine (2769): a climbing stem with spiral tendrils, big heart
// leaves on both sides, a white flower among them, teal flowers at the top
// and on a side shoot; broad dark leaves round the foot; 3.3 m
model("flower_vine",
  stem(path((t) => sp(0.08 * Math.sin(t * 5), t * 3.0, 0.05 * Math.sin(t * 4)), 0.05, 0.022)),
  stem(path((t) => sp(-0.1 - t * 0.55, t * 2.1, 0.05), 0.028, 0.012), "stem", 4),
  [[0, 0.8, 0.3, 10, 40, 0.6], [0, 1.0, 0.25, 175, 35, 0.55], [0, 1.5, 0.3, 20, 45, 0.55], [0, 1.85, 0.25, 160, 45, 0.5],
   [0, 2.4, 0.3, 5, 40, 0.5], [0, 2.75, 0.25, 170, 45, 0.48], [0, 3.0, 0.15, 60, 50, 0.45], [-0.62, 2.1, 0.1, 150, 45, 0.42], [-0.45, 1.6, 0.15, 200, 40, 0.35]].map((l, i) =>
    sprig(l, i, i === 8 ? ARROW : HEART, tone(i))),
  // a long blade leaf leaning out to the right
  leafAt(sp(0.1, 0.5, 0.1), 15, 55, 1.0, LANCE, ["leafL", "leaf"]),
  whiteFlower(sp(0.0, 1.35, 0.2), 0.3), whiteFlower(sp(0.18, 0.85, 0.25), 0.18),
  tealFlower(sp(0.08, 3.1, 0.15), 0.5), tealFlower(sp(-0.65, 2.15, 0.15), 0.4), tealFlower(sp(0.4, 0.75, 0.2), 0.28),
  tendril(sp(0.1, 1.6, 0.05), 0.14, 1), tendril(sp(-0.05, 2.2, 0.05), 0.12, -1), tendril(sp(0.25, 1.0, 0.05), 0.12, 1),
  footLeaves(10, 0.8, 7, ["leafD", "leafX"]))

// tall vine (1788): stems climbing 4.3 m, the tallest bare to an arrow leaf
// at its tip; heart leaves and white flowers bunched at 1.3-2.8 m and round
// the foot, tendrils curling out
const tallStems = [[-0.1, 4.2, 0.03], [0.08, 3.4, 0.035], [0.0, 2.9, 0.03], [0.18, 2.6, 0.025], [-0.2, 2.4, 0.025]]
model("vine_tall",
  tallStems.map(([u, h, r], i) => stem(path((t) => sp(u + 0.08 * Math.sin(t * 4 + i), t * h, 0.05 * Math.cos(t * 3 + i)), r, r * 0.4), i % 2 ? "stemD" : "stem", 5)),
  leafAt(sp(-0.05, 4.15, 0), 60, 55, 0.3, ARROW, ["leafL", "leaf"]),
  leafAt(sp(0.12, 3.35, 0), 30, 50, 0.26, ARROW, ["leafL", "leaf"]),
  [[-0.1, 1.4, 0.3, 175, 40, 0.42], [0.1, 1.5, 0.3, 5, 40, 0.4], [-0.1, 1.9, 0.25, 160, 45, 0.45], [0.1, 2.0, 0.3, 20, 45, 0.42],
   [-0.1, 2.35, 0.3, 185, 40, 0.4], [0.05, 2.55, 0.2, 40, 50, 0.38], [0, 2.8, 0.15, 120, 50, 0.34], [0.15, 2.3, 0.35, 0, 35, 0.36],
   [-0.15, 1.65, 0.4, 200, 35, 0.38], [0.1, 1.75, 0.15, 60, 50, 0.4]].map((l, i) => sprig(l, i, i % 4 === 1 ? ARROW : HEART, tone(i))),
  [[-0.1, 0.3, 0.3, 190, 40, 0.38], [0.1, 0.45, 0.3, -10, 40, 0.4], [0.1, 0.75, 0.25, 30, 45, 0.36], [-0.1, 0.9, 0.3, 160, 45, 0.36], [0.1, 1.05, 0.35, 0, 40, 0.34]].map((l, i) =>
    sprig(l, i, i % 2 ? ARROW : HEART, ["leaf", "leafD"])),
  whiteFlower(sp(0.05, 2.45, 0.2), 0.26), whiteFlower(sp(-0.25, 2.0, 0.2), 0.28), whiteFlower(sp(0.3, 1.75, 0.2), 0.22),
  whiteFlower(sp(0.35, 0.75, 0.2), 0.2), whiteFlower(sp(-0.05, 1.3, 0.2), 0.18),
  tendril(sp(0.2, 2.3, 0.05), 0.14, 1), tendril(sp(-0.3, 1.7, 0.05), 0.12, -1), tendril(sp(0.15, 1.2, 0.05), 0.1, 1), tendril(sp(-0.2, 0.6, 0.05), 0.1, -1),
  footLeaves(7, 0.45, 9))

// vine crowns (1791): two clumps of bare stems, 1.7 and 2.4 m, each topped
// with a crown of big heart leaves, white flowers and tendrils; the right
// clump lower and darker
const crown = (u0, h, n, seed, dark, big) => [
  Array.from({ length: n }, (_, i) => stem(path((t) => sp(u0 + (i - n / 2) * 0.06 + 0.05 * Math.sin(t * 3 + i), t * h * (0.85 + rnd(i, 1, seed) * 0.2), 0.04 * Math.cos(t * 2 + i)), 0.026, 0.014), i % 2 ? "stemD" : "stem", 5)),
  [[0, -0.25, 0.3, 175, 40], [0, -0.2, 0.3, 5, 40], [0, 0.0, 0.2, 150, 50], [0, 0.0, 0.25, 30, 50], [0, -0.45, 0.2, 200, 35], [0, -0.4, 0.25, -20, 35]].map(([du, dy, r, yaw, up], i) =>
    sprig([u0 + du, h + dy, r, yaw, up, big * (0.85 + (i % 3) * 0.1)], i, i === 4 ? ARROW : HEART, dark ? ["leaf", "leafD"] : tone(i))),
  whiteFlower(sp(u0, h + 0.1, 0.25), 0.28), whiteFlower(sp(u0 + 0.15, h - 0.4, 0.22), 0.18),
  tendril(sp(u0 - 0.25, h - 0.2, 0.05), 0.15, -1), tendril(sp(u0 + 0.3, h - 0.15, 0.05), 0.14, 1)]
model("vine_crowns", crown(-0.3, 2.2, 4, 3, false, 0.5), crown(0.5, 1.5, 3, 7, true, 0.42),
  sprig([-0.3, 1.5, 0.5, 185, 45, 0.25], 1, ARROW, ["leafL", "leaf"]))
for (const n of ["vine_heart", "flower_vine", "vine_tall", "vine_crowns"]) looms(n)

// --- dark palms and snapping pods (group «planta»: 2770, 2772-2775) -----------
// umbrella palms of long narrow leaves in rust, brown, black-brown and olive,
// on dark curving stalks; some carry snapping pods: an olive egg with pale
// spots, a dark mouth and ivory fangs underneath, two brown horns behind.
// Dead leaves lie round their foot. In the retail map they stand at the rim,
// drawn almost black in front of the arena: our light does that.
// a frond: a long narrow leaf along +z, in segments, each bending further
// down (droop degrees each), its halves folded up along the midrib
const FROND = [[0.3, 0.05, 0.75], [0.25, 0.75, 1.0], [0.25, 1.0, 0.85], [0.2, 0.85, 0]]
const frond = (len, w, droop, mats, k = 0) => {
  if (k === FROND.length) return []
  const [f, w0, w1] = FROND[k], L = f * len
  const prof = w1 > 0 ? [[w0 * w / 2, 0], [w1 * w / 2, L]] : [[w0 * w / 2, 0], [w0 * w * 0.35, L * 0.6], [0, L]]
  return [tf({ rot: [90, 0, 0] }, foldPiece(prof, mats[0], mats[1], 18)),
    tf({ pos: [0, 0, L], rot: [droop, 0, 0] }, frond(len, w, droop, mats, k + 1))]
}
// a whorl of n fronds at p (screen u, y, v): spread round, rising `rise`
// degrees, drooping, long len; tones cycle through mats
const PALM_TONES = [["rust", "rustL"], ["brown", "rust"], ["umber", "brown"], ["dolive", "doliveL"]]
const whorl = (p, n, len, rise, droop, seed, tones = PALM_TONES, w = 0.19) => tf({ pos: sp(...p) },
  Array.from({ length: n }, (_, i) => {
    const yaw = (i * 360 / n + rnd(i, 1, seed) * 30) + 45, a = yaw / DEG
    return tf({ rot: [0, Math.atan2(Math.cos(a), -Math.sin(a)) * DEG, 0] },
      tf({ rot: [-(rise + rnd(i, 2, seed) * 15), 0, 0] }, frond(len * (0.8 + rnd(i, 3, seed) * 0.4), w, droop + 6 + rnd(i, 4, seed) * 8, tones[(i + seed) % tones.length])))
  }))
// a stalk from the foot (screen u0, v0) to p, bowing sideways by `bow`
const palmStalk = ([u0, v0], [u, y, v], r, bow = 0.15, seed = 1) =>
  stem(path((t) => sp(u0 + (u - u0) * t + bow * Math.sin(t * Math.PI), y * t, v0 + (v - v0) * t), r, r * 0.45, 6), rnd(1, 1, seed) > 0.5 ? "palmStem" : "palmStemL", 5)
// a snapping pod at p, its body s long, facing screen yaw (it hangs from its
// back end, tipped down a little)
const pod = (p, s, yaw = 180, tilt = 15) => tf({ pos: sp(...p), rot: [0, yaw + 45, 0] }, tf({ rot: [0, 0, -tilt], scale: s },
  // the egg, longer than tall, its back end on the stalk
  sphere(0.5, { mat: "pod", detail: 2, pos: [0.5, 0, 0], scale: [1.0, 0.68, 0.72] }),
  // pale spots on its top and sides
  [[0.35, 0.28, 0.12], [0.62, 0.3, -0.1], [0.75, 0.18, 0.22], [0.5, 0.2, -0.3], [0.2, 0.15, 0.25]].map(([x, y, z], i) =>
    sphere(0.07 + (i % 2) * 0.03, { mat: "podL", detail: 1, pos: [x, y, z], scale: [1, 0.35, 1] })),
  // the dark mouth along its belly, the fangs hanging from it
  sphere(0.42, { mat: "mouth", detail: 2, pos: [0.52, -0.12, 0], scale: [1.05, 0.5, 0.78] }),
  [[0.15, 0.1], [0.32, 0.22], [0.52, 0.27], [0.72, 0.22], [0.88, 0.1], [0.32, -0.22], [0.6, -0.26], [0.84, -0.16]].map(([x, z], i) =>
    cone(0.055, 0.2 + (i % 3) * 0.05, { mat: "fang", sides: 5, pos: [x, -0.2, z * 1.25], rot: [180, 0, 0] })),
  // two horns and a ruff of dark scales at the back
  [-1, 1].map((k) => cone(0.07, 0.38, { mat: "podHorn", sides: 5, pos: [0.06, 0.18, k * 0.12], rot: [k * 25, 0, 40] })),
  sphere(0.2, { mat: "podD", detail: 1, pos: [0.04, 0.02, 0], scale: [0.6, 1, 1.2] }),
  tendril([0, 0.3, 0], 0.18, 1, 1.3, 0.1, "palmStemL")))
// dead leaves round a foot: little brown heart leaves lying flat, overlapping
const LEAFLET = [[0.3, -0.15], [0.5, 0.1], [0.42, 0.45], [0.2, 0.8], [0, 1]]
const litter = (n, ru, rv, seed, s = 0.13) => Array.from({ length: n }, (_, i) => {
  const r = (k) => rnd(i, k, seed), a = r(1) * Math.PI * 2, d = Math.sqrt(r(2))
  const [x, z] = at(Math.cos(a) * d * ru, Math.sin(a) * d * rv)
  return tf({ pos: [x, 0.004 + (i % 4) * 0.004, z], rot: [0, r(3) * 360, 0] }, tf({ rot: [-90 + (r(4) - 0.5) * 30, 0, 0], scale: s * (0.8 + r(5) * 0.5) },
    extrude(halfLeaf(LEAFLET, 1), 0.01, { mat: ["litter", "litterL", "litterD"][i % 3] }),
    extrude(halfLeaf(LEAFLET, -1), 0.01, { mat: ["litterL", "litter", "litter"][i % 3] })))
})

// snapping plant (2770): a stalk climbing 3 m to a big pod, palm whorls at
// 0.9-2 m, a small pod low on the left
model("snap_plant",
  palmStalk([0, 0], [-0.15, 3.0, 0], 0.06, 0.2, 1), pod([-0.15, 3.0, 0], 0.95, 180, 20),
  palmStalk([0, 0], [0.05, 2.0, 0], 0.05, -0.15, 2), whorl([0.05, 2.0, 0], 11, 0.75, 25, 14, 3),
  palmStalk([0.05, 0.05], [0.75, 1.6, -0.1], 0.045, -0.1, 3), whorl([0.75, 1.6, -0.1], 12, 0.8, 25, 15, 5),
  palmStalk([0, 0], [-0.75, 1.15, 0.05], 0.04, 0.1, 4), whorl([-0.75, 1.15, 0.05], 10, 0.65, 20, 16, 7),
  palmStalk([0.05, 0], [0.45, 0.9, 0.15], 0.04, 0.05, 5), whorl([0.45, 0.9, 0.15], 11, 0.7, 20, 16, 9),
  palmStalk([0, 0], [-0.75, 1.0, 0.1], 0.03, 0.1, 6), pod([-0.75, 1.0, 0.1], 0.55, 180, 10),
  litter(26, 0.5, 0.3, 11))
// snapping plant with three pods (2772): the big pod on top at 2.9 m, one
// each side at 1.3 m, whorls between
model("snap_plant_three",
  palmStalk([0, 0], [0.05, 2.9, 0], 0.055, 0.2, 21), pod([0.05, 2.9, 0], 0.95, 180, 20),
  palmStalk([0, 0], [-0.65, 1.3, 0.1], 0.04, 0.1, 22), pod([-0.65, 1.3, 0.1], 0.65, 180, 10),
  palmStalk([0.05, 0], [0.75, 1.35, 0], 0.04, -0.1, 23), pod([0.75, 1.35, 0], 0.6, 0, 10),
  palmStalk([0, 0], [-0.15, 2.0, 0], 0.045, -0.1, 24), whorl([-0.15, 2.0, 0], 11, 0.7, 25, 14, 25),
  palmStalk([0, 0.05], [0.45, 1.9, -0.1], 0.045, 0.1, 25), whorl([0.45, 1.9, -0.1], 11, 0.75, 25, 15, 27),
  palmStalk([0, 0], [-0.3, 1.0, 0.15], 0.04, 0.05, 26), whorl([-0.3, 1.0, 0.15], 11, 0.7, 20, 16, 29),
  palmStalk([0, 0], [0.4, 0.95, 0.15], 0.04, -0.05, 27), whorl([0.4, 0.95, 0.15], 10, 0.65, 20, 16, 31),
  litter(24, 0.45, 0.28, 33))
// low snapping plant (2773): broad whorls at 1.3-2.2 m, a pod reaching out
// sideways on the left
model("snap_plant_low",
  palmStalk([0, 0], [-0.35, 2.2, 0], 0.05, 0.1, 41), whorl([-0.35, 2.2, 0], 12, 0.85, 25, 14, 43),
  palmStalk([0.05, 0], [0.55, 2.0, -0.1], 0.05, -0.1, 42), whorl([0.55, 2.0, -0.1], 12, 0.8, 25, 15, 45),
  palmStalk([0, 0], [0.05, 1.3, 0.1], 0.045, 0.05, 43), whorl([0.05, 1.3, 0.1], 11, 0.75, 20, 16, 47),
  palmStalk([0, 0], [-0.9, 1.75, 0], 0.035, 0.25, 44), pod([-0.9, 1.75, 0], 0.75, 180, 5),
  litter(24, 0.45, 0.3, 49))
// dark palm (2774): no pods; a tall whorl at 3.2 m on the right, a big one
// of pale leaves in the middle at 2.2 m, darker ones low on both sides
const PALE = [["pale", "paleL"], ["paleL", "pale"], ["pale", "paleL"], ["brown", "pale"]]
model("dark_palm",
  palmStalk([0, 0], [0.35, 3.2, -0.1], 0.05, -0.1, 51), whorl([0.35, 3.2, -0.1], 12, 0.85, 25, 14, 53),
  palmStalk([0, 0], [-0.05, 2.2, 0.05], 0.06, 0.1, 52), whorl([-0.05, 2.2, 0.05], 14, 1.0, 25, 13, 55, PALE, 0.17),
  palmStalk([0, 0], [-0.75, 1.6, 0], 0.045, 0.15, 53), whorl([-0.75, 1.6, 0], 11, 0.8, 20, 15, 57, [["umber", "brown"], ["dolive", "doliveL"]]),
  palmStalk([0.05, 0], [0.55, 1.4, 0.1], 0.045, -0.1, 54), whorl([0.55, 1.4, 0.1], 11, 0.8, 20, 15, 59, [["dolive", "doliveL"], ["pale", "paleL"]]),
  litter(28, 0.5, 0.3, 61))
// small dark palm (2775): two whorls at 2.6 m, two at 1.5 m, the right one olive
model("dark_palm_small",
  palmStalk([0, 0], [-0.4, 2.55, 0], 0.045, 0.1, 71), whorl([-0.4, 2.55, 0], 11, 0.75, 25, 14, 73),
  palmStalk([0, 0], [0.5, 2.5, -0.1], 0.045, -0.1, 72), whorl([0.5, 2.5, -0.1], 11, 0.8, 25, 15, 75),
  palmStalk([0, 0], [-0.45, 1.55, 0.1], 0.04, 0.05, 73), whorl([-0.45, 1.55, 0.1], 10, 0.7, 20, 16, 77, [["rust", "rustL"], ["umber", "brown"]]),
  palmStalk([0.05, 0], [0.4, 1.5, 0.1], 0.04, -0.05, 74), whorl([0.4, 1.5, 0.1], 10, 0.7, 20, 16, 79, [["dolive", "doliveL"]]),
  litter(24, 0.45, 0.28, 81))
for (const n of ["snap_plant", "snap_plant_three", "snap_plant_low", "dark_palm", "dark_palm_small"]) looms(n)

// --- callas (group «planta» 2776, group «planta mediana» 2777) ---------------
// a rosette of broad brown leaves lying out, long brown stalks carrying a
// dark green spathe with a blue spadix
const OVAL = [[0.25, 0.08], [0.42, 0.3], [0.42, 0.55], [0.28, 0.8], [0, 1]]
// the rosette: long strap leaves lying out low all round, a few standing
const CALLA_TONES = [["pale", "brown"], ["rust", "brown"], ["paleL", "pale"], ["brown", "umber"]]
const rosette = (n, len, seed) => [
  whorl([0, 0.02, 0], n, len, 22, 4, seed, CALLA_TONES, 0.22),
  whorl([0, 0.02, 0], Math.round(n / 3), len * 0.8, 50, 8, seed + 1, CALLA_TONES, 0.2)]
// a calla on a stalk from the foot to p (screen u, y, v): the spathe a cupped
// leaf leaning out to `yaw`, the spadix standing in it
const calla = (p, yaw, s = 0.32) => [
  stem(path((t) => sp(p[0] * t + 0.05 * Math.sin(t * Math.PI), p[1] * t, p[2] * t), 0.03, 0.02, 6), "palmStemL", 5),
  leafAt(sp(...p), yaw, 70, s, OVAL, ["spatheL", "spathe"], 55, 0.8),
  tf({ pos: sp(p[0], p[1] + 0.02, p[2] + 0.04) }, cone(0.045 * s / 0.32, 0.28 * s / 0.32, { mat: "spadix", sides: 6, rot: [0, 0, -10] }))]
model("calla_pair", rosette(12, 0.85, 91), calla([-0.15, 1.85, 0], 120, 0.45), calla([0.3, 1.6, -0.05], 60, 0.42), litter(10, 0.35, 0.2, 93, 0.11))
model("calla", rosette(10, 0.8, 95), calla([0.05, 1.45, 0], 80, 0.45), litter(8, 0.3, 0.2, 97, 0.11))
for (const n of ["calla_pair", "calla"]) looms(n)

// --- fern sprigs (group «planta mediana» 2145-2147, group «planta» 2148) ----
// lime sprigs about 1.6 m tall: thin stems zigzagging up and branching, a
// pair of small pointed leaflets at every bend, over a tuft of olive grass
const SPRIG = [[0.05, 0.1], [0.09, 0.35], [0.06, 0.7], [0, 1]]
// one zigzag stem from (u, y) climbing h, k bends, leaning `lean` (screen u
// per metre); a leaflet pair at each bend, pointing out and up
function zigzag(u, y0, h, k, lean, seed, w = 0.012) {
  const pts = [], out = []
  for (let i = 0; i <= k; i++) {
    const t = i / k, zz = (i % 2 ? 1 : -1) * 0.06 * (1 - t * 0.5)
    pts.push([...sp(u + lean * t * h + (i ? zz : 0), y0 + t * h, 0.02 * Math.sin(i + seed)), w * (1 - t * 0.6)])
    // three spiky leaflets at each bend: out to each side and one down
    if (i) out.push([-1, 0, 1].map((sd) => leafAt(sp(u + lean * t * h + zz, y0 + t * h, 0.03),
      sd > 0 ? 20 + rnd(i, 1, seed) * 30 : sd < 0 ? 160 - rnd(i, 2, seed) * 30 : (i % 2 ? 0 : 180),
      sd ? 30 + rnd(i, 3, seed) * 35 : -40, 0.2 + rnd(i, 4, seed) * 0.08, SPRIG, (i + sd + 2) % 2 ? ["leafL", "leaf"] : ["leaf", "leafD"], 20)))
  }
  // the tip: a leaflet straight up
  out.push(leafAt(sp(...[u + lean * h, y0 + h, 0.02]), 90, 80, 0.14, SPRIG, ["leafL", "leaf"]))
  return [stem(pts, "stemD", 4), out]
}
const fernSprig = (seed) => [
  zigzag(0.0, 0, 1.6, 8, 0.02, seed), zigzag(-0.2, 0, 1.25, 6, -0.12, seed + 1), zigzag(0.22, 0, 1.3, 6, 0.1, seed + 2),
  zigzag(-0.05, 0.6, 0.75, 4, -0.35, seed + 3), zigzag(0.08, 0.7, 0.7, 4, 0.35, seed + 4), zigzag(-0.1, 0.1, 0.9, 5, -0.25, seed + 5),
  fineTuft(16, [[-0.35, 0.05], [0.35, 0.05], [0, 0.1]], [0.35, 0.2], 0.2, 0.5, 0.06, 0, 30, seed + 6, (i, r) => r > 0.5 ? ["oliveD", "olive", "oliveD"] : ["oliveD", "oliveL", "olive"])]
model("fern_sprig", fernSprig(201))
looms("fern_sprig")

// --- fan sprouts (2781, 2782, 2783: owner "plantita negra") ------------------
// two little fan palms on a creeping stem: each a rosette of round fan
// leaves cut into fingers. Drawn yellow (2781), green (2782) and purple
// (2783) in the retail: the three looms
const FAN_TONES = { fan: ["#9a9018", "#4e8a20", "#7a3060"], fanL: ["#bcb030", "#70a832", "#9a4a7a"], fanD: ["#6a6a14", "#2e5a1a", "#5a2244"] }
SET(FAN_TONES, 0.7)
SKINNED.push(...Object.keys(FAN_TONES))
// a fan leaf: a half disc of fingers, each a thin wedge from the stalk
const fanLeaf = (r, mat) => Array.from({ length: 7 }, (_, i) => {
  const a = (-60 + i * 20) / DEG
  return extrude([0, 0, Math.sin(a - 0.07) * r, Math.cos(a - 0.07) * r, Math.sin(a) * r * 1.05, Math.cos(a) * r * 1.05, Math.sin(a + 0.07) * r, Math.cos(a + 0.07) * r], 0.006, { mat: i % 2 ? mat : mat + "L", pos: [0, 0, i * 0.0005] })
})
const fanRosette = (p, n, r, seed) => tf({ pos: sp(...p) }, Array.from({ length: n }, (_, i) => {
  const yaw = i * 360 / n + rnd(i, 1, seed) * 30
  const a = (yaw + 45) / DEG
  return tf({ rot: [0, Math.atan2(Math.cos(a), -Math.sin(a)) * DEG, 0] }, tf({ rot: [-(20 + rnd(i, 2, seed) * 30), 0, 0] },
    tube([0, 0, 0, 0, 0, r * 0.6], 0.008, { mat: "fanD", sides: 4 }),
    tf({ pos: [0, 0, r * 0.55], rot: [90, 0, 0] }, fanLeaf(r, "fan"))))
}))
model("fan_sprouts", { scale: 0.55 },
  stem(path((t) => sp(-0.3 + t * 0.55, 0.05 + 0.08 * Math.sin(t * Math.PI), 0.05 * Math.sin(t * 5)), 0.016, 0.012), "fanD", 4),
  fanRosette([0.2, 0.08, 0], 7, 0.24, 301), fanRosette([-0.3, 0.05, 0.05], 6, 0.17, 303))
looms("fan_sprouts")

// --- thorny roots (group «raíz con pinchos»: 2599, 2601, 2602, 2604, 2605;
// 2600 from «hojas secas») ----------------------------------------------------
// thick green roots arching out of the ground and back in, or rising to
// curl over, studded with cream thorns pointing out from the curve
const THORN = { root: ["#5e7e22", "#6a4a2a", "#5a3a5a"], rootL: ["#7e9c32", "#8a6438", "#7a5278"],
  thorn: ["#e2d690", "#d8c8a0", "#e0d0c0"], thornD: ["#a89a52", "#9a8460", "#a0889a"] }
SET(THORN, 0.7)
SKINNED.push(...Object.keys(THORN))
// a smooth curve through screen points [u, y, v] (Catmull-Rom), n per span
function spline(pts, n = 5) {
  const out = []
  for (let i = 0; i < pts.length - 1; i++) {
    const p0 = pts[Math.max(0, i - 1)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[Math.min(pts.length - 1, i + 2)]
    for (let k = 0; k < n; k++) {
      const t = k / n, t2 = t * t, t3 = t2 * t
      out.push([0, 1, 2].map((c) => 0.5 * (2 * p1[c] + (-p0[c] + p2[c]) * t + (2 * p0[c] - 5 * p1[c] + 4 * p2[c] - p3[c]) * t2 + (-p0[c] + 3 * p1[c] - 3 * p2[c] + p3[c]) * t3)))
    }
  }
  out.push(pts[pts.length - 1])
  return out
}
// a root along screen points: r0 at the start tapering to r1, a flared
// collar where it leaves the ground, thorns every `step` along it pointing
// out from the curve (alternating sides, some towards the camera)
function thornRoot(pts, r0, r1, seed, { step = 0.1, collarEnd = false } = {}) {
  r0 *= 1.25; r1 *= 1.25
  const c = spline(pts), L = c.length
  const body = stem(c.map((p, i) => [...sp(...p), r0 + (r1 - r0) * i / (L - 1)]), "root", 7)
  const thorns = []
  let acc = 0
  for (let i = 1; i < L; i++) {
    const [u0, y0] = c[i - 1], [u1, y1] = c[i], d = Math.hypot(u1 - u0, y1 - y0)
    acc += d
    if (acc < step) continue
    acc = 0
    const k = thorns.length, side = k % 2 ? 1 : -1, r = r0 + (r1 - r0) * i / (L - 1)
    const nu = -(y1 - y0) / d * side, ny = (u1 - u0) / d * side
    const th = Math.atan2(-nu, ny) * DEG, tip = (rnd(k, 1, seed) - 0.5) * 70
    thorns.push(tf({ pos: sp(...c[i]), rot: [0, 45, 0] }, tf({ rot: [tip, 0, th] },
      cone(r * 0.6, r * 1.1 + 0.03, { mat: k % 3 ? "thorn" : "thornD", sides: 3, pos: [0, r * 0.7, 0] }))))
  }
  const collar = (p, rr) => tf({ pos: sp(p[0], 0, p[2]) }, cone(rr * 1.45, rr * 2.4, { mat: "root", sides: 7, jitter: 0.01, seed }))
  return [body, thorns, collar(pts[0], r0), collarEnd ? collar(pts[pts.length - 1], r1) : []]
}
// an arch from (ua) to (ub) at depth v, h tall
const arch = (ua, ub, h, v, r0, r1, seed, lean = 0) => thornRoot(
  [[ua, -0.02, v], [ua + (ub - ua) * 0.05 + lean, h * 0.65, v], [(ua + ub) / 2 + lean, h, v], [ub - (ub - ua) * 0.05 + lean * 0.5, h * 0.6, v], [ub, -0.02, v]],
  r0, r1, seed, { collarEnd: true })
// a root rising from (u) and curling over to `dir` at the top into a hook
const curl = (u, h, v, dir, r0, r1, seed) => thornRoot(
  [[u, -0.02, v], [u + dir * 0.05, h * 0.55, v], [u + dir * 0.18, h * 0.95, v], [u + dir * 0.36, h, v], [u + dir * 0.44, h * 0.82, v], [u + dir * 0.36, h * 0.68, v], [u + dir * 0.28, h * 0.76, v]],
  r0, r1, seed)

// thorny roots (2599, 2605): a tall arch on the left, a root on the right
// rising to curl over
model("thorn_arches", { pivot: "origin" },
  arch(-0.62, -0.05, 0.95, 0, 0.085, 0.07, 401, -0.05), curl(0.12, 0.85, 0.05, 1, 0.08, 0.035, 403))
// a row of thorny arches (2601): a small one each side of a tall narrow one
model("thorn_row", { pivot: "origin" },
  arch(-0.7, -0.35, 0.45, 0.05, 0.065, 0.055, 411), arch(-0.18, 0.08, 0.95, 0, 0.08, 0.07, 413), arch(0.32, 0.65, 0.42, 0.05, 0.065, 0.055, 415))
// a tangle of thorny roots (2602, 2604): a root curling over on the left,
// two arches overlapping on the right
model("thorn_tangle", { pivot: "origin" },
  curl(-0.55, 0.9, 0, 1, 0.08, 0.035, 421), arch(-0.2, 0.45, 0.65, -0.1, 0.075, 0.065, 423), arch(0.1, 0.7, 0.45, 0.12, 0.07, 0.06, 425))
// thorny stub (2600): a root standing up 0.9 m, broken off, a loose piece
// of it lying across its foot
model("thorn_stub", { pivot: "origin" },
  thornRoot([[0, -0.02, 0], [0.04, 0.35, 0], [-0.02, 0.65, 0], [0.03, 0.88, 0]], 0.08, 0.065, 431, { step: 0.11 }),
  thornRoot([[-0.2, 0.06, 0.15], [0.05, 0.08, 0.2], [0.25, 0.05, 0.18]], 0.06, 0.055, 433, { step: 0.11 }))
for (const n of ["thorn_arches", "thorn_row", "thorn_tangle", "thorn_stub"]) looms(n)

// --- dry leaves (group «hojas secas»: 2771, 2779) -----------------------------
// little brown heart leaves lying flat in a drift, overlapping
model("leaf_litter", litter(40, 0.68, 0.62, 501, 0.2))
model("leaf_litter_small", litter(14, 0.3, 0.26, 503, 0.18))
for (const n of ["leaf_litter", "leaf_litter_small"]) looms(n)

// --- stones of the jungle ruins (groups «tótem de roca» 2323, 2326, 2329 and
// «roca con pintura» 2324) ----------------------------------------------------
// mossy olive stone (arena 6's stoneMoss loom), carved with pale spirals and
// meanders; moss cushions and grass on top
pal(Object.fromEntries(LOOMS.flatMap((s, i) => [
  ["mossStone" + s, { tex: "../arena6/out/stoneMoss" + s, uv: 1.2, rough: 0.9, color: ["#e8e4c8", "#e4e8e4", "#f0e0d4"][i] }],
  ["mossStoneD" + s, { tex: "../arena6/out/stoneMoss" + s, uv: 1.2, rough: 0.9, color: ["#9a9478", "#94989a", "#a08a80"][i] }],
])))
const RUIN = { carve: ["#d6cca0", "#c8c8c0", "#dcc0a8"], carveD: ["#b4ac80", "#a8a8a2", "#bc9e88"], slot: ["#2e2a18", "#262628", "#2e1e18"],
  mossTop: ["#6e7e1c", "#3e6428", "#7a6e20"], mossTopL: ["#8c9e26", "#58823a", "#9a8c2e"] }
SET(RUIN, 0.85)
SKINNED.push("mossStone", "mossStoneD", ...Object.keys(RUIN))
// a block with chamfered edges: w (x) by d (z), h tall, base at p, turned ry
// (a four-sided lathe of radius 0.7071 is a unit square, then stretched)
const cblock = (w, h, d, p, ry = 0, mat = "mossStone", ch = 0.06, seed = 1) => tf({ pos: p, rot: [0, ry, 0] },
  tf({ scale: [w, 1, d] }, lathe([0, 0, 0.62, 0, 0.7071, ch, 0.7071, h - ch, 0.62, h, 0, h], { mat, sides: 4, jitter: 0.012, seed })))
// a round spiral in the XY plane (it faces +z), R across, as a raised cord
const spiral = (R, turns = 2.2, r = 0.022, mat = "carve") => {
  const pts = []
  for (let i = 0; i <= 40; i++) { const t = i / 40, a = t * turns * Math.PI * 2, rr = R * (0.12 + 0.88 * t); pts.push(Math.cos(a) * rr, Math.sin(a) * rr, 0) }
  return tube(pts, r, { mat, sides: 5 })
}
// a square meander: a spiral of straight runs
const meander = (R, r = 0.025, mat = "carve") => {
  const pts = [0, 0, 0], dirs = [[1, 0], [0, 1], [-1, 0], [0, -1]]
  let x = 0, y = 0
  for (let i = 0; i < 7; i++) { const L = R * 0.28 * (i + 1); x += dirs[i % 4][0] * L; y += dirs[i % 4][1] * L; pts.push(x, y, 0) }
  return tube(pts, r, { mat, sides: 4 })
}
// (boxes sit on their base: y is a box's foot)
// put a carving on a block face: face "z" (+z, the screen's lower left) or
// "x" (+x, lower right), centred at (a, y) on that face, d out from the centre
const onFace = (face, a, y, d, ...items) => face === "z" ? tf({ pos: [a, y, d] }, ...items) : tf({ pos: [d, y, -a], rot: [0, 90, 0] }, ...items)
// moss cushions over a top at height y: flattened lumps
const mossCap = (y, spots, seed) => spots.map(([x, z, r], i) =>
  sphere(r, { mat: i % 2 ? "mossTop" : "mossTopL", detail: 1, pos: [x, y, z], scale: [1, 0.22, 1], jitter: 0.02, seed: seed + i }))
const grassAt = (u, v, n, h, seed) => tf({ pos: sp(u, 0, v) }, fineTuft(n, [[0, 0]], [0.25, 0.15], h * 0.5, h, 0.07, 0, 35, seed,
  (i, r) => r > 0.5 ? ["sappy", "sappyL", "sappy"] : ["oliveD", "sappy", "olive"]))

// stone skull (2326): a big faceted boulder 1.5 m tall, its +z face carved
// as a skull: two square eye sockets with pale frames, four teeth in a row
// along its foot; a carved arch low on its +x side, moss and grass on top.
// Eight sides, turned so one face looks down +z and one down +x; R is the
// face's distance from the centre
const SK = 0.66, SKR = SK / Math.cos(Math.PI / 8)
model("stone_skull",
  lathe([0, 0, SKR * 0.95, 0, SKR, 0.12, SKR, 0.8, SKR * 0.85, 1.05, SKR * 0.5, 1.25, 0, 1.32], { mat: "mossStone", sides: 8, rot: [0, 22.5, 0], jitter: 0.02, seed: 601 }),
  [-1, 1].map((k) => onFace("z", k * 0.26, 0.42, SK,
    box(0.34, 0.4, 0.05, { mat: "carve" }), box(0.2, 0.26, 0.06, { mat: "slot", pos: [0, 0.03, 0.005] }),
    box(0.09, 0.11, 0.07, { mat: "carveD", pos: [0, 0.03, 0.01] }))),
  [-0.3, -0.1, 0.1, 0.3].map((a, i) => onFace("z", a, 0.03, SK + 0.03, box(0.16, 0.26 - (i % 2) * 0.04, 0.1, { mat: i % 2 ? "carveD" : "carve", jitter: 0.008, seed: 610 + i }))),
  // the arch: a doorway outline, flat on the face
  onFace("x", 0.1, 0.0, SK - 0.005, extrude([-0.2, 0, 0.2, 0, ...Array.from({ length: 7 }, (_, i) => { const a = i / 6 * Math.PI; return [Math.cos(a) * 0.2, 0.22 + Math.sin(a) * 0.2] }).flat()], 0.02, { mat: "slot" })),
  mossCap(1.28, [[0, 0, 0.3], [-0.2, 0.18, 0.2], [0.18, -0.2, 0.22]], 621),
  tf({ pos: [0, 1.3, 0] }, fineTuft(10, [[0, 0]], [0.2, 0.1], 0.3, 0.6, 0.07, 0, 30, 625, (i, r) => ["sappy", r > 0.5 ? "sappyL" : "sappy", "sappy"])),
  grassAt(-0.65, 0.25, 9, 0.6, 627))

// carved stone block (2323): a broad mossy block with a big pale spiral on
// its +x face and pale slabs on top, two small dark blocks fallen at its
// front left, a cube on top behind; grass both sides
model("carved_block",
  cblock(1.25, 0.85, 1.05, [0, 0, 0], 0, "mossStone", 0.08, 631),
  cblock(0.42, 0.36, 0.42, [0.15, 0.85, -0.3], 10, "mossStoneD", 0.04, 633),
  onFace("x", 0.05, 0.14, 0.625, box(0.6, 0.56, 0.02, { mat: "mossStoneD" }), tf({ pos: [0, 0.28, 0.015] }, spiral(0.21, 2.0, 0.03))),
  [[-0.3, 0.2, 0.3], [0.25, 0.3, 0.26]].map(([x, z, w], i) => box(w, 0.04, w * 0.8, { mat: "carve", pos: [x, 0.85, z], rot: [0, 15 * i, 0] })),
  cblock(0.4, 0.34, 0.36, [-0.25, 0, 0.72], 20, "mossStoneD", 0.04, 635), cblock(0.34, 0.3, 0.32, [-0.62, 0, 0.55], -10, "mossStoneD", 0.04, 637),
  mossCap(0.86, [[-0.1, -0.1, 0.4], [0.35, 0.1, 0.25], [-0.4, -0.3, 0.22]], 641),
  grassAt(-0.75, 0.1, 8, 0.55, 643), grassAt(0.75, 0.15, 8, 0.6, 645))

// small carved block (2329): a low block with a pale meander on its top and
// two dark slots on its +z face, a cube against its +x side, grass in front
model("carved_block_small",
  cblock(0.8, 0.72, 0.8, [0, 0, 0], 0, "mossStone", 0.06, 651),
  tf({ pos: [0, 0.73, 0], rot: [-90, 0, 0] }, box(0.5, 0.42, 0.03, { mat: "carveD" }), tf({ pos: [-0.1, -0.08, 0.02] }, meander(0.11))),
  [-0.18, 0.15].map((a) => onFace("z", a, 0.25, 0.4, box(0.16, 0.32, 0.02, { mat: "slot" }))),
  cblock(0.42, 0.42, 0.42, [0.62, 0, -0.1], 5, "mossStoneD", 0.04, 653),
  mossCap(0.73, [[0.25, -0.25, 0.18], [-0.28, 0.25, 0.14]], 655),
  grassAt(-0.1, 0.55, 12, 0.6, 657))

// painted rock (2324): a mossy egg-shaped boulder 1.2 m tall, pale spirals
// painted on its two front faces, grass at its foot
const decal = ([dx, dy, dz], R, ...items) => {
  const L = Math.hypot(dx, dy, dz), d = [dx / L, dy / L, dz / L]
  return tf({ pos: [d[0] * R, d[1] * R, d[2] * R], rot: [0, Math.atan2(d[0], d[2]) * DEG, 0] }, tf({ rot: [-Math.asin(d[1]) * DEG, 0, 0] }, ...items))
}
model("painted_rock",
  tf({ pos: [0, 0.68, 0] }, sphere(0.6, { mat: "mossStone", detail: 1, scale: [0.95, 1.13, 0.9], jitter: 0.03, seed: 661 }),
    decal([0.25, 0.1, 1], 0.55, tf({ scale: [1, 1.15, 0.4] }, spiral(0.18, 2.2, 0.024, "carveD"))), decal([1, 0.0, 0.2], 0.58, tf({ scale: [1, 1.15, 0.4] }, spiral(0.16, 2.0, 0.024, "carveD"))),
    decal([1, -0.35, 0.6], 0.55, tf({ scale: [1, 1, 0.4] }, spiral(0.1, 1.6, 0.02, "carveD"))),
    decal([-0.3, 0.75, 0.3], 0.58, sphere(0.2, { mat: "mossTop", detail: 1, scale: [1.2, 1, 0.35] }))),
  grassAt(-0.45, 0.35, 10, 0.6, 663), grassAt(0.4, 0.4, 8, 0.5, 665))
for (const n of ["stone_skull", "carved_block", "carved_block_small", "painted_rock"]) looms(n)

// --- skull on a stake (1601), dry stalk (2159) ---------------------------------
const PROPS = { stake: ["#8a6a36", "#6e665a", "#6a4628"], stakeD: ["#5a4220", "#4a443c", "#462c18"],
  bone: ["#ece4c8", "#dcdcd2", "#e4ccaa"], boneD: ["#a89a78", "#8e8e88", "#a08462"], hole: ["#2a2018", "#222224", "#2a1810"],
  earth: ["#6a4a2a", "#4e4438", "#5e3622"], dry: ["#c4a46a", "#a8a088", "#c08a5a"], dryD: ["#8a6a3a", "#76705e", "#86563a"], dryG: ["#7e8a4a", "#6a7a5a", "#8a7a3e"] }
SET(PROPS, 0.85)
SKINNED.push(...Object.keys(PROPS))
// a long narrow dry leaf
const STRAP = [[0.05, 0.05], [0.09, 0.3], [0.08, 0.7], [0, 1]]
// a skull on a sharpened stake, 1.2 m, a little earth heaped at its foot
model("skull_stake",
  lathe([0.05, 0, 0.045, 0.95, 0.03, 1.08, 0, 1.25], { mat: "stake", sides: 6, jitter: 0.004 }),
  tf({ pos: [0, 0.88, 0], rot: [0, -45, 0], scale: 1.4 },
    sphere(0.13, { mat: "bone", detail: 2, pos: [0, 0.03, 0], scale: [1, 0.9, 1.05] }),
    sphere(0.1, { mat: "bone", detail: 2, pos: [0.06, -0.05, 0], scale: [0.8, 0.8, 1] }),
    [-1, 1].map((k) => sphere(0.04, { mat: "hole", detail: 1, pos: [0.135, -0.02, k * 0.048], scale: [0.6, 1, 1] })),
    sphere(0.018, { mat: "hole", detail: 0, pos: [0.15, -0.075, 0], scale: [0.6, 1, 0.8] }),
    box(0.04, 0.03, 0.1, { mat: "boneD", pos: [0.12, -0.12, 0] })),
  [[0.15, 0.05, 0.09], [-0.12, 0.1, 0.08], [0.02, -0.14, 0.07], [-0.08, -0.06, 0.06], [0.16, -0.08, 0.05]].map(([x, z, r], i) =>
    rock(r, { mat: "earth", seed: 701 + i, pos: [x, r * 0.3, z], scale: [1.3, 0.55, 1.2] })))
// dry stalk (2159): a tall dead leaf stalk 2.3 m, rolled and twisting, its
// tip bowing over to the left; two broken sticks and green round leaves at
// its foot
model("dry_stalk",
  stem(path((t) => sp(-0.05 + 0.12 * Math.sin(t * 2.2) - 0.25 * t * t * t, t * 2.2, 0.03 * Math.sin(t * 5)), 0.055, 0.02, 10), "dryD", 6),
  stem(path((t) => sp(0.05 + 0.08 * Math.sin(t * 2.5) - 0.15 * t * t * t, t * 1.9, 0.06), 0.035, 0.015, 8), "dryG", 5),
  // the dry leaves peeling off the stalk, and the tip leaf hanging over
  leafAt(sp(-0.02, 0.9, 0.05), 100, 80, 0.9, STRAP, ["dry", "dryG"], 30, 0.8),
  leafAt(sp(0.0, 1.5, 0.05), 140, 70, 0.6, STRAP, ["dryD", "dry"], 30, 0.8),
  leafAt(sp(-0.2, 2.15, 0.02), 170, -30, 0.55, STRAP, ["dry", "dryD"], 30, 0.8),
  leafAt(sp(-0.05, 0.2, 0.1), 0, 75, 0.6, STRAP, ["dryG", "dry"], 30, 0.8),
  stem([[...sp(0.35, 0, 0.1), 0.02], [...sp(0.45, 0.65, 0.1), 0.012]], "dryD", 5), stem([[...sp(-0.3, 0, 0.1), 0.02], [...sp(-0.25, 0.35, 0.1), 0.014]], "dryD", 5),
  [[-0.3, 0.25, 160, 0.34], [-0.35, 0.55, 170, 0.3], [0.25, 0.2, 10, 0.32], [0.35, 0.5, 20, 0.3], [-0.1, 0.1, 200, 0.28], [0.1, 0.05, -20, 0.26]].map(([u, y, yaw, sz], i) =>
    sprig([u * 0.3, y * 0.5, 0.25, yaw, 30 + i * 4, sz], i, HEART, i % 2 ? ["leafD", "leafX"] : ["leafX", "leafD"])))
for (const n of ["skull_stake", "dry_stalk"]) looms(n)
