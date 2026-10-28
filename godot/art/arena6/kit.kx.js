// Arena 6 (retail world 36: a floating meadow, ruins and scaffolds) — the
// pieces it doesn't share with the arena 1, 2 and 5 kits, each in three
// looms: <name> (a), <name>_b, <name>_c. Broad surfaces use loom textures
// (kit.tx.js); moss tufts and petals use palette colours. Retail gfx in
// brackets.
include("../common/shapes.kx.js")

const LOOMS = ["", "_b", "_c"]
pal(Object.fromEntries(LOOMS.flatMap((s) => [
  ["stone" + s, { tex: "out/stone" + s, uv: 0.9, rough: 0.85 }],
  ["stoneMoss" + s, { tex: "out/stoneMoss" + s, uv: 0.9, rough: 0.9 }],
  ["cliff" + s, { tex: "out/cliff" + s, uv: 2.2, rough: 0.9 }],
  ["flag" + s, { tex: "out/flag" + s, uv: 1, rough: 0.8 }],
  ["board" + s, { tex: "out/board" + s, uv: 0.8, rough: 0.8 }],
  ["flagCrack" + s, { tex: "out/flagCrack" + s, uv: 1, rough: 0.8 }],
  // the same stone a shade darker: every other loose rock, so neighbours part
  ["stoneShade" + s, { tex: "out/stone" + s, uv: 0.9, rough: 0.85, color: "#e4e0d2" }],
  // the moss-washed stones of the mossy cap (1472): the mossy stone, greener
  ["stoneGreen" + s, { tex: "out/stoneMoss" + s, uv: 0.9, rough: 0.9, color: ["#c4cc98", "#a8bca0", "#c8c496"][LOOMS.indexOf(s)] }],
])))
// palette looms: [a, b, c] per key, matching the stone looms
const PAL = {
  // moss cushions on the stones: olive-yellow (retail), deep green, dry olive
  mossD: ["#5e6a12", "#24441c", "#5a5216"], moss: ["#94a41c", "#3e6e2a", "#8a8226"], mossL: ["#c4d038", "#6a9a3e", "#b8ac44"],
  // the small white flowers on the mossy cap (1472): white (retail), pale
  // yellow, pink; a yellow heart
  // the iron bolts of the scaffolds and fences
  bolt: ["#8a8c8a", "#8a8c8a", "#6e6a64"], boltD: ["#4a4c4c", "#4a4c4c", "#3a3632"],
  // the pale worn rim under the sandstone slabs (17-20, 455-457)
  flagRim: ["#e4dcb8", "#d4d6d4", "#e8cdb8"],
  petal: ["#f4f2ea", "#f4e8a8", "#f0b8c8"], petalD: ["#c8c4b8", "#d0c070", "#c88098"], heart: ["#e8c030", "#d08a20", "#f0d050"],
}
pal(Object.fromEntries(LOOMS.flatMap((s, i) => Object.entries(PAL).map(([k, v]) => [k + s, v[i]]))))
const SKINNED = ["stone", "stoneMoss", "stoneGreen", "stoneShade", "cliff", "flag", "flagCrack", "board", ...Object.keys(PAL)]
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

// --- dressed stones ----------------------------------------------------------
// one stone: a block with every edge rounded (radius about a quarter of its
// smallest side), so it reads as a soft worn pillow at game scale. Built as
// the union of three rounded extrusions: along z, along x, and upright.
// Origin at its base centre; rot is a small turn about y.
function stone(x, y, z, w, h, d, { rot = 0, mat = "stone", seed = 1, tilt = 0, round = 0.26 } = {}) {
  const r = Math.min(w, h, d) * round, j = 0.004
  return tf({ pos: [x, y, z], rot: [tilt, rot, tilt * 0.6] },
    extrude(rrect(w, h, r), d - 2 * r, { mat, pos: [0, h / 2, 0], jitter: j, seed }),
    extrude(rrect(d, h - 0.004, r), w - 2 * r, { mat, rot: [0, 90, 0], pos: [0, h / 2, 0], jitter: j, seed: seed + 1 }),
    prismUp(rrect(w - 0.003, d - 0.003, r), h - 2 * r, r, mat, j))
}
// a moss cushion lying on a top face: a few flattened lumps, the light ones on top
const mossPad = (x, y, z, s, seed) => tf({ pos: [x, y, z], rot: [0, rnd(0, 3, seed) * 360, 0] },
  [0, 1, 2, 3].map((i) => sphere(s * (0.55 + rnd(i, 1, seed) * 0.45), {
    mat: i === 3 ? "mossL" : i === 0 ? "mossD" : "moss", detail: 1,
    pos: [(rnd(i, 2, seed) - 0.5) * s * 1.6, 0, (rnd(i, 4, seed) - 0.5) * s * 1.6], scale: [1, 0.32, 1], jitter: s * 0.08, seed: seed + i })))
