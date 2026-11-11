// S35c: the 31 coach hats and helmets (cards.json type 11). Own designs; the
// retail illustrations (capturas/s35/flow/ropa-coach/11-cascos) only gave the
// idea. Same convention as hats.kx.js: pivot "origin", y = 0 is where the hat
// sits on the head (~0.27 m across there), a helmet or mask hangs below 0.
{ // the helpers below stay local to this include
pal({
  iron: { color: "#3a3d44", metal: 0.4, rough: 0.45 }, ironL: "#5a5f6a", hornW: "#efe6d2",
  woolR: "#d8402c", woolY: "#e8c23a", woolG: "#7aa040", brownH: "#7a4a2a", stitchD: "#3a2618",
  jestB: "#a8c8ee", jestY: "#f0d040", jestO: "#e8902a", bell: { color: "#c8a030", metal: 0.5, rough: 0.3 }, bellG: "#5a8a3a",
  balR: "#c8282a", balRD: "#8a1a1a", maskW: "#f4f0e8",
  teal: "#2f8a88", tealD: "#1f6462", halo: { color: "#f0c840", emit: "#f0c040", glow: 1 },
  skull: "#f2ede2", skullR: "#c8323a", hole: "#2a2224",
  champW: "#f4f2ec", champR: "#c8202a", champD: "#d8d0c4",
  bowl: "#5c6068", bowlD: "#3e4248",
  quill: "#c8b070", quillD: "#6a5030",
  jelly: { color: "#e8505a", rough: 0.15 }, jellyL: { color: "#f8a0a8", rough: 0.15 },
  glove: "#b8301e", gloveD: "#7e1e12", band: "#f0c040",
  avi: "#d8902a", aviD: "#9e6018",
  earB: "#3a5a8a", earW: "#f0ece4", scarf: "#d8282a",
  squire: "#b8b830", squireD: "#80801e",
  champG: "#6a6e70", champK: "#2a2a2e", gold: { color: "#e8b440", metal: 0.4, rough: 0.35 },
  mortar: "#1f4f7a", mortarD: "#153a5a", tassel: "#e8902a",
  deer: "#8a6040", deerD: "#b8502a",
  dragon: "#e8eef4", dragonD: "#a8b8c8", dragonB: "#2a5aa8", fang: "#f8f4e8",
  alu: "#5a4878", aluD: "#3a2e50", aluE: { color: "#c8f040", emit: "#b8f030", glow: 1.2 },
  gos: "#2f6a70", gosD: "#1e4a50", shard: "#efe8c8",
  steel: { color: "#a8b0b8", metal: 0.5, rough: 0.35 }, rockG: "#8a8e94", plumeW: "#f0e8c8",
  coin: { color: "#f0c830", metal: 0.5, rough: 0.3 }, coinD: "#c09820",
  stasis: "#7a7468", stasisD: "#4e4a42",
  bird: "#d8282a", birdD: "#9a1a1a",
  boss: "#d88a2a", bossD: "#a8601a", bossY: "#e8c040",
  lolo: "#e8302a", loloP: "#f0a8b8",
  wonej: "#f6f2ea", wonejB: "#9ad0d8", cross: "#8a6040",
  samara: "#d8b830", samaraD: "#a88a20", leafS: "#e8d890",
  leaf: "#7ab83a", leafD: "#4e8a22", stem: "#6a4428",
  cloud: "#f4f8fc", cloudD: "#c8d8e8",
  eye: "#1e1a1a",
})

const ring = (n, f) => Array.from({ length: n }, (_, i) => f(i, (i * 360) / n))
const rad = (a) => (a * Math.PI) / 180
const at = (r, a, y) => [Math.sin(rad(a)) * r, y, Math.cos(rad(a)) * r]
// a dome cap from the rim (y0, below the head's top for a helmet) up
const dome = (mat, y0 = -0.02, r = 0.165, h = 0.17, o = {}) =>
  lathe([r - 0.01, y0, r, y0 + 0.05, r * 0.9, y0 + h * 0.6, r * 0.55, y0 + h * 0.9, 0, y0 + h], { mat, sides: 10, ...o })
// a horn: a bent tube from the side of the head, tapering by steps
const horn = (mat, x, y, pts, r = 0.03) => tube([x, y, 0, ...pts], r, { mat, sides: 5 })

// 8 Casco Hornudo: a dark iron helmet, a nose guard, two white horns
model("hat_horned", { pivot: "origin" },
  dome("iron", -0.06, 0.168, 0.2),
  box(0.035, 0.11, 0.03, { mat: "ironL", pos: [0, -0.1, 0.165] }),
  sym("x", cone(0.04, 0.2, { mat: "hornW", pos: [0.15, 0.06, 0], rot: [0, 0, -60], sides: 6 }),
    cone(0.025, 0.08, { mat: "hornW", pos: [0.3, 0.15, 0], rot: [0, 0, -10], sides: 5 })))

// 19 Gorro Jalatranki: a lumpy wool cap in red, yellow and green, brown horns
model("hat_jalatranki", { pivot: "origin" },
  dome("woolY", -0.02, 0.165, 0.15),
  ring(9, (i, a) => sphere(0.055, { mat: ["woolR", "woolY", "woolG"][i % 3], pos: at(0.13, a, 0.05 + (i % 2) * 0.04), detail: 0 })),
  ring(4, (i, a) => sphere(0.06, { mat: ["woolR", "woolG"][i % 2], pos: at(0.06, a + 30, 0.15), detail: 0 })),
  sym("x", cone(0.03, 0.1, { mat: "brownH", pos: [0.16, 0.1, 0], rot: [0, 0, -50], sides: 5 })),
  box(0.08, 0.012, 0.012, { mat: "stitchD", pos: [0.05, 0.06, 0.16], rot: [0, 0, 40] }),
  box(0.08, 0.012, 0.012, { mat: "stitchD", pos: [0.05, 0.06, 0.16], rot: [0, 0, -40] }))

// 29 Sombrero de cascabeles: a jester's cap, two floppy points with bells
model("hat_jester", { pivot: "origin" },
  cyl(0.16, 0.05, { mat: "jestO", sides: 10 }),
  dome("jestY", 0.03, 0.15, 0.1),
  tube([0, 0.08, 0, 0.12, 0.14, 0.02, 0.24, 0.1, 0.06, 0.29, 0.0, 0.08], 0.05, { mat: "jestY", sides: 6 }),
  tube([0, 0.08, 0, -0.12, 0.14, -0.02, -0.24, 0.1, -0.04, -0.29, 0.0, -0.04], 0.05, { mat: "jestB", sides: 6 }),
  sphere(0.03, { mat: "bell", pos: [0.3, -0.03, 0.08], detail: 1 }),
  sphere(0.03, { mat: "bellG", pos: [-0.3, -0.03, -0.04], detail: 1 }))

// 31 Pasamontañas rojo: a red balaclava, a white mask round the eyes, a curl
model("hat_balaclava", { pivot: "origin" },
  dome("balR", -0.2, 0.17, 0.33),
  box(0.2, 0.06, 0.03, { mat: "maskW", pos: [0, -0.07, 0.16] }),
  sym("x", sphere(0.022, { mat: "hole", pos: [0.05, -0.04, 0.178], scale: [1.2, 0.8, 0.4], detail: 0 })),
  ring(7, (i, a) => cone(0.02, 0.03, { mat: "balRD", pos: at(0.165, a - 90, -0.2), rot: [180, 0, 0], sides: 3 })),
  tube([0, 0.13, 0, 0.02, 0.2, 0.0, 0.07, 0.24, 0, 0.1, 0.2, 0], 0.012, { mat: "balR", sides: 4 }))

// 37 Sombrero puntiagudo: a teal hood with two pointed ears, stitched, a halo
model("hat_pointy", { pivot: "origin" },
  dome("teal", -0.06, 0.168, 0.2),
  sym("x", cone(0.06, 0.16, { mat: "teal", pos: [0.09, 0.1, 0], rot: [0, 0, -18], sides: 4 }),
    box(0.012, 0.1, 0.012, { mat: "tealD", pos: [0.1, 0.13, 0.04], rot: [0, 0, -18] })),
  torus(0.06, 0.008, { mat: "halo", pos: [-0.13, 0.3, 0], rot: [0, 0, 20], sides: 5, rings: 14 }))

// 48 Cabeza del Chaferombi: a white skull helmet with red stripes, eye holes
model("hat_chaferombi", { pivot: "origin" },
  dome("skull", -0.08, 0.17, 0.24),
  ring(3, (i, a) => box(0.03, 0.012, 0.18, { mat: "skullR", pos: [-0.05 + i * 0.05, 0.15 - Math.abs(i - 1) * 0.02, 0], rot: [0, 0, (i - 1) * 15] })),
  sym("x", sphere(0.04, { mat: "hole", pos: [0.06, -0.04, 0.155], scale: [1, 0.8, 0.4], detail: 0 })),
  ring(4, (i) => box(0.02, 0.03, 0.02, { mat: "skull", pos: [-0.03 + i * 0.02, -0.1, 0.16] })))

// 51 Casco Champi: a wide white mushroom cap with red spots
model("hat_champi", { pivot: "origin" },
  lathe([0.1, -0.01, 0.27, 0.02, 0.25, 0.08, 0.16, 0.15, 0, 0.17], { mat: "champW", sides: 12 }),
  cyl(0.15, 0.04, { mat: "champD", sides: 10, pos: [0, -0.03, 0] }),
  ring(6, (i, a) => sphere(0.045, { mat: "champR", pos: at(i % 2 ? 0.2 : 0.11, a, i % 2 ? 0.095 : 0.15), scale: [1, 0.35, 1], detail: 0 })))

// 55 Sombrero de Sgrim: a grey bowler, a stitched seam, a curled brim
model("hat_bowler", { pivot: "origin" },
  tf({ scale: [1, 1, 0.9] }, lathe([0.14, 0, 0.22, 0.01, 0.235, 0.04, 0.21, 0.03, 0.14, 0.02], { mat: "bowlD", sides: 12 })),
  lathe([0.15, 0, 0.155, 0.06, 0.13, 0.13, 0.07, 0.17, 0, 0.18], { mat: "bowl", sides: 10 }),
  ring(5, (i) => box(0.012, 0.03, 0.012, { mat: "stitchD", pos: [0, 0.08 + i * 0.02, 0.15 - i * 0.02], rot: [-20 - i * 10, 0, 0] })))

// 114 Casco Kepika: a mass of quills, a dark cap under it
model("hat_kepika", { pivot: "origin" },
  dome("quillD", -0.04, 0.165, 0.17),
  ...[0, 1, 2].map((k) => ring(9 - k * 2, (i, a) => cone(0.02, 0.17 - k * 0.03, { mat: k % 2 ? "quillD" : "quill",
    pos: at(0.14 - k * 0.05, a + k * 20, 0.04 + k * 0.05), rot: [Math.cos(rad(a + k * 20)) * (70 - k * 25), 0, -Math.sin(rad(a + k * 20)) * (70 - k * 25)], sides: 3 }))).flat())

// 125 Casco de gelatina: a glossy red jelly bubble round the head
model("hat_jelly", { pivot: "origin" },
  sphere(0.21, { mat: "jelly", pos: [0, 0.02, 0], scale: [1, 0.95, 1], detail: 2 }),
  sphere(0.05, { mat: "jellyL", pos: [-0.08, 0.15, 0.12], scale: [1, 0.6, 0.5], detail: 0 }),
  sphere(0.03, { mat: "jellyL", pos: [0.12, 0.1, 0.13], detail: 0 }))

// 131 Sombrero Sedforme: a yellow band with a red glove standing on it
model("hat_sedforme", { pivot: "origin" },
  cyl(0.165, 0.05, { mat: "band", sides: 10, pos: [0, -0.01, 0] }),
  ring(8, (i, a) => cone(0.025, 0.04, { mat: "band", pos: at(0.165, a, 0.035), rot: [0, 0, 0], sides: 3 })),
  box(0.15, 0.12, 0.08, { mat: "glove", pos: [0, 0.03, 0] }),
  ...[-1, 0, 1].map((k) => cyl(0.024, 0.1 - Math.abs(k) * 0.02, { mat: "glove", pos: [k * 0.045, 0.15, 0], rot: [0, 0, -k * 10], sides: 6 })),
  cyl(0.022, 0.07, { mat: "gloveD", pos: [0.08, 0.1, 0], rot: [0, 0, -55], sides: 6 }))

// 142 Sombrero Rompedor: an orange leather aviator cap with ear flaps
model("hat_aviator", { pivot: "origin" },
  dome("avi", -0.05, 0.168, 0.19),
  sym("x", box(0.04, 0.13, 0.09, { mat: "avi", pos: [0.155, -0.12, 0.0], rot: [0, 0, 6] })),
  ring(5, (i) => box(0.012, 0.012, 0.04, { mat: "aviD", pos: [0, 0.135 - i * 0.004, -0.06 + i * 0.03], rot: [i * 8 - 16, 0, 0] })))

// 172 Orejas de wabbit: two tall blue ears, white inside, a red bandana
model("hat_wabbitears", { pivot: "origin" },
  cyl(0.168, 0.06, { mat: "scarf", sides: 10, pos: [0, -0.02, 0] }),
  tube([0.0, 0.02, -0.17, -0.03, -0.05, -0.24, -0.02, -0.12, -0.27], 0.03, { mat: "scarf", sides: 4 }),
  sym("x", cone(0.05, 0.28, { mat: "earB", pos: [0.06, 0.05, 0], rot: [0, 0, -12], sides: 4, scale: [1, 1, 0.45] }),
    cone(0.028, 0.2, { mat: "earW", pos: [0.062, 0.07, 0.02], rot: [0, 0, -12], sides: 4, scale: [1, 1, 0.3] })))

// 180 Casco del escudero: an olive round helmet with ear guards, scratched
model("hat_squire", { pivot: "origin" },
  dome("squire", -0.07, 0.17, 0.21),
  sym("x", box(0.035, 0.1, 0.1, { mat: "squireD", pos: [0.158, -0.1, 0] })),
  box(0.2, 0.02, 0.02, { mat: "squireD", pos: [0, -0.06, 0.165] }),
  ring(3, (i) => box(0.06, 0.008, 0.008, { mat: "squireD", pos: [-0.04 + i * 0.04, 0.09, 0.115], rot: [-48, 0, 20 + i * 10] })))

// 187 Casco del Campeón: a grey horned helm with a black-and-gold band, fangs
model("hat_champion", { pivot: "origin" },
  dome("champG", -0.08, 0.17, 0.2),
  cyl(0.175, 0.05, { mat: "champK", sides: 10, pos: [0, -0.03, 0] }),
  ring(6, (i, a) => box(0.03, 0.05, 0.01, { mat: "gold", pos: at(0.178, a, -0.005), rot: [0, a, 0] })),
  sym("x", cone(0.04, 0.17, { mat: "hornW", pos: [0.13, 0.08, 0.03], rot: [0, 0, -45], sides: 5 }),
    cone(0.03, 0.12, { mat: "hornW", pos: [0.16, -0.02, 0.05], rot: [0, 0, -100], sides: 5 }),
    cone(0.015, 0.06, { mat: "fang", pos: [0.05, -0.06, 0.15], rot: [180, 0, 0], sides: 3 })))

// 193 Casco del Campierrele: a black-and-gold helm, two great golden horns
model("hat_campierrele", { pivot: "origin" },
  dome("champK", -0.07, 0.17, 0.2),
  ring(5, (i, a) => box(0.035, 0.12, 0.012, { mat: "gold", pos: at(0.165, a - 60, 0.02), rot: [0, a - 60, 0] })),
  sym("x", tube([0.14, 0.06, 0, 0.24, 0.12, 0.02, 0.3, 0.24, 0.0], 0.035, { mat: "gold", sides: 6 }),
    cone(0.03, 0.08, { mat: "gold", pos: [0.3, 0.24, 0], sides: 5 })))

// 199 Sombrero de Grilembore: a tilted navy mortarboard with a tassel
model("hat_mortar", { pivot: "origin" },
  cyl(0.155, 0.08, { mat: "mortarD", sides: 10, pos: [0, -0.01, 0] }),
  box(0.36, 0.025, 0.36, { mat: "mortar", pos: [0, 0.075, 0], rot: [6, 45, 0] }),
  cyl(0.015, 0.02, { mat: "tassel", pos: [0, 0.095, 0], sides: 6 }),
  tube([0, 0.1, 0, 0.12, 0.1, 0.06, 0.18, 0.02, 0.09], 0.008, { mat: "tassel", sides: 4 }))

// 210 Sombrero de L.Men'Tal: a brown deerstalker, flaps, a knot on top
model("hat_deerstalker", { pivot: "origin" },
  dome("deer", -0.03, 0.168, 0.18),
  box(0.2, 0.02, 0.12, { mat: "deer", pos: [0, 0.0, 0.18], rot: [-10, 0, 0] }),
  box(0.2, 0.02, 0.12, { mat: "deer", pos: [0, 0.0, -0.18], rot: [10, 0, 0] }),
  sym("x", box(0.03, 0.09, 0.1, { mat: "deerD", pos: [0.16, -0.05, 0] })),
  sym("x", cone(0.02, 0.06, { mat: "deerD", pos: [0.02, 0.15, 0], rot: [0, 0, -15], sides: 4 })))

// 213 Casco del Dragón Blanco: a white dragon's head, blue horns, fangs
model("hat_whitedragon", { pivot: "origin" },
  dome("dragon", -0.07, 0.17, 0.2),
  box(0.2, 0.08, 0.14, { mat: "dragon", pos: [0, -0.02, 0.17] }),
  sym("x", cone(0.014, 0.05, { mat: "fang", pos: [0.07, -0.02, 0.23], rot: [180, 0, 0], sides: 3 }),
    sphere(0.022, { mat: "dragonB", pos: [0.07, 0.06, 0.18], detail: 0 }),
    tube([0.12, 0.1, -0.02, 0.2, 0.16, -0.1, 0.23, 0.2, -0.2], 0.025, { mat: "dragonB", sides: 5 }),
    ring(3, (i) => cone(0.03, 0.06, { mat: "dragonD", pos: [0.12, 0.06 - i * 0.06, -0.12], rot: [-70, 0, -40], sides: 3 }))))

// 215 Sombrero de Alu-Card: a purple hood with two curved horns, green eyes
model("hat_alucard", { pivot: "origin" },
  dome("alu", -0.1, 0.17, 0.24),
  sym("x", tube([0.1, 0.1, 0, 0.18, 0.2, -0.03, 0.2, 0.32, -0.06, 0.16, 0.42, -0.08], 0.035, { mat: "aluD", sides: 6 }),
    sphere(0.03, { mat: "aluE", pos: [0.06, -0.06, 0.155], scale: [1, 0.8, 0.5], detail: 0 })))

// 504 Sombrero Gosbaster: a teal skull mask under a crown of bone shards
model("hat_gosbaster", { pivot: "origin" },
  dome("gos", -0.1, 0.17, 0.22),
  sym("x", sphere(0.04, { mat: "hole", pos: [0.06, -0.04, 0.15], scale: [1, 0.9, 0.4], detail: 0 })),
  ring(4, (i) => box(0.025, 0.035, 0.02, { mat: "shard", pos: [-0.04 + i * 0.027, -0.11, 0.16] })),
  ring(9, (i, a) => cone(0.03, 0.09 + (i % 2) * 0.05, { mat: "shard", pos: at(0.13, a, 0.08), rot: [-Math.cos(rad(a)) * 15, 0, Math.sin(rad(a)) * 15], sides: 3 })))

// 508 Casco de guerra: a steel helm with a nose guard, rocks on the sides, a plume
model("hat_war", { pivot: "origin" },
  dome("steel", -0.1, 0.17, 0.23),
  box(0.03, 0.14, 0.03, { mat: "iron", pos: [0, -0.16, 0.17] }),
  sym("x", rock(0.08, { mat: "rockG", pos: [0.17, 0.0, 0], seed: 3 })),
  ring(5, (i) => cone(0.025, 0.12, { mat: "plumeW", pos: [0, 0.12, 0.06 - i * 0.04], rot: [-20 - i * 12, 0, 0], sides: 3 })))

// 510 Sombrero Kamas: a big gold coin standing on the head
model("hat_kamas", { pivot: "origin" },
  cyl(0.15, 0.04, { mat: "coinD", sides: 10, pos: [0, -0.01, 0] }),
  cyl(0.2, 0.05, { mat: "coin", sides: 14, pos: [0, 0.2, -0.025], rot: [90, 0, 0] }),
  ring(3, (i, a) => box(0.2, 0.02, 0.012, { mat: "coinD", pos: [0, 0.2, 0.028], rot: [0, 0, a] })))

// 513 Sombrero Stasis: a grey round helmet, an eye slit, one horn
model("hat_stasis", { pivot: "origin" },
  dome("stasis", -0.16, 0.17, 0.3),
  box(0.2, 0.025, 0.02, { mat: "hole", pos: [0, -0.04, 0.165] }),
  box(0.025, 0.08, 0.02, { mat: "hole", pos: [0, -0.1, 0.165] }),
  cone(0.04, 0.12, { mat: "hornW", pos: [0, 0.13, 0.02], rot: [-12, 0, 0], sides: 5 }),
  cyl(0.172, 0.02, { mat: "stasisD", sides: 10, pos: [0, -0.16, 0] }))

// 544 Sombrero del pío rojo: a red bird crest of layered feathers
model("hat_redbird", { pivot: "origin" },
  dome("bird", -0.03, 0.165, 0.15),
  ...[0, 1, 2].map((k) => ring(5, (i, a) => cone(0.035, 0.16 - k * 0.02, { mat: (i + k) % 2 ? "birdD" : "bird",
    pos: [(i - 2) * 0.035, 0.12 - k * 0.04, 0.06 - k * 0.08], rot: [-60 - k * 20, 0, (i - 2) * 12], sides: 3 }))).flat(),
  cone(0.03, 0.06, { mat: "jestY", pos: [0, 0.02, 0.17], rot: [90, 0, 0], sides: 4 }))

// 860 Casco de Superjefe: an orange bird mask, a feathered crest, a beak
model("hat_boss", { pivot: "origin" },
  dome("boss", -0.08, 0.17, 0.2),
  cone(0.06, 0.14, { mat: "bossY", pos: [0, -0.03, 0.16], rot: [100, 0, 0], sides: 4 }),
  sym("x", sphere(0.025, { mat: "hole", pos: [0.06, 0.02, 0.15], detail: 0 })),
  ring(7, (i) => cone(0.035, 0.2 - Math.abs(i - 3) * 0.02, { mat: i % 2 ? "bossD" : "boss", pos: [(i - 3) * 0.04, 0.12, -0.04], rot: [-70, 0, (i - 3) * 18], sides: 3 })))

// 892 Máscara de Lolomg: a pink mask under a mop of flame-red hair
model("hat_lolomg", { pivot: "origin" },
  dome("lolo", -0.04, 0.17, 0.17),
  box(0.22, 0.07, 0.04, { mat: "loloP", pos: [0, -0.06, 0.16] }),
  sym("x", sphere(0.02, { mat: "hole", pos: [0.05, -0.05, 0.185], detail: 0 })),
  ring(9, (i, a) => cone(0.04, 0.12 + (i % 3) * 0.03, { mat: "lolo", pos: at(0.12, a, 0.1), rot: [-Math.cos(rad(a)) * 40, 0, Math.sin(rad(a)) * 40], sides: 4 })),
  cone(0.035, 0.16, { mat: "lolo", pos: [0, 0.16, -0.02], sides: 4 }))

// 896 Sombrero de wonejo: a white bunny head, floppy ears, a stitched cross
model("hat_wonejo", { pivot: "origin" },
  dome("wonej", -0.05, 0.17, 0.2),
  sym("x", tube([0.08, 0.13, 0, 0.18, 0.2, 0.0, 0.25, 0.14, 0.02], 0.04, { mat: "wonej", sides: 6 }),
    sphere(0.02, { mat: "eye", pos: [0.06, 0.04, 0.155], detail: 0 })),
  box(0.06, 0.014, 0.012, { mat: "cross", pos: [-0.07, 0.1, 0.13], rot: [-30, 0, 45] }),
  box(0.06, 0.014, 0.012, { mat: "cross", pos: [-0.07, 0.1, 0.13], rot: [-30, 0, -45] }),
  sphere(0.02, { mat: "wonejB", pos: [0, 0.0, 0.17], detail: 0 }))

// 897 Casco Sámara: a yellow helmet with a chin strap and a seed-wing plume
model("hat_samara", { pivot: "origin" },
  dome("samara", -0.06, 0.168, 0.2),
  sym("x", box(0.02, 0.15, 0.03, { mat: "samaraD", pos: [0.16, -0.12, 0.03] })),
  box(0.06, 0.04, 0.02, { mat: "samaraD", pos: [0, -0.07, 0.165] }),
  extrude([0, 0, 0.05, 0.08, 0.06, 0.22, 0.02, 0.3, -0.02, 0.18], 0.012, { mat: "leafS", pos: [0.02, 0.12, -0.02], rot: [0, 0, -20] }))

// 901 Sombrero leñoso: a green leaf cap with a brown stem
model("hat_woody", { pivot: "origin" },
  lathe([0.14, -0.01, 0.2, 0.02, 0.17, 0.09, 0.08, 0.15, 0, 0.16], { mat: "leaf", sides: 7, scale: [1, 1, 1.25] }),
  box(0.012, 0.012, 0.36, { mat: "leafD", pos: [0, 0.155, 0], rot: [-8, 0, 0] }),
  tube([0, 0.14, -0.15, 0, 0.17, -0.22, 0.02, 0.22, -0.25], 0.014, { mat: "stem", sides: 5 }))

// 908 Sombrero Nuboso: a puffy white cloud
model("hat_cloud", { pivot: "origin" },
  ring(7, (i, a) => sphere(0.08 + (i % 2) * 0.02, { mat: i % 3 ? "cloud" : "cloudD", pos: at(0.13, a, 0.03 + (i % 2) * 0.03), detail: 1 })),
  sphere(0.12, { mat: "cloud", pos: [0, 0.1, 0], detail: 1 }),
  sphere(0.07, { mat: "cloudD", pos: [0.06, 0.18, -0.02], detail: 1 }))
}
