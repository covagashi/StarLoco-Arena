// Arena 2 (retail world 10: autumn and lava) — the pieces it doesn't share
// with the arena 1 kit, each in three looms: <name> (a), <name>_b, <name>_c.
// Broad surfaces use loom textures (kit.tx.js); plants and weapons use
// palette colours, 2–3 tones placed by light. Retail gfx in brackets.
include("../common/shapes.kx.js")

const LOOMS = ["", "_b", "_c"]
pal(Object.fromEntries(LOOMS.flatMap((s) => [
  ["crag" + s, { tex: "out/crag" + s, uv: 1, rough: 0.85 }],
  ["flag" + s, { tex: "out/flag" + s, uv: 1, rough: 0.8 }],
  ["lava" + s, { tex: "out/lava" + s, uv: 0.8, rough: 0.4 }],
  ["totem" + s, { tex: "out/totem" + s, uv: 0.8, rough: 0.8 }],
])))
// palette looms: [a, b, c] per key
const PAL = {
  leafD: ["#5a4410", "#5e1a0e", "#34401a"], leaf: ["#8f7222", "#a0341a", "#5a6e26"], leafL: ["#c8a23e", "#d8642c", "#8ea444"],
  twig: ["#3b2a1e", "#2e1c16", "#3a3226"],
  bark: ["#b9b090", "#6e5a44", "#8a8a84"], barkD: ["#7e765c", "#43362a", "#5a5a56"],
  blade: ["#3e3416", "#2c3a1a", "#5a4a26"], bladeL: ["#8a7a3a", "#5e7a34", "#b09a58"],
  basalt: ["#4e6656", "#5a5a5e", "#5e4a3a"], basaltL: ["#7a9a80", "#86868a", "#8a7058"], basaltD: ["#2e3e34", "#38383c", "#3a2c22"],
  pale: ["#d8d2b8", "#c8ccd0", "#d8c0a0"], paleD: ["#a8a088", "#9a9ea4", "#a88c6c"], tuft: ["#7a9a3a", "#5a8a4a", "#9a9a3a"],
  steel: ["#9aa0a8", "#b08a4a", "#8a5a3a"], steelD: ["#5a6068", "#6a4a22", "#4a2a1a"],
  grip: ["#5a3a22", "#3a2a2a", "#6a4a2a"], bone: ["#e4dcc0", "#d0c8a8", "#c8c0b0"], boneD: ["#a8a088", "#988e70", "#8a8478"],
}
pal(Object.fromEntries(LOOMS.flatMap((s, i) => Object.entries(PAL).map(([k, v]) => [k + s, v[i]]))))
pal({ glowL: { color: "#ffb040", emit: "#ff8a20", glow: 4 } })
const SKINNED = ["crag", "flag", "lava", "totem", ...Object.keys(PAL)]
const looms = (name) => threeLooms(name, SKINNED)

// --- ground ------------------------------------------------------------------
// rock block (1240, 1242, 1243, 1244): a cell of cracked earth rock, a few
// plates standing proud of the faces
model("rock_block",
  prismUp(roundSquare(CELL_HALF, 0.04), 0.86, 0, "crag", 0.012),
  box(0.42, 0.38, 0.06, { mat: "crag", pos: [-0.18, 0.12, 0.47], rot: [4, 0, 3], jitter: 0.02, seed: 1 }),
  box(0.36, 0.3, 0.06, { mat: "crag", pos: [0.47, 0.42, 0.12], rot: [0, 90, -4], jitter: 0.02, seed: 2 }),
  box(0.5, 0.06, 0.4, { mat: "crag", pos: [0.15, 0.85, -0.18], rot: [0, 12, 3], jitter: 0.02, seed: 3 }),
  box(0.3, 0.32, 0.06, { mat: "crag", pos: [0.22, 0.5, 0.47], rot: [-3, 0, -5], jitter: 0.02, seed: 4 }))
