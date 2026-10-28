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
  ["plaster" + s, { tex: "out/plaster" + s, uv: 1.6, rough: 0.9 }],
  ["timber" + s, { tex: "out/timber" + s, uv: 0.8, rough: 0.85 }],
  // packed dark earth, no strata (the dirt block's top face and band)
  ["earth" + s, { tex: "out/earth" + s, uv: 1, rough: 0.9 }],
  ["grassMid" + s, { tex: "out/grass" + s, uv: 1.1, rough: 0.85, color: "#c2c8a8" }],
])))
// palette looms: [a, b, c] per key, matching the grass and soil looms
const PAL = {
  bladeD: ["#4a6410", "#24481e", "#6a5a1e"], blade: ["#7c9e16", "#3e7a2c", "#988a30"], bladeL: ["#b6d232", "#76ac48", "#cfc05a"],
  soilD: ["#5a4220", "#3a2c1c", "#5e2a18"],
  // ivy on the low walls: autumn orange (retail), deep red, green
  ivyD: ["#a83c10", "#6a1414", "#2e5a1e"], ivy: ["#e0661c", "#a02a1e", "#4a8a2c"], ivyL: ["#f4a03a", "#d0503a", "#7ab040"],
  vine: ["#6a5236", "#4e3a2a", "#5a4a30"], iron: ["#2e2a26", "#2e2a26", "#2e2a26"],
  // roof tiles: green glazed (retail), terracotta, slate
  roofD: ["#1e4a32", "#7a3218", "#2a3038"], roof: ["#2e6a48", "#a8482a", "#3e4650"], roofL: ["#4a8a64", "#c8643a", "#5a6470"],
}
pal(Object.fromEntries(LOOMS.flatMap((s, i) => Object.entries(PAL).map(([k, v]) => [k + s, v[i]]))))
const SKINNED = ["grass", "grassRim", "grassMid", "soil", "earth", "plaster", "timber", ...Object.keys(PAL)]
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

// --- house walls (179 low, 181 high; the owner: the same wall, two heights)
// and the roof (178) -------------------------------------------------------
// a cell of lime-plastered wall; on top, two timbers along the two sides the
// camera sees: on +z a beam on two corbels, on +x the wooden water channel
// (a U trough, a little higher), a board capping the rest. The roof sits on
// them. Retail heights: 179 about 2.6 m, 181 about 4.5 m, from the block's
// foot like every tile.
function wall(H) {
  const U = [-0.11, 0, 0.11, 0, 0.11, 0.17, 0.07, 0.17, 0.07, 0.045, -0.07, 0.045, -0.07, 0.17, -0.11, 0.17]
  return [
    prismUp(roundSquare(0.495, 0.012), H, 0, "plaster", 0.006),
    box(0.9, 0.05, 0.9, { mat: "timber", pos: [-0.02, H, -0.02] }),
    box(1.06, 0.16, 0.2, { mat: "timber", pos: [0, H, 0.44], jitter: 0.004, seed: 1 }),
    [-0.22, 0.2].map((x, i) => box(0.13, 0.15, 0.2, { mat: "timber", pos: [x, H - 0.15, 0.53], jitter: 0.004, seed: 2 + i })),
    extrude(U, 1.06, { mat: "timber", pos: [0.46, H + 0.02, 0], jitter: 0.003 }),
  ]
}
model("wall_low", wall(2.45))
model("wall_high", wall(4.35))
// roof (178): a board tilted down toward +z, rows of curved tiles laid on it
// staggered, each overlapping the one below
const tileArc = Array.from({ length: 7 }, (_, i) => [Math.cos(Math.PI * i / 6) * 0.095, Math.sin(Math.PI * i / 6) * 0.06]).flat()
  .concat(Array.from({ length: 7 }, (_, i) => [Math.cos(Math.PI * (6 - i) / 6) * 0.07, Math.sin(Math.PI * (6 - i) / 6) * 0.04]).flat())
model("roof",
  tf({ rot: [24, 0, 0], pos: [0, 0.25, 0] },
    box(1.08, 0.04, 1.12, { mat: "timber", pos: [0, -0.04, 0] }),
    [0, 1, 2].flatMap((row) => Array.from({ length: 6 }, (_, c) => {
      const x = -0.45 + c * 0.18 + (row % 2) * 0.09, m = (c + row) % 3 === 0 ? "roofL" : (c + row) % 3 === 1 ? "roof" : "roofD"
      return x > 0.5 ? null : extrude(tileArc, 0.44, { mat: m, pos: [x, (2 - row) * 0.014, -0.34 + row * 0.34], jitter: 0.004, seed: row * 6 + c })
    }))))
for (const n of ["wall_low", "wall_high", "roof"]) looms(n)

