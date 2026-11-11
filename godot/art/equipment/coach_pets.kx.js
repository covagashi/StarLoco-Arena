// S35c: the coach pets without a fighter twin (cards.json type 13; Miaumiau
// and Wauwau wear the fighter's pet_miaumiau and pet_wauwau). Own designs,
// from the card names (no retail illustration in ropa-coach). Same
// convention as pets.kx.js: pivot "origin", feet at the origin, facing +Z,
// ~0.16 m tall, on the left shoulder.
{ // the helpers below stay local to this include
pal({
  eyeW: "#f8f6f0", pupil: "#1e1a1a",
  carrot: "#f08a1c", carrotD: "#c25a12", leaf: "#5aa83a", leafD: "#3a7a24",
  demon: "#c83a4a", demonD: "#8a2232", horn: "#2a2224", wing: "#5a2a3a",
  imp: "#e85a2a", impD: "#a83a1a", impY: "#f0c040",
  clockG: { color: "#d8b040", metal: 0.4, rough: 0.35 }, face: "#f4f0e4", hand: "#2a2224", clockD: "#8a6a20",
  doll: "#e8c8a0", dollR: "#b8282a", stitch: "#3a2a20", bandage: "#f0ece0",
})

const range = (n, f) => Array.from({ length: n }, (_, i) => f(i))
const eyes = (dx, y, z, r = 0.018) => sym("x",
  sphere(r, { mat: "eyeW", pos: [dx, y, z], scale: [1, 1.15, 0.6], detail: 1 }),
  sphere(r * 0.45, { mat: "pupil", pos: [dx, y - r * 0.15, z + r * 0.5], detail: 0 }))

// 71 Zanahowia pataleante: a kicking carrot, leafy top, little legs
model("pet_carrot", { pivot: "origin" },
  sym("x", tube([0.02, 0.05, 0, 0.035, 0.02, 0.02, 0.04, 0, 0.03], 0.009, { mat: "carrotD", sides: 4 })),
  lathe([0, 0.03, 0.03, 0.05, 0.05, 0.11, 0.045, 0.16, 0, 0.17], { mat: "carrot", sides: 7 }),
  ...range(3, (k) => box(0.03, 0.006, 0.006, { mat: "carrotD", pos: [0, 0.07 + k * 0.03, 0.044], rot: [0, 0, 10 - k * 10] })),
  eyes(0.018, 0.13, 0.04, 0.014),
  ...range(4, (k) => cone(0.018, 0.08, { mat: k % 2 ? "leafD" : "leaf", pos: [0, 0.165, 0], rot: [(k - 1.5) * 18, k * 45, (k - 1.5) * 12], sides: 3 })))

// 88 Demonita: a little red she-demon, horns, bat wings, a pointed tail
model("pet_demonita", { pivot: "origin" },
  sym("x", cyl(0.012, 0.035, { mat: "demonD", pos: [0.02, 0, 0], sides: 5 })),
  sphere(0.036, { mat: "demon", pos: [0, 0.06, 0], scale: [1, 1.1, 0.9], detail: 1 }),
  sphere(0.05, { mat: "demon", pos: [0, 0.13, 0.005], detail: 1 }),
  eyes(0.02, 0.14, 0.04, 0.015),
  sym("x", cone(0.012, 0.045, { mat: "horn", pos: [0.03, 0.17, 0], rot: [0, 0, -25], sides: 4 }),
    cone(0.035, 0.09, { mat: "wing", pos: [0.03, 0.08, -0.03], rot: [-20, 0, -70], sides: 3, scale: [1, 1, 0.3] })),
  tube([0, 0.04, -0.03, 0, 0.03, -0.07, 0, 0.07, -0.09], 0.006, { mat: "demonD", sides: 4 }),
  cone(0.015, 0.025, { mat: "demonD", pos: [0, 0.07, -0.09], sides: 3 }))

// 92 Diablotín: an orange imp, big ears, a wide grin, a yellow belly
model("pet_imp", { pivot: "origin" },
  sym("x", cyl(0.013, 0.03, { mat: "impD", pos: [0.022, 0, 0], sides: 5 })),
  sphere(0.042, { mat: "imp", pos: [0, 0.06, 0], detail: 1 }),
  sphere(0.028, { mat: "impY", pos: [0, 0.055, 0.025], scale: [1, 1.1, 0.5], detail: 0 }),
  sphere(0.05, { mat: "imp", pos: [0, 0.13, 0.005], scale: [1.15, 0.95, 1], detail: 1 }),
  eyes(0.022, 0.145, 0.04, 0.014),
  box(0.05, 0.008, 0.01, { mat: "pupil", pos: [0, 0.11, 0.05] }),
  sym("x", cone(0.025, 0.07, { mat: "imp", pos: [0.05, 0.14, 0], rot: [0, 0, -75], sides: 3, scale: [1, 1, 0.4] })))

// 99 Reloj: a walking pocket watch, a face with hands, a crown and feet
model("pet_clock", { pivot: "origin" },
  sym("x", tube([0.02, 0.03, 0, 0.03, 0.01, 0.01, 0.032, 0, 0.025], 0.008, { mat: "hand", sides: 4 })),
  cyl(0.065, 0.04, { mat: "clockG", pos: [0, 0.095, -0.02], rot: [90, 0, 0], sides: 10 }),
  cyl(0.055, 0.006, { mat: "face", pos: [0, 0.095, 0.021], rot: [90, 0, 0], sides: 10 }),
  box(0.006, 0.04, 0.006, { mat: "hand", pos: [0, 0.095, 0.026] }),
  box(0.03, 0.006, 0.006, { mat: "hand", pos: [0.014, 0.095, 0.026] }),
  cyl(0.012, 0.02, { mat: "clockD", pos: [0, 0.16, 0], sides: 6 }),
  torus(0.018, 0.005, { mat: "clockG", pos: [0, 0.19, 0], rot: [90, 0, 0], sides: 4, rings: 10 }),
  eyes(0.022, 0.12, 0.024, 0.01))

// 103 Sacrificada: a patched rag doll, stitched eyes, a red bandage
model("pet_ragdoll", { pivot: "origin" },
  sym("x", cyl(0.013, 0.035, { mat: "doll", pos: [0.02, 0, 0], sides: 5 }),
    tube([0.035, 0.08, 0, 0.055, 0.05, 0.01], 0.01, { mat: "doll", sides: 4 })),
  box(0.06, 0.06, 0.04, { mat: "dollR", pos: [0, 0.03, 0] }),
  sphere(0.05, { mat: "doll", pos: [0, 0.12, 0], detail: 1 }),
  ...[-1, 1].map((s) => tf({ pos: [s * 0.02, 0.125, 0.047] },
    box(0.02, 0.005, 0.005, { mat: "stitch", rot: [0, 0, 45] }), box(0.02, 0.005, 0.005, { mat: "stitch", rot: [0, 0, -45] }))),
  torus(0.049, 0.008, { mat: "bandage", pos: [0, 0.145, 0], rot: [10, 0, -15], sides: 4, rings: 12 }),
  box(0.03, 0.005, 0.005, { mat: "stitch", pos: [0, 0.095, 0.048] }))
}
