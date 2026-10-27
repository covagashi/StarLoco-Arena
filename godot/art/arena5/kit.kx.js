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
])))
// palette looms: [a, b, c] per key, matching the grass and soil looms
const PAL = {
  bladeD: ["#4a6410", "#24481e", "#6a5a1e"], blade: ["#7c9e16", "#3e7a2c", "#988a30"], bladeL: ["#b6d232", "#76ac48", "#cfc05a"],
  soilD: ["#5a4220", "#3a2c1c", "#5e2a18"],
}
pal(Object.fromEntries(LOOMS.flatMap((s, i) => Object.entries(PAL).map(([k, v]) => [k + s, v[i]]))))
const SKINNED = ["grass", "soil", ...Object.keys(PAL)]
const looms = (name) => threeLooms(name, SKINNED)

// --- grass block (315, 316, 317; the owner: the same block) -----------------
// a cell of earth (soil strata on the sides), a wavy lip of dark earth just
// under the top, a thick cushion of grass, its fringe of blades spilling over
// every edge, a few longer dark blades standing out of the top
const TOP = 0.86
// the grass spilling over one edge (the +z edge; turned for the others):
// a row of soft lumps bulging past the rim, blades hanging from them
function fringe(seed) {
  const out = []
  for (let i = 0; i < 7; i++) {
    const t = -0.42 + i * 0.14 + (((i * 37 + seed * 11) % 5) - 2) * 0.008
    out.push(sphere(0.085 + ((i + seed) % 3) * 0.012, { mat: "grass", detail: 1, pos: [t, TOP - 0.07, 0.465],
      scale: [1.15, 0.55, 0.62], jitter: 0.01, seed: seed + i }))
  }
  for (let i = 0; i < 13; i++) {
    const t = -0.45 + i * (0.9 / 12) + (((i * 29 + seed * 7) % 5) - 2) * 0.01
    const len = 0.09 + ((i * 7 + seed) % 4) * 0.025, lean = 140 + ((i * 13 + seed) % 5) * 6
    const m = (i + seed) % 3 === 0 ? "bladeL" : (i + seed) % 3 === 1 ? "blade" : "bladeD"
    out.push(cone(0.035, len, { mat: m, sides: 3, pos: [t, TOP - 0.08, 0.5], rot: [lean, ((i * 29) % 40) - 20, 0], scale: [1, 1, 0.35] }))
  }
  return out
}
const tuft = (x, z, n, s) => Array.from({ length: n }, (_, i) =>
  tf({ pos: [x, TOP - 0.03, z], rot: [0, (i * 137.5 + s * 50) % 360, 0] },
    cone(0.02, 0.11 + ((i * 7 + s) % 4) * 0.03, { mat: i % 3 ? "blade" : "bladeL", sides: 3, rot: [20 + (i * 11) % 25, 0, 0], scale: [1, 1, 0.4] })))
model("grass_block",
  prismUp(roundSquare(CELL_HALF, 0.06), 0.72, 0, "soil", 0.006),
  prismUp(roundSquare(CELL_HALF + 0.012, 0.08, 6, 0.035, 3), 0.1, 0.66, "soilD", 0.008),
  prismUp(roundSquare(CELL_HALF + 0.005, 0.1), 0.035, 0.74, "grass", 0.004),
  terrain(2 * (CELL_HALF - 0.01), 2 * (CELL_HALF - 0.01),
    { res: 20, height: 0.08, fn: cushionFn(CELL_HALF - 0.01, 0.12, 0.08, 0.35, 5), mat: "grass", pos: [0, TOP - 0.08, 0] }),
  [0, 90, 180, 270].map((a, k) => tf({ rot: [0, a, 0] }, fringe(k * 5 + 1))),
  tuft(-0.22, -0.25, 6, 1), tuft(0.25, 0.05, 5, 2), tuft(-0.05, 0.28, 4, 3))
// the column under it: plain soil, 1 m tall, strata that carry on across
// stacked columns
model("soil_col", prismUp(roundSquare(CELL_HALF, 0.06), 1, 0, "soil", 0.006))
for (const n of ["grass_block", "soil_col"]) looms(n)
