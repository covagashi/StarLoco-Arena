// Arena 1 (snow biome) — the whole decoration kit, in kiln, each piece in
// three looms: <name> (a), <name>_b, <name>_c (textures in block.tx.js and
// kit.tx.js). The map editor places these; nothing here is laid out.
// Retail gfx each piece stands in for, in brackets.
include("tree.kx.js")

const SFX = { b: "_b", c: "_c" }
pal(Object.fromEntries(["", "_b", "_c"].flatMap((s) => [
  ["ice" + s, { tex: "out/ice_body" + s, uv: 0.75, rough: 0.25 }],
  ["snow" + s, { tex: "out/snow_soft" + s, uv: 0.9, rough: 0.9 }],
  ["iceClear" + s, { tex: "out/ice_clear" + s, uv: 0.86, rough: 0.15 }],
  ["iceClearTop" + s, { tex: "out/ice_clear_top" + s, uv: 0.9, rough: 0.12 }],
  ["iceCol" + s, { tex: "out/ice_col" + s, uv: 1, rough: 0.25 }],
  ["iceClearCol" + s, { tex: "out/ice_clear_col" + s, uv: 1, rough: 0.15 }],
  ["wood" + s, { tex: "out/wood" + s, uv: 0.6, rough: 0.8 }],
  ["slab" + s, { tex: "out/slab" + s, uv: 1, rough: 0.5 }],
  ["rune" + s, { tex: "out/rune" + s, uv: 1, rough: 0.6 }],
  ["leaf" + s, { tex: "out/leaf" + s, uv: 0.5, rough: 0.55 }],
  ["pebble" + s, { tex: "out/pebble" + s, uv: 0.4, rough: 0.85 }],
  ["stone" + s, { tex: "out/stone" + s, uv: 0.9, rough: 0.85 }],
  ["boulder" + s, { tex: "out/boulder" + s, uv: 0.7, rough: 0.85 }],
  ["softBoulder" + s, { tex: "out/boulder" + s, uv: 1.3, rough: 0.85 }],
  ["softStone" + s, { tex: "out/boulder" + (s === "_c" ? "_c" : "_b"), uv: 1.4, rough: 0.85, color: s === "" ? "#f0e4a8" : "#ffffff" }],
  ["moss" + s, { tex: "out/moss" + s, uv: 1, rough: 0.7 }],
  ["stem" + s, { tex: "out/stem" + s, uv: 0.4, rough: 0.8 }],
])))
// dead tree bark (150): the tree's painted bark, tinted per loom
pal({
  deadBark: { tex: "out/bark_paint", uv: 0.45, color: "#d8d0b0", rough: 0.9 },
  deadBark_b: { tex: "out/bark_paint", uv: 0.45, color: "#a8a8a4", rough: 0.9 },
  deadBark_c: { tex: "out/bark_paint", uv: 0.45, color: "#7a6450", rough: 0.9 },
  deadBarkD: { tex: "out/bark_paint", uv: 0.45, color: "#8a7e60", rough: 0.9 },
  deadBarkD_b: { tex: "out/bark_paint", uv: 0.45, color: "#646462", rough: 0.9 },
  deadBarkD_c: { tex: "out/bark_paint", uv: 0.45, color: "#46362a", rough: 0.9 },
  // metal grate (513): plate, rim and the dark under the holes
  grate: { color: "#9a9a96", rough: 0.45, metal: 0.6 }, grate_b: { color: "#8a6a4a", rough: 0.6, metal: 0.4 },
  grate_c: { color: "#a88a4a", rough: 0.4, metal: 0.6 },
  grateRim: { color: "#8a4a26", rough: 0.75, metal: 0.3 }, grateRim_b: { color: "#5a3a26", rough: 0.8, metal: 0.3 },
  grateRim_c: { color: "#6a5030", rough: 0.6, metal: 0.4 },
  pit: { color: "#141210", rough: 1 },
  rope: { color: "#b4a870", rough: 0.95 }, ropeD: { color: "#8a8050", rough: 0.95 },
})
pal({
  iron: { color: "#1e1c1a", rough: 0.6, metal: 0.4 },
  ironL: { color: "#b4b4b0", rough: 0.5, metal: 0.5 },
  // ice shards: white with grey facets as the retail paints them (a), pale
  // blue (b), lilac (c); flat shading picks out the facets
  shard: { color: "#eef2f6", rough: 0.3 }, shard_b: { color: "#c4e4f4", rough: 0.25 }, shard_c: { color: "#e0d0f0", rough: 0.25 },
  shardD: { color: "#aab2be", rough: 0.3 }, shardD_b: { color: "#86b4d0", rough: 0.25 }, shardD_c: { color: "#a898c4", rough: 0.25 },
  // the snowy rocks: grey-brown boulders (a), cold grey (b), dark (c)
  softRock: { tex: "out/boulder_b", uv: 1.2, rough: 0.85, color: "#e8d8b8" }, softRock_b: { tex: "out/boulder_b", uv: 1.2, rough: 0.85 },
  softRock_c: { tex: "out/boulder_c", uv: 1.2, rough: 0.85 },
  // the lantern's stone lamp and the rune's slate plate
  lampWood: { color: "#4a3420", rough: 0.85 }, lampWood_b: { color: "#4a4844", rough: 0.85 }, lampWood_c: { color: "#2a1e16", rough: 0.85 },
  lampWoodL: { color: "#6a4a2a", rough: 0.85 }, lampWoodL_b: { color: "#64605a", rough: 0.85 }, lampWoodL_c: { color: "#3e2c20", rough: 0.85 },
  lampStone: { color: "#b8ac80", rough: 0.8 }, lampStone_b: { color: "#a4a8ac", rough: 0.8 }, lampStone_c: { color: "#8a7a6a", rough: 0.8 },
  slate: { color: "#2e3438", rough: 0.7 }, slate_b: { color: "#3a3430", rough: 0.7 }, slate_c: { color: "#2a2e3a", rough: 0.7 },
  slateD: { color: "#16191c", rough: 0.8 }, slateD_b: { color: "#1e1a16", rough: 0.8 }, slateD_c: { color: "#14161e", rough: 0.8 },
  // the bridge and fence timber, smooth as the retail paints it: weathered
  // grey (a), brown (b), tarred (c)
  plank: { color: "#66625a", rough: 0.85 }, plank_b: { color: "#8a5a32", rough: 0.85 }, plank_c: { color: "#4a3a2e", rough: 0.85 },
  plankL: { color: "#76716a", rough: 0.85 }, plankL_b: { color: "#a06c3e", rough: 0.85 }, plankL_c: { color: "#5a483a", rough: 0.85 },
  plankD: { color: "#2c2a26", rough: 0.9 }, plankD_b: { color: "#4a2e1a", rough: 0.9 }, plankD_c: { color: "#221a14", rough: 0.9 },
  glow: { color: "#ffd98a", emit: "#ffc65a", glow: 3 },
  glow_b: { color: "#bfe4ff", emit: "#8fd0ff", glow: 3 },
  glow_c: { color: "#ffb3a6", emit: "#ff7a5c", glow: 3 },
})
// the b and c looms of a piece: the same model, every skinned material swapped
const SKINNED = ["ice", "snow", "iceClear", "iceClearTop", "iceCol", "iceClearCol", "wood", "slab", "rune", "leaf", "pebble", "glow",
  "stone", "boulder", "softBoulder", "softStone", "plank", "plankL", "plankD", "shard", "shardD", "softRock", "lampStone", "lampWood", "lampWoodL", "slate", "slateD", "moss", "stem", "deadBark", "deadBarkD", "grate", "grateRim"]
