// Arena 8 (retail world 39: a volcano) — loom textures for its own broad
// surfaces, three looms each (mat, mat_b, mat_c). Thin pieces use palette
// colours in kit.kx.js.
const SUF = { a: "", b: "_b", c: "_c" }
const skins = (sets) => {
  for (const [k, s] of Object.entries(sets))
    pal(Object.fromEntries(Object.entries(s).map(([n, v]) => [n + k, v])))
}

// --- pumice: the volcanic floor stones (2285, 2280) -------------------------
// porous volcanic rock, smooth worn skin: broad soft swells, a mid scale of
// thin grooves raked across it by the flow, a few round pits of three sizes
// (the big ones deep and dark), fine grit; the bumps worn paler, the pits
// and grooves dark
//   a warm dark brown (retail, as the map tints it)   b ash grey   c red scoria
skins({
  a: { p0: "#100b08", p1: "#2a2019", p2: "#3e3024", p3: "#5c4834" },
  b: { p0: "#101012", p1: "#303036", p2: "#45454c", p3: "#66666e" },
  c: { p0: "#160906", p1: "#3a1a10", p2: "#522618", p3: "#763e2a" },
})
{
  const swell = noise({ scale: 3, octaves: 3, seed: 801 }).warp(noise({ scale: 2, seed: 802 }), 0.1).as("swell")
  const groove = stripes({ count: 9, soft: 0.2 }).threshold(0.9, 0.05)
    .warp(noise({ scale: 2, octaves: 2, seed: 803 }), 0.12)
    .mul(noise({ scale: 3, seed: 804 }).threshold(0.62, 0.1)).as("groove")
  const pitBig = dots({ scale: 4, radius: 0.13, jitter: 1, soft: 0.05, seed: 805 }).mul(noise({ scale: 2, seed: 806 }).threshold(0.45, 0.1))
  const pitMid = dots({ scale: 9, radius: 0.12, jitter: 1, soft: 0.05, seed: 807 }).mul(noise({ scale: 3, seed: 808 }).threshold(0.6, 0.1))
  const pitFine = dots({ scale: 22, radius: 0.12, jitter: 1, seed: 809 }).mul(noise({ scale: 3, seed: 810 }).threshold(0.7, 0.1))
  const pits = pitBig.max(pitMid.mul(0.85)).max(pitFine.mul(0.5)).as("pits")
  const fine = noise({ scale: 64, octaves: 2, seed: 811 })
  const h = swell.mul(0.35).add(fine.mul(0.06)).sub(groove.mul(0.18)).sub(pits.mul(0.5)).as("pumiceH")
  const worn = h.convex(0.012, 10).mul(groove.blur(0.01).invert()).as("worn")
  const dark = h.cavity(0.006, 10).max(pits.mul(0.9)).max(groove.mul(0.5)).as("grime")
  for (const k of "abc") {
    const col = (n) => n + k
    material("pumice" + SUF[k], { size: 512, depth: 0.03, ao: 0.7 }, {
      height: h,
      color: ramp(swell.levels(0.25, 0.75, 0, 1), [col("p1"), col("p2"), col("p2"), col("p3")])
        .mix(col("p3"), worn.mul(0.45)).mix(col("p0"), dark.mul(0.85)),
      rough: worn.levels(0, 1, 0.88, 0.6).max(pits.mul(0.95)),
    })
  }
}

// --- molten: the lava cells (2270, 2271, 2276-2279) and the lava fall (146) --
// a smooth glowing sheet, not the crusted lava of arena 2: broad slow swells,
// round darker blotches where it cools a little (a few with a paler ring),
// fine shimmer; it glows everywhere, the blotches less
//   a gold-yellow (retail)   b brighter, hotter yellow   c deep red-orange
skins({
  a: { m0: "#d06a0a", m1: "#f0a010", m2: "#ffc21c", m3: "#ffdc50" },
  b: { m0: "#e89018", m1: "#f8b820", m2: "#ffd040", m3: "#ffe680" },
  c: { m0: "#901c06", m1: "#d03c0c", m2: "#f06418", m3: "#ff9440" },
})
{
  const swell = noise({ scale: 3, octaves: 3, seed: 821 }).warp(noise({ scale: 2, seed: 822 }), 0.15).as("swell")
  const blot = dots({ scale: 3, radius: 0.32, jitter: 1, soft: 0.35, seed: 823 })
    .max(dots({ scale: 9, radius: 0.18, jitter: 1, soft: 0.35, seed: 824 }).mul(0.75))
    .mul(noise({ scale: 2, seed: 825 }).threshold(0.25, 0.2)).as("blot")
  const ring = dots({ scale: 4, radius: 0.2, jitter: 1, soft: 0.05, seed: 823 }).sub(dots({ scale: 4, radius: 0.16, jitter: 1, soft: 0.05, seed: 823 }))
    .clamp(0, 1).mul(noise({ scale: 3, seed: 826 }).threshold(0.6, 0.1)).as("ring")
  const fine = noise({ scale: 40, octaves: 2, seed: 827 })
  const h = swell.mul(0.4).sub(blot.mul(0.25)).add(ring.mul(0.15)).add(fine.mul(0.05)).as("moltenH")
  for (const k of "abc") {
    const col = (n) => n + k
    const hot = ramp(swell.mix(fine, 0.15).levels(0.2, 0.8, 0, 1), [col("m1"), col("m2"), col("m2"), col("m3")])
      .mix(col("m0"), blot).mix(col("m3"), ring.mul(0.6))
    material("molten" + SUF[k], { size: 512, depth: 0.012, ao: 0.2 }, {
      height: h,
      color: hot,
      rough: blot.mix(0.2, 0.5),
      emit: hot.mul(0.4),
    })
  }
}
