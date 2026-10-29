// Arena 9 (retail world 40: ruins with iron railings) — the pieces it doesn't
// share with the other kits, each in three looms: <name> (a), <name>_b,
// <name>_c. The stone reuses the arena 6 loom textures (build its kit.tx.js
// first). Retail gfx in brackets.
include("../common/shapes.kx.js")

const LOOMS = ["", "_b", "_c"]
pal(Object.fromEntries(LOOMS.flatMap((s, i) => [
  ["stone" + s, { tex: "../arena6/out/stone" + s, uv: 0.9, rough: 0.85 }],
  ["stoneShade" + s, { tex: "../arena6/out/stone" + s, uv: 0.9, rough: 0.85, color: "#e4e0d2" }],
  // the odd pebble a darker, damper stone
  ["stoneDark" + s, { tex: "../arena6/out/stone" + s, uv: 0.9, rough: 0.9, color: "#a49c84" }],
  // the 1428 slab: a greyer, faintly pink stone (the granite loom warmed)
  ["stonePale" + s, { tex: "../arena6/out/stone" + ["_b", "_b", "_c"][i], uv: 0.9, rough: 0.85, color: ["#ffdccc", "#e8e8ec", "#fff0e8"][i] }],
  // the broken paving of arena 11 (2313-2316): a brown stone, light on top
  ["stoneBrown" + s, { tex: "../arena6/out/stone" + ["", "_b", "_c"][i], uv: 0.9, rough: 0.9, color: ["#bca08c", "#a8a49c", "#ccb4ac"][i] }],
])))
// the dark cracks round the broken paving: [a, b, c]
const CRACK = { crack: ["#3a3028", "#2e2e32", "#382622"] }
pal(Object.fromEntries(LOOMS.flatMap((s, i) => Object.entries(CRACK).map(([k, v]) => [k + s, { color: v[i], rough: 1 }]))))
const SKINNED = ["stone", "stoneShade", "stoneDark", "stonePale", "stoneBrown", "crack"]
const looms = (name) => threeLooms(name, SKINNED)

// Screen terms, as in the arena 8 kit: u along the screen's horizontal
// (world (1, 0, -1)), v towards the camera (world (1, 0, 1)), in metres
// (61 px a metre along u at 1×; the retail sprites are measured in those).
const R2 = Math.SQRT1_2
const at = (u, v) => [(u + v) * R2, (v - u) * R2]

// --- pebbles (group «roquitas»: 1413, 2174, 1559, 2168, 2169, 2200, 1428) ---
// small chips of the pale ruin stone scattered on the floor slabs: rounded
// lumps, sharp little pyramids, ridged wedges, flat flakes, worn slabs and
// square-cut blocks. Each pebble [u, v, w, h, d, kind, turn, tilt, mat, y]: w across the
// screen, d towards the camera, h tall; its base sunk 1 cm (or raised to y,
// to lie on another). Sizes and places measured on the retail sprites.
const unit = {
  // a lump: six sides, its rim and foot chamfered
  round: (o) => lathe([0, 0, 0.44, 0, 0.5, 0.2, 0.48, 0.66, 0.38, 0.92, 0.24, 1, 0, 1], { ...o, sides: 6 }),
  // a chip: five sides narrowing to a blunt point
  point: (o) => lathe([0, 0, 0.5, 0, 0.47, 0.22, 0.24, 0.72, 0.06, 1, 0, 1], { ...o, sides: 5 }),
  // a flake: low, wide, a bevelled top
  flat: (o) => lathe([0, 0, 0.48, 0, 0.5, 0.45, 0.4, 0.92, 0.2, 1, 0, 1], { ...o, sides: 7 }),
  // a wedge broken off a block: a ridge along its length
  ridge: (o) => prism(1, 1, 1, o),
  // a slab: worn round, its corners clipped, its top edges bevelled
  slab: (o) => lathe([0, 0, 0.53, 0, 0.54, 0.55, 0.46, 1, 0, 1], { ...o, sides: 8, rot: [0, 22.5, 0] }),
  // a block: square-cut, rounded corners, its top a step in (a bevel)
  block: (o) => [prismUp(roundSquare(0.5, 0.14, 3), 0.62, 0, o.mat, o.jitter), prismUp(roundSquare(0.43, 0.12, 3), 0.38, 0.62, o.mat, o.jitter)],
}
const pebble = ([u, v, w, h, d, kind = "round", turn = 0, tilt = 0, mat, y = -0.01], seed) => {
  const [x, z] = at(u, v)
  // jitter in the unit shape, before it is scaled to the pebble
  return tf({ pos: [x, y, z], rot: [tilt, 45 + turn, tilt * 0.6], scale: [w, h + 0.01, d] },
    unit[kind]({ mat: mat ?? (seed % 3 ? "stone" : "stoneShade"), jitter: kind === "slab" || kind === "block" ? 0.03 : 0.07, seed }))
}
const pebbles = (list, seed) => list.map((p, i) => pebble(p, seed + i))