function looms(name) {
  for (const s of Object.values(SFX))
    model(name + s, { base: name, swap: Object.fromEntries(SKINNED.map((m) => [m, m + s])) })
}

// --- blocks (153, 154 + 155/156) and columns: from block.kx.js -------------
for (const n of ["ice_block", "ice_clear", "ice_col", "ice_clear_col"]) looms(n)
// the tree (175): its snow takes the loom; the bark stays
for (const s of Object.values(SFX)) model("tree" + s, { base: "tree", swap: { snowT: "snow" + s } })

// --- wooden bridge (167): three thick weathered boards side by side, a
// cell long, their ends bevelled round, dark grooves between them ---------
const DECK = 0.22
// a board along x, w wide at z, its two ends bevelled; profile in XY
const board = (z, w, h, seed, len = 1.0) => extrude([-len / 2, 0, len / 2, 0, len / 2, h * 0.4, len / 2 - 0.06, h * 0.82, len / 2 - 0.15, h,
  -len / 2 + 0.15, h, -len / 2 + 0.06, h * 0.82, -len / 2, h * 0.4], w, { mat: seed % 2 ? "plank" : "plankL", pos: [0, 0, z], jitter: 0.005, seed })
const deck = () => tf({ rot: [0, 90, 0] },
  box(0.96, DECK - 0.04, 0.9, { mat: "plankD" }),
  board(-0.33, 0.31, DECK, 1), board(0.0, 0.32, DECK - 0.015, 2), board(0.33, 0.31, DECK, 3),
  box(0.6, 0.008, 0.012, { mat: "plankD", pos: [0.05, DECK - 0.014, 0.03] }))   // a split