model("crag_col", prismUp(roundSquare(CELL_HALF, 0.04), 1, 0, "crag", 0.012))
// flagstone (129, 130, 131): a low slab with a lip spilling over its rim
model("flagstone",
  prismUp(roundSquare(0.5, 0.1), 0.05, 0, "flag", 0.006),
  prismUp(roundSquare(0.47, 0.1), 0.09, 0.04, "flag", 0.008))
// lava pool (142, 143): a molten sheet, glowing drips over its edge
model("lava_pool",
  prismUp(roundSquare(0.49, 0.12), 0.07, 0, "lava", 0.006),
  [[-0.3, 0.5], [0.05, 0.5], [0.32, 0.5], [0.5, -0.2], [0.5, 0.18]].map(([x, z], i) =>
    lathe([0, -0.1 - (i % 3) * 0.04, 0.035, -0.06, 0.045, 0, 0.04, 0.07, 0, 0.075],
      { mat: "lava", sides: 7, pos: [x * 0.98, 0, z * 0.98], scale: [1, 1, 0.6] })))
for (const n of ["rock_block", "crag_col", "flagstone", "lava_pool"]) looms(n)

// --- plants ------------------------------------------------------------------
// a mass of leaves: a dark core covered in maple leaves turned outward, the
// lighter ones on top (where the light falls)
// a maple leaf: five broad rounded lobes, shallow notches (r(θ) over 28 points)
const maple = Array.from({ length: 28 }, (_, i) => {
  const t = (i / 28) * Math.PI * 2, lobe = Math.pow(Math.abs(Math.cos(2.5 * (t - Math.PI / 2))), 1.5)
  const r = 0.085 * (0.68 + 0.32 * lobe) * (1 - 0.35 * Math.max(0, -Math.sin(t)))
  return [Math.cos(t) * r, Math.sin(t) * r + 0.02]
}).flat()
function leaves(x, y, z, r, seed) {
  const out = [sphere(r * 0.8, { mat: "leafD", detail: 1, pos: [x, y, z], jitter: 0.05, seed })]
  const n = Math.round(10 + r * 40)
  for (let i = 0; i < n; i++) {
    // golden-angle points over the sphere, fewer underneath
    const t = (i + 0.5) / n, yy = 1 - 1.6 * t, rr = Math.sqrt(Math.max(0, 1 - yy * yy)), a = i * 137.5 + seed * 31
    const nx = Math.cos(a * Math.PI / 180) * rr, nz = Math.sin(a * Math.PI / 180) * rr
    const k = 2.2 + ((i * 7 + seed) % 5) * 0.25
    out.push(tf({ pos: [x + nx * r * 0.85, y + yy * r * 0.85, z + nz * r * 0.85], rot: [0, -a + 90, 0] },
      extrude(maple, 0.015, { mat: yy > 0.3 ? "leafL" : yy > -0.3 ? "leaf" : "leafD", rot: [-(yy * 70) + 20, 0, (i * 53) % 360], scale: k * r * 0.9 })))
  }
  return out
}
const twig = (pts, r) => tube(pts, r, { mat: "twig", sides: 5 })
// autumn bush (1016, 1022, 1028, 1033, 1034): round and dense, twigs poking out
model("autumn_bush",
  leaves(0, 0.55, 0, 0.55, 1), leaves(0.45, 0.45, 0.2, 0.4, 4), leaves(-0.42, 0.42, 0.15, 0.4, 7),
  leaves(0.1, 0.95, -0.25, 0.4, 10), leaves(-0.2, 0.4, -0.4, 0.35, 13),
  twig([0.1, 0.9, 0.1, 0.35, 1.35, 0.15, 0.5, 1.5, 0.1], 0.025), twig([-0.2, 0.8, 0, -0.55, 1.2, -0.05], 0.022),
  twig([0.3, 0.5, 0.4, 0.72, 0.7, 0.55], 0.02))
