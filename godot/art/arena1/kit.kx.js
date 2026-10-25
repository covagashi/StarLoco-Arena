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
])))
pal({
  iron: { color: "#3a3633", rough: 0.6, metal: 0.4 },
  glow: { color: "#ffd98a", emit: "#ffc65a", glow: 3 },
  glow_b: { color: "#bfe4ff", emit: "#8fd0ff", glow: 3 },
  glow_c: { color: "#ffb3a6", emit: "#ff7a5c", glow: 3 },
})
// the b and c looms of a piece: the same model, every skinned material swapped
const SKINNED = ["ice", "snow", "iceClear", "iceClearTop", "iceCol", "iceClearCol", "wood", "slab", "rune", "leaf", "pebble", "glow"]
function looms(name) {
  for (const s of Object.values(SFX))
    model(name + s, { base: name, swap: Object.fromEntries(SKINNED.map((m) => [m, m + s])) })
}

// --- blocks (153, 154 + 155/156) and columns: from block.kx.js -------------
for (const n of ["ice_block", "ice_clear", "ice_col", "ice_clear_col"]) looms(n)
// the tree (175): its snow takes the loom; the bark stays
for (const s of Object.values(SFX)) model("tree" + s, { base: "tree", swap: { snowT: "snow" + s } })

// --- wooden bridge (167): a low deck of planks on two beams ----------------
const PL = 6, PW = 0.96 / PL
model("bridge",
  sym("z", box(0.98, 0.16, 0.12, { mat: "wood", pos: [0, 0, 0.38], jitter: 0.01 })),
  Array.from({ length: PL }, (_, i) => box(PW - 0.018, 0.06, 0.98 - (i % 2) * 0.04,
    { mat: "wood", pos: [-0.48 + PW * (i + 0.5), 0.16, ((i * 7) % 3 - 1) * 0.012], rot: [0, ((i * 5) % 3 - 1) * 1.5, 0], jitter: 0.008, seed: i })),
  // iron nails over the beams
  Array.from({ length: PL }, (_, i) => sym("z", box(0.025, 0.012, 0.025,
    { mat: "iron", pos: [-0.48 + PW * (i + 0.5), 0.22, 0.38] }))))
looms("bridge")

// --- frost (170) and small frost (174): a line of drifted snow along one
// axis of the cell, its crest whipped into sharp peaks by the wind ----------
// ridge: lumps along x; peaks: [x, height, lean (deg, along the line), side]
const drift = (len, lumps, peaks) => [
  lumps.map(([x, r, h], i) => sphere(r, { mat: "snow", detail: 2, pos: [x * len, 0, ((i * 5) % 3 - 1) * 0.015],
    scale: [1.5, h, 0.8] })),
  peaks.map(([x, h, lean, side], i) => cone(0.03 + h * 0.07, h * 1.7, { mat: "snow", sides: 4,
    pos: [x * len, 0.02, side * 0.03], rot: [side * 14, (i * 37) % 90, -lean], scale: [1, 1, 0.55], jitter: 0.006 })),
]
model("frost", drift(0.9,
  [[-0.42, 0.09, 0.7], [-0.25, 0.11, 0.8], [-0.08, 0.1, 0.7], [0.1, 0.09, 0.65], [0.28, 0.08, 0.6], [0.44, 0.06, 0.55]],
  [[-0.45, 0.13, 25, 0], [-0.32, 0.24, 18, 1], [-0.22, 0.18, 30, -1], [-0.1, 0.27, 15, 0], [0.02, 0.15, 35, 1],
   [0.14, 0.2, 22, -1], [0.27, 0.12, 30, 0], [0.38, 0.16, 20, 1], [0.48, 0.08, 40, -1]]))
model("frost_small", drift(0.62,
  [[-0.38, 0.07, 0.7], [-0.15, 0.09, 0.8], [0.08, 0.08, 0.7], [0.3, 0.06, 0.6]],
  [[-0.4, 0.1, 28, 0], [-0.22, 0.19, 18, 1], [-0.05, 0.14, 30, -1], [0.12, 0.17, 20, 0], [0.32, 0.09, 35, 1]]))
looms("frost"); looms("frost_small")

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

