// Arena 5 (retail world 21: meadow, ruins of a house) — the pieces it doesn't
// share with the arena 1 and 2 kits, each in three looms: <name> (a),
// <name>_b, <name>_c. Broad surfaces use loom textures (kit.tx.js); blades
// and fringes use palette colours, 2–3 tones placed by light. Retail gfx in
// brackets.
include("../common/shapes.kx.js")

const LOOMS = ["", "_b", "_c"]
pal(Object.fromEntries(LOOMS.flatMap((s) => [
  ["grass" + s, { tex: "out/grass" + s, uv: 1.1, rough: 0.8 }],
  ["soil" + s, { tex: "out/soil" + s, uv: 1, rough: 0.85 }],
  // the same grass, shaded darker: the rim of each cell, so the grid reads
  ["grassRim" + s, { tex: "out/grass" + s, uv: 1.1, rough: 0.85, color: "#9ca482" }],
  // packed dark earth, no strata (the dirt block's top face and band)
  ["earth" + s, { tex: "out/earth" + s, uv: 1, rough: 0.9 }],
  ["grassMid" + s, { tex: "out/grass" + s, uv: 1.1, rough: 0.85, color: "#c2c8a8" }],
])))
// palette looms: [a, b, c] per key, matching the grass and soil looms
const PAL = {
  bladeD: ["#4a6410", "#24481e", "#6a5a1e"], blade: ["#7c9e16", "#3e7a2c", "#988a30"], bladeL: ["#b6d232", "#76ac48", "#cfc05a"],
  soilD: ["#5a4220", "#3a2c1c", "#5e2a18"],
}
pal(Object.fromEntries(LOOMS.flatMap((s, i) => Object.entries(PAL).map(([k, v]) => [k + s, v[i]]))))
const SKINNED = ["grass", "grassRim", "grassMid", "soil", "earth", ...Object.keys(PAL)]
const looms = (name) => threeLooms(name, SKINNED)

// --- grass block (315, 316, 317; the owner: the same block) -----------------
// a cell of earth (soil strata on the sides) under a grass top. The owner
// wants every cell to read as its own cushion, the grid showing, like the
// block on its own (not one continuous meadow): the grass domes up from a
// low rim, and the rims of neighbouring cells meet in a groove of lumps and
// hanging blades.
const BODY = 0.72   // top of the soil body; the dome peaks at about 0.94
// the grass top, its base at y = b: a wavy lip of dark earth, a thin grass
// sheet to the rim, the dome (darker grass round its foot), the fringe on every side, a few tufts
function grassTop(b) {
  // the grass spilling over one edge (the +z edge; turned for the others):
  // a row of soft lumps bulging past the rim, blades hanging from them
  const fringe = (seed) => {
    const out = []
    for (let i = 0; i < 7; i++) {
      const t = -0.42 + i * 0.14 + (((i * 37 + seed * 11) % 5) - 2) * 0.008
      out.push(sphere(0.085 + ((i + seed) % 3) * 0.012, { mat: "grassMid", detail: 1, pos: [t, b + 0.05, 0.465],
        scale: [1.15, 0.55, 0.62], jitter: 0.01, seed: seed + i }))
    }
    for (let i = 0; i < 13; i++) {
      const t = -0.45 + i * (0.9 / 12) + (((i * 29 + seed * 7) % 5) - 2) * 0.01
      const len = 0.09 + ((i * 7 + seed) % 4) * 0.025, lean = 140 + ((i * 13 + seed) % 5) * 6
      const m = (i + seed) % 3 === 0 ? "bladeL" : (i + seed) % 3 === 1 ? "blade" : "bladeD"
      out.push(cone(0.035, len, { mat: m, sides: 3, pos: [t, b + 0.04, 0.5], rot: [lean, ((i * 29) % 40) - 20, 0], scale: [1, 1, 0.35] }))
    }
    return out
  }
  const tuft = (x, z, n, sd) => Array.from({ length: n }, (_, i) =>
    tf({ pos: [x, b + 0.12, z], rot: [0, (i * 137.5 + sd * 50) % 360, 0] },
      cone(0.02, 0.11 + ((i * 7 + sd) % 4) * 0.03, { mat: i % 3 ? "blade" : "bladeL", sides: 3, rot: [20 + (i * 11) % 25, 0, 0], scale: [1, 1, 0.4] })))
  return [
    prismUp(roundSquare(CELL_HALF + 0.012, 0.08, 6, 0.035, 3), 0.1, b - 0.06, "soilD", 0.008),
    prismUp(roundSquare(CELL_HALF + 0.005, 0.1), 0.035, b + 0.02, "grassRim", 0.004),
    terrain(2 * (CELL_HALF - 0.01), 2 * (CELL_HALF - 0.01),
      { res: 20, height: 0.19, fn: cushionFn(CELL_HALF - 0.01, 0.2, 0.26, 0.25, 5), mat: (h) => (h < 0.18 ? "grassRim" : "grass"), pos: [0, b + 0.03, 0] }),
    [0, 90, 180, 270].map((a, k) => tf({ rot: [0, a, 0] }, fringe(k * 5 + 1))),
    tuft(-0.2, -0.22, 6, 1), tuft(0.22, 0.05, 5, 2), tuft(-0.05, 0.25, 4, 3),
  ]
}
model("grass_block", prismUp(roundSquare(CELL_HALF, 0.06), BODY, 0, "soil", 0.006), grassTop(BODY))
// the grass on its own, to lay on top of another block (the retail map has
// it on grey stone too): y = 0 is that block's top, the lip hangs over its
// sides
model("grass_cap", { pivot: "origin" }, grassTop(0))
// the column under the grass block: plain soil, 1 m tall, strata that carry
// on across stacked columns
model("soil_col", prismUp(roundSquare(CELL_HALF, 0.06), 1, 0, "soil", 0.006))
for (const n of ["grass_block", "grass_cap", "soil_col"]) looms(n)

// --- dirt block (233): bare earth, strata on the sides, a band of packed dark
// earth along the top with a wavy lower edge, the top face dark too, its
// edges worn round. In the retail map it is mostly tinted blue-grey (the grey
// blocks under the grass): that is the editor's tint, not a loom.
model("dirt_block",
  prismUp(roundSquare(CELL_HALF, 0.07), 0.74, 0, "soil", 0.006),
  prismUp(roundSquare(CELL_HALF + 0.002, 0.075), 0.1, 0.72, "earth", 0.006),
  prismUp(roundSquare(CELL_HALF - 0.03, 0.12), 0.04, 0.81, "earth", 0.004))
looms("dirt_block")
