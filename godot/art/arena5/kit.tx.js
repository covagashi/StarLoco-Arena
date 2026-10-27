// Arena 5 (retail world 21: meadow, ruins of a house) — loom textures for the
// broad surfaces, three looms each (mat, mat_b, mat_c). Thin pieces (blades,
// fringes) use palette colours in kit.kx.js.
const SUF = { a: "", b: "_b", c: "_c" }
const skins = (sets) => {
  for (const [k, s] of Object.entries(sets))
    pal(Object.fromEntries(Object.entries(s).map(([n, v]) => [n + k, v])))
}

// --- grass: the top of the grass block (315, 316, 317), seen from above -----
// clumps of blades (cells, each a tuft brighter at its heart), long strokes
// laid in every direction by warped stretched noise, fine grit; the light
// tips on the high strokes, dark soil peeking in the deep gaps between tufts
//   a fresh yellow-green (retail)   b deep meadow green   c dry, golden
skins({
  a: { g0: "#2e3a0c", g1: "#5e7a14", g2: "#8fae1e", g3: "#c4dc3c", gs: "#4a3a1c" },
  b: { g0: "#173018", g1: "#2f6026", g2: "#4f8a34", g3: "#86bc52", gs: "#3a2e1c" },
  c: { g0: "#3a3010", g1: "#7a6a24", g2: "#a8963a", g3: "#d8c866", gs: "#4e3a1e" },
})
{
  const tufts = cells({ scale: 9, jitter: 0.9, seed: 501 })
  const clump = tufts.invert().smooth(0.15, 1).mul(tufts.id.levels(0, 1, 0.75, 1)).blur(0.004).as("clump")
  const strokeA = noise({ scale: [12, 44], octaves: 3, seed: 502 }).warp(noise({ scale: 5, seed: 503 }), 0.3)
  const strokeB = noise({ scale: [44, 12], octaves: 3, seed: 504 }).warp(noise({ scale: 5, seed: 505 }), 0.3)
  const strokes = strokeA.max(strokeB).levels(0.35, 1, 0, 1).as("strokes")
  const fine = noise({ scale: 48, octaves: 2, seed: 506 })
  const h = clump.mul(0.4).add(strokes.mul(0.5)).add(fine.mul(0.1)).as("grassH")
  const gap = h.invert().threshold(0.86, 0.05).mul(noise({ scale: 5, seed: 507 }).threshold(0.55, 0.1)).as("gap")
  const tips = h.convex(0.006, 8).mul(strokes).as("tips")
  for (const k of "abc") {
    const col = (n) => n + k
    material("grass" + SUF[k], { size: 512, depth: 0.03, ao: 0.7 }, {
      height: h,
      color: ramp(h.mix(tufts.id, 0.2), [col("g1"), col("g1"), col("g2"), col("g3")]).hsv({ h: tufts.id.levels(0, 1, -6, 6) })
        .mix(col("g0"), h.cavity(0.006, 8).mul(0.5)).mix(col("gs"), gap.mul(0.5)).mix(col("g3"), tips.mul(0.5)),
      rough: fine.levels(0, 1, 0.7, 0.85).mix(0.95, gap).mix(0.55, tips),
    })
  }
}

// --- soil: the earth under the grass and the dirt block (233) ---------------
// horizontal strata of packed earth and sand (wavy bands), each band its own
// tone, pebbles and roots in the dark bands, fine grit; light sandy ledges
// where a band stands proud
//   a sandy ochre (retail)   b dark loam   c red clay
skins({
  a: { s0: "#3a2a14", s1: "#7a5a30", s2: "#a8844a", s3: "#d2b070" },
  b: { s0: "#1e160e", s1: "#4a3622", s2: "#6a5034", s3: "#8e7050" },
  c: { s0: "#30140c", s1: "#7a3a22", s2: "#a85a36", s3: "#cc8456" },
})
{
  const bands = waves({ count: 3, dir: "h", warp: 0.9, scale: 2, seed: 511 }).as("bands")
  const band2 = waves({ count: 7, dir: "h", warp: 1.2, scale: 3, seed: 512 }).mul(noise({ scale: 3, seed: 517 }).threshold(0.45, 0.2))
  const mid = noise({ scale: 6, octaves: 4, seed: 513 }).warp(noise({ scale: 2, seed: 514 }), 0.05).as("soilMid")
  const fine = noise({ scale: 40, octaves: 3, seed: 515 })
  const stones = dots({ scale: 7, radius: 0.16, jitter: 1, seed: 516 }).mul(bands.invert().threshold(0.6, 0.15)).mul(noise({ scale: 4, seed: 518 }).threshold(0.5, 0.15)).as("stones")
  const h = bands.mul(0.5).add(band2.mul(0.18)).add(mid.mul(0.2)).add(fine.mul(0.06)).add(stones.mul(0.2)).as("soilH")
  const dirt = h.cavity(0.008, 10).as("soilDirt")
  const ledge = h.convex(0.008, 10).as("ledge")
  for (const k of "abc") {
    const col = (n) => n + k
    material("soil" + SUF[k], { size: 512, depth: 0.03, ao: 0.7 }, {
      height: h,
      color: ramp(bands.mix(mid, 0.35).mix(band2, 0.2), [col("s1"), col("s2"), col("s3")])
        .mix(col("s0"), dirt.mul(0.6)).mix(col("s1"), stones.mul(0.6)).mix(col("s3"), ledge.mul(0.35)),
      rough: fine.levels(0, 1, 0.78, 0.92).mix(0.97, dirt).mix(0.7, ledge),
    })
  }
}
