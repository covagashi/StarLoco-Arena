// Arena 10 (retail world 41: a butcher's kitchen) — the pieces it doesn't
// share with the other kits, each in three looms: <name> (a), <name>_b,
// <name>_c. Build kit.tx.js first. Retail gfx in brackets.
include("../common/shapes.kx.js")

const LOOMS = ["", "_b", "_c"]
pal(Object.fromEntries(LOOMS.flatMap((s) => [
  // the floor bricks (kit.tx.js paver): the joints pale, the bricks a shade
  // darker and greener (retail, smooth normals: soft*), their sides in shade
  ["joint" + s, { tex: "out/paver" + s, uv: 0.8, rough: 0.85, color: ["#d0d4e8", "#dcdcdc", "#e0d8d0"][LOOMS.indexOf(s)] }],
  ["softBrick" + s, { tex: "out/paver" + s, uv: 0.8, rough: 0.8, color: ["#b4bab8", "#b4b8bc", "#c8a49c"][LOOMS.indexOf(s)] }],
  ["softBrickD" + s, { tex: "out/paver" + s, uv: 0.8, rough: 0.85, color: ["#8a8e86", "#8a8e94", "#a8806e"][LOOMS.indexOf(s)] }],
  ["jointD" + s, { tex: "out/paver" + s, uv: 0.8, rough: 0.9, color: ["#acaca8", "#9a9ca0", "#b08474"][LOOMS.indexOf(s)] }],
])))
// wood: arena 6's board loom (grain along u) and boardV (grain along v, for
// upright faces; build arena 6's kit.tx.js first), tinted per piece family
const WOOD = {
  // the wooden posts under the floor (984, 985): grey-brown old timber
  post: ["#d8c4b0", "#b8b8b8", "#c89c84"], postD: ["#8c7c6c", "#707070", "#7a5848"],
}
// which board loom each loom of a family uses: the posts' grey-brown comes
// from the silver-grey boards warmed
const WOOD_TEX = { post: ["_b", "_b", "_c"], postD: ["_b", "_b", "_c"] }
pal(Object.fromEntries(LOOMS.flatMap((s, i) => Object.entries(WOOD).flatMap(([k, v]) => [
  [k + s, { tex: "../arena6/out/board" + (WOOD_TEX[k] || LOOMS)[i], uv: 0.8, rough: 0.85, color: v[i] }],
  [k + "V" + s, { tex: "../arena6/out/boardV" + (WOOD_TEX[k] || LOOMS)[i], uv: 0.8, rough: 0.85, color: v[i] }]]))))
// blood (kit.tx.js blood, bloodFlow): the river's top smooth (soft*), glossy;
// the falls streaked down, darker as they drop
pal(Object.fromEntries(LOOMS.flatMap((s) => [
  ["softBlood" + s, { tex: "out/blood" + s, uv: 1.2, rough: 0.2 }],
  ["softBloodFlow" + s, { tex: "out/bloodFlow" + s, uv: 1.2, rough: 0.2 }],
  ["softBloodFlowD" + s, { tex: "out/bloodFlow" + s, uv: 1.2, rough: 0.25, color: "#8c8080" }],
  ["softBloodFlowDD" + s, { tex: "out/bloodFlow" + s, uv: 1.2, rough: 0.3, color: "#5a5050" }],
  ["bloodBed" + s, { tex: "out/blood" + s, uv: 1.2, rough: 0.4, color: "#6a6060" }],
])))
// the gutters' and the stream's lit blood, a plain glossy red brighter than
// the river (the retail paints it lit): [a, b, c]
const LIT = { bloodLit: ["#96180e", "#4e4856", "#4e7a26"] }
pal(Object.fromEntries(LOOMS.flatMap((s, i) => Object.entries(LIT).map(([k, v]) => [k + s, { color: v[i], rough: 0.15 }]))))
// the dashes of the floor's joint line: [a, b, c]
const DASH = { dash: ["#5a5440", "#3e4042", "#5a2e20"] }
pal(Object.fromEntries(LOOMS.flatMap((s, i) => Object.entries(DASH).map(([k, v]) => [k + s, { color: v[i], rough: 0.95 }]))))
const SKINNED = ["softBlood", "softBloodFlow", "softBloodFlowD", "softBloodFlowDD", "bloodBed", "joint", "softBrick", "softBrickD", "jointD", ...Object.keys(DASH), ...Object.keys(LIT),
  ...Object.keys(WOOD).flatMap((k) => [k, k + "V"])]
const looms = (name) => threeLooms(name, SKINNED)