// a scatter of five (1413; 2174 is the same scatter): a lump at the back, a
// sharp chip in front, three crumbs
model("pebbles",
  pebbles([[-0.07, -0.25, 0.20, 0.07, 0.14, "round", 10], [0.11, -0.20, 0.07, 0.03, 0.05, "round"],
    [-0.08, 0.36, 0.23, 0.13, 0.17, "point", 20, 6], [0.34, 0.16, 0.08, 0.04, 0.04, "round", 40],
    [-0.30, 0.26, 0.15, 0.04, 0.10, "flat", -15]], 11))
// a wider scatter (1559): two lumps behind, a chip to the right, a lump in
// front and crumbs between
model("pebbles_spread",
  pebbles([[0.05, -0.35, 0.21, 0.07, 0.14, "round", 15], [-0.16, -0.26, 0.20, 0.08, 0.16, "round", -25],
    [0.34, 0.15, 0.25, 0.12, 0.19, "point", 30, -6], [0.20, 0.03, 0.15, 0.04, 0.10, "flat", 10],
    [-0.16, 0.03, 0.07, 0.03, 0.05, "round"], [0.52, 0.03, 0.07, 0.03, 0.05, "round", 30],
    [-0.49, 0.10, 0.15, 0.04, 0.10, "flat", 5], [-0.07, 0.46, 0.20, 0.08, 0.16, "round", 40]], 21))
// shards (2168): a lump at the back, a ridged wedge on the left, a darker one
// on the right, a small sharp chip in front
model("stone_shards",
  pebbles([[-0.02, -0.33, 0.28, 0.08, 0.22, "round", 5], [-0.22, 0.02, 0.39, 0.14, 0.32, "ridge", -10, 6],
    [0.30, -0.10, 0.15, 0.04, 0.10, "flat", 20], [0.01, 0.08, 0.07, 0.03, 0.08, "round"],
    [0.24, 0.26, 0.36, 0.09, 0.24, "ridge", 20, -6, "stoneDark"], [-0.05, 0.49, 0.18, 0.13, 0.17, "point", 35, 5]], 31))
// a broken flagstone (2169): a long flat slab with a thinner one lying on
// it, a dark wedge and a lump at its left, crumbs
model("stone_flake",
  pebbles([[0.18, 0.06, 0.62, 0.08, 0.38, "slab", -45], [0.21, -0.01, 0.40, 0.04, 0.24, "slab", -40, 0, "stoneShade", 0.065],
    [-0.30, 0.08, 0.21, 0.09, 0.21, "ridge", 30, 8, "stoneDark"], [-0.38, 0.39, 0.20, 0.07, 0.17, "round", -10],
    [-0.27, -0.27, 0.15, 0.03, 0.11, "flat"], [-0.15, -0.11, 0.07, 0.03, 0.05, "round"],
    [-0.03, 0.35, 0.30, 0.08, 0.26, "round", 20]], 41))
// a few crumbs (2200): a sharp chip on the right, a darker lump in front, a
// small chip at the back
model("pebbles_few",
  pebbles([[-0.04, -0.23, 0.13, 0.08, 0.12, "point", 10], [0.28, 0.21, 0.18, 0.13, 0.17, "point", 25, -5],
    [-0.08, 0.27, 0.21, 0.07, 0.17, "round", -15, 0, "stoneDark"], [-0.31, 0.25, 0.15, 0.04, 0.10, "flat", 15],
    [0.21, 0.37, 0.08, 0.03, 0.05, "round"]], 51))
// a bevelled slab of a paler stone (1428), long towards the back right, with
// round pebbles and a chip at its left end
model("slab_chips",
  pebbles([[0.2, 0.1, 0.62, 0.11, 0.3, "block", 45, 0, "stonePale"], [-0.32, 0.22, 0.20, 0.08, 0.2, "round", 0, 0, "stonePale"],
    [-0.15, 0.14, 0.11, 0.05, 0.09, "round", 30, 0, "stonePale"], [-0.22, 0.33, 0.13, 0.06, 0.11, "point", 15, 0, "stonePale"],
    [0.04, -0.26, 0.13, 0.04, 0.1, "round", 0, 0, "stonePale"]], 61))
for (const n of ["pebbles", "pebbles_spread", "stone_shards", "stone_flake", "pebbles_few", "slab_chips"]) looms(n)

