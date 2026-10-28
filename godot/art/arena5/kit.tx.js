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

// --- earth: the packed dark top of the dirt block (233) ---------------------
// no strata: trodden earth, mottled, small stones pressed in, thin dry cracks
// and lighter dust on the high spots
//   a dark olive earth (retail)   b black loam   c dark red clay
skins({
  a: { e0: "#241c10", e1: "#4a3e24", e2: "#62553a", e3: "#857652" },
  b: { e0: "#110d09", e1: "#2a2219", e2: "#3c3226", e3: "#584a3a" },
  c: { e0: "#200c08", e1: "#4a2618", e2: "#643626", e3: "#8a5440" },
})
{
  const mid = noise({ scale: 5, octaves: 4, seed: 521 }).warp(noise({ scale: 2, seed: 522 }), 0.08).as("earthMid")
  const fine = noise({ scale: 36, octaves: 3, seed: 523 })
  const stones = dots({ scale: 10, radius: 0.12, jitter: 1, seed: 524 }).mul(noise({ scale: 3, seed: 525 }).threshold(0.5, 0.2)).as("earthStones")
  const crack = cells({ scale: 4, jitter: 0.9, seed: 526 }).edge.invert().threshold(0.95, 0.02).mul(noise({ scale: 3, seed: 527 }).threshold(0.6, 0.15)).as("earthCrack")
  const h = mid.mul(0.6).add(fine.mul(0.15)).add(stones.mul(0.3)).sub(crack.mul(0.2)).as("earthH")
  const dust = h.convex(0.01, 10).as("earthDust")
  for (const k of "abc") {
    const col = (n) => n + k
    material("earth" + SUF[k], { size: 512, depth: 0.02, ao: 0.6 }, {
      height: h,
      color: ramp(mid, [col("e1"), col("e2"), col("e3")]).mix(col("e0"), crack.mul(0.55).max(h.cavity(0.008, 10).mul(0.4))).mix(col("e3"), stones.mul(0.5)).mix(col("e3"), dust.mul(0.3)),
      rough: fine.levels(0, 1, 0.8, 0.95).mix(0.7, stones),
    })
  }
}

// --- plaster: the house walls (179, 181) -------------------------------------
// lime plaster over stone: broad soft patches where it was re-plastered (big
// warped cells, each its own tone), worn hollows, a few fine cracks, grime
// and a little moss low down is the model's job (a separate band)
//   a cream (retail)   b white-grey (the map's tint)   c warm ochre
skins({
  a: { p0: "#6e6444", p1: "#bfb486", p2: "#ddd3a6", p3: "#f0e8c4" },
  b: { p0: "#5a6070", p1: "#b4bac4", p2: "#d4d8de", p3: "#eef0f2" },
  c: { p0: "#7a5430", p1: "#c49a5e", p2: "#dcb67c", p3: "#eed09c" },
})
{
  // soft blotches, no hard edges (warped noise in two bands of tone)
  const blot = noise({ scale: 3, octaves: 3, seed: 531 }).warp(noise({ scale: 2, seed: 537 }), 0.15)
  const patches = blot.threshold(0.5, 0.06).as("patches")
  const mid = noise({ scale: 6, octaves: 4, seed: 532 }).warp(noise({ scale: 2, seed: 533 }), 0.1).as("plMid")
  const fine = noise({ scale: 44, octaves: 3, seed: 534 })
  const crack = ridged({ scale: 3, octaves: 3, seed: 535 }).threshold(0.965, 0.01).mul(noise({ scale: 3, seed: 536 }).threshold(0.65, 0.1)).as("plCrack")
  const h = patches.mul(0.12).add(mid.mul(0.6)).add(fine.mul(0.1)).sub(crack.mul(0.1)).as("plH")
  const hollow = h.cavity(0.012, 10).as("plHollow")
  for (const k of "abc") {
    const col = (n) => n + k
    material("plaster" + SUF[k], { size: 512, depth: 0.015, ao: 0.5 }, {
      height: h,
      color: ramp(patches.mul(0.6).add(mid.mul(0.4)), [col("p1"), col("p2"), col("p3")]).mix(col("p0"), crack.mul(0.5).max(hollow.mul(0.3))),
      rough: fine.levels(0, 1, 0.82, 0.95),
    })
  }
}

