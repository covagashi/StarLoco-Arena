// S35c: the 13 coach staffs and standards (cards.json type 12). Own designs;
// the retail illustrations (capturas/s35/flow/ropa-coach/12-armas) only gave
// the idea. Same convention as weapons.kx.js: pivot "origin", the middle of
// the grip at the origin, the pole along +Y, flat side facing +Z. All are
// staff_ (held upright, Fighter3D.WEAPON_STYLES). A standard's cloth hangs
// off a crossbar on the -X side (away from the body in the right hand); its
// emblems go through the cloth so they show on both faces.
{ // the helpers below stay local to this include
pal({
  gold: { color: "#e8b440", metal: 0.4, rough: 0.35 }, goldD: "#a87a20", wood: "#7a5030", woodD: "#523420",
  iron: { color: "#7a808a", metal: 0.4, rough: 0.4 },
  lyre: "#e8c050", lyreD: "#b89030",
  blackC: "#2a2628", boneW: "#f0ece0",
  jestY: "#f2d038", jestW: "#f4f2ec", jestB: "#5a7ac8", bell: { color: "#d8b030", metal: 0.5, rough: 0.3 },
  redC: "#c8282a", redD: "#8a1a1a",
  teal: "#2f9a98", tealD: "#1f6e6c",
  gnaw: "#d8b848", gnawD: "#9a8030", gear: "#6a6e74",
  flameW: "#f4f0ea", flameR: { color: "#e8402a", emit: "#e8402a", glow: 0.6 },
  spike: { color: "#e8a830", metal: 0.4, rough: 0.35 },
  champK: "#3a3c40", champO: "#e8902a",
  campK: "#1e1e22", campO: "#f07a1a",
  aluK: "#1a1620", aluP: "#5a3a8a", aluW: "#f0e8d8",
  jalaR: "#c8302a", jalaW: "#f4f0e8", jalaK: "#2a2224",
  loloT: "#1e4a48", loloR: "#d8282a", loloG: "#3a8a6a",
})

const range = (n, f) => Array.from({ length: n }, (_, i) => f(i))
const T = 0.012   // cloth thickness
// a pole from the butt (-0.4) to top, a knob on it
const pole = (mat, top = 0.8, r = 0.017) => cyl(r, top + 0.4, { mat, pos: [0, -0.4, 0], sides: 6 })
// a standard: crossbar and cloth w wide, h tall, hanging from top; hem(t)
// (t 0 at the pole .. 1 at the free edge) lifts the bottom edge
function banner({ cloth, bar = "gold", w = 0.24, h = 0.42, top = 0.76, hem = () => 0, steps = 4 }) {
  const pts = [0, top, 0, top - h + hem(0)]
  for (let k = 1; k <= steps; k++) pts.push(-w * k / steps, top - h + hem(k / steps))
  pts.push(-w, top)
  return [extrude(pts, T, { mat: cloth, pos: [0, 0, -T / 2] }),
    box(w + 0.05, 0.02, 0.02, { mat: bar, pos: [-w / 2 + 0.01, top, 0] })]
}
// an emblem through the cloth at (x, y)
const emb = (x, y, item) => tf({ pos: [x, y, 0] }, item)
const zig = (n, d) => (t) => d * Math.abs((t * n) % 1 - 0.5) * 2

// 5 Laúd: a gold pole and banner, a lyre on it
model("staff_lute", { pivot: "origin" },
  pole("gold"), sphere(0.03, { mat: "gold", pos: [0, 0.81, 0], detail: 0 }),
  ...banner({ cloth: "lyre", bar: "goldD", h: 0.36 }),
  emb(-0.12, 0.58, [tube([-0.05, -0.08, 0, -0.06, 0.02, 0, -0.03, 0.08, 0], 0.01, { mat: "lyreD", sides: 4 }),
    tube([0.05, -0.08, 0, 0.06, 0.02, 0, 0.03, 0.08, 0], 0.01, { mat: "lyreD", sides: 4 }),
    box(0.1, 0.012, 0.02, { mat: "lyreD", pos: [0, -0.08, 0] }),
    ...range(3, (k) => box(0.005, 0.15, 0.02, { mat: "lyreD", pos: [-0.025 + k * 0.025, -0.08, 0] }))]))

// 11 Maza claveteada: a wooden pole with a studded iron head, a black skull flag
model("staff_mace", { pivot: "origin" },
  pole("wood"), sphere(0.06, { mat: "iron", pos: [0, 0.84, 0], detail: 1 }),
  ...range(6, (k) => cone(0.018, 0.05, { mat: "iron", pos: [Math.sin(k) * 0.055, 0.84 + Math.cos(k * 2) * 0.03, Math.cos(k) * 0.055], rot: [Math.cos(k) * 80, 0, -Math.sin(k) * 80], sides: 4 })),
  ...banner({ cloth: "blackC", bar: "woodD", h: 0.38, hem: zig(2, 0.06), top: 0.74 }),
  emb(-0.12, 0.6, [sphere(0.04, { mat: "boneW", scale: [1, 1, 0.4], detail: 0 }),
    box(0.15, 0.02, 0.02, { mat: "boneW", pos: [0, -0.07, 0], rot: [0, 0, 35] }),
    box(0.15, 0.02, 0.02, { mat: "boneW", pos: [0, -0.07, 0], rot: [0, 0, -35] })]))

// 27 Cetro de cascabeles: a striped pole, a jester's flag in two colours, bells
model("staff_bells", { pivot: "origin" },
  pole("jestB"), ...range(6, (k) => cyl(0.019, 0.06, { mat: "jestW", pos: [0, -0.3 + k * 0.18, 0], sides: 6 })),
  extrude([0, 0.78, 0, 0.5, -0.12, 0.6, -0.24, 0.72], T, { mat: "jestY", pos: [0, 0, -T / 2] }),
  extrude([0, 0.78, -0.24, 0.72, -0.18, 0.86], T, { mat: "jestW", pos: [0, 0, -T / 2 - 0.001] }),
  sphere(0.025, { mat: "bell", pos: [-0.24, 0.7, 0], detail: 1 }), sphere(0.025, { mat: "bell", pos: [-0.12, 0.58, 0], detail: 1 }),
  sphere(0.03, { mat: "bell", pos: [0, 0.81, 0], detail: 1 }))

// 32 Deshueso Sigal Ospuntos: a gold pole, a red banner with a white bone
model("staff_bone", { pivot: "origin" },
  pole("gold"), cone(0.03, 0.06, { mat: "gold", pos: [0, 0.8, 0], sides: 5 }),
  ...banner({ cloth: "redC", h: 0.4, hem: (t) => 0.05 * t }),
  emb(-0.12, 0.56, tf({ rot: [0, 0, 20] }, box(0.025, 0.2, 0.02, { mat: "boneW", pos: [0, -0.1, 0] }),
    ...[-1, 1].flatMap((s) => [-1, 1].map((t) => sphere(0.018, { mat: "boneW", pos: [t * 0.016, s * 0.1, 0], scale: [1, 1, 0.7], detail: 0 }))))))

// 38 Mh'Asalto: a gold pole, a teal banner with curling hooks down the pole side
model("staff_assault", { pivot: "origin" },
  pole("gold"), sphere(0.03, { mat: "iron", pos: [0, 0.81, 0], detail: 0 }),
  ...banner({ cloth: "teal", h: 0.44, hem: (t) => 0.1 * t * t }),
  ...range(3, (k) => torus(0.03, 0.007, { mat: "gold", pos: [0.035, 0.68 - k * 0.1, 0], rot: [90, 0, 0], sides: 4, rings: 8 })),
  emb(-0.13, 0.52, box(0.012, 0.28, 0.02, { mat: "tealD" })))

// 46 Cetro roído: a gold pole, a yellow banner with a gnawed edge and a gear
model("staff_gnawed", { pivot: "origin" },
  pole("gold"), sphere(0.03, { mat: "iron", pos: [0, 0.81, 0], detail: 0 }),
  ...banner({ cloth: "gnaw", h: 0.44, hem: (t) => (Math.floor(t * 6) % 2) * 0.05, steps: 6 }),
  ...range(5, (k) => box(0.025, 0.03, 0.02, { mat: "gnawD", pos: [-0.24, 0.7 - k * 0.08, 0], rot: [0, 0, 45] })),
  emb(-0.11, 0.6, [cyl(0.04, 0.02, { mat: "gear", rot: [90, 0, 0], pos: [0, 0, 0.01], sides: 8 }),
    ...range(8, (k) => box(0.02, 0.02, 0.02, { mat: "gear", pos: [Math.sin(k * 0.785) * 0.045, Math.cos(k * 0.785) * 0.045, 0] }))]))

// 53 Aurea flamma: a red-and-white pole, a white pennant with a red flame
model("staff_flame", { pivot: "origin" },
  pole("flameW"), ...range(6, (k) => cyl(0.019, 0.06, { mat: "redC", pos: [0, -0.3 + k * 0.18, 0], sides: 6 })),
  extrude([0, 0.8, 0, 0.5, -0.26, 0.62, -0.2, 0.7, -0.26, 0.78], T, { mat: "flameW", pos: [0, 0, -T / 2] }),
  emb(-0.08, 0.6, cone(0.04, 0.12, { mat: "flameR", sides: 3, scale: [1, 1, 0.3] })),
  cone(0.025, 0.06, { mat: "redC", pos: [0, 0.8, 0], sides: 5 }))

// 147 Bastón Rompedor: a gold staff with a jagged spearhead
model("staff_breaker", { pivot: "origin" },
  pole("woodD", 0.62), cyl(0.03, 0.05, { mat: "spike", pos: [0, 0.6, 0], sides: 6 }),
  extrude([0, 0.64, 0.05, 0.7, 0.03, 0.76, 0.06, 0.82, 0.02, 0.88, 0, 0.98, -0.02, 0.88, -0.06, 0.82, -0.03, 0.76, -0.05, 0.7], 0.02, { mat: "spike", pos: [0, 0, -0.01] }),
  ...[-1, 1].map((s) => cone(0.015, 0.08, { mat: "spike", pos: [s * 0.04, 0.66, 0], rot: [0, 0, -s * 60], sides: 3 })))

// 183 / 195 Campeón and Campierrele: a dark banner, ragged, with bars
const champ = (cloth, mark) => [pole("iron"), cone(0.025, 0.08, { mat: mark, pos: [0, 0.8, 0], sides: 4 }),
  ...banner({ cloth, bar: "iron", h: 0.5, hem: zig(3, 0.07), steps: 6 }),
  ...range(3, (k) => emb(-0.12, 0.66 - k * 0.07, box(0.08, 0.018, 0.02, { mat: mark })))]
model("staff_champion", { pivot: "origin" }, ...champ("champK", "champO"))
model("staff_campierrele", { pivot: "origin" }, ...champ("campK", "campO"),
  emb(-0.12, 0.42, [box(0.05, 0.012, 0.02, { mat: "campO", pos: [-0.05, 0, 0] }), box(0.012, 0.06, 0.02, { mat: "campO", rot: [0, 0, 20] }),
    box(0.05, 0.012, 0.02, { mat: "campO", pos: [0.05, 0, 0] })]))

// 221 Estandarte de Alu-Card: a dark pole, a long purple banner with tails and a skull
model("staff_alucard", { pivot: "origin" },
  pole("aluK"), extrude([0, 0, 0.06, 0.02, 0.02, 0.06], 0.02, { mat: "iron", pos: [0, 0.78, -0.01] }),
  ...banner({ cloth: "aluP", bar: "aluK", h: 0.6, hem: zig(2, 0.14), steps: 4 }),
  emb(-0.12, 0.62, [sphere(0.035, { mat: "aluW", scale: [1, 1.1, 0.4], detail: 0 }), box(0.012, 0.3, 0.02, { mat: "aluW", pos: [-0.015, -0.33, 0] }),
    box(0.012, 0.3, 0.02, { mat: "aluW", pos: [0.015, -0.33, 0] })]))

// 230 Estandarte de jálabol: a red banner with gold trim and a white sheep's face
model("staff_jalabol", { pivot: "origin" },
  pole("gold"), sphere(0.03, { mat: "gold", pos: [0, 0.81, 0], detail: 0 }),
  ...banner({ cloth: "jalaR", h: 0.48, hem: zig(3, 0.06), steps: 6 }),
  emb(-0.12, 0.74, box(0.22, 0.02, 0.02, { mat: "gold" })),
  emb(-0.12, 0.56, [...range(6, (k) => sphere(0.03, { mat: "jalaW", pos: [Math.sin(k * 1.05) * 0.05, Math.cos(k * 1.05) * 0.05, 0], scale: [1, 1, 0.5], detail: 0 })),
    sphere(0.035, { mat: "jalaW", scale: [1, 1, 0.5], detail: 0 }),
    ...[-1, 1].map((s) => sphere(0.01, { mat: "jalaK", pos: [s * 0.02, 0.01, 0.015], detail: 0 }))]))

// 889 Estandarte de Lolomg: a crossbar with balls, a dark teal banner splashed red
model("staff_lolomg", { pivot: "origin" },
  pole("loloG"), sphere(0.035, { mat: "loloG", pos: [0, 0.82, 0], detail: 0 }),
  ...banner({ cloth: "loloT", bar: "loloG", w: 0.28, h: 0.46, hem: (t) => 0.08 * Math.sin(t * Math.PI) }),
  sphere(0.025, { mat: "loloG", pos: [-0.3, 0.76, 0], detail: 0 }),
  ...[[-0.08, 0.6, 0.04], [-0.17, 0.5, 0.035], [-0.12, 0.42, 0.025], [-0.22, 0.64, 0.02]].map(([x, y, r]) =>
    emb(x, y, sphere(r, { mat: "loloR", scale: [1.3, 1, 0.4], detail: 0 }))))
}
