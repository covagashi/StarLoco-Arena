// Arena 2 (retail world 10: autumn and lava) — the pieces it doesn't share
// with the arena 1 kit, each in three looms: <name> (a), <name>_b, <name>_c.
// Broad surfaces use loom textures (kit.tx.js); plants and weapons use
// palette colours, 2–3 tones placed by light. Retail gfx in brackets.
include("../common/shapes.kx.js")

const LOOMS = ["", "_b", "_c"]
pal(Object.fromEntries(LOOMS.flatMap((s) => [
  ["crag" + s, { tex: "out/crag" + s, uv: 1, rough: 0.85 }],
  ["cragM" + s, { tex: "out/crag" + s, uv: 1, rough: 0.85, color: "#d8ccb8" }],
  ["cragD" + s, { tex: "out/crag" + s, uv: 1, rough: 0.9, color: "#a89a86" }],
  ["cragDD" + s, { tex: "out/crag" + s, uv: 1, rough: 0.95, color: "#4a4038" }],
  ["flag" + s, { tex: "out/flag" + s, uv: 1, rough: 0.8 }],
  ["totem" + s, { tex: "out/totem" + s, uv: 0.8, rough: 0.8 }],
])))
// palette looms: [a, b, c] per key
const PAL = {
  leafS: ["#4a3a0e", "#4a120a", "#26321a"], leafD: ["#574510", "#5e1a0e", "#34401a"], leaf: ["#86701c", "#a0341a", "#5a6e26"], leafL: ["#b09a30", "#d8642c", "#8ea444"],
  twig: ["#3b2a1e", "#2e1c16", "#3a3226"], twigP: ["#c8bc9c", "#a89a88", "#b4b0a4"],
  bark: ["#b9b090", "#6e5a44", "#8a8a84"], barkD: ["#7e765c", "#43362a", "#5a5a56"],
  blade: ["#3e3416", "#2c3a1a", "#5a4a26"], bladeL: ["#8a7a3a", "#5e7a34", "#b09a58"],
  plateL: ["#76562e", "#b85a34", "#7a746d"], plate: ["#5e4224", "#8a3a22", "#5e5954"], plateM: ["#50381e", "#74301c", "#4e4a46"], plateD: ["#3e2c18", "#5a2416", "#3e3b38"], plateK: ["#1e140c", "#250c08", "#141414"],
  basalt: ["#4e6656", "#5a5a5e", "#5e4a3a"], basaltL: ["#7a9a80", "#86868a", "#8a7058"], basaltD: ["#2e3e34", "#38383c", "#3a2c22"],
  pale: ["#d8d2b8", "#c8ccd0", "#d8c0a0"], paleD: ["#a8a088", "#9a9ea4", "#a88c6c"], tuft: ["#7a9a3a", "#5a8a4a", "#9a9a3a"],
  tuftL: ["#b4cc52", "#8ec070", "#c8c848"], carve: ["#e6dcae", "#dcdcdc", "#e8c09a"], groove: ["#8a9a6a", "#8a8e94", "#a07a5a"],
  steel: ["#9aa0a8", "#b08a4a", "#8a5a3a"], steelD: ["#5a6068", "#6a4a22", "#4a2a1a"],
  grip: ["#5a3a22", "#3a2a2a", "#6a4a2a"], gripL: ["#a0743c", "#6a5a4a", "#b08a50"], brass: ["#b8903a", "#a0a4a8", "#c07a3a"],
  cloth: ["#d8b8a0", "#b8c0c8", "#c8a0a0"], clothD: ["#a07a6a", "#7a8088", "#8a5a5a"], steelL: ["#d4d8dc", "#d0b070", "#b08060"], boneG: ["#9aa45a", "#8a9a6a", "#a09060"], bone: ["#e4dcc0", "#d0c8a8", "#c8c0b0"], boneD: ["#a8a088", "#988e70", "#8a8478"],
}
pal(Object.fromEntries(LOOMS.flatMap((s, i) => Object.entries(PAL).map(([k, v]) => [k + s, v[i]]))))
pal({ glowL: { color: "#ffb040", emit: "#ff8a20", glow: 4 } })
// the lava of the lava rock (128), the colours of arena 8's lava fall: hot
// in the crack, cooling as it drops; [a, b, c] glowing per key
const LAVA = {
  lava0: ["#f8a818", "#ffd040", "#f06018"], lava1: ["#e88010", "#f8b428", "#c8380c"],
  lava2: ["#c44e0a", "#d88818", "#8a1c08"], lava3: ["#7a2408", "#9a4a0c", "#4e0e06"],
}
const LAVA_GLOW = { lava0: 1.3, lava1: 1.1, lava2: 0.8, lava3: 0.5 }
pal(Object.fromEntries(LOOMS.flatMap((s, i) => Object.entries(LAVA).map(([k, v]) =>
  [k + s, { color: v[i], emit: v[i], glow: LAVA_GLOW[k], rough: 0.35 }]))))
const SKINNED = ["crag", "cragM", "cragD", "cragDD", "flag", "totem", ...Object.keys(PAL), ...Object.keys(LAVA)]
const looms = (name) => threeLooms(name, SKINNED)

