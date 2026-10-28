// Arena 7 (retail world 38: a graveyard) — the pieces it doesn't share with
// the other kits, each in three looms: <name> (a), <name>_b, <name>_c. The
// stone surfaces reuse the arena 6 and arena 5 loom textures (build their
// kit.tx.js first); iron and bone use palette colours. Retail gfx in
// brackets.
include("../common/shapes.kx.js")

const LOOMS = ["", "_b", "_c"]
pal(Object.fromEntries(LOOMS.flatMap((s) => [
  ["stone" + s, { tex: "../arena6/out/stone" + s, uv: 0.9, rough: 0.85 }],
  ["stoneShade" + s, { tex: "../arena6/out/stone" + s, uv: 0.9, rough: 0.85, color: "#e4e0d2" }],
  ["flagCrack" + s, { tex: "../arena6/out/flagCrack" + s, uv: 1, rough: 0.8 }],
  // the stone slab (1482, 1645): the plaster stone of the arena 5 house, worn
  // to a duller sand; its sides darker, its foot greyed by damp
  ["plaster" + s, { tex: "../arena5/out/plaster" + s, uv: 0.7, rough: 0.9, color: "#c8c4ae" }],
  ["plasterSide" + s, { tex: "../arena5/out/plaster" + s, uv: 0.7, rough: 0.92, color: "#aea486" }],
  ["plasterFoot" + s, { tex: "../arena5/out/plaster" + s, uv: 1.6, rough: 0.95, color: "#8a8a72" }],
  // tombstones: the arena 6 mossy stone; the recessed panels a red-brown
  // stone; planks in the arena 6 board wood (upright grain: boardV), the
  // wooden headstone (2500) stained olive
  ["stoneMoss" + s, { tex: "../arena6/out/stoneMoss" + s, uv: 0.9, rough: 0.9 }],
  ["panel" + s, { tex: "../arena6/out/stone" + s, uv: 0.9, rough: 0.85, color: "#c49c86" }],
  ["board" + s, { tex: "../arena6/out/board" + s, uv: 0.8, rough: 0.8 }],
  ["boardV" + s, { tex: "../arena6/out/boardV" + s, uv: 0.8, rough: 0.8 }],
  ["boardOlive" + s, { tex: "../arena6/out/boardV" + s, uv: 0.8, rough: 0.8, color: "#c8d094" }],
  // the earth slabs (kit.tx.js): every other plate a shade darker, the lip
  // and the hanging clods darker still
  ["dirt" + s, { tex: "out/dirt" + s, uv: 1, rough: 0.9 }],
  ["dirtShade" + s, { tex: "out/dirt" + s, uv: 1, rough: 0.9, color: "#e2d8c6" }],
  ["dirtD" + s, { tex: "out/dirt" + s, uv: 1, rough: 0.95, color: "#84765f" }],
])))
// palette looms: [a, b, c] per key
const PAL = {
  // wrought iron of the railings: grey (retail, which the map tints
  // blue-black), rusty, verdigris
  // grey dead leaves and dust flakes on the floor: grey-brown (retail), ash
  // grey, rusty brown
  flake: ["#5e544e", "#7a7874", "#7a5238"], flakeD: ["#3e3632", "#55534f", "#55361f"], flakeL: ["#6e645c", "#8c8a86", "#8a6042"],
  // bone (the skull reliefs; later the bones): ivory, grey-white, yellowed
  bone: ["#e6dcc0", "#d8d8d2", "#e4cf98"], boneD: ["#a89c80", "#9a9a94", "#a89060"],
  // eye sockets, carved lines, the dark of a niche
  hole: ["#2e2a24", "#2a2a2c", "#2e221c"],
  // grass tufts at the foot of the stones
  bladeD: ["#5a7414", "#2e5a1e", "#6a6418"], blade: ["#94b024", "#4e8a2c", "#a29a2a"], bladeL: ["#c4d83c", "#7ab446", "#ccc04a"],
  // the dead plant (1706): grey-purple (retail), dry grey-brown, near black
  deadD: ["#2c2430", "#4a4238", "#262224"], dead: ["#433846", "#6a5e4e", "#3a3436"], deadL: ["#584c5e", "#867a66", "#4e4648"],
  // poppies (520, 521, and among 522): red (retail), white, orange; black
  // hearts; thin olive stems and leaves
  poppyD: ["#a8201a", "#c8c4b8", "#c85a14"], poppy: ["#dc3a24", "#ecebe4", "#f07e1e"], poppyL: ["#f2603e", "#ffffff", "#ffa040"],
  poppyC: ["#2a1e1a", "#3a3a2a", "#2a1e1a"],
  stalkD: ["#4a5a14", "#3e5a1c", "#5a5a18"], stalk: ["#86a024", "#5a8a2c", "#9a9428"], stalkL: ["#c0cc3c", "#8ab44a", "#c8c04a"],
  // daisies among the 522 poppies: white petals, yellow hearts
  daisy: ["#f4f2ea", "#f4e8a8", "#f0c8d8"], daisyC: ["#f0c030", "#e8a020", "#f0d050"],
  // the candle in the niche (1503): wax, and its flame (glows)
  wax: ["#f0e2a0", "#ecebe2", "#e8c88a"],
  iron: ["#5c6068", "#5e3c2a", "#36463e"], ironL: ["#868b94", "#84553a", "#557064"], ironD: ["#33363c", "#3a2418", "#1f2a24"],
}
pal(Object.fromEntries(LOOMS.flatMap((s, i) => Object.entries(PAL).map(([k, v]) => [k + s, v[i]]))))
// the candle flame glows the same in every loom
pal({ flame: { color: "#ffd24a", emit: "#ffb830", glow: 4 } })
const SKINNED = ["stone", "stoneShade", "flagCrack", "plaster", "plasterSide", "plasterFoot", "stoneMoss", "panel", "board", "boardV", "boardOlive", "dirt", "dirtShade", "dirtD", ...Object.keys(PAL)]
const looms = (name) => threeLooms(name, SKINNED)

