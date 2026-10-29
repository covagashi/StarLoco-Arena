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
])))
const SKINNED = ["stone", "stoneShade", "stoneDark", "stonePale"]
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