// --- ground ------------------------------------------------------------------
// rock block (1240, 1242, 1243, 1244): a cell of cracked earth rock a metre
// tall, built of angular plates: a 3 x 3 jittered grid of them on every
// face and on top, each a little askew and proud, the dark heart showing in
// the cracks between them (as the retail draws it)
const ROCK_H = 1.0
const rndR = (i, k, seed) => ((Math.sin((i + 1) * 12.9898 * k + seed * 78.233) * 43758.5453) % 1 + 1) % 1
// a w x h face split into cols x rows plates: the grid's inner points
// jittered, each cell shrunk to its centre by `gap`; [x0, y0, ...] each
function plates(w, h, cols, rows, seed, gap = 0.018) {
  const P = (i, j) => {
    const inner = i > 0 && i < cols && j > 0 && j < rows
    return [(i / cols - 0.5) * w + (inner ? (rndR(i * 7 + j, 1, seed) - 0.5) * w / cols * 0.6 : 0),
      (j / rows) * h + (inner ? (rndR(i * 7 + j, 2, seed) - 0.5) * h / rows * 0.6 : 0)]
  }
  const out = []
  for (let i = 0; i < cols; i++) for (let j = 0; j < rows; j++) {
    const q = [P(i, j), P(i + 1, j), P(i + 1, j + 1), P(i, j + 1)]
    const cx = q.reduce((t, p) => t + p[0], 0) / 4, cy = q.reduce((t, p) => t + p[1], 0) / 4
    out.push(q.flatMap(([x, y]) => { const dx = x - cx, dy = y - cy, l = Math.hypot(dx, dy); return [x - dx / l * gap, y - dy / l * gap] }))
  }
  return out
}
const SIDE_MATS = ["plate", "plateM", "plateM", "plateD"]
// the four faces (+z, +x, -z, -x) and the top
const rockFace = (k, seed) => tf({ rot: [0, k * 90, 0] }, plates(0.94, ROCK_H - 0.04, 3, 3, seed).map((pts, i) =>
  extrude(pts, 0.06, { mat: SIDE_MATS[Math.floor(rndR(i, 3, seed) * 4)], pos: [0, 0, 0.47 + rndR(i, 4, seed) * 0.02],
    rot: [(rndR(i, 5, seed) - 0.5) * 6, (rndR(i, 6, seed) - 0.5) * 6, 0], jitter: 0.006, seed: seed + i })))
const rockTop = (seed) => plates(0.96, 0.96, 3, 3, seed, 0.016).map((pts, i) =>
  extrude(pts.map((v, j) => j % 2 ? v - 0.48 : v), 0.06, { mat: rndR(i, 3, seed) > 0.3 ? "plateL" : "plate",
    rot: [-90 + (rndR(i, 5, seed) - 0.5) * 5, 0, (rndR(i, 6, seed) - 0.5) * 5], pos: [0, ROCK_H - 0.03 + rndR(i, 4, seed) * 0.02, 0], jitter: 0.006, seed: seed + i }))
model("rock_block",
  box(0.92, ROCK_H - 0.02, 0.92, { mat: "plateK" }),
  [0, 1, 2, 3].map((k) => rockFace(k, 11 + k * 5)), rockTop(7))
model("crag_col", prismUp(roundSquare(CELL_HALF, 0.04), 1, 0, "crag", 0.012))
// flagstone (129, 130, 131): a low slab with a lip spilling over its rim
model("flagstone",
  prismUp(roundSquare(0.5, 0.1), 0.05, 0, "flag", 0.006),
  prismUp(roundSquare(0.47, 0.1), 0.09, 0.04, "flag", 0.008))
// the lava cells (142, 143) are arena 8's lava_spots (shared in kit.json)
for (const n of ["rock_block", "crag_col", "flagstone"]) looms(n)