// tall autumn bush (1021, 1035): sparser, its twigs climbing out of the top
model("autumn_bush_tall",
  leaves(0, 0.55, 0, 0.45, 21), leaves(0.35, 0.5, 0.15, 0.32, 24), leaves(-0.3, 0.45, 0.1, 0.32, 27),
  leaves(0.05, 1.05, -0.05, 0.36, 30), leaves(-0.15, 1.45, 0.05, 0.24, 33),
  twig([0, 0.9, 0, 0.1, 1.6, 0.05, 0.25, 2.1, 0.1], 0.03), twig([0.05, 1.3, 0, -0.3, 1.8, -0.05, -0.4, 2.05, 0], 0.022),
  twig([0.1, 1.1, 0, 0.5, 1.5, 0.1, 0.62, 1.62, 0.15], 0.02), leaves(0.25, 2.1, 0.1, 0.13, 36), leaves(0.62, 1.62, 0.15, 0.12, 39))
// autumn tree (1029): a short trunk splitting under a crown of leaf masses
model("autumn_tree",
  lathe([0.16, 0, 0.11, 0.4, 0.09, 1.0], { mat: "twig", sides: 6, jitter: 0.01 }),
  twig([0, 0.9, 0, -0.25, 1.3, 0.05], 0.06), twig([0, 0.9, 0, 0.3, 1.35, -0.05], 0.06),
  leaves(0, 1.55, 0, 0.55, 41), leaves(0.45, 1.35, 0.15, 0.4, 44), leaves(-0.45, 1.4, -0.05, 0.42, 47),
  leaves(0.1, 2.0, -0.1, 0.35, 50), leaves(-0.1, 1.2, 0.4, 0.3, 53))
// bare tree (2558, 2559): a slim pale trunk, thin branches, a few leaves left
const branch = (pts, r) => tube(pts, r, { mat: "barkD", sides: 5 })
model("bare_tree",
  lathe([0.11, 0, 0.08, 0.15, 0.06, 1.2, 0.035, 2.0, 0, 2.15], { mat: "bark", sides: 7, jitter: 0.008 }),
  [[0.04, 0.05, 0.12, 30], [-0.03, 0.05, 0.1, 160], [0.0, 0.04, 0.12, 270]].map(([x, y, l, a]) =>
    tf({ rot: [0, a, 0] }, cone(0.05, l * 2, { mat: "barkD", sides: 5, pos: [0.07, 0.04, 0], rot: [0, 0, -75] }))),
  branch([0, 1.0, 0, 0.3, 1.35, 0.05, 0.42, 1.55, 0.1], 0.025), branch([0, 1.3, 0, -0.28, 1.6, -0.05, -0.36, 1.8, 0], 0.022),
  branch([0, 1.7, 0, 0.18, 1.95, 0.1, 0.2, 2.1, 0.15], 0.018), branch([0, 0.7, 0, -0.25, 0.9, 0.1], 0.02),
  [[0.42, 1.58, 0.1], [-0.36, 1.83, 0], [0.2, 2.12, 0.15], [-0.25, 0.92, 0.1], [0.1, 1.2, -0.12]].map(([x, y, z], i) =>
    extrude([0, 0, 0.04, 0.05, 0, 0.12, -0.04, 0.05], 0.01, { mat: i % 2 ? "leaf" : "leafL", pos: [x, y, z], rot: [70, i * 50, 0] })))
// fallen leaves (127, 201, 202, 203): maple leaves lying flat
model("fallen_leaves",
  [[0, 0, 0, "leafL"], [0.2, 0.1, 40, "leaf"], [-0.18, 0.15, 110, "leafL"], [0.1, -0.2, 200, "leaf"],
   [-0.25, -0.12, 300, "leafD"], [0.32, -0.08, 80, "leafL"], [-0.05, 0.3, 160, "leaf"]].map(([x, z, a, m], i) =>
    tf({ pos: [x, 0.01 + i * 0.002, z], rot: [0, a, 0] },
      extrude(maple, 0.012, { mat: m, rot: [90, 0, 0], scale: 1 + (i % 3) * 0.15 }))))