// --- broken slabs (group «losa rota»: 2170, 2171 here; 2313-2316 in arena 11)
// floor flags broken into a few flat plates, measured on the retail sprites:
// each plate an outline [u0, v0, u1, v1, ...] in screen metres and its
// thickness t. The pale sandstone ones (2170, 2171) are worn round, their
// tops stepped in a little; the brown paving (2313-2316) is cut sharp and
// lies among dark cracks in the ground.
const outline = (uv) => { const pts = []; for (let k = 0; k < uv.length; k += 2) pts.push(...at(uv[k], uv[k + 1])); return pts }
// the outline pulled in towards its middle by a fraction f
const shrink = (pts, f) => {
  const n = pts.length / 2, cx = pts.filter((_, k) => k % 2 === 0).reduce((a, b) => a + b) / n, cz = pts.filter((_, k) => k % 2).reduce((a, b) => a + b) / n
  return pts.map((p, k) => (k % 2 ? cz : cx) + (p - (k % 2 ? cz : cx)) * (1 - f))
}
const plate = ([t, uv], mat, worn) => {
  const pts = outline(uv)
  return worn
    ? [prismUp(pts, t * 0.65, -0.01, mat, 0.006), prismUp(shrink(pts, 0.1), t * 0.35 + 0.01, t * 0.65 - 0.01, mat, 0.006)]
    : prismUp(pts, t + 0.01, -0.01, mat, 0.004)
}
// a crack: a dark hole with jagged arms, each bent once and thinning to a
// point, just above the ground
const crack = ([u, v, r], seed) => {
  const [x, z] = at(u, v)
  const seg = (x0, z0, x1, z1, w) => {
    const dx = x1 - x0, dz = z1 - z0, l = Math.hypot(dx, dz), nx = -dz / l * w, nz = dx / l * w
    return prismUp([x0 + nx, z0 + nz, x1, z1, x0 - nx, z0 - nz], 0.004, 0, "crack")
  }
  const arms = Array.from({ length: 6 }, (_, i) => {
    const a = (i / 6 + rnd(i, 3, seed) * 0.12) * 2 * Math.PI, len = r * (0.7 + 0.9 * rnd(i, 5, seed))
    const b = a + (rnd(i, 9, seed) - 0.5) * 1.2, w = 0.03 + 0.02 * rnd(i, 7, seed)
    const kx = Math.cos(a) * len * 0.5, kz = Math.sin(a) * len * 0.5
    return [seg(0, 0, kx * 1.15, kz * 1.15, w), seg(kx, kz, kx + Math.cos(b) * len * 0.5, kz + Math.sin(b) * len * 0.5, w * 0.6)]
  })
  return tf({ pos: [x, 0, z] }, arms, prismUp(roundSquare(r * 0.3, r * 0.14, 2, 0.3, seed), 0.005, 0, "crack"))
}
const rnd = (i, k, seed) => ((Math.sin((i + 1) * 12.9898 * k + seed * 78.233) * 43758.5453) % 1 + 1) % 1

// 2170: a big rounded flag, a split one to the right, two slivers
model("broken_slab", { pivot: "origin" },
  plate([0.05, [-0.525, 0.103, -0.426, -0.028, -0.262, -0.226, -0.098, -0.259, 0.066, -0.16, 0.131, 0.07, 0.098, 0.268, -0.066, 0.399, -0.23, 0.432, -0.361, 0.333, -0.492, 0.202]], "stone", true),
  plate([0.05, [0.148, 0.235, 0.262, 0.004, 0.361, -0.16, 0.459, -0.061, 0.574, 0.037, 0.525, 0.202, 0.361, 0.3, 0.23, 0.399, 0.148, 0.333]], "stoneShade", true),
  plate([0.04, [0.0, -0.408, 0.066, -0.473, 0.18, -0.375, 0.197, -0.243, 0.131, -0.243, 0.033, -0.342]], "stone", true),
  plate([0.04, [-0.066, 0.612, 0.0, 0.481, 0.115, 0.415, 0.18, 0.481, 0.066, 0.612, -0.033, 0.645]], "stone", true),
  pebble([0.12, -0.1, 0.06, 0.03, 0.05, "round"], 71))