// --- plants ------------------------------------------------------------------
// Screen terms, as in the later kits: u along the screen's horizontal (world
// (1, 0, -1)), v towards the camera (world (1, 0, 1)), metres. Retail sizes
// from the sprites: 61 px a metre along u, 52.7 px a metre up.
const R2 = Math.SQRT1_2
const sp = (u, y, v) => [(u + v) * R2, y, (v - u) * R2]
const rnd = (i, k, seed) => ((Math.sin((i + 1) * 12.9898 * k + seed * 78.233) * 43758.5453) % 1 + 1) % 1
const CAM = [0.612, 0.5, 0.612]
// a bush leaf: ovate with a pointed tip, 1 long, its stalk end at the
// origin, in the XY plane pointing +y (eight points: a big bush has hundreds)
const OVATE = [0, 0, 0.24, 0.16, 0.32, 0.45, 0.2, 0.78, 0, 1, -0.2, 0.78, -0.32, 0.45, -0.24, 0.16]
const leaf = (s, mat) => extrude(OVATE.map((v) => v * s), 0.012, { mat })
// a spray of n leaves fanned round screen angle `dir` (0 right, 90 up) at
// world point p, in the plane facing the camera, each tipped a little out
// of it
const spray = (p, s, n, dir, spread, mats, seed) => tf({ pos: p, rot: [0, 45, 0] }, Array.from({ length: n }, (_, i) => {
  const a = dir - spread / 2 + spread * (n > 1 ? i / (n - 1) : 0.5) + (rnd(i, 1, seed) - 0.5) * 24
  return tf({ rot: [0, 0, a - 90] }, tf({ rot: [(rnd(i, 2, seed) - 0.5) * 70, (rnd(i, 3, seed) - 0.5) * 30, 0] },
    leaf(s * (0.8 + rnd(i, 4, seed) * 0.4), mats[i % mats.length])))
}))
// a mass of foliage: sprays over the surface of screen-space ellipsoids
// [u, y, v, ru, ry, rv], a dark core inside each so no gaps show; the sprays
// on top and facing the camera lighter, underneath and behind darker; the
// ones turned fully away are left out
function foliage(blobs, count, s, seed, hollow = null) {
  const vol = blobs.map((b) => b[3] * b[4] * b[5]), tot = vol.reduce((x, y) => x + y, 0)
  const out = blobs.map(([u, y, v, ru, ry, rv], k) => tf({ pos: sp(u, y, v), rot: [0, 45, 0] },
    sphere(1, { mat: "leafS", detail: 1, scale: [ru * 0.7, ry * 0.7, rv * 0.7], jitter: 0.04, seed: seed + k })))
  for (let i = 0; i < count; i++) {
    let t = rnd(i, 1, seed) * tot, k = 0
    while (t > vol[k] && k < blobs.length - 1) t -= vol[k++]
    const [u, y, v, ru, ry, rv] = blobs[k]
    // a direction on the sphere (more of them up and towards the camera)
    const z = rnd(i, 2, seed) * 2 - 0.7, ph = rnd(i, 3, seed) * Math.PI * 2, rr = Math.sqrt(Math.max(0, 1 - Math.min(1, z * z)))
    const nu = Math.cos(ph) * rr, nv = Math.sin(ph) * rr * 0.6 + 0.4 * Math.abs(Math.sin(ph) * rr), ny = Math.min(1, z)
    const d = 0.72 + rnd(i, 5, seed) * 0.26, pu = u + nu * ru * d, py = y + ny * ry * d, pv = v + nv * rv * d
    if (hollow && Math.hypot((pu - hollow[0]) / hollow[3], (py - hollow[1]) / hollow[4]) < 1 && pv > v) continue
    const w = sp(nu, ny, nv), face = (w[0] * CAM[0] + w[1] * CAM[1] + w[2] * CAM[2])
    if (face < -0.35) continue
    const light = ny * 0.55 + face * 0.45 + (rnd(i, 4, seed) - 0.5) * 0.35
    const mats = light > 0.38 ? ["leafL", "leaf"] : light > -0.05 ? ["leaf", "leaf", "leafL"] : ["leafD", "leaf"]
    // the spray fans out along the surface: its screen angle from the normal
    const dir = Math.atan2(ny * 0.87 - nv * 0.5, nu) * 180 / Math.PI
    out.push(spray(sp(pu, py, pv), s * (0.9 + 0.25 * d), 5, dir, 190, mats, seed * 13 + i))
  }
  return out
}
// a twig through screen points [u, y, v] (pale, as the retail draws them),
// r at its foot tapering by half; a spray of leaves at its tip if `tip`
const twig = (pts, r, tip = 0, seed = 1, mat = "twigP") => {
  const w = pts.map((p) => sp(...p)), out = []
  for (let i = 0; i < w.length - 1; i++)
    out.push(tube([...w[i], ...w[i + 1]], r * (1 - 0.5 * i / (w.length - 1)), { mat, sides: 5 }), i ? sphere(r * (1 - 0.5 * i / (w.length - 1)) * 0.92, { mat, detail: 0, pos: w[i] }) : [])
  if (tip) {
    const [a, b] = [pts[pts.length - 2], pts[pts.length - 1]]
    out.push(spray(w[w.length - 1], tip, 5, Math.atan2(b[1] - a[1], b[0] - a[0]) * 180 / Math.PI, 200, ["leaf", "leafL", "leafD"], seed))
  }
  return out
}
// autumn bush (1016, 1022, 1028, 1033, 1034): a hedge 2.4 m across and 2 m
// tall, dense with leaves, a dark hollow low in its middle where the pale
// stems show, twigs poking out of its top and sides with sprays at their ends
model("autumn_bush", { scale: 0.88 },
  foliage([[0, 0.85, 0, 0.95, 0.9, 0.5], [-0.75, 0.55, 0.1, 0.5, 0.6, 0.38], [0.75, 0.6, 0, 0.5, 0.65, 0.38], [0.1, 1.55, -0.1, 0.6, 0.45, 0.4]],
    155, 0.22, 1, [-0.05, 0.6, 0, 0.36, 0.38]),
  twig([[-0.1, 0, 0.1], [-0.15, 0.6, 0.15], [-0.35, 1.3, 0.1], [-0.55, 2.2, 0.05], [-0.62, 2.45, 0]], 0.028, 0.22, 2),
  twig([[0.05, 0, 0.1], [0.12, 0.7, 0.15], [0.3, 1.4, 0.05], [0.5, 2.1, 0], [0.75, 2.35, 0]], 0.028, 0.22, 3),
  twig([[-0.2, 0.9, 0.2], [-0.8, 1.3, 0.15], [-1.25, 1.45, 0.1]], 0.025, 0.2, 4),
  twig([[0.2, 1.0, 0.2], [0.85, 1.5, 0.1], [1.2, 1.75, 0.05]], 0.025, 0.2, 5),
  twig([[0.3, 1.8, 0], [0.35, 2.3, 0], [0.5, 2.6, 0]], 0.02, 0.18, 6, "twig"))
// tall autumn bush (1021, 1035): a leafy mass 1.9 m tall, bare branches
// climbing out of it to 3.8 m, forking, a few sprays left on their tips
model("autumn_bush_tall", { scale: 0.92 },
  foliage([[0, 0.82, 0, 0.9, 0.88, 0.5], [0.45, 1.45, 0, 0.6, 0.5, 0.4], [-0.6, 0.55, 0.1, 0.45, 0.55, 0.35]], 140, 0.22, 21),
  twig([[-0.1, 0.8, 0.1], [-0.3, 1.8, 0.1], [-0.55, 2.8, 0.05], [-0.5, 3.6, 0]], 0.034, 0.2, 22),
  twig([[-0.4, 2.3, 0.05], [-0.85, 2.85, 0.05], [-1.0, 3.2, 0]], 0.025, 0.18, 23),
  twig([[0.1, 1.2, 0.1], [0.2, 2.0, 0.05], [0.35, 2.8, 0], [0.3, 3.2, 0]], 0.03, 0, 24),
  twig([[0.3, 2.4, 0], [0.8, 2.6, 0], [1.3, 3.0, 0], [1.55, 3.1, 0]], 0.028, 0, 25),
  twig([[0.9, 2.65, 0], [1.05, 3.05, 0], [1.0, 3.3, 0]], 0.018, 0, 26),
  twig([[-0.2, 1.0, 0.25], [-0.9, 1.35, 0.2], [-1.3, 1.6, 0.1]], 0.025, 0.2, 27))