model("bridge", deck())
looms("bridge")

// --- frost (170) and small frost (174): a line of frost along one axis of
// the cell: a low drift of snow and, out of it, a crowd of sharp shards
// pointing every way, the longest 0.45 m --------------------------------------
// ridge: lumps along x; shards: [x, length, lean (deg, along the line), side]
const drift = (len, lumps, peaks) => [
  lumps.map(([x, r, h], i) => sphere(r, { mat: "snow", detail: 2, pos: [x * len, 0, ((i * 5) % 3 - 1) * 0.015], scale: [1.5, h, 0.8] })),
  peaks.map(([x, h, lean, side], i) => tf({ pos: [x * len, 0.02, side * 0.05], rot: [side * 28, (i * 47) % 90, -lean] },
    cone(0.025 + h * 0.08, h, { mat: i % 3 ? "shard" : "shardD", sides: 3, jitter: 0.004 }))),
]
model("frost", drift(0.9,
  [[-0.4, 0.08, 0.6], [-0.2, 0.1, 0.7], [0.0, 0.09, 0.6], [0.2, 0.08, 0.6], [0.4, 0.06, 0.5]],
  [[-0.48, 0.18, 55, 0], [-0.4, 0.3, 30, 1], [-0.32, 0.22, -20, -1], [-0.22, 0.42, 15, 0], [-0.14, 0.26, 50, 1], [-0.06, 0.34, -35, -1],
   [0.02, 0.45, 5, 0], [0.1, 0.3, 40, 1], [0.18, 0.24, -45, -1], [0.26, 0.36, 20, 0], [0.34, 0.2, 60, 1], [0.42, 0.26, -25, -1], [0.5, 0.14, 50, 0]]))
model("frost_small", drift(0.62,
  [[-0.35, 0.07, 0.6], [-0.1, 0.08, 0.7], [0.15, 0.07, 0.6], [0.36, 0.05, 0.5]],
  [[-0.45, 0.16, 45, 0], [-0.32, 0.28, 20, 1], [-0.2, 0.2, -30, -1], [-0.06, 0.34, 10, 0], [0.08, 0.22, 45, 1], [0.2, 0.28, -20, -1],
   [0.34, 0.18, 35, 0], [0.46, 0.12, -50, 1]]))
looms("frost"); looms("frost_small")
// the same drift in grass (138, 139, 140, 141): the owner's "lo mismo que la
// escarcha", green; palette greens, three looms
pal({ grassD: "#24361e", grassD_b: "#2e4a22", grassD_c: "#5a4a22",
  grass: "#3e5a2e", grass_b: "#5a7a34", grass_c: "#8a7a3a" })
for (const n of ["frost", "frost_small"]) {
  model(n.replace("frost", "grass_drift"), { base: n, swap: { snow: "grassD", shard: "grass", shardD: "grassD" } })
  model(n.replace("frost", "grass_drift") + "_b", { base: n, swap: { snow: "grassD_b", shard: "grass_b", shardD: "grassD_b" } })
  model(n.replace("frost", "grass_drift") + "_c", { base: n, swap: { snow: "grassD_c", shard: "grass_c", shardD: "grassD_c" } })
}

// --- snowy leaves (176): broad leaves fanned out of a snow drift -----------
const leafShape = (w, h) => [0, 0, w * 0.55, h * 0.22, w * 0.5, h * 0.6, w * 0.22, h * 0.88, 0, h,
  -w * 0.22, h * 0.88, -w * 0.5, h * 0.6, -w * 0.55, h * 0.22]
const leaf = (w, h, turn, lean) => tf({ rot: [0, turn, 0] }, tf({ rot: [-lean, 0, 0] },
  extrude(leafShape(w, h), 0.025, { mat: "leaf", jitter: 0.004 }),
  // snow lying on the leaf, near the tip
  sphere(w * 0.24, { mat: "snow", detail: 2, pos: [0, h * 0.74, 0.025], scale: [1.1, 0.7, 0.45] })))
model("leaves", { scale: 1.6 },
  sphere(0.08, { mat: "snow", detail: 2, scale: [1.3, 0.5, 1.2] }),
  // broad leaves fanned low round the middle, two short ones standing up
  leaf(0.3, 0.42, 0, 58), leaf(0.28, 0.4, 72, 62), leaf(0.3, 0.44, 144, 55), leaf(0.27, 0.38, 216, 64),
  leaf(0.29, 0.41, 288, 60), leaf(0.18, 0.3, 36, 22), leaf(0.17, 0.28, 200, 26))
looms("leaves")

