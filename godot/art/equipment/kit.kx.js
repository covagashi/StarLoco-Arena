// S35c: the fighter equipment pieces, rigid, hung from a rig bone or beside
// the figure (Fighter3D.equip). Own designs; the straw hat was the pilot.
pal({ steel: { color: "#c9d2dc", metal: 0.5, rough: 0.35 }, steelD: "#8c97a6", leather: "#6b4430",
  straw: "#d9b65a", strawL: "#ecd07a", strawD: "#a9853a", band: "#7a3b2e",
  gem: { color: "#57c27a", emit: "#3fbf6a", glow: 1.5, rough: 0.2 }, gold: { color: "#e8b440", metal: 0.4, rough: 0.35 } })

// a wide straw hat: brim, crown, a red band
model("hat_straw",
  cyl(0.24, 0.025, { mat: "straw", sides: 12, jitter: 0.012 }),
  cyl(0.135, 0.12, { mat: "strawL", sides: 10, top: 0.11, pos: [0, 0.02, 0], jitter: 0.008 }),
  cyl(0.138, 0.03, { mat: "band", sides: 10, pos: [0, 0.03, 0] }),
  cyl(0.115, 0.012, { mat: "strawD", sides: 10, pos: [0, 0.135, 0] }))


include("hats.kx.js")
include("weapons.kx.js")
include("cape_kit.kx.js")
include("capes.kx.js")
include("pets.kx.js")
include("dofus.kx.js")
include("coach_hats.kx.js")
include("coach_capes.kx.js")