// spiky grass (246): long striped blades fanned out of a clump
model("spiky_grass",
  Array.from({ length: 16 }, (_, i) => {
    const a = i * 137.5 % 360, lean = 25 + (i * 23) % 40, h = 0.55 + ((i * 7) % 5) * 0.08
    return tf({ rot: [0, a, 0] }, cone(0.075, h * 1.3, { mat: i % 3 ? "blade" : "bladeL", sides: 3, rot: [lean, 0, 0], scale: [1, 1, 0.3], jitter: 0.005 }))
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
// basalt rocks (137): a knot of hexagonal stone columns, mossy tops
model("basalt_rocks",
  [[0, 0, 0.17, 0.75], [0.22, 0.1, 0.14, 0.5], [-0.2, 0.08, 0.15, 0.6], [0.05, -0.22, 0.13, 0.42], [-0.1, 0.26, 0.12, 0.35],
   [0.3, -0.15, 0.1, 0.3], [-0.32, -0.14, 0.11, 0.28]].map(([x, z, r, h], i) => [
    cyl(r, h, { mat: i % 2 ? "basalt" : "basaltD", sides: 6, pos: [x, 0, z], rot: [0, i * 17, 0], jitter: 0.01 }),
    cyl(r * 0.96, 0.03, { mat: "basaltL", sides: 6, pos: [x, h, z], rot: [0, i * 17, 0] })]))
// lava rock (128): a raised slab, lava pouring off its front edge
model("lava_rock",
  prismUp(roundSquare(0.42, 0.1), 0.12, 0.55, "flag", 0.008),
  cyl(0.18, 0.56, { mat: "crag", sides: 6, jitter: 0.02 }),
  extrude([-0.12, 0, 0.12, 0, 0.1, -0.7, 0.14, -1.15, -0.14, -1.15, -0.1, -0.7], 0.06,
    { mat: "lava", pos: [0.12, 0.67, 0.42], jitter: 0.004 }),
  sphere(0.1, { mat: "lava", detail: 1, pos: [0.12, 0.66, 0.38], scale: [1.4, 0.4, 1] }))
// totems (274: two heads, 275: three, horned): carved stone, moss on top
const head = (y, h, w, s) => [
  prismUp(roundSquare(w, 0.08), h, y, "totem", 0.01),
  sym("x", box(0.08, 0.06, 0.03, { mat: "basaltD", pos: [w * 0.4, y + h * 0.6, w + 0.005] })),
  torus(0.07, 0.018, { mat: "totem", pos: [0, y + h * 0.28, w + 0.01], rot: [90, 0, 0] }),
  box(w * 1.5, 0.05, 0.03, { mat: "totem", pos: [0, y + h * 0.45, w + 0.01], seed: s }),
]
const mossTop = (y, w) => [cone(0.05, 0.22, { mat: "tuft", sides: 3, pos: [-w * 0.3, y, 0], rot: [0, 0, 15] }),
  cone(0.05, 0.3, { mat: "tuft", sides: 3, pos: [w * 0.2, y, 0.05], rot: [10, 0, -12] }),
  cone(0.04, 0.18, { mat: "tuft", sides: 3, pos: [0, y, -w * 0.3], rot: [-15, 0, 0] })]
model("totem", head(0, 0.75, 0.32, 1), head(0.72, 0.65, 0.27, 2), mossTop(1.37, 0.27))
model("totem_tall", head(0, 0.7, 0.3, 3), head(0.68, 0.62, 0.26, 4), head(1.28, 0.55, 0.23, 5),
  sym("x", cone(0.06, 0.22, { mat: "totem", sides: 5, pos: [0.22, 1.7, 0], rot: [0, 0, -50] })), mossTop(1.83, 0.23))
// white stones (611, 616): a few pale flat fragments, grass between them
const frag = (x, z, s, a, m) => extrude([0, 0.12, 0.11, 0.05, 0.08, -0.1, -0.06, -0.12, -0.12, 0.02], 0.04,
  { mat: m, pos: [x, 0.02, z], rot: [-90, 0, a], scale: s, jitter: 0.004 })
model("white_stones",
  frag(0, 0, 1.5, 0, "pale"), frag(0.25, 0.12, 1, 60, "paleD"), frag(-0.22, 0.15, 1.1, 140, "pale"), frag(0.12, -0.25, 0.9, 220, "pale"),
  [[0.14, 0.24], [-0.3, -0.05], [0.33, -0.12]].map(([x, z], i) => cone(0.03, 0.12, { mat: "tuft", sides: 3, pos: [x, 0, z], rot: [10, i * 40, 8] })))
for (const n of ["rock_column", "basalt_rocks", "lava_rock", "totem", "totem_tall", "white_stones"]) looms(n)

// --- weapons -------------------------------------------------------------------
// mace and dagger on the ground (1270, 1272)
model("weapons_ground",
  cyl(0.025, 0.42, { mat: "grip", sides: 6, rot: [0, 0, 80], pos: [-0.05, 0.03, 0] }),
  sphere(0.08, { mat: "steelD", detail: 1, pos: [0.2, 0.08, 0.0] }),
  [0, 72, 144, 216, 288].map((a) => tf({ pos: [0.2, 0.08, 0], rot: [0, a, 0] }, cone(0.025, 0.07, { mat: "steel", sides: 4, pos: [0.07, 0, 0], rot: [0, 0, -90] }))),
  box(0.22, 0.012, 0.04, { mat: "steel", pos: [-0.1, 0.01, 0.2], rot: [0, 30, 0] }),
  box(0.07, 0.03, 0.03, { mat: "grip", pos: [-0.24, 0.015, 0.28], rot: [0, 30, 0] }))
// curved sword stuck in the ground (1289)
model("sword_stuck",
  extrude([0, 0, 0.05, 0, 0.08, 0.35, 0.05, 0.6, -0.02, 0.72, -0.04, 0.3], 0.02, { mat: "steel", pos: [0, -0.05, 0] }),
  box(0.2, 0.03, 0.05, { mat: "steelD", pos: [0.02, 0.66, 0] }),
  cyl(0.02, 0.2, { mat: "grip", sides: 6, pos: [0.02, 0.68, 0] }),
  sphere(0.03, { mat: "steelD", detail: 1, pos: [0.02, 0.9, 0] }))
// spear stuck in the ground (1294): a trident head
model("spear_stuck",
  cyl(0.02, 1.25, { mat: "grip", sides: 6, rot: [0, 0, 6] }),
  tf({ pos: [-0.13, 1.24, 0], rot: [0, 0, 6] },
    cone(0.035, 0.28, { mat: "steel", sides: 4 }),
    sym("x", cone(0.02, 0.16, { mat: "steel", sides: 4, pos: [0.07, 0.0, 0], rot: [0, 0, -12] })),
    box(0.16, 0.025, 0.03, { mat: "steelD" })))
// big serrated bone blade stuck in the ground (2006)
model("bone_blade_stuck",
  extrude([-0.08, 0, 0.08, 0, 0.1, 0.12, 0.07, 0.2, 0.11, 0.3, 0.07, 0.4, 0.1, 0.5, 0.05, 0.62, 0, 0.75, -0.06, 0.6, -0.1, 0.3],
    0.04, { mat: "bone", pos: [0, -0.04, 0], jitter: 0.004 }),
  box(0.06, 0.03, 0.05, { mat: "boneD", pos: [0, 0.73, 0] }),
  cyl(0.025, 0.28, { mat: "grip", sides: 6, pos: [0, 0.75, 0], rot: [0, 0, 4] }),
  sphere(0.035, { mat: "steelD", detail: 1, pos: [-0.02, 1.04, 0] }))
for (const n of ["weapons_ground", "sword_stuck", "spear_stuck", "bone_blade_stuck"]) looms(n)
