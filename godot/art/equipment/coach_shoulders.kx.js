// S35c: the 13 coach shoulderpads (cards.json type 7). Own designs; the
// retail illustrations (capturas/s35/flow/ropa-coach/07-hombreras) only gave
// the idea. One pad, for the left shoulder (Fighter3D.hang wears a pair):
// pivot "origin" on the skin at the top of the shoulder, upright, its
// outside towards +X, its front +Z, for an upper arm 0.05 m thick. pad()
// lowers each one by how high its inside rises, so the cap rests on the
// skin instead of floating over it. The right arm
// wears it mirrored, or "<name>_r" when the pair differs.
{ // the helpers below stay local to this include
pal({
  spEye: "#f8f6f0", spPupil: "#1e1a1a",
  spYog: "#6a3a2e", spYogD: "#4a2620", spYogL: "#8a5040", spClaw: "#e8e0c8",
  spWoolY: "#ecc63a", spWoolYD: "#c8a020", spWoolR: "#d8302a", spWoolRD: "#a8201c",
  spWing: "#f4f2ea", spWingD: "#d8d4c6", spRed: "#b8202a", spRedD: "#701420",
  spKep: "#e8901c", spKepD: "#b86410", spHorn: "#f0ead8",
  spGold: { color: "#e8b830", metal: 0.4, rough: 0.35 }, spGoldD: "#b08418",
  spSed: "#d8401c", spSedD: "#a82a12", spSedY: "#f0c040",
  spRomp: "#c8922a", spRompD: "#8a6018", spStitch: "#4a3018",
  spAlu: "#3a2a4a", spAluD: "#24182e", spBone: "#f0ead8", spSteel: { color: "#b8bec8", metal: 0.5, rough: 0.35 },
  spWar: "#3a5a58", spWarD: "#243c3a", spWarL: "#e8e0c8",
  spSta: "#7a7868", spStaD: "#545248", spStaL: "#a8a694",
  spBoss: "#a8902a", spBossD: "#5a4a18", spBossO: "#e8761c",
  spSam: "#b8a030", spSamD: "#86741c", spSamL: "#e0cc70",
  spCloud: "#f4f8fc", spCloudD: "#c8d8e8",
})

const LEAN = -38   // the cap leans out, over the deltoid
const pad = (name, sink, ...items) => model(name, { pivot: "origin" }, tf({ pos: [0, -sink, 0] }, ...items))
const range = (n, f) => Array.from({ length: n }, (_, i) => f(i))
// the cap: a dome over the shoulder, its axis leaning out; open below
const dome = (mat, r = 0.075, h = 0.055, o = {}) => lathe(
  [r, -0.025, r * 0.98, 0.0, r * 0.85, h * 0.55, r * 0.55, h * 0.9, 0, h],
  { mat, sides: o.sides ?? 9, pos: o.pos ?? [0.01, -0.01, 0], rot: o.rot ?? [0, 0, LEAN], scale: o.scale, jitter: o.jitter })
// a point on the dome's surface (as dome() leans it): a across the front
// (0 = outside +X, 90 = front +Z), v up (0 rim .. 1 top), lifted d off it
const onDome = (a, v, r = 0.075, h = 0.055, d = 0.004) => {
  const t = v * Math.PI / 2, rr = (r + d) * Math.cos(t), y = (h + d) * Math.sin(t)
  const x = rr * Math.cos(a * Math.PI / 180), z = rr * Math.sin(a * Math.PI / 180), c = Math.cos(LEAN * Math.PI / 180), sn = Math.sin(LEAN * Math.PI / 180)
  return [x * c - y * sn + 0.01, x * sn + y * c - 0.01, z]
}
const eyes = (x, y, z, r = 0.012) => [-1, 1].flatMap((s) => [
  sphere(r, { mat: "spEye", pos: [x, y, z + s * r * 1.6], scale: [0.6, 1.1, 1], detail: 1 }),
  sphere(r * 0.5, { mat: "spPupil", pos: [x + r * 0.45, y, z + s * r * 1.6], detail: 0 })])

// 10 Hombreras Yoghi: a furry brown critter's head on the shoulder, a mane
// of tufts, eyes and a snout looking out
pad("shoulders_yoghi", 0.045,
  dome("spYog", 0.075, 0.06, { jitter: 0.006 }),
  ...range(7, (k) => cone(0.022, 0.07, { mat: k % 2 ? "spYogD" : "spYogL", pos: [-0.01 + k * 0.003, 0.03, -0.045 + k * 0.015], rot: [(k - 3) * 12, 0, 20 - k * 2], sides: 4 })),
  sphere(0.03, { mat: "spYogL", pos: [0.075, -0.005, 0], scale: [1.2, 0.8, 1], detail: 1 }),
  sphere(0.01, { mat: "spPupil", pos: [0.11, 0.0, 0], detail: 0 }),
  ...eyes(0.06, 0.03, 0),
  ...[-1, 1].map((s) => cone(0.008, 0.022, { mat: "spClaw", pos: [0.075, -0.03, s * 0.018], rot: [180, 0, 0], sides: 3 })))

// 21 Hombreras Jalatranki: a ball of yellow wool, a red one on the other side
const wool = (m, d) => [
  sphere(0.05, { mat: m, pos: [0.025, 0.02, 0], detail: 1, jitter: 0.006 }),
  ...range(6, (k) => sphere(0.03, { mat: k % 2 ? d : m, pos: [0.025 + 0.04 * Math.cos(k), 0.02 + 0.03 * Math.sin(k * 2.1), 0.04 * Math.sin(k)], detail: 1, jitter: 0.004 }))]
pad("shoulders_jalatranki", 0.0, ...wool("spWoolY", "spWoolYD"))
pad("shoulders_jalatranki_r", 0.0, ...wool("spWoolR", "spWoolRD"))

// 109 La Moralizadora: a white wing on one shoulder, a red hooked claw on
// the other
pad("shoulders_moral", 0.025,
  dome("spWingD", 0.06, 0.04),
  ...range(4, (k) => box(0.11 - k * 0.018, 0.012, 0.035, { mat: k % 2 ? "spWingD" : "spWing", pos: [0.0 + k * 0.004, 0.02 + k * 0.012, -0.02 - k * 0.006], rot: [0, 20, 25 + k * 8] })))
pad("shoulders_moral_r", 0.035,
  dome("spRed", 0.07, 0.05),
  tube([0.02, 0.04, 0, 0.06, 0.08, 0, 0.11, 0.09, 0, 0.14, 0.06, 0], 0.016, { mat: "spRedD", sides: 5 }),
  cone(0.016, 0.03, { mat: "spRedD", pos: [0.14, 0.06, 0], rot: [0, 0, 150], sides: 5 }))

// 116 Hombreras Kepika: an orange plate, a white horn curving up and out,
// two small spikes on the rim
pad("shoulders_kepika", 0.03,
  dome("spKep", 0.075, 0.045),
  dome("spKepD", 0.08, 0.012, { pos: [0.012, -0.03, 0], sides: 9 }),
  tube([0.02, 0.04, 0, 0.05, 0.08, 0, 0.06, 0.13, 0, 0.05, 0.17, 0], 0.014, { mat: "spHorn", sides: 5 }),
  ...[-1, 1].map((s) => cone(0.01, 0.035, { mat: "spHorn", pos: [0.075, -0.015, s * 0.035], rot: [0, 0, -95], sides: 4 })))

// 122 Hombreras de Krono: a gold cog lying on the shoulder
pad("shoulders_krono", 0.01,
  tf({ pos: [0.025, 0.0, 0], rot: [0, 0, LEAN - 12] },
    cyl(0.07, 0.022, { mat: "spGold", sides: 10 }),
    cyl(0.025, 0.026, { mat: "spGoldD", pos: [0, -0.002, 0], sides: 8 }),
    ...range(8, (k) => box(0.026, 0.022, 0.024, { mat: "spGold", pos: [0.078 * Math.cos(k * Math.PI / 4), 0, 0.078 * Math.sin(k * Math.PI / 4)], rot: [0, -k * 45, 0] }))),
  dome("spGoldD", 0.065, 0.03, { pos: [0.012, -0.015, 0] }))

// 133 Hombreras Sedforme: a red hand gripping the shoulder, fingers spread
// up, a yellow cuff
pad("shoulders_sedforme", 0.035,
  dome("spSed", 0.07, 0.05),
  ...range(4, (k) => tube([0.03, 0.04, -0.03 + k * 0.02, 0.05, 0.08, -0.04 + k * 0.027, 0.045, 0.11, -0.045 + k * 0.03], 0.012, { mat: "spSed", sides: 5 })),
  tube([0.05, 0.0, 0.05, 0.08, 0.04, 0.06], 0.012, { mat: "spSed", sides: 5 }),
  torus(0.07, 0.01, { mat: "spSedY", pos: [0.012, -0.028, 0], rot: [0, 0, LEAN], sides: 4, rings: 10 }))

// 144 Hombreras Rompedoras: a patched leather flap folded over the shoulder
pad("shoulders_rompedoras", 0.025,
  dome("spRomp", 0.08, 0.04, { scale: [1, 1, 1.15], jitter: 0.005 }),
  sphere(0.022, { mat: "spRompD", pos: onDome(30, 0.45, 0.08, 0.04, -0.004), scale: [1, 0.35, 1], rot: [0, 0, -50], detail: 1 }),
  ...range(4, (k) => box(0.004, 0.016, 0.004, { mat: "spStitch", pos: onDome(-20 + k * 22, 0.15, 0.08, 0.04, 0.0), rot: [0, -(-20 + k * 22), -20] })))

// 216 Hombreras de Alu-Card: a purple dome, a skull on the front, an iron
// ring, fangs round the hem
pad("shoulders_alucard", 0.045,
  dome("spAlu", 0.078, 0.06),
  sphere(0.026, { mat: "spBone", pos: [0.075, 0.02, 0], scale: [0.7, 1, 1], detail: 1 }),
  ...[-1, 1].map((s) => sphere(0.007, { mat: "spPupil", pos: [0.092, 0.025, s * 0.01], detail: 0 })),
  torus(0.02, 0.006, { mat: "spSteel", pos: [0.05, -0.015, 0.06], rot: [0, 30, 0], sides: 4, rings: 8 }),
  ...range(5, (k) => cone(0.01, 0.025, { mat: "spBone", pos: [0.08 * Math.cos((k - 2) * 0.45) * 0.7 + 0.025, -0.035, 0.08 * Math.sin((k - 2) * 0.45)], rot: [180, 0, 0], sides: 3 })))

// 506 Hombreras de guerra: a dark teal plate, a steel rim and one big horn
pad("shoulders_war", 0.04,
  dome("spWar", 0.08, 0.055),
  torus(0.078, 0.008, { mat: "spSteel", pos: [0.012, -0.026, 0], rot: [0, 0, LEAN], sides: 4, rings: 10 }),
  cone(0.022, 0.1, { mat: "spWarL", pos: [0.02, 0.04, 0], rot: [0, 0, -18], sides: 5 }),
  ...[-1, 1].map((s) => sphere(0.008, { mat: "spSteel", pos: [0.06, 0.0, s * 0.04], detail: 0 })))

// 512 Hombreras Stasis: stacked grey stone plates with round studs
pad("shoulders_stasis", 0.045,
  ...range(3, (k) => dome(k % 2 ? "spStaD" : "spSta", 0.08 - k * 0.012, 0.03, { pos: [0.01 + k * 0.012, -0.01 - k * 0.022, 0], rot: [0, 0, LEAN - k * 10], sides: 7 })),
  dome("spSta", 0.06, 0.05, { pos: [0.005, 0.0, 0], sides: 7 }),
  ...[[40, 0.5], [-40, 0.5], [0, 0.8]].map(([a, v]) => sphere(0.011, { mat: "spStaL", pos: onDome(a, v, 0.06, 0.05, 0), detail: 0 })))

// 864 Hombreras de Superjefe: a gold helm-like cap with dark plates and an
// orange spiky fringe under it
pad("shoulders_boss", 0.045,
  dome("spBoss", 0.078, 0.06, { sides: 6 }),
  ...[[50, 0.45], [-30, 0.4]].map(([a, v]) => sphere(0.02, { mat: "spBossD", pos: onDome(a, v, 0.078, 0.06, -0.01), scale: [1, 0.4, 1], rot: [0, 0, -55], detail: 0 })),
  ...range(6, (k) => cone(0.014, 0.035, { mat: "spBossO", pos: [0.09 * Math.cos((k - 2.5) * 0.4) * 0.75 + 0.03, -0.04, 0.09 * Math.sin((k - 2.5) * 0.4)], rot: [0, 0, -120], sides: 3 })))

// 898 Hombreras Sámara: an olive-gold cap with a winged seed standing on it
pad("shoulders_samara", 0.04,
  dome("spSam", 0.075, 0.055),
  cone(0.03, 0.11, { mat: "spSamL", pos: [0.0, 0.04, -0.01], rot: [-12, 0, -18], sides: 3, scale: [1, 1, 0.35] }),
  cone(0.022, 0.07, { mat: "spSamD", pos: [0.02, 0.035, 0.02], rot: [20, 0, -35], sides: 3, scale: [1, 1, 0.35] }))

// 909 Hombreras Nubosas: a white cloud of puffs
pad("shoulders_cloudy", 0.0,
  sphere(0.05, { mat: "spCloud", pos: [0.02, 0.02, 0], detail: 1 }),
  ...range(5, (k) => sphere(0.032, { mat: k % 2 ? "spCloudD" : "spCloud", pos: [0.02 + 0.035 * Math.cos(k * 1.26), 0.0 + 0.02 * (k % 2), 0.045 * Math.sin(k * 1.26)], detail: 1 })))
}