// --- floor --------------------------------------------------------------------
// brick slab (2736): a thin pale slab, its top three by three soft square
// bricks proud of the joints; one joint line (x = -0.16) dashed dark, as the
// retail draws it. The bricks are cushions dipping under the joint face at
// their rims, so nothing is coplanar.
const SLAB_H = 0.08, PITCH = 0.32, PAD = 0.156
model("brick_slab",
  // the body in shade, a thin pale joint face on top
  prismUp(roundSquare(CELL_HALF, 0.025), SLAB_H - 0.006, 0, "jointD", 0.003),
  prismUp(roundSquare(CELL_HALF - 0.006, 0.025), 0.008, SLAB_H - 0.008, "joint", 0.001),
  // each brick darker at its rim, paler in the middle
  [-1, 0, 1].flatMap((i) => [-1, 0, 1].map((k) =>
    terrain(2 * PAD, 2 * PAD, { res: 14, height: 0.026, fn: cushionFn(PAD, 0.09, 0.07, 0.2, i * 3 + k + 5),
      mat: (h) => h < 0.22 ? "softBrickD" : "softBrick", pos: [i * PITCH, SLAB_H - 0.002, k * PITCH] }))),
  Array.from({ length: 16 }, (_, j) => box(0.012, 0.006, 0.024, { mat: "dash", pos: [-PITCH / 2, SLAB_H - 0.003, -0.42 + j * 0.056] })))
looms("brick_slab")