// a flat moss patch stuck on a face (z = 0 is the face, +z out): a ragged
// star of olive-yellow with a lighter heart, like the retail splotches
function mossFlat(x, y, z, s, face, seed) {
  const star = (r, k) => Array.from({ length: 22 }, (_, i) => {
    const a = (i / 22) * Math.PI * 2, rr = r * (i % 2 ? 0.45 + rnd(i, 7 + k, seed) * 0.3 : 0.8 + rnd(i, 8 + k, seed) * 0.5)
    return [Math.cos(a) * rr * 1.3, Math.sin(a) * rr]
  }).flat()
  const turn = { z: 0, x: 90, "-x": -90, "-z": 180 }[face]
  return tf({ pos: [x, y, z], rot: [0, turn, 0] }, tf({ rot: [0, 0, (rnd(0, 9, seed) - 0.5) * 60] },
    extrude(star(s, 0), 0.008, { mat: "moss", pos: [0, 0, 0.004] }),
    extrude(star(s * 0.5, 3), 0.008, { mat: "mossL", pos: [s * 0.15, s * 0.1, 0.009] })))
}

// a streak of moss along a joint: the patch stretched sideways and flattened
const mossStreak = (x, y, z, s, face, seed) => tf({ pos: [x, y, z], rot: [0, { z: 0, x: 90 }[face], 0] },
  tf({ scale: [1.8, 0.6, 1] }, mossFlat(0, 0, 0, s, "z", seed)))
// the same patch lying on a top face
const mossTop = (x, y, z, s, seed) => tf({ pos: [x, y, z], rot: [-90, rnd(0, 3, seed) * 360, 0] }, mossFlat(0, 0, 0, s, "z", seed))

// --- ashlar block (1381) -----------------------------------------------------
// a cell of big dressed stones in three courses, two stones a course, the
// joint turning a quarter each course like a bond; the stones a little
// uneven, some mossy, moss cushions on the top and down the seen faces.
// In the map they stand in rows as the ruined walls, and the mossy cap
// (1472) is stacked on some. 0.78 m tall, as the retail.
const ASHLAR_H = 0.78
function course(y, h, seed, mossy, long = null, vary = 0.03) {
  // a 2 × 2 grid of stones, the joints shifted off centre (the other way each
  // course, so they never line up)
  const out = [], G = 0.035, E = 0.47
  const sx = (rnd(0, 1, seed) - 0.5) * 0.24, sz = (rnd(0, 2, seed) - 0.5) * 0.24
  // long = "x": two long stones lying along x (one joint, along x), "z" the same along z
  const grid = long === "x" ? [[0, -1], [0, 1]] : long === "z" ? [[-1, 0], [1, 0]] : [[-1, -1], [1, -1], [-1, 1], [1, 1]]
  for (const [i, [ax, az]] of grid.entries()) {
    const x0 = ax === 0 ? -E : ax < 0 ? -E : sx, x1 = ax === 0 ? E : ax < 0 ? sx : E
    const z0 = az === 0 ? -E : az < 0 ? -E : sz, z1 = az === 0 ? E : az < 0 ? sz : E
    const hh = h - 0.02 - rnd(i, 3, seed) * vary
    out.push(stone((x0 + x1) / 2, y, (z0 + z1) / 2, x1 - x0 - G, hh, z1 - z0 - G,
      { rot: (rnd(i, 4, seed) - 0.5) * 5, mat: mossy.includes(i) ? "stoneMoss" : "stone", seed: seed * 7 + i }))
  }
  return out
}
model("ashlar_block",
  course(0, 0.27, 11, [1, 3]), course(0.27, 0.25, 12, [0], "z"), course(0.52, 0.27, 14, [1], null, 0.06),
  mossTop(0.2, ASHLAR_H - 0.02, -0.18, 0.1, 21), mossTop(-0.22, ASHLAR_H - 0.03, 0.26, 0.06, 22),
  mossFlat(-0.1, 0.42, 0.46, 0.09, "z", 23), mossFlat(0.15, 0.2, 0.46, 0.07, "z", 25), mossFlat(0.46, 0.5, -0.05, 0.08, "x", 24))