// --- ice spike (157) and double spike (159): great shards of ice 2.2 m
// tall, white with grey facets, smaller shards round their feet, a ragged
// heap of snow ----------------------------------------------------------------
// a shard at (x, z), r at the foot, h tall, leaning `lean` towards yaw
const shardAt = (x, z, r, h, lean, yaw, seed, mat = "shard") => tf({ pos: [x, -0.02, z], rot: [0, yaw, 0] }, tf({ rot: [0, 0, -lean] },
  lathe([r, 0, r * 0.82, h * 0.45, r * 0.4, h * 0.82, 0, h], { mat, sides: 4, rot: [0, 45 + seed * 17, 0], jitter: r * 0.12, seed })))
const snowHeap = (r, seed) => [0, 1, 2, 3, 4].map((i) => {
  const a = i * 1.3 + seed, d = i ? r * 0.55 : 0
  return sphere(r * (i ? 0.55 : 0.8), { mat: "snow", detail: 2, pos: [Math.cos(a) * d, 0, Math.sin(a) * d], scale: [1.3, 0.42, 1.2] })
})
model("spike",
  shardAt(0, 0, 0.3, 2.2, 3, 0, 1), shardAt(0.05, 0.02, 0.2, 1.75, -4, 40, 2, "shardD"),
  shardAt(0.22, 0.08, 0.16, 0.95, 22, 20, 3), shardAt(-0.2, -0.05, 0.13, 0.7, 26, 200, 4, "shardD"), shardAt(0.05, 0.25, 0.1, 0.45, 30, 100, 5),
  snowHeap(0.42, 1))
model("spike_double",
  shardAt(-0.1, 0, 0.22, 2.2, 4, 180, 11), shardAt(-0.06, 0.04, 0.15, 1.6, 2, 40, 12, "shardD"),
  shardAt(0.12, 0.02, 0.17, 1.9, 24, 0, 13), shardAt(0.05, -0.18, 0.1, 0.6, 30, 260, 14, "shardD"), shardAt(0.1, 0.22, 0.09, 0.4, 26, 120, 15),
  snowHeap(0.4, 2))
looms("spike"); looms("spike_double")

// --- slab with a baybayin glyph (470, 496, 497): lies on a block top --------
model("slab", prism(roundSquare(0.47, 0.05), 0.05, 0, "slab", 0.003))
looms("slab")

// --- floor rune (507, 508, 509, 510): an eight-sided slate plate a metre
// across with a dark rim, the glowing glyph disc set in it -----------------
const octagon = (r) => Array.from({ length: 8 }, (_, i) => { const a = (i + 0.5) / 8 * Math.PI * 2; return [Math.cos(a) * r, Math.sin(a) * r] }).flat()
model("rune",
  prism(octagon(0.52), 0.04, 0, "slateD", 0.003), prism(octagon(0.46), 0.03, 0.03, "slate", 0.002),
  cyl(0.38, 0.03, { mat: "rune", sides: 28, pos: [0, 0.035, 0] }))
looms("rune")

// --- lantern post (1675; 1676 is its mirror, the editor flips it): a
// tower of four timber legs leaning in to a stone lamp 2.3 m up, braced
// twice, a riveted plank shield on one side at its foot ------------------
const LEG = (sx, sz) => tube([sx * 0.3, 0, sz * 0.3, sx * 0.13, 1.72, sz * 0.13], 0.045, { mat: "lampWood", sides: 4 })
const brace = (y, half) => [0, 90, 180, 270].map((a) => tf({ rot: [0, a, 0] }, box(2 * half, 0.06, 0.05, { mat: "lampWood", pos: [0, y, half] })))
model("lantern",
  LEG(1, 1), LEG(1, -1), LEG(-1, 1), LEG(-1, -1),
  brace(0.55, 0.28), brace(1.35, 0.2),
  // the stone lamp: a block widening to a hollow bowl, the light inside
  box(0.32, 0.12, 0.32, { mat: "lampStone", pos: [0, 1.7, 0] }),
  lathe([0.17, 0, 0.2, 0.1, 0.28, 0.22, 0.27, 0.27], { mat: "lampStone", sides: 4, rot: [0, 45, 0], pos: [0, 1.82, 0] }),
  box(0.3, 0.02, 0.3, { mat: "glow", pos: [0, 2.04, 0] }),
  // the plank shield on +x, bolted
  box(0.06, 0.95, 0.46, { mat: "lampWoodL", pos: [0.36, 0, 0.0], jitter: 0.006 }),
  [0.18, 0.78].map((y) => box(0.07, 0.06, 0.48, { mat: "lampWood", pos: [0.365, y, 0] })),
  [[0.3, -0.12], [0.3, 0.12], [0.65, -0.12], [0.65, 0.12]].map(([y, z]) => cyl(0.035, 0.03, { mat: "iron", sides: 8, pos: [0.39, y, z], rot: [0, 0, 90] })),
  light({ type: "point", color: "#ffc65a", power: 6, pos: [0, 2.15, 0.3] }))
