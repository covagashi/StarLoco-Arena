// S35c: the 13 coach bracelets (cards.json type 5). Own designs; the retail
// illustrations (capturas/s35/flow/ropa-coach/05-brazaletes) only gave the
// idea. One bracelet, for the left forearm (Fighter3D.hang wears a pair):
// pivot "origin" in its middle, a sleeve about +Y (+Y towards the elbow),
// its outside towards +X, its front +Z, for a forearm 0.04 m thick. The
// right arm wears it mirrored, or "<name>_r" when the pair differs.
{ // the helpers below stay local to this include
pal({
  brLeather: "#6a4428", brLeatherD: "#4a2e1a", brSteel: { color: "#c0c6d0", metal: 0.5, rough: 0.3 },
  brWoolY: "#ecc63a", brWoolYD: "#c8a020", brWoolR: "#d8302a", brWoolRD: "#a8201c",
  brWood: "#b8742a", brWoodD: "#8a5018", brWire: { color: "#a8b0b8", metal: 0.4, rough: 0.4 },
  brKep: "#2a2422", brKepO: "#e8901c", brHorn: "#f0ead8",
  brGold: { color: "#e8b830", metal: 0.4, rough: 0.35 }, brGoldD: "#b08418",
  brSed: "#d8401c", brSedL: "#f0e2b8", brSedG: "#8ab030", brStrap: "#7a3a1a",
  brRomp: "#c8922a", brRompD: "#8a6018",
  brSq: "#c8d040", brSqD: "#a0a828", brSqT: "#2a8a78",
  brGrey: "#8a9088", brOrange: "#e8781c", brRed: "#c03a24", brCream: "#f0e0b0", brYellow: "#f0c040",
  brAlu: "#3a2a4a", brAluD: "#24182e",
  brBoss: "#b8982a", brBossD: "#6a5418",
  brStone: "#7a7c80", brStoneD: "#5a5c60",
})

const range = (n, f) => Array.from({ length: n }, (_, i) => f(i))
// the cuff: an open sleeve about Y, a little wider at the elbow
const cuff = (mat, h = 0.08, r = 0.046, o = {}) => lathe(
  [r * 0.96, -h / 2, r, -h / 2 + 0.006, r * 1.04, h / 2 - 0.006, r * 1.02, h / 2],
  { mat, sides: o.sides ?? 9, pos: o.pos ?? [0, 0, 0], jitter: o.jitter })
// a ring round the cuff at height y
const band = (mat, y, r = 0.049, t = 0.008) => torus(r, t, { mat, pos: [0, y, 0], sides: 4, rings: 10 })
// a point on the cuff's outside at angle a (0 = +X outside, 90 = +Z front)
const at = (a, y, r = 0.048) => [r * Math.cos(a * Math.PI / 180), y, r * Math.sin(a * Math.PI / 180)]

// 7 Brazaletes de fuerza: a brown leather cuff with a steel stud outside
model("bracelets_strength", { pivot: "origin" },
  cuff("brLeather", 0.085, 0.046, { jitter: 0.003 }),
  band("brLeatherD", 0.036, 0.048, 0.007), band("brLeatherD", -0.036, 0.047, 0.007),
  sphere(0.014, { mat: "brSteel", pos: at(0, 0, 0.05), scale: [0.6, 1, 1], detail: 1 }))

// 17 Brazaletes Jalatranki: rolls of yellow wool, red ones on the other arm
const rolls = (m, d) => range(3, (k) => torus(0.05, 0.016, { mat: k % 2 ? d : m, pos: [0, -0.03 + k * 0.03, 0], sides: 5, rings: 9, jitter: 0.003 }))
model("bracelets_jalatranki", { pivot: "origin" }, cuff("brWoolYD", 0.08, 0.044), ...rolls("brWoolY", "brWoolYD"))
model("bracelets_jalatranki_r", { pivot: "origin" }, cuff("brWoolRD", 0.08, 0.044), ...rolls("brWoolR", "brWoolRD"))

// 44 Alambrada espinosa: wooden slats bound with barbed wire
model("bracelets_barbed", { pivot: "origin" },
  ...range(8, (k) => box(0.022, 0.09, 0.01, { mat: k % 2 ? "brWoodD" : "brWood", pos: at(k * 45, -0.045, 0.049), rot: [0, 90 - k * 45, 0] })),
  ...[-0.02, 0.02].flatMap((y) => [band("brWire", y, 0.056, 0.004),
    ...range(6, (k) => cone(0.005, 0.018, { mat: "brWire", pos: at(k * 60 + (y > 0 ? 30 : 0), y, 0.058), rot: [0, 90 - (k * 60 + (y > 0 ? 30 : 0)), -90], sides: 3 }))]))

// 112 Brazaletes Kepika: a black cuff, an orange rim, a white horn outside
model("bracelets_kepika", { pivot: "origin" },
  cuff("brKep", 0.08),
  band("brKepO", 0.038, 0.049, 0.007), band("brKepO", -0.038, 0.048, 0.006),
  tube([0.05, -0.01, 0, 0.075, 0.01, 0, 0.09, 0.05, 0], 0.011, { mat: "brHorn", sides: 5 }),
  cone(0.011, 0.025, { mat: "brHorn", pos: [0.09, 0.05, 0], rot: [0, 0, -15], sides: 5 }))

// 121 Brazaletes de Krono: a gold cuff with a crest outside and rivets
model("bracelets_krono", { pivot: "origin" },
  cuff("brGold", 0.085),
  extrude([0, -0.04, 0.035, -0.02, 0.045, 0.03, 0.015, 0.06, 0, 0.04], 0.012, { mat: "brGoldD", pos: [0.045, 0, -0.006] }),
  ...[-90, 90, 180].map((a) => sphere(0.008, { mat: "brGoldD", pos: at(a, 0, 0.05), detail: 0 })))

// 129 Brazaletes Sedforme: a red cuff, a cream panel in front, two straps
// and a green fin outside
model("bracelets_sedforme", { pivot: "origin" },
  cuff("brSed", 0.09),
  box(0.045, 0.08, 0.008, { mat: "brSedL", pos: [0, -0.04, 0.05] }),
  band("brStrap", 0.02, 0.052, 0.006), band("brStrap", -0.022, 0.052, 0.006),
  cone(0.02, 0.07, { mat: "brSedG", pos: [0.05, -0.03, 0], rot: [0, 0, -12], sides: 3, scale: [1, 1, 0.3] }))

// 140 Brazaletes Rompedores: an ochre leather cuff, a jagged hem, spikes
model("bracelets_rompedores", { pivot: "origin" },
  cuff("brRomp", 0.085, 0.047, { jitter: 0.003 }),
  ...range(6, (k) => cone(0.012, 0.03, { mat: "brRompD", pos: at(k * 60, -0.035, 0.044), rot: [180, 0, 0], sides: 3 })),
  ...[-30, 30].map((a) => cone(0.01, 0.035, { mat: "brRompD", pos: at(a, 0.005, 0.046), rot: [0, -a, -90], sides: 4 })))

// 179 Brazaletes del escudero: yellow-green cloth wrapped round, a teal band,
// a frayed cuff below
model("bracelets_squire", { pivot: "origin" },
  cuff("brSq", 0.075, 0.047),
  band("brSqT", 0.005, 0.051, 0.01),
  ...range(8, (k) => box(0.014, 0.03, 0.006, { mat: k % 2 ? "brSqD" : "brSq", pos: at(k * 45, -0.06, 0.046), rot: [0, 90 - k * 45, 0] })))

// 188 Brazalete del Campeón: bands of grey, orange and red
model("bracelets_champion", { pivot: "origin" },
  cuff("brGrey", 0.08),
  ...["brOrange", "brRed", "brOrange"].map((m, k) => band(m, -0.025 + k * 0.025, 0.05, 0.009)))

// 191 Brazalete del Campierrele: bands of cream, orange and yellow
model("bracelets_campierrele", { pivot: "origin" },
  cuff("brCream", 0.08),
  ...["brOrange", "brYellow", "brOrange"].map((m, k) => band(m, -0.025 + k * 0.025, 0.05, 0.009)))

// 220 Brazaletes de Alu-Card: a purple cuff, rivets and one steel spike out
model("bracelets_alucard", { pivot: "origin" },
  cuff("brAlu", 0.085),
  band("brAluD", 0.038, 0.049, 0.006),
  cone(0.016, 0.05, { mat: "brSteel", pos: at(0, 0, 0.046), rot: [0, 0, -90], sides: 5 }),
  ...[60, 120, -60, -120].map((a) => sphere(0.006, { mat: "brSteel", pos: at(a, -0.02, 0.049), detail: 0 })))

// 865 Brazaletes de Superjefe: a long gold bracer with a ridge outside
model("bracelets_boss", { pivot: "origin" },
  cuff("brBoss", 0.11, 0.047, { sides: 7 }),
  box(0.012, 0.1, 0.014, { mat: "brBossD", pos: [0.048, -0.05, 0] }),
  band("brBossD", 0.05, 0.051, 0.006))

// 888 Brazaletes de Lolomg: twisted grey stone rings
model("bracelets_lolomg", { pivot: "origin" },
  cuff("brStoneD", 0.09, 0.044),
  ...range(4, (k) => torus(0.05, 0.012, { mat: k % 2 ? "brStoneD" : "brStone", pos: [0, -0.036 + k * 0.024, 0], rot: [k % 2 ? 8 : -8, k * 40, 0], sides: 4, rings: 8, jitter: 0.004 })))
}
