// Arena 5 (Entrenamiento) — tile blocks, 1 m = one cell. Body of ice, a
// cap per tile type; the snow caps overhang a little with soft lumps along
// the edge, the painted Ankama-like silhouette.
pal({
  snow: { tex: "out/snow_top", uv: 1 },
  lilac: { tex: "out/snow_lilac", uv: 1 },
  iceTop: { tex: "out/ice_top", uv: 1, rough: 0.2 },
  ice: { tex: "out/ice_side", uv: 1, rough: 0.3 },
  stone: { tex: "out/stone_slab", uv: 1 },
  gold: { tex: "out/gold_spawn", uv: 1 },
})

const H = 0.7   // body height under the cap

// lumps hanging over the four top edges
const lumps = (mat) => [0, 90, 180, 270].map((r) => tf({ rot: [0, r, 0] },
  [-0.42, -0.25, -0.08, 0.09, 0.26, 0.42].map((x, i) => sphere(0.07 + ((i * 37) % 3) * 0.012,
    { mat, detail: 2, pos: [x, H + 0.05 - (i % 2) * 0.025, 0.49], scale: [1.35, 1.0, 0.6] }))))

const snowCap = (mat) => [box(1.04, 0.12, 1.04, { mat, pos: [0, H, 0], jitter: 0.01 }), ...lumps(mat)]

model("t_snow", box(1, H, 1, "ice"), snowCap("snow"))
model("t_lilac", box(1, H, 1, "ice"), snowCap("lilac"))
model("t_ice", box(1, H + 0.1, 1, "ice"), box(1.0, 0.03, 1.0, { mat: "iceTop", pos: [0, H + 0.1, 0] }))
model("t_stone", box(1, H - 0.2, 1, "ice"), box(1.0, 0.08, 1.0, { mat: "stone", pos: [0, H - 0.2, 0] }))
model("t_gold", box(1, H, 1, "ice"), box(1.02, 0.1, 1.02, { mat: "gold", pos: [0, H, 0] }))

// plain ice column, stacked under a tile down to the arena floor
model("t_col", box(1, 1, 1, "ice"))

pack("arena5_tiles", ["t_snow", "t_lilac", "t_ice", "t_stone", "t_gold", "t_col"])
