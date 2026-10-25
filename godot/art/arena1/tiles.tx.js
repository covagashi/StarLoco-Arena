// Arena 1 (Entrenamiento, retail world 5) — tile textures, painted Ankama-like look:
// clean ramps, soft lumps, little fine noise. Tops tile at one cell.
pal({
  snowD: "#b9c9dc", snow: "#e6eef7", snowL: "#fbfdff",
  lilD: "#a79bd2", lil: "#cdc4ee", lilL: "#ebe6fb",
  iceD: "#4d8fbf", ice: "#8cc6e6", iceL: "#d4f0fb",
  stoneD: "#2e3138", stone: "#4a4e57", stoneL: "#6b707b",
  goldD: "#a8822c", gold: "#e3c04f", goldL: "#f7e49a",
  rune: "#7fd6e8",
})

// --- snow: soft pillowy lumps, blue-grey in the hollows ---------------------
const lumps = cells({ scale: 5, seed: 4 }).invert().blur(0.03).as("lumps")
const soft = noise({ scale: 6, octaves: 3, seed: 2 })
const snowH = lumps.mul(0.7).add(soft.mul(0.3)).normalize().as("snowH")
const snowHollow = snowH.cavity(0.02, 10).as("hollow")
material("snow_top", { size: 256, depth: 0.02, ao: 0.6 }, {
  height: snowH,
  color: ramp(snowH, ["snowD", "snow", "snowL"]).mix("snowD", snowHollow.mul(0.5)),
  rough: 0.85,
})
material("snow_lilac", { size: 256, depth: 0.02, ao: 0.6 }, {
  height: snowH,
  color: ramp(snowH, ["lilD", "lil", "lilL"]).mix("lilD", snowHollow.mul(0.5)),
  rough: 0.85,
})

// --- ice top: glassy, a few clean cracks -------------------------------------
const crack = ridged({ scale: 3, octaves: 1, seed: 7 }).threshold(0.95, 0.015).as("crack")
const iceGlow = noise({ scale: 3, octaves: 2, seed: 9 }).as("iceGlow")
material("ice_top", { size: 256, depth: 0.01, ao: 0.3 }, {
  height: crack.invert().mul(0.2).add(0.8),
  color: ramp(iceGlow, ["ice", "iceL"]).mix("snowL", crack.mul(0.85)),
  rough: 0.15,
})

// --- ice side: vertical streaks, frost at the top edge (v = 0) ---------------
const streak = noise({ scale: [3, 1], octaves: 3, seed: 5 }).warp(noise({ scale: 4, seed: 6 }), 0.03).as("streak")
material("ice_side", { size: 256, depth: 0.015, ao: 0.4 }, {
  height: streak,
  color: ramp(streak, ["iceD", "ice", "iceL"]),
  rough: 0.25,
})

// --- stone slab: 2×2 worn flags of dark stone ---------------------------------
const flags = tiles({ rows: 2, cols: 2, gap: 0.02, bevel: 0.05, vary: 0.2, seed: 3 }).as("flags")
const chips = noise({ scale: 10, octaves: 4, seed: 11 })
const stoneH = flags.mul(0.85).add(chips.mul(0.15)).as("stoneH")
material("stone_slab", { size: 256, depth: 0.03, ao: 0.8 }, {
  height: stoneH,
  color: ramp(flags.id.mix(chips, 0.4), ["stoneD", "stone", "stoneL"])
    .mix("stoneD", flags.mask.invert())
    .mix("stoneL", stoneH.convex(0.01, 10).mul(0.5)),
  rough: chips.levels(0, 1, 0.6, 0.9),
})

// --- gold spawn platform: a square border around a sun disc ----------------
// kiln projects UVs from the world origin = the block centre, so the motif is
// centred on the texture corner (shapes wrap) to land in the middle of the top.
const border = shape({ kind: "rect", cx: 0, cy: 0, w: 0.86, h: 0.86, round: 0.06 }).sub(shape({ kind: "rect", cx: 0, cy: 0, w: 0.7, h: 0.7, round: 0.04 })).as("border")
const disc = shape({ kind: "ring", cx: 0, cy: 0, r: 0.2, w: 0.045 }).max(shape({ kind: "star", cx: 0, cy: 0, sides: 8, r: 0.11, inner: 0.05 })).as("disc")
const motif = border.max(disc).clamp(0, 1).as("motif")
const goldN = noise({ scale: 4, octaves: 3, seed: 13 })
material("gold_spawn", { size: 256, depth: 0.025, ao: 0.7 }, {
  height: motif.mul(0.5).add(goldN.mul(0.15)).add(0.3),
  color: ramp(goldN, ["gold", "goldL"]).mix("goldD", motif.mul(0.8)),
  rough: 0.45,
})
