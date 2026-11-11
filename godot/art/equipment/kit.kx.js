// S35c pilot pieces: rigid equipment hung from a rig bone (Fighter3D.equip).
// Own designs; sized for a 1.45 m fighter's head (~0.30 m across with hair).
pal({ straw: "#d9b65a", strawL: "#ecd07a", strawD: "#a9853a", band: "#7a3b2e",
  gem: { color: "#57c27a", emit: "#3fbf6a", glow: 1.5, rough: 0.2 }, gold: { color: "#e8b440", metal: 0.4, rough: 0.35 } })

// a wide straw hat: brim, crown, a red band
model("hat_straw",
  cyl(0.24, 0.025, { mat: "straw", sides: 12, jitter: 0.012 }),
  cyl(0.135, 0.12, { mat: "strawL", sides: 10, top: 0.11, pos: [0, 0.02, 0], jitter: 0.008 }),
  cyl(0.138, 0.03, { mat: "band", sides: 10, pos: [0, 0.03, 0] }),
  cyl(0.115, 0.012, { mat: "strawD", sides: 10, pos: [0, 0.135, 0] }))

// a dofus: an egg that floats beside the fighter
model("dofus_green",
  lathe([0, 0, 0.05, 0.02, 0.075, 0.07, 0.07, 0.11, 0.045, 0.15, 0, 0.165], { mat: "gem", sides: 10 }),
  torus(0.076, 0.008, { mat: "gold", pos: [0, 0.07, 0], sides: 12 }))
