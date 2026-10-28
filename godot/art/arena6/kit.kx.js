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
  // the moss-washed stones of the mossy cap (1472): the mossy stone, greener
  ["stoneGreen" + s, { tex: "out/stoneMoss" + s, uv: 0.9, rough: 0.9, color: ["#c4cc98", "#a8bca0", "#c8c496"][LOOMS.indexOf(s)] }],
])))
// palette looms: [a, b, c] per key, matching the stone looms
const PAL = {
  // moss cushions on the stones: olive-yellow (retail), deep green, dry olive
  mossD: ["#5e6a12", "#24441c", "#5a5216"], moss: ["#94a41c", "#3e6e2a", "#8a8226"], mossL: ["#c4d038", "#6a9a3e", "#b8ac44"],
  // the small white flowers on the mossy cap (1472): white (retail), pale
  // yellow, pink; a yellow heart
  petal: ["#f4f2ea", "#f4e8a8", "#f0b8c8"], petalD: ["#c8c4b8", "#d0c070", "#c88098"], heart: ["#e8c030", "#d08a20", "#f0d050"],
}
pal(Object.fromEntries(LOOMS.flatMap((s, i) => Object.entries(PAL).map(([k, v]) => [k + s, v[i]]))))
const SKINNED = ["stone", "stoneMoss", "stoneGreen", ...Object.keys(PAL)]
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
