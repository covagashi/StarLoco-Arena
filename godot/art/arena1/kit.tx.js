// Arena 1 (snow biome) — textures for the decoration kit, three looms each
// (a, b, c), picked per placed piece in the map editor. Run glyphs.py first:
// the slabs and runes read their baybayin glyph from out/glyphs/.
const SUF = { a: "", b: "_b", c: "_c" }
const skins = (sets) => {
  for (const [k, s] of Object.entries(sets))
    pal(Object.fromEntries(Object.entries(s).map(([n, v]) => [n + k, v])))
}

// --- wood (bridge planks, lantern posts) -------------------------------------
//   a warm brown   b weathered grey   c dark tarred
skins({
  a: { w0: "#3e2716", w1: "#6b4527", w2: "#8f5f36", w3: "#b5824e" },
  b: { w0: "#2f2d2b", w1: "#5b5652", w2: "#7f7973", w3: "#a59e95" },
  c: { w0: "#1c1512", w1: "#382a22", w2: "#523e31", w3: "#6f5745" },
})
const grain = noise({ scale: [1, 9], octaves: 4, seed: 41 }).warp(noise({ scale: 3, seed: 42 }), 0.04).as("grain")
const rings = waves({ count: 9, dir: "h", warp: 0.5, scale: 3, seed: 43 }).as("rings")
for (const k of "abc") {
  const c = (n) => n + k
  material("wood" + SUF[k], { size: 256, depth: 0.02, ao: 0.5 }, {
    height: grain.mul(0.7).add(rings.mul(0.3)),
    color: ramp(grain.mix(rings, 0.3), [c("w1"), c("w2"), c("w3")]).mix(c("w0"), rings.threshold(0.9, 0.05).mul(0.5)),
    rough: 0.8,
  })
}

// --- slabs with a baybayin glyph, a square greca border round it -------------
//   a old gold, dark glyph   b gold, blue glyph   c gold, red glyph
skins({
  a: { g0: "#5e5a2e", g1: "#a59a55", g2: "#cfc27a", g3: "#ebe0a6", gi: "#3f4a2c" },
  b: { g0: "#6a5420", g1: "#b8953f", g2: "#dcbd62", g3: "#f3e29c", gi: "#2c58b8" },
  c: { g0: "#6a5420", g1: "#b8953f", g2: "#dcbd62", g3: "#f3e29c", gi: "#b8322c" },
})
// centred on the texture corner (= the slab centre, kiln projects from there)
const border = shape({ kind: "rect", cx: 0, cy: 0, w: 0.9, h: 0.9, round: 0.05 })
  .sub(shape({ kind: "rect", cx: 0, cy: 0, w: 0.8, h: 0.8, round: 0.04 })).as("border")
const inner = shape({ kind: "rect", cx: 0, cy: 0, w: 0.7, h: 0.7, round: 0.03 })
  .sub(shape({ kind: "rect", cx: 0, cy: 0, w: 0.66, h: 0.66, round: 0.03 })).as("inner")
const slabN = noise({ scale: 5, octaves: 4, seed: 51 }).as("slabN")
const worn = noise({ scale: 4, octaves: 4, seed: 52 }).threshold(0.68, 0.08).as("worn")
for (const k of "abc") {
  const c = (n) => n + k
  const g = image(`out/glyphs/slab_${k}.png`).luma().as("glyph" + k)
  material("slab" + SUF[k], { size: 512, depth: 0.025, ao: 0.6 }, {
    height: slabN.mul(0.25).add(0.6).sub(g.mul(0.35)).add(border.mul(0.15)).sub(inner.mul(0.2)).sub(worn.mul(0.1)),
    color: ramp(slabN, [c("g1"), c("g2"), c("g3")]).mix(c("g0"), border.mul(0.5)).mix(c("g0"), inner.mul(0.7))
      .mix(c("g0"), worn.mul(0.4)).mix(c("gi"), g),
    rough: 0.5,
  })
}

// --- floor runes: a dark stone disc, a ring and a glowing glyph --------------
//   a amber   b blue   c red
skins({
  a: { r0: "#1d1c1f", r1: "#36343a", rg: "#e8903a", rl: "#ffd08a" },
  b: { r0: "#1a1c22", r1: "#30343f", rg: "#3f7fe0", rl: "#a9cdff" },
  c: { r0: "#1f1a1b", r1: "#3a3033", rg: "#d8423a", rl: "#ffab9b" },
})
pal({ off: "#000000" })
const ring = shape({ kind: "ring", cx: 0, cy: 0, r: 0.27, w: 0.025 }).as("ring")
const ticks = [0, 45, 90, 135].map((a) => shape({ kind: "rect", cx: 0, cy: 0, w: 0.66, h: 0.02, rot: a }))
  .reduce((x, y) => x.max(y)).mul(shape({ kind: "ring", cx: 0, cy: 0, r: 0.305, w: 0.045 })).as("ticks")
