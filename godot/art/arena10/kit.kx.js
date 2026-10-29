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
// the pale boxes (1620, 2740): pine, its a loom the pale ash (retail), b the
// golden, c the dark; their recessed panels in shade. The barrel (832): the
// golden pine warmed to orange
const PINE_OF = ["_b", "", "_c"]
pal(Object.fromEntries(LOOMS.flatMap((s, i) => [
  ["box" + s, { tex: "out/pine" + PINE_OF[i], uv: 0.8, rough: 0.8 }],
  ["boxV" + s, { tex: "out/pineV" + PINE_OF[i], uv: 0.8, rough: 0.8 }],
  ["boxDV" + s, { tex: "out/pineV" + PINE_OF[i], uv: 0.8, rough: 0.85, color: "#8a7a64" }],
  ["stave" + s, { tex: "out/pine" + s, uv: 0.8, rough: 0.7, color: "#ffb478" }],
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
// grease, leather and skin, steel, ivory, the soup: [a, b, c]
const MISC = {
  grease: ["#c4ac54", "#bcb47c", "#9c8a3a"], greaseD: ["#7e7038", "#706e50", "#5e4e22"],
  leather: ["#8a3418", "#2e2622", "#9a6a3a"], leatherL: ["#b04a24", "#4a3e36", "#c08a52"], strap: ["#6a6a2a", "#5a4a2a", "#3a2a1a"],
  skin: ["#bcd2c0", "#e2bca2", "#c8a07c"], steel: ["#a8acb2", "#7a7e84", "#9a6a4a"], steelD: ["#5a5e66", "#3e4046", "#5a3a26"],
  tusk: ["#e6dca8", "#f0ece0", "#d8c49a"], tuskD: ["#b4a676", "#c4beac", "#a48e66"],
  stake: ["#8a5a2a", "#5e4a36", "#6a3a1a"], stakeD: ["#4e2e12", "#3a2c20", "#3a1c0a"],
  tong: ["#6e8a6a", "#5a5e66", "#7a6a4a"], tongL: ["#9ab890", "#8a8e96", "#a8946a"], rust: ["#a8542a", "#8a4a2a", "#7a3a1a"],
  handle: ["#6a3e1e", "#4a3a2e", "#8a5a30"], mallet: ["#e2dac0", "#b8b4aa", "#c8a074"],
  plate: ["#e0c060", "#ece8de", "#c8784a"], plateD: ["#a88a34", "#b8b2a4", "#8a4a2a"], dish: ["#7a5230", "#5a4a3a", "#8a6a4a"],
  lettuce: ["#6aa83a", "#4a8a3a", "#8ab040"], lettuceD: ["#3a6a1e", "#2a5a24", "#5a7a24"], mash: ["#ecdcb0", "#e8d8b8", "#f0e0a0"], carrot: ["#e86a1e", "#d8501a", "#e8902a"],
  glass: ["#8a8a2a", "#3a6a4a", "#8a3a2a"], liquor: ["#4a2210", "#2a1a10", "#5a1a10"], cup: ["#a8744a", "#8a8a8a", "#b8885a"],
  fur: ["#b8ba8e", "#8a8680", "#a8825a"], furD: ["#86885e", "#5e5a56", "#7a5a3a"], pink: ["#d888a8", "#d890a0", "#c87888"],
  flesh: ["#f0c8c0", "#e8b8b0", "#f4d0c4"], fleshD: ["#c88880", "#b8787a", "#d09088"],
  sheet: ["#c4bca0", "#a8acb0", "#b49a7a"], coal: ["#2e2420", "#26262a", "#2a1c16"], ash: ["#8a8a8a", "#6e6e70", "#8a8070"],
  dress: ["#7ea2c8", "#a87e9a", "#8aa86a"], dressD: ["#4e6e94", "#7a5470", "#5a7a44"], apronBlue: ["#4e7086", "#6a4a5a", "#4a6a4a"],
  apronBrown: ["#6a5444", "#4a4a4e", "#8a6a3a"], slipper: ["#e898c0", "#c8a0e0", "#f0b890"], yarn: ["#9ac83a", "#e8b030", "#4aa0d0"],
  stitch: ["#3a9a3a", "#3a5aa8", "#a83a3a"], heart: ["#e85a2a", "#e8c030", "#e85a8a"], pale: ["#ece0b8", "#e8cfb4", "#c89878"],
  pelt: ["#c0641e", "#8a7a6a", "#a83a1a"], peltL: ["#e08a3a", "#aa9a88", "#c85a2a"], stone: ["#b4c2b0", "#a8a8a8", "#c0a890"], stoneD: ["#7a907a", "#787878", "#8a7460"],
  jar: ["#9ab08a", "#9aaab8", "#b8a080"], pickle: ["#f0dc98", "#e0e8b0", "#f0b878"], string: ["#c8281a", "#2a5aa8", "#3a8a3a"],
  skull: ["#e8d080", "#e0dcd0", "#d8b878"], skullD: ["#9a8040", "#8a8680", "#8a6a3a"],
  soup: ["#5aa03a", "#8a5a2a", "#a82a1a"], soupL: ["#9ad060", "#b8844a", "#d8582e"], towel: ["#f2f0ea", "#e8e0c8", "#e0e4ec"],
}
const MISC_ROUGH = { glass: 0.1, liquor: 0.1, plate: 0.4, plateD: 0.45, tong: 0.5, tongL: 0.45, flesh: 0.45, fleshD: 0.5, grease: 0.25, greaseD: 0.35, steel: 0.35, steelD: 0.45, soup: 0.15, soupL: 0.15, tusk: 0.5, tuskD: 0.55 }
pal(Object.fromEntries(LOOMS.flatMap((s, i) => Object.entries(MISC).map(([k, v]) =>
  [k + s, { color: v[i], rough: MISC_ROUGH[k] ?? 0.85, metal: k.startsWith("steel") ? 0.6 : k.startsWith("tong") ? 0.4 : 0 }]))))
// glowing embers in the grill and the hearth: [a, b, c]
const EMBER = { ember: ["#ff5a14", "#ffb020", "#ff3010"] }
pal(Object.fromEntries(LOOMS.flatMap((s, i) => Object.entries(EMBER).map(([k, v]) => [k + s, { color: v[i], emit: v[i], glow: 2, rough: 0.5 }]))))
// the dashes of the floor's joint line: [a, b, c]
const DASH = { dash: ["#5a5440", "#3e4042", "#5a2e20"] }
pal(Object.fromEntries(LOOMS.flatMap((s, i) => Object.entries(DASH).map(([k, v]) => [k + s, { color: v[i], rough: 0.95 }]))))
const SKINNED = ["softBlood", "softBloodFlow", "softBloodFlowD", "softBloodFlowDD", "bloodBed", "joint", "softBrick", "softBrickD", "jointD", "cloth", "crate", "crateV", "crateD", "crateDV", "box", "boxV", "boxDV", "stave", ...Object.keys(DASH), ...Object.keys(LIT), ...Object.keys(BAR), ...Object.keys(MEAT), ...Object.keys(MISC), ...Object.keys(EMBER),
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


// --- grease stains (1385, 1466) -------------------------------------------------
// the owner's "stained slab": yellow grease spilt on a floor slab, lying on
// it (flat): overlapping round splashes, a darker rim under each
const splashes = (spots, seed) => spots.map(([x, z, r], i) => [
  cyl(r * 1.15, 0.005, { mat: "greaseD", sides: 9, pos: [x, 0, z], scale: [1, 1, 0.8 + rnd(i, 3, seed) * 0.4], rot: [0, rnd(i, 5, seed) * 180, 0], jitter: r * 0.08, seed: seed + i }),
  cyl(r, 0.008, { mat: "grease", sides: 9, pos: [x, 0, z], scale: [1, 1, 0.8 + rnd(i, 3, seed) * 0.4], rot: [0, rnd(i, 5, seed) * 180, 0], jitter: r * 0.08, seed: seed + i })])
// grease stain (1385): a ring of splashes round the slab's middle
model("grease_stain", { pivot: "origin" }, splashes(Array.from({ length: 15 }, (_, i) => {
  const a = i / 15 * Math.PI * 2 + rnd(i, 7, 501) * 0.3, d = 0.3 + rnd(i, 9, 501) * 0.08
  return [Math.cos(a) * d, Math.sin(a) * d, 0.09 + rnd(i, 11, 501) * 0.07]
}), 501))
// small grease stain (1466): one sprawling splash of drops
model("grease_stain_small", { pivot: "origin", scale: 1.4 }, splashes([[0, 0, 0.14], [0.14, -0.08, 0.1], [-0.15, 0.06, 0.1], [0.06, 0.16, 0.08],
  [-0.06, -0.17, 0.08], [0.24, 0.06, 0.06], [-0.26, -0.06, 0.05], [0.18, 0.2, 0.04], [-0.2, 0.2, 0.05]], 511))
for (const n of ["grease_stain", "grease_stain_small"]) looms(n)

// --- severed legs (2758, 2759) ------------------------------------------------------
// a leg in a boot: the boot along +x, its shaft up y, a strap round it, the
// pale leg out of its top cut red, the bone sticking out
const bootLeg = () => [
  extrude(roundSquare(1, 0.5).map((v, i) => v * (i % 2 ? 0.07 : 0.14)), 0.14, { mat: "leather", rot: [0, 0, 0], pos: [0.05, 0.07, 0], scale: [1, 1, 1] }),
  cyl(0.1, 0.32, { mat: "leather", sides: 8, top: 0.11, pos: [-0.02, 0.02, 0] }),
  cyl(0.12, 0.05, { mat: "leatherL", sides: 8, pos: [-0.02, 0.32, 0] }),
  cyl(0.106, 0.05, { mat: "strap", sides: 8, pos: [-0.02, 0.14, 0] }),
  cyl(0.075, 0.13, { mat: "skin", sides: 8, pos: [-0.02, 0.36, 0] }),
  cyl(0.078, 0.025, { mat: "meat", sides: 8, pos: [-0.02, 0.49, 0] }),
  cyl(0.026, 0.13, { mat: "bone", sides: 6, pos: [-0.02, 0.5, 0] }),
  [-1, 1].map((k) => sphere(0.035, { mat: "bone", detail: 1, pos: [-0.02, 0.64, k * 0.024] })),
]
// leg (2758): standing in its boot, about 0.65 m
model("severed_leg", { scale: 1.2 }, tf({ rot: [0, -90, 0] }, bootLeg()))
// leg lying (2759): the same leg fallen along x, a pool of blood at the cut
model("severed_leg_lying", { scale: 1.2 }, tf({ pos: [0, 0.11, 0], rot: [0, 0, 90] }, bootLeg()),
  cyl(0.16, 0.004, { mat: "bloodLit", sides: 9, pos: [-0.55, -0.0, 0.02], scale: [1.4, 1, 0.9] }))
for (const n of ["severed_leg", "severed_leg_lying"]) looms(n)

// --- pale boxes: the broken box of bones (2740) and the tall box (1620) --------
// a box with a beam frame on its twelve edges, each side a panel of upright
// boards set back in shade, an iron bolt at every frame joint
function frameBox(w, h, d, { top = true, seed = 1 } = {}) {
  const t = 0.08, out = []
  for (const [sx, sz] of [[1, 1], [1, -1], [-1, 1], [-1, -1]])
    out.push(box(t, h, t, { mat: "boxV", pos: [sx * (w - t) / 2, 0, sz * (d - t) / 2], jitter: 0.004 }))
  for (const y of [0, h - t]) {
    for (const sz of [1, -1]) out.push(box(w, t, t, { mat: "box", pos: [0, y, sz * (d - t) / 2], jitter: 0.004 }))
    for (const sx of [1, -1]) out.push(box(t, t, d - 2 * t, { mat: "box", pos: [sx * (w - t) / 2, y, 0], jitter: 0.004 }))
  }
  // the panels: boards a little set back from the frame
  const n = 3
  for (const [r, len, off] of [[0, w, d], [90, d, w], [180, w, d], [270, d, w]])
    out.push(tf({ rot: [0, r, 0] }, Array.from({ length: n }, (_, i) => box((len - 2 * t) / n - 0.008, h - 2 * t, 0.03,
      { mat: "boxDV", pos: [-(len - 2 * t) / 2 + (i + 0.5) * (len - 2 * t) / n, t, off / 2 - t * 0.6], jitter: 0.004, seed: seed + r + i }))))
  // the lid set down inside the frame
  if (top) out.push(box(w - 2 * t, 0.03, d - 2 * t, { mat: "boxDV", pos: [0, h - t * 1.6, 0] }))
  out.push(box(w - 0.04, 0.03, d - 0.04, { mat: "boxDV", pos: [0, 0.01, 0] }))
  // bolts at the joints on the two faces the camera sees, and on top
  for (const y of [t / 2, h - t / 2]) for (const k of [-1, 1]) {
    out.push(sphere(0.022, { mat: "steelD", detail: 1, pos: [k * (w / 2 - t / 2), y, d / 2 + 0.002], scale: [1, 1, 0.5] }))
    out.push(sphere(0.022, { mat: "steelD", detail: 1, pos: [w / 2 + 0.002, y, k * (d / 2 - t / 2)], scale: [0.5, 1, 1] }))
  }
  return out
}
// broken box of bones (2740): an open box about 0.8 m, bones and bloody meat
// heaped inside, two long bones sticking out, blood run down its +z side
model("bone_box", frameBox(0.86, 0.72, 0.86, { top: false, seed: 521 }),
  sphere(0.36, { mat: "meatD", detail: 1, pos: [0, 0.6, 0], scale: [1, 0.3, 1] }),
  steak(-0.12, 0.66, 0.1, 1.0, 30, 20),
  knuckleBone(0.12, 0.85, -0.12, 0.5, 0.04, 30, 55), knuckleBone(-0.22, 0.76, -0.1, 0.32, 0.035, -60, 70),
  knuckleBone(0.05, 0.7, 0.2, 0.3, 0.03, 100, 10),
  smear(-0.12, 0.62, 0.435, 0.24, 0.09), smear(0.2, 0.4, 0.435, 0.06, 0.2),
  cyl(0.08, 0.004, { mat: "bloodLit", sides: 8, pos: [0.22, 0, 0.5], scale: [1.4, 1, 0.8] }))
// tall box (1620): a closed box about 0.9 m square and 1.3 m tall
model("tall_box", frameBox(0.9, 1.3, 0.9, { seed: 531 }))
for (const n of ["bone_box", "tall_box"]) looms(n)

// --- bear trap (2479) -------------------------------------------------------------
// a steel trap lying open: a flat ring with teeth all round pointing up, the
// two jaws laid out flat, the pressure plate and its bar across the middle
model("bear_trap", { scale: 1.5 },
  torus(0.2, 0.035, { mat: "steel", rings: 20, sides: 5, pos: [0, 0.035, 0], scale: [1, 1.2, 0.8] }),
  Array.from({ length: 12 }, (_, i) => {
    const a = i / 12 * Math.PI * 2
    return cone(0.035, 0.09, { mat: i % 2 ? "steel" : "steelD", sides: 4, pos: [Math.cos(a) * 0.2, 0.06, Math.sin(a) * 0.16], rot: [0, 0, 0] })
  }),
  box(0.42, 0.025, 0.04, { mat: "steelD", pos: [0, 0.01, 0] }),
  box(0.12, 0.02, 0.1, { mat: "steel", pos: [0, 0.02, 0] }),
  [-1, 1].map((k) => box(0.06, 0.03, 0.05, { mat: "steelD", pos: [k * 0.24, 0.0, 0] })))
looms("bear_trap")

// --- tusks (2593) -------------------------------------------------------------------
// a heap of five great tusks, their roots together on the floor, rising
// nearly upright and curling a little towards -x (screen terms, like the ribs)
model("tusks", tf({ rot: [0, 45, 0] },
  rib(0.1, 0, -0.05, 0.85, 0.13, 6, 7, 180, 5, "tusk", 0.85),
  rib(-0.05, 0, 0.08, 0.7, 0.12, 12, 6, 175, 5, "tusk", 0.85),
  rib(0.22, 0, 0.1, 0.55, 0.11, 4, 8, 185, 5, "tuskD", 0.85),
  rib(-0.2, 0, -0.04, 0.45, 0.085, 35, 8, 170, 5, "tusk", 0.85),
  rib(-0.3, 0, 0.12, 0.35, 0.08, 70, 6, 160, 4, "tuskD", 0.85)))
looms("tusks")

// --- stakes (2072) ------------------------------------------------------------------
// five sharpened wooden stakes driven into the floor
model("stakes", [[-0.18, -0.1, 0.32], [0.05, -0.2, 0.36], [0.2, 0.0, 0.3], [-0.05, 0.12, 0.4], [0.24, 0.24, 0.24]].map(([x, z, h], i) =>
  [cone(0.065, h, { mat: "stake", sides: 6, pos: [x, 0, z], rot: [(rnd(i, 3, 541) - 0.5) * 12, 0, (rnd(i, 5, 541) - 0.5) * 12], jitter: 0.004, seed: 541 + i }),
    cone(0.017, h * 0.25, { mat: "stakeD", sides: 6, pos: [x, h * 0.74, z], rot: [(rnd(i, 3, 541) - 0.5) * 12, 0, (rnd(i, 5, 541) - 0.5) * 12] })]))
looms("stakes")

// --- barrels: the barrel on its cradle (832) and the soup tub (1855) ---------------
// barrel (832): a barrel lying along x on two wooden cradles, orange staves,
// two pairs of iron hoops, a tap at its +x end
const BR = 0.24, BL = 0.72, BY = 0.36
model("barrel_tap",
  tf({ pos: [-BL / 2, BY, 0], rot: [0, 0, -90] },
    lathe([BR * 0.86, 0, BR, BL * 0.3, BR, BL * 0.7, BR * 0.86, BL], { mat: "stave", sides: 12 }),
    [0.1, 0.2, 0.8, 0.9].map((u) => torus(BR * (0.95 + 0.1 * Math.sin(u * Math.PI)) * 0.98, 0.016, { mat: "steel", rings: 16, sides: 4, pos: [0, u * BL, 0] }))),
  [-1, 1].map((k) => cyl(BR * 0.8, 0.02, { mat: "box", sides: 12, rot: [0, 0, 90], pos: [k * (BL / 2 + 0.0) + (k > 0 ? 0.01 : 0), BY, 0] })),
  cyl(0.025, 0.08, { mat: "steelD", sides: 6, rot: [0, 0, -90], pos: [BL / 2, BY - 0.08, 0] }),
  box(0.03, 0.06, 0.02, { mat: "steel", pos: [BL / 2 + 0.07, BY - 0.07, 0] }),
  // the cradles: a block with a hollow for the barrel
  [-0.2, 0.2].map((x) => extrude([-0.24, 0, 0.24, 0, 0.24, 0.2, 0.15, 0.22, 0.06, 0.15, -0.06, 0.15, -0.15, 0.22, -0.24, 0.2], 0.1,
    { mat: "tableD", rot: [0, 90, 0], pos: [x, 0, 0], jitter: 0.004 })))
// soup tub (1855): a wide wooden tub full of green soup, an iron band low
// round it, a ladle standing in it and a white cloth over its -x rim
model("soup_tub",
  lathe([0.34, 0, 0.4, 0.5, 0.42, 0.56, 0.37, 0.56, 0.35, 0.08], { mat: "table", sides: 14 }),
  torus(0.385, 0.022, { mat: "steelD", rings: 18, sides: 4, pos: [0, 0.13, 0] }),
  cyl(0.37, 0.02, { mat: "soup", sides: 14, pos: [0, 0.46, 0] }),
  [[0.1, 0.08, 0.06], [-0.12, -0.1, 0.05], [0.0, -0.18, 0.04], [0.18, -0.08, 0.035]].map(([x, z, r]) => cyl(r, 0.022, { mat: "soupL", sides: 7, pos: [x, 0.465, z] })),
  tf({ pos: [0.12, 0.45, -0.1], rot: [20, 0, -18] }, cyl(0.035, 0.85, { mat: "table", sides: 6 }), sphere(0.07, { mat: "tableD", detail: 1, pos: [0, -0.02, 0], scale: [1, 0.5, 1] })),
  // the cloth over the rim
  box(0.16, 0.02, 0.26, { mat: "towel", pos: [-0.39, 0.56, 0.0], jitter: 0.008 }),
  box(0.02, 0.24, 0.26, { mat: "towel", pos: [-0.47, 0.34, 0.0], rot: [0, 0, -6], jitter: 0.008 }))
for (const n of ["barrel_tap", "soup_tub"]) looms(n)


// --- tools (1636, 2102, 2580) -----------------------------------------------------
// mallet (1636): a big pale wooden mallet lying on the floor, its square
// head down, the handle along +x resting on the floor
model("mallet", { scale: 1.3 },
  box(0.2, 0.18, 0.18, { mat: "mallet", pos: [-0.2, 0, 0], jitter: 0.01, seed: 601 }),
  tf({ pos: [-0.12, 0.09, 0], rot: [0, 0, -4] }, cyl(0.035, 0.4, { mat: "handle", sides: 6, rot: [0, 0, -90] })))
// smith's tongs (2102): long tongs standing on their round jaws, the two
// arms opening up in a V, green with rust (verdigris iron)
model("tongs", { scale: 0.95 },
  torus(0.13, 0.045, { mat: "tong", rings: 14, sides: 5, rot: [90, 0, 0], pos: [0, 0.17, 0] }),
  [[0.03, 0.03], [0.07, 0.04], [-0.06, 0.08], [0.0, 0.19], [-0.1, 0.18]].map(([x, z], i) => sphere(0.03, { mat: "rust", detail: 0, pos: [x * 1.2, 0.08 + z * 0.6, 0.03], scale: [1, 1, 0.4] })),
  [-1, 1].map((k) => tf({ pos: [k * 0.04, 0.28, 0], rot: [0, 0, -k * 14] },
    cyl(0.045, 0.8, { mat: "tong", sides: 6, top: 0.035 }), sphere(0.04, { mat: "tongL", detail: 1, pos: [0, 0.82, 0], scale: [1, 1.6, 1] }),
    sphere(0.03, { mat: "rust", detail: 0, pos: [0, 0.3 + k * 0.1, 0.02], scale: [1, 1.6, 0.5] }))),
  cyl(0.04, 0.05, { mat: "tongL", sides: 6, rot: [90, 0, 0], pos: [0, 0.25, -0.025] }))
// hammer and spanner (2580): a small hammer and a spanner lying crossed
model("hammer_spanner", { scale: 1.6 },
  tf({ rot: [0, 25, 0] }, box(0.14, 0.06, 0.07, { mat: "steel", pos: [-0.12, 0.0, 0] }),
    cyl(0.022, 0.3, { mat: "handle", sides: 6, rot: [0, 0, -90], pos: [-0.08, 0.03, 0] })),
  tf({ pos: [0.02, 0.0, -0.02], rot: [0, -60, 0] },
    box(0.32, 0.018, 0.04, { mat: "steel", pos: [0, 0.0, 0] }),
    [-1, 1].map((e) => tf({ pos: [e * 0.17, 0, 0] }, cyl(0.045, 0.02, { mat: "steel", sides: 8 }),
      box(0.05, 0.022, 0.035, { mat: "steelD", pos: [e * 0.03, 0.0, 0] })))))
for (const n of ["mallet", "tongs", "hammer_spanner"]) looms(n)

// --- plates and food (2525, 2531, 2581, 2363) --------------------------------------
// a round plate: a shallow dish with a raised rim
const plate = (r, mat = "plate") => [
  lathe([r * 0.7, 0, r, 0.03, r * 0.98, 0.045, r * 0.82, 0.02, 0.0, 0.02], { mat, sides: 14 }),
  torus(r * 0.97, 0.012, { mat: mat === "plate" ? "plateD" : mat, rings: 16, sides: 4, pos: [0, 0.04, 0] })]
// plate with a bone (2525): a pottery plate with red sauce, the ribs of a
// roast arching over it, a fork stuck upright in it, a bone dropped beside
model("plate_bones", { scale: 1.3 },
  plate(0.26),
  cyl(0.19, 0.008, { mat: "meat", sides: 12, pos: [0, 0.02, 0], scale: [1, 1, 0.9], jitter: 0.01 }),
  spine(-0.14, 0.14, 0.05, 0.03),
  [-0.12, -0.04, 0.04, 0.12].flatMap((x) => [-1, 1].map((k) => rib(x, 0.05, 0, 0.3, 0.02, 30, 34, -90 * k, 3))),
  tf({ pos: [0.03, 0.06, -0.02], rot: [8, 0, -6] }, cyl(0.008, 0.18, { mat: "steel", sides: 4 }),
    [-1, 0, 1].map((k) => box(0.005, 0.06, 0.005, { mat: "steel", pos: [k * 0.012, 0.17, 0] })),
    cyl(0.014, 0.12, { mat: "handle", sides: 6, pos: [0, 0.2, 0] })),
  knuckleBone(-0.3, 0.015, 0.12, 0.14, 0.012, 30))
// plate of leftovers (2531): a wooden dish with lettuce, mash and carrot bits
model("plate_leftovers", { scale: 1.5 },
  plate(0.22, "dish"),
  [0, 1, 2, 3, 4, 5, 6, 7].map((i) => {
    const a = i * 45 + 10
    return box(0.12, 0.012, 0.07, { mat: i % 2 ? "lettuce" : "lettuceD", pos: [Math.cos(a * Math.PI / 180) * 0.15, 0.04 + (i % 3) * 0.008, Math.sin(a * Math.PI / 180) * 0.15], rot: [0, -a, (i % 2 ? 15 : -10)], jitter: 0.01, seed: 611 + i })
  }),
  sphere(0.11, { mat: "mash", detail: 1, pos: [0, 0.04, 0], scale: [1, 0.35, 0.85], jitter: 0.01, seed: 619 }),
  [[0.04, 0.02], [-0.05, 0.04], [0.0, -0.05]].map(([x, z]) => box(0.03, 0.02, 0.02, { mat: "carrot", pos: [x, 0.07, z] })))
// liquor and a little plate (2581): a gourd-shaped bottle of dark liquor, a
// little cup and a small plate with scraps
model("liquor_plate", { scale: 1.6 },
  lathe([0.07, 0, 0.1, 0.06, 0.09, 0.14, 0.05, 0.19, 0.06, 0.25, 0.03, 0.3, 0.025, 0.36], { mat: "glass", sides: 10, pos: [-0.04, 0, -0.06] }),
  cyl(0.025, 0.03, { mat: "handle", sides: 6, pos: [-0.04, 0.36, -0.06] }),
  lathe([0.025, 0, 0.04, 0.05, 0.035, 0.06], { mat: "cup", sides: 8, pos: [0.15, 0, -0.02] }),
  tf({ pos: [0.04, 0, 0.13] }, plate(0.12, "dish"), steak(0, 0.03, 0, 0.35, 20)))
// steak on lettuce (2363): a wooden platter heaped with lettuce, a big
// T-bone steak on top, a knife stuck upright in it
model("steak_platter", { scale: 1.3 },
  plate(0.3, "dish"),
  Array.from({ length: 12 }, (_, i) => {
    const a = i * 30 + 7, d = 0.12 + (i % 3) * 0.05
    return box(0.18, 0.02, 0.11, { mat: i % 2 ? "lettuce" : "lettuceD", pos: [Math.cos(a * Math.PI / 180) * d, 0.04 + (i % 4) * 0.01, Math.sin(a * Math.PI / 180) * d], rot: [0, -a, (i % 2 ? 20 : -15)], jitter: 0.012, seed: 621 + i })
  }),
  steak(0.02, 0.08, 0.02, 0.85, 25),
  cyl(0.03, 0.03, { mat: "bone", sides: 8, pos: [0.12, 0.09, -0.05] }),
  tf({ pos: [-0.04, 0.1, 0.02], rot: [0, 30, 6] }, box(0.008, 0.14, 0.035, { mat: "steel", pos: [0, -0.04, 0] }), box(0.016, 0.1, 0.03, { mat: "handle", pos: [0, 0.1, 0] })))
for (const n of ["plate_bones", "plate_leftovers", "liquor_plate", "steak_platter"]) looms(n)

// --- dead rats (1634, 2762) -----------------------------------------------------------
// skinned rat (1634): a small skinned rat curled up in a lumpy pink heap,
// blood spattered round it (the owner's "little dead rat with blood")
model("rat_skinned", { scale: 1.7 },
  Array.from({ length: 9 }, (_, i) => sphere(0.06 + (i % 3) * 0.012, { mat: i % 2 ? "flesh" : "fleshD", detail: 1,
    pos: [Math.cos(i * 0.9) * 0.08, 0.05 + (i % 2) * 0.02, Math.sin(i * 0.9) * 0.06], jitter: 0.008, seed: 631 + i })),
  tube([0.12, 0.02, 0.02, 0.2, 0.01, 0.06, 0.24, 0.01, 0.0], 0.01, { mat: "pink", sides: 4 }),
  [[0.16, -0.05, 0.04], [-0.15, 0.07, 0.035], [0.0, 0.14, 0.03], [-0.17, -0.07, 0.025]].map(([x, z, r]) =>
    cyl(r, 0.004, { mat: "bloodLit", sides: 7, pos: [x, 0, z], scale: [1.6, 1, 0.6], rot: [0, x * 200, 0] })))
// dead rat (2762): a fat rat on its side, paws up, crosses for eyes, its
// long pink tail out behind (along -x... it faces +x)
model("rat_dead", { scale: 1.3 },
  sphere(0.13, { mat: "fur", detail: 2, pos: [0, 0.1, 0], scale: [1.4, 0.8, 0.9] }),
  sphere(0.08, { mat: "fur", detail: 1, pos: [0.19, 0.08, 0], scale: [1.3, 0.85, 0.9] }),
  cone(0.03, 0.06, { mat: "pink", sides: 5, rot: [0, 0, -90], pos: [0.28, 0.07, 0] }),
  [-1, 1].map((k) => cyl(0.035, 0.012, { mat: "pink", sides: 7, rot: [90, 0, 0], pos: [0.17, 0.15, k * 0.05] })),
  [-1, 1].map((k) => [box(0.03, 0.006, 0.006, { mat: "eye", pos: [0.24, 0.12, k * 0.04], rot: [0, 0, 45] }), box(0.03, 0.006, 0.006, { mat: "eye", pos: [0.24, 0.12, k * 0.04], rot: [0, 0, -45] })]),
  [[0.08, 1], [-0.08, 1], [0.08, -1], [-0.08, -1]].map(([x, k]) => cyl(0.015, 0.08, { mat: "pink", sides: 4, pos: [x, 0.16, k * 0.05], rot: [k * 30, 0, 0] })),
  sphere(0.06, { mat: "furD", detail: 1, pos: [-0.04, 0.05, 0.1], scale: [1.5, 0.5, 0.4] }),
  tube([-0.17, 0.06, 0, -0.32, 0.02, 0.06, -0.45, 0.01, 0.02, -0.55, 0.01, 0.08], 0.012, { mat: "pink", sides: 4 }))
for (const n of ["rat_skinned", "rat_dead"]) looms(n)

// --- underwear (1719) -------------------------------------------------------------------
// a pair of white knickers dropped on the floor
model("knickers", { scale: 1.5 },
  extrude([-0.12, 0.08, 0.12, 0.08, 0.1, 0.0, 0.03, -0.08, -0.03, -0.08, -0.1, 0.0], 0.02, { mat: "towel", rot: [90, 0, 0], pos: [0, 0.01, 0], jitter: 0.004 }),
  box(0.25, 0.02, 0.025, { mat: "towel", pos: [0, 0.012, -0.08] }))
looms("knickers")


// --- butcher's block (2476) ------------------------------------------------------------
// a squat wooden block filling the cell, about 0.55 m, its top sheathed in a
// stained metal sheet with rounded edges; on top a chunk of meat bristling
// with bone spurs, a red-handled cleaver and two hooks; blood run down the
// +z face
model("butcher_block",
  timber(-0.47, 0.47, -0.47, 0.47, 0, 0.48, "postDV", 701, 0.08),
  prismUp(roundSquare(0.49, 0.1), 0.06, 0.46, "sheet", 0.004),
  sphere(0.22, { mat: "meat", detail: 1, pos: [-0.08, 0.52, -0.05], scale: [1.5, 0.35, 0.8], jitter: 0.01 }),
  [-0.3, -0.18, -0.05, 0.08, 0.2].map((x, i) => cone(0.05, 0.16 + (i % 2) * 0.05, { mat: "bone", sides: 5, pos: [x, 0.54, -0.08 + (i % 2) * 0.08], rot: [0, 0, -10 + i * 4] })),
  tf({ pos: [0.12, 0.525, 0.05], rot: [0, 35, 0] }, box(0.24, 0.012, 0.16, { mat: "steel", pos: [-0.05, 0, 0] }),
    box(0.3, 0.035, 0.04, { mat: "comb", pos: [0.22, 0, 0] })),
  [[-0.32, 0.25], [0.25, 0.28]].map(([x, z]) => torus(0.035, 0.009, { mat: "steelD", rings: 8, sides: 4, pos: [x, 0.525, z] })),
  [-0.25, -0.12, 0.1].map((x, i) => box(0.035 - i * 0.006, 0.35 - i * 0.1, 0.008, { mat: "bloodLit", pos: [x, 0.5 - (0.35 - i * 0.1), 0.475] })))
looms("butcher_block")

// --- grill (2539) ------------------------------------------------------------------------
// a low frame of pale boards on four legs, dark coals glowing inside, a
// wire grill laid over it, its round wooden handle out at +x
model("grill",
  [[-1, -1], [1, -1], [-1, 1], [1, 1]].map(([sx, sz]) => box(0.1, 0.24, 0.1, { mat: "boxV", pos: [sx * 0.38, 0, sz * 0.38], jitter: 0.004 })),
  [0, 90, 180, 270].map((r) => tf({ rot: [0, r, 0] }, box(0.9, 0.12, 0.06, { mat: "box", pos: [0, 0.26, 0.42], jitter: 0.004 }))),
  box(0.8, 0.04, 0.8, { mat: "coal", pos: [0, 0.27, 0] }),
  [[-0.2, -0.1], [0.15, 0.2], [0.05, -0.2], [-0.15, 0.22], [0.25, -0.05]].map(([x, z], i) => sphere(0.05, { mat: i % 2 ? "ember" : "coal", detail: 0, pos: [x, 0.31, z], scale: [1.4, 0.5, 1] })),
  // the wire grill: a frame and bars along x
  tube([-0.38, 0.39, -0.38, 0.38, 0.39, -0.38, 0.38, 0.39, 0.38, -0.38, 0.39, 0.38], 0.012, { mat: "steel", sides: 4, closed: true }),
  [-0.28, -0.14, 0, 0.14, 0.28].map((z) => cyl(0.008, 0.76, { mat: "steel", sides: 4, rot: [0, 0, -90], pos: [-0.38, 0.39, z] })),
  cyl(0.012, 0.16, { mat: "steel", sides: 4, rot: [0, 0, -90], pos: [0.38, 0.39, 0.1] }),
  sphere(0.07, { mat: "mallet", detail: 1, pos: [0.6, 0.39, 0.1], scale: [1.4, 0.8, 0.8] }))
looms("grill")

// --- hearth (2540) -----------------------------------------------------------------------
// a primitive hearth: a round stone bowl of ash with glowing embers between
// two upright bones, a spit across them along x carrying the skeleton of an
// animal (its ribs hanging down), a wooden crank at the +x end
model("spit_hearth",
  lathe([0.24, 0, 0.32, 0.1, 0.33, 0.16, 0.29, 0.16, 0.27, 0.08], { mat: "post", sides: 12, pos: [0, 0, 0] }),
  cyl(0.28, 0.02, { mat: "ash", sides: 12, pos: [0, 0.1, 0] }),
  [[-0.1, 0.05], [0.12, -0.08], [0.0, 0.14], [0.08, 0.1]].map(([x, z]) => sphere(0.04, { mat: "ember", detail: 0, pos: [x, 0.12, z], scale: [1.3, 0.5, 1] })),
  [-1, 1].map((k) => tf({ pos: [k * 0.42, 0, 0], rot: [0, 0, k * 6] }, cyl(0.09, 0.82, { mat: "bone", sides: 6, top: 0.065 }),
    sphere(0.08, { mat: "bone", detail: 1, pos: [0, 0.84, 0], scale: [1, 0.8, 1.3] }))),
  cyl(0.02, 1.15, { mat: "steel", sides: 5, rot: [0, 0, -90], pos: [-0.55, 0.8, 0] }),
  spine(-0.3, 0.3, 0.8, 0.05),
  [-0.24, -0.08, 0.08, 0.24].flatMap((x, i) => [-1, 1].map((k) => rib(x, 0.8, 0, 0.42, 0.04, 150, -18, -90 * k, 3))),
  tf({ pos: [0.6, 0.8, 0] }, box(0.04, 0.18, 0.05, { mat: "table", pos: [0, -0.16, 0] }), cyl(0.03, 0.14, { mat: "table", sides: 6, rot: [0, 0, -90], pos: [0, -0.14, 0] })))
looms("spit_hearth")

// --- aprons (2749) -----------------------------------------------------------------------
// two aprons hung on a wall from one peg (the wall is the plane x = 0, facing
// +x, like arena 9's whip; y = 0 is the floor): a blue one in front, a brown
// one behind, their bibs, waists and long skirts
const apron = (z, y0, mat, tilt) => tf({ pos: [0.04, y0, z], rot: [tilt, 0, 0] },
  extrude([-0.1, 0, 0.1, 0, 0.13, -0.18, 0.2, -0.24, 0.22, -0.9, -0.22, -0.9, -0.2, -0.24, -0.13, -0.18], 0.025,
    { mat, rot: [0, 90, 0], jitter: 0.006, seed: z * 100 }),
  box(0.015, 0.05, 0.44, { mat, pos: [0.01, -0.26, 0] }),
  tube([0.0, 0.0, -0.08, 0.0, 0.12, 0.0, 0.0, 0.0, 0.08], 0.008, { mat, sides: 4 }))
model("aprons", { pivot: "origin" },
  cyl(0.025, 0.12, { mat: "table", sides: 6, rot: [0, 0, -90], pos: [0, 1.35, 0] }),
  apron(0.1, 1.24, "apronBrown", -6),
  tf({ pos: [0.03, 0, 0] }, apron(-0.12, 1.22, "apronBlue", 5)))
looms("aprons")

// --- squashed squirrel (2754) --------------------------------------------------------------
// a squirrel flattened like a rug: a splayed orange pelt, four paws, the
// big curled tail at the back, its head turned up with crosses for eyes
model("squirrel_rug", { scale: 1.5 },
  extrude([-0.2, 0, -0.1, 0.12, 0.08, 0.1, 0.2, 0.18, 0.24, 0.06, 0.16, -0.04, 0.22, -0.16, 0.06, -0.1, -0.08, -0.18, -0.18, -0.12], 0.025,
    { mat: "pelt", rot: [90, 0, 0], pos: [0, 0.012, 0], jitter: 0.006 }),
  sphere(0.08, { mat: "peltL", detail: 1, pos: [-0.2, 0.04, 0.02], scale: [1, 0.5, 1] }),
  [-1, 1].map((k) => [box(0.025, 0.004, 0.006, { mat: "eye", pos: [-0.22, 0.08, k * 0.03], rot: [0, 45, 0] }), box(0.025, 0.004, 0.006, { mat: "eye", pos: [-0.22, 0.08, k * 0.03], rot: [0, -45, 0] })]),
  torus(0.09, 0.035, { mat: "pelt", rings: 14, sides: 5, pos: [0.24, 0.035, -0.05], scale: [1, 0.5, 1] }),
  sphere(0.05, { mat: "peltL", detail: 1, pos: [0.24, 0.04, -0.05], scale: [1, 0.5, 1] }))
looms("squirrel_rug")

// --- stone hand (2756) ----------------------------------------------------------------------
// a pale stone forearm and hand lying along x, fingers spread at +x, mossy
// patches
model("stone_hand",
  cyl(0.06, 0.5, { mat: "stone", sides: 7, top: 0.05, rot: [0, 0, -90], pos: [-0.35, 0.055, 0], jitter: 0.006 }),
  box(0.12, 0.06, 0.13, { mat: "stone", pos: [0.2, 0.025, 0], jitter: 0.008 }),
  [-0.045, -0.015, 0.015, 0.045].map((z, i) => cyl(0.016, 0.1 + (i % 2) * 0.02, { mat: "stone", sides: 5, rot: [0, -z * 300, -90], pos: [0.26, 0.04, z] })),
  cyl(0.016, 0.08, { mat: "stone", sides: 5, rot: [0, 50, -90], pos: [0.2, 0.04, 0.06] }),
  [[-0.25, 0.04], [0.0, -0.03]].map(([x, z]) => sphere(0.035, { mat: "stoneD", detail: 0, pos: [x, 0.1, z], scale: [1.5, 0.3, 1] })))
looms("stone_hand")

// --- jar (2761) -----------------------------------------------------------------------------
// a glass jar of pale pickled lumps, its lid tied with red string
model("pickle_jar", { scale: 1.1 },
  lathe([0.1, 0, 0.12, 0.04, 0.12, 0.24, 0.09, 0.28, 0.09, 0.3], { mat: "jar", sides: 10 }),
  [[-0.04, 0.08, 0.06], [0.05, 0.12, 0.05], [0.0, 0.18, 0.05]].map(([x, y, r]) => sphere(r, { mat: "pickle", detail: 1, pos: [x, y, 0.08], scale: [1, 1, 0.5] })),
  cyl(0.1, 0.03, { mat: "string", sides: 10, pos: [0, 0.29, 0] }),
  tube([0.09, 0.3, 0.0, 0.14, 0.22, 0.02, 0.15, 0.14, 0.0], 0.006, { mat: "string", sides: 4 }))
looms("pickle_jar")

// --- headless woman in a rocking chair (2763) ---------------------------------------------
// the owner's "headless person sitting on a wooden chair": a stout woman in
// a blue dress and a white apron with an embroidered heart, pale arms on
// the armrests, pink slippers, her knitting yarn rolled off on the floor;
// a red stump where the head was. Faces +x.
const SEAT = 0.5
model("headless_knitter",
  // the rocking chair
  [-1, 1].map((k) => tube([-0.5, 0.1, k * 0.3, -0.2, 0.0, k * 0.3, 0.3, 0.0, k * 0.3, 0.55, 0.12, k * 0.3], 0.03, { mat: "post", sides: 5 })),
  [[-0.3, 0.3], [0.3, 0.3], [-0.3, -0.3], [0.3, -0.3]].map(([x, z]) => cyl(0.035, SEAT, { mat: "postV", sides: 6, pos: [x, 0.0, z] })),
  box(0.68, 0.06, 0.66, { mat: "post", pos: [0, SEAT, 0] }),
  [-1, 1].map((k) => [cyl(0.035, 0.85, { mat: "postV", sides: 6, pos: [-0.32, SEAT, k * 0.28], rot: [0, 0, 10] }),
    box(0.55, 0.05, 0.08, { mat: "post", pos: [0.0, SEAT + 0.3, k * 0.32] })]),
  [0.2, 0.45, 0.7].map((y) => box(0.04, 0.08, 0.56, { mat: "post", pos: [-0.32 - y * 0.18, SEAT + y, 0], rot: [0, 0, 10] })),
  // the body: a broad blue dress, the white apron, the stump
  sphere(0.3, { mat: "dress", detail: 2, pos: [0.0, SEAT + 0.32, 0], scale: [0.95, 1.25, 1.15] }),
  sphere(0.36, { mat: "dressD", detail: 2, pos: [0.12, SEAT + 0.08, 0], scale: [1.1, 0.45, 1.05] }),
  box(0.03, 0.42, 0.4, { mat: "towel", pos: [0.33, SEAT, 0], rot: [0, 0, 12], jitter: 0.01 }),
  box(0.012, 0.12, 0.16, { mat: "stitch", pos: [0.35, SEAT + 0.15, 0], rot: [0, 0, 12] }),
  box(0.012, 0.07, 0.08, { mat: "heart", pos: [0.357, SEAT + 0.17, 0], rot: [0, 0, 12] }),
  cyl(0.1, 0.05, { mat: "pale", sides: 8, pos: [-0.02, SEAT + 0.66, 0] }),
  cyl(0.085, 0.02, { mat: "meat", sides: 8, pos: [-0.02, SEAT + 0.7, 0] }),
  // arms on the armrests, legs down to the slippers
  [-1, 1].map((k) => [sphere(0.11, { mat: "pale", detail: 1, pos: [0.0, SEAT + 0.48, k * 0.33], scale: [1, 1.5, 0.9] }),
    cyl(0.07, 0.36, { mat: "pale", sides: 7, rot: [0, 0, -80], pos: [-0.02, SEAT + 0.36, k * 0.33] }),
    cyl(0.09, SEAT - 0.02, { mat: "pale", sides: 7, top: 0.07, pos: [0.36, 0.06, k * 0.16], rot: [0, 0, 8] }),
    sphere(0.08, { mat: "slipper", detail: 1, pos: [0.42, 0.05, k * 0.17], scale: [1.6, 0.6, 1] })]),
  // the yarn ball and its thread
  sphere(0.07, { mat: "yarn", detail: 1, pos: [0.72, 0.07, -0.35] }),
  tube([0.3, SEAT + 0.15, 0.1, 0.5, 0.2, 0.0, 0.6, 0.02, -0.25, 0.72, 0.07, -0.35], 0.006, { mat: "yarn", sides: 4 }))
looms("headless_knitter")

// --- bloody skull (2764) --------------------------------------------------------------------
// a yellowed skull lying in a pool of blood, its face to +x
model("skull_blood", { scale: 1.6 },
  cyl(0.2, 0.004, { mat: "bloodLit", sides: 10, pos: [0.04, 0, 0], scale: [1.3, 1, 0.9], jitter: 0.02 }),
  sphere(0.13, { mat: "skull", detail: 2, pos: [0, 0.13, 0], scale: [1.1, 0.95, 0.95] }),
  box(0.1, 0.07, 0.15, { mat: "skull", pos: [0.08, 0.02, 0], jitter: 0.008 }),
  [-1, 1].map((k) => sphere(0.035, { mat: "coal", detail: 1, pos: [0.13, 0.13, k * 0.05], scale: [0.5, 1, 1] })),
  sphere(0.06, { mat: "meatD", detail: 1, pos: [0.0, 0.2, -0.08], scale: [1, 0.6, 0.6] }))
looms("skull_blood")
