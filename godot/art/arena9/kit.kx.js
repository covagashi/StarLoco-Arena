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
// the drains: wrought iron (arena 7's railing colours), the moss down the
// hole's mouth, the dark below, a brass rim, blood; [a, b, c]
const DRAIN = {
  iron: ["#5c6068", "#5e3c2a", "#36463e"], ironL: ["#868b94", "#84553a", "#557064"],
  mouth: ["#46482a", "#3e3e36", "#4a3424"], pit: ["#14120e", "#121214", "#160e0c"],
  brass: ["#c8a030", "#9a948a", "#b0763a"], blood: ["#8a1810", "#3a3440", "#4a7a24"], bloodD: ["#4c1410", "#24222a", "#2e4a18"],
}
pal(Object.fromEntries(LOOMS.flatMap((s, i) => Object.entries(DRAIN).map(([k, v]) =>
  [k + s, { color: v[i], rough: k.startsWith("iron") ? 0.5 : k === "brass" ? 0.35 : k.startsWith("blood") ? 0.25 : 0.95, metal: k.startsWith("iron") || k === "brass" ? 0.6 : 0 }]))))
// the axes: their heads olive verdigris (retail), steel, rusty iron; the
// hafts' wood and cloth wrapping
const AXE = {
  axe: ["#8a9c5c", "#9298a2", "#8a5a3a"], axeL: ["#bccc8c", "#c4c8ce", "#b47c54"], axeD: ["#56663a", "#5a5e66", "#552f1c"],
  haft: ["#8e7e34", "#6e5a40", "#5a3a22"], wrap: ["#e4dca0", "#dcd8cc", "#d4c094"],
  grip: ["#4a2a14", "#3a2e24", "#2e1c10"], slit: ["#100c08", "#100c08", "#100c08"],
}
pal(Object.fromEntries(LOOMS.flatMap((s, i) => Object.entries(AXE).map(([k, v]) =>
  [k + s, { color: v[i], rough: k.startsWith("axe") ? 0.45 : 0.85, metal: k.startsWith("axe") ? 0.5 : 0 }]))))
// the wall torch: its wood (bands of pale wood and dark iron), the prongs of
// its crown, the cold ash inside; [a, b, c]
const TORCH = {
  torchWood: ["#8e7c5c", "#7a7670", "#8a5e3e"], torchBand: ["#3a2c22", "#2e2e32", "#3a2418"],
  prong: ["#c8901e", "#9aa0a8", "#b0602a"], prongD: ["#7a5414", "#5a5e66", "#6a3418"], ash: ["#26201c", "#222224", "#2a1c18"],
}
pal(Object.fromEntries(LOOMS.flatMap((s, i) => Object.entries(TORCH).map(([k, v]) =>
  [k + s, { color: v[i], rough: k.startsWith("prong") ? 0.4 : 0.85, metal: k.startsWith("prong") ? 0.5 : 0 }]))))
const SKINNED = ["stone", "stoneShade", "stoneDark", "stonePale", "stoneBrown", "crack", ...Object.keys(DRAIN), ...Object.keys(AXE), ...Object.keys(TORCH)]
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

// --- drains (group «alcantarilla»: 1570 here, 2746 in arena 10) ------------
// a hole in the floor with iron bars over it; flat pieces laid on a floor
// block's top. The bars run along world z, as the retail draws them.
const bar = (x, y, half, r) => tube([x, y, -half, x, y, half], r, { mat: "iron", sides: 6 })
// a flat ring r0..r1 (a polygon cut open along +x, so it extrudes)
const ring = (r0, r1, n = 24) => {
  const pts = []
  for (let k = 0; k <= n; k++) pts.push(r1 * Math.cos(k / n * 2 * Math.PI), r1 * Math.sin(k / n * 2 * Math.PI))
  for (let k = n; k >= 0; k--) pts.push(r0 * Math.cos(k / n * 2 * Math.PI), r0 * Math.sin(k / n * 2 * Math.PI))
  return pts
}
// the sewer (1570): a square frame of the pale stone filling the cell, its
// mouth sloping down into the dark under a mossy lip, two thick bars lying
// across the hole, sunk below the frame
model("sewer_grate", { pivot: "origin" },
  // the frame: four stones round a square opening 0.54 m across
  sym("z", box(0.94, 0.06, 0.2, { mat: "stone", pos: [0, 0, 0.37], jitter: 0.006, seed: 91 })),
  sym("x", box(0.2, 0.06, 0.54, { mat: "stoneShade", pos: [0.37, 0, 0], jitter: 0.006, seed: 92 })),
  // the mouth: four mossy slopes from the frame's inner edge down to the dark
  [0, 90, 180, 270].map((a) => tf({ rot: [0, a, 0] },
    box(0.54, 0.012, 0.1, { mat: "mouth", pos: [0, 0.03, 0.23], rot: [-32, 0, 0] }))),
  box(0.4, 0.006, 0.4, { mat: "pit" }),
  bar(-0.07, 0.025, 0.25, 0.036), bar(0.08, 0.025, 0.25, 0.036))
