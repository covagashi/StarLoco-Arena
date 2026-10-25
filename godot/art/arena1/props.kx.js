// Arena 1 (Entrenamiento, retail world 5) — decoration props, painted low-poly: few big
// shapes, 2–3 tones each, a little jitter so nothing looks machined.
pal({
  iceL: "#e3f6ff", ice: "#a9daf2", iceD: "#69a9d3",
  snow: { tex: "out/snow_top", uv: 0.6 },
  bark: "#d9c7a3", barkD: "#a8916b",
  cry: { color: "#38c4e4", emit: "#3fd6ff", glow: 0.6, rough: 0.3 },
  cryL: { color: "#a6efff", emit: "#7fe8ff", glow: 0.4, rough: 0.3 },
  cryD: "#1f7fa8",
  stone: "#8d93a1", stoneD: "#5d6372",
  wood: "#8a5a32", woodD: "#5c3a20",
  glow: { color: "#ffd98a", emit: "#ffc65a", glow: 3 },
})

// ice spike: one tall shard and two leaning ones, on a snow mound
model("p_spike",
  sphere(0.32, { mat: "snow", detail: 2, scale: [1, 0.35, 1] }),
  cone(0.2, 1.7, { mat: "iceL", sides: 5, jitter: 0.03 }),
  cone(0.13, 1.0, { mat: "ice", sides: 5, pos: [0.15, 0, 0.08], rot: [8, 30, -16], jitter: 0.03 }),
  cone(0.1, 0.7, { mat: "iceD", sides: 5, pos: [-0.14, 0, -0.06], rot: [-10, 70, 18], jitter: 0.03 }))

// bare pale tree with snow sitting on its branches
const branch = (pts, r) => tube(pts, r, { mat: "bark", sides: 5 })
model("p_tree",
  sphere(0.3, { mat: "snow", detail: 2, scale: [1, 0.3, 1] }),
  lathe([0.13, 0, 0.1, 0.35, 0.08, 0.75, 0.05, 1.05, 0, 1.15], { mat: "barkD", sides: 6 }),
  branch([0, 0.7, 0, 0.22, 0.95, 0.05, 0.36, 1.1, 0.02], 0.035),
  branch([0, 0.85, 0, -0.18, 1.08, -0.06, -0.3, 1.18, -0.1], 0.03),
  branch([0, 0.55, 0, -0.05, 0.75, 0.2, -0.02, 0.9, 0.33], 0.03),
  [[0.36, 1.13, 0.02, 0.09], [-0.3, 1.21, -0.1, 0.08], [-0.02, 0.93, 0.33, 0.075], [0.02, 1.17, 0, 0.1]].map(
    ([x, y, z, r]) => sphere(r, { mat: "snow", detail: 2, pos: [x, y, z], scale: [1.3, 0.75, 1.3] })))

// glowing crystal cluster
const shard = (h, r, pos, rot, mat) =>
  lathe([r, 0, r, h * 0.75, 0, h], { mat, sides: 6, pos, rot, jitter: 0.01 })
model("p_crystal",
  sphere(0.26, { mat: "snow", detail: 2, scale: [1, 0.3, 1] }),
  shard(0.62, 0.08, [0, 0, 0], [0, 0, 0], "cry"),
  shard(0.42, 0.06, [0.1, 0, 0.05], [0, 20, -22], "cryL"),
  shard(0.38, 0.06, [-0.09, 0, 0.06], [12, 50, 20], "cry"),
  shard(0.3, 0.05, [0.02, 0, -0.1], [-25, 10, 0], "cryD"),
  shard(0.26, 0.045, [-0.05, 0, -0.06], [-12, 80, 18], "cryL"))

// wooden lantern post beside a coach pedestal
model("p_lantern",
  box(0.36, 0.08, 0.36, "woodD"),
  box(0.12, 1.1, 0.12, "wood"),
  box(0.3, 0.06, 0.3, { mat: "woodD", pos: [0, 1.1, 0] }),
  box(0.18, 0.22, 0.18, { mat: "glow", pos: [0, 1.16, 0] }),
  cone(0.24, 0.18, { mat: "woodD", sides: 4, pos: [0, 1.38, 0], rot: [0, 45, 0] }),
  light({ type: "point", color: "#ffc65a", power: 6, pos: [0, 1.27, 0.25] }))

// a few pebbles with a cap of snow, flat enough to walk over
model("p_pebbles",
  rock(0.09, { mat: "stone", seed: 2, pos: [0, 0.03, 0] }),
  rock(0.06, { mat: "stoneD", seed: 5, pos: [0.13, 0.02, 0.06] }),
  rock(0.05, { mat: "stone", seed: 8, pos: [-0.1, 0.02, 0.09] }),
  sphere(0.07, { mat: "snow", detail: 1, pos: [0, 0.09, 0], scale: [1.2, 0.4, 1.2] }))

pack("arena1_props", ["p_spike", "p_tree", "p_crystal", "p_lantern", "p_pebbles"])