// --- wooden posts: the blocks the floor stands on (984, 985) -----------------
// a cell-wide block of old timber, about 1.5 m: a big beam on top, its top
// split into planks, over shorter upright blocks; the floor slab (2736) caps
// it. Rounded vertical edges, thin dark gaps between the timbers.
const POST_H = 1.5
// an upright timber: x0..x1, z0..z1 (cell metres), y0..y1, rounded edges
const timber = (x0, x1, z0, z1, y0, y1, mat, seed, r = 0.05) => {
  const hw = (x1 - x0) / 2 - 0.012, hd = (z1 - z0) / 2 - 0.012
  const pts = roundSquare(1, r / Math.min(hw, hd)).map((v, i) => v * (i % 2 ? hd : hw))
  return extrude(pts, y1 - y0 - 0.016, { mat, rot: [90, 0, 0], pos: [(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2], jitter: 0.006, seed })
}
const H0 = -0.5, H1 = 0.5   // the retail posts fill the cell edge to edge
// post (984): the top beam over a low course of four blocks, two per face;
// its top two planks along x, a wide one and a narrow one at +z
// the dark heart the gaps between the timbers show
const postCore = () => box(0.94, POST_H - 0.04, 0.94, { mat: "postD", pos: [0, 0.01, 0] })
model("wood_post", postCore(),
  timber(H0, 0, H0, 0, 0, 0.5, "postDV", 1), timber(0, H1, H0, 0, 0, 0.5, "postV", 2),
  timber(H0, 0, 0, H1, 0, 0.5, "postV", 3), timber(0, H1, 0, H1, 0, 0.5, "postV", 4),
  timber(H0, H1, H0, H1, 0.5, POST_H - 0.07, "postV", 5),
  timber(H0, H1, H0, 0.16, POST_H - 0.07, POST_H, "post", 6, 0.04),
  timber(H0, H1, 0.16, H1, POST_H - 0.07, POST_H - 0.005, "post", 7, 0.04),
  // a split down the +z face
  box(0.012, 0.6, 0.01, { mat: "postD", pos: [0.08, 0.62, H1 - 0.003], rot: [0, 0, 4] }))
// post (985): the beam lower and split on its +x face; its top three planks,
// a long one along x at the back and two short ones along z in front
model("wood_post_alt", postCore(),
  timber(H0, 0, H0, H1, 0, 0.36, "postV", 11), timber(0, H1, H0, H1, 0, 0.36, "postV", 12),
  timber(H0, H1, H0, 0.02, 0.36, POST_H - 0.07, "postV", 13), timber(H0, H1, 0.02, H1, 0.36, POST_H - 0.07, "postV", 14),
  timber(H0, H1, H0, -0.12, POST_H - 0.07, POST_H, "post", 15, 0.04),
  timber(H0, 0.02, -0.12, H1, POST_H - 0.07, POST_H - 0.004, "post", 16, 0.04),
  timber(0.02, H1, -0.12, H1, POST_H - 0.07, POST_H, "post", 17, 0.04))
for (const n of ["wood_post", "wood_post_alt"]) looms(n)

// --- the river of blood (2458), its gutters (2461, 2465, 2470-2472) and
// falls (2459, 474) -----------------------------------------------------------
// river of blood (2458): a cell of thick glossy blood, gently rippled, edge
// to edge so a run of them is one river; it lies a step below the floor
const ripple = (seed) => (x, z) => 0.5 + 0.25 * Math.sin(x * 7 + seed) * Math.sin(z * 6 + seed * 1.3) + 0.25 * Math.sin((x + z) * 11 + seed * 2.1)
model("blood_river",
  prismUp(roundSquare(0.5, 0.02), 0.03, 0, "bloodBed", 0.002),
  terrain(1.0, 1.0, { res: 16, height: 0.018, fn: ripple(1), mat: "softBlood", pos: [0, 0.031, 0] }))
// blood gutter (2461, 2472): a channel of blood along x lying on the floor
// slab, between two low curbs of the slab's pale stone; it runs from edge to
// edge so gutters chain, and pours off the floor's rim as the blood stream
// (2459). The corner (2465, 2470, 2471) turns from +x to +z.
const GW = 0.1, CURB = 0.04
const curb = (x0, x1, z0, z1) => box(x1 - x0, 0.055, z1 - z0, { mat: "joint", pos: [(x0 + x1) / 2, 0, (z0 + z1) / 2], jitter: 0.002 })
const gutterBlood = (x0, x1, z0, z1) => box(x1 - x0, 0.03, z1 - z0, { mat: "bloodLit", pos: [(x0 + x1) / 2, 0, (z0 + z1) / 2] })
model("blood_gutter", { pivot: "origin" },
  gutterBlood(-0.5, 0.5, -GW, GW),
  curb(-0.5, 0.5, -GW - CURB, -GW), curb(-0.5, 0.5, GW, GW + CURB))
model("blood_gutter_corner", { pivot: "origin" },
  gutterBlood(-GW, 0.5, -GW, GW), gutterBlood(-GW, GW, GW, 0.5),
  // the outer curb wraps the corner, the inner one stops at it
  curb(-GW - CURB, 0.5, -GW - CURB, -GW), curb(-GW - CURB, -GW, -GW, 0.5),
  curb(GW, 0.5, GW, GW + CURB), curb(GW, GW + CURB, GW + CURB, 0.5))
// blood stream (2459): the thin pour from a gutter's end over the floor's
// rim: y = 0 is the lip it leaves, x = 0 the rim's face, falling about 1.3 m
// onto the river in a splash
const STREAM = 1.3
model("blood_stream", { pivot: "origin" },
  // the lip: a flattened roll over the rim (a tube's scale scales its points
  // too, so it is built at z = 0)
  tube([-0.1, 0.015, 0, 0.0, 0.0, 0, 0.06, -0.1, 0], 0.05, { mat: "bloodLit", sides: 6, scale: [1, 1, 1.6] }),
  cyl(0.07, STREAM - 0.08, { mat: "bloodLit", sides: 7, top: 0.06, pos: [0.07, -STREAM, 0], scale: [0.55, 1, 1.5], jitter: 0.004, seed: 2 }),
  // the splash: a low crown where it lands, droplets thrown out
  cyl(0.2, 0.03, { mat: "softBlood", sides: 9, top: 0.14, pos: [0.07, -STREAM, 0], jitter: 0.01, seed: 3 }),
  lathe([0.06, 0, 0.15, 0.06, 0.13, 0.1, 0.09, 0.07], { mat: "bloodLit", sides: 9, pos: [0.07, -STREAM + 0.02, 0] }),
  [[0.22, 0.1, 0.035], [-0.12, 0.07, 0.03], [0.14, 0.18, 0.025], [0.02, 0.14, 0.026], [0.18, 0.06, 0.022]].map(([x, z, r], i) =>
    sphere(r, { mat: "bloodLit", detail: 1, pos: [0.07 + x * (i % 2 ? -1 : 1), -STREAM + 0.06 + (i % 3) * 0.04, z * (i < 3 ? 1 : -1)] })))
// blood fall (474): the river pouring off the island's edge: a cell of blood
// rolling over its +x side and falling about 5.5 m as a sheet in three
// bulging streams, darkening as it drops (green in the retail sprite, tinted
// red on the map). y = 0 is the cell's top; turn it to face the drop.
const FALL_H = 5.5
model("blood_fall", { pivot: "origin" },
  prismUp(roundSquare(0.5, 0.02), 0.03, -0.03, "bloodBed", 0.002),
  terrain(1.0, 1.0, { res: 16, height: 0.018, fn: ripple(4), mat: "softBlood", pos: [0, 0.001, 0] }),
  // the roll over the rim
  // (a tube's scale also scales its points: flatten it at z = 0, then move it)
  [-0.3, 0, 0.3].map((z, i) => tf({ pos: [0, 0, z] }, tube([0.4, 0.0, 0, 0.5, -0.02, 0, 0.54, -0.14, 0], 0.08 - (i % 2) * 0.015, { mat: "softBloodFlow", sides: 6, scale: [1, 1, 1.9] }))),
  // the sheet in four bands that darken as it drops, three low bulges down
  // its face
  ["softBloodFlow", "softBloodFlow", "softBloodFlowD", "softBloodFlowDD"].map((m, j) =>
    box(0.07, FALL_H / 4 + 0.01, 0.98, { mat: m, pos: [0.52, -(j + 1) * FALL_H / 4, 0], jitter: 0.004, seed: j })),
  [-0.3, 0, 0.3].flatMap((z, i) => ["softBloodFlow", "softBloodFlow", "softBloodFlowD", "softBloodFlowDD"].map((m, j) =>
    cyl(0.12, FALL_H / 4 + 0.01, { mat: m, sides: 8, pos: [0.535, -(j + 1) * FALL_H / 4, z], scale: [0.35, 1, 1.1], jitter: 0.004, seed: i * 4 + j }))))
for (const n of ["blood_river", "blood_gutter", "blood_gutter_corner", "blood_stream", "blood_fall"]) looms(n)
