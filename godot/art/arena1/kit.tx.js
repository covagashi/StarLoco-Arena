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
