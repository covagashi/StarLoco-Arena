// Arena 5 decoration fills (loom): painted textures the vex shapes clip
// inside, for the detail the flat shapes lack. Same ramps as arena5.vx.js.
pal({
  t0: "#5e5a43", t1: "#8e896a", t2: "#c2bc98", t3: "#e4dfc2",
  s0: "#5f79a6", s1: "#a9bdd9", s2: "#e3ecf6", s3: "#ffffff",
  l0: "#6e6aa6", l1: "#a9a6d6", l2: "#dcd9f3", l3: "#f8f7ff",
})

// bark: tall plates split by dark crevices, each plate its own tone, fine
// vertical grain, a knot here and there
const cl = cells({ scale: [5, 1], jitter: 0.7, seed: 12 })
const wob = noise({ scale: [3, 1], seed: 8 })
const plates = { edge: cl.edge.warp(wob, 0.04).as("plateEdge"), id: cl.id.warp(wob, 0.04) }
const crev = plates.edge.invert().threshold(0.92, 0.05).as("crevice")
const grain = noise({ scale: [18, 2], octaves: 3, seed: 4 }).as("grain")
const knot = dots({ scale: 3, radius: 0.12, jitter: 0.9, soft: 0.4, seed: 9 }).as("knot")
const barkH = plates.edge.mul(0.6).add(grain.mul(0.3)).sub(knot.mul(0.25)).as("barkH")
material("bark_paint", { size: 256, depth: 0.03, ao: 0.6 }, {
  height: barkH,
  color: ramp(plates.id.mix(grain, 0.35), ["t1", "t2", "t3"]).mix("t0", crev.mul(0.85)).mix("t0", knot.mul(0.6)),
  rough: 0.85,
})

// snow on the props: soft pillows with blue in the folds
const pill = cells({ scale: 4, seed: 21 }).invert().blur(0.04).as("pill")
const sh = pill.mul(0.8).add(noise({ scale: 10, octaves: 3, seed: 6 }).mul(0.2)).normalize().as("snowH")
material("snow_paint", { size: 256, depth: 0.015, ao: 0.5 }, {
  height: sh,
  color: ramp(sh, [[0, "s1"], [0.5, "s2"], [1, "s3"]]),
  rough: 0.9,
})

// lilac ice: long soft streaks and a few clean planes
const streak = noise({ scale: [2, 8], octaves: 3, seed: 15 }).warp(noise({ scale: 3, seed: 2 }), 0.05).as("streak")
const facets = cells({ scale: 2, seed: 33 }).as("facets")
material("ice_lilac", { size: 256, depth: 0.01, ao: 0.3 }, {
  height: streak.mul(0.6).add(facets.edge.mul(0.4)),
  color: ramp(facets.id.mix(streak, 0.5), ["l1", "l2", "l3"]).mix("l0", facets.edge.invert().threshold(0.94, 0.06).mul(0.25)),
  rough: 0.2,
})