looms("ashlar_block")

// --- rough stonework: the rubble heap (1565), the pillar (1650), the mossy
// cap (1472) --------------------------------------------------------------
// courses of smaller rough stones: each course a grid of nx × nz stones with
// the joints at random places, some stones standing proud or set back, a
// little turned; inset narrows the course (a heap tapers, a pillar doesn't).
// Only the stones on the outside of the course are made.
//   courses: [[h, nx, nz, inset], ...] bottom to top
function rubble(courses, { half = 0.46, seed = 1, moss = 0.3, round = 0.3, mossMat = "stoneMoss" } = {}) {
  const out = []
  let y = 0
  const cuts = (n, lo, hi, s) => {
    const c = [lo]
    for (let k = 1; k < n; k++) c.push(lo + (hi - lo) * (k + (rnd(k, s, seed) - 0.5) * 0.5) / n)
    c.push(hi)
    return c
  }
  courses.forEach(([h, nx, nz, inset = 0], ci) => {
    const e = half - inset
    const xs = cuts(nx, -e, e, ci * 3 + 1), zs = cuts(nz, -e, e, ci * 3 + 2)
    for (let i = 0; i < nx; i++) for (let k = 0; k < nz; k++) {
      if (i > 0 && i < nx - 1 && k > 0 && k < nz - 1 && ci < courses.length - 1) continue
      const n = ci * 31 + i * 7 + k
      const out1 = (rnd(n, 11, seed) - 0.3) * 0.11
      const cx = (xs[i] + xs[i + 1]) / 2 + (i === 0 ? -out1 : i === nx - 1 ? out1 : 0)
      const cz = (zs[k] + zs[k + 1]) / 2 + (k === 0 ? -out1 : k === nz - 1 ? out1 : 0)
      const hh = h - 0.02 - rnd(n, 12, seed) * h * (ci === courses.length - 1 ? 0.45 : 0.25)
      out.push(stone(cx, y, cz, xs[i + 1] - xs[i] - 0.04, hh, zs[k + 1] - zs[k] - 0.04,
        { rot: (rnd(n, 13, seed) - 0.5) * 14, mat: rnd(n, 14, seed) < moss ? mossMat : "stone", seed: n, round }))
    }
    // the hidden core of the course, so no gap shows through the joints
    out.push(box(2 * e - 0.12, h - (ci === courses.length - 1 ? 0.12 : 0.03), 2 * e - 0.12, { mat: "stone", pos: [0, y, 0] }))
    y += h
  })
  return out
}
// small loose stones lying on a top: [x, y, z, size] each
const smallStones = (list, seed) => list.map(([x, y, z, s], i) =>
  stone(x, y, z, s * (0.9 + rnd(i, 21, seed) * 0.4), s * 0.75, s * (0.8 + rnd(i, 22, seed) * 0.3),
    { rot: rnd(i, 23, seed) * 90, tilt: (rnd(i, 24, seed) - 0.5) * 16, seed: seed + i, round: 0.2 }))

