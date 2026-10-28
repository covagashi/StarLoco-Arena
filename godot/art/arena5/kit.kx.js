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

// --- corner grass (1199, 1355; the owner: "hierba de esquina", decoration) --
// the grass hanging down a block's open side, where the map ends or drops: a
// curtain over one side of the cell (+z here; the editor turns it, 1355 is
// 1199 on the other face). y = 0 is the block's top. Three layers of jagged
// blades, the long dark ones behind, short light ones in front, a soft roll
// of grass along the rim, the bottom flaring out a little.
// one layer: a strip across the side, its lower edge cut into blade tips
function curtain(len, tips, seed) {
  const pts = [0.5, 0.05, -0.5, 0.05]
  for (let i = 0; i <= tips; i++) {
    const x = -0.5 + i / tips, r = ((i * 37 + seed * 13) % 11) / 10
    pts.push(x, -len * (0.55 + 0.45 * r), x + 0.5 / tips, -len * (0.25 + 0.15 * (1 - r)))
  }
  pts.pop(); pts.pop()
  return pts
}
model("grass_edge", { pivot: "origin" },
  extrude(curtain(0.42, 11, 1), 0.02, { mat: "bladeD", pos: [0, 0, 0.49], rot: [-8, 0, 0], jitter: 0.008, seed: 1 }),
  extrude(curtain(0.3, 13, 2), 0.02, { mat: "blade", pos: [0, 0, 0.515], rot: [-11, 0, 0], jitter: 0.008, seed: 2 }),
  extrude(curtain(0.17, 15, 3), 0.02, { mat: "bladeL", pos: [0, 0, 0.535], rot: [-14, 0, 0], jitter: 0.006, seed: 3 }),
  Array.from({ length: 8 }, (_, i) => sphere(0.07 + (i % 3) * 0.01, { mat: "grassMid", detail: 1,
    pos: [-0.44 + i * 0.125, 0.03, 0.5], scale: [1.2, 0.6, 0.7], jitter: 0.01, seed: i })))
looms("grass_edge")

// --- medium grass (1754) and small grass (1755) ------------------------------
// clumps of short, broad, curved blades spread over the cell; each blade a
// dark base and a light curved tip (two pieces), the lighter ones in front.
// 1755 is lower and sparser, a few blades lying down.
// a blade, h tall, in XY: base piece and tip piece, the tip curling over
// broad in the middle, bending to one side as it rises (x drifts with y²)
const bend = (h, y) => 0.09 * (y / h) * (y / h)
const bladeBase = (h) => [-0.016, 0, 0.016, 0, 0.03 + bend(h, h * 0.32), h * 0.32, -0.026 + bend(h, h * 0.32), h * 0.32]
const bladeTip = (h) => [-0.026 + bend(h, h * 0.3), h * 0.3, 0.03 + bend(h, h * 0.3), h * 0.3, 0.026 + bend(h, h * 0.6), h * 0.6,
  bend(h, h) + 0.004, h, -0.012 + bend(h, h * 0.65), h * 0.65]
function blades(n, area, hMin, hMax, seed, lying = 0) {
  const out = []
  for (let i = 0; i < n; i++) {
    const r = (k) => ((Math.sin((i + 1) * 12.9898 * k + seed * 78.233) * 43758.5453) % 1 + 1) % 1
    // bunched: three clump centres, blades scattered round them
    const c = [[-0.18, -0.05], [0.12, 0.08], [0.02, -0.18]][i % 3]
    const x = (c[0] + (r(1) - 0.5) * 0.3) * area[0] / 0.6, z = (c[1] + (r(2) - 0.5) * 0.25) * area[1] / 0.45
    const h = hMin + r(3) * (hMax - hMin), down = i < lying
    const lean = down ? 70 + r(4) * 15 : 5 + r(4) * 40, turn = r(5) * 360
    const tip = z > 0.05 ? "bladeL" : r(6) > 0.5 ? "bladeL" : "blade"
    out.push(tf({ pos: [x, 0, z], rot: [0, turn, 0] }, tf({ rot: [lean, 0, 0] },
      extrude(bladeBase(h), 0.006, { mat: "bladeD" }), extrude(bladeTip(h), 0.006, { mat: tip, pos: [0, 0, 0.001] }))))
  }
  return out
}
model("grass_tuft", { scale: [1.2, 1.5, 1.2] }, blades(42, [0.6, 0.45], 0.14, 0.27, 1))
model("grass_tuft_small", { scale: [1.2, 1.6, 1.2] }, blades(26, [0.7, 0.5], 0.07, 0.16, 2, 6))
for (const n of ["grass_tuft", "grass_tuft_small"]) looms(n)