// a repeatable pseudo-random number in 0..1 for (i, k, seed)
const rnd = (i, k, seed) => ((Math.sin((i + 1) * 12.9898 * k + seed * 78.233) * 43758.5453) % 1 + 1) % 1
// rounded rectangle outline (XY, for prismUp), w × d, corner radius r
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
// one dressed stone, every edge rounded (as in the arena 6 kit). Origin at
// its base centre; rot is a small turn about y
function stone(x, y, z, w, h, d, { rot = 0, mat = "stone", seed = 1, tilt = 0, round = 0.26 } = {}) {
  const r = Math.min(w, h, d) * round, j = 0.004
  return tf({ pos: [x, y, z], rot: [tilt, rot, tilt * 0.6] },
    extrude(rrect(w, h, r), d - 2 * r, { mat, pos: [0, h / 2, 0], jitter: j, seed }),
    extrude(rrect(d, h - 0.004, r), w - 2 * r, { mat, rot: [0, 90, 0], pos: [0, h / 2, 0], jitter: j, seed: seed + 1 }),
    prismUp(rrect(w - 0.003, d - 0.003, r), h - 2 * r, r, mat, j))
}

// --- wall top (1417) ----------------------------------------------------------
// the top of the graveyard wall, stacked on a block: two courses of
// ashlars, three to a face, joints staggered, every other stone a shade
// darker, under a thick cracked coping in two slabs, ridged along x (the ^
// seen on the +x face) and overhanging all round
const COURSE = 0.26
function course(y, seed, cuts) {
  // a ring of stones round a rubble core: along the +z and -z faces cut at
  // cuts (x), and along the +x and -x faces cut at -cuts (z)
  const run = (cs) => [-0.46, ...cs, 0.46].slice(1).map((b, i, a) => [i ? a[i - 1] : -0.46, b])
  const out = []
  for (const [face, sgn] of [["z", 1], ["z", -1], ["x", 1], ["x", -1]])
    run(face === "z" ? cuts : cuts.map((c) => -c).sort((p, q) => p - q)).forEach(([a, b], i) => {
      const len = b - a - 0.012, m = (i + seed + (face === "x" ? 1 : 0)) % 2 ? "stone" : "stoneShade", sd = seed + i + (face === "x" ? 7 : 0) + (sgn > 0 ? 0 : 13)
      const t = (rnd(i, 121, sd) - 0.5) * 2
      out.push(face === "z"
        ? stone((a + b) / 2, y, sgn * 0.33, len, COURSE - 0.01, 0.26, { seed: sd, mat: m, rot: t })
        : stone(sgn * 0.33, y, (a + b) / 2, 0.26, COURSE - 0.01, len, { seed: sd, mat: m, rot: t }))
    })
  out.push(box(0.5, COURSE - 0.02, 0.5, { mat: "stoneShade", pos: [0, y, 0] }))
  return out
}
// a coping slab: a pentagon (flat sides, a low ridge) extruded along x
const copingSlab = (x, len, seed) => tf({ pos: [x, 0, 0], rot: [0, 90, 0] },
  extrude([-0.5, 0, 0.5, 0, 0.5, 0.17, 0, 0.29, -0.5, 0.17], len, { mat: "flagCrack", jitter: 0.008, seed }))
model("wall_top",
  course(0, 131, [-0.17, 0.2]), course(COURSE, 133, [-0.02, 0.3]),
  tf({ pos: [0, 2 * COURSE - 0.01, 0] },
    copingSlab(-0.26, 0.53, 141), tf({ pos: [0, -0.012, 0], rot: [1.5, 0, -2] }, copingSlab(0.27, 0.52, 143))))

// --- iron railing (1445) -----------------------------------------------------
// three wrought-iron spikes in a row along x with one cross bar, a little
// crooked; stands on whatever it is placed on (the wall tops, or round the
// graves). A spike: a thin square bar with a sharp tip, its foot splayed
const spike = (x, h, lean, seed) => tf({ pos: [x, 0, 0], rot: [lean * 0.4, 0, lean] },
  cyl(0.034, h * 0.8, { mat: "iron", sides: 4, rot: [0, 45, 0], top: 0.026 }),
  cone(0.027, h * 0.22, { mat: "ironL", sides: 4, rot: [0, 45, 0], pos: [0, h * 0.8 - 0.005, 0] }),
  cone(0.06, 0.07, { mat: "ironD", sides: 4, rot: [0, 45, 0] }))