// autumn tree (1029): a great bush-tree 2.5 m across and 3.2 m tall, its
// leaves in a ring round a dark hollow where the pale forked stem shows,
// dark branches out of its top, sprays reaching out at both sides
model("autumn_tree", { scale: 0.8 },
  twig([[0, 0, 0], [0.0, 0.8, 0], [-0.3, 1.6, 0], [-0.45, 2.2, 0]], 0.09, 0, 41),
  twig([[0.0, 0.8, 0], [0.35, 1.5, 0], [0.5, 2.2, 0]], 0.07, 0, 42),
  foliage([[0, 0.5, 0.05, 0.85, 0.55, 0.5], [-0.65, 1.3, 0.05, 0.55, 0.75, 0.42], [0.65, 1.35, 0, 0.55, 0.8, 0.42],
    [0.05, 2.15, -0.05, 0.8, 0.55, 0.45], [0.05, 1.3, -0.35, 0.6, 0.7, 0.3]], 180, 0.24, 43, [0.0, 1.3, 0, 0.42, 0.45]),
  twig([[0.0, 2.3, 0], [0.05, 2.9, 0], [-0.05, 3.35, 0], [0.0, 3.6, 0]], 0.04, 0.2, 44, "twig"),
  twig([[0.05, 2.9, 0], [0.4, 3.15, 0], [0.55, 3.3, 0]], 0.022, 0, 45, "twig"),
  twig([[0.3, 2.4, 0], [0.55, 2.9, 0], [0.6, 3.1, 0]], 0.02, 0, 46, "twig"),
  twig([[-0.6, 1.1, 0.2], [-1.1, 1.4, 0.15], [-1.35, 1.55, 0.1]], 0.025, 0.22, 47),
  twig([[0.6, 1.6, 0.2], [1.05, 1.95, 0.1], [1.3, 2.0, 0.05]], 0.025, 0.22, 48))
// bare tree (2558, 2559): a slim pale trunk 2.6 m tall, flared roots, moss
// at its foot, dead stubs and a few crooked twigs, its top split in two
// leaders, a handful of leaves left
const stub = (y, a, len, up, r) => tf({ pos: [0, y, 0], rot: [0, a, 0] }, tf({ rot: [0, 0, -90 + up] },
  cyl(r, len, { mat: "bark", sides: 5, top: r * 0.55 }), sphere(r * 0.7, { mat: "barkD", detail: 0, pos: [0, len, 0] })))
model("bare_tree",
  lathe([0.16, 0, 0.11, 0.12, 0.085, 0.5, 0.075, 1.2, 0.06, 1.8, 0.045, 2.1], { mat: "bark", sides: 7, jitter: 0.02, seed: 3 }),
  // knots and swellings up the trunk
  [[0.35, 20], [0.8, 140], [1.15, 260], [1.5, 60], [1.9, 200]].map(([y, a], i) => tf({ rot: [0, a, 0] },
    sphere(0.05 - i * 0.004, { mat: i % 2 ? "barkD" : "bark", detail: 1, pos: [0.07 - i * 0.006, y, 0], scale: [1, 1.6, 1] }))),
  [0, 72, 144, 216, 288].map((a, i) => tf({ rot: [0, a + 20, 0] }, tf({ pos: [0.09, 0.03, 0], rot: [0, 0, -68] }, cone(0.06, 0.22 + (i % 2) * 0.08, { mat: i % 2 ? "barkD" : "bark", sides: 5 })))),
  [[0.25, 0.04, 0.2], [-0.15, 0.05, 0.22], [0.0, 0.03, 0.3]].map(([u, v, r], i) => cyl(r, 0.03, { mat: "tuft", sides: 7, pos: sp(u * 0.6, 0, v), scale: [1, 1, 0.7] })),
  twig([[0, 2.05, 0], [0.05, 2.35, 0], [0.12, 2.6, 0]], 0.04, 0, 51, "bark"), twig([[0, 2.05, 0], [-0.08, 2.4, 0], [-0.14, 2.55, 0]], 0.035, 0, 52, "bark"),
  stub(0.55, 30, 0.14, 25, 0.035), stub(0.95, 200, 0.18, 35, 0.03), stub(1.3, 100, 0.12, 20, 0.03), stub(1.65, 300, 0.16, 40, 0.025),
  stub(0.75, 110, 0.1, 30, 0.028), stub(1.1, 330, 0.12, 15, 0.025), stub(1.45, 230, 0.1, 45, 0.022), stub(1.95, 80, 0.12, 30, 0.02),
  twig([[0.05, 1.45, 0], [0.28, 1.62, 0], [0.42, 1.6, 0], [0.48, 1.7, 0]], 0.018, 0, 53, "barkD"),
  twig([[-0.04, 1.85, 0], [-0.3, 2.05, 0], [-0.38, 2.2, 0]], 0.016, 0, 54, "barkD"),
  twig([[0.03, 2.3, 0], [0.3, 2.45, 0], [0.42, 2.42, 0]], 0.014, 0, 55, "barkD"),
  [[0.45, 1.72], [-0.38, 2.22], [0.42, 2.43], [0.14, 2.62], [-0.16, 1.1], [0.12, 0.75]].map(([u, y], i) =>
    spray(sp(u, y, 0.05), 0.16, 2 + (i % 2), u > 0 ? 30 : 150, 70, i % 2 ? ["leaf", "leafL"] : ["leafL", "leaf"], 60 + i)))