const runeN = noise({ scale: 6, octaves: 3, seed: 61 }).as("runeN")
for (const k of "abc") {
  const c = (n) => n + k
  const g = image(`out/glyphs/rune_${k}.png`).luma().as("rglyph" + k)
  const lit = g.max(ring).max(ticks)
  material("rune" + SUF[k], { size: 512, depth: 0.015, ao: 0.4 }, {
    height: runeN.mul(0.3).add(0.5).sub(lit.mul(0.3)),
    color: ramp(runeN, [c("r0"), c("r1")]).mix(c("rg"), lit).mix(c("rl"), g.mul(0.5)),
    rough: 0.6,
    emit: ramp(lit, ["off", c("rg")]),
  })
}

// --- leaves (retail 176: broad leaves, snow on top) ---------------------------
//   a teal (the retail one)   b pine green   c lilac
skins({
  a: { l0: "#0f5a6e", l1: "#1c8ea6", l2: "#36c1d6", l3: "#9ff0f5" },
  b: { l0: "#1f4a2a", l1: "#2f7a3f", l2: "#4fa85a", l3: "#a8dc8f" },
  c: { l0: "#4a3a7a", l1: "#7360b4", l2: "#9c8ad8", l3: "#d8cdf6" },
})
const vein = waves({ count: 5, dir: "v", warp: 0.15, scale: 2, seed: 71 }).threshold(0.92, 0.03).as("vein")
const leafN = noise({ scale: [2, 5], octaves: 3, seed: 72 }).as("leafN")
for (const k of "abc") {
  const c = (n) => n + k
  material("leaf" + SUF[k], { size: 256, depth: 0.01, ao: 0.4 }, {
    height: leafN.mul(0.6).add(vein.mul(0.4)),
    color: ramp(leafN, [c("l1"), c("l2"), c("l3")]).mix(c("l0"), vein.mul(0.35)),
    rough: 0.55,
  })
}

// --- pebbles -----------------------------------------------------------------
//   a cold grey   b sandstone   c dark slate
skins({
  a: { p0: "#4b5260", p1: "#7a8392", p2: "#a7b0bd" },
  b: { p0: "#6b5a40", p1: "#a58d66", p2: "#d2bf98" },
  c: { p0: "#23262c", p1: "#3d424b", p2: "#5d636e" },
})
const pebN = noise({ scale: 6, octaves: 4, seed: 81 }).as("pebN")
for (const k of "abc") {
  const c = (n) => n + k
  material("pebble" + SUF[k], { size: 256, depth: 0.02, ao: 0.6 }, {
    height: pebN,
    color: ramp(pebN, [c("p0"), c("p1"), c("p2")]),
    rough: 0.85,
  })
}

// --- cut stone (77, 78, 79, 109): big cracked blocks -------------------------
//   a sandstone   b grey granite   c blue slate
skins({
  a: { s0: "#5a5032", s1: "#8f8358", s2: "#ada170", s3: "#cfc391" },
  b: { s0: "#4a4a4c", s1: "#7d7d80", s2: "#a2a2a4", s3: "#c8c8c8" },
  c: { s0: "#2e3a4a", s1: "#4f6075", s2: "#6f8399", s3: "#9cb0c4" },
})
// height first: two courses of cut blocks, chipped corners, fine grain;
// joints and cracks low, dark and rough; worn edges light; frost in hollows
const slabs = bricks({ rows: 2, cols: 2, gap: 0.012, bevel: 0.03, wobble: 0.15, seed: 91 }).as("slabs")
const sGrain = noise({ scale: 22, octaves: 4, seed: 94 })
const sMid = noise({ scale: 6, octaves: 4, seed: 93 }).warp(noise({ scale: 3, seed: 95 }), 0.05).as("stoneMid")
const cracks = ridged({ scale: 4, octaves: 3, seed: 92 }).threshold(0.9, 0.04).mul(noise({ scale: 3, seed: 96 }).threshold(0.45, 0.2)).as("cracks")
const chips = ridged({ scale: 10, octaves: 2, seed: 97 }).threshold(0.88, 0.05).mul(slabs.dist.invert().threshold(0.6, 0.2)).as("chips")
const stoneH = slabs.mul(slabs.id.levels(0, 1, 0.85, 1)).mul(0.75).add(sMid.mul(0.15)).add(sGrain.mul(0.06)).sub(cracks.mul(0.2)).sub(chips.mul(0.15)).as("stoneH")
const stoneDirt = stoneH.cavity(0.008, 14).max(slabs.mask.invert().mul(0.6)).max(cracks).as("stoneDirt")
const stoneWear = stoneH.convex(0.008, 10).mul(noise({ scale: 9, seed: 98 }).threshold(0.4, 0.3)).as("stoneWear")
for (const k of "abc") {
  const c = (n) => n + k
  material("stone" + SUF[k], { size: 512, depth: 0.03, ao: 0.7 }, {
    height: stoneH,
    color: ramp(slabs.id.mix(sMid, 0.4), [c("s1"), c("s2"), c("s3")])
      .hsv({ h: slabs.id.levels(0, 1, -6, 6) })
      .mix(c("s0"), stoneDirt.mul(0.7)).mix(c("s3"), stoneWear.mul(0.5)),
    rough: sGrain.levels(0, 1, 0.7, 0.9).mix(0.95, stoneDirt).mix(0.55, stoneWear),
  })
}