// 2171: two flags side by side, a thicker broken block in front, a lump behind
model("broken_slab_split", { pivot: "origin" },
  plate([0.05, [-0.484, 0.087, -0.385, -0.045, -0.238, -0.209, -0.107, -0.144, -0.008, 0.087, -0.041, 0.251, -0.156, 0.383, -0.287, 0.383, -0.418, 0.251]], "stone", true),
  plate([0.05, [0.057, 0.087, 0.139, -0.045, 0.27, -0.176, 0.418, -0.176, 0.516, -0.045, 0.467, 0.087, 0.336, 0.284, 0.254, 0.35, 0.189, 0.251, 0.074, 0.152]], "stoneShade", true),
  plate([0.08, [-0.107, 0.533, 0.008, 0.402, 0.221, 0.369, 0.254, 0.501, 0.172, 0.599, 0.074, 0.632, -0.025, 0.599]], "stone", true),
  pebble([0.0, -0.42, 0.18, 0.08, 0.13, "round", 10], 72))
// 2313: a big paving stone, a notched one behind and one to the right
model("cracked_paving", { pivot: "origin" },
  crack([-0.32, -0.066, 0.15], 1), crack([0.205, 0.362, 0.08], 2),
  plate([0.03, [-0.205, -0.54, -0.074, -0.573, 0.107, -0.343, 0.008, -0.211, -0.123, -0.112, -0.205, -0.047, -0.287, -0.178, -0.221, -0.277, -0.205, -0.409]], "stoneBrown"),
  plate([0.03, [-0.467, 0.151, -0.156, 0.052, 0.123, 0.151, 0.238, 0.348, 0.139, 0.545, -0.025, 0.677, -0.107, 0.776, -0.254, 0.644, -0.418, 0.48, -0.467, 0.315]], "stoneBrown"),
  plate([0.03, [0.287, -0.112, 0.369, -0.178, 0.598, 0.052, 0.5, 0.216, 0.303, 0.348, 0.221, 0.249, 0.287, 0.151]], "stoneBrown"))
// 2314: the same, the big stone further left
model("cracked_paving_left", { pivot: "origin" },
  crack([-0.279, -0.181, 0.13], 3), crack([0.115, 0.28, 0.08], 4),
  plate([0.03, [-0.295, -0.392, -0.148, -0.557, -0.049, -0.557, -0.049, -0.326, 0.016, -0.228, 0.016, -0.063, -0.082, -0.063, -0.148, -0.129, -0.23, -0.26]], "stoneBrown"),
  plate([0.03, [-0.426, 0.332, -0.23, 0.134, -0.066, 0.003, 0.098, 0.068, 0.148, 0.2, 0.279, 0.299, 0.197, 0.529, 0.016, 0.661, -0.18, 0.628, -0.393, 0.562]], "stoneBrown"),
  plate([0.03, [0.148, -0.129, 0.246, -0.129, 0.443, 0.068, 0.344, 0.2, 0.18, 0.332, 0.148, 0.134]], "stoneBrown"))
// 2315: three small stones round two cracks
model("cracked_paving_bits", { pivot: "origin" },
  crack([-0.082, 0.115, 0.1], 5), crack([0.295, 0.214, 0.13], 6),
  plate([0.03, [-0.016, -0.458, 0.131, -0.491, 0.311, -0.293, 0.197, -0.162, 0.049, -0.03, -0.033, 0.036, -0.115, -0.063, -0.049, -0.162, -0.016, -0.326]], "stoneBrown"),
  plate([0.03, [-0.361, 0.167, -0.262, 0.101, -0.148, 0.003, -0.131, 0.167, -0.082, 0.299, -0.115, 0.397, -0.213, 0.332, -0.311, 0.233]], "stoneBrown"),
  plate([0.03, [-0.098, 0.365, 0.033, 0.299, 0.197, 0.332, 0.262, 0.463, 0.148, 0.628, 0.082, 0.661, -0.049, 0.562, -0.098, 0.463]], "stoneBrown"))
// 2316: a long stone with a knuckle at its back end, one to the right, a
// crack between them
model("cracked_paving_long", { pivot: "origin" },
  crack([0.082, 0.247, 0.16], 7),
  plate([0.03, [-0.475, 0.167, -0.377, 0.003, -0.262, -0.096, -0.115, -0.293, -0.049, -0.491, 0.033, -0.491, 0.049, -0.293, 0.115, -0.228, 0.148, -0.063, 0.131, 0.036, 0.049, -0.03, -0.082, 0.003, -0.213, 0.134, -0.295, 0.2, -0.41, 0.233]], "stoneBrown"),
  plate([0.03, [0.213, 0.003, 0.279, -0.03, 0.492, 0.134, 0.393, 0.299, 0.213, 0.496, 0.148, 0.397, 0.197, 0.266]], "stoneBrown"))
for (const n of ["broken_slab", "broken_slab_split", "cracked_paving", "cracked_paving_left", "cracked_paving_bits", "cracked_paving_long"]) looms(n)