model("iron_railing",
  [[-0.3, 1.32, -2.5], [0.0, 1.16, 1.5], [0.3, 1.38, 3]].map(([x, h, l], i) => spike(x, h, l, 151 + i)),
  tf({ pos: [0.02, 0.42, 0.045], rot: [0, 0, -12] }, box(0.98, 0.05, 0.04, { mat: "iron", jitter: 0.004 })))
for (const n of ["wall_top", "iron_railing"]) looms(n)

// --- earth slab (263, 266, 267, 268, 1526, 1527, 1532, 1533) ------------------
// the floor of the graveyard; the owner: "like the grass cap, but earth". It
// lies on another block's top (y = 0): packed earth split by cracks into four
// plates (their edges broken so the cracks wander), each domed in four steps
// so it reads like a cushion, every other one a shade darker and a little
// tilted; under them a dark wavy lip and clods of earth hanging over the
// block's four sides. The eight retail drawings only move
// the cracks: one model
const PLATES = [
  [[-0.47, -0.47], [0.06, -0.47], [0.03, -0.2], [-0.47, -0.12]],
  [[-0.47, -0.12], [0.03, -0.2], [0.0, 0.02], [-0.01, 0.22], [-0.04, 0.47], [-0.47, 0.47]],
  [[0.06, -0.47], [0.47, -0.47], [0.47, 0.18], [-0.01, 0.22], [0.0, 0.02], [0.03, -0.2]],
  [[-0.01, 0.22], [0.47, 0.18], [0.47, 0.47], [-0.04, 0.47]],
]
// pull every corner of a plate towards its centre by d (the crack between
// plates is twice that)
const shrink = (poly, d) => {
  const cx = poly.reduce((a, p) => a + p[0], 0) / poly.length, cz = poly.reduce((a, p) => a + p[1], 0) / poly.length
  return poly.flatMap(([x, z]) => { const l = Math.hypot(x - cx, z - cz); return [x - (x - cx) / l * d, z - (z - cz) / l * d] })
}
// break each edge of a plate at its middle, nudged in or out, so the
// cracks wander
const wobble = (poly, seed) => poly.flatMap((p, i) => {
  const q = poly[(i + 1) % poly.length], n = 0.025 * (rnd(i, 169, seed) - 0.5) * 2
  const mx = (p[0] + q[0]) / 2, mz = (p[1] + q[1]) / 2, l = Math.hypot(q[0] - p[0], q[1] - p[1])
  const edge = Math.abs(mx) > 0.46 || Math.abs(mz) > 0.46
  return [p, [mx + (edge ? 0 : -(q[1] - p[1]) / l * n), mz + (edge ? 0 : (q[0] - p[0]) / l * n)]]
})
const plate = (poly, i) => tf({ pos: [0, (i % 2) * 0.01, 0], rot: [(rnd(i, 161, 7) - 0.5) * 2.5, 0, (rnd(i, 162, 7) - 0.5) * 2.5] },
  [[0.016, 0.04, 0], [0.032, 0.03, 0.037], [0.056, 0.022, 0.064], [0.09, 0.014, 0.083]].map(([d, h, y], k) =>
    prismUp(shrink(wobble(poly, 181 + i), d), h, y, i % 2 ? "dirtShade" : "dirt", 0.007)))
// the clods along the +z side (turned for the others): broken chunks of
// earth hanging flush with the block's side from under the rim, each a
// little askew and its own length
const clods = (seed) => Array.from({ length: 6 }, (_, i) => {
  const x = -0.4 + i * 0.16 + (rnd(i, 163, seed) - 0.5) * 0.04, len = 0.14 + rnd(i, 164, seed) * 0.1
  return tf({ pos: [x, 0.01, 0.455], rot: [(rnd(i, 165, seed) - 0.5) * 10, (rnd(i, 166, seed) - 0.5) * 14, (rnd(i, 168, seed) - 0.5) * 16] },
    box(0.15 + rnd(i, 167, seed) * 0.04, len, 0.07, { mat: "dirtD", pos: [0, -len, 0], jitter: 0.012, seed: seed + i }))
})
model("dirt_cap", { pivot: "origin" },
  prismUp(roundSquare(CELL_HALF + 0.012, 0.06, 6, 0.03, 4), 0.14, -0.13, "dirtD", 0.008),
  PLATES.map((p, i) => plate(p, i)),
  [0, 90, 180, 270].map((a, k) => tf({ rot: [0, a, 0] }, clods(171 + k * 9))))
looms("dirt_cap")