// fallen leaves (127, 201, 202, 203): seven maple leaves, sharp-lobed, lying
// about a metre of ground, a few curled up at an edge
const MAPLE = (() => {
  // five pointed lobes (r over the angle), deep notches, a short stalk
  const pts = []
  for (let k = 0; k < 40; k++) {
    const t = k / 40 * Math.PI * 2 - Math.PI / 2, f = ((t + Math.PI / 2) / (Math.PI * 2) * 5) % 1, tri = 1 - 2 * Math.abs(f - 0.5)
    // broad lobes ending in sharp tips; the bottom lobes shorter
    const r = 0.5 * (0.58 + 0.42 * Math.pow(tri, 1.6)) * (1 - 0.3 * Math.max(0, Math.sin(t + Math.PI / 2 + Math.PI)))
    pts.push(Math.cos(t + Math.PI) * r, Math.sin(t + Math.PI) * r + 0.1)
  }
  return pts
})()
model("fallen_leaves",
  [[0, 0, 0, "leafL", 0.3], [0.38, 0.12, 40, "leaf", 0.26], [-0.36, 0.14, 110, "leafL", 0.28], [0.18, -0.26, 200, "leaf", 0.24],
   [-0.45, -0.14, 300, "leafD", 0.22], [0.56, -0.12, 80, "leafL", 0.2], [-0.1, 0.34, 160, "leaf", 0.25]].map(([u, v, a, m, s], i) =>
    tf({ pos: sp(u, 0.006 + i * 0.002, v), rot: [0, a, 0] }, extrude(MAPLE, 0.012, { mat: m, rot: [90 + (i % 3 === 1 ? 14 : 0), 0, 0], scale: s }))))
// spiky grass (246): a clump of long flat blades 1.2 m, fanned out, each
// dark with pale bands across (as the retail paints them)
const bandBlade = (h, w, mats) => {
  const cut = [0, 0.3, 0.38, 0.62, 0.7, 1], seg = []
  const half = (t) => w / 2 * (1 - t) * (t < 0.15 ? 0.7 + t * 2 : 1)
  for (let k = 0; k < cut.length - 1; k++) {
    const t0 = cut[k], t1 = cut[k + 1]
    seg.push(extrude([half(t0), h * t0, half(t1) + (t1 >= 1 ? 0 : 0), h * t1, t1 >= 1 ? 0 : -half(t1), h * t1, -half(t0), h * t0].filter((v, j, arr) => !(t1 >= 1 && j === 4) && !(t1 >= 1 && j === 5)),
      0.008, { mat: mats[k % 2] }))
  }
  return seg
}
model("spiky_grass",
  Array.from({ length: 20 }, (_, i) => {
    const a = (i / 20) * 300 - 150 + (rnd(i, 1, 7) - 0.5) * 20, h = 0.9 + rnd(i, 2, 7) * 0.5, lean = 6 + Math.abs(a) * 0.22 + rnd(i, 3, 7) * 8
    // each blade faces the camera give or take, leaning out to its side
    return tf({ pos: sp((rnd(i, 4, 7) - 0.5) * 0.15, 0, (rnd(i, 5, 7) - 0.5) * 0.12), rot: [0, 45 + (rnd(i, 6, 7) - 0.5) * 60, 0] },
      tf({ rot: [(rnd(i, 7, 7) - 0.5) * 30, 0, -Math.sign(a) * lean] }, bandBlade(h, 0.16, i % 3 ? ["blade", "bladeL"] : ["bladeL", "blade"])))
  }))
for (const n of ["autumn_bush", "autumn_bush_tall", "autumn_tree", "bare_tree", "fallen_leaves", "spiky_grass"]) looms(n)

// --- stone -------------------------------------------------------------------
// rock column (921): a tall pillar of cracked rock, three cells high
model("rock_column",
  prismUp(roundSquare(0.32, 0.06), 1.2, 0, "crag", 0.03),
  prismUp(roundSquare(0.3, 0.06), 1.1, 1.18, "crag", 0.035),
  prismUp(roundSquare(0.27, 0.07), 0.95, 2.26, "crag", 0.035),
  box(0.3, 0.4, 0.08, { mat: "crag", pos: [0.15, 0.6, 0.3], rot: [3, 10, 4], jitter: 0.02 }),
  box(0.08, 0.5, 0.26, { mat: "crag", pos: [-0.31, 1.6, 0.05], rot: [0, 0, -3], jitter: 0.02 }))
// basalt rocks (137): a knot of a dozen hexagonal stone columns 1.4 m
// across, the tallest 1.15 m at the back, short ones in front; each top a
// paler cap, bevelled, a few snapped off aslant; a thin column apart on the
// right
const basalt = ([u, v, h, r, tilt], i) => tf({ pos: sp(u, 0, v), rot: [0, 45 + i * 13, 0] },
  cyl(r, h, { mat: i % 3 ? "basalt" : "basaltD", sides: 6, jitter: 0.008, seed: i }),
  tf({ pos: [0, h, 0], rot: [tilt, 0, tilt * 0.5] }, cyl(r * 0.98, 0.04, { mat: "basalt", sides: 6, pos: [0, -0.02, 0] }),
    cyl(r * 0.93, 0.03, { mat: "basaltL", sides: 6, top: r * 0.8, pos: [0, 0.02, 0] })))
model("basalt_rocks", { scale: 0.78 },
  [[-0.35, -0.3, 0.9, 0.17, 0], [0.0, -0.32, 1.15, 0.18, 0], [0.35, -0.28, 0.95, 0.17, -14],
   [-0.55, 0.0, 0.55, 0.16, 10], [-0.18, 0.0, 0.85, 0.18, 0], [0.18, 0.02, 1.0, 0.18, 0], [0.55, 0.0, 0.72, 0.16, 0],
   [-0.36, 0.3, 0.42, 0.16, 0], [0.0, 0.3, 0.6, 0.17, 12], [0.36, 0.28, 0.4, 0.16, 0],
   [-0.62, 0.5, 0.28, 0.13, 0], [0.18, 0.55, 0.24, 0.13, -10], [0.78, -0.12, 0.88, 0.09, 0]].map(basalt))
