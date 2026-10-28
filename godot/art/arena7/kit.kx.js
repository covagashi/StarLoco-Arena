// Arena 7 (retail world 38: a graveyard) — the pieces it doesn't share with
// the other kits, each in three looms: <name> (a), <name>_b, <name>_c. The
// stone surfaces reuse the arena 6 loom textures (build arena6/kit.tx.js
// first); iron and bone use palette colours. Retail gfx in brackets.
include("../common/shapes.kx.js")

const LOOMS = ["", "_b", "_c"]
pal(Object.fromEntries(LOOMS.flatMap((s) => [
  ["stone" + s, { tex: "../arena6/out/stone" + s, uv: 0.9, rough: 0.85 }],
  ["stoneShade" + s, { tex: "../arena6/out/stone" + s, uv: 0.9, rough: 0.85, color: "#e4e0d2" }],
  ["flagCrack" + s, { tex: "../arena6/out/flagCrack" + s, uv: 1, rough: 0.8 }],
])))
// palette looms: [a, b, c] per key
const PAL = {
  // wrought iron of the railings: grey (retail, which the map tints
  // blue-black), rusty, verdigris
  iron: ["#5c6068", "#5e3c2a", "#36463e"], ironL: ["#868b94", "#84553a", "#557064"], ironD: ["#33363c", "#3a2418", "#1f2a24"],
}
pal(Object.fromEntries(LOOMS.flatMap((s, i) => Object.entries(PAL).map(([k, v]) => [k + s, v[i]]))))
const SKINNED = ["stone", "stoneShade", "flagCrack", ...Object.keys(PAL)]
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
