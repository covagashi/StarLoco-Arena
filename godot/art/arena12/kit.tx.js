// Arena 12 (retail world 44: a swamp) — loom textures for its own broad
// surfaces, three looms each (mat, mat_b, mat_c). The planks reuse arena 6's
// board loom; thin pieces use palette colours in kit.kx.js.
const SUF = { a: "", b: "_b", c: "_c" }
const skins = (sets) => {
  for (const [k, s] of Object.entries(sets))
    pal(Object.fromEntries(Object.entries(s).map(([n, v]) => [n + k, v])))
}

// --- peat: the moss-grown earth block under every cell (619) -----------------
// soft cushions of moss packed together, each one rounded and paler on its
// crown, the gaps between them dark; a mid scale of tufts and dents and a
// fine fibre over all; a few green patches. peatSide is the same moss hanging
// down the block's sides: the cushions stretched into streaks along v.
//   a ochre moss (retail)   b green moss   c rust peat
skins({
  a: { q0: "#5a4e22", q1: "#86783a", q2: "#a69650", q3: "#c8b86e", g0: "#76802c" },
  b: { q0: "#3e5030", q1: "#56703e", q2: "#6c8650", q3: "#8ea46a", g0: "#8a9a4a" },
  c: { q0: "#523626", q1: "#6e4c34", q2: "#886046", q3: "#a8805e", g0: "#76703a" },
})
{
  for (const [name, sc] of [["peat", (s) => s], ["peatSide", (s) => [s, Math.max(1, Math.round(s / 4))]]]) {
    const cc = cells({ scale: sc(6), jitter: 0.9, seed: 1201 })
    const cush = cc.warp(noise({ scale: sc(5), seed: 1206 }), 0.04).as("cushion")
    const crown = cush.invert().levels(0.2, 1, 0, 1).pow(0.8).blur(0.006).as("crown")
    const gap = cc.edge.warp(noise({ scale: sc(5), seed: 1206 }), 0.04).invert().threshold(0.82, 0.14).blur(0.006).as("gap")
    const tufts = noise({ scale: sc(16), octaves: 3, seed: 1202 }).warp(noise({ scale: sc(6), seed: 1203 }), 0.1).as("tufts")
    const fibre = noise({ scale: sc(70), octaves: 2, seed: 1204 })
    const green = noise({ scale: sc(3), octaves: 2, seed: 1205 }).threshold(0.62, 0.12).as("green")
    const h = crown.mul(0.45).add(tufts.mul(0.3)).add(fibre.mul(0.1)).sub(gap.mul(0.12)).as("peatH")
    const shade = h.cavity(0.012, 10).max(gap.mul(0.25)).as("shade")
    for (const k of "abc") {
      const col = (n) => n + k
      material(name + SUF[k], { size: 512, depth: 0.03, ao: 0.5 }, {
        height: h,
        color: ramp(crown.mix(tufts, 0.4), [col("q1"), col("q2"), col("q2"), col("q3")])
          .mix(col("g0"), green.mul(0.35)).mix(col("q0"), shade.mul(0.7)),
        rough: crown.levels(0, 1, 0.95, 0.8),
      })
    }
  }
}

// --- mud: the swamp slabs (2654-2657, 2659, 2660, 2692, 1501) ----------------
// thick wet mud: smooth broad swells, winding pale ridges where it was pushed
// up (the retail draws them as cream crests), a darker trough beside each
// ridge, a mid scale of smears and dimples and fine silt; wetter (glossier)
// in the hollows
//   a ochre mud (retail)   b grey silt   c red clay
skins({
  a: { d0: "#3e3218", d1: "#6a5830", d2: "#806c3e", d3: "#a8945e" },
  b: { d0: "#34322c", d1: "#5c5a50", d2: "#76736a", d3: "#a6a296" },
  c: { d0: "#40201a", d1: "#6e3c2c", d2: "#8a5038", d3: "#b67c5e" },
})
{
  const swell = noise({ scale: 2, octaves: 3, seed: 1211 }).warp(noise({ scale: 2, seed: 1212 }), 0.2).as("swell")
  const ridge = ridged({ scale: 3, octaves: 1, seed: 1213 }).warp(noise({ scale: 3, seed: 1214 }), 0.12)
    .levels(0.78, 0.97, 0, 1).mul(noise({ scale: 2, seed: 1215 }).levels(0.3, 0.6, 0, 1)).blur(0.004).as("ridge")
  const trough = ridge.blur(0.02).sub(ridge).max(0).levels(0, 0.25, 0, 1).as("trough")
  const smear = noise({ scale: 9, octaves: 3, seed: 1216 }).warp(noise({ scale: 4, seed: 1217 }), 0.1).as("smear")
  const dimple = dots({ scale: 12, radius: 0.12, jitter: 1, soft: 0.4, seed: 1218 }).mul(noise({ scale: 3, seed: 1219 }).threshold(0.55, 0.2)).as("dimple")
  const silt = noise({ scale: 64, octaves: 2, seed: 1220 })
  const h = swell.mul(0.3).add(ridge.mul(0.35)).sub(trough.mul(0.15)).add(smear.mul(0.15)).sub(dimple.mul(0.1)).add(silt.mul(0.04)).as("mudH")
  const wet = h.cavity(0.012, 10).max(trough.mul(0.6)).as("wet")
  for (const k of "abc") {
    const col = (n) => n + k
    material("mud" + SUF[k], { size: 512, depth: 0.02, ao: 0.6 }, {
      height: h,
      color: ramp(swell.mix(smear, 0.4).levels(0.3, 0.7, 0, 1), [col("d1"), col("d2"), col("d2"), col("d3")])
        .mix(col("d3"), ridge.mul(0.45)).mix(col("d0"), wet.mul(0.55)).mix(col("d0"), dimple.mul(0.3)),
      rough: wet.levels(0, 1, 0.75, 0.3),
    })
  }
}

// --- duckweed: the green film on the swamp water (2662-2667) -----------------
// a crowd of tiny round fronds packed edge to edge, each a little domed and
// paler on top, darker water showing in the gaps; some fronds bigger, a few
// paired; patchy tone across the mat
//   a yellow-green (retail)   b deep green   c red azolla
skins({
  a: { k0: "#4e520e", k1: "#666c12", k2: "#767e18", k3: "#8c9228" },
  b: { k0: "#24381a", k1: "#2e4c24", k2: "#3a5c2e", k3: "#4e723c" },
  c: { k0: "#4a2014", k1: "#622c1c", k2: "#723822", k3: "#8a4e32" },
})
{
  const big = dots({ scale: 16, radius: 0.5, jitter: 0.7, soft: 0.35, seed: 1231 })
  const small = dots({ scale: 28, radius: 0.5, jitter: 0.8, soft: 0.35, seed: 1234 })
  const dome = big.max(small.mul(0.85)).as("dome")
  const gap = dome.invert().threshold(0.75, 0.25).as("gap")
  const tone = noise({ scale: 4, octaves: 2, seed: 1232 }).as("tone")
  const fine = noise({ scale: 80, octaves: 1, seed: 1233 })
  const h = dome.mul(0.7).sub(gap.mul(0.3)).add(fine.mul(0.05)).as("weedH")
  for (const k of "abc") {
    const col = (n) => n + k
    material("duckweed" + SUF[k], { size: 512, depth: 0.012, ao: 0.5 }, {
      height: h,
      color: ramp(dome.mul(0.6).add(tone.mul(0.4)), [col("k1"), col("k2"), col("k3")]).mix(col("k0"), gap.mul(0.5)),
      rough: gap.levels(0, 1, 0.45, 0.2),
    })
  }
}