// lava rock (128): a flagstone at the edge of a step over the lava, cracked
// near its +x edge, the crack glowing; from where it reaches the +x side the lava
// pours down about a metre in two streams, a thin one and a wide one,
// cooling as they fall (the colours of arena 8's lava fall)
const crack = [[0.02, 0.12, 0.16, 0.05], [0.16, 0.05, 0.32, 0.08], [0.32, 0.08, 0.47, 0.02]]
const lavaStream = (z, r, len) => [
  tube([0.4, 0.13, z, 0.5, 0.11, z, 0.53, 0.0, z], r, { mat: "lava0", sides: 6 }),
  ["lava0", "lava0", "lava1", "lava2"].map((m, i) => cyl(r * (1 - i * 0.06), len / 4,
    { mat: m, sides: 6, pos: [0.53, -(i + 1) * len / 4, z], scale: [0.5, 1, 1], jitter: 0.004, seed: i + 3 })),
]
model("lava_rock", { pivot: "origin" },
  prismUp(roundSquare(0.5, 0.1), 0.05, 0, "flag", 0.006),
  prismUp(roundSquare(0.47, 0.1), 0.09, 0.04, "flag", 0.008),
  // the crack: a glowing seam a hair proud of the top, zig-zagging to +x
  crack.map(([x0, z0, x1, z1]) => {
    const len = Math.hypot(x1 - x0, z1 - z0), a = Math.atan2(z1 - z0, x1 - x0) * 180 / Math.PI
    return box(len + 0.03, 0.012, 0.035, { mat: "lava0", pos: [(x0 + x1) / 2, 0.126, (z0 + z1) / 2], rot: [0, -a, 0] })
  }),
  lavaStream(0.02, 0.1, 1.0), lavaStream(-0.2, 0.035, 0.85))
// totems (274: two heads, 275: three, the top one horned): rounded carved
// heads stacked on dark necks, about a cell wide. Pale spirals stand proud of
// the faces the camera sees (+x, +z); the eyes are dark sockets under a pale
// brow; grass grows out of every joint.
// a pillow block: five stacked prisms, the caps inset (rounded edges)
const pillow = (w, h, y, r, s) => [[0.1, 0.11], [0.14, 0.04], [0.5, 0], [0.14, 0.04], [0.1, 0.11]].reduce(
  (acc, [f, inset]) => (acc.items.push(prismUp(roundSquare(w - inset * w / 0.4, r), h * f + 0.012, y + acc.y - 0.006, "totem", 0.008)), acc.y += h * f, acc),
  { items: [], y: 0 }).items
// an S spiral, drawn with a tube in the XY plane, 0.14 m tall; `a` is the arm
const spiralPath = (sz) => {
  const arm = (cx, cy, sgn) => Array.from({ length: 9 }, (_, i) => {
    const t = i / 8, ang = sgn * (-Math.PI / 2 + t * Math.PI * 1.6), r = sz * (0.5 - 0.33 * t)
    return [cx + Math.cos(ang) * r * sgn, cy + Math.sin(ang) * r, 0]
  })
  const top = arm(0, sz * 0.5, 1), bot = arm(0, -sz * 0.5, -1)
  return [...bot.reverse(), [0, 0, 0], ...top].flat()
}
const spiral = (sz, pos, rot, s) => tube(spiralPath(sz), sz * 0.11, { mat: "carve", sides: 5, pos, rot, jitter: 0.003, seed: s })
// the two faces the camera sees: +z (rot 0) and +x (rot y 90)
const onZ = (w, x, y) => [[x, y, w + 0.015], [0, 0, 0]]
const onX = (w, z, y) => [[w + 0.015, y, z], [0, 90, 0]]
const eyes = (w, y, gap) => [
  sym("x", box(0.14, 0.12, 0.03, { mat: "carve", pos: [gap, y, w + 0.005] }),
    box(0.09, 0.07, 0.025, { mat: "basaltD", pos: [gap, y + 0.02, w + 0.03] })),
  box(gap * 2 + 0.2, 0.05, 0.035, { mat: "carve", pos: [0, y + 0.13, w + 0.005] }),   // brow
  box(0.06, 0.12, 0.03, { mat: "carve", pos: [0, y - 0.1, w + 0.005] }),               // nose
]
const neck = (y, w) => cyl(w * 0.8, 0.09, { mat: "basaltD", sides: 8, pos: [0, y, 0] })
const grass = (x, y, z, n, s) => Array.from({ length: n }, (_, i) => {
  const a = (i * 137.5 + s * 40) % 360, h = 0.22 + ((i * 7 + s) % 4) * 0.05
  return tf({ pos: [x, y, z], rot: [0, a, 0] }, cone(0.03, h, { mat: i % 2 ? "tuft" : "tuftL", sides: 3, pos: [0.06, 0, 0], rot: [0, 0, -(22 + (i * 11) % 25)], scale: [1, 1, 0.5] }))
})
// a cell-wide head: spirals on both seen faces
const carvedHead = (y, h, w, s) => [
  pillow(w, h, y, 0.12, s),
  spiral(0.26, ...onZ(w, -w * 0.4, y + h * 0.5), s), spiral(0.2, ...onZ(w, w * 0.42, y + h * 0.42), s + 1),
  spiral(0.26, ...onX(w, w * 0.35, y + h * 0.5), s + 2), spiral(0.2, ...onX(w, -w * 0.42, y + h * 0.42), s + 3),
]
// a face head: eyes on +z, a spiral on +x
const faceHead = (y, h, w, s) => [
  pillow(w, h, y, 0.11, s), eyes(w, y + h * 0.58, w * 0.42),
  spiral(0.24, ...onX(w, 0, y + h * 0.5), s + 4),
]
model("totem",
  carvedHead(0, 1.0, 0.47, 1), neck(0.97, 0.3),
  faceHead(1.03, 0.85, 0.38, 2),
  box(0.46, 0.12, 0.3, { mat: "totem", pos: [0, 1.05, 0.42], jitter: 0.01, seed: 3 }),      // the jutting jaw
  grass(-0.1, 1.86, 0.05, 7, 1), grass(0.32, 1.0, 0.3, 4, 2), grass(-0.4, 1.0, 0.15, 3, 3),
  grass(0.35, 0, 0.42, 4, 4), grass(-0.45, 0, -0.1, 3, 5), grass(0.1, 0, 0.5, 3, 6))