// --- stone slab (1482, 1645; the owner: the same slab) ----------------------
// a thick slab of the arena 5 house's stone lying on another block's top
// (y = 0): darker lumpy sides with a rounded rim, the top swelling a little,
// the foot greyed by damp
model("stone_slab", { pivot: "origin" },
  prismUp(roundSquare(CELL_HALF + 0.01, 0.06, 4, 0.012, 2), 0.06, 0, "plasterFoot", 0.008),
  prismUp(roundSquare(CELL_HALF + 0.006, 0.07, 4, 0.012, 3), 0.18, 0.055, "plasterSide", 0.01),
  prismUp(roundSquare(CELL_HALF - 0.012, 0.09, 4, 0.006, 5), 0.035, 0.23, "plaster", 0.008),
  prismUp(roundSquare(CELL_HALF - 0.05, 0.12), 0.015, 0.262, "plaster", 0.005))
looms("stone_slab")

// --- grey dead leaves and dust (2454, 2453; 2456, 2455) ---------------------
// flat flakes lying on the floor, the owner: "like the leaves, but grey".
// The four retail drawings only change how many there are: a spread of many
// (2454, 2453) and a few (2456, 2455). A flake: a rounded, ragged outline
// folded a little along its middle, every third one darker or lighter
function flake(x, z, r, a, i, seed) {
  const half = (side) => {
    const pts = [0, -r]
    for (let k = 1; k < 4; k++) {
      const t = -Math.PI / 2 + (k / 4) * Math.PI, rr = r * (0.75 + rnd(k + side * 5, 171, seed) * 0.35)
      pts.push(side * Math.cos(t) * rr * 0.8, Math.sin(t) * rr)
    }
    pts.push(0, r)
    return side > 0 ? pts : pts.reduceRight((o, _, k) => (k % 2 ? o : o.concat(pts[k], pts[k + 1])), [])
  }
  const m = i % 3 === 0 ? "flakeD" : i % 3 === 1 ? "flake" : "flakeL"
  return tf({ pos: [x, 0.006 + (i % 3) * 0.002, z], rot: [0, a, 0] }, tf({ rot: [-90, 0, 0] },
    extrude(half(1), 0.008, { mat: m, rot: [0, 10, 0] }), extrude(half(-1), 0.008, { mat: m, rot: [0, -10, 0] })))
}
// n flakes scattered over a spread of w × d, sizes r0..r1: one per cell of
// a jittered grid, so they spread out and seldom pile up
const flakes = (n, w, d, r0, r1, seed) => {
  const cols = Math.ceil(Math.sqrt(n * w / d)), rows = Math.ceil(n / cols)
  return Array.from({ length: n }, (_, i) => flake(
    ((i % cols) + 0.2 + rnd(i, 172, seed) * 0.6) / cols * w - w / 2, (Math.floor(i / cols) + 0.2 + rnd(i, 173, seed) * 0.6) / rows * d - d / 2,
    r0 + rnd(i, 174, seed) * (r1 - r0), rnd(i, 175, seed) * 360, i, seed))
}
model("dead_leaves", { pivot: "origin" }, flakes(12, 0.78, 0.6, 0.06, 0.11, 181))
model("dead_leaves_few", { pivot: "origin" }, flakes(5, 0.48, 0.36, 0.055, 0.12, 191))
for (const n of ["dead_leaves", "dead_leaves_few"]) looms(n)

// --- tombstones and crosses (2492, 2495, 2496, 2494, 1423, 1426, 1416, 1503,
// 1464, 2500, 247, 1419, 2493) -----------------------------------------------
// each one its own, built from a few shared parts. They face +z (the face the
// retail draws on the left) and stand at the cell centre unless noted.
// an arch outline (XY), w wide, h tall to the crown, sitting on y = 0
const archPts = (w, h, seg = 8) => {
  const r = w / 2, pts = [r, 0, r, h - r]
  for (let i = 1; i < seg; i++) { const a = (i / seg) * Math.PI; pts.push(Math.cos(a) * r, h - r + Math.sin(a) * r) }
  pts.push(-r, h - r, -r, 0)
  return pts
}
// an arched frame (a ∩ band, b wide) round a recessed panel: the band is d
// deep, the panel sits `sink` behind its face. top: "arch" or a rounded square
function framed(w, h, b, d, { mat = "stone", panel = "panel", sink = 0.04, square = 0, seed = 1 } = {}) {
  const outer = square ? rrect(w, h, square).map((v, i) => (i % 2 ? v + h / 2 : v)) : archPts(w, h)
  const inner = square ? rrect(w - 2 * b, h - b, square * 0.6).map((v, i) => (i % 2 ? v + (h - b) / 2 : v)) : archPts(w - 2 * b, h - b)
  // the band: the outer outline down one side, the inner one back up
  const band = square
    ? [...archBand(w, h, b, square)]
    : [...outer, ...inner.reduceRight((o, _, k) => (k % 2 ? o : o.concat(inner[k], inner[k + 1])), [])]
  return [
    extrude(band, d, { mat, jitter: 0.006, seed }),
    extrude(inner, d - 2 * sink, { mat: panel, pos: [0, 0, -sink], jitter: 0.004, seed: seed + 1 }),
  ]
}
// the ∩ band of a square-topped frame with rounded corners r
function archBand(w, h, b, r) {
  const W = w / 2, I = W - b, out = [W, 0, W, h - r]
  for (let i = 1; i < 4; i++) { const a = (i / 4) * Math.PI / 2; out.push(W - r + Math.cos(a) * r, h - r + Math.sin(a) * r) }
  out.push(-W + r, h)
  for (let i = 1; i < 4; i++) { const a = Math.PI / 2 + (i / 4) * Math.PI / 2; out.push(-W + r + Math.cos(a) * r, h - r + Math.sin(a) * r) }
  out.push(-W, 0, -I, 0, -I, h - b - r * 0.6, -I + r * 0.6, h - b, I - r * 0.6, h - b, I, h - b - r * 0.6, I, 0)
  return out
}
// a skull in relief on a +z face at (x, y, z), s across: cranium, jaw, two
// dark sockets and a nose
const skull = (x, y, z, s, mat = "stoneShade") => tf({ pos: [x, y, z] },
  sphere(s * 0.5, { mat, detail: 1, scale: [1, 0.95, 0.35] }),
  box(s * 0.56, s * 0.3, s * 0.16, { mat, pos: [0, -s * 0.55, 0] }),
  [-1, 1].map((k) => sphere(s * 0.15, { mat: "hole", detail: 1, pos: [k * s * 0.2, -s * 0.06, s * 0.16], scale: [1, 1, 0.4] })),
  cone(s * 0.07, s * 0.12, { mat: "hole", sides: 3, pos: [0, -s * 0.3, s * 0.16], rot: [0, 0, 180] }))