looms("lantern")

// --- snow mound (505), loose snow (503, 504), pebbles (161, 163) -----------
// mound (505): a long low drift 1.4 m across and 0.4 m high, its crest soft,
// spreading thin at its edges; a small lump in front
model("mound", { scale: 0.62 },
  [[-0.45, 0.22, 0.32], [-0.15, 0.3, 0.42], [0.15, 0.32, 0.4], [0.45, 0.24, 0.3], [0.62, 0.15, 0.2]].map(([u, r, h], i) =>
    sphere(r, { mat: "snow", detail: 3, pos: [(u) * 0.7071, 0, -u * 0.7071], scale: [1.4, h / r * 0.7, 1.0] })),
  sphere(0.6, { mat: "snow", detail: 2, scale: [1.5, 0.08, 1.0] }),
  sphere(0.09, { mat: "snow", detail: 2, pos: [0.3, 0, 0.42], scale: [1.4, 0.6, 1.2] }))
// loose snow (503, 504): a few small lumps, well apart over the cell
model("loose_snow",
  [[-0.24, -0.06, 0.09], [0.28, 0.04, 0.075], [0.02, 0.3, 0.06], [-0.04, -0.32, 0.05]].map(([x, z, r], i) => [
    sphere(r, { mat: "snow", detail: 2, pos: [x, 0, z], scale: [1.3, 0.55, 1.2] }),
    sphere(r * 0.45, { mat: "snow", detail: 1, pos: [x + r * 1.4, 0, z + r * (i % 2 ? 0.8 : -0.9)], scale: [1.2, 0.5, 1.1] })]))
// pebbles (161, 162, 163): flat stones scattered over the cell, each with a
// little cap of snow
model("pebbles",
  [[0, 0, 0.12, 2], [0.27, 0.1, 0.095, 5], [-0.25, 0.14, 0.09, 8], [0.05, -0.27, 0.08, 11], [-0.08, 0.33, 0.07, 14],
   [0.34, -0.2, 0.065, 17], [-0.32, -0.18, 0.07, 20], [0.2, 0.33, 0.055, 23]].map(([x, z, r, sd]) => [
    rock(r, { mat: "pebble", seed: sd, pos: [x, r * 0.35, z], scale: [1.3, 0.6, 1.1] }),
    sphere(r * 0.62, { mat: "snow", detail: 2, pos: [x, r * 0.7, z], scale: [1.3, 0.38, 1.2] })]))
looms("mound"); looms("loose_snow"); looms("pebbles")

// --- more ground: from arenas 12, 15 and 72 ----------------------------------
// cut stone block (77, 78, 79, 109): a big rounded cube of cracked
// sandstone, every edge worn round (soft normals), its top domed a little
const softTop = (half, r, h, y, dome, mat) => terrain(2 * (half - 0.293 * r - 0.01), 2 * (half - 0.293 * r - 0.01), { res: 24, height: dome, mat, pos: [0, y - 0.004, 0],
  fn: (x, z) => { const e = (half - 0.293 * r - 0.01) - Math.max(Math.abs(x), Math.abs(z)); const t = Math.min(1, e / 0.12); return t * t * (3 - 2 * t) } })
model("stone_block",
  prism(roundSquare(0.49, 0.17, 6, 0.006, 5), 0.8, 0, "softStone", 0.006),
  softTop(0.49, 0.17, 0.04, 0.8, 0.07, "softStone"))
// rough stone block (104, 105): a cell heaped with big rounded sandstone
// chunks, broad ones on top, others bulging out of the sides
const chunk = (x, y, z, w, h, d, ry, seed) => tf({ pos: [x, y, z], rot: [0, ry, 0] },
  sphere(0.5, { mat: "softBoulder", detail: 1, scale: [w, h, d], jitter: 0.012, seed }))
model("rock_block",
  swell([[0, 0.44, 0.1], [0.5, 0.47, 0.12], [0.68, 0.42, 0.12]], "softBoulder", 0.03, 9),
  chunk(-0.15, 0.7, -0.15, 0.72, 0.32, 0.7, 10, 1), chunk(0.22, 0.72, -0.05, 0.56, 0.34, 0.72, -15, 2),
  chunk(-0.1, 0.68, 0.26, 0.7, 0.3, 0.48, 20, 3),
  chunk(0.42, 0.4, 0.08, 0.28, 0.62, 0.72, 0, 5), chunk(0.05, 0.38, 0.42, 0.75, 0.6, 0.28, 0, 6))
