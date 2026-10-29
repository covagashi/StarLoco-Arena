// Arena 10 (retail world 41: a butcher's kitchen) — loom textures for its own
// broad surfaces, three looms each (mat, mat_b, mat_c).
const SUF = { a: "", b: "_b", c: "_c" }
const skins = (sets) => {
  for (const [k, s] of Object.entries(sets))
    pal(Object.fromEntries(Object.entries(s).map(([n, v]) => [n + k, v])))
}

// --- paver: the fired bricks of the kitchen floor (2736) ----------------------
// a smooth fired clay face: broad soft clouds of tone, a mid scale of worn
// smears and shallow chips, fine grit and a few pin holes; paler where it is
// worn high, a little grime in the hollows. Kept light: kit.kx.js tints the
// bricks darker than the joints.
//   a cream (retail)   b grey slate   c terracotta
skins({
  a: { p0: "#8c8466", p1: "#cfc6a2", p2: "#e2dab8", p3: "#f2ecd2" },
  b: { p0: "#5e605e", p1: "#a6a8a4", p2: "#bebfba", p3: "#d4d4ce" },
  c: { p0: "#7a3e28", p1: "#c47a56", p2: "#d6906a", p3: "#e6a882" },
})
{
  const cloud = noise({ scale: 3, octaves: 3, seed: 1001 }).warp(noise({ scale: 2, seed: 1002 }), 0.15).as("cloud")
  const smear = noise({ scale: 11, octaves: 3, seed: 1003 }).warp(noise({ scale: 5, seed: 1004 }), 0.08).as("smear")
  const fine = noise({ scale: 70, octaves: 2, seed: 1005 })
  const chips = dots({ scale: 9, radius: 0.18, jitter: 1, soft: 0.3, seed: 1006 })
    .mul(noise({ scale: 4, seed: 1007 }).threshold(0.62, 0.1)).as("chips")
  const pins = dots({ scale: 22, radius: 0.08, jitter: 1, seed: 1008 }).mul(noise({ scale: 3, seed: 1009 }).threshold(0.5, 0.2)).as("pins")
  const h = cloud.mul(0.25).add(smear.mul(0.3)).add(fine.mul(0.08)).sub(chips.mul(0.2)).sub(pins.mul(0.12)).as("paverH")
  const worn = h.convex(0.01, 10).as("worn")
  const grime = h.cavity(0.008, 10).max(chips.mul(0.5)).as("grime")
  for (const k of "abc") {
    const col = (n) => n + k
    material("paver" + SUF[k], { size: 512, depth: 0.012, ao: 0.5 }, {
      height: h,
      color: ramp(cloud.mix(smear, 0.4).levels(0.3, 0.7, 0, 1), [col("p1"), col("p2"), col("p2"), col("p3")])
        .mix(col("p3"), worn.mul(0.35)).mix(col("p0"), grime.mul(0.45)).mix(col("p0"), pins.mul(0.5)),
      rough: worn.levels(0, 1, 0.85, 0.6),
    })
  }
}