// a tuft of grass blades at (x, z)
const tuft = (x, z, n, h, seed) => Array.from({ length: n }, (_, i) =>
  tf({ pos: [x, 0, z], rot: [0, (i * 137.5 + seed * 40) % 360, 0] },
    cone(0.025, h * (0.7 + rnd(i, 201, seed) * 0.5), { mat: i % 3 ? "blade" : "bladeL", sides: 3, rot: [18 + rnd(i, 202, seed) * 25, 0, 0], scale: [1, 1, 0.4] })))
// a stepped base: (w, d) per step from the ground up, h each
const steps = (sizes, h, mat = "stone") => sizes.map(([w, d], i) =>
  box(w, h, d, { mat: i % 2 ? "stoneShade" : mat, pos: [0, i * h, 0], jitter: 0.005, seed: 211 + i }))

// arched headstone with a skull (2492): a thick sandstone arch, the skull
// carved on its sunk panel, grass at the corners
model("headstone_skull",
  framed(0.72, 0.78, 0.12, 0.26, { panel: "stoneShade", sink: 0.05, seed: 221 }),
  skull(0, 0.4, 0.04, 0.32),
  box(0.76, 0.07, 0.29, { mat: "stoneMoss", jitter: 0.004 }),
  tuft(-0.3, 0.12, 5, 0.14, 1), tuft(0.31, 0.1, 4, 0.12, 2))
// gothic iron cross (2495), a little bent: bars of wrought beads, each arm
// ending in three knobs, the whole leaning over
const trefoil = (x, y, a) => tf({ pos: [x, y, 0], rot: [0, 0, a] },
  sphere(0.045, { mat: "ironD", detail: 1, pos: [0, 0.04, 0] }), sphere(0.038, { mat: "ironD", detail: 1, pos: [-0.04, 0, 0] }), sphere(0.038, { mat: "ironD", detail: 1, pos: [0.04, 0, 0] }))
// a bar of wrought iron beads from (x0, y0) to (x1, y1)
const beads = (x0, y0, x1, y1, n) => Array.from({ length: n }, (_, i) => {
  const t = (i + 0.5) / n
  return sphere(0.034, { mat: i % 2 ? "ironD" : "iron", detail: 1, pos: [x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, 0], scale: [1, 1.2, 1] })
})
model("iron_cross", tf({ rot: [-6, 0, 22] },
  box(0.045, 0.6, 0.045, { mat: "ironD" }), beads(0, 0.04, 0, 0.6, 9), trefoil(0, 0.63, 0),
  tf({ pos: [0, 0.4, 0], rot: [0, 0, 6] }, box(0.38, 0.045, 0.045, { mat: "ironD" }), beads(-0.19, 0, 0.19, 0, 6), trefoil(0.21, 0, -90), trefoil(-0.21, 0, 90)),
  cone(0.06, 0.06, { mat: "ironD", sides: 4 })))
// tall stone cross (2496): a plain square shaft and arms, moss at its foot
model("stone_cross",
  box(0.11, 1.25, 0.1, { mat: "stone", jitter: 0.006 }),
  box(0.48, 0.11, 0.1, { mat: "stone", pos: [0.02, 0.86, 0], jitter: 0.006 }),
  box(0.14, 0.08, 0.13, { mat: "stoneMoss", jitter: 0.006 }))
// cross of Santiago (2494): small stone cross, arms ending in round lobes,
// the foot a long blade, leaning
const lobe = (x, y) => cyl(0.09, 0.11, { mat: "stone", sides: 8, rot: [90, 0, 0], pos: [x, y, -0.055] })
model("cross_santiago", tf({ rot: [-8, 0, -14] },
  box(0.11, 0.62, 0.11, { mat: "stone", jitter: 0.005 }),
  box(0.36, 0.11, 0.11, { mat: "stone", pos: [0, 0.4, 0], jitter: 0.005 }),
  lobe(0.19, 0.455), lobe(-0.19, 0.455), lobe(0, 0.66),
  box(0.1, 0.05, 0.1, { mat: "stoneMoss" })))