// --- boulders (104, 105, 2584, 2592, 166) -------------------------------------
//   a warm sandstone   b grey   c dark basalt
skins({
  a: { b0: "#5e4a2a", b1: "#9c7a44", b2: "#c49a5a", b3: "#e0bf80" },
  b: { b0: "#3c3a38", b1: "#6a6560", b2: "#8f8984", b3: "#b3aea6" },
  c: { b0: "#16171b", b1: "#2e3036", b2: "#474a52", b3: "#666a73" },
})
// boulder: big faceted planes (cells edges as ridges), medium warped noise,
// fine grain; grime in the hollows, light on the ridges, lichen facing up
const bc = cells({ scale: 3, jitter: 0.9, seed: 101 })
const planes = bc.edge.smooth(0.02, 0.35).as("planes")
const bMid = noise({ scale: 5, octaves: 4, seed: 102 }).warp(noise({ scale: 2, seed: 103 }), 0.08).as("boulMid")
const bFine = noise({ scale: 26, octaves: 3, seed: 104 })
const boulH = planes.mul(bc.id.levels(0, 1, 0.8, 1)).mul(0.7).add(bMid.mul(0.22)).add(bFine.mul(0.06)).as("boulH")
const boulDirt = boulH.cavity(0.01, 12).as("boulDirt")
const boulEdge = boulH.convex(0.01, 10).as("boulEdge")
for (const k of "abc") {
  const c = (n) => n + k
  material("boulder" + SUF[k], { size: 512, depth: 0.035, ao: 0.7 }, {
    height: boulH,
    color: ramp(bc.id.mix(bMid, 0.5), [c("b1"), c("b2"), c("b3")]).hsv({ h: bc.id.levels(0, 1, -5, 5) })
      .mix(c("b0"), boulDirt.mul(0.65)).mix(c("b3"), boulEdge.mul(0.45)),
    rough: bFine.levels(0, 1, 0.72, 0.9).mix(0.95, boulDirt).mix(0.6, boulEdge),
  })
}

// --- moss floor (623): flat green stone, wet moss in the joints --------------
//   a moss green   b frosted blue   c dry olive
skins({
  a: { m0: "#1f2a24", m1: "#2c5a36", m2: "#467f48", m3: "#86b06a", f1: "#5d655f", f2: "#8a918a" },
  b: { m0: "#1c2833", m1: "#4f7f9a", m2: "#7fb0c8", m3: "#d4ecf4", f1: "#4f5866", f2: "#7d8796" },
  c: { m0: "#2a2618", m1: "#6a6a2a", m2: "#94913f", m3: "#c8c27a", f1: "#6a6052", f2: "#968a76" },
})
// moss floor: four worn flagstones, moss growing out of the joints and
// patchy over the stone (noise-masked), damp darker hollows
const mossC = tiles({ rows: 2, cols: 2, gap: 0.016, bevel: 0.04, vary: 0.25, seed: 111 }).as("mossC")
const mMid = noise({ scale: 5, octaves: 4, seed: 113 }).warp(noise({ scale: 3, seed: 114 }), 0.06).as("mossMid")
const mFine = noise({ scale: 28, octaves: 3, seed: 115 })
const mossH = mossC.mul(0.7).add(mMid.mul(0.2)).add(mFine.mul(0.06)).as("mossH")
const mossGrow = mossC.mask.invert().blur(0.04).mul(1.6).add(mMid.sub(0.5).mul(2.2)).add(0.15).threshold(0.4, 0.14).as("mossGrow")
for (const k of "abc") {
  const c = (n) => n + k
  material("moss" + SUF[k], { size: 512, depth: 0.025, ao: 0.6 }, {
    height: mossH.add(mossGrow.mul(0.08)),
    color: ramp(mossC.id.mix(mMid, 0.5), [c("f1"), c("f2")]).mix(ramp(mFine.mix(mMid, 0.5), [c("m1"), c("m2"), c("m3")]), mossGrow)
      .mix(c("m0"), mossH.cavity(0.008, 14).mul(0.6)),
    rough: mFine.levels(0, 1, 0.6, 0.8).mix(0.9, mossGrow),
  })
}

// --- mushroom stems (160) ------------------------------------------------------
//   a pale bone   b red-brown   c grey-violet
skins({
  a: { t0: "#8f8466", t1: "#c9bea0", t2: "#e8dfc4" },
  b: { t0: "#5a2e22", t1: "#9a5a40", t2: "#c88a68" },
  c: { t0: "#4a4256", t1: "#7d7390", t2: "#ada3c0" },
})
const fib = noise({ scale: [1, 8], octaves: 3, seed: 121 }).as("fib")
for (const k of "abc") {
  const c = (n) => n + k
  material("stem" + SUF[k], { size: 256, depth: 0.015, ao: 0.4 }, {
    height: fib,
    color: ramp(fib, [c("t0"), c("t1"), c("t2")]),
    rough: 0.8,
  })
}
