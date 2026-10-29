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
  // the chicken cages (2738, 2739, 2741, 2745, 2751, 1437): honey planks
  // gone olive (retail), grey, dark; their round bars are palette (BAR)
  cage: ["#f0d898", "#c8c8c8", "#d0b098"], cageD: ["#a89070", "#8a8a8a", "#8c705c"],
  // the low table (1593): olive-green old wood (retail), grey, brown
  table: ["#c8c890", "#c0c0c0", "#d0a888"], tableD: ["#8a8a5c", "#808080", "#8a6a54"],
}
// which board loom each loom of a family uses: the posts' grey-brown comes
// from the silver-grey boards warmed
const WOOD_TEX = Object.fromEntries(["post", "postD", "cage", "cageD", "table", "tableD"].map((k) => [k, ["_b", "_b", "_c"]]))
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
// the cages' round bars and nail heads, the straw, and the chickens (yellow
// chick, white hen, brown hen): [a, b, c]
const BAR = {
  bar: ["#4e4c2c", "#3e4044", "#3a2a1e"], nail: ["#6c6a3c", "#6a6c70", "#5a4632"],
  straw: ["#e8c040", "#d8c890", "#c89a40"], hinge: ["#c86a1e", "#7a7a80", "#a0521e"],
  chick: ["#f4d238", "#f2eee2", "#a8622e"], chickD: ["#d8a020", "#cfc8b8", "#7a4220"],
  beak: ["#f08a1a", "#f0a020", "#e8b030"], comb: ["#d8281a", "#d8281a", "#c02018"], eye: ["#141010", "#141010", "#141010"],
}
pal(Object.fromEntries(LOOMS.flatMap((s, i) => Object.entries(BAR).map(([k, v]) =>
  [k + s, { color: v[i], rough: k === "nail" || k === "hinge" ? 0.5 : 0.85, metal: k === "nail" || k === "hinge" ? 0.4 : 0 }]))))
// the meat crates and boxes (kit.tx.js pine, pineV): golden pine, pale ash,
// dark stained; the corner posts and floor a shade darker
pal(Object.fromEntries(LOOMS.flatMap((s) => [
  ["crate" + s, { tex: "out/pine" + s, uv: 0.8, rough: 0.75 }],
  ["crateV" + s, { tex: "out/pineV" + s, uv: 0.8, rough: 0.75 }],
  ["crateD" + s, { tex: "out/pine" + s, uv: 0.8, rough: 0.8, color: "#a89078" }],
  ["crateDV" + s, { tex: "out/pineV" + s, uv: 0.8, rough: 0.8, color: "#a89078" }],
])))
// the tablecloths (kit.tx.js cloth): red, blue or green checks
pal(Object.fromEntries(LOOMS.map((s) => ["cloth" + s, { tex: "out/cloth" + s, uv: 1.0, rough: 0.92 }])))
// meat and bone, palette colours: fresh (retail), roasted, cured; [a, b, c]
const MEAT = {
  meat: ["#a82a20", "#7a3818", "#b86858"], meatD: ["#6a1410", "#4a1e0c", "#7a3a30"], fat: ["#f0dcc8", "#d8b088", "#f4e4d4"],
  ham: ["#7a4426", "#4e2810", "#9a6644"], hamL: ["#a8683e", "#7a4420", "#c08a64"],
  sausage: ["#dca492", "#9a5a32", "#c88a74"], sausageD: ["#a86a5a", "#6a3a1c", "#946050"],
  bone: ["#e4dabc", "#d8ccaa", "#ece4cc"], boneD: ["#aca07e", "#9c8e6a", "#b4aa90"],
  twine: ["#c89a20", "#b08a3a", "#a87a2a"], wicker: ["#b88a3a", "#8a7a5a", "#7a5430"], wickerD: ["#7a5420", "#5a4e3a", "#4e321a"],
}
pal(Object.fromEntries(LOOMS.flatMap((s, i) => Object.entries(MEAT).map(([k, v]) =>
  [k + s, { color: v[i], rough: k.startsWith("meat") ? 0.45 : k === "fat" ? 0.5 : 0.75 }]))))
