// S35c: the 15 coach capes (cards.json type 8). Own designs; the retail
// illustrations (capturas/s35/flow/ropa-coach/08-capas) only gave the idea.
// Same convention and shape as capes.kx.js (cape_kit.kx.js, so this file is
// built through kit.kx.js): the collar's middle at the origin,
// hanging down -Y behind the back, the outer side facing -Z.
{ // the helpers below stay local to this include
const { cape, on, back, collar } = CapeKit   // cape_kit.kx.js
pal({
  lav: "#8a86c8", lavD: "#6a66a8", trim: { color: "#e8c050", metal: 0.3, rough: 0.4 },
  woolR: "#d8402c", woolY: "#e8c23a", woolG: "#7aa040", woolD: "#5a7a2a",
  prof: "#f2eee6", profD: "#d8d2c6", profR: "#c8282a",
  cig: "#d8c060", cigD: "#b09838", cigB: "#5a8a88", badge: "#c8322a",
  quillK: "#2e2a26", quillL: "#8a7a50",
  krono: "#6a9aa0", kronoD: "#4a7a80", kronoL: "#a8d0d0",
  sed: "#f0e6c0", sedD: "#d0c290",
  romp: "#c89a38", rompD: "#8a6420", patch: "#7a9a3a", leafR: "#e0c080",
  champK: "#3a3c40", champL: "#55585e", leafO: "#e8902a", leafY: "#f0c040", tassK: "#1e1e22", tassO: "#e87a1a",
  campR: "#d8402a",
  alu: "#18161c", aluP: "#4a3a6a",
  gos: "#3ab8d8", gosD: "#2a8ab0", gosW: "#eef6f8",
  bird: "#c8282a", birdD: "#8a1a1a",
  cloud: "#f4f8fc", cloudD: "#c8d8e8",
  zar: "#e8e8a0", zarD: "#c8c878", zarS: { color: "#f8e070", emit: "#f0d050", glow: 0.8 },
})

const range = (n, f) => Array.from({ length: n }, (_, i) => f(i))
const zig = (n, d) => (u) => d * Math.abs(((u + 0.5) * n) % 1 - 0.5) * 2   // a sawtooth hem

// 1 Capa Arlan Txin: lavender with a gold border down both sides and the hem
model("cape_arlan", { pivot: "origin" }, back(7,
  ...cape({ mat: (i) => i % 2 ? "lavD" : "lav", hem: (u) => Math.abs(u) * 0.14 }),
  ...[-0.47, 0.47].map((u) => on(u, -0.6 + Math.abs(u) * 0.14, box(0.03, 0.56 - Math.abs(u) * 0.14, 0.004, { mat: "trim" }))),
  ...range(6, (k) => on(-0.42 + k * 0.168, -0.6 + Math.abs(-0.42 + k * 0.168) * 0.14, box(0.08, 0.025, 0.004, { mat: "trim" }))),
  collar("trim")))

// 18 La Jalosa: a narrow column of wool tufts, red at the top, then yellow, then green
model("cape_jalatranki", { pivot: "origin" }, back(5,
  ...cape({ len: 0.56, w0: 0.26, w1: 0.28, n: 4, mat: "woolD" }),
  ...range(5, (row) => range(3, (k) => on(-0.33 + k * 0.33, -0.06 - row * 0.12,
    sphere(0.06, { mat: ["woolR", "woolY", "woolY", "woolG", "woolG"][row], detail: 0 }), { w0: 0.26, w1: 0.28, len: 0.56, lift: 0.03 }))).flat(),
  sphere(0.07, { mat: "woolR", pos: [0, 0.0, -0.04], scale: [1.6, 0.8, 1], detail: 0 })))

// 50 Capa de Profión: a slim white cape with a fluffy collar and red tips
model("cape_profion", { pivot: "origin" }, back(7,
  ...cape({ w0: 0.26, w1: 0.3, n: 4, mat: (i) => i % 2 ? "profD" : "prof", hem: zig(4, 0.08), steps: 8 }),
  ...range(4, (k) => on(-0.375 + k * 0.25, -0.6, cone(0.025, 0.05, { mat: "profR", rot: [180, 0, 0], sides: 3, scale: [1, 1, 0.4] }), { w0: 0.26, w1: 0.3 })),
  ...range(5, (k) => sphere(0.045, { mat: "prof", pos: [-0.12 + k * 0.06, -0.01, -0.02 - (k % 2) * 0.01], detail: 0 }))))

// 106 La Capa Ciguador: long and straight, ochre with a teal border, a red badge
const W106 = { len: 0.66, w1: 0.4 }
model("cape_ciguador", { pivot: "origin" }, back(6,
  ...cape({ ...W106, mat: (i) => i % 2 ? "cigD" : "cig" }),
  ...[-0.48, 0.48].map((u) => on(u, -0.64, box(0.035, 0.62, 0.004, { mat: "cigB" }), W106)),
  on(0, -0.1, box(0.07, 0.08, 0.004, { mat: "badge", rot: [0, 0, 45] }), W106),
  collar("cigB")))

// 113 Capa Kepika: a bundle of dark quills sweeping down the back
model("cape_kepika", { pivot: "origin" }, back(8,
  ...cape({ len: 0.5, w1: 0.4, mat: "quillK", hem: (u) => Math.abs(u) * 0.1 }),
  ...range(4, (row) => range(5, (k) => on(-0.4 + k * 0.2 + (row % 2) * 0.1, -0.05 - row * 0.12,
    cone(0.018, 0.22, { mat: (row + k) % 2 ? "quillL" : "quillK", rot: [-160, 0, (k - 2) * 8], sides: 3 }), { len: 0.5, w1: 0.4, lift: 0.015 }))).flat(),
  collar("quillK")))

// 123 La capa de Krono: a long grey-teal cape, ragged hem, an arrow down the back
const W123 = { len: 0.64 }
model("cape_krono", { pivot: "origin" }, back(7,
  ...cape({ ...W123, mat: (i) => i % 2 ? "kronoD" : "krono", hem: (u) => [0, 0.06, 0.02, 0.08, 0, 0.05, 0.03][Math.min(6, Math.floor((u + 0.5) * 7))], steps: 4 }),
  on(0, -0.48, box(0.02, 0.36, 0.004, { mat: "kronoL" }), W123),
  on(0, -0.5, cone(0.05, 0.08, { mat: "kronoL", rot: [180, 0, 0], sides: 3, scale: [1, 1, 0.1] }), W123),
  collar("kronoD")))

// 130 Capa Sedforme: a cream cape ending in a fringe
model("cape_sedforme", { pivot: "origin" }, back(7,
  ...cape({ len: 0.5, mat: (i) => i % 2 ? "sedD" : "sed" }),
  ...range(10, (k) => on(-0.45 + k * 0.1, -0.53, box(0.03, 0.07, 0.006, { mat: k % 2 ? "sedD" : "sed" }), { len: 0.5 })),
  collar("sedD")))

// 141 Capa Rompedora: a mustard cape, stitched seams, a patch and a leaf
model("cape_rompedor", { pivot: "origin" }, back(7,
  ...cape({ mat: "romp", hem: (u) => 0.08 * (u + 0.5) }),
  ...[[-0.15, -0.25, 25], [0.1, -0.42, -15]].map(([u, y, a]) => on(u, y, range(5, (k) => box(0.035, 0.008, 0.004, { mat: "rompD", pos: [(k - 2) * 0.03, (k - 2) * 0.03 * Math.tan(a * Math.PI / 180), 0], rot: [0, 0, 90 + a] })))),
  on(0.2, -0.2, box(0.07, 0.06, 0.004, { mat: "patch", rot: [0, 0, 10] })),
  on(-0.25, -0.48, box(0.06, 0.03, 0.004, { mat: "leafR", rot: [0, 0, -30] })),
  collar("rompD")))

// 185 / 192 Campeón and Campierrele: a dark cape under a mane of leaves,
// tassels along the hem
const mane = (a, b, tass) => back(7,
  ...cape({ len: 0.56, mat: (i) => i % 2 ? "champL" : "champK", hem: zig(5, 0.07), steps: 10 }),
  ...range(7, (k) => on(-0.45 + k * 0.15, -0.55 + zig(5, 0.07)(-0.45 + k * 0.15), cyl(0.012, 0.09, { mat: k % 2 ? tass : "tassK", pos: [0, -0.09, 0], sides: 4 }), { len: 0.56 })),
  ...range(9, (k) => cone(0.05, 0.16, { mat: k % 2 ? a : b, pos: [-0.16 + k * 0.04, 0.0, -0.04 - (k % 3) * 0.02], rot: [-120 + (k % 3) * 15, 0, (k - 4) * 14], sides: 3 })))
model("cape_champion", { pivot: "origin" }, mane("leafO", "leafY", "leafY"))
model("cape_campierrele", { pivot: "origin" }, mane("campR", "leafO", "tassO"))

// 222 Capa de Alu-Card: a black cape cut into long points, purple inside
model("cape_alucard", { pivot: "origin" }, back(8,
  ...cape({ len: 0.66, w1: 0.5, n: 6, mat: (i) => i % 2 ? "aluP" : "alu", hem: zig(3, 0.22), steps: 9 }),
  collar("alu", 0.34)))

// 503 Capa Gosbaster: long cyan strands, a white crest at the top
model("cape_gosbaster", { pivot: "origin" }, back(6,
  ...cape({ len: 0.5, w1: 0.38, mat: "gosD" }),
  ...range(3, (row) => range(6, (k) => on(-0.42 + k * 0.17, -0.08 - row * 0.15,
    cone(0.03, 0.3 - row * 0.05, { mat: (k + row) % 2 ? "gos" : "gosD", rot: [-172, 0, (k - 2.5) * 4], sides: 3, scale: [1, 1, 0.4] }), { len: 0.5, w1: 0.38, lift: 0.01 + row * 0.006 }))).flat(),
  ...range(5, (k) => cone(0.025, 0.12, { mat: "gosW", pos: [-0.1 + k * 0.05, 0.02, -0.03], rot: [-30, 0, (k - 2) * 20], sides: 3 }))))

// 546 Capa del pío rojo: red feathers, a spiky collar
model("cape_redbird", { pivot: "origin" }, back(7,
  ...cape({ mat: (i) => i % 2 ? "birdD" : "bird", hem: zig(6, 0.1), steps: 12 }),
  ...range(3, (row) => range(5, (k) => on(-0.4 + k * 0.2 + (row % 2) * 0.1, -0.12 - row * 0.15,
    cone(0.04, 0.12, { mat: (row + k) % 2 ? "birdD" : "bird", rot: [180, 0, 0], sides: 3, scale: [1, 1, 0.2] })))).flat(),
  ...range(5, (k) => cone(0.022, 0.1, { mat: "birdD", pos: [-0.1 + k * 0.05, 0.01, -0.02], rot: [-15, 0, (k - 2) * 18], sides: 3 }))))

// 906 Cobija Nubosa: a cloud draped over the back
model("cape_cloud", { pivot: "origin" }, back(4,
  ...range(8, (k) => sphere(0.09 + (k % 3) * 0.02, { mat: k % 3 ? "cloud" : "cloudD", detail: 1,
    pos: [[-0.1, 0.1, 0, -0.12, 0.12, -0.04, 0.06, 0][k], [-0.04, -0.06, -0.16, -0.24, -0.26, -0.36, -0.38, -0.48][k], -0.1 - (k % 2) * 0.03] }))))

// 913 Capa de Zar: a wide pale cape with long stripes and a star clasp
model("cape_zar", { pivot: "origin" }, back(7,
  ...cape({ w1: 0.54, n: 7, mat: (i) => i % 2 ? "zarD" : "zar", hem: (u) => 0.05 * Math.cos(u * Math.PI) }),
  ...range(4, (k) => cone(0.02, 0.05, { mat: "zarS", pos: [0, 0.0, -0.045], rot: [90, 0, k * 90], sides: 3 })),
  sphere(0.025, { mat: "zarS", pos: [0, 0, -0.04], detail: 0 }),
  collar("zarD")))
}
