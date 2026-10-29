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
// the dashes of the floor's joint line: [a, b, c]
const DASH = { dash: ["#5a5440", "#3e4042", "#5a2e20"] }
pal(Object.fromEntries(LOOMS.flatMap((s, i) => Object.entries(DASH).map(([k, v]) => [k + s, { color: v[i], rough: 0.95 }]))))
const SKINNED = ["joint", "softBrick", "softBrickD", "jointD", ...Object.keys(DASH),
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
