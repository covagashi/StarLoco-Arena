// Hero ice block — textures. The body texture spans the block's whole height
// once (kiln uv = body height): light at the top, a deep band at the foot.
pal({
  iceTop: "#dff6ff", iceL: "#b4e3f7", ice: "#7cc3e8", iceM: "#4f9fd2", iceD: "#2f6fae", iceDD: "#244f8a",
  snowD: "#a9bbd4", snow: "#dbe5f1", snowL: "#f6faff",
})

// soft vertical bands from top (v = 0) to foot (v = 1)
const foot = shape({ kind: "rect", cy: 0.86, w: 2, h: 0.26, soft: 0.1 }).warp(noise({ scale: [6, 2], seed: 9 }), 0.035).as("foot")
const top = shape({ kind: "rect", cy: 0.12, w: 2, h: 0.16, soft: 0.1 }).as("top")
const streak = noise({ scale: [5, 1], octaves: 3, seed: 21 }).warp(noise({ scale: 3, seed: 4 }), 0.04).as("streak")
// a few long inner fractures, like light caught inside the ice
const frac = ridged({ scale: [3, 2], octaves: 2, seed: 17 }).threshold(0.965, 0.02)
  .mul(shape({ kind: "rect", cy: 0.45, w: 2, h: 0.5, soft: 0.2 })).as("frac")
const base = ramp(streak, ["iceM", "ice", "iceL"])
material("ice_body", { size: 512, depth: 0.012, ao: 0.3 }, {
  height: streak.mul(0.6).add(frac.mul(0.4)),
  color: base.mix("iceTop", top.mul(0.55)).mix(ramp(streak, ["iceDD", "iceD"]), foot.mul(0.85)).mix("iceTop", frac.mul(0.35)),
  rough: 0.25,
})

// snow: big soft pillows, a cool shadow tone in the folds, sparkle-free
const pill = cells({ scale: 3, seed: 8 }).invert().blur(0.05).as("pill")
const fine = noise({ scale: 9, octaves: 3, seed: 3 })
const sh = pill.mul(0.8).add(fine.mul(0.2)).normalize().as("snowH")
material("snow_soft", { size: 512, depth: 0.015, ao: 0.4 }, {
  height: sh,
  color: ramp(sh, [[0, "snowD"], [0.55, "snow"], [1, "snowL"]]),
  rough: 0.9,
})