// --- timber: the beams and the water channel on the walls --------------------
// long grain along the beam (stretched warped noise), rings, a few dark
// knots, weathered pale on the raised grain
//   a olive tan (retail)   b weathered grey   c dark brown
skins({
  a: { t0: "#3a3018", t1: "#6e5e34", t2: "#958250", t3: "#bba870" },
  b: { t0: "#2e2c28", t1: "#5e5a52", t2: "#837e74", t3: "#a8a296" },
  c: { t0: "#1e140c", t1: "#45301e", t2: "#5e432a", t3: "#7e5e3e" },
})
{
  const grain = noise({ scale: [2, 30], octaves: 4, seed: 541 }).warp(noise({ scale: 3, seed: 542 }), 0.05).as("tGrain")
  const rings = waves({ count: 6, dir: "h", warp: 0.6, scale: 3, seed: 543 }).as("tRings")
  const fine = noise({ scale: 40, octaves: 2, seed: 544 })
  const knots = dots({ scale: 4, radius: 0.08, jitter: 1, seed: 545 }).mul(noise({ scale: 2, seed: 546 }).threshold(0.6, 0.1)).as("tKnots")
  const h = grain.mul(0.6).add(rings.mul(0.25)).add(fine.mul(0.08)).sub(knots.mul(0.3)).as("tH")
  for (const k of "abc") {
    const col = (n) => n + k
    material("timber" + SUF[k], { size: 256, depth: 0.02, ao: 0.5 }, {
      height: h,
      color: ramp(grain.mix(rings, 0.3), [col("t1"), col("t2"), col("t3")]).mix(col("t0"), knots.mul(0.8).max(h.cavity(0.01, 8).mul(0.4))),
      rough: fine.levels(0, 1, 0.75, 0.9),
    })
  }
}

// --- cobble: the paving stones set in the white slabs (183, 184) -------------
// worn smooth river stone: soft mottling, a few dark pits, fine speckle, the
// edges a little darker where dirt lodges (the model rounds the stones)
//   a sage grey (retail)   b blue slate   c warm brown
skins({
  a: { c0: "#4e5444", c1: "#8a9078", c2: "#a6ab92", c3: "#c2c6ae" },
  b: { c0: "#3a4250", c1: "#6e7a8c", c2: "#8a96a6", c3: "#a8b2c0" },
  c: { c0: "#4a3626", c1: "#8a6a4c", c2: "#a6845e", c3: "#c2a07a" },
})
{
  const mid = noise({ scale: 4, octaves: 4, seed: 551 }).warp(noise({ scale: 2, seed: 552 }), 0.08).as("cobMid")
  const speck = noise({ scale: 60, octaves: 2, seed: 553 }).threshold(0.68, 0.05).as("cobSpeck")
  const pits = dots({ scale: 12, radius: 0.08, jitter: 1, seed: 554 }).mul(noise({ scale: 3, seed: 555 }).threshold(0.6, 0.1)).as("cobPits")
  const h = mid.mul(0.8).add(noise({ scale: 24, octaves: 2, seed: 556 }).mul(0.1)).sub(pits.mul(0.25)).as("cobH")
  for (const k of "abc") {
    const col = (n) => n + k
    material("cobble" + SUF[k], { size: 256, depth: 0.012, ao: 0.4 }, {
      height: h,
      color: ramp(mid, [col("c1"), col("c2"), col("c3")]).mix(col("c0"), pits.mul(0.7).max(speck.mul(0.25))),
      rough: mid.levels(0, 1, 0.55, 0.75).mix(0.9, pits),
    })
  }
}
