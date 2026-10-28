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
  ["cobble" + s, { tex: "out/cobble" + s, uv: 0.5, rough: 0.7 }],

  ["staves" + s, { tex: "out/staves" + s, uv: 1.3, rough: 0.7 }],
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
  vine: ["#a8926e", "#7a6250", "#8e7e5c"], vineD: ["#6e5a40", "#4a382c", "#5a4e38"], iron: ["#2e2a26", "#2e2a26", "#2e2a26"],
  // the mortar of the cobble slabs: white (retail), grey, sand
  mortar: ["#e8e6dc", "#b4b8bc", "#d8c8a4"], mortarD: ["#b8b6a6", "#868a90", "#a8987a"],
  // fence logs: weathered tan (retail), grey, dark; moss on their feet
  logL: ["#e2cf9a", "#c4c2bc", "#8a6e50"], log: ["#b49a64", "#8e8c86", "#5e4632"], logD: ["#7a6640", "#5c5a56", "#3a2a1e"],
  moss: ["#94a82e", "#5e8a3a", "#7e8a34"],
  // iron hoops and nails
  hoop: ["#9a9c98", "#8a8e92", "#6e6a64"], hoopD: ["#4a4c4a", "#3e4246", "#34302c"],
  // the green trees: leaves (lime green, the retail 2556 / olive autumn, the
  // retail 2548 / deep summer green) and a pale twisting bark
  treeD: ["#3a5214", "#4a3a12", "#1e3a1a"], tree: ["#6e8a22", "#8a6a1e", "#3a6a2a"], treeL: ["#a8c234", "#c0a03a", "#6a9a3e"],
  treeX: ["#5a7a1a", "#9a4a1a", "#2e5222"],
  barkL: ["#d8c890", "#c8bca0", "#a08a6a"], bark: ["#a89660", "#8e8270", "#6e5a42"], barkD: ["#6e6038", "#5a5246", "#42342a"],
  // cup flowers (481, 482): yellow-orange (retail), white, red; and the small
  // ground flowers (126): pink (retail), lilac, white
  flowerD: ["#c8641a", "#b8b8a8", "#8a1a1a"], flower: ["#f0a020", "#ecece4", "#c8302a"], flowerL: ["#fcd04a", "#ffffff", "#e8604a"],
  flowerC: ["#e07a10", "#e8c030", "#f0c030"],
  // their leaves: a dull olive, not the lime of the grass block
  stalkD: ["#34401a", "#2e3e1e", "#34401a"], stalk: ["#56682a", "#4a6230", "#56682a"], stalkL: ["#74863a", "#668040", "#74863a"],
  pinkD: ["#b83a6a", "#7a4ab0", "#a8b8d0"], pink: ["#e86a9a", "#a874d8", "#dce6f4"], pinkC: ["#fff4e8", "#fff4e8", "#f0d050"],
  // window bars (the dormer): green (retail), dark iron, brown wood
  bar: ["#4e7a2a", "#3a3a3a", "#5a3a22"], hole: ["#141810", "#141414", "#181210"],
  // moss pads and sprouts (1680-1683, 334, 331, 333, 613): soft olive-yellow
  // (retail), deep green, dry straw
  padD: ["#5a681a", "#2a4a22", "#6e5c22"], pad: ["#7e8e22", "#3e6e2e", "#948034"], padL: ["#9cac2c", "#5e923c", "#b4a24e"],
  // engraved slabs (466-468): cream-olive stone (retail), grey, terracotta;
  // the raised greca a shade lighter
  slabD: ["#8a8458", "#6e7074", "#8a4a30"], slab: ["#b8b080", "#9a9c9e", "#b06a48"], slabL: ["#d8d0a2", "#c4c6c6", "#d08e68"],
  // roof tiles: green glazed (retail), terracotta, slate
  roofD: ["#1e4a32", "#7a3218", "#2a3038"], roof: ["#2e6a48", "#a8482a", "#3e4650"], roofL: ["#4a8a64", "#c8643a", "#5a6470"],
}
pal(Object.fromEntries(LOOMS.flatMap((s, i) => Object.entries(PAL).map(([k, v]) => [k + s, v[i]]))))
const SKINNED = ["grass", "grassRim", "grassMid", "soil", "earth", "plaster", "timber", "cobble", "staves", ...Object.keys(PAL)]
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
// mats: [base, tip, light tip] (default the grass block's blades)
function blades(n, area, hMin, hMax, seed, lying = 0, mats = ["bladeD", "blade", "bladeL"]) {
  const out = []
  for (let i = 0; i < n; i++) {
    const r = (k) => ((Math.sin((i + 1) * 12.9898 * k + seed * 78.233) * 43758.5453) % 1 + 1) % 1
    // bunched: three clump centres, blades scattered round them
    const c = [[-0.18, -0.05], [0.12, 0.08], [0.02, -0.18]][i % 3]
    const x = (c[0] + (r(1) - 0.5) * 0.3) * area[0] / 0.6, z = (c[1] + (r(2) - 0.5) * 0.25) * area[1] / 0.45
    const h = hMin + r(3) * (hMax - hMin), down = i < lying
    const lean = down ? 70 + r(4) * 15 : 5 + r(4) * 40, turn = r(5) * 360
    const tip = z > 0.05 ? mats[2] : r(6) > 0.5 ? mats[2] : mats[1]
    out.push(tf({ pos: [x, 0, z], rot: [0, turn, 0] }, tf({ rot: [lean, 0, 0] },
      extrude(bladeBase(h), 0.006, { mat: mats[0] }), extrude(bladeTip(h), 0.006, { mat: tip, pos: [0, 0, 0.001] }))))
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
// ivy, as the retail draws it: a woody trunk out of the ground, thick at
// the foot, branching into thin twigs up the +z face; big leaves low down,
// smaller toward the tips, each standing off the wall at its own angle, two
// tones (a dark leaf under a lighter one, so a dark rim shows)
// a leaf: a broad oval drawn to a point at the tip; stalk at the origin
const vineLeaf = Array.from({ length: 22 }, (_, i) => {
  const t = (i / 22) * Math.PI * 2
  const r = 0.04 * (0.9 + 0.45 * Math.pow(Math.max(0, Math.sin(t)), 12))
  return [Math.cos(t) * r * 0.95, Math.sin(t) * r * 1.15 + 0.045]
}).flat()
const WALL_T = 0.23
// a branch: tube segments tapering from r0 to r1 along 3D points
function vineBranch(pts, r0, r1) {
  const out = [], n = pts.length - 1
  for (let i = 0; i < n; i++) {
    const r = r0 + (r1 - r0) * (i / Math.max(1, n - 1))
    out.push(tube([...pts[i], ...pts[i + 1]], r, { mat: i < 1 && r0 > 0.025 ? "vineD" : "vine", sides: 5 }))
    if (i < n - 1) out.push(sphere(r, { mat: "vine", detail: 0, pos: pts[i + 1] }))
  }
  return out
}
const along = (pts, t) => {
  const f = t * (pts.length - 1), k = Math.min(pts.length - 2, Math.floor(f)), u = f - k
  return pts[k].map((v, j) => v + (pts[k + 1][j] - v) * u)
}
// leaves along a branch, big at its foot (s0) to small at its tip (s1);
// h = the wall's top: leaves above it lie on the top instead of the face
function vineLeaves(pts, n, s0, s1, seed, h = 9) {
  const out = []
  for (let i = 0; i < n; i++) {
    const t = n === 1 ? 1 : 0.08 + 0.92 * (i / (n - 1)), p = along(pts, t), sz = s0 + (s1 - s0) * t
    const side = (i + seed) % 2 ? 1 : -1, tilt = 12 + ((i * 17 + seed * 5) % 18), turn = side * (20 + ((i * 29 + seed) % 50))
    const lit = (i + seed) % 3 ? "ivy" : "ivyL"
    const leaf = [extrude(vineLeaf, 0.005, { mat: "ivyD", scale: sz * 1.06 }),
      extrude(vineLeaf, 0.005, { mat: lit, pos: [0, 0.004 * sz, 0.006], scale: sz * 0.96 })]
    const onTop = p[1] > h - 0.04
    out.push(tf({ pos: p }, tf({ rot: onTop ? [-90 + tilt * 0.5, turn * 2, 0] : [tilt, 0, turn] }, leaf)))
  }
  return out
}
// a whole plant on the +z face: [points, r0, r1, leaves, s0, s1] per branch
const ivyPlant = (branches, seed, h) => branches.map(([pts, r0, r1, n, s0, s1], k) => {
  const P = pts.map(([x, y, z]) => [x, y, z === undefined ? WALL_T + 0.02 : z])
  return [vineBranch(P, r0, r1), vineLeaves(P, n, s0, s1, seed + k * 3, h)]
})
model("low_wall", lwBody(1.2, 0.98, 1), lwSkirt(31))
model("low_wall_ivy", lwBody(1.28, 0.98, 2), lwSkirt(41),
  ivyPlant([
    [[[-0.08, 0, 0.3], [-0.12, 0.12], [-0.18, 0.3], [-0.25, 0.52], [-0.3, 0.74], [-0.28, 0.9]], 0.04, 0.009, 10, 3.0, 1.1],
    [[[-0.14, 0.2], [-0.02, 0.33], [0.06, 0.47], [0.1, 0.62]], 0.02, 0.007, 6, 1.9, 1.0],
    [[[-0.22, 0.42], [-0.36, 0.55], [-0.4, 0.68]], 0.015, 0.006, 4, 1.6, 1.0],
  ], 1))
// broken: the top bitten off at one end, ivy over it and onto the top
model("low_wall_ivy_broken",
  tf({ rot: [0, 90, 0] }, extrude(lwProfile(1.3), 0.6, { mat: "plaster", pos: [0, 0, -0.19], jitter: 0.012, seed: 3 }),
    extrude(lwProfile(1.08), 0.4, { mat: "plaster", pos: [0, 0, 0.3], jitter: 0.02, seed: 4 })),
  lwSkirt(51),
  ivyPlant([
    [[[0.08, 0, 0.3], [0.04, 0.16], [-0.08, 0.38], [-0.2, 0.6], [-0.3, 0.85], [-0.32, 1.06]], 0.042, 0.01, 10, 3.1, 1.2],
    // over the broken top and onto it, a cluster of leaves up there
    [[[-0.31, 1.0], [-0.26, 1.14], [-0.2, 1.26, 0.16], [-0.08, 1.31, 0.04], [0.06, 1.31, -0.06]], 0.016, 0.007, 7, 1.4, 2.4],
    [[[-0.1, 0.45], [-0.32, 0.55], [-0.4, 0.66]], 0.015, 0.006, 4, 1.6, 1.0],
  ], 2),
  // the red cluster spilling over the top's far corner
  vineLeaves([[-0.02, 1.3, 0.04], [0.06, 1.31, -0.04], [0.1, 1.29, -0.12]], 5, 2.4, 2.0, 9))
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

// --- cobble slabs (183, 184: the same slab, two layouts) ---------------------
// a skin of white mortar laid over a block's top, its edge sagging over the
// sides in a few drips, seven rounded paving stones set in it. A cap like
// the grass cap: y = 0 is the block's top.
// a rounded rectangle outline (XY), w × d, corner radius r
const rrect = (w, d, r, seg = 3) => {
  const pts = [], cs = [[1, 1], [-1, 1], [-1, -1], [1, -1]]
  cs.forEach(([sx, sy], c) => {
    for (let i = 0; i <= seg; i++) {
      const a = (c * 90 + (i / seg) * 90) * Math.PI / 180
      pts.push(sx * (w / 2 - r) + Math.cos(a) * r, sy * (d / 2 - r) + Math.sin(a) * r)
    }
  })
  return pts
}
// stones: [x, z, w, d] in the cell
function cobbleSlab(stones, seed) {
  return [
    prismUp(roundSquare(0.5, 0.05), 0.05, -0.01, "mortar", 0.004),
    // the sagging edge: a thin wavy skirt hanging over the sides, a few drips
    prismUp(roundSquare(0.51, 0.06, 6, 0.02, seed), 0.07, -0.07, "mortarD", 0.006),
    [[0.5, -0.2], [0.5, 0.25], [-0.15, 0.5], [0.3, 0.5]].map(([x, z], i) =>
      sphere(0.035, { mat: "mortarD", detail: 1, pos: [x * 1.005, -0.06, z * 1.005], scale: [1, 1.6, 1] })),
    stones.map(([x, z, w0, d0], i) => [w0 * 1.14, d0 * 1.14, x, z]).map(([w, d, x, z], i) => tf({ pos: [x, 0.03, z], rot: [0, ((i * 37 + seed * 11) % 9) - 4, 0] },
      prismUp(rrect(w, d, Math.min(w, d) * 0.4, 4), 0.03, 0, "cobble", 0.004),
      sphere(0.5, { mat: "cobble", detail: 2, pos: [0, 0.028, 0], scale: [w * 0.95, 0.03, d * 0.95] }))),
  ]
}
model("cobble_cap", { pivot: "origin" }, cobbleSlab([
  [-0.22, -0.28, 0.3, 0.2], [0.15, -0.3, 0.32, 0.18], [-0.32, 0.02, 0.22, 0.26], [0.0, 0.0, 0.34, 0.2],
  [0.32, 0.02, 0.2, 0.24], [-0.12, 0.3, 0.4, 0.2], [0.28, 0.3, 0.26, 0.2]], 1))
model("cobble_cap_alt", { pivot: "origin" }, cobbleSlab([
  [-0.3, -0.27, 0.22, 0.22], [0.08, -0.28, 0.42, 0.2], [-0.22, 0.0, 0.38, 0.22], [0.2, 0.02, 0.26, 0.22],
  [-0.3, 0.3, 0.22, 0.2], [0.02, 0.3, 0.24, 0.2], [0.3, 0.29, 0.22, 0.24]], 2))
for (const n of ["cobble_cap", "cobble_cap_alt"]) looms(n)

// --- broken wooden fence (199: a post and its rail, 200: two posts and a
// rail) ---------------------------------------------------------------------
// rustic log posts, cut flat on top with a few splinters round the rim,
// split slats at the foot, moss up the lower half; a crooked log rail. The
// fence runs along z (199 chains: its rail reaches the post of the 199 in
// the next cell, at z - 1).
function post(x, z, h, seed) {
  const r = 0.11
  return [
    lathe([r * 1.08, 0, r, h * 0.5, r * 0.95, h], { mat: "log", sides: 7, pos: [x, 0, z], jitter: 0.006, seed }),
    lathe([r * 1.16, 0, r * 1.08, h * 0.42, 0, h * 0.42], { mat: "moss", sides: 7, pos: [x, 0, z], jitter: 0.008, seed: seed + 1 }),
    cyl(r * 0.88, 0.012, { mat: "logL", sides: 7, pos: [x, h, z] }),
    // moss creeping up in two streaks, and dark splits in the bark
    [[30, 0.62], [75, 0.5]].map(([a, k], i) => tf({ pos: [x, 0, z], rot: [0, a + seed * 9, 0] },
      box(0.035, h * k, 0.01, { mat: "moss", pos: [r * 1.0, 0, 0], rot: [0, 90, 0] }))),
    [10, 55, 100].map((a, i) => tf({ pos: [x, 0, z], rot: [0, a + seed * 17, 0] },
      box(0.008, h * (0.35 + (i % 2) * 0.2), 0.006, { mat: "logD", pos: [r * 1.0, h * 0.45, 0], rot: [0, 90, 0] }))),
    // splinters round the top rim
    [40, 160, 280].map((a, i) => tf({ pos: [x, h, z], rot: [0, a + seed * 13, 0] },
      box(0.025, 0.05 + (i % 2) * 0.03, 0.012, { mat: "logD", pos: [r * 0.85, 0, 0], rot: [0, 0, -8] }))),
    // split slats leaning out at the foot
    [20, 130, 230, 320].map((a, i) => tf({ pos: [x, 0, z], rot: [0, a + seed * 7, 0] },
      box(0.04, 0.12 + (i % 3) * 0.04, 0.02, { mat: i % 2 ? "log" : "logL", pos: [r + 0.02, 0, 0], rot: [0, 0, -14] }))),
  ]
}
const rail = (a, b, seed) => tube([...a, (a[0] + b[0]) / 2 + 0.01, (a[1] + b[1]) / 2 - 0.02, (a[2] + b[2]) / 2, ...b], 0.035,
  { mat: "log", sides: 6, jitter: 0.004, seed })
model("fence", { pivot: "origin" }, post(0, 0.25, 0.62, 1), rail([0, 0.46, 0.2], [0, 0.36, -0.72], 2))
model("fence_pair", { pivot: "origin" }, post(0, 0.32, 0.5, 3), post(0, -0.32, 0.72, 5), rail([0, 0.36, 0.28], [0, 0.48, -0.28], 4))
for (const n of ["fence", "fence_pair"]) looms(n)

// --- barrel (218) and crate (220) ---------------------------------------------
// a big barrel, nearly a cell: bulging painted staves, two iron hoops with
// rivets, thick rims of pale wood top and foot, the lid set in with its
// bung hole
model("barrel",
  lathe([0.36, 0.06, 0.42, 0.3, 0.44, 0.48, 0.42, 0.68, 0.36, 0.9], { mat: "staves", sides: 16, jitter: 0.004 }),
  lathe([0.39, 0, 0.4, 0.1, 0.36, 0.12, 0, 0.12], { mat: "timber", sides: 16 }),
  lathe([0.38, 0.86, 0.39, 0.98, 0.3, 0.98, 0.3, 0.93, 0, 0.93], { mat: "timber", sides: 16 }),
  cyl(0.07, 0.012, { mat: "hoopD", sides: 10, pos: [0.13, 0.93, 0.05] }),
  [[0.3, 0.435], [0.6, 0.43]].map(([y, r]) => [
    lathe([r + 0.012, 0, r + 0.014, 0.075, 0, 0.075], { mat: "hoop", sides: 16, pos: [0, y, 0] }),
    Array.from({ length: 10 }, (_, i) => sphere(0.012, { mat: "hoopD", detail: 0, pos: [Math.cos(i * 0.628) * (r + 0.022), y + 0.037, Math.sin(i * 0.628) * (r + 0.022)] }))]))
// a wooden crate, open at the top: a frame of beams along every edge, plank
// panels set back inside it, nails at the joints, the floor showing inside
const CR = 0.38, CH = 0.6   // half its width, its height
// a panel of vertical boards between the frame beams, set back from it; the
// boards turned so the grain runs up them
const panel = (n, w, h) => Array.from({ length: n }, (_, i) =>
  box(w / n - 0.012, h, 0.025, { mat: i % 2 ? "timber" : "logD", pos: [-w / 2 + (i + 0.5) * (w / n), 0, 0], rot: [0, 0, 0], jitter: 0.002, seed: i }))
const PW = 2 * CR - 0.16, PH = CH - 0.16
model("crate",
  sym("z", tf({ pos: [0, 0.08, CR - 0.05] }, panel(4, PW, PH))),
  sym("x", tf({ pos: [CR - 0.05, 0.08, 0], rot: [0, 90, 0] }, panel(4, PW, PH))),
  box(2 * CR - 0.08, 0.03, 2 * CR - 0.08, { mat: "timber", pos: [0, 0.03, 0] }),
  // frame: four corner posts, the top and foot edges
  sym("x", sym("z", box(0.08, CH, 0.08, { mat: "timber", pos: [CR - 0.04, 0, CR - 0.04], jitter: 0.004 }))),
  [0, CH - 0.08].map((y) => [
    sym("z", box(2 * CR, 0.08, 0.08, { mat: "timber", pos: [0, y, CR - 0.04], jitter: 0.004 })),
    sym("x", box(0.08, 0.08, 2 * CR - 0.16, { mat: "timber", pos: [CR - 0.04, y, 0], jitter: 0.004 }))]),
  // nails at the corners of the two faces the camera sees
  [[CR - 0.04, CH - 0.04], [-(CR - 0.04), CH - 0.04], [CR - 0.04, 0.04], [-(CR - 0.04), 0.04]].map(([x, y]) => [
    sphere(0.014, { mat: "hoopD", detail: 0, pos: [x, y, CR + 0.002] }),
    sphere(0.014, { mat: "hoopD", detail: 0, pos: [CR + 0.002, y, x] })]))
for (const n of ["barrel", "crate"]) looms(n)

// --- green trees (2548, 2550, 2556) --------------------------------------------
// a slender pale trunk with a slight twist, flaring into roots, under an open
// crown of big maple leaves: a dark core in clumps, leaves fanned over it,
// the light ones on top, a few odd-coloured ones mixed in
const mapleLeaf = Array.from({ length: 20 }, (_, i) => {
  const t = (i / 20) * Math.PI * 2, lobe = Math.pow(Math.abs(Math.cos(2.5 * (t - Math.PI / 2))), 1.4)
  const r = 0.1 * (0.55 + 0.45 * lobe) * (1 - 0.4 * Math.max(0, -Math.sin(t)))
  return [Math.cos(t) * r, Math.sin(t) * r + 0.03]
}).flat()
// one clump of the crown: a small dark core, n big leaves fanned out round
// it with gaps between them, the light ones only on top
function clump(x, y, z, r, seed) {
  const out = [sphere(r * 0.5, { mat: "treeD", detail: 1, pos: [x, y, z], jitter: r * 0.1, seed })]
  const n = Math.round(6 + r * 16)
  for (let i = 0; i < n; i++) {
    const t = (i + 0.5) / n, yy = 1 - 1.6 * t, rr = Math.sqrt(Math.max(0, 1 - yy * yy)), a = i * 137.5 + seed * 41
    const nx = Math.cos(a * Math.PI / 180) * rr, nz = Math.sin(a * Math.PI / 180) * rr
    const m = (i * 7 + seed) % 6 === 0 ? "treeX" : yy > 0.45 ? "treeL" : yy > -0.2 ? "tree" : "treeD"
    out.push(tf({ pos: [x + nx * r * 0.95, y + yy * r * 0.7, z + nz * r * 0.95], rot: [0, -a + 90, 0] },
      extrude(mapleLeaf, 0.012, { mat: m, rot: [-(yy * 60) + 25, 0, (i * 53) % 360], scale: 1.4 + ((i * 5 + seed) % 4) * 0.2 })))
  }
  return out
}
// a trunk along points, tapering, with root flares at its foot
function trunk(pts, r0, r1, seed) {
  const out = [], n = pts.length - 1
  for (let i = 0; i < n; i++) {
    const r = r0 + (r1 - r0) * (i / Math.max(1, n - 1))
    out.push(tube([...pts[i], ...pts[i + 1]], r, { mat: i % 2 ? "bark" : "barkL", sides: 7, jitter: 0.006, seed: seed + i }))
    if (i < n - 1) out.push(sphere(r, { mat: "bark", detail: 1, pos: pts[i + 1] }))
  }
  // streaks of dark bark winding up the trunk
  out.push(tube(pts.slice(0, 3).map(([x, y, z], i) => [x + r0 * 0.98 * Math.cos(i * 1.2), y, z + r0 * 0.98 * Math.sin(i * 1.2)]).flat(), r0 * 0.18, { mat: "barkD", sides: 4 }))
  out.push(lathe([r0 * 1.6, 0, r0 * 1.15, 0.08, r0, 0.2], { mat: "bark", sides: 7, jitter: 0.01, seed }))
  out.push(blades(9, [0.35, 0.3], 0.06, 0.14, seed + 30, 2))
  return out
}
const branch = (pts, r) => tube(pts.flat(), r, { mat: "bark", sides: 5 })
// 2548: a tall straight tree, a broad round crown from half its height
model("leaf_tree", { scale: 0.85 },
  trunk([[0, 0, 0], [0.04, 0.55, 0.02], [-0.02, 1.1, 0], [0.02, 1.5, -0.02]], 0.1, 0.05, 1),
  branch([[0.02, 1.2, 0], [0.45, 1.55, 0.1]], 0.035), branch([[0, 1.3, 0], [-0.45, 1.6, -0.05]], 0.035),
  clump(0, 2.0, 0, 0.5, 1), clump(0.55, 1.65, 0.15, 0.45, 2), clump(-0.55, 1.7, 0.05, 0.45, 3),
  clump(0.15, 2.3, -0.1, 0.38, 4), clump(-0.2, 1.45, -0.4, 0.35, 5), clump(0.25, 1.4, 0.45, 0.32, 6),
  clump(-0.4, 2.15, 0.1, 0.3, 7))
// 2550: the trunk splits in a Y half way up, a wide crown over both arms
model("leaf_tree_fork", { scale: 0.85 },
  trunk([[0, 0, 0], [0.02, 0.45, 0], [0, 0.85, 0]], 0.11, 0.09, 2),
  trunk([[0, 0.82, 0], [-0.3, 1.3, 0.05], [-0.48, 1.65, 0]], 0.075, 0.045, 3).slice(0, 3),
  trunk([[0, 0.82, 0], [0.26, 1.25, -0.02], [0.42, 1.6, -0.05]], 0.075, 0.045, 4).slice(0, 3),
  clump(-0.5, 1.9, 0, 0.48, 11), clump(0.48, 1.85, -0.05, 0.48, 12), clump(0, 2.25, 0, 0.42, 13),
  clump(0.8, 1.6, 0.2, 0.3, 14), clump(-0.82, 1.65, 0.2, 0.28, 15), clump(0, 1.7, 0.4, 0.32, 16))
// 2556: a young tree, slim trunk leaning a little, a smaller open crown
model("leaf_tree_young", { scale: 0.85 },
  trunk([[0, 0, 0], [0.05, 0.55, 0], [0.1, 1.1, 0.02], [0.08, 1.45, 0]], 0.07, 0.04, 5),
  branch([[0.08, 1.05, 0], [0.45, 1.3, 0.1], [0.58, 1.45, 0.1]], 0.022), branch([[0.08, 1.15, 0], [-0.3, 1.45, -0.05]], 0.022),
  clump(0.1, 1.8, 0, 0.4, 21), clump(0.6, 1.5, 0.1, 0.3, 22), clump(-0.32, 1.6, -0.05, 0.3, 23), clump(0.15, 2.12, -0.05, 0.26, 24))
for (const n of ["leaf_tree", "leaf_tree_fork", "leaf_tree_young"]) looms(n)

// --- flowers (481: two cup flowers, 482: one) and small ground flowers (126) --
// a petal: a rounded spoon shape, base at the origin, pointing up +y
const petal = [0, 0, 0.022, 0.02, 0.03, 0.05, 0.022, 0.075, 0, 0.082, -0.022, 0.075, -0.03, 0.05, -0.022, 0.02]
// a cup flower on a short stem: big ruffled outer petals, an upright inner
// ring, a dark orange centre
function cupFlower(x, z, h, size, seed, open = 55) {
  const out = [tube([x, 0, z, x + 0.01, h * 0.6, z, x, h, z], 0.008, { mat: "stalkD", sides: 4 })]
  for (let i = 0; i < 7; i++) {
    const a = i * 360 / 7 + seed * 13, m = i % 3 === 0 ? "flowerD" : i % 3 === 1 ? "flower" : "flowerL"
    out.push(tf({ pos: [x, h, z], rot: [0, a, 0] }, extrude(petal, 0.006, { mat: m, rot: [open + (i % 2) * 12, 0, 0], scale: size })))
  }
  for (let i = 0; i < 5; i++)
    out.push(tf({ pos: [x, h + 0.005, z], rot: [0, i * 72 + 36 + seed * 13, 0] }, extrude(petal, 0.006, { mat: "flowerL", rot: [25, 0, 0], scale: size * 0.7 })))
  out.push(sphere(0.02 * size, { mat: "flowerC", detail: 1, pos: [x, h + 0.025 * size, z] }))
  return out
}
const OLIVE = ["stalkD", "stalk", "stalkL"]
model("flowers",
  cupFlower(-0.1, 0.08, 0.09, 2.2, 1), cupFlower(0.16, 0.16, 0.05, 1.5, 2, 60),
  tf({ pos: [0.04, 0, -0.1] }, blades(10, [0.45, 0.3], 0.14, 0.26, 81, 0, OLIVE)))
model("flower_single", cupFlower(-0.04, 0.1, 0.08, 1.8, 3), tf({ pos: [0.04, 0, -0.08] }, blades(8, [0.35, 0.25], 0.14, 0.26, 82, 0, OLIVE)))
// small ground flowers (126): five petals in a shallow cup, a big white
// centre, scattered over the cell, a few smaller ones
const smallFlower = (x, z, size, seed) => [
  [0, 1, 2, 3, 4].map((i) => tf({ pos: [x, 0.012, z], rot: [0, i * 72 + seed * 17, 0] },
    extrude(petal, 0.005, { mat: i % 2 ? "pink" : "pinkD", rot: [62, 0, 0], scale: size }))),
  sphere(0.022 * size, { mat: "pinkC", detail: 1, pos: [x, 0.03 * size, z], scale: [1, 0.6, 1] })]
model("petals",
  [[-0.3, -0.1, 1.6], [-0.12, -0.28, 1.2], [0.05, -0.05, 1.7], [0.27, -0.22, 1.1], [0.33, 0.08, 1.4],
   [-0.22, 0.16, 1.1], [0.0, 0.24, 0.9], [0.2, 0.32, 1.2], [-0.4, 0.32, 0.8], [0.42, 0.34, 0.8]].map(([x, z, k], i) => smallFlower(x, z, k, i)))
for (const n of ["flowers", "flower_single", "petals"]) looms(n)

// --- flying buttress (225) and dormer window (226, 227) ------------------------
// the buttress: a band of plaster stone, square in section, rising straight
// from the ground, then bending in an arc toward the wall it props (-x) and
// ending in a vertical cut flush with that wall. Origin at the cell centre
// on the ground: the cut lands on the cell's -x edge (x = -0.5), where the
// face of a wall in the next cell is. Retail: the cut meets the wall a
// little under the roof beams of a low wall.
// centreline: a straight leg of length L leaning a0 degrees toward the wall,
// then an arc of radius R turning to a1 degrees (nearly level), so the top
// of its end shows as in the retail; the foot is placed so the end lands on
// the wall (x = edge)
const BUTT = { L: 0.8, a0: 15, R: 0.85, a1: 85, w0: 0.23, w1: 0.19, edge: -0.5 }
const bandPts = (() => {
  const { L, a0, R, a1, w0, w1, edge } = BUTT, rad = Math.PI / 180
  const C = []   // [x, y, dirx, diry], foot at x = 0 for now
  const d0 = [-Math.sin(a0 * rad), Math.cos(a0 * rad)]
  for (let i = 0; i <= 4; i++) C.push([d0[0] * L * i / 4, d0[1] * L * i / 4, ...d0])
  const [sx, sy] = C[C.length - 1]
  for (let i = 1; i <= 12; i++) {
    const f = (a0 + (a1 - a0) * i / 12) * rad
    C.push([sx - R * (Math.cos(a0 * rad) - Math.cos(f)), sy + R * (Math.sin(f) - Math.sin(a0 * rad)), -Math.sin(f), Math.cos(f)])
  }
  const shift = edge - C[C.length - 1][0]
  const outer = [], inner = []
  C.forEach(([x, y, dx, dy], i) => {
    const w = w0 + (w1 - w0) * (i / (C.length - 1)), nx = dy, ny = -dx
    outer.push([x + shift + nx * w, Math.max(0, y + ny * w)]); inner.push([x + shift - nx * w, Math.max(0, y - ny * w)])
  })
  // the vertical cut: both end points on x = edge
  outer[outer.length - 1][0] = edge; inner[inner.length - 1][0] = edge
  return [...outer, ...inner.reverse()].flat()
})()
model("buttress", { pivot: "origin" },
  extrude(bandPts, 0.4, { mat: "plaster", jitter: 0.006, seed: 3 }),
  rock(0.07, { mat: "plaster", pos: [0.62, 0.03, 0.14], seed: 4 }), rock(0.045, { mat: "plaster", pos: [0.25, 0.025, 0.22], seed: 5 }),
  tf({ pos: [0.4, 0, 0.2] }, blades(6, [0.3, 0.12], 0.06, 0.13, 91, 2)))
// the dormer: sits on a roof (y = 0 is the roof board, the roof falls toward
// +z): two stone posts and a lintel framing a dark window with a cross of
// bars, a sloping stone cheek down its open side, a pitched cap of stone
model("dormer", { pivot: "origin" },
  box(0.46, 0.44, 0.06, { mat: "hole", pos: [0, 0.02, 0.16] }),
  tf({ pos: [0, 0.24, 0.2], rot: [0, 0, 12] }, box(0.03, 0.42, 0.03, { mat: "bar", pos: [0, -0.21, 0] }), box(0.4, 0.03, 0.03, { mat: "bar" })),
  // posts leaning in a little, a heavy flat lintel across them
  sym("x", box(0.14, 0.52, 0.28, { mat: "plaster", pos: [0.29, 0, 0.1], rot: [0, 0, 6], jitter: 0.01, seed: 1 })),
  box(0.74, 0.16, 0.34, { mat: "plaster", pos: [0, 0.5, 0.1], rot: [-6, 0, 2], jitter: 0.012, seed: 2 }),
  // the cheek: a wedge of stone running back down to the roof on one side
  wedge(0.14, 0.56, 0.55, { mat: "plaster", pos: [-0.3, 0, -0.3], rot: [0, 180, 0], jitter: 0.01, seed: 4 }),
  box(0.56, 0.5, 0.4, { mat: "plaster", pos: [0, 0, -0.12], jitter: 0.008, seed: 5 }))
for (const n of ["buttress", "dormer"]) looms(n)

// --- moss pads (1682, 334; 1681, 1683; 1680) and sprouts (331, 333, 613) -----
// a pad: a low lumpy cushion of moss (a flattened blob and a few smaller
// lumps round its rim, light on top), short blades fringing its edge. They
// grow on stone slabs and along the grass edges.
const PADS = ["padD", "pad", "padL"]
function mossPad(x, z, rx, rz, rot, seed) {
  const out = [tf({ pos: [x, 0, z], rot: [0, rot, 0] },
    sphere(0.5, { mat: "pad", detail: 2, scale: [rx * 2, 0.045, rz * 2], jitter: 0.01, seed }),
    sphere(0.5, { mat: "padL", detail: 2, pos: [-rx * 0.15, 0.012, -rz * 0.1], scale: [rx * 1.5, 0.04, rz * 1.4], jitter: 0.008, seed: seed + 1 }),
    [0, 1, 2, 3, 4].map((i) => {
      const a = (i / 5) * Math.PI * 2 + seed
      return sphere(0.5, { mat: i % 2 ? "padD" : "pad", detail: 1, pos: [Math.cos(a) * rx * 0.75, 0, Math.sin(a) * rz * 0.75],
        scale: [rx * 0.8, 0.035, rz * 0.8], jitter: 0.008, seed: seed + 2 + i })
    }))]
  // the fringe: tiny dark blade tips poking out from under the rim
  const n = Math.round(4 + (rx + rz) * 12)
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2 + seed * 0.7, h = 0.035 + ((i * 7 + seed) % 3) * 0.012
    const px = x + Math.cos(a) * rx * 0.95, pz = z + Math.sin(a) * rz * 0.95
    out.push(tf({ pos: [px, 0.004, pz], rot: [0, -a * 180 / Math.PI + 90, 0] },
      extrude([-0.014, 0, 0.014, 0, 0, h], 0.004, { mat: "padD", rot: [82, 0, 0] })))
  }
  return out
}
model("moss_pads", { scale: 1.3 }, mossPad(-0.2, -0.12, 0.17, 0.12, 20, 1), mossPad(0.18, -0.18, 0.2, 0.11, -10, 2), mossPad(0.02, 0.18, 0.22, 0.13, 5, 3))
model("moss_patch", { scale: 1.3 }, mossPad(-0.18, -0.15, 0.24, 0.12, 35, 4), mossPad(0.12, 0.12, 0.28, 0.13, 35, 5), mossPad(0.3, -0.2, 0.12, 0.07, 35, 6))
model("moss_tall", { scale: 1.2 }, mossPad(0.02, 0.06, 0.32, 0.17, 10, 7), tf({ pos: [0.08, 0.02, -0.06] }, blades(16, [0.45, 0.18], 0.12, 0.22, 101, 0, PADS)))
// sprouts: clusters of broad curved blades, dark at the foot and light at
// the tip, spread over most of the cell
model("sprouts", [[-0.24, -0.1], [0.14, -0.2], [0.0, 0.16], [0.3, 0.12], [-0.3, 0.22]].map(([x, z], i) =>
  tf({ pos: [x, 0, z], scale: 1.3 }, blades(7, [0.22, 0.16], 0.1, 0.2, 111 + i * 7, 1, PADS))))
for (const n of ["moss_pads", "moss_patch", "moss_tall", "sprouts"]) looms(n)

// --- engraved slabs (466 the knot at the centre, 467/468 the arms round it;
// 468 is 467 mirrored) -------------------------------------------------------
// a low stone slab, chipped at the rim, and a greca standing proud of it:
// square spirals drawn as raised bands. The knot's four spirals each run a
// tail out to the middle of one edge; an arm's band runs to the middle of
// its -x edge, so set round the knot the bands join up across cells.
const SLAB_T = 0.045, BAND = 0.038, RELIEF = 0.018
// a raised band from (x0, z0) to (x1, z1), axis-aligned
const band = (x0, z0, x1, z1) => box(Math.abs(x1 - x0) + BAND, RELIEF, Math.abs(z1 - z0) + BAND,
  { mat: "slabL", pos: [(x0 + x1) / 2, SLAB_T, (z0 + z1) / 2] })
// a square spiral from its centre outward: legs of 1, 1, 2, 2, 3, 3... steps,
// turning one way (sgn); returns its points
function spiralPts(cx, cz, step, legs, sgn, a0 = 0) {
  const dirs = [[1, 0], [0, 1], [-1, 0], [0, -1]].map(([x, z]) => [x, z * sgn])
  const pts = [[cx, cz]]
  let [x, z] = [cx, cz]
  for (let i = 0; i < legs; i++) {
    const [dx, dz] = dirs[(i + a0) % 4], l = Math.ceil((i + 1) / 2) * step
    x += dx * l; z += dz * l; pts.push([x, z])
  }
  return pts
}
const bandsOf = (pts) => pts.slice(1).map((p, i) => band(pts[i][0], pts[i][1], p[0], p[1]))
const slabBase = (seed) => [
  // the body reaches 12 cm below its face, to bury a grass block's dome
  prismUp(roundSquare(0.49, 0.05, 6, 0.012, seed), SLAB_T + 0.12, -0.12, "slab", 0.006),
  // chips knocked out of the rim
  [[0.46, 0.2], [-0.3, 0.47], [-0.47, -0.25], [0.15, -0.47]].map(([x, z], i) =>
    rock(0.035, { mat: "slabD", pos: [x, SLAB_T - 0.01, z], scale: [1.2, 0.5, 1.2], seed: seed + i })),
]
// a spiral's tail: from its last point straight to the nearer axis
const tailTo = ([ex, ez]) => (Math.abs(ex) < Math.abs(ez) ? band(ex, ez, 0, ez) : band(ex, ez, ex, 0))
// the knot: a cross of bands edge to edge through the centre, a spiral in
// each quadrant hooked onto it, a stud where the bands cross
model("slab_knot", { pivot: "origin" }, slabBase(1),
  band(-0.47, 0, 0.47, 0), band(0, -0.47, 0, 0.47),
  // one quadrant's spiral, turned four times: a pinwheel, every spiral hooked
  [0, 90, 180, 270].map((r) => tf({ rot: [0, r, 0] }, (() => {
    const pts = spiralPts(0.24, 0.24, 0.07, 5, 1, 2)
    return [bandsOf(pts), tailTo(pts[pts.length - 1])]
  })())),
  box(0.08, RELIEF + 0.006, 0.08, { mat: "slabL", pos: [0, SLAB_T, 0] }))
// an arm: one spiral hooked onto a band running to the middle of the -x
// edge (where the knot's cross begins), three short parallel stripes in the
// far corner, a stud
model("slab_arm", { pivot: "origin" }, slabBase(5),
  (() => {
    const pts = spiralPts(0.14, 0.04, 0.085, 6, 1, 0)
    return [bandsOf(pts), tailTo(pts[pts.length - 1]), band(-0.47, 0, 0.1, 0)]
  })(),
  [0, 1, 2].map((i) => band(-0.36 + i * 0.075, -0.42, -0.36 + i * 0.075, -0.3)),
  box(0.06, RELIEF, 0.06, { mat: "slabL", pos: [0.36, SLAB_T, 0.36] }))
for (const n of ["slab_knot", "slab_arm"]) looms(n)

// --- broken paving (15) and stone strips (16) --------------------------------
// both lie flat on a cell, in the engraved slabs' stone, sprouts coming up
// between the pieces
// a flat worn fragment: a rounded rectangle, a little tilted, a lighter
// worn face on top
const frag2 = (x, z, w, d, rot, seed) => tf({ pos: [x, 0, z], rot: [((seed * 7) % 5) - 2, rot, ((seed * 11) % 5) - 2] },
  prismUp(rrect(w, d, Math.min(w, d) * 0.3, 3), 0.03, 0, "slabD", 0.004),
  // the worn face, only where the fragment is wide enough to carry one
  Math.min(w, d) > 0.08 ? prismUp(rrect(w - 0.04, d - 0.04, (Math.min(w, d) - 0.04) * 0.3, 3), 0.008, 0.026, "slab", 0.002) : null)
const sproutAt = (x, z, seed) => tf({ pos: [x, 0, z] }, blades(4, [0.08, 0.06], 0.1, 0.17, seed, 0, PADS))
model("paving_broken", { scale: [1.12, 1, 1.12] },
  frag2(-0.2, -0.24, 0.24, 0.16, 8, 1), frag2(0.12, -0.28, 0.18, 0.14, -12, 2), frag2(0.3, -0.05, 0.3, 0.18, 5, 3),
  frag2(-0.05, 0.02, 0.2, 0.15, -4, 4), frag2(-0.3, 0.12, 0.18, 0.2, 14, 5), frag2(0.06, 0.28, 0.32, 0.18, -6, 6),
  frag2(0.34, 0.26, 0.14, 0.12, 20, 7),
  // thin strips along the far edges, what is left of the kerb
  frag2(-0.38, -0.42, 0.3, 0.05, 6, 8), frag2(0.2, -0.45, 0.36, 0.05, -3, 9),
  sproutAt(-0.12, -0.12, 121), sproutAt(0.2, 0.1, 122), sproutAt(-0.25, 0.32, 123), sproutAt(0.32, -0.3, 124))
// three long strips bowed a little in plan, laid side by side, each one
// piece: an arc-shaped outline, rounded at the ends, a worn face on top
function stripOutline(len, w, bow) {
  const C = Array.from({ length: 9 }, (_, i) => { const t = i / 8 - 0.5; return [t * len, bow * (1 - 4 * t * t), -8 * bow * t] })
  const side = (k) => C.map(([x, z, dz]) => { const l = Math.hypot(1, dz); return [x - k * dz / l * w / 2, z + k / l * w / 2] })
  return [...side(1), ...side(-1).reverse()].flat()
}
const strip = (z, len, w, bow, seed) => tf({ pos: [0, 0, z] },
  prismUp(stripOutline(len, w, bow), 0.032, 0, "slabD", 0.004),
  prismUp(stripOutline(len - 0.05, w - 0.045, bow), 0.008, 0.028, "slab", 0.002))
model("stone_strips",
  strip(-0.26, 0.86, 0.22, 0.03, 1), strip(0.0, 0.92, 0.23, 0.035, 2), strip(0.26, 0.82, 0.22, 0.03, 3),
  frag2(0.05, -0.43, 0.5, 0.05, 4, 4),
  sproutAt(-0.22, -0.12, 131), sproutAt(0.12, 0.12, 132), sproutAt(0.3, -0.12, 133))
for (const n of ["paving_broken", "stone_strips"]) looms(n)

// --- chimney (228) and wall window (210) ---------------------------------------
// chimney: stands on a roof (y = 0 is the roof board): a pale stone shaft,
// a band of timber, a square stone cap with its flue hole
model("chimney", { pivot: "origin" },
  prismUp(roundSquare(0.12, 0.03), 0.34, 0, "plaster", 0.008),
  prismUp(roundSquare(0.15, 0.02), 0.12, 0.33, "timber", 0.004),
  // the cap: four walls round the flue, the dark flue inside
  sym("x", box(0.09, 0.2, 0.38, { mat: "plaster", pos: [0.145, 0.45, 0], jitter: 0.005, seed: 1 })),
  sym("z", box(0.2, 0.2, 0.09, { mat: "plaster", pos: [0, 0.45, 0.145], jitter: 0.005, seed: 2 })),
  box(0.2, 0.02, 0.2, { mat: "hole", pos: [0, 0.6, 0] }))
// canal block: a dark stone set in the water channel, its top two long
// slabs split by a groove and bevelled at the front, a dark plinth under
// them, two iron cleats with rivets on the back slab
// wall window: hangs on a wall face (z = 0 is the face, +z out): a frame of
// pale planks, a dark opening with a plant behind two bars
model("wall_window", { pivot: "origin", scale: 1.25 },
  box(0.34, 0.36, 0.02, { mat: "hole", pos: [0, -0.46, 0.005] }),
  tf({ pos: [0.02, -0.46, 0.02] }, blades(7, [0.18, 0.02], 0.18, 0.32, 141, 0, PADS)),
  sym("x", box(0.09, 0.5, 0.06, { mat: "logL", pos: [0.215, -0.52, 0.03], jitter: 0.004 })),
  box(0.52, 0.09, 0.07, { mat: "logL", pos: [0, -0.11, 0.035], jitter: 0.004, seed: 2 }),
  box(0.54, 0.08, 0.09, { mat: "log", pos: [0, -0.56, 0.04], jitter: 0.004, seed: 3 }))
for (const n of ["chimney", "wall_window"]) looms(n)
