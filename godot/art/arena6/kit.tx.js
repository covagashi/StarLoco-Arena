// Arena 6 (retail world 36: a floating meadow, ruins and scaffolds) — loom
// textures for the broad surfaces, three looms each (mat, mat_b, mat_c).
// Thin pieces (moss tufts, petals, blades) use palette colours in kit.kx.js.
const SUF = { a: "", b: "_b", c: "_c" }
const skins = (sets) => {
  for (const [k, s] of Object.entries(sets))
    pal(Object.fromEntries(Object.entries(s).map(([n, v]) => [n + k, v])))
}

// --- dressed stone: the stacked blocks and pillars (1381, 1565, 1650, 1472) --
// a soft, worn sandstone: broad blotches of tone, shallow pits, a few fine
// hairline cracks, chips paler at their rims; moss (the _moss version) creeps
// in from the cracks and pits in patches, olive-yellow
//   a cream-olive sandstone (retail)   b cool grey granite   c warm red sandstone
skins({
  a: { r0: "#3e3828", r1: "#7a7150", r2: "#a29870", r3: "#d0c596", m0: "#5e6612", m1: "#93a21e", m2: "#c2cc3a" },
  b: { r0: "#323436", r1: "#64676a", r2: "#888b8c", r3: "#b0b2b0", m0: "#2e4a1e", m1: "#4e7a2c", m2: "#7eaa44" },
  c: { r0: "#3e2a20", r1: "#7a5442", r2: "#9a7058", r3: "#bc967a", m0: "#5a5a16", m1: "#8a8a26", m2: "#b4b444" },
})
{
  const blot = noise({ scale: 3, octaves: 3, seed: 601 }).warp(noise({ scale: 2, seed: 602 }), 0.15).as("blot")
  const mid = noise({ scale: 9, octaves: 3, seed: 603 }).as("mid")
  const fine = noise({ scale: 56, octaves: 2, seed: 604 })
  const crack = cells({ scale: 4, jitter: 1, seed: 605 }).edge.threshold(0.03, 0.03).invert()
    .mul(noise({ scale: 3, seed: 606 }).threshold(0.7, 0.1)).blur(0.003).as("crack")
  const pits = dots({ scale: 14, radius: 0.07, jitter: 1, seed: 607 }).mul(noise({ scale: 4, seed: 608 }).threshold(0.5, 0.2)).as("pits")
  const h = blot.mul(0.35).add(mid.mul(0.35)).add(fine.mul(0.08)).sub(crack.mul(0.35)).sub(pits.mul(0.18)).as("stoneH")
  const dirt = h.cavity(0.008, 10).as("stoneDirt")
  const worn = h.convex(0.01, 10).as("worn")
  // moss: grows out of the cavities, in patches, densest where the patch noise peaks
  const patch = noise({ scale: 3, octaves: 2, seed: 609 }).warp(noise({ scale: 6, seed: 610 }), 0.1)
  const moss = patch.threshold(0.62, 0.06).max(dirt.mul(patch.threshold(0.45, 0.1)).mul(1.6)).clamp(0, 1)
    .mul(noise({ scale: 30, octaves: 2, seed: 611 }).levels(0, 1, 0.55, 1)).as("moss")
  for (const k of "abc") {
    const col = (n) => n + k
    const stone = ramp(blot.mix(mid, 0.45).levels(0.25, 0.75, 0, 1), [col("r1"), col("r2"), col("r2"), col("r3")])
      .mix(col("r0"), dirt.mul(0.55)).mix(col("r0"), crack.mul(0.45)).mix(col("r3"), worn.mul(0.35))
    const rough = fine.levels(0, 1, 0.78, 0.9).mix(0.95, dirt.mul(0.5))
    material("stone" + SUF[k], { size: 512, depth: 0.025, ao: 0.6 }, { height: h, color: stone, rough })
    material("stoneMoss" + SUF[k], { size: 512, depth: 0.025, ao: 0.6 }, {
      height: h.add(moss.mul(0.12)),
      color: stone.mix(ramp(mid.mix(fine, 0.4), [col("m0"), col("m1"), col("m2")]), moss),
      rough: rough.mix(0.95, moss),
    })
  }
}