// the ram head on top: a big pillow, heavy brow, thick horns hugging its
// sides and curling forward and down
const horn = (sgn, x, y) => {
  const pts = Array.from({ length: 11 }, (_, i) => {
    const a = Math.PI * (0.55 - i * 0.18), r = 0.25 - i * 0.011
    return [sgn * (x + 0.06 + i * 0.004), y + Math.sin(a) * r, Math.cos(a) * r]
  })
  return [tube(pts.flat(), 0.07, { mat: "carve", sides: 6, jitter: 0.004 }),
    cone(0.07, 0.15, { mat: "carve", sides: 6, pos: pts[10], rot: [-105, 0, 0] })]
}
model("totem_tall",
  carvedHead(0, 0.95, 0.46, 11), neck(0.92, 0.3),
  faceHead(0.98, 0.8, 0.38, 12), neck(1.75, 0.28),
  pillow(0.43, 0.9, 1.81, 0.16, 13), eyes(0.43, 1.81 + 0.9 * 0.5, 0.17),
  horn(1, 0.43, 2.44), horn(-1, 0.43, 2.44),
  grass(0.05, 2.71, -0.05, 6, 7), grass(0.3, 1.78, 0.25, 4, 8), grass(-0.38, 0.95, 0.2, 4, 9),
  grass(0.4, 0.95, -0.1, 3, 10), grass(0.3, 0, 0.42, 4, 11), grass(-0.45, 0, 0.0, 3, 12))
// white stones (611, 616): pieces of a broken carved floor, pale cream, a
// big slab carved with two spirals and smaller fragments round it (one
// tipped up on another), green grass between them
const groove = (sz, x, z, a) => tube(spiralPath(sz), sz * 0.07, { mat: "groove", sides: 4, pos: [x, 0.062, z], rot: [-90, 0, a], scale: [1, 1, 0.35] })
const shard = (pts, x, z, a, y = 0, tilt = 0, mat = "pale") => extrude(pts, 0.05, { mat, pos: [x, y + 0.03, z], rot: [-90 + tilt, 0, a], jitter: 0.004 })
model("white_stones",
  shard([-0.36, -0.22, 0.12, -0.3, 0.4, -0.1, 0.34, 0.22, -0.05, 0.3, -0.38, 0.12], 0, 0, 10),
  groove(0.22, -0.12, 0.02, 20), groove(0.16, 0.18, -0.06, 200),
  shard([-0.14, -0.1, 0.12, -0.12, 0.16, 0.08, -0.1, 0.12], 0.5, 0.3, 40, 0, 0, "paleD"),
  shard([-0.12, -0.08, 0.14, -0.1, 0.1, 0.12, -0.14, 0.08], -0.42, 0.42, 110),
  shard([-0.1, -0.1, 0.12, -0.06, 0.08, 0.1, -0.12, 0.08], 0.42, -0.36, 250),
  shard([-0.16, -0.1, 0.14, -0.12, 0.18, 0.1, -0.12, 0.1], -0.5, -0.28, 300, 0, 0, "paleD"),
  groove(0.1, -0.42, 0.42, 30),
  [[0.32, 0.12], [-0.4, 0.05], [0.12, 0.4], [-0.15, -0.4], [0.55, -0.05], [-0.2, 0.42]].map(([x, z], i) => tf({ scale: [1, 0.45, 1] }, grass(x, 0, z, 4, 20 + i))))
for (const n of ["rock_column", "basalt_rocks", "lava_rock", "totem", "totem_tall", "white_stones"]) looms(n)

// --- weapons -------------------------------------------------------------------
// Drawn big, as the retail does (its props are about 1.5 times life): each
// stands in the plane facing the camera (rot y 45), leaning as the sprite.
// a wrapped grip along y: rings of two tones
const wrap = (r, len, y0, n, mats = ["grip", "gripL"]) => Array.from({ length: n }, (_, i) =>
  cyl(r * (i % 2 ? 1.0 : 1.12), len / n + 0.002, { mat: mats[i % 2], sides: 7, pos: [0, y0 + i * len / n, 0] }))