// rubble heap (1565): a low dry-stone mound of rough stones, narrowing in
// three courses, a few small stones left on top, moss in the joints.
// About 0.6 m, one cell.
model("rubble_heap",
  rubble([[0.28, 3, 2, 0], [0.26, 2, 3, 0.03]], { seed: 31, moss: 0.35 }),
  smallStones([[-0.22, 0.5, 0.2, 0.2], [0.2, 0.52, -0.02, 0.18], [-0.12, 0.5, -0.24, 0.17], [0.16, 0.5, 0.28, 0.15],
    [0.3, 0.52, -0.3, 0.13], [-0.02, 0.64, 0.02, 0.15]], 32),
  mossStreak(-0.15, 0.26, 0.5, 0.1, "z", 33), mossStreak(0.5, 0.25, 0.1, 0.09, "x", 34),
  mossTop(-0.3, 0.5, -0.05, 0.06, 35))
looms("rubble_heap")

// stone pillar (1650): a ruined pillar of rough stones, seven courses, the
// stones of each course in a different grid; the top uneven, a couple of
// stones standing proud. About 1.65 m, one cell.
model("stone_pillar",
  rubble([[0.36, 2, 2, 0], [0.34, 2, 3, 0.01], [0.36, 3, 2, 0.02], [0.34, 2, 2, 0.02], [0.32, 2, 3, 0.03]],
    { half: 0.5, seed: 41, moss: 0.25, round: 0.28 }),
  smallStones([[-0.18, 1.72, 0.14, 0.2], [0.2, 1.72, -0.12, 0.17]], 42),
  mossStreak(-0.1, 1.06, 0.5, 0.1, "z", 43), mossStreak(0.5, 0.36, 0.05, 0.1, "x", 44))
looms("stone_pillar")

// mossy cap (1472): two courses of rounded stones grown over with moss,
// small white flowers on top. It stacks on the ashlar block (1381), the way
// the retail map piles it. About 0.62 m.
// a small five-petal flower facing up, its heart yellow
const flower = (x, y, z, s, seed) => tf({ pos: [x, y, z], rot: [(rnd(0, 31, seed) - 0.5) * 30, rnd(0, 32, seed) * 72, 0] },
  [0, 1, 2, 3, 4].map((i) => tf({ rot: [0, i * 72, 0] },
    sphere(s * 0.5, { mat: i % 2 ? "petal" : "petalD", detail: 1, pos: [0, 0, s * 0.55], scale: [0.8, 0.25, 1.2] }))),
  sphere(s * 0.28, { mat: "heart", detail: 1, pos: [0, s * 0.08, 0], scale: [1, 0.6, 1] }))
model("mossy_cap",
  rubble([[0.36, 3, 2, 0.02], [0.32, 2, 2, 0.12]], { seed: 51, moss: 1, round: 0.36, mossMat: "stoneGreen" }),
  mossTop(-0.15, 0.67, -0.1, 0.1, 52), mossTop(0.3, 0.35, -0.32, 0.09, 54),
  mossStreak(0.0, 0.35, 0.49, 0.12, "z", 55), mossStreak(0.49, 0.3, -0.1, 0.11, "x", 56),
  flower(-0.1, 0.69, 0.12, 0.13, 57), flower(0.17, 0.68, -0.15, 0.12, 58), flower(-0.32, 0.38, 0.36, 0.1, 59),
  flower(0.36, 0.37, 0.3, 0.11, 60))
looms("mossy_cap")

// --- cliff rock under the island's edge cells (1798, 1799, 1802, 1803, 1804)
// kind cliff: hangs under an edge cell in place of its block; the origin is
// the cell centre at the block's top (the cap lies on it), the rock goes down
// from there. A square head fills the cell under the cap; below it a bundle
// of long faceted shards of different lengths, each narrowing to a point, the
// ones on the seen faces (+x, +z) standing out a little with lit ledges.
// a shard: a five-sided crystal hanging from y = top, len long, radius r,
// full width down to about half its length, then narrowing to its tip;
// squash flattens it in z
function shard(x, z, top, len, r, { seed = 1, rot = 0, squash = 1, mat = "cliff" } = {}) {
  return tf({ pos: [x, top - len, z], rot: [0, rot, 0], scale: [1, 1, squash] },
    lathe([0, 0, r * 0.45, len * 0.14, r * 0.85, len * 0.34, r, len * 0.52, r * 1.02, len, 0, len],
      { mat, sides: 5, jitter: Math.min(0.03, r * 0.08), seed }))
}
// the head: a cell-sized rock block just under the cap
// (a little narrower at its foot, where the shards take over)
const cliffHead = (h, seed) => [
  prismUp(roundSquare(0.45, 0.12, 4, 0.03, seed), h * 0.6, -h * 0.6, "cliff", 0.02),
  prismUp(roundSquare(0.4, 0.14, 4, 0.06, seed + 1), h * 0.4, -h, "cliff", 0.03)]