// the drain (2746): a round hole with a brass rim at the end of the blood
// river, blood round the hole and lapping over the rim front and back, one
// bar across
model("blood_drain", { pivot: "origin" },
  torus(0.33, 0.035, { mat: "brass", sides: 6, rings: 24, pos: [0, 0.03, 0] }),
  prismUp(ring(0.2, 0.32), 0.03, 0, "blood"),
  torus(0.205, 0.015, { mat: "bloodD", sides: 5, rings: 24, pos: [0, 0.025, 0] }),
  cyl(0.21, 0.004, { mat: "pit", sides: 24 }),
  [[0.24, 0.24], [-0.24, -0.24]].map(([x, z], i) => sphere(1, { mat: "blood", detail: 2, pos: [x, 0.045, z], rot: [0, 45, 0], scale: [0.16, 0.02, 0.07], jitter: 0.004, seed: 81 + i })),
  bar(0.02, 0.04, 0.24, 0.03))
for (const n of ["sewer_grate", "blood_drain"]) looms(n)

// --- axes (group «hacha»: 2016 here, 2755 and 2481 in arena 10) -------------
// a flat blade: an outline in XY (metres) given a thickness along z
const blade = (pts, t, mat) => extrude(pts, t, { mat, pos: [0, 0, -t / 2], jitter: 0.004 })
// the war axe (2016): about 2.4 m, stuck upright in the floor and leaning a
// little to the right; a big head (socket and hammer in one block, a spike
// on top) and a crescent blade on +x, the haft wrapped in cloth under the
// head. Built facing the screen (x = screen horizontal), turned 45° at the end.
const crescent = [0.1, 1.7, 0.24, 1.86, 0.34, 2.14, 0.44, 2.0, 0.48, 1.8, 0.49, 1.6, 0.45, 1.38, 0.34, 1.12, 0.22, 1.02, 0.27, 1.22, 0.24, 1.36, 0.1, 1.46]
const crescentEdge = [0.34, 2.14, 0.44, 2.0, 0.48, 1.8, 0.49, 1.6, 0.45, 1.38, 0.34, 1.12, 0.22, 1.02,
  0.2, 1.07, 0.3, 1.17, 0.4, 1.4, 0.43, 1.6, 0.42, 1.8, 0.38, 1.97, 0.31, 2.07]
model("war_axe", { pivot: "origin" },
  tf({ rot: [0, 45, 0] }, tf({ rot: [0, 0, -8] },
    cyl(0.04, 0.9, { mat: "haft", sides: 6, pos: [0, -0.05, 0] }),
    // the cloth wrapping, banded, and two frayed ends hanging off it
    [0, 1, 2, 3, 4, 5].map((k) => cyl(k % 2 ? 0.058 : 0.066, 0.17, { mat: "wrap", sides: 7, pos: [0, 0.82 + k * 0.16, 0], rot: [0, 0, k % 2 ? 6 : -6], jitter: 0.006, seed: k })),
    box(0.035, 0.24, 0.012, { mat: "wrap", pos: [-0.09, 0.84, 0.03], rot: [0, 0, -28] }),
    box(0.035, 0.2, 0.012, { mat: "wrap", pos: [0.08, 1.04, 0.03], rot: [0, 0, 24] }),
    // the head: a chunky block round the haft, the hammer face on -x a shade
    // lighter, a blunt spike on top
    box(0.3, 0.42, 0.18, { mat: "axe", pos: [-0.05, 1.54, 0], jitter: 0.015, seed: 3 }),
    box(0.08, 0.34, 0.22, { mat: "axeL", pos: [-0.22, 1.58, 0], jitter: 0.01, seed: 4 }),
    // two rivets on the head
    sym("x", sphere(0.025, { mat: "axeD", detail: 1, pos: [0.05, 1.8, 0.09] })),
    box(0.08, 0.08, 0.21, { mat: "axeD", pos: [0.02, 1.7, 0] }),
    cone(0.06, 0.16, { mat: "axeL", sides: 4, pos: [-0.06, 1.95, 0] }),
    // the crescent blade on +x, its neck in the head; a lighter honed band
    // along the edge, a little thicker than the blade so it shows
    blade(crescent, 0.05, "axe"), blade(crescentEdge, 0.06, "axeL"))))