// mace and arrow on the ground (1272, 1270): a spiked iron head lying in
// the dirt, its wrapped haft raised on it; an arrow beside it
model("weapons_ground",
  tf({ pos: sp(0.25, 0.16, 0.05), scale: 1.2 }, sphere(0.13, { mat: "steelD", detail: 1 }), cyl(0.15, 0.04, { mat: "steel", sides: 8, pos: [0, -0.02, 0], rot: [0, 0, 0] }),
    [[0, 0], [72, 0], [144, 0], [216, 0], [288, 0], [36, 60], [180, 60], [0, -60]].map(([a, e]) => tf({ rot: [0, a, e] },
      cone(0.04, 0.11, { mat: "steel", sides: 4, pos: [0.11, 0, 0], rot: [0, 0, -90] })))),
  // the haft rests on the head and runs back to the ground, wrapped in
  // two-tone bands
  (() => {
    const a = sp(0.1, 0.16, 0.03), b = sp(-0.28, 0.045, -0.24), n = 7, out = []
    for (let i = 0; i < n; i++) {
      const t0 = i / n, t1 = (i + 1) / n, P = (t) => a.map((v, k) => v + (b[k] - v) * t)
      out.push(tube([...P(t0), ...P(t1)], i % 2 ? 0.045 : 0.052, { mat: i === 0 ? "steel" : i % 2 ? "gripL" : "grip", sides: 7 }))
    }
    return out
  })(),
  tf({ pos: sp(-0.2, 0.025, 0.35), rot: [0, 20, 0] },
    cyl(0.012, 0.5, { mat: "grip", sides: 5, rot: [0, 0, 90], pos: [0.25, 0, 0] }),
    cone(0.03, 0.08, { mat: "steel", sides: 4, rot: [0, 0, -90], pos: [0.25, 0, 0] }),
    [-1, 1].map((k) => extrude([0, 0, 0.1, 0, 0.12, 0.05, 0.02, 0.05], 0.004, { mat: "bone", pos: [-0.26, 0, 0], rot: [k * 90, 0, 0] }))))
// glaive stuck in the ground (1289): a pale curved blade sunk in the earth,
// a cloth-wrapped grip between brass ferrules, a leaf-shaped steel blade
// above it; 1.5 m, leaning right
model("sword_stuck",
  tf({ rot: [0, 45, 0] }, tf({ rot: [0, 0, -14] },
    extrude([-0.02, -0.05, 0.14, -0.05, 0.2, 0.12, 0.14, 0.32, 0.05, 0.46, -0.04, 0.46, 0.0, 0.3, -0.02, 0.1], 0.035, { mat: "bone" }),
    cyl(0.045, 0.04, { mat: "brass", sides: 7, pos: [0.0, 0.45, 0] }), wrap(0.045, 0.32, 0.49, 6, ["cloth", "clothD"]),
    cyl(0.045, 0.04, { mat: "brass", sides: 7, pos: [0, 0.81, 0] }),
    extrude([-0.06, 0.84, 0.06, 0.84, 0.14, 1.05, 0.11, 1.28, 0.02, 1.47, -0.05, 1.3, -0.09, 1.05], 0.03, { mat: "steel" }),
    extrude([-0.02, 0.88, 0.02, 0.88, 0.04, 1.3, 0.02, 1.4, -0.01, 1.3], 0.032, { mat: "steelL" }))))
// spear stuck in the ground (1294): a wooden shaft, a steel head with a
// long blade and two prongs curving up from its collar; 2 m
model("spear_stuck",
  tf({ rot: [0, 45, 0] }, tf({ rot: [0, 0, 5] },
    cyl(0.032, 1.45, { mat: "grip", sides: 6, top: 0.028 }),
    cyl(0.045, 0.1, { mat: "steelD", sides: 6, pos: [0, 1.42, 0] }),
    extrude([-0.07, 1.5, 0.07, 1.5, 0.05, 1.7, 0, 1.98, -0.05, 1.7], 0.03, { mat: "steel" }),
    extrude([-0.02, 1.52, 0.02, 1.52, 0.015, 1.9, 0, 1.95, -0.015, 1.9], 0.036, { mat: "steelL" }),
    sym("x", tube([0.03, 1.5, 0, 0.13, 1.52, 0, 0.19, 1.6, 0, 0.2, 1.72, 0], 0.018, { mat: "steel", sides: 5 }),
      cone(0.018, 0.08, { mat: "steel", sides: 4, pos: [0.2, 1.72, 0] })),
    box(0.3, 0.035, 0.035, { mat: "steelD", pos: [0, 1.49, 0] }))))
// great bone blade stuck in the ground (2006): a broad serrated blade of
// bone 1.1 m long, its point in the earth, green-stained low down; a small
// guard, a wrapped grip and a round pommel; 1.65 m
const SAW = (() => {
  // the outline up the right edge then down the left, teeth on both
  const R = [], L = []
  for (let k = 0; k <= 9; k++) {
    const t = k / 9, y = t * 1.08, w = 0.04 + 0.2 * Math.pow(t, 0.7)
    R.push(w, y); if (k < 9) R.push(w + 0.06 - t * 0.02, y + 0.06)
    L.push(-w * 0.85, y); if (k < 9) L.push(-w * 0.85 - 0.05, y + 0.06)
  }
  R.push(0.24, 1.14); L.push(-0.21, 1.14)
  const out = [0, -0.05, ...R]
  for (let i = L.length - 2; i >= 0; i -= 2) out.push(L[i], L[i + 1])
  return out
})()
model("bone_blade_stuck",
  tf({ rot: [0, 45, 0] }, tf({ rot: [0, 0, 4] },
    extrude(SAW, 0.05, { mat: "bone", jitter: 0.004 }),
    // the stain low on the blade, a thicker overlay so it never z-fights
    extrude([0, -0.05, 0.08, 0.05, 0.14, 0.32, 0.02, 0.4, -0.12, 0.3, -0.07, 0.05], 0.062, { mat: "boneG" }),
    extrude([-0.015, 0.1, 0.015, 0.1, 0.02, 1.1, -0.02, 1.1], 0.066, { mat: "boneD" }),
    box(0.5, 0.06, 0.09, { mat: "boneD", pos: [0.01, 1.13, 0] }),
    wrap(0.04, 0.34, 1.19, 7), sphere(0.06, { mat: "brass", detail: 1, pos: [0, 1.58, 0] }))))
for (const n of ["weapons_ground", "sword_stuck", "spear_stuck", "bone_blade_stuck"]) looms(n)