// a bundle of shards from a list [x, z, top, len, r], each turned its own way
const shards = (list, seed) => list.map(([x, z, top, len, r], i) =>
  shard(x, z, top, len, r, { seed: seed + i, rot: rnd(i, 41, seed) * 72 }))

// flat plates standing out of the two seen faces: vertical strips, each its
// own length, their tops catching the light. [along, top, len, r] per plate;
// along runs over the face (-0.4..0.4)
const plates = (zFace, xFace, seed) => [
  ...zFace.map(([a, top, len, r], i) => shard(a, 0.44, top, len, r, { seed: seed + i, rot: rnd(i, 51, seed) * 20 - 10, squash: 0.45 })),
  ...xFace.map(([a, top, len, r], i) => tf({ rot: [0, 90, 0] },
    shard(-a, 0.44, top, len, r, { seed: seed + 10 + i, rot: rnd(i, 52, seed) * 20 - 10, squash: 0.45 })))]

// cliff column (1803): about 2.75 m under the block top; three broad shards
// fill the cell, a long one on the seen corner, a short one on each face
model("cliff_col", { pivot: "origin" },
  cliffHead(1.0, 1),
  shards([[0.08, 0.08, -0.05, 2.75, 0.42], [-0.14, 0.14, -0.1, 1.7, 0.34], [0.15, -0.14, -0.1, 1.6, 0.34],
    [-0.15, -0.15, -0.1, 1.4, 0.34]], 61),
  plates([[-0.18, -0.8, 1.0, 0.24]], [[0.12, -0.3, 1.3, 0.24]], 65))
// cliff column with boulders (1802): the same, rounded boulders wedged at
// the top of its +z face
model("cliff_col_knobs", { pivot: "origin" },
  cliffHead(1.0, 2),
  shards([[0.1, 0.06, -0.05, 2.6, 0.42], [-0.15, 0.14, -0.1, 1.6, 0.34], [0.15, -0.15, -0.1, 1.7, 0.34],
    [-0.15, -0.15, -0.1, 1.4, 0.34]], 71),
  plates([[0.2, -0.6, 1.0, 0.22]], [[-0.18, -0.25, 1.3, 0.24]], 75),
  rock(0.2, { mat: "cliff", pos: [-0.24, -0.28, 0.44], rough: 0.12, squash: 0.8, seed: 72 }),
  rock(0.15, { mat: "cliff", pos: [-0.4, -0.55, 0.4], rough: 0.12, squash: 0.8, seed: 73 }),
  rock(0.13, { mat: "cliff", pos: [0.02, -0.18, 0.5], rough: 0.12, squash: 0.8, seed: 74 }))
// cliff tip (1798): the island's lowest point, at its front corner: a long
// spine standing out of the corner, reaching about 3.3 m, a shorter pillar
// beside it, the column behind
model("cliff_tip", { pivot: "origin" },
  cliffHead(1.0, 3),
  shards([[0.0, 0.0, -0.05, 2.3, 0.42], [-0.16, 0.16, -0.1, 1.7, 0.34], [0.16, -0.16, -0.1, 1.7, 0.34]], 81),
  shard(0.3, 0.3, -0.1, 3.25, 0.3, { seed: 85, rot: 20 }),
  shard(0.12, 0.4, -0.2, 2.75, 0.22, { seed: 86, rot: 45, squash: 0.7 }),
  plates([[-0.22, -0.8, 1.0, 0.22]], [[-0.22, -0.4, 1.2, 0.22]], 88))