// --- low house walls (193 plain, 194 broken with ivy, 195 ivy, 197 iron mark,
// 223 the wedge at its end; the owner: walls of the house) -------------------
// a ruined garden wall: one cell long (x), half a cell thick, about 1.3 m
// tall, its top worn round, a skirt of grass at its foot. Same plaster as the
// house (the owner: the texture is enough, the decoration bricks 214/215/216
// are left out).
// the wall's side profile (z, y), top corners rounded, extruded along x
const lwProfile = (h, t = 0.23, r = 0.17) => {
  const pts = [-t, 0, t, 0]
  // up the +z side, round the corner to the top, across, down the -z side
  for (let i = 4; i >= 0; i--) { const a = (i / 4) * Math.PI / 2; pts.push(t - r + Math.sin(a) * r, h - r + Math.cos(a) * r) }
  for (let i = 4; i >= 0; i--) { const a = (i / 4) * Math.PI / 2; pts.push(-t + r - Math.cos(a) * r, h - r + Math.sin(a) * r) }
  return pts
}
const lwBody = (h, len = 0.98, seed = 1) => tf({ rot: [0, 90, 0] }, extrude(lwProfile(h), len, { mat: "plaster", jitter: 0.012, seed }))
// grass along the foot of both faces the camera sees
const lwSkirt = (seed) => [
  tf({ pos: [0, 0, 0.25] }, blades(14, [0.95, 0.06], 0.08, 0.17, seed, 3)),
  tf({ pos: [0, 0, -0.25] }, blades(10, [0.95, 0.06], 0.06, 0.13, seed + 7, 3))]
// ivy: a climbing stem with leaves (three-lobed) off it, on the +z face
// a broad leaf of three round lobes (r(θ) over 24 points), stalk at the origin
const ivyLeaf = Array.from({ length: 24 }, (_, i) => {
  const t = (i / 24) * Math.PI * 2, lobe = Math.pow(Math.abs(Math.cos(1.5 * (t - Math.PI / 2))), 0.7)
  const r = 0.05 * (0.62 + 0.38 * lobe) * (1 - 0.45 * Math.max(0, -Math.sin(t)))
  return [Math.cos(t) * r, Math.sin(t) * r + 0.035]
}).flat()
function ivyOn(pts, n, seed, z = 0.245) {
  const out = [tube(pts.flatMap(([x, y]) => [x, y, z + 0.01]), 0.012, { mat: "vine", sides: 4 })]
  for (let i = 0; i < n; i++) {
    const t = (i + 0.5) / n, k = Math.min(pts.length - 2, Math.floor(t * (pts.length - 1)))
    const f = t * (pts.length - 1) - k, x = pts[k][0] + (pts[k + 1][0] - pts[k][0]) * f, y = pts[k][1] + (pts[k + 1][1] - pts[k][1]) * f
    const side = i % 2 ? 1 : -1, m = (i + seed) % 3 === 0 ? "ivyL" : (i + seed) % 3 === 1 ? "ivy" : "ivyD"
    out.push(extrude(ivyLeaf, 0.008, { mat: m, pos: [x + side * 0.04, y, z + 0.02 + (i % 3) * 0.008], rot: [-15, 0, side * (30 + (i * 23) % 50)], scale: 1.5 + ((i * 7 + seed) % 4) * 0.2 }))
  }
  return out
}
model("low_wall", lwBody(1.2, 0.98, 1), lwSkirt(31))
model("low_wall_ivy", lwBody(1.28, 0.98, 2), lwSkirt(41),
  ivyOn([[-0.2, 0], [-0.22, 0.25], [-0.14, 0.5], [-0.2, 0.75], [-0.1, 0.95]], 12, 1),
  ivyOn([[-0.18, 0.4], [-0.02, 0.5], [0.08, 0.66]], 5, 4))
// broken: the top bitten off at one end, ivy over it and onto the top
model("low_wall_ivy_broken",
  tf({ rot: [0, 90, 0] }, extrude(lwProfile(1.3), 0.6, { mat: "plaster", pos: [0, 0, -0.19], jitter: 0.012, seed: 3 }),
    extrude(lwProfile(1.08), 0.4, { mat: "plaster", pos: [0, 0, 0.3], jitter: 0.02, seed: 4 })),
  lwSkirt(51),
  ivyOn([[-0.32, 0], [-0.3, 0.3], [-0.38, 0.6], [-0.3, 0.9], [-0.18, 1.12]], 14, 2),
  ivyOn([[-0.3, 1.0], [-0.05, 1.18], [0.12, 1.05], [0.3, 1.02]], 9, 3))
// the iron mark: a recess in the +z face, a dark bar with cross pieces in it
model("low_wall_mark", lwBody(1.25, 0.98, 5), lwSkirt(61),
  box(0.2, 0.48, 0.02, { mat: "iron", pos: [-0.1, 0.39, 0.232] }),
  box(0.17, 0.44, 0.03, { mat: "plaster", pos: [-0.1, 0.41, 0.24], jitter: 0.003 }),
  box(0.035, 0.34, 0.03, { mat: "iron", pos: [-0.1, 0.46, 0.26] }),
  [0.47, 0.77].map((y) => box(0.1, 0.03, 0.03, { mat: "iron", pos: [-0.1, y, 0.26] })),
  sphere(0.025, { mat: "iron", detail: 1, pos: [-0.1, 0.83, 0.26] }))
// the wedge at the wall's end (223): a fin of plaster tapering to a point
model("low_wall_end",
  extrude([-0.42, 0, 0.42, 0, 0.18, 1.0, 0.05, 1.32, -0.05, 1.3], 0.34, { mat: "plaster", jitter: 0.015, seed: 6 }),
  tf({ pos: [0, 0, 0.2] }, blades(8, [0.8, 0.05], 0.06, 0.14, 71, 2)))
for (const n of ["low_wall", "low_wall_ivy", "low_wall_ivy_broken", "low_wall_mark", "low_wall_end"]) looms(n)