// --- ice spike (157) and double spike (159) ---------------------------------
model("spike",
  sphere(0.36, { mat: "snow", detail: 2, scale: [1.2, 0.35, 1.1] }),
  cone(0.29, 1.75, { mat: "iceClear", sides: 6, jitter: 0.025 }),
  cone(0.14, 0.65, { mat: "iceClear", sides: 5, pos: [0.2, 0, 0.08], rot: [10, 30, -18], jitter: 0.02 }),
  cone(0.11, 0.45, { mat: "iceClear", sides: 5, pos: [-0.18, 0, -0.07], rot: [-12, 60, 20], jitter: 0.02 }),
  sphere(0.14, { mat: "snow", detail: 2, pos: [0.02, 0.1, 0.2], scale: [1.3, 0.6, 1] }))
model("spike_double",
  sphere(0.32, { mat: "snow", detail: 2, scale: [1.3, 0.35, 1.1] }),
  cone(0.15, 1.5, { mat: "iceClear", sides: 5, pos: [-0.06, 0, 0], rot: [0, 0, 9], jitter: 0.02 }),
  cone(0.13, 1.25, { mat: "iceClear", sides: 5, pos: [0.09, 0, 0.02], rot: [4, 40, -14], jitter: 0.02, seed: 4 }),
  cone(0.07, 0.45, { mat: "iceClear", sides: 5, pos: [0.02, 0, -0.14], rot: [-22, 10, 0], jitter: 0.02 }))
looms("spike"); looms("spike_double")

// --- slab with a baybayin glyph (470, 496, 497): lies on a block top --------
model("slab", prism(roundSquare(0.47, 0.05), 0.05, 0, "slab", 0.003))
looms("slab")

// --- floor rune (507, 508, 509, 510): a stone disc with a glowing glyph ----
model("rune", cyl(0.33, 0.035, { mat: "rune", sides: 28 }))
looms("rune")

// --- lantern post (1675; 1676 is its mirror, the editor flips it) ----------
model("lantern",
  box(0.34, 0.1, 0.34, { mat: "wood", jitter: 0.01 }),
  box(0.12, 1.15, 0.12, { mat: "wood", pos: [0, 0.1, 0], jitter: 0.006 }),
  // the cage: four slats round a glowing core, a roof, a ring on top
  box(0.3, 0.04, 0.3, { mat: "wood", pos: [0, 1.25, 0] }),
  sym("x", sym("z", box(0.035, 0.26, 0.035, { mat: "wood", pos: [0.12, 1.29, 0.12] }))),
  box(0.17, 0.22, 0.17, { mat: "glow", pos: [0, 1.3, 0] }),
  cone(0.26, 0.2, { mat: "wood", sides: 4, pos: [0, 1.55, 0], rot: [0, 45, 0] }),
  torus(0.04, 0.012, { mat: "iron", pos: [0, 1.77, 0] }),
  sphere(0.1, { mat: "snow", detail: 2, pos: [0, 1.66, 0], scale: [1.6, 0.5, 1.6] }),
  light({ type: "point", color: "#ffc65a", power: 6, pos: [0, 1.38, 0.3] }))
looms("lantern")

// --- snow mound (505), loose snow (503, 504), pebbles (161, 163) -----------
model("mound", { scale: 1.15 },
  sphere(0.3, { mat: "snow", detail: 3, scale: [1.3, 0.45, 1.1] }),
  sphere(0.2, { mat: "snow", detail: 3, pos: [0.25, 0, 0.1], scale: [1.2, 0.5, 1] }),
  sphere(0.16, { mat: "snow", detail: 3, pos: [-0.24, 0, -0.08], scale: [1.2, 0.55, 1] }))
model("loose_snow", { scale: 1.7 },
  [[0, 0, 0.09], [0.16, 0.06, 0.06], [-0.13, 0.1, 0.05], [0.05, -0.15, 0.045]].map(([x, z, r]) =>
    sphere(r, { mat: "snow", detail: 2, pos: [x, 0, z], scale: [1.3, 0.55, 1.2] })))
model("pebbles", { scale: 1.7 },
  rock(0.08, { mat: "pebble", seed: 2, pos: [0, 0.03, 0] }),
  rock(0.06, { mat: "pebble", seed: 5, pos: [0.13, 0.02, 0.06] }),
  rock(0.05, { mat: "pebble", seed: 8, pos: [-0.11, 0.02, 0.08] }),
  rock(0.045, { mat: "pebble", seed: 11, pos: [0.02, 0.02, -0.12] }),
  sphere(0.06, { mat: "snow", detail: 2, pos: [0, 0.09, 0], scale: [1.2, 0.4, 1.2] }))
looms("mound"); looms("loose_snow"); looms("pebbles")

// no pack: the editor loads each piece from out/models/<name>.glb (kit.json
// lists them); a pack can't resolve the swapped materials across includes