// a rock face hanging on the +z face of a column (z = 0.47 is the face): a
// row of flattened shards side by side, their tops at y = 0, their lengths
// running from lenL at -x to lenR at +x, so the bottom slants in points.
// w wide along x
function rockFace(w, n, lenL, lenR, r, seed) {
  return Array.from({ length: n }, (_, i) => {
    const f = n > 1 ? i / (n - 1) : 0.5
    const len = lenL + (lenR - lenL) * f + (rnd(i, 71, seed) - 0.5) * 0.25
    return shard(-w / 2 + r * 0.8 + f * (w - r * 1.6), 0.47, -(rnd(i, 72, seed) * 0.12), len, r,
      { seed: seed + i, rot: rnd(i, 73, seed) * 30 - 15, squash: 0.5 })
  })
}
// cliff face (1804): a rock face on the +x face, the whole cell wide,
// longest at its +z end (about 2.5 m), short at its -z end
model("cliff_slant", { pivot: "origin" }, tf({ rot: [0, 90, 0] }, rockFace(1.0, 4, 2.5, 1.1, 0.3, 91)))
// cliff shard (1799): a narrow rock face, half a cell wide, on the +z face,
// to break a long run of columns
model("cliff_shard", { pivot: "origin" }, tf({ pos: [0.2, 0, 0] }, rockFace(0.5, 2, 2.3, 1.7, 0.2, 101)))
for (const n of ["cliff_col", "cliff_col_knobs", "cliff_tip", "cliff_slant", "cliff_shard"]) looms(n)

// --- loose rocks (1834, 1835, 1833, 1836) ------------------------------------
// pale angular chunks of the same sandstone, lying on the ground at the foot
// of walls and pillars and alone on the grass: blocks with softened edges,
// each tilted its own way, a flat lit top and a few cracks (the stone loom).
// a chunk: a six-sided block, its top rim and foot chamfered, every corner
// pushed about so no two faces are square; stretched to w × h × d, tilted,
// its base sunk a little in the ground. [x, z, w, h, d, rot, tilt]
const chunk = ([x, z, w, h, d, rot, tilt = 0], seed) => tf({ pos: [x, -0.04, z], rot: [tilt, rot, tilt * 0.5], scale: [w, h + 0.04, d] },
  lathe([0, 0, 0.44, 0, 0.5, 0.18, 0.5, 0.66, 0.4, 0.92, 0.3, 1, 0, 1], { mat: seed % 2 ? "stoneShade" : "stone", sides: 6, jitter: 0.06, seed }))
const chunks = (list, seed) => list.map((c, i) => chunk(c, seed + i))
// rock heap (1834): six chunks tumbled together, about 0.45 m
model("rock_heap",
  chunks([[-0.22, -0.1, 0.42, 0.4, 0.4, 12, 8], [0.08, -0.26, 0.4, 0.42, 0.36, -20, -10], [0.26, 0.04, 0.36, 0.38, 0.42, 35, 12],
    [-0.04, 0.2, 0.4, 0.34, 0.36, -8, 18], [0.26, 0.32, 0.3, 0.26, 0.28, 50, -14], [-0.3, 0.3, 0.28, 0.24, 0.28, 25, 10]], 111))
// two rocks (1835): a pair of chunks on the -x +z side, a single tilted one
// on the +x -z side, low (about 0.3 m) and spread across the cell
model("rock_pair",
  chunks([[-0.2, 0.2, 0.56, 0.24, 0.5, 10, 5], [0.02, 0.36, 0.36, 0.18, 0.32, -15, -6], [0.26, -0.22, 0.5, 0.22, 0.44, 30, 16]], 121))