// the butcher's axe (2755 on a table, 2481 in a wall): a wide blade whose
// edge (along x, at y = 0) is sunk in a surface, a socket at its back
// (0, 0.3); the haft goes on from the socket its own way, as each sprite
// has it. A dark slit marks the cut.
const cleaverBlade = [-0.42, 0.0, 0.4, 0.0, 0.3, 0.2, 0.14, 0.3, 0.1, 0.26, 0.02, 0.32, -0.06, 0.28, -0.12, 0.33, -0.3, 0.24]
const cleaverHead = () => [blade(cleaverBlade, 0.04, "axe"), box(0.14, 0.12, 0.08, { mat: "axeD", pos: [0.0, 0.25, 0] })]
// the haft along +y from the socket: dark grip, white wrapping, a knob
const cleaverHaft = () => [
  cyl(0.03, 0.28, { mat: "grip", sides: 6 }),
  cyl(0.04, 0.32, { mat: "wrap", sides: 7, pos: [0, 0.26, 0] }),
  sphere(0.05, { mat: "grip", detail: 1, pos: [0, 0.62, 0] }),
]
// on a table (2755): the edge 6 cm into the top along world x, the blade
// leaning back 32°, the haft going back (-z) almost level and turned 30°
// towards +x
model("butcher_axe", { pivot: "origin" },
  tf({ pos: [0, -0.07, 0], rot: [-32, 0, 0], scale: 1.15 }, cleaverHead()),
  tf({ pos: [0, 0.22, -0.19], rot: [0, -30, 0] }, tf({ rot: [-82, 0, 0] }, cleaverHaft())),
  box(0.86, 0.004, 0.03, { mat: "slit" }))
// in a wall (2481): the wall is the plane x = 0, its face towards +x; the
// edge upright 6 cm into it, the haft coming out and down (+x, 39° down)
// the whole turned 30° about the edge so the blade shows its face
model("butcher_axe_wall", { pivot: "origin" }, tf({ rot: [0, 30, 0] },
  tf({ pos: [-0.06, 0.9, 0], rot: [0, 0, -90], scale: 1.15 }, cleaverHead()),
  tf({ pos: [0.27, 0.9, 0], rot: [0, 0, -129] }, cleaverHaft()),
  box(0.004, 0.98, 0.03, { mat: "slit", pos: [0, 0.41, 0] })))
for (const n of ["war_axe", "butcher_axe", "butcher_axe_wall"]) looms(n)

// --- wall torch (group «antorcha»: 1538), unlit ------------------------------
// fixed to the corner of a pillar, high up: from the bottom, a pointed bulb, a
// narrow stem, a cup of pale wood bound with dark iron bands, and a crown of
// golden prongs round the cold ash. About 0.95 m. y = 0 is the bulb's tip;
// an iron bracket goes back from the cup (-x -z, away from the camera) to the
// wall.
model("wall_torch", { pivot: "origin" },
  lathe([0, 0, 0.06, 0.04, 0.11, 0.12, 0.1, 0.2, 0.06, 0.24], { mat: "torchWood", sides: 7 }),
  cyl(0.07, 0.03, { mat: "prong", sides: 7, pos: [0, 0.15, 0] }),
  cyl(0.055, 0.12, { mat: "torchWood", sides: 7, pos: [0, 0.23, 0] }),
  // the cup: four bands, pale and dark, widening upwards
  [[0.34, 0.11, "torchBand"], [0.4, 0.13, "torchWood"], [0.46, 0.135, "torchBand"], [0.52, 0.15, "torchWood"], [0.58, 0.155, "torchBand"]].map(([y, r, mat], k) =>
    lathe([r - 0.02, 0, r, 0.02, r, 0.06], { mat, sides: 9, pos: [0, y - 0.01, 0], rot: [0, k * 9, 0] })),
  lathe([0, 0, 0.1, 0, 0.12, 0.34], { mat: "torchWood", sides: 9, pos: [0, 0.31, 0] }),
  // the crown: a ring and seven short prongs splayed out, the ash heaped inside
  cyl(0.17, 0.05, { mat: "prongD", sides: 9, pos: [0, 0.64, 0] }),
  lathe([0, 0, 0.15, 0, 0.11, 0.06, 0, 0.09], { mat: "ash", sides: 8, pos: [0, 0.66, 0] }),
  Array.from({ length: 7 }, (_, k) => {
    const a = k / 7 * 360 + 10, h = k % 2 ? 0.12 : 0.17
    return tf({ rot: [0, a, 0] }, tf({ pos: [0.15, 0.67, 0], rot: [0, 0, -38] },
      cone(0.045, h, { mat: "prong", sides: 4, scale: [0.6, 1, 1] })))
  }),
  // the bracket to the wall
  tf({ rot: [0, 225, 0] }, box(0.05, 0.05, 0.3, { mat: "torchBand", pos: [0, 0.43, 0.2] }), box(0.2, 0.26, 0.03, { mat: "torchBand", pos: [0, 0.32, 0.34] })))
looms("wall_torch")
