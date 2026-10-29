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