// tall ice pillar (152): two cells high, the hero block's snow cap on top
model("ice_pillar",
  prism(roundSquare(HALF, 0.07), 1.7, 0, "iceCol", 0.004),
  terrain(2 * CAP, 2 * CAP, { res: 48, height: 0.3, fn: cushion, mat: "snow", pos: [0, 1.7 - 0.12, 0] }),
  tf({ pos: [0, 0.95, 0] }, drips))
// moss floor (623): a thin flagstone at floor level
model("moss_floor", prism(roundSquare(0.49, 0.03), 0.12, 0, "moss", 0.004))
// bridge end (168): the boards with two iron cleats at their back end, a
// pair of black bolt heads on each
const cleat = (x) => [box(0.14, 0.12, 0.26, { mat: "ironL", pos: [x, DECK - 0.01, -0.38], jitter: 0.004 }),
  [-0.06, 0.06].map((dz) => cyl(0.022, 0.025, { mat: "iron", sides: 8, pos: [x, DECK + 0.105, -0.38 + dz] }))]
model("bridge_end", deck(), cleat(-0.22), cleat(0.22))
// the bridge end on its post (169): a thick dark post under the middle of
// the end, tapering as it sinks into the water channel; the deck stays at
// y 0..0.22
model("bridge_end_post", { pivot: "origin" }, deck(), cleat(-0.22), cleat(0.22),
  tf({ pos: [0.0, -0.75, 0] }, lathe([0.3, 0, 0.27, 0.6, 0.3, 0.76], { mat: "plankD", sides: 4, rot: [0, 45, 0], jitter: 0.006 })))
looms("bridge_end_post")
// their columns: 1 m bodies to stack under them
model("stone_col", prism(roundSquare(HALF, 0.05), 1, 0, "stone", 0.006))
model("rock_col", box(0.96, 1, 0.96, { mat: "boulder", jitter: 0.03, seed: 7 }))
for (const n of ["stone_block", "rock_block", "ice_pillar", "moss_floor", "bridge_end", "stone_col", "rock_col"]) looms(n)

// --- more decoration -----------------------------------------------------------
// ice crystals (158): a fan of six ice shards 1.6 m, leaning out from one
// foot, round balls of snow on their tips, snow heaped at the foot
model("ice_crystals",
  [[0, 0, 0.24, 1.45, 6, 0], [0.08, 0.04, 0.18, 1.15, 22, 10], [-0.08, 0.02, 0.19, 1.2, 20, 170], [0.02, -0.08, 0.16, 0.9, 26, 260],
   [0.04, 0.1, 0.15, 0.75, 30, 80], [-0.06, -0.04, 0.14, 0.65, 34, 210]].map(([x, z, r, h, lean, yaw], i) => [
    shardAt(x, z, r, h, lean, yaw, 30 + i, i % 2 ? "shardD" : "shard"),
    tf({ pos: [x, 0, z], rot: [0, yaw, 0] }, tf({ rot: [0, 0, -lean] }, sphere(r * 0.3, { mat: "snow", detail: 2, pos: [0, h * 0.88, 0] })))]),
  snowHeap(0.35, 3))
// fence piece (166): two thick square posts and a heavy beam across their
// tops, its ends bevelled, a rope looped round each end and hanging slack,
// frayed tufts along it (owner: "dos palos de madera con uno arriba, como si
// fuera el trozo de una valla"); 1.1 m
const POST_H = 0.6
const beam = (len, w, h) => extrude([-len / 2, 0, len / 2, 0, len / 2, h - 0.05, len / 2 - 0.05, h, -len / 2 + 0.05, h, -len / 2, h - 0.05], w, { mat: "plank", jitter: 0.006, seed: 5 })
// a rope tied round the beam near x: three turns, frayed tufts, an end
// hanging slack down the post
const ropeLoop = (x, sgn) => [
  [-0.03, 0, 0.03].map((dx, i) => torus(0.16, 0.022, { mat: i % 2 ? "ropeD" : "rope", rings: 12, sides: 5, pos: [x + dx, POST_H + 0.12, 0], rot: [0, 0, 90] })),
  tube([x + sgn * 0.02, POST_H + 0.02, 0.15, x + sgn * 0.06, POST_H - 0.2, 0.14, x + sgn * 0.02, POST_H - 0.38, 0.13], 0.02, { mat: "rope", sides: 5 }),
  Array.from({ length: 6 }, (_, i) => { const a = i / 6 * Math.PI * 2
    return cone(0.02, 0.07, { mat: "ropeD", sides: 3, pos: [x, POST_H + 0.12 + Math.cos(a) * 0.17, Math.sin(a) * 0.17], rot: [a * 180 / Math.PI, 0, 0] }) }),
]
model("fence_piece",
  sym("x", box(0.22, POST_H, 0.22, { mat: "plankL", pos: [0.3, 0, 0], rot: [0, 4, 0], jitter: 0.012, seed: 1 })),
  tf({ pos: [0, POST_H - 0.02, 0], rot: [0, 0, 2] }, beam(1.0, 0.26, 0.28)),
  ropeLoop(0.3, 1), ropeLoop(-0.3, -1))
