// S35c test: one coach hat, card 213 "Casco del Dragón Blanco". Own design;
// the retail illustration only gave the idea (a white dragon, blue horns).
// Convention as hats.kx.js: pivot "origin", y = 0 is where the hat sits on
// the head (~0.27 m across there, its top ~0.12 m above), +Z is the face.
// The coach looks out from under the dragon's upper jaw, worn as a visor.
{ // the helpers below stay local to this file
pal({
  scale: "#d8e0ea", scaleD: "#93a5ba", scaleS: "#8496aa",
  ice: "#2f66b8", iceD: "#1d4484", iceL: "#7fb4e8",
  fang: "#fbf6e6", mouth: "#39486a",
  eye: { color: "#58c8ff", emit: "#40b8ff", glow: 1.4 }, pupil: "#10203a",
})

const rad = (a) => (a * Math.PI) / 180

model("hat_test_fable", { pivot: "origin" },
  // the skull: a cap tipped back, high over the face and down over the nape, a darker rim
  tf({ rot: [-12, 0, 0] },
    lathe([0.158, -0.055, 0.172, -0.02, 0.17, 0.04, 0.145, 0.105, 0.09, 0.15, 0, 0.165], { mat: "scale", sides: 10 }),
    lathe([0.176, -0.065, 0.18, -0.04, 0.172, -0.02], { mat: "scaleD", sides: 10 })),
  tf({ pos: [0, 0.022, 0] },
  // the upper jaw: a flat tapering snout out over the forehead, its dark roof under it
  tf({ pos: [0, 0.035, 0.1], rot: [97, 0, 0] },
    tf({ scale: [1, 1, 0.5] }, lathe([0.135, 0, 0.125, 0.07, 0.095, 0.14, 0.075, 0.185, 0.05, 0.205, 0, 0.212], { mat: "scale", sides: 8 }))),
  box(0.15, 0.012, 0.15, { mat: "mouth", pos: [0, -0.034, 0.165], rot: [7, 0, 0] }),
  // the snout's ridge and the two nostrils
  box(0.026, 0.02, 0.13, { mat: "scaleD", pos: [0, 0.074, 0.14], rot: [14, 0, 0] }),
  cone(0.02, 0.06, { mat: "iceL", pos: [0, 0.05, 0.262], rot: [20, 0, 0], sides: 4 }),
  sym("x", box(0.014, 0.012, 0.022, { mat: "pupil", pos: [0.032, 0.046, 0.283], rot: [8, 25, 0] })),
  sym("x",
    // brow plates over the eyes, the eyes in their shade
    box(0.06, 0.026, 0.12, { mat: "scaleD", pos: [0.102, 0.052, 0.135], rot: [12, 20, -25] }),
    sphere(0.03, { mat: "eye", pos: [0.118, 0.034, 0.185], scale: [0.6, 0.8, 1.15], detail: 0 }),
    sphere(0.012, { mat: "pupil", pos: [0.133, 0.034, 0.196], scale: [0.5, 1.3, 0.8], detail: 0 }),
    // fangs along the edge of the jaw, the front pair longest
    ...[[0.04, 0.275, 0.055], [0.078, 0.215, 0.04], [0.105, 0.155, 0.032]].map(([x, z, h]) =>
      cone(0.013, h, { mat: "fang", pos: [x, -0.022 + (0.275 - z) * 0.12, z], rot: [180, 0, 0], sides: 4 })),
    // a horn swept back and up: three stepped lengths and a point
    tube([0.1, 0.1, -0.02, 0.155, 0.15, -0.085], 0.034, { mat: "ice", sides: 6 }),
    tube([0.15, 0.145, -0.078, 0.185, 0.2, -0.165], 0.026, { mat: "iceD", sides: 6 }),
    tube([0.182, 0.195, -0.158, 0.19, 0.265, -0.225], 0.018, { mat: "ice", sides: 4 }),
    cone(0.018, 0.07, { mat: "iceL", pos: [0.19, 0.262, -0.222], rot: [-35, 0, -4], sides: 4 }),
    // a cheek fin: three blades fanned back from the jaw's hinge
    ...[0, 1, 2].map((i) => tf({ pos: [0.165, -0.035 - i * 0.012, 0.0], rot: [0, -28, 0] },
      tf({ rot: [-62 - i * 30, 0, 0] }, cone(0.03, 0.13 - i * 0.02, { mat: i % 2 ? "iceL" : "ice", scale: [0.3, 1, 1], sides: 4 })))),
    // cheek plates down to the jaw line
    box(0.03, 0.06, 0.1, { mat: "scaleD", pos: [0.16, -0.13, 0.03], rot: [-8, 0, 4] }))),
  // a crest of fins down the middle, from the brow to the nape
  ...[[0.135, 0.03, 0.085, -8], [0.158, -0.035, 0.1, -28], [0.14, -0.1, 0.09, -52], [0.085, -0.15, 0.075, -78], [0.01, -0.172, 0.06, -100]].map(([y, z, h, a], i) =>
    cone(0.04, h, { mat: i % 2 ? "iceD" : "ice", pos: [0, y - 0.01 * Math.cos(rad(a)), z + 0.01 * Math.sin(-rad(a))], rot: [a, 0, 0], scale: [0.28, 1, 1], sides: 4 })),
  // neck plates: three scales overlapping down the nape
  ...[-1, 0, 1].map((k) => box(0.085, 0.07, 0.022, { mat: k ? "scaleD" : "scaleS", pos: [k * 0.085, -0.15 - (k ? 0 : 0.012), -0.148 + Math.abs(k) * 0.03], rot: [10, k * 32, 0] })))
}