// the dashes of the floor's joint line: [a, b, c]
const DASH = { dash: ["#5a5440", "#3e4042", "#5a2e20"] }
pal(Object.fromEntries(LOOMS.flatMap((s, i) => Object.entries(DASH).map(([k, v]) => [k + s, { color: v[i], rough: 0.95 }]))))
const SKINNED = ["softBlood", "softBloodFlow", "softBloodFlowD", "softBloodFlowDD", "bloodBed", "joint", "softBrick", "softBrickD", "jointD", "cloth", "crate", "crateV", "crateD", "crateDV", ...Object.keys(DASH), ...Object.keys(LIT), ...Object.keys(BAR), ...Object.keys(MEAT),
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

// a repeatable pseudo-random number in 0..1 for (i, k, seed)
const rnd = (i, k, seed) => ((Math.sin((i + 1) * 12.9898 * k + seed * 78.233) * 43758.5453) % 1 + 1) % 1
// --- chicken cages (2738, 2739, 2741, 2745, 2751, 1437) -----------------------
// a low cage a little wider than the cell: three thick planks along z for a
// floor, three for a lid, eight dark round bars between them (corners and
// middles), a nail head over each bar. 2741 is the same cage turned 90°. Two
// of them hold a chicken.
const CG = { len: 1.06, pw: 0.33, pt: 0.15, bar: 0.39, h: 0.55 }
// a thick plank along x centred at (y, z), rounded edges seen from above
const cagePlank = (y, z, len, mat, seed) =>
  tf({ pos: [0, y, z] }, extrude(roundSquare(1, 0.12).map((v, i) => v * (i % 2 ? (CG.pw - 0.02) / 2 : len / 2)), CG.pt,
    { mat, rot: [90, 0, 0], pos: [0, CG.pt / 2, 0], jitter: 0.005, seed }))
const cageBars = (y0, h, skip = []) => [-1, 0, 1].flatMap((i) => [-1, 0, 1].map((k) => [i, k]))
  .filter(([i, k]) => (i || k) && !skip.some(([a, b]) => a === i && b === k))
  .map(([i, k]) => cyl(0.055, h, { mat: "bar", sides: 7, pos: [i * CG.bar, y0, k * CG.bar], jitter: 0.003, seed: i * 3 + k }))
const nails = (y, pts) => pts.map(([x, z]) => sphere(0.055, { mat: "nail", detail: 1, pos: [x, y, z], scale: [1, 0.55, 1] }))
// two nail heads near each end of every lid plank
const lidNails = (y) => nails(y, [-1, 1].flatMap((sx) => [-1, 0, 1].flatMap((k) => [-1, 1].map((sz) => [sx * 0.43, k * CG.pw + sz * 0.08]))))
function cageBody(seed) {
  const top = CG.pt + CG.h
  return [
    [-1, 0, 1].map((k) => cagePlank(0, k * CG.pw, CG.len - (k === 0 ? 0.03 : 0), k ? "cage" : "cageD", seed + k)),
    cageBars(CG.pt - 0.01, CG.h + 0.02),
    [-1, 0, 1].map((k) => cagePlank(top, k * CG.pw, CG.len + (k === 1 ? 0.02 : 0), "cage", seed + 5 + k)),
    lidNails(top + CG.pt),
  ].map((it) => tf({ rot: [0, 90, 0] }, it))
}
// a round chicken, about 0.35 m: plump body, head, beak, comb, a tail tuft;
// faces +x
const chicken = (x, y, z, a, s = 1) => tf({ pos: [x, y, z], rot: [0, a, 0], scale: s },
  sphere(0.17, { mat: "chick", detail: 2, pos: [0, 0.16, 0], scale: [1.1, 0.95, 1] }),
  sphere(0.11, { mat: "chick", detail: 2, pos: [0.13, 0.3, 0] }),
  cone(0.035, 0.08, { mat: "beak", sides: 5, pos: [0.22, 0.29, 0], rot: [0, 0, -90] }),
  box(0.06, 0.06, 0.02, { mat: "comb", pos: [0.13, 0.4, 0], jitter: 0.008 }),
  [-1, 1].map((sz) => sphere(0.018, { mat: "eye", detail: 1, pos: [0.2, 0.33, sz * 0.06] })),
  [-1, 1].map((sz) => sphere(0.08, { mat: "chickD", detail: 1, pos: [-0.01, 0.17, sz * 0.15], scale: [1.3, 0.8, 0.4] })),
  cone(0.07, 0.12, { mat: "chickD", sides: 5, pos: [-0.17, 0.2, 0], rot: [0, 0, 60] }))
// cage (2738, 2741)
model("cage", cageBody(301))
// cage with a chicken (2739, 2745)
model("cage_chicken", cageBody(311), chicken(0.02, CG.pt, 0.0, 20, 1.3))
// open hutch (2751): a narrower, taller cage: the floor planks, bars ringed
// by two rails, and a band of planks round the top with a square mouth; its
// lid stands open on two orange hinges at the -x side; straw on the floor and
// two chickens inside
const HB = 0.4, HUT_TOP = 0.78
const hutBand = () => [[0, 1], [90, 1], [180, 1], [270, 1]].map(([r]) => tf({ rot: [0, r, 0] },
  box(2 * HB + 0.08, 0.26, 0.1, { mat: "cage", pos: [0, HUT_TOP - 0.26, HB], jitter: 0.004, seed: r })))
const straw = (n, r, y, seed) => Array.from({ length: n }, (_, i) => {
  const a = rnd(i, 3, seed) * 360, d = rnd(i, 5, seed) * r
  return box(0.32 + rnd(i, 7, seed) * 0.2, 0.012, 0.02, { mat: "straw",
    pos: [Math.cos(a * Math.PI / 180) * d, y + rnd(i, 9, seed) * 0.03, Math.sin(a * Math.PI / 180) * d], rot: [0, rnd(i, 11, seed) * 180, (rnd(i, 13, seed) - 0.5) * 20] })
})
model("cage_open",
  [-1, 0, 1].map((k) => cagePlank(0, k * 0.3, 0.96, k ? "cage" : "cageD", 321 + k)),
  [-1, 1].flatMap((i) => [-1, 1].map((k) => cyl(0.05, HUT_TOP - CG.pt, { mat: "bar", sides: 7, pos: [i * HB * 0.92, CG.pt - 0.01, k * HB * 0.92] }))),
  [-1, 1].flatMap((i) => [-0.13, 0.13].map((k) => cyl(0.042, 0.42, { mat: "bar", sides: 7, pos: [i * HB * 0.92, CG.pt - 0.01, k] }))),
  [-1, 1].flatMap((i) => [-0.13, 0.13].map((k) => cyl(0.042, 0.42, { mat: "bar", sides: 7, pos: [k, CG.pt - 0.01, i * HB * 0.92] }))),
  // the rails round the bars, their ends knobbed
  [0, 90, 180, 270].map((r) => tf({ rot: [0, r, 0] },
    cyl(0.03, 2 * HB + 0.06, { mat: "cageD", sides: 6, rot: [0, 0, 90], pos: [HB + 0.03, 0.36, HB * 0.95] }),
    sphere(0.045, { mat: "cageD", detail: 1, pos: [HB + 0.04, 0.36, HB * 0.95] }))),
  hutBand(),
  // the lid, open: hinged on the -x side of the mouth, leaning back past
  // upright; its two orange hinge straps
  tf({ pos: [-HB - 0.03, HUT_TOP, 0], rot: [0, 0, 96] },
    [-1, 1].map((k) => box(0.5, 0.1, 0.36, { mat: "cage", pos: [0.26, 0, k * 0.185], jitter: 0.005, seed: 331 + k })),
    [-0.2, 0.2].map((z) => box(0.18, 0.13, 0.07, { mat: "hinge", pos: [0.08, 0.02, z] }))),
  straw(26, 0.34, CG.pt, 341),
  straw(6, 0.45, CG.pt + 0.02, 351),
  chicken(0.05, CG.pt, -0.12, 30, 1.0), chicken(-0.08, CG.pt, 0.15, -20, 0.9))
// broken cage (1437): the floor planks whole, the lid slid off and leaning
// down onto the +x side, two bars knocked over and one still standing
model("cage_broken",
  tf({ rot: [0, 90, 0] }, [-1, 0, 1].map((k) => cagePlank(0, k * CG.pw, CG.len, k ? "cage" : "cageD", 361 + k))),
  // the lid planks leaning from the back over the standing bar to the front
  tf({ pos: [0.1, 0.12, 0], rot: [0, 0, -33] },
    [-1, 0, 1].map((k) => tf({ rot: [0, (k * 4), 0] }, box(1.0, CG.pt * 0.8, CG.pw - 0.02, { mat: "cage", pos: [0, 0, k * CG.pw], jitter: 0.005, seed: 365 + k }))),
    nails(CG.pt * 0.8, [[-0.4, -0.4], [-0.4, 0.27], [0.4, -0.3], [0.4, 0.38], [-0.4, 0.4], [0.4, 0.05]])),
  cyl(0.055, 0.62, { mat: "bar", sides: 7, pos: [-0.38, CG.pt - 0.02, -0.25], rot: [0, 0, 8] }),
  cyl(0.055, 0.62, { mat: "bar", sides: 7, pos: [-0.36, CG.pt - 0.02, 0.32], rot: [10, 0, 2] }),
  // the knocked-over bars: one fallen across the floor, one leaning out
  cyl(0.055, 0.6, { mat: "bar", sides: 7, pos: [-0.45, CG.pt + 0.05, -0.38], rot: [0, 0, 62] }),
  cyl(0.055, 0.55, { mat: "bar", sides: 7, pos: [0.1, CG.pt + 0.02, 0.42], rot: [-75, 20, 0] }))
for (const n of ["cage", "cage_chicken", "cage_open", "cage_broken"]) looms(n)


// --- the low table and its tablecloth (1593, 2651) ----------------------------
// low table (1593): a thick top of three planks along x, a little wider than
// the cell, on four square legs each bundled from two boards; about 0.55 m
const TABLE_H = 0.5
const leg = (x, z, seed) => [-1, 1].map((k) => box(0.11, TABLE_H - 0.2, 0.22, { mat: k < 0 ? "tableDV" : "tableV", pos: [x + k * 0.057, 0, z], jitter: 0.006, seed: seed + k }))
model("low_table",
  [[-1, -1], [1, -1], [-1, 1], [1, 1]].map(([sx, sz], i) => leg(sx * 0.33, sz * 0.33, 401 + i * 2)),
  [-1, 0, 1].map((k) => tf({ pos: [0, TABLE_H - 0.22, k * 0.335] },
    extrude(roundSquare(1, 0.25).map((v, i) => v * (i % 2 ? 0.163 : 0.52)), 0.22, { mat: "table", rot: [90, 0, 0], pos: [0, 0.11, 0], jitter: 0.008, seed: 411 + k }))))
// tablecloth (2651): a checked cloth laid on the low table's top (y = 0 is
// that top) and hanging over its +x side nearly to the floor, flaring out a
// little, its hem ragged
model("tablecloth", { pivot: "origin" },
  box(1.02, 0.015, 1.02, { mat: "cloth", pos: [0, 0, 0] }),
  tf({ pos: [0.51, 0.008, 0], rot: [90, 0, 0] }, cyl(0.02, 1.02, { mat: "cloth", sides: 6, pos: [0, -0.51, 0] })),
  tf({ pos: [0.525, 0, 0], rot: [0, 0, 6] },
    box(0.015, TABLE_H - 0.1, 1.02, { mat: "cloth", pos: [0, -(TABLE_H - 0.1), 0], jitter: 0.004, seed: 421 }),
    Array.from({ length: 9 }, (_, i) => box(0.012, 0.03 + rnd(i, 3, 425) * 0.04, 0.1, { mat: "cloth", pos: [0, -(TABLE_H - 0.1) - 0.03, -0.45 + i * 0.112], rot: [rnd(i, 5, 425) * 20 - 10, 0, 0] }))))
for (const n of ["low_table", "tablecloth"]) looms(n)

// --- meat: the butcher's cuts, shared by the crates, the basket, the plates
// and the block (2742-2744, 2758, 2759, 2363, 2476, 2525) --------------------
// a ham: a fat brown leg tapering to its knuckle, the cut face red with a
// ring of fat, a bone end poking out; s = its length, faces +x
const ham = (x, y, z, s, ry, rz = 0) => tf({ pos: [x, y, z], rot: [0, ry, rz], scale: s },
  sphere(0.5, { mat: "ham", detail: 2, scale: [0.62, 0.5, 0.5], pos: [0, 0.25, 0], jitter: 0.02, seed: 3 }),
  lathe([0.24, 0, 0.16, 0.25, 0.09, 0.42, 0.08, 0.5], { mat: "hamL", sides: 8, rot: [0, 0, 90], pos: [-0.12, 0.25, 0] }),
  cyl(0.24, 0.02, { mat: "fat", sides: 10, rot: [0, 0, -90], pos: [0.27, 0.25, 0], scale: [1, 1, 1] }),
  cyl(0.19, 0.024, { mat: "meat", sides: 10, rot: [0, 0, -90], pos: [0.275, 0.25, 0] }),
  cyl(0.045, 0.16, { mat: "bone", sides: 6, rot: [0, 0, 90], pos: [-0.56, 0.25, 0] }),
  sphere(0.07, { mat: "bone", detail: 1, pos: [-0.72, 0.25, 0], scale: [0.8, 1, 1.3] }))
// a string of sausages: n plump links along x, pinched and tied
const sausages = (x, y, z, n, r, ry, curl = 0) => tf({ pos: [x, y, z], rot: [0, ry, 0] },
  Array.from({ length: n }, (_, i) => {
    const a = i * curl * Math.PI / 180, px = Math.sin(a) * r * 2.6 * (curl ? 1 / (curl * Math.PI / 180) : i), pz = curl ? (1 - Math.cos(a)) * r * 2.6 / (curl * Math.PI / 180) : 0
    return [sphere(r, { mat: i % 2 ? "sausageD" : "sausage", detail: 1, pos: [curl ? px : i * r * 2.3, r, pz], rot: [0, -i * curl, 0], scale: [1.35, 1, 1] }),
      sphere(r * 0.35, { mat: "twine", detail: 0, pos: [(curl ? px : i * r * 2.3) + r * 1.2, r, pz] })]
  }))
// a steak: a flat slab of red meat, rounded, its edge rimmed with fat
const steak = (x, y, z, s, ry, tilt = 0) => tf({ pos: [x, y, z], rot: [tilt, ry, 0], scale: s },
  extrude(roundSquare(1, 0.6, 4, 0.12, 3).map((v, i) => v * (i % 2 ? 0.16 : 0.22)), 0.05, { mat: "fat", rot: [90, 0, 0], pos: [0, 0.025, 0] }),
  extrude(roundSquare(1, 0.6, 4, 0.12, 3).map((v, i) => v * (i % 2 ? 0.14 : 0.2)), 0.056, { mat: "meat", rot: [90, 0, 0], pos: [0.005, 0.028, 0] }),
  box(0.2, 0.058, 0.018, { mat: "fat", pos: [0.0, 0.0, 0.03], rot: [0, 25, 0] }))
// a short bone with knobbed ends, along x
const knuckleBone = (x, y, z, len, r, ry, rz = 0) => tf({ pos: [x, y, z], rot: [0, ry, rz] },
  cyl(r, len, { mat: "bone", sides: 6, rot: [0, 0, -90], pos: [-len / 2, 0, 0] }),
  [-1, 1].flatMap((e) => [-1, 1].map((k) => sphere(r * 1.5, { mat: e < 0 ? "boneD" : "bone", detail: 1, pos: [e * len / 2, 0, k * r * 0.9] }))))
// the heap of cuts in a crate or a basket: hams, steaks, bones, sausages,
// a smear of blood; centred at y, about r across
const meatHeap = (y, r, seed) => [
  sphere(r * 0.85, { mat: "hamL", detail: 1, pos: [0, y, 0], scale: [1, 0.4, 0.8] }),
  ham(-r * 0.3, y - 0.05, -r * 0.25, r * 1.6, 30, 30),
  ham(r * 0.35, y - 0.06, r * 0.15, r * 1.4, -150, 25),
  ham(-r * 0.1, y - 0.02, r * 0.45, r * 1.1, -60, 15),
  steak(-r * 0.55, y + 0.06, r * 0.3, 0.8, 20, -35), steak(r * 0.15, y + 0.16, -r * 0.4, 0.7, -40, 35),
  knuckleBone(r * 0.45, y + 0.16, -r * 0.05, 0.16, 0.03, 30, 35),
  sausages(r * 0.5, y + 0.02, r * 0.45, 3, 0.06, -70, 30),
]
// a crate of golden boards: two boards to a side, corner posts, open on top
const meatCrate = (w, d, h, seed) => [
  box(w - 0.06, 0.04, d - 0.06, { mat: "crateD", pos: [0, 0.01, 0] }),
  [0, 90, 180, 270].map((r, i) => tf({ rot: [0, r, 0] },
    [0, 1].map((k) => box((i % 2 ? d : w) - 0.03, h / 2 - 0.012, 0.04, { mat: "crate", pos: [0, k * h / 2, (i % 2 ? w : d) / 2 - 0.02], jitter: 0.005, seed: seed + i * 2 + k })))),
  [[1, 1], [1, -1], [-1, 1], [-1, -1]].map(([sx, sz]) => box(0.07, h, 0.07, { mat: "crateDV", pos: [sx * (w / 2 - 0.03), 0, sz * (d / 2 - 0.03)] })),
]
// a blood smear down the +z face of a crate (a thin decal, proud of it)
const smear = (x, y, z, w, h) => [box(w, h, 0.006, { mat: "meatD", pos: [x, y, z], jitter: 0.01 }),
  box(0.03, h * 1.4, 0.007, { mat: "meatD", pos: [x + w * 0.2, y - h * 0.6, z] })]
// two crates of meat (2744): two golden crates stacked, the top one heaped
// with hams, steaks, a bone and sausages, a string of sausages hanging down
// its +x side, blood smeared on the front
const CR = { w: 0.96, d: 0.78, h: 0.26 }
const crateStack = (seed) => [
  meatCrate(CR.w, CR.d, CR.h, seed),
  tf({ pos: [0.02, CR.h + 0.01, 0], rot: [0, 4, 0] }, meatCrate(CR.w, CR.d, CR.h, seed + 10), meatHeap(CR.h - 0.05, 0.4, seed)),
  smear(-0.1, CR.h + 0.12, CR.d / 2 + 0.005, 0.3, 0.08),
  tf({ pos: [CR.w / 2 + 0.06, 0.12, 0.18], rot: [0, 0, 80] }, sausages(0, 0, 0, 4, 0.055, 90)),
]
model("meat_crates", crateStack(431))
// crates of meat spilled (2743): the same two crates, a ham fallen against
// their front and a string of sausages on the floor
model("meat_crates_spilled", crateStack(451),
  ham(0.05, 0.0, CR.d / 2 + 0.2, 0.42, -100, 40),
  sausages(0.25, 0, 0.55, 3, 0.06, 20, 50),
  cyl(0.12, 0.004, { mat: "bloodLit", sides: 9, pos: [-0.05, 0, 0.55], scale: [1.4, 1, 0.8] }))
// basket of meat (2742): a round wicker basket heaped with the cuts, blood
// dripping under it, one sausage dropped beside it
model("meat_basket",
  lathe([0.22, 0, 0.3, 0.12, 0.36, 0.26, 0.34, 0.27, 0.27, 0.12, 0.18, 0.03], { mat: "wicker", sides: 12 }),
  [0.06, 0.12, 0.18].map((y, i) => torus(0.26 + y * 0.35, 0.015, { mat: "wickerD", pos: [0, y, 0], rings: 18, sides: 5 })),
  torus(0.355, 0.03, { mat: "wicker", pos: [0, 0.265, 0], rings: 18, sides: 6 }),
  meatHeap(0.22, 0.32, 461),
  cyl(0.16, 0.004, { mat: "bloodLit", sides: 9, pos: [0.06, 0, 0.12], scale: [1.4, 1, 0.9] }),
  sausages(-0.32, 0, 0.36, 2, 0.06, 30))
for (const n of ["meat_crates", "meat_crates_spilled", "meat_basket"]) looms(n)

// --- ribcages (2747, 2748, 234) -------------------------------------------------
// a curved tapering bone: chained lathe sections, each bent a little more
// (like arena 8's horn); starts at (x, y, z), leaning lean° from upright
// towards +x after turning turn° about y
const rib = (x, y, z, len, r, lean, bend, turn, segs = 4, mat = "bone", flat = 1) => {
  const sl = len / segs
  const sec = (i) => i >= segs ? [] : tf({ pos: [0, i ? sl : 0, 0], rot: [0, 0, i ? -bend : 0] },
    lathe([r * (1 - i / segs * 0.7), -0.008, r * (1 - (i + 1) / segs * 0.7), sl], { mat, sides: 5 }), sec(i + 1))
  return tf({ pos: [x, y, z], rot: [0, turn, 0] }, tf({ rot: [0, 0, -lean] }, tf({ scale: [1, 1, flat] }, sec(0))))
}
// a spine lying along x: knobbly vertebrae from x0 to x1 at height y
const spine = (x0, x1, y, r) => {
  const n = Math.max(3, Math.round((x1 - x0) / (r * 1.6)))
  return Array.from({ length: n }, (_, i) => [
    sphere(r, { mat: i % 2 ? "boneD" : "bone", detail: 1, pos: [x0 + (x1 - x0) * i / (n - 1), y, 0], scale: [0.8, 1, 1.1] }),
    box(r * 0.5, r * 1.6, r * 0.4, { mat: "bone", pos: [x0 + (x1 - x0) * i / (n - 1), y, -r * 0.6] })])
}
// ribcage (2747): a big ribcage lying on the floor, drawn as the retail
// draws it, in screen terms (turned 45° about y, so x runs along the
// screen's horizontal): the spine along it, seven ribs rising from it in two
// rows and sweeping back towards -x, longest in the middle; a pink scrap of
// gristle at the tail end
model("ribcage", tf({ rot: [0, 45, 0] },
  spine(-0.6, 0.5, 0.08, 0.08),
  [-0.48, -0.32, -0.16, 0, 0.16, 0.32, 0.46].map((x, i) => rib(x, 0.05, i % 2 ? 0.08 : -0.08, 0.6 + Math.sin((i + 1) / 8 * Math.PI) * 0.3, 0.06, -22, 24, 180, 4, "bone", 0.6)),
  tube([0.5, 0.08, 0, 0.66, 0.16, 0.02, 0.7, 0.3, 0.0, 0.6, 0.36, -0.03], 0.025, { mat: "sausage", sides: 5 })))
// small ribcage (2748): a little one lying flat, like a fish's bones: the
// spine along x, short ribs fanning out to both sides, one loose bone
model("ribcage_small", { scale: 1.35 },
  spine(-0.3, 0.3, 0.035, 0.04),
  [-0.24, -0.14, -0.04, 0.06, 0.16, 0.24].flatMap((x, i) => [-1, 1].map((k) => rib(x, 0.03, 0, 0.2 - Math.abs(i - 2.5) * 0.02, 0.025, 50, 14, k * 90 + 10, 3))),
  knuckleBone(0.12, 0.02, 0.32, 0.24, 0.018, -30))
// standing ribcage (234): a small ribcage stood up on its rib tips like a
// spider, the spine on top along x, the ribs arching out and down to the
// floor on both sides
model("ribcage_standing", { scale: 1.1 },
  spine(-0.24, 0.24, 0.2, 0.065),
  [-0.19, -0.065, 0.065, 0.19].flatMap((x, i) => [-1, 1].map((k) =>
    rib(x, 0.2, 0, 0.55, 0.075, 70, 30, -90 * k + (i - 1.5) * 10, 4, "bone", 0.75))).map((it) => tf({ rot: [0, 45, 0] }, it)))
for (const n of ["ribcage", "ribcage_small", "ribcage_standing"]) looms(n)
