// S35c: the rigid parts of the coach's garments (garments.json "extras"):
// what a garment that bends can't have, joined into it by coach_garment.py
// wholly on one bone. Own designs. pivot "origin" on the skin, +Y out of it,
// +X up the body; a "ring" goes round its limb: round +Y, for a limb
// 0.05 m thick (coach_garment.py sizes it).
{ // the helpers below stay local to this include
pal({
  xBone: "#f0ead8", xBoneD: "#c8bc9c", xSkull: "#b89a8a",
  xFur: "#ffffff", xFurD: "#e4e0dc", xWool: "#f2c230", xWoolD: "#d09a18",
  xJelly: { color: "#f07080", rough: 0.15 }, xJellyL: { color: "#ffd1d7", rough: 0.15 },
  xBlack: "#1a1a1e", xRed: "#c8221e", xWhite: "#f4f2ec",
  xGold: { color: "#f2c41c", metal: 0.4, rough: 0.35 }, xGoldD: "#b08418",
  xIce: { color: "#a8e4f4", rough: 0.15 }, xIceD: "#5ab0d0",
  xOrange: "#e8961c", xGem: { color: "#5ab8f0", emit: "#3a90d0", glow: 0.6, rough: 0.2 },
  xTeal: "#4fb0a0", xGrey: "#7a807a", xGreyD: "#4a4e4a", xWood: "#8a6040", xFeather: "#e8e0d0",
})

const ex = (name, ...items) => model(name, { pivot: "origin" }, ...items)
const range = (n, f) => Array.from({ length: n }, (_, i) => f(i))
const fluff = (m, d, n = 10, R = 0.05, r = 0.022) => range(n, (k) => {
  const a = (k / n) * Math.PI * 2
  return sphere(r * (k % 2 ? 1 : 1.15), { mat: k % 3 ? m : d, pos: [R * Math.cos(a), (k % 2) * 0.006, R * Math.sin(a)], detail: 0, jitter: 0.004 })
})

// a cone from `at` along the direction `deg` in the XY plane (0 = +Y,
// out of the skin; 90 = +X, up the body), its base there: kiln centres a
// cone, so it is moved half its length along
const seg = (at, deg, r, len, mat, o = {}) => {
  const t = deg * Math.PI / 180, dx = Math.sin(t), dy = Math.cos(t)
  return cone(r, len, { mat, sides: o.sides ?? 6, pos: [at[0] + dx * len / 2, at[1] + dy * len / 2, at[2] ?? 0], rot: [o.tilt ?? 0, 0, -deg] })
// spikes, studs, crests (war breastplate, the Champion's boots, Superjefe)
ex("x_spike", seg([0, -0.004, 0], 0, 0.016, 0.05, "xGreyD"))
ex("x_spike_gold", seg([0, -0.004, 0], 0, 0.016, 0.05, "xGoldD"))
ex("x_bolt",                               // a stone bolt (Stasis)
  cyl(0.016, 0.012, { mat: "xGrey", sides: 6, pos: [0, 0.004, 0] }),
  sphere(0.009, { mat: "xGreyD", pos: [0, 0.012, 0], detail: 0 }))
ex("x_crest",                              // an orange crest of points round a collar
  ...range(5, (k) => seg([0, -0.004, (k - 2) * 0.022], 90 - Math.abs(k - 2) * 15, 0.014, 0.06 - Math.abs(k - 2) * 0.01, "xOrange", { sides: 4 })))
ex("x_sunflower",                          // a sunflower on the shoulder (Joroba)
  cyl(0.02, 0.01, { mat: "xWood", sides: 8, pos: [0, 0.008, 0] }),
  ...range(10, (k) => box(0.022, 0.006, 0.012, { mat: "xWool", pos: [0.03 * Math.cos(k * 0.628), 0.008, 0.03 * Math.sin(k * 0.628)], rot: [0, -k * 36, 0] })))
ex("x_flower",                             // a teal flower (wonejo)
  sphere(0.012, { mat: "xWhite", pos: [0, 0.01, 0], detail: 0 }),
  ...range(6, (k) => sphere(0.013, { mat: "xTeal", pos: [0.018 * Math.cos(k * 1.047), 0.008, 0.018 * Math.sin(k * 1.047)], scale: [1, 0.5, 1], detail: 0 })))
ex("x_feathers",                           // a fan of white and blue feathers (Gosbaster)
  ...range(5, (k) => seg([0, -0.004, (k - 2) * 0.015], 75 - Math.abs(k - 2) * 12, 0.012, 0.08, k % 2 ? "xIce" : "xWhite", { sides: 4 })))
ex("x_skull",                              // a little skull on the toe (Aplastacampis)
  sphere(0.025, { mat: "xSkull", pos: [0, 0.022, 0], scale: [1, 0.9, 1], detail: 1 }),
  sphere(0.009, { mat: "xBlack", pos: [0.004, 0.038, 0.011], detail: 0 }),
  sphere(0.009, { mat: "xBlack", pos: [0.004, 0.038, -0.011], detail: 0 }))
ex("x_glasses",                            // round sunglasses pushed up on the head (Zar)
  torus(0.022, 0.004, { mat: "xBlack", pos: [0, 0.006, 0.026], sides: 4, rings: 10 }),
  torus(0.022, 0.004, { mat: "xBlack", pos: [0, 0.006, -0.026], sides: 4, rings: 10 }),
  cyl(0.02, 0.003, { mat: "xTeal", sides: 10, pos: [0, 0.006, 0.026] }),
  cyl(0.02, 0.003, { mat: "xTeal", sides: 10, pos: [0, 0.006, -0.026] }))
// a ring of big red beads round the chest (Lolomg): sized like the leg rings
ex("x_bead_ring", ...range(9, (k) => sphere(0.016, { mat: "xRed", pos: [0.05 * Math.cos(k * 0.698), 0, 0.05 * Math.sin(k * 0.698)], detail: 1 })))
}
// the end of such a cone, less `back` (the next one starts inside it)
const tip = (at, deg, len, back = 0.25) => {
  const t = deg * Math.PI / 180, k = len * (1 - back)
  return [at[0] + Math.sin(t) * k, at[1] + Math.cos(t) * k, at[2] ?? 0]
// spikes, studs, crests (war breastplate, the Champion's boots, Superjefe)
ex("x_spike", seg([0, -0.004, 0], 0, 0.016, 0.05, "xGreyD"))
ex("x_spike_gold", seg([0, -0.004, 0], 0, 0.016, 0.05, "xGoldD"))
ex("x_bolt",                               // a stone bolt (Stasis)
  cyl(0.016, 0.012, { mat: "xGrey", sides: 6, pos: [0, 0.004, 0] }),
  sphere(0.009, { mat: "xGreyD", pos: [0, 0.012, 0], detail: 0 }))
ex("x_crest",                              // an orange crest of points round a collar
  ...range(5, (k) => seg([0, -0.004, (k - 2) * 0.022], 90 - Math.abs(k - 2) * 15, 0.014, 0.06 - Math.abs(k - 2) * 0.01, "xOrange", { sides: 4 })))
ex("x_sunflower",                          // a sunflower on the shoulder (Joroba)
  cyl(0.02, 0.01, { mat: "xWood", sides: 8, pos: [0, 0.008, 0] }),
  ...range(10, (k) => box(0.022, 0.006, 0.012, { mat: "xWool", pos: [0.03 * Math.cos(k * 0.628), 0.008, 0.03 * Math.sin(k * 0.628)], rot: [0, -k * 36, 0] })))
ex("x_flower",                             // a teal flower (wonejo)
  sphere(0.012, { mat: "xWhite", pos: [0, 0.01, 0], detail: 0 }),
  ...range(6, (k) => sphere(0.013, { mat: "xTeal", pos: [0.018 * Math.cos(k * 1.047), 0.008, 0.018 * Math.sin(k * 1.047)], scale: [1, 0.5, 1], detail: 0 })))
ex("x_feathers",                           // a fan of white and blue feathers (Gosbaster)
  ...range(5, (k) => seg([0, -0.004, (k - 2) * 0.015], 75 - Math.abs(k - 2) * 12, 0.012, 0.08, k % 2 ? "xIce" : "xWhite", { sides: 4 })))
ex("x_skull",                              // a little skull on the toe (Aplastacampis)
  sphere(0.025, { mat: "xSkull", pos: [0, 0.022, 0], scale: [1, 0.9, 1], detail: 1 }),
  sphere(0.009, { mat: "xBlack", pos: [0.004, 0.038, 0.011], detail: 0 }),
  sphere(0.009, { mat: "xBlack", pos: [0.004, 0.038, -0.011], detail: 0 }))
ex("x_glasses",                            // round sunglasses pushed up on the head (Zar)
  torus(0.022, 0.004, { mat: "xBlack", pos: [0, 0.006, 0.026], sides: 4, rings: 10 }),
  torus(0.022, 0.004, { mat: "xBlack", pos: [0, 0.006, -0.026], sides: 4, rings: 10 }),
  cyl(0.02, 0.003, { mat: "xTeal", sides: 10, pos: [0, 0.006, 0.026] }),
  cyl(0.02, 0.003, { mat: "xTeal", sides: 10, pos: [0, 0.006, -0.026] }))
// a ring of big red beads round the chest (Lolomg): sized like the leg rings
ex("x_bead_ring", ...range(9, (k) => sphere(0.016, { mat: "xRed", pos: [0.05 * Math.cos(k * 0.698), 0, 0.05 * Math.sin(k * 0.698)], detail: 1 })))
}

// a horn of bone, out of the skin and curling up (Kepika): three cones,
// each starting inside the last
const H0 = [0, -0.005, 0], H1 = tip(H0, 10, 0.05), H2 = tip(H1, 45, 0.045)
ex("x_horn",
  seg(H0, 10, 0.022, 0.05, "xBone"),
  seg(H1, 45, 0.016, 0.045, "xBone"),
  seg(H2, 75, 0.011, 0.04, "xBoneD", { sides: 5 }))

// rings of fur (Ladilla) and of wool (Jalatranki) round a leg
ex("x_fur_ring", ...fluff("xFur", "xFurD"))
ex("x_wool_ring", ...fluff("xWool", "xWoolD", 9, 0.05, 0.024))

// a jelly bubble on the cloth
ex("x_bubble",
  sphere(0.03, { mat: "xJelly", pos: [0, 0.02, 0], detail: 1 }),
  sphere(0.009, { mat: "xJellyL", pos: [0.012, 0.042, 0.01], detail: 1 }))

// belt buckles, flat on the belly
const disc = (r, m, o = {}) => cyl(r, 0.012, { mat: m, sides: o.sides ?? 12, pos: [0, o.y ?? 0.006, 0] })
ex("x_buckle_jalabol",                     // a red and black emblem
  disc(0.04, "xBlack"), disc(0.03, "xRed", { y: 0.012 }),
  box(0.012, 0.004, 0.03, { mat: "xWhite", pos: [0.006, 0.02, 0] }))
ex("x_coin",                               // a big gold coin, a bar across
  disc(0.042, "xGoldD", { sides: 14 }), disc(0.036, "xGold", { y: 0.011, sides: 14 }),
  box(0.012, 0.006, 0.04, { mat: "xGoldD", pos: [0, 0.02, 0] }))
ex("x_crystal",                            // shards of ice from one base
  sphere(0.016, { mat: "xIceD", pos: [0, 0.006, 0], detail: 0 }),
  seg([0, 0, 0], 60, 0.018, 0.06, "xIce", { sides: 5 }),
  seg([0, 0, 0], -50, 0.015, 0.05, "xIceD", { sides: 5 }),
  seg([0, 0, 0.01], 10, 0.013, 0.045, "xIce", { sides: 5, tilt: 30 }))
ex("x_cloud_gem",                          // an orange ring round a blue gem
  torus(0.03, 0.009, { mat: "xOrange", pos: [0, 0.01, 0], sides: 5, rings: 12 }),
  sphere(0.02, { mat: "xGem", pos: [0, 0.012, 0], scale: [1, 0.6, 1], detail: 1 }))
ex("x_bow",                                // a white bow, a teal knot
  sphere(0.025, { mat: "xWhite", pos: [0, 0.012, 0.03], scale: [0.7, 0.5, 1.2], detail: 1 }),
  sphere(0.025, { mat: "xWhite", pos: [0, 0.012, -0.03], scale: [0.7, 0.5, 1.2], detail: 1 }),
  sphere(0.014, { mat: "xTeal", pos: [0, 0.016, 0], detail: 1 }))
ex("x_pouch",                              // a pouch hanging off a belt
  box(0.07, 0.035, 0.055, { mat: "xGrey", pos: [-0.04, 0.02, 0] }),
  box(0.02, 0.04, 0.06, { mat: "xGreyD", pos: [-0.008, 0.022, 0] }))
ex("x_arrows",                             // a bundle of arrows at the hip
  ...range(3, (k) => cyl(0.004, 0.14, { mat: "xWood", pos: [-0.02, 0.02, (k - 1) * 0.012], rot: [0, 0, 80], sides: 4 })),
  ...range(3, (k) => cone(0.01, 0.025, { mat: "xFeather", pos: [-0.09, 0.012, (k - 1) * 0.012], rot: [0, 0, 80], sides: 3 })))
ex("x_tail",                               // a ball of white fluff (wabbit)
  sphere(0.04, { mat: "xFur", pos: [0, 0.03, 0], detail: 1, jitter: 0.006 }),
  ...range(5, (k) => sphere(0.02, { mat: "xFurD", pos: [0.03 * Math.cos(k * 1.3), 0.03 + 0.02 * Math.sin(k * 2), 0.03 * Math.sin(k * 1.3)], detail: 1, jitter: 0.003 })))
// spikes, studs, crests (war breastplate, the Champion's boots, Superjefe)
ex("x_spike", seg([0, -0.004, 0], 0, 0.016, 0.05, "xGreyD"))
ex("x_spike_gold", seg([0, -0.004, 0], 0, 0.016, 0.05, "xGoldD"))
ex("x_bolt",                               // a stone bolt (Stasis)
  cyl(0.016, 0.012, { mat: "xGrey", sides: 6, pos: [0, 0.004, 0] }),
  sphere(0.009, { mat: "xGreyD", pos: [0, 0.012, 0], detail: 0 }))
ex("x_crest",                              // an orange crest of points round a collar
  ...range(5, (k) => seg([0, -0.004, (k - 2) * 0.022], 90 - Math.abs(k - 2) * 15, 0.014, 0.06 - Math.abs(k - 2) * 0.01, "xOrange", { sides: 4 })))
ex("x_sunflower",                          // a sunflower on the shoulder (Joroba)
  cyl(0.02, 0.01, { mat: "xWood", sides: 8, pos: [0, 0.008, 0] }),
  ...range(10, (k) => box(0.022, 0.006, 0.012, { mat: "xWool", pos: [0.03 * Math.cos(k * 0.628), 0.008, 0.03 * Math.sin(k * 0.628)], rot: [0, -k * 36, 0] })))
ex("x_flower",                             // a teal flower (wonejo)
  sphere(0.012, { mat: "xWhite", pos: [0, 0.01, 0], detail: 0 }),
  ...range(6, (k) => sphere(0.013, { mat: "xTeal", pos: [0.018 * Math.cos(k * 1.047), 0.008, 0.018 * Math.sin(k * 1.047)], scale: [1, 0.5, 1], detail: 0 })))
ex("x_feathers",                           // a fan of white and blue feathers (Gosbaster)
  ...range(5, (k) => seg([0, -0.004, (k - 2) * 0.015], 75 - Math.abs(k - 2) * 12, 0.012, 0.08, k % 2 ? "xIce" : "xWhite", { sides: 4 })))
ex("x_skull",                              // a little skull on the toe (Aplastacampis)
  sphere(0.025, { mat: "xSkull", pos: [0, 0.022, 0], scale: [1, 0.9, 1], detail: 1 }),
  sphere(0.009, { mat: "xBlack", pos: [0.004, 0.038, 0.011], detail: 0 }),
  sphere(0.009, { mat: "xBlack", pos: [0.004, 0.038, -0.011], detail: 0 }))
ex("x_glasses",                            // round sunglasses pushed up on the head (Zar)
  torus(0.022, 0.004, { mat: "xBlack", pos: [0, 0.006, 0.026], sides: 4, rings: 10 }),
  torus(0.022, 0.004, { mat: "xBlack", pos: [0, 0.006, -0.026], sides: 4, rings: 10 }),
  cyl(0.02, 0.003, { mat: "xTeal", sides: 10, pos: [0, 0.006, 0.026] }),
  cyl(0.02, 0.003, { mat: "xTeal", sides: 10, pos: [0, 0.006, -0.026] }))
// a ring of big red beads round the chest (Lolomg): sized like the leg rings
ex("x_bead_ring", ...range(9, (k) => sphere(0.016, { mat: "xRed", pos: [0.05 * Math.cos(k * 0.698), 0, 0.05 * Math.sin(k * 0.698)], detail: 1 })))
}