// the same fence piece under snow (160): heaped on the beam in big soft
// lumps, a little at the feet
model("fence_piece_snow", stamp("fence_piece"),
  sphere(0.26, { mat: "snow", detail: 3, pos: [-0.22, POST_H + 0.32, 0], scale: [1.3, 0.75, 1.0] }),
  sphere(0.24, { mat: "snow", detail: 3, pos: [0.06, POST_H + 0.38, 0.02], scale: [1.2, 0.8, 1.0] }),
  sphere(0.27, { mat: "snow", detail: 3, pos: [0.3, POST_H + 0.42, -0.02], scale: [1.3, 0.75, 1.0] }),
  sym("x", sphere(0.17, { mat: "snow", detail: 2, pos: [0.3, 0.02, 0.05], scale: [1.4, 0.35, 1.3] })))
// metal grate (513), the classic trap: a plate with a 3×3 grid of holes,
// a rusty frame round it
model("grate",
  box(0.8, 0.012, 0.8, { mat: "pit" }),
  [-1, 0, 1].flatMap((i) => [-1, 0, 1].map((j) => cyl(0.08, 0.034, { mat: "pit", sides: 10, pos: [i * 0.22, 0, j * 0.22] }))),
  // the plate around the holes: bars between them, so the holes stay open
  [-0.33, -0.11, 0.11, 0.33].map((v) => [box(0.66, 0.03, 0.06, { mat: "grate", pos: [0, 0.006, v] }),
    box(0.06, 0.03, 0.66, { mat: "grate", pos: [v, 0.006, 0] })]),
  [-1, 0, 1].flatMap((i) => [-1, 0, 1].map((j) => torus(0.09, 0.022, { mat: "grate", sides: 6, rings: 12, pos: [i * 0.22, 0.03, j * 0.22] }))),
  sym("z", box(0.84, 0.05, 0.06, { mat: "grateRim", pos: [0, 0, 0.39], jitter: 0.004 })),
  sym("x", box(0.06, 0.05, 0.72, { mat: "grateRim", pos: [0.39, 0, 0], jitter: 0.004 })))
// dead tree (150): a pale split trunk, no leaves, gnarled bare limbs
// clawing out of its broken top
model("dead_tree",
  lathe([0.36, 0, 0.25, 0.1, 0.18, 0.45, 0.15, 0.9, 0.13, 1.12, 0, 1.18],
    { mat: "deadBark", sides: 7, pos: [0, 0, 0], rot: [0, 0, -3], jitter: 0.03, seed: 4 }),
  // the split: two slabs of trunk peeling outward
  lathe([0.12, 0, 0.1, 0.4, 0.06, 0.75, 0, 0.82], { mat: "deadBark", sides: 5, pos: [0.13, 0.35, 0.05], rot: [0, 0, -16], jitter: 0.02, seed: 6 }),
  lathe([0.1, 0, 0.08, 0.35, 0.04, 0.6, 0, 0.66], { mat: "deadBarkD", sides: 5, pos: [-0.12, 0.45, -0.04], rot: [8, 0, 18], jitter: 0.02, seed: 7 }),
  [[0.3, 0, 0.05, 30], [-0.28, 0, 0.1, -40], [0.05, 0, 0.32, 80], [-0.1, 0, -0.28, 200]].map(([x, y, z, ry]) =>
    cone(0.09, 0.34, { mat: "deadBarkD", sides: 5, pos: [x * 0.8, 0.02, z * 0.8], rot: [0, ry, -74], jitter: 0.015 })),
  limb([0.05, 1.0, 0, 0.3, 1.2, 0.05, 0.42, 1.42, 0.14, 0.62, 1.55, 0.12, 0.72, 1.72, 0.05], 0.08, 0.025, "deadBarkD"),
  limb([0.42, 1.42, 0.14, 0.58, 1.38, 0.3, 0.7, 1.5, 0.4], 0.035, 0.016, "deadBarkD"),
  limb([-0.03, 1.05, 0, -0.25, 1.25, -0.05, -0.42, 1.32, 0.06, -0.58, 1.52, 0.04, -0.66, 1.7, -0.04], 0.075, 0.022, "deadBarkD"),
  limb([-0.42, 1.32, 0.06, -0.6, 1.28, -0.1, -0.74, 1.36, -0.16], 0.032, 0.014, "deadBarkD"),
  limb([0.0, 1.1, 0.02, 0.06, 1.42, -0.08, -0.02, 1.72, -0.14, 0.08, 1.9, -0.12], 0.065, 0.02, "deadBarkD"),
  limb([0.12, 0.72, 0.08, 0.4, 0.86, 0.14, 0.6, 1.02, 0.08, 0.7, 1.18, 0.12], 0.055, 0.018, "deadBarkD"),
  limb([-0.12, 0.9, -0.03, -0.4, 0.96, -0.18, -0.5, 1.12, -0.3], 0.05, 0.016, "deadBarkD"))