// headstone with boards (1423): a rough frame, square-topped, round
// three boards set in it
model("headstone_boards",
  framed(0.62, 0.86, 0.13, 0.26, { square: 0.14, panel: "panel", sink: 0.05, seed: 231 }),
  [0.08, 0.3, 0.52].map((y, i) => box(0.42, 0.17, 0.04, { mat: "board", pos: [0, y, 0.05], rot: [0, 0, [2, -3, 1][i]], jitter: 0.004 })))
// tall arched headstone (1426): a heavy arch round a cracked red-brown
// panel, moss on its crown, a little stone tablet leaning at its foot
model("headstone_tall",
  framed(0.72, 1.24, 0.14, 0.3, { panel: "panel", sink: 0.06, seed: 241 }),
  tf({ pos: [0, 1.16, 0] }, box(0.36, 0.06, 0.26, { mat: "stoneMoss", jitter: 0.008 })),
  tf({ pos: [0, 0, 0.3], rot: [-62, 0, 0] }, box(0.34, 0.2, 0.03, { mat: "stoneShade", jitter: 0.004 })))
// headstone with a figure (1416): an upright slab, a praying figure carved
// on it (head, shoulders, robe), grass at its foot
model("headstone_figure",
  box(0.5, 0.82, 0.18, { mat: "stone", jitter: 0.008, seed: 251 }),
  tf({ pos: [0, 0, 0.09] },
    sphere(0.1, { mat: "plaster", detail: 1, pos: [0, 0.6, 0], scale: [1, 1.15, 0.6] }),
    cone(0.18, 0.4, { mat: "plaster", sides: 6, pos: [0, 0.14, 0], scale: [1, 1, 0.4] }),
    box(0.24, 0.06, 0.06, { mat: "plaster", pos: [0, 0.36, 0.03], rot: [0, 0, 8] })),
  tuft(-0.24, 0.1, 5, 0.13, 3), tuft(0.25, 0.12, 5, 0.15, 4))
// candle shrine (1503): a mossy niche on two steps, a lit candle inside
// standing out against its pale back
model("candle_shrine",
  steps([[0.7, 0.62], [0.58, 0.5]], 0.09),
  tf({ pos: [0, 0.18, 0] },
    framed(0.5, 0.62, 0.07, 0.4, { mat: "stoneMoss", panel: "stoneShade", sink: 0.14, square: 0.08, seed: 261 }),
    box(0.56, 0.07, 0.44, { mat: "stone", pos: [0, 0.6, 0], jitter: 0.006 }),
    tf({ pos: [0, 0, 0.06] }, cyl(0.055, 0.15, { mat: "wax", sides: 8 }), cone(0.045, 0.12, { mat: "flame", sides: 6, pos: [0, 0.16, 0] }))))
// cross with a skull (1464): a wheel cross on a shaft over two steps, the
// skull carved on the wheel, a wooden RIP board hanging askew on the shaft
model("cross_skull",
  steps([[0.46, 0.4], [0.34, 0.3]], 0.09),
  box(0.16, 0.86, 0.13, { mat: "stone", pos: [0, 0.18, 0], jitter: 0.006 }),
  tf({ pos: [0, 1.0, 0], scale: 1.35 },
    cyl(0.2, 0.14, { mat: "stone", sides: 12, rot: [90, 0, 0], pos: [0, 0, -0.07] }),
    box(0.62, 0.16, 0.13, { mat: "stone", pos: [0, -0.08, 0], jitter: 0.006 }),
    box(0.16, 0.32, 0.13, { mat: "stone", pos: [0, 0, 0], jitter: 0.006 }),
    skull(0, 0.02, 0.08, 0.22)),
  tf({ pos: [0, 0.5, 0.1], rot: [0, 0, 28] }, box(0.46, 0.17, 0.04, { mat: "board", jitter: 0.004 })))
// wooden headstone (2500): two thick olive-stained upright planks with
// rounded tops, a skull and a bone nailed on, grass all round
model("headstone_wood",
  [[-0.16, 0.86], [0.16, 0.8]].map(([x, h], i) => extrude(archPts(0.32, h, 4), 0.13, { mat: "boardOlive", pos: [x, 0, 0], rot: [0, 0, i ? -2 : 2], jitter: 0.005, seed: 271 + i })),
  skull(0, 0.5, 0.1, 0.26, "bone"),
  tf({ pos: [0, 0.4, 0.1], rot: [0, 0, -8] }, cyl(0.03, 0.62, { mat: "bone", sides: 6, rot: [0, 0, 90], pos: [0.31, 0, 0] }),
    [-1, 1].map((k) => sphere(0.045, { mat: "bone", detail: 1, pos: [k * 0.31, 0, 0] }))),
  tuft(-0.24, 0.12, 6, 0.2, 5), tuft(0.2, 0.15, 6, 0.24, 6), tuft(0.0, 0.2, 5, 0.16, 7), tuft(-0.3, -0.1, 4, 0.18, 8))
