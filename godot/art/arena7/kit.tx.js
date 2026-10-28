// Arena 7 (retail world 38: a graveyard) — loom textures for its own broad
// surfaces, three looms each (mat, mat_b, mat_c). The stones reuse the arena 6
// textures; thin pieces use palette colours in kit.kx.js.
const SUF = { a: "", b: "_b", c: "_c" }
const skins = (sets) => {
  for (const [k, s] of Object.entries(sets))
    pal(Object.fromEntries(Object.entries(s).map(([n, v]) => [n + k, v])))
}

// --- dry earth: the earth slabs of the floor (263, 266-268, 1526, 1527, 1532,
// 1533) ---------------------------------------------------------------------
// packed, dried earth: broad soft blotches, a mid scale of lumps and smears,
// fine grit, a few pressed-in pebbles and hairline cracks; dust paler on the
// bumps, darker in the hollows
//   a tan earth (retail)   b cool grey-brown   c dark red clay
skins({
  a: { e0: "#42362a", e1: "#6c5c44", e2: "#8a785a", e3: "#a89676" },
  b: { e0: "#34302a", e1: "#5c564a", e2: "#7a7262", e3: "#9c9480" },
  c: { e0: "#3a241c", e1: "#5e3c2e", e2: "#7a5240", e3: "#966a56" },
})
{
  const blot = noise({ scale: 3, octaves: 3, seed: 701 }).warp(noise({ scale: 2, seed: 702 }), 0.12).as("blot")
  const mid = noise({ scale: 10, octaves: 3, seed: 703 }).as("lumps")
  const fine = noise({ scale: 60, octaves: 2, seed: 704 })
  const pebbles = dots({ scale: 7, radius: 0.1, jitter: 1, seed: 705 }).mul(noise({ scale: 3, seed: 706 }).threshold(0.55, 0.2)).as("pebbles")
  const crack = cells({ scale: 5, jitter: 0.9, seed: 707 }).edge.invert().threshold(0.96, 0.02)
    .mul(noise({ scale: 3, seed: 708 }).threshold(0.64, 0.12)).as("crack")
  const h = blot.mul(0.3).add(mid.mul(0.35)).add(fine.mul(0.1)).add(pebbles.mul(0.1)).sub(crack.mul(0.3)).as("dirtH")
  const dust = h.convex(0.01, 10).as("dust")
  const dirt = h.cavity(0.008, 10).as("grime")
  for (const k of "abc") {
    const col = (n) => n + k
    material("dirt" + SUF[k], { size: 512, depth: 0.02, ao: 0.6 }, {
      height: h,
      color: ramp(blot.mix(mid, 0.45).levels(0.3, 0.7, 0, 1), [col("e1"), col("e2"), col("e2"), col("e3")])
        .mix(col("e3"), dust.mul(0.4)).mix(col("e1"), pebbles.mul(0.35)).mix(col("e0"), dirt.mul(0.6)).mix(col("e0"), crack.mul(0.8)),
      rough: dust.levels(0, 1, 0.92, 0.8),
    })
  }
}