// snowy rocks (2584 tall, 2592 low, 2586 small): rounded grey-brown
// boulders (soft normals) under caps of snow
// tall rock (2584): a tall rounded rock 1.3 m tapering to a blunt top,
// bulging in two lobes, snow on its crown and in two patches on its sides,
// a little at its foot
model("rock_tall", { scale: 0.88 },
  lathe([0.42, 0, 0.47, 0.2, 0.42, 0.5, 0.36, 0.7, 0.33, 0.9, 0.24, 1.15, 0.1, 1.28, 0, 1.3], { mat: "softRock", sides: 9, jitter: 0.035, seed: 5 }),
  sphere(0.2, { mat: "snow", detail: 2, pos: [0.0, 1.2, 0.0], scale: [1.2, 0.45, 1.15] }),
  sphere(0.1, { mat: "snow", detail: 2, pos: [0.3, 0.68, 0.18], scale: [1.4, 0.4, 0.9] }),
  sphere(0.09, { mat: "snow", detail: 2, pos: [-0.2, 0.62, 0.32], scale: [1.4, 0.4, 0.9] }),
  sphere(0.12, { mat: "snow", detail: 2, pos: [0.25, 0.02, 0.4], scale: [1.6, 0.35, 1.0] }),
  sphere(0.1, { mat: "snow", detail: 2, pos: [-0.38, 0.02, 0.22], scale: [1.6, 0.35, 1.0] }))
// low rock (2592): a cone of rock 1.25 m across and 0.85 m high, its upper
// half under a smooth cap of snow, a ragged skirt of snow round its foot
model("rock_low", { scale: 0.85 },
  lathe([0.62, 0, 0.58, 0.15, 0.45, 0.4, 0.28, 0.65, 0.1, 0.8, 0, 0.82], { mat: "softRock", sides: 9, jitter: 0.03, seed: 9 }),
  lathe([0.42, 0.4, 0.44, 0.45, 0.36, 0.66, 0.2, 0.82, 0, 0.88], { mat: "snow", sides: 12, jitter: 0.015, seed: 3 }),
  [0, 1, 2, 3, 4].map((i) => { const a = i / 5 * Math.PI * 2 + 0.4
    return sphere(0.24, { mat: "snow", detail: 2, pos: [Math.cos(a) * 0.55, 0, Math.sin(a) * 0.5], scale: [1.4, 0.28, 1.1] }) }))
// small rock (2586): a low lumpy knot of stones 0.9 m across, thin snow on
// its tops
model("rock_small", { scale: 0.75 },
  [[-0.15, 0, 0.32, 0.6], [0.2, 0.05, 0.28, 0.55], [0.02, -0.18, 0.24, 0.6], [0.05, 0.22, 0.2, 0.5]].map(([x, z, r, h], i) =>
    sphere(r, { mat: "softRock", detail: 2, pos: [x, 0, z], scale: [1.2, h, 1.0], jitter: 0.02, seed: 20 + i })),
  [[-0.15, 0, 0.16], [0.2, 0.05, 0.12], [0.02, -0.18, 0.1]].map(([x, z, r], i) =>
    sphere(r, { mat: "snow", detail: 2, pos: [x, [0.18, 0.14, 0.13][i], z], scale: [1.2, 0.3, 1.0] })))
looms("rock_small")
for (const n of ["ice_crystals", "fence_piece", "fence_piece_snow", "grate", "dead_tree", "rock_tall", "rock_low"]) looms(n)

// no pack: the editor loads each piece from out/models/<name>.glb (kit.json
// lists them); a pack can't resolve the swapped materials across includes