// thick tomb with an iron cross (247): a stone block under a heavy rounded
// cap that overhangs it, a wrought-iron cross of rings standing behind
const ring = (x, y, r) => torus(r, 0.012, { mat: "iron", pos: [x, y, 0], rot: [90, 0, 0] })
model("tomb_iron_cross",
  box(0.6, 0.5, 0.56, { mat: "stone", jitter: 0.008, seed: 281 }),
  [-0.15, 0.15].map((x) => box(0.05, 0.34, 0.02, { mat: "hole", pos: [x, 0.06, 0.28] })),
  tf({ pos: [0, 0.46, 0] }, prismUp(rrect(0.88, 0.82, 0.22), 0.16, 0, "stoneShade", 0.012), prismUp(rrect(0.8, 0.74, 0.24), 0.08, 0.15, "stoneShade", 0.01),
    prismUp(rrect(0.62, 0.56, 0.22), 0.04, 0.22, "stoneShade", 0.008)),
  tf({ pos: [-0.12, 0.7, -0.26] },
    box(0.035, 1.0, 0.035, { mat: "ironD" }),
    ring(0, 0.66, 0.1), ring(-0.2, 0.52, 0.1), ring(0.2, 0.52, 0.1), ring(0, 0.52, 0.07), ring(0, 0.94, 0.09)))
// headstone with horns (1419): a low slab lying in front, the stone behind
// it crowned with two horns, a brow and two eyes carved on its face
model("headstone_horns",
  box(0.7, 0.12, 0.42, { mat: "stoneShade", pos: [0, 0, 0.1], jitter: 0.008 }),
  tf({ pos: [0, 0, -0.14] },
    box(0.56, 0.52, 0.2, { mat: "stone", jitter: 0.01, seed: 291 }),
    [-1, 1].map((k) => cone(0.07, 0.26, { mat: "stone", sides: 5, pos: [k * 0.2, 0.5, 0], rot: [0, 0, -k * 10] })),
    box(0.4, 0.035, 0.02, { mat: "hole", pos: [0, 0.38, 0.1] }),
    [-1, 1].map((k) => sphere(0.025, { mat: "hole", detail: 1, pos: [k * 0.11, 0.3, 0.1], scale: [1, 1, 0.4] }))))
// sunken headstone (2493): the owner: "just cut the headstone so only its
// tip shows". The arched headstone (2492) cut at the ground line, its frame
// and sunk panel kept, a tuft at its side
// keep the part of an outline (XY) above y = c, moved down to y = 0
function clipAbove(pts, c) {
  const out = [], n = pts.length / 2
  for (let i = 0; i < n; i++) {
    const [x0, y0] = [pts[2 * i], pts[2 * i + 1]], [x1, y1] = [pts[(2 * i + 2) % pts.length], pts[(2 * i + 3) % pts.length]]
    if (y0 >= c) out.push(x0, y0 - c)
    if ((y0 >= c) !== (y1 >= c)) out.push(x0 + (x1 - x0) * (c - y0) / (y1 - y0), 0)
  }
  return out
}
const SUNK = 0.5
// the 2492 frame: a ∩ band (the outer arch, then the inner one backwards)
// round the sunk panel
const sunkInner = archPts(0.48, 0.66)
const sunkBand = [...archPts(0.72, 0.78), ...sunkInner.reduceRight((o, _, k) => (k % 2 ? o : o.concat(sunkInner[k], sunkInner[k + 1])), [])]
model("headstone_sunk",
  tf({ rot: [-4, 0, 5] },
    extrude(clipAbove(sunkBand, SUNK), 0.26, { mat: "stone", jitter: 0.006, seed: 301 }),
    extrude(clipAbove(sunkInner, SUNK), 0.16, { mat: "stoneShade", pos: [0, 0, -0.05], jitter: 0.004, seed: 302 })),
  tuft(-0.32, 0.1, 4, 0.14, 9))
for (const n of ["headstone_skull", "iron_cross", "stone_cross", "cross_santiago", "headstone_boards", "headstone_tall", "headstone_figure",
  "candle_shrine", "cross_skull", "headstone_wood", "tomb_iron_cross", "headstone_horns", "headstone_sunk"]) looms(n)

// --- plants: the dead plant (1706) and flowers (520, 521, 522) ---------------
// a pointed leaf (XY outline), base at the origin, pointing up +y
const blade = (w, l) => [0, 0, w * 0.5, l * 0.18, w * 0.45, l * 0.55, w * 0.18, l * 0.85, 0, l, -w * 0.18, l * 0.85, -w * 0.45, l * 0.55, -w * 0.5, l * 0.18]
// dead plant (1706): a wide rosette of long pointed leaves, dead and
// grey-purple, most lying out low, a few inner ones standing, each bent
// down at its middle
model("dead_plant", { scale: 1.35 },
  Array.from({ length: 13 }, (_, i) => {
    const inner = i < 4, a = i * 137.5 + rnd(i, 211, 3) * 20, l = inner ? 0.3 + rnd(i, 212, 3) * 0.1 : 0.34 + rnd(i, 213, 3) * 0.12
    const m = i % 3 === 0 ? "deadD" : i % 3 === 1 ? "dead" : "deadL"
    return tf({ rot: [0, a, 0] }, tf({ rot: [inner ? 30 : 62 + rnd(i, 214, 3) * 14, 0, 0] },
      extrude(blade(0.15, l * 0.55), 0.01, { mat: m }),
      tf({ pos: [0, l * 0.5, 0], rot: [inner ? 25 : 18, 0, 0] }, extrude(blade(0.14, l * 0.55).map((v, k) => (k % 2 ? v : v * 0.9)), 0.01, { mat: m }))))
  }))
