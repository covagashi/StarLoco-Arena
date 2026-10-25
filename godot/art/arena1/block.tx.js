// Arena 1 (snow biome) — block textures, three looms each: the map editor
// lets the owner pick a, b or c per placed piece.
//   a nieve     white snow, blue ice (the approved look)
//   b lila      lilac snow, violet ice
//   c escarcha  grey-green frost, teal ice
// The body texture spans the block's whole height once (kiln uv = body
// height): light at the top, a deep band at the foot.
const SKINS = {
  a: { iceTop: "#dff6ff", iceL: "#b4e3f7", ice: "#7cc3e8", iceM: "#4f9fd2", iceD: "#2f6fae", iceDD: "#244f8a",
    snowD: "#a9bbd4", snow: "#dbe5f1", snowL: "#f6faff",
    clrW: "#f4fbff", clrL: "#d9eef8", clr: "#b9d9ea", clrM: "#93bad3", clrD: "#6f97b8" },
  b: { iceTop: "#ece6ff", iceL: "#c9bdf2", ice: "#a294e0", iceM: "#7d6cc8", iceD: "#5a4aa6", iceDD: "#433585",
    snowD: "#9384c9", snow: "#c4b6ee", snowL: "#e9e2fc",
    clrW: "#f7f4ff", clrL: "#e4ddf8", clr: "#cbc0ec", clrM: "#a99bd6", clrD: "#8576b8" },
  c: { iceTop: "#e2f7f2", iceL: "#b2e0d6", ice: "#7cc2b8", iceM: "#55a097", iceD: "#3a7c76", iceDD: "#2c5f5c",
    snowD: "#a3b5ae", snow: "#d4e0da", snowL: "#f2f7f4",
    clrW: "#f3faf7", clrL: "#d9ece6", clr: "#bad6cd", clrM: "#95b6ad", clrD: "#71948c" },
}
const SUF = { a: "", b: "_b", c: "_c" }
for (const [k, s] of Object.entries(SKINS))
  pal(Object.fromEntries(Object.entries(s).map(([n, v]) => [n + k, v])))

// soft vertical bands from top (v = 0) to foot (v = 1)
const foot = shape({ kind: "rect", cy: 0.86, w: 2, h: 0.26, soft: 0.1 }).warp(noise({ scale: [6, 2], seed: 9 }), 0.035).as("foot")
const top = shape({ kind: "rect", cy: 0.12, w: 2, h: 0.16, soft: 0.1 }).as("top")
const streak = noise({ scale: [5, 1], octaves: 3, seed: 21 }).warp(noise({ scale: 3, seed: 4 }), 0.04).as("streak")
// a few long inner fractures, like light caught inside the ice
const frac = ridged({ scale: [3, 2], octaves: 2, seed: 17 }).threshold(0.965, 0.02)
  .mul(shape({ kind: "rect", cy: 0.45, w: 2, h: 0.5, soft: 0.2 })).as("frac")
// snow: big soft pillows, a cool shadow tone in the folds, sparkle-free
const pill = cells({ scale: 3, seed: 8 }).invert().blur(0.05).as("pill")
const fine = noise({ scale: 9, octaves: 3, seed: 3 })
const sh = pill.mul(0.8).add(fine.mul(0.2)).normalize().as("snowH")
// clear ice: light caught in long diagonal streaks
const glint = [[0.05, 0.1, 0.45, 0.75], [0.35, 0.05, 0.8, 0.8], [0.6, 0.2, 0.95, 0.7]]
  .map(([x0, y0, x1, y1], i) => shape({ kind: "line", x0, y0, x1, y1, w: 0.05 - i * 0.01, soft: 0.04 }))
  .reduce((a, b) => a.max(b)).warp(noise({ scale: 3, seed: 12 }), 0.03).as("glint")
const haze = noise({ scale: [3, 2], octaves: 3, seed: 6 }).as("haze")

for (const k of Object.keys(SKINS)) {
  const c = (n) => n + k, sfx = SUF[k]
  const base = ramp(streak, [c("iceM"), c("ice"), c("iceL")])
  material("ice_body" + sfx, { size: 512, depth: 0.012, ao: 0.3 }, {
    height: streak.mul(0.6).add(frac.mul(0.4)),
    color: base.mix(c("iceTop"), top.mul(0.55)).mix(ramp(streak, [c("iceDD"), c("iceD")]), foot.mul(0.85)).mix(c("iceTop"), frac.mul(0.35)),
    rough: 0.25,
  })
  // a column body: the same ice with no top or foot band, so pieces stack
  material("ice_col" + sfx, { size: 512, depth: 0.012, ao: 0.3 }, {
    height: streak.mul(0.6).add(frac.mul(0.4)),
    color: ramp(streak, [c("iceD"), c("iceM"), c("ice")]).mix(c("iceTop"), frac.mul(0.3)),
    rough: 0.25,
  })
  material("snow_soft" + sfx, { size: 512, depth: 0.015, ao: 0.4 }, {
    height: sh,
    color: ramp(sh, [[0, c("snowD")], [0.55, c("snow")], [1, c("snowL")]]),
    rough: 0.9,
  })
  // clear ice (the bare block, retail 154): pale and cool, almost white at the
  // top, a soft band at the foot
  material("ice_clear" + sfx, { size: 512, depth: 0.008, ao: 0.2 }, {
    height: haze.mul(0.5).add(frac.mul(0.5)),
    color: ramp(haze, [c("clrM"), c("clr"), c("clrL")]).mix(c("clrW"), top.mul(0.6)).mix(c("clrD"), foot.mul(0.6))
      .mix(c("clrW"), glint.mul(0.55)).mix(c("clrW"), frac.mul(0.5)),
    rough: 0.15,
  })
  material("ice_clear_col" + sfx, { size: 512, depth: 0.008, ao: 0.2 }, {
    height: haze.mul(0.5).add(frac.mul(0.5)),
    color: ramp(haze, [c("clrD"), c("clrM"), c("clr")]).mix(c("clrW"), glint.mul(0.45)).mix(c("clrW"), frac.mul(0.5)),
    rough: 0.15,
  })
  // its flat top: hairline cracks
  material("ice_clear_top" + sfx, { size: 512, depth: 0.006, ao: 0.15 }, {
    height: haze.mul(0.4).add(frac.mul(0.6)),
    color: ramp(haze, [c("clrM"), c("clr"), c("clrL")]).mix(c("clrW"), frac.mul(0.6)).mix(c("clrW"), glint.mul(0.4)),
    rough: 0.12,
  })
}