// rock mound (1833): a dome of big slabs leaning in on each other round a
// low core, about 0.55 m
model("rock_mound",
  chunk([0, 0, 0.6, 0.36, 0.6, 10, 0], 130),
  [[0.36, 0.04, 0.24, 0.42, 0.56, 90, 10], [0.02, 0.38, 0.56, 0.4, 0.24, 0, 12], [-0.36, 0.06, 0.24, 0.38, 0.5, 90, -10],
    [0.04, -0.36, 0.54, 0.42, 0.24, 0, -10], [0.34, 0.36, 0.34, 0.32, 0.22, 45, 14], [-0.32, -0.32, 0.32, 0.32, 0.22, 45, -12]].map(([x, z, w, h, d, rot, tilt], i) =>
    // each slab tipped in toward the middle
    tf({ pos: [x, 0, z], rot: rot === 90 ? [0, 0, tilt] : [-tilt, rot, 0] }, chunk([0, 0, w, h, d, 0, 0], 132 + i))))
// two big blocks (1836): a pair of big chunks side by side, split by a deep
// crack, a slab leaning on the front of the left one; about 0.55 m
model("rock_blocks",
  chunks([[-0.18, 0.04, 0.56, 0.58, 0.7, 6, 4], [0.27, -0.04, 0.42, 0.52, 0.62, -8, -5]], 141),
  tf({ pos: [-0.1, 0, 0.36], rot: [24, 4, 0] }, chunk([0, 0, 0.42, 0.42, 0.18, 0, 0], 144)))
for (const n of ["rock_heap", "rock_pair", "rock_mound", "rock_blocks"]) looms(n)

// --- sandstone slabs (17, 20, 456, 457 plain; 18, 19, 455 cracked) -----------
// the border row under the back walls: a thick slab of pale sandstone laid on
// a block's top (kind cap: y = 0 is that top), its face a crazy paving of
// flags (the flag loom), its edge rounded over a pale worn rim
function sandSlab(mat, seed) {
  return [
    prismUp(roundSquare(0.505, 0.08, 4, 0.012, seed), 0.03, -0.08, "flagRim", 0.004),
    prismUp(roundSquare(0.5, 0.08, 4, 0.012, seed + 1), 0.1, -0.055, mat, 0.004),
    // the face bulges a little from the rounded rim, like a cushion
    terrain(0.98, 0.98, { res: 24, height: 0.035, fn: cushionFn(0.49, 0.1, 0.09, 0.15, seed), mat, pos: [0, 0.04, 0] })]
}
model("sand_slab", { pivot: "origin" }, sandSlab("flag", 151))
model("sand_slab_cracked", { pivot: "origin" }, sandSlab("flagCrack", 155))
for (const n of ["sand_slab", "sand_slab_cracked"]) looms(n)

// --- timber cages: the scaffolds and broken fences (1863-1865, 1875, 1876,
// 1999, 2000) and loose boards (1867, 1871) ---------------------------------
// one family: a cage of nailed boards filling a cell, empty inside (the dark
// shape in the middle of the retail sprites is the shadow inside the cage,
// owner 2026-10-28: the light makes it here). A flat board at each corner, rails along each
// side (their ends running past the corners, an iron bolt at each end), a
// wide board a storey on every side, zigzagging up. One storey is the broken
// fence, three the scaffold, seven the tall scaffold.
const CE = 0.37, STOREY = 0.4
const bolt = (x, y, z) => tf({ pos: [x, y, z], rot: [90, 0, 0] },
  cyl(0.03, 0.035, { mat: "bolt", sides: 6 }), cyl(0.018, 0.045, { mat: "boltD", sides: 6 }))
// a board lying along x, centred on (x, y) of a face plane at z, turned by a
// degrees in that plane (+ lifts its +x end)
const rail = (x, y, z, len, a, w = 0.1, t = 0.035) => tf({ pos: [x, y, z], rot: [0, 0, a] },
  box(len, w, t, { mat: "board", pos: [0, -w / 2, 0], jitter: 0.004 }),
  bolt(len / 2 - 0.05, 0, t / 2), bolt(-len / 2 + 0.05, 0, t / 2))
