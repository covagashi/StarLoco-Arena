// S35c: the 15 fighter capes (fightercards type 3). Own designs; the retail
// illustrations (capturas/s35/flow/accesorios) only gave the idea.
// Convention (Fighter3D.hang): pivot "origin", the middle of the collar at
// the origin, the cape hangs down -Y and lies behind the back (-Z), ~0.34 m
// across at the shoulders (CAPE_WIDTH), ~0.6 m long; the outer side faces -Z.
// A cape is a few flat strips round a cylinder so it wraps the back, the
// hem shaped per cape, tilted back a little so the legs walk clear of it.
{ // the helpers below stay local to this include
pal({
  olive: "#6f7a3a", oliveD: "#4a5226", rope: "#a88a5a",
  navy: "#1f4f8f", navyD: "#173a6a", sky: "#7fc0e8",
  sage: "#8fb0a0", sand: "#d9b870", sandD: "#b08a48",
  cream: "#efe2c4", creamD: "#cbb890",
  white: "#f2efe8", whiteD: "#d2ccc0", orange: "#ec8a24", orangeD: "#b8621a",
  fur: "#f4ead2", furD: "#d8c8a0",
  teal: "#2f6a68", tealD: "#214c4a", patch: "#9a9a3a", patchB: "#b08a5a",
  bark: "#6a4428", barkL: "#c88a3a", barkD: "#3e2616",
  wool: "#f3ecd8", woolD: "#dcd0b4", bow: "#d23a2c", hoof: "#3d5a8a",
  leaf: "#5a9a3e", leafD: "#3c7028", leafL: "#86c25a",
  slime: "#9fd23a", slimeD: "#6ea01e", slimeL: "#d4f070",
  pack: "#e88a1c", packD: "#b86412", helm: "#41558c", helmD: "#2e3d68",
  goggle: { color: "#e8b440", metal: 0.4, rough: 0.35 }, glass: "#f0c040", tusk: "#efe6d2", strap: "#4a3020",
  stone: "#e6e2d6", stoneD: "#a8a296", moss: "#9aae4a",
  prespic: "#d88a1c", prespicD: "#9e5a12", claw: "#3a2a1c",
  plume: "#eef4fa", plumeD: "#a8c0d8",
  gold: { color: "#e8b440", metal: 0.4, rough: 0.35 },
})

const T = 0.02                    // cloth thickness
const rad = (a) => (a * Math.PI) / 180
const range = (n, f) => Array.from({ length: n }, (_, i) => f(i))

// The cape body: n strips round a cylinder of radius r (its axis in front,
// at z = r), w0 across at the top and w1 at the bottom, len long; hem(u)
// lifts the bottom edge at u (-0.5..0.5 across) and mat(i) colours strip i.
function cape({ len = 0.6, w0 = 0.34, w1 = 0.46, n = 5, r = 0.24, hem = () => 0, mat, steps = 3 }) {
  const a0 = w0 / r / n, out = []
  for (let i = 0; i < n; i++) {
    const phi = (i - (n - 1) / 2) * a0
    const t0 = w0 / n / 2, t1 = (w1 / n / 2) * 1.04
    const pts = [-t0, 0, t0, 0]
    for (let k = 0; k <= steps; k++) {
      const s = 1 - k / steps, x = -t1 + 2 * t1 * s
      const u = (i + s) / n - 0.5
      pts.push(x, -len + hem(u))
    }
    out.push(tf({ pos: [r * Math.sin(phi), 0, r - r * Math.cos(phi)], rot: [0, -phi * 180 / Math.PI, 0] },
      extrude(pts, T, { mat: typeof mat === "function" ? mat(i) : mat, pos: [0, 0, -T] })))
  }
  return out
}
// an item placed on the cape's outer side at u (-0.5..0.5 across) and y
// (0 at the collar, -len at the hem), facing out (-Z)
function on(u, y, items, { w0 = 0.34, w1 = 0.46, len = 0.6, r = 0.24, lift = 0.006 } = {}) {
  const phi = (u * w0) / r
  const k = 1 + ((w1 / w0 - 1) * -y) / len   // the strips widen downwards
  const x = r * Math.sin(phi) * k, z = r - r * Math.cos(phi)
  return tf({ pos: [x, y, z - T - lift], rot: [0, -phi * 180 / Math.PI, 0] }, items)
}
const back = (tilt, ...items) => tf({ rot: [tilt, 0, 0] }, ...items)
const collar = (mat, w = 0.3) => box(w, 0.035, 0.05, { mat, pos: [0, -0.02, -0.01] })

// 96 N'terarroza: a ragged olive cape, torn hem, dark holes, a rope collar
const rag = (u) => [0.0, 0.08, 0.02, 0.12, 0.0, 0.06, 0.15, 0.01, 0.09, 0.0, 0.11][Math.min(10, Math.floor((u + 0.5) * 11))]
model("cape_nterarroza", { pivot: "origin" }, back(8,
  ...cape({ mat: (i) => i % 2 ? "oliveD" : "olive", hem: rag, steps: 6 }),
  on(-0.15, -0.3, box(0.05, 0.07, 0.004, { mat: "oliveD", rot: [0, 0, 20] })),
  on(0.2, -0.42, box(0.04, 0.05, 0.004, { mat: "oliveD", rot: [0, 0, -15] })),
  tube([-0.15, -0.02, -0.02, 0, -0.04, -0.035, 0.15, -0.02, -0.02], 0.012, { mat: "rope", sides: 5 })))

// 97 Gallo Umbo: a long deep-blue cape, a sky-blue border, a gold clasp
const W97 = { len: 0.66, w1: 0.44 }
model("cape_umbo", { pivot: "origin" }, back(6,
  ...cape({ ...W97, mat: "navy", hem: (u) => Math.abs(u) * 0.06 }),
  ...[-0.46, 0.46].map((u) => range(6, (k) => on(u, -0.08 - k * 0.1, box(0.025, 0.05, 0.004, { mat: "sky", rot: [0, 0, k % 2 ? 30 : -30] }), W97))).flat(),
  ...range(5, (k) => on(-0.4 + k * 0.2, -0.6, box(0.05, 0.022, 0.004, { mat: "sky" }), W97)),
  collar("navyD"), sphere(0.03, { mat: "gold", pos: [0, -0.02, -0.04], scale: [1, 1, 0.5], detail: 0 })))

// 98 Taz: tall stripes of sage and sand, cut to a point
model("cape_taz", { pivot: "origin" }, back(7,
  ...cape({ n: 6, mat: (i) => ["sage", "sand", "sandD"][i % 3], hem: (u) => Math.abs(u) * 0.22 }),
  collar("sandD")))

// 99 Tofu Loco: a cream cape that ends in a fringe of feathers
model("cape_tofu", { pivot: "origin" }, back(7,
  ...cape({ len: 0.42, mat: (i) => i % 2 ? "creamD" : "cream" }),
  ...range(9, (k) => on(-0.44 + k * 0.11, -0.4, cone(0.03, 0.16 + (k % 3) * 0.04, { mat: k % 2 ? "cream" : "creamD", sides: 3, rot: [180, 0, (k - 4) * 4], scale: [1, 1, 0.35] }), { len: 0.42 })),
  collar("creamD")))

// 102 Dofustadora: a white cape with an orange egg-dot border, gold collar
model("cape_dofustadora", { pivot: "origin" }, back(7,
  ...cape({ mat: "white", hem: (u) => 0.02 * Math.cos(u * 12) }),
  ...[-0.44, 0.44].map((u) => range(5, (k) => on(u, -0.08 - k * 0.11, box(0.035, 0.05, 0.004, { mat: k % 2 ? "orangeD" : "orange" })))).flat(),
  ...range(4, (k) => on(-0.3 + k * 0.2, -0.54, sphere(0.022, { mat: "orange", scale: [0.8, 1.1, 0.3], detail: 0 }))),
  collar("gold")))

// 103 Wey Wabbit: an orange cape all round in fluffy cream fur
const W103 = { len: 0.56, w1: 0.42 }
model("cape_weywabbit", { pivot: "origin" }, back(8,
  ...cape({ ...W103, mat: "orange", hem: (u) => 0.03 * (1 - 4 * u * u) }),
  ...[-0.5, 0.5].map((u) => range(6, (k) => on(u, -0.04 - k * 0.1, sphere(0.04, { mat: k % 2 ? "furD" : "fur", detail: 0 }), W103))).flat(),
  ...range(5, (k) => on(-0.36 + k * 0.18, -0.54 + 0.03 * (1 - 4 * (k * 0.18 - 0.36) ** 2), sphere(0.04, { mat: k % 2 ? "fur" : "furD", detail: 0 }), W103)),
  ...range(4, (k) => sphere(0.045, { mat: "fur", pos: [-0.13 + k * 0.087, -0.01, -0.02], detail: 0 }))))

// 104 La Harapa: a teal hooded rag with patches
model("cape_harapa", { pivot: "origin" }, back(8,
  ...cape({ mat: (i) => i % 2 ? "tealD" : "teal", hem: (u) => [0.0, 0.05, 0.0, 0.07, 0.02, 0.0, 0.06][Math.min(6, Math.floor((u + 0.5) * 7))], steps: 4 }),
  on(0.12, -0.35, box(0.08, 0.08, 0.004, { mat: "patch", rot: [0, 0, 8] })),
  on(-0.18, -0.48, box(0.06, 0.05, 0.004, { mat: "patchB", rot: [0, 0, -10] })),
  sphere(0.11, { mat: "teal", pos: [0, -0.06, -0.06], scale: [1.2, 0.6, 0.55], detail: 1 })))   // the hood, down

// 105 Abracapa: overlapping bark scales, dark and amber
model("cape_abra", { pivot: "origin" }, back(8,
  ...cape({ len: 0.58, w1: 0.4, mat: "barkD", hem: (u) => Math.abs(u) * 0.12 }),
  ...range(4, (row) => range(3 + (row % 2), (k) => on(-0.33 + k * 0.22 + (row % 2 ? -0.11 : 0), -0.06 - row * 0.13,
    lathe([0, -0.13, 0.05, -0.06, 0.04, 0, 0, 0.02], { mat: (row + k) % 2 ? "bark" : "barkL", sides: 4, scale: [1, 1, 0.3] }), { len: 0.58, w1: 0.4, lift: 0.01 + row * 0.004 }))).flat(),
  collar("barkD")))

// 106 Capa Jalosa: a whole fleece on the back, a red bow, little blue hooves
model("cape_jalosa", { pivot: "origin" }, back(4,
  ...range(7, (k) => sphere(0.1 - (k % 3) * 0.015, { mat: k % 2 ? "woolD" : "wool", detail: 1,
    pos: [[-0.09, 0.09, 0, -0.1, 0.1, -0.03, 0.04][k], [-0.08, -0.1, -0.2, -0.3, -0.32, -0.42, -0.42][k], -0.08 - (k % 2) * 0.02] })),
  sphere(0.07, { mat: "wool", pos: [0, 0.0, -0.05], scale: [1.8, 0.8, 1], detail: 1 }),
  ...[-1, 1].map((s) => cone(0.04, 0.07, { mat: "bow", sides: 3, pos: [s * 0.04, -0.3, -0.2], rot: [0, 0, s * 90] })),
  sphere(0.02, { mat: "bow", pos: [0, -0.3, -0.2], detail: 0 }),
  ...[-1, 1].map((s) => cyl(0.03, 0.05, { mat: "hoof", pos: [s * 0.07, -0.53, -0.08], sides: 6 }))))

// 107 Vegacapa: one big leaf, a notched edge and a pale midrib
model("cape_vega", { pivot: "origin" }, back(7,
  ...cape({ mat: (i) => i % 2 ? "leafD" : "leaf", w1: 0.4, hem: (u) => 0.32 * (2 * u) ** 2 + (Math.abs(u) > 0.3 ? 0.04 : 0), steps: 6 }),
  on(0, -0.3, box(0.016, 0.52, 0.004, { mat: "leafL", pos: [0, -0.26, 0] })),
  ...[-1, 1].map((s) => range(3, (k) => on(s * 0.1, -0.15 - k * 0.12, box(0.012, 0.12, 0.004, { mat: "leafL", rot: [0, 0, s * 50] })))).flat(),
  collar("leafD")))

// 127 Champ Champ: a slimy lime cape, drips down the hem, bubbles
model("cape_champ", { pivot: "origin" }, back(7,
  ...cape({ len: 0.5, mat: (i) => i % 2 ? "slimeD" : "slime", hem: (u) => 0.03 * Math.sin(u * 20) }),
  ...range(6, (k) => on(-0.4 + k * 0.16, -0.5, lathe([0.02, 0.02, 0.014, -0.06 - (k % 3) * 0.04, 0.02, -0.08 - (k % 3) * 0.04, 0, -0.1 - (k % 3) * 0.04], { mat: "slime", sides: 5 }), { len: 0.5 })),
  ...[[-0.2, -0.15], [0.15, -0.25], [-0.05, -0.38], [0.28, -0.1]].map(([u, y]) => on(u, y, sphere(0.022, { mat: "slimeL", detail: 0 }), { len: 0.5 })),
  collar("slimeD")))

// 129 Mochila del Pequeño Moskito: a backpack with a mosquito-helmet lid,
// goggles and tusks, on two straps
model("cape_moskito", { pivot: "origin" },
  box(0.24, 0.28, 0.14, { mat: "pack", pos: [0, -0.38, -0.1] }),
  box(0.2, 0.08, 0.02, { mat: "packD", pos: [0, -0.34, -0.18] }),
  lathe([0.13, 0, 0.13, 0.04, 0.1, 0.1, 0, 0.13], { mat: "helm", sides: 8, pos: [0, -0.12, -0.1], scale: [1, 1, 0.75] }),
  sym("x", torus(0.03, 0.008, { mat: "goggle", pos: [0.05, -0.05, -0.19], rot: [90, 0, 0], sides: 5, rings: 10 }),
    cyl(0.026, 0.01, { mat: "glass", pos: [0.05, -0.05, -0.185], rot: [90, 0, 0], sides: 8 }),
    cone(0.014, 0.06, { mat: "tusk", pos: [0.04, -0.12, -0.19], rot: [180, 0, 0], sides: 4 }),
    box(0.035, 0.36, 0.02, { mat: "strap", pos: [0.09, -0.3, -0.01] })))

// 130 Crujicapa: a cape of cracked white stone, moss in the cracks
model("cape_cruji", { pivot: "origin" }, back(7,
  ...cape({ mat: (i) => i % 2 ? "stoneD" : "stone", hem: (u) => [0, 0.04, 0.0, 0.05, 0.01, 0.0, 0.03][Math.min(6, Math.floor((u + 0.5) * 7))], steps: 4 }),
  ...[[-0.2, -0.2, 30], [0.1, -0.3, -20], [-0.05, -0.45, 70], [0.25, -0.5, 10], [0.0, -0.12, -60]].map(([u, y, a]) => on(u, y, box(0.09, 0.008, 0.004, { mat: "stoneD", rot: [0, 0, a] }))),
  ...[[-0.25, -0.35], [0.18, -0.15], [0.05, -0.52]].map(([u, y]) => on(u, y, sphere(0.02, { mat: "moss", scale: [1.2, 0.8, 0.3], detail: 0 }))),
  collar("stoneD")))

// 131 Prespic: a bristling orange fur cape, paws with claws over the shoulders
model("cape_prespic", { pivot: "origin" }, back(8,
  ...cape({ len: 0.62, mat: (i) => i % 2 ? "prespicD" : "prespic", hem: (u) => 0.03 * ((Math.floor((u + 0.5) * 12) % 2)), steps: 12 }),
  ...range(4, (row) => range(4, (k) => on(-0.36 + k * 0.24 + (row % 2) * 0.12, -0.1 - row * 0.13, cone(0.02, 0.07, { mat: "prespicD", sides: 3, rot: [-60, 0, 0] }), { len: 0.62 }))).flat(),
  ...[-1, 1].map((s) => tf({ pos: [s * 0.15, 0.0, 0.02] },
    sphere(0.045, { mat: "prespic", scale: [1, 0.7, 1.3], detail: 0 }),
    ...range(3, (k) => cone(0.008, 0.035, { mat: "claw", sides: 3, pos: [(k - 1) * 0.02, -0.01, 0.06], rot: [90, 0, 0] }))))))

// 156 Plumobardes: long pale-blue feathers that split into points
model("cape_plumo", { pivot: "origin" }, back(7,
  ...cape({ n: 6, mat: (i) => i % 2 ? "plumeD" : "plume", hem: (u) => 0.3 * Math.abs(Math.sin((u + 0.5) * Math.PI * 3)), steps: 9 }),
  ...range(5, (k) => on(-0.4 + k * 0.2, -0.2, box(0.008, 0.3, 0.004, { mat: "plumeD", pos: [0, -0.15, 0] }))),
  collar("plumeD")))
}