// a petal: a rounded spoon shape, base at the origin, pointing up +y (as in
// the arena 5 kit)
const petal = [0, 0, 0.022, 0.02, 0.03, 0.05, 0.022, 0.075, 0, 0.082, -0.022, 0.075, -0.03, 0.05, -0.022, 0.02]
// a poppy on a thin stem leaning out: a cup of five broad petals round a
// black heart, facing up and a little out
function poppy(x, z, h, size, seed) {
  const lean = (rnd(1, 215, seed) - 0.5) * 30, turn = rnd(2, 216, seed) * 360
  return tf({ pos: [x, 0, z], rot: [0, turn, 0] }, tf({ rot: [lean, 0, 0] },
    tube([0, 0, 0, 0.01, h * 0.5, 0, 0, h, 0], 0.006, { mat: "stalk", sides: 4 }),
    tf({ pos: [0, h, 0], rot: [20, 0, 0] },
      Array.from({ length: 5 }, (_, i) => tf({ rot: [0, i * 72, 0] },
        extrude(petal, 0.006, { mat: i % 3 === 0 ? "poppyD" : i % 3 === 1 ? "poppy" : "poppyL", rot: [52 + (i % 2) * 10, 0, 0], scale: size }))),
      sphere(0.018 * size, { mat: "poppyC", detail: 1, pos: [0, 0.012 * size, 0] }))))
}
// a daisy: eight narrow white petals laid out flat round a yellow heart
const daisy = (x, z, h, seed) => tf({ pos: [x, 0, z], rot: [0, rnd(1, 217, seed) * 360, 0] },
  tube([0, 0, 0, 0.005, h * 0.5, 0, 0, h, 0], 0.005, { mat: "stalk", sides: 4 }),
  tf({ pos: [0, h, 0], rot: [15, 0, 0] },
    Array.from({ length: 8 }, (_, i) => tf({ rot: [0, i * 45, 0] }, extrude(blade(0.03, 0.05), 0.004, { mat: "daisy", rot: [80, 0, 0] }))),
    sphere(0.016, { mat: "daisyC", detail: 1, pos: [0, 0.006, 0], scale: [1, 0.6, 1] })))
// a few olive leaves at the foot
const leaves = (n, w, seed) => Array.from({ length: n }, (_, i) => tf({ pos: [(rnd(i, 218, seed) - 0.5) * w, 0, (rnd(i, 219, seed) - 0.5) * w], rot: [0, rnd(i, 220, seed) * 360, 0] },
  extrude(blade(0.06, 0.16), 0.006, { mat: i % 3 === 0 ? "stalkD" : i % 3 === 1 ? "stalk" : "stalkL", rot: [40 + rnd(i, 221, seed) * 25, 0, 0] })))
// poppies (520, 521): nine red poppies spread out at different heights on thin stems,
// a few leaves at their feet
model("poppies",
  [[-0.32, -0.12, 0.2, 1.7], [-0.1, 0.18, 0.28, 1.9], [0.14, -0.2, 0.24, 1.8], [0.34, 0.1, 0.16, 1.6],
   [-0.38, 0.26, 0.12, 1.4], [0.02, 0.0, 0.32, 2.0], [0.22, 0.32, 0.1, 1.4], [-0.18, -0.36, 0.14, 1.5],
   [0.36, -0.3, 0.12, 1.4]].map(([x, z, h, k], i) => poppy(x, z, h, k, 231 + i)),
  leaves(16, 0.75, 241))
// flower patch (522): small poppies and daisies over a bed of olive leaves
model("flower_patch",
  [[-0.2, -0.05, 0.14, 1.4], [0.04, 0.18, 0.18, 1.5], [0.2, -0.12, 0.16, 1.3], [-0.06, -0.22, 0.12, 1.3], [0.26, 0.2, 0.1, 1.2],
   [-0.3, 0.22, 0.1, 1.2], [0.1, -0.02, 0.2, 1.4]].map(([x, z, h, k], i) => poppy(x, z, h, k, 251 + i)),
  [[-0.1, 0.08, 0.12], [0.12, 0.02, 0.15], [-0.26, 0.2, 0.09], [0.08, -0.26, 0.1], [0.3, 0.0, 0.08], [-0.2, -0.24, 0.1], [0.2, 0.3, 0.11]].map(([x, z, h], i) => daisy(x, z, h, 261 + i)),
  leaves(30, 0.66, 271), leaves(10, 0.4, 281))
for (const n of ["dead_plant", "poppies", "flower_patch"]) looms(n)
