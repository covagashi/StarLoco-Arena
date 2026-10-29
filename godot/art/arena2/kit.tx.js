// Arena 2 (retail world 10: autumn and lava) — loom textures for the broad
// surfaces, three looms each (mat, mat_b, mat_c). Plants and weapons use
// palette colours in kit.kx.js (thin shapes smear box-projected textures).
const SUF = { a: "", b: "_b", c: "_c" }
const skins = (sets) => {
  for (const [k, s] of Object.entries(sets))
    pal(Object.fromEntries(Object.entries(s).map(([n, v]) => [n + k, v])))
}

// --- crag: the brown rock blocks (1240-1244) and the rock column (921) -------
// big fractured plates (cells edges as ridges), plates vary in tone, deep dark
// cracks, chipped bright rims, fine grit
//   a earth brown   b lava-lit red   c ash grey
skins({
  a: { k0: "#1f140c", k1: "#4a3220", k2: "#6b4a2e", k3: "#8e6a44" },
  b: { k0: "#250c08", k1: "#5e2416", k2: "#8a3a22", k3: "#b85a34" },
  c: { k0: "#141414", k1: "#3a3735", k2: "#57524e", k3: "#7a746d" },
})
{
  const c = cells({ scale: 2, jitter: 0.9, seed: 201 })
  const plates = c.edge.smooth(0.012, 0.16).as("plates")
  const mid = noise({ scale: 6, octaves: 4, seed: 202 }).warp(noise({ scale: 3, seed: 203 }), 0.06).as("cragMid")
  const fine = noise({ scale: 28, octaves: 3, seed: 204 })
  const crack = plates.invert().threshold(0.75, 0.15)
    .max(ridged({ scale: 5, octaves: 2, seed: 205 }).threshold(0.93, 0.03).mul(noise({ scale: 3, seed: 206 }).threshold(0.5, 0.2))).as("crack")
  const h = plates.mul(c.id.levels(0, 1, 0.7, 1)).mul(0.75).add(mid.mul(0.18)).add(fine.mul(0.05)).sub(crack.mul(0.12)).as("cragH")
  const rim = h.convex(0.008, 10).as("cragRim")
  for (const k of "abc") {
    const col = (n) => n + k
    material("crag" + SUF[k], { size: 512, depth: 0.04, ao: 0.8 }, {
      height: h,
      color: ramp(c.id.mix(mid, 0.4), [col("k1"), col("k2"), col("k3")]).hsv({ h: c.id.levels(0, 1, -6, 6) })
        .mix(col("k0"), crack.mul(0.85)).mix(col("k3"), rim.mul(0.4)),
      rough: fine.levels(0, 1, 0.72, 0.9).mix(0.95, crack).mix(0.6, rim),
    })
  }
}

// --- flagstone: the low green slabs (129-131), a few big worn plates ---------
//   a sage green   b sandstone   c slate
skins({
  a: { f0: "#2a3a2c", f1: "#5d7a5c", f2: "#7f9a78", f3: "#a8bf9c" },
  b: { f0: "#4a3c26", f1: "#9a8458", f2: "#b9a270", f3: "#d8c79a" },
  c: { f0: "#1e2430", f1: "#4a5568", f2: "#667388", f3: "#8f9bb0" },
})
{
  const c = cells({ scale: 3, jitter: 0.8, seed: 211 })
  const plates = c.edge.smooth(0.015, 0.12).as("flagPlates")
  const mid = noise({ scale: 5, octaves: 4, seed: 212 }).warp(noise({ scale: 2, seed: 213 }), 0.05).as("flagMid")
  const fine = noise({ scale: 26, octaves: 3, seed: 214 })
  const h = plates.mul(c.id.levels(0, 1, 0.85, 1)).mul(0.7).add(mid.mul(0.22)).add(fine.mul(0.05)).as("flagH")
  const joint = plates.invert().threshold(0.7, 0.2)
  for (const k of "abc") {
    const col = (n) => n + k
    material("flag" + SUF[k], { size: 512, depth: 0.025, ao: 0.6 }, {
      height: h,
      color: ramp(c.id.mix(mid, 0.5), [col("f1"), col("f2"), col("f3")]).mix(col("f0"), joint.mul(0.75))
        .mix(col("f0"), h.cavity(0.01, 12).mul(0.35)),
      rough: fine.levels(0, 1, 0.65, 0.85).mix(0.92, joint),
    })
  }
}

// --- carved stone (the totems 274, 275): soft weathered stone, moss in the
// carvings facing up
//   a mossy sandstone   b grey   c red stone
skins({
  a: { t0: "#3e3a22", t1: "#9a8d5a", t2: "#b8aa72", t3: "#d6c993", tm: "#7a9a3a" },
  b: { t0: "#2c2c2e", t1: "#77777a", t2: "#98989a", t3: "#bcbcbc", tm: "#6a8a4a" },
  c: { t0: "#3a1c14", t1: "#8e4a32", t2: "#b06a48", t3: "#d0906a", tm: "#8a9a3a" },
})
{
  const mid = noise({ scale: 5, octaves: 4, seed: 231 }).warp(noise({ scale: 2, seed: 232 }), 0.06).as("totMid")
  const fine = noise({ scale: 24, octaves: 3, seed: 233 })
  const pits = ridged({ scale: 4, octaves: 2, seed: 234 }).threshold(0.94, 0.03).mul(noise({ scale: 3, seed: 236 }).threshold(0.5, 0.2)).as("totPits")
  const h = mid.mul(0.7).add(fine.mul(0.15)).sub(pits.mul(0.2)).as("totH")
  const moss = h.facing("up", 4).mul(noise({ scale: 6, seed: 235 }).threshold(0.55, 0.15)).as("totMoss")
  for (const k of "abc") {
    const col = (n) => n + k
    material("totem" + SUF[k], { size: 512, depth: 0.025, ao: 0.6 }, {
      height: h,
      color: ramp(mid, [col("t1"), col("t2"), col("t3")]).mix(col("t0"), pits.max(h.cavity(0.01, 10)).mul(0.6)).mix(col("tm"), moss.mul(0.8)),
      rough: fine.levels(0, 1, 0.7, 0.88).mix(0.9, moss),
    })
  }
}