// one side of the cage, built along x on the +z face: a wide board per
// storey, near its top, tilted the other way each storey (a zigzag up the
// side), its ends running past the corners. skip leaves boards out (by
// storey); hang adds a fallen board hanging from one bolt
function cageSide(n, seed, { skip = [], hang = null, low = false } = {}) {
  const out = [], z = CE + 0.05
  // the low fence has a second board near the ground
  if (low) out.push(rail((rnd(9, 81, seed) - 0.5) * 0.06, 0.2, z, 0.92 + rnd(9, 82, seed) * 0.08, (rnd(9, 83, seed) - 0.5) * 8, 0.17, 0.05))
  for (let k = 0; k < n; k++) {
    if (skip.includes(k)) continue
    const tilt = ((k + seed) % 2 ? 1 : -1) * (10 + rnd(k, 83, seed) * 12)
    out.push(rail((rnd(k, 81, seed) - 0.5) * 0.08, k * STOREY + STOREY * 0.72, z + (k % 2) * 0.02,
      1.12 + rnd(k, 82, seed) * 0.16, tilt, 0.21, 0.05))
  }
  if (hang) out.push(rail(hang[0], hang[1], z + 0.05, 0.75, hang[2], 0.19, 0.05))
  return out
}
// the corner boards, flat, all facing the camera's way (+x +z); h tall
const cornerPosts = (h, seed) => [[1, 1], [-1, 1], [1, -1], [-1, -1]].map(([sx, sz], i) =>
  tf({ pos: [sx * (CE + 0.1), 0, sz * (CE + 0.1)], rot: [0, 45, (rnd(i, 85, seed) - 0.5) * 4] },
    box(0.16, h + rnd(i, 86, seed) * 0.1, 0.05, { mat: "board", jitter: 0.005 })))
// sides: [rot, options] for the four faces (+z 0, +x 90, -z 180, -x 270)
function cage(n, seed, opts = {}) {
  const h = n * STOREY + 0.06
  return [
    cornerPosts(h, seed),
    [0, 90, 180, 270].map((r, i) => tf({ rot: [0, r, 0] },
      cageSide(n, seed + i, { low: opts.low, ...(opts[r] || {}) }))),
  ]
}
// broken fence (1864): one storey, whole
model("cage_low", cage(1, 171, { low: true }))
// broken fence, more broken (1863, 1865): a rail missing at the back, a top
// rail fallen and hanging from one bolt on the +z face
model("cage_low_broken", cage(1, 175, { 0: { skip: [0], hang: [0.1, 0.3, -24] }, 270: { skip: [0] } }))
// scaffold (1875, 1876): three storeys
model("scaffold", cage(3, 181, { 180: { skip: [1] } }))
// tall scaffold (1999, 2000): seven storeys
model("scaffold_tall", cage(7, 191, { 270: { skip: [2] }, 180: { skip: [4] } }))
// loose cage piece (1867): a corner board with a rail still bolted to it,
// broken off and left standing
model("cage_piece",
  tf({ pos: [-0.18, 0, 0.3], rot: [0, 0, 5] }, box(0.15, 0.6, 0.05, { mat: "board", jitter: 0.005 })),
  tf({ pos: [0.2, 0, 0.32], rot: [0, 0, -4] }, box(0.14, 0.48, 0.05, { mat: "board", jitter: 0.005 })),
  rail(0.0, 0.5, 0.36, 0.62, -8, 0.15, 0.05), rail(0.02, 0.22, 0.36, 0.56, 6, 0.13, 0.05))
// nailed boards (1871): three planks nailed across the face of a pillar,
// leaning on it, the middle one pierced by an iron pipe; stands at the +z
// edge of its cell
model("boards_nailed", { scale: 1.3 },
  tf({ pos: [0, 0, 0.3], rot: [-8, 0, 0] },
    rail(0, 0.86, 0, 0.66, 18, 0.24, 0.06), rail(0.02, 0.6, 0.02, 0.6, -4, 0.26, 0.06), rail(-0.02, 0.32, 0, 0.64, 10, 0.24, 0.06),
    tf({ pos: [0.04, 0.48, 0.05], rot: [90, 0, 0] }, cyl(0.06, 0.12, { mat: "bolt", sides: 10 }), cyl(0.04, 0.13, { mat: "boltD", sides: 10 }))))
for (const n of ["cage_low", "cage_low_broken", "scaffold", "scaffold_tall", "cage_piece", "boards_nailed"]) looms(n)
