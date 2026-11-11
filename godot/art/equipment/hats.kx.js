// S35c: the 16 fighter hats (fightercards type 4). Own designs; the retail
// illustrations (capturas/s35/flow/accesorios) only gave the idea.
// Convention (Fighter3D.hang): pivot "origin", y = 0 is where the hat sits
// on the head, the head is ~0.27 m wide there (HAT_CROWN) and its top rises
// ~0.12 m above: a hat's crown clears that; a helmet or mask hangs below 0.
pal({
  bone: "#e8ddc0", boneD: "#b9a982", dark: "#2b2422",
  cream: "#efe2b0", leafG: "#4f8a3a", leafD: "#35632a",
  orange: "#e39a2c", orangeD: "#b06a1c", stitch: "#4a2b1e",
  shell: "#f4efe6", shellD: "#cfc4b2",
  tan: "#d8b46a", tanD: "#a98444",
  cowboy: "#d6b06a", cowboyD: "#9e7a40", buckle: { color: "#e8b440", metal: 0.4, rough: 0.35 },
  olive: "#8f8a2e", oliveD: "#6a6622", spot: "#e8c23a", stalk: "#7a5a3a",
  helm: { color: "#b8c2cc", metal: 0.45, rough: 0.35 }, helmD: "#7c8794", feather: "#2e3340",
  beak: "#d9542a", beakD: "#a83a1c", mane: "#d9bf72", maneD: "#a88d48", eyeY: "#f1d34a",
  wool: "#f3ead6", woolD: "#d8ccb0", horn: "#4f6fa8", hornD: "#38507e", pink: "#e98a9a",
  red: "#d23a2c", redD: "#9e2a20", white: "#f6f1e6",
  hood: "#41558c", hoodD: "#2e3d68", goggle: { color: "#e8b440", metal: 0.5, rough: 0.3 }, glass: "#f0c040",
  fur: "#d88a2e", furD: "#a86220",
  stone: "#bdb7a8", stoneD: "#8f897c", moss: "#7fae4a",
  steel: { color: "#c9d2dc", metal: 0.5, rough: 0.35 }, spike: { color: "#f0b030", metal: 0.3, rough: 0.35 },
})

const ring = (n, f) => Array.from({ length: n }, (_, i) => f(i, (i * 360) / n))
const rad = (a) => (a * Math.PI) / 180

// 109 Kritter: a horned bone skull, eye holes over the face, fangs
model("hat_kritter", { pivot: "origin" },
  lathe([0.15, -0.06, 0.165, 0.02, 0.15, 0.09, 0.1, 0.15, 0, 0.17], { mat: "bone", sides: 9 }),
  box(0.3, 0.045, 0.06, { mat: "boneD", pos: [0, -0.03, 0.13] }),                       // brow
  sym("x", sphere(0.035, { mat: "dark", pos: [0.06, -0.05, 0.148], scale: [1, 1, 0.35], detail: 0 })),   // eye holes
  sym("x", cone(0.04, 0.17, { mat: "bone", pos: [0.13, 0.08, 0], rot: [0, 0, -55], sides: 5 })),
  sym("x", cone(0.014, 0.06, { mat: "bone", pos: [0.05, -0.08, 0.16], rot: [180, 0, 0], sides: 4 })))

// 110 Dora: a soft round cap, cream with a green rim and leaf dots
model("hat_dora", { pivot: "origin" },
  lathe([0.15, 0, 0.18, 0.025, 0.17, 0.07, 0.12, 0.13, 0, 0.15], { mat: "cream", sides: 12 }),
  torus(0.163, 0.018, { mat: "leafG", pos: [0, 0.015, 0], sides: 6, rings: 16 }),
  ring(5, (i, a) => box(0.035, 0.012, 0.02, { mat: "leafD", pos: [Math.sin(rad(a)) * 0.1, 0.13, Math.cos(rad(a)) * 0.1], rot: [0, a + 30, 15] })))

// 111 Dantgul: an orange round cap with stitched crosses
model("hat_dantgul", { pivot: "origin" },
  lathe([0.16, -0.01, 0.17, 0.04, 0.15, 0.1, 0.09, 0.15, 0, 0.165], { mat: "orange", sides: 10, jitter: 0.004 }),
  torus(0.165, 0.014, { mat: "orangeD", pos: [0, 0.0, 0], sides: 6, rings: 16 }),
  ...[[0.07, 0.13, 0.08, 30], [-0.08, 0.11, -0.05, -40]].map(([x, y, z, r]) =>
    tf({ pos: [x, y, z], rot: [0, r, 0] },
      box(0.07, 0.012, 0.012, { mat: "stitch", rot: [0, 45, 0] }), box(0.07, 0.012, 0.012, { mat: "stitch", rot: [0, -45, 0] }))))

// 112 Dragosombrero: a dragon's egg shell, cracked rim
model("hat_dragoshell", { pivot: "origin" },
  lathe([0.16, -0.02, 0.172, 0.05, 0.15, 0.13, 0.09, 0.19, 0, 0.215], { mat: "shell", sides: 10 }),
  ring(12, (i, a) => cone(0.032, 0.025 + (i % 3) * 0.012, { mat: "shellD", pos: [Math.sin(rad(a)) * 0.158, -0.015, Math.cos(rad(a)) * 0.158], rot: [180, 0, 0], sides: 3 })),
  sphere(0.03, { mat: "white", pos: [0.06, 0.17, 0.08], detail: 0 }))

// 113 Champo: a wide flat mushroom cap with darker spots
model("hat_champo", { pivot: "origin" },
  lathe([0.08, 0, 0.27, 0.03, 0.25, 0.07, 0.16, 0.12, 0, 0.14], { mat: "tan", sides: 12, jitter: 0.006 }),
  cyl(0.14, 0.03, { mat: "tanD", sides: 10 }),
  ring(6, (i, a) => sphere(0.035, { mat: "tanD", pos: [Math.sin(rad(a)) * (0.08 + (i % 2) * 0.08), 0.12 - (i % 2) * 0.03, Math.cos(rad(a)) * (0.08 + (i % 2) * 0.08)], scale: [1, 0.35, 1], detail: 0 })))

// 114 Clint: a cowboy hat, brim curled up at the sides, a band and buckle
model("hat_clint", { pivot: "origin" },
  tf({ scale: [1.05, 1, 0.82] },
    lathe([0.13, 0, 0.2, 0.004, 0.245, 0.03, 0.255, 0.06, 0.24, 0.065, 0.225, 0.03, 0.13, 0.02], { mat: "cowboy", sides: 12 })),
  lathe([0.14, 0, 0.14, 0.08, 0.12, 0.15, 0.05, 0.155, 0, 0.13], { mat: "cowboy", sides: 8 }),
  cyl(0.143, 0.03, { mat: "cowboyD", sides: 8, pos: [0, 0.015, 0] }),
  box(0.05, 0.035, 0.02, { mat: "buckle", pos: [0, 0.013, 0.14] }))

// 115 Caparasombrero: a flat turtle shell with spots and a stalk on top
model("hat_carapace", { pivot: "origin" },
  lathe([0.15, -0.01, 0.25, 0.02, 0.22, 0.07, 0.13, 0.12, 0, 0.14], { mat: "olive", sides: 7 }),
  torus(0.24, 0.016, { mat: "oliveD", pos: [0, 0.015, 0], sides: 5, rings: 14 }),
  ring(5, (i, a) => sphere(0.03, { mat: "spot", pos: [Math.sin(rad(a)) * 0.14, 0.09, Math.cos(rad(a)) * 0.14], scale: [1, 0.3, 1], detail: 0 })),
  cyl(0.012, 0.07, { mat: "stalk", pos: [0, 0.13, 0], rot: [0, 0, 12], sides: 5 }))

// 116 Cuerbosombrero: a steel helm with a crow's beak visor and a feather crest
model("hat_crowhelm", { pivot: "origin" },
  lathe([0.155, -0.07, 0.165, 0.0, 0.15, 0.09, 0.09, 0.15, 0, 0.165], { mat: "helm", sides: 10 }),
  cone(0.05, 0.13, { mat: "helmD", pos: [0, -0.02, 0.14], rot: [80, 0, 0], sides: 4 }),
  ring(4, (i, a) => cone(0.022, 0.16 - i * 0.02, { mat: "feather", pos: [0, 0.15, 0.05 - i * 0.05], rot: [-25 - i * 15, 0, 0], sides: 3 })))

// 117 Melenuda: a bird head with a red beak and a straw mane down the back
model("hat_maned", { pivot: "origin" },
  lathe([0.15, -0.03, 0.165, 0.03, 0.14, 0.11, 0, 0.15], { mat: "maneD", sides: 9 }),
  cone(0.06, 0.15, { mat: "beak", pos: [0, 0.03, 0.14], rot: [75, 0, 0], sides: 5 }),
  sym("x", sphere(0.03, { mat: "eyeY", pos: [0.08, 0.07, 0.12], detail: 0 })),
  ring(9, (i, a) => cone(0.04, 0.2, { mat: i % 2 ? "mane" : "maneD", pos: [Math.sin(rad(a / 2.2 + 105)) * 0.14, 0.09 - (i % 3) * 0.03, Math.cos(rad(a / 2.2 + 105)) * 0.14], rot: [-140 + (i % 3) * 10, a / 2.2 + 105, 0], sides: 4 })))

// 125 Jalató: a woolly sheep cap with curled blue horns and pink ears
model("hat_jalato", { pivot: "origin" },
  lathe([0.155, -0.02, 0.17, 0.05, 0.13, 0.13, 0, 0.16], { mat: "woolD", sides: 9 }),
  ring(8, (i, a) => sphere(0.06, { mat: "wool", pos: [Math.sin(rad(a)) * 0.12, 0.07 + (i % 2) * 0.03, Math.cos(rad(a)) * 0.12], detail: 0 })),
  sphere(0.07, { mat: "wool", pos: [0, 0.14, 0], detail: 0 }),
  sym("x", tube([0.15, 0.05, 0, 0.22, 0.09, -0.02, 0.25, 0.03, 0.02, 0.22, -0.02, 0.05], 0.025, { mat: "horn", sides: 6 })),
  sym("x", sphere(0.03, { mat: "pink", pos: [0.17, -0.01, 0.06], scale: [1.3, 0.6, 0.8], detail: 0 })))

// 126 Champisombrero: a red mushroom dome, white spots, bone horns
model("hat_shroom", { pivot: "origin" },
  lathe([0.12, 0, 0.23, 0.02, 0.21, 0.08, 0.13, 0.15, 0, 0.17], { mat: "red", sides: 12 }),
  torus(0.22, 0.012, { mat: "redD", pos: [0, 0.01, 0], sides: 5, rings: 16 }),
  ring(7, (i, a) => sphere(0.026, { mat: "white", pos: [Math.sin(rad(a)) * (0.1 + (i % 2) * 0.06), 0.15 - (i % 2) * 0.04, Math.cos(rad(a)) * (0.1 + (i % 2) * 0.06)], scale: [1, 0.4, 1], detail: 0 })),
  ring(4, (i, a) => cone(0.025, 0.09, { mat: "bone", pos: [Math.sin(rad(a + 45)) * 0.08, 0.13, Math.cos(rad(a + 45)) * 0.08], rot: [Math.cos(rad(a + 45)) * 30, 0, -Math.sin(rad(a + 45)) * 30], sides: 5 })))

// 128 Moskitogarruleto: a blue hood with golden goggles and a proboscis
model("hat_mosquito", { pivot: "origin" },
  lathe([0.15, -0.09, 0.17, 0.0, 0.15, 0.1, 0.08, 0.16, 0, 0.17], { mat: "hood", sides: 10 }),
  box(0.3, 0.04, 0.05, { mat: "hoodD", pos: [0, 0.0, 0.13] }),
  sym("x", tf({ pos: [0.06, 0.04, 0.15] }, cyl(0.05, 0.03, { mat: "goggle", rot: [90, 0, 0], sides: 8 }), cyl(0.038, 0.034, { mat: "glass", rot: [90, 0, 0], sides: 8 }))),
  cone(0.012, 0.1, { mat: "orange", pos: [0, -0.04, 0.16], rot: [110, 0, 0], sides: 4 }),
  sym("x", tube([0.05, 0.15, 0.02, 0.09, 0.22, 0.05, 0.13, 0.25, 0.1], 0.008, { mat: "hoodD", sides: 4 })))

// 132 Prespic: a furry orange hood with spikes and round eyes
model("hat_prespic", { pivot: "origin" },
  lathe([0.16, -0.05, 0.175, 0.02, 0.15, 0.1, 0.08, 0.16, 0, 0.17], { mat: "fur", sides: 9, jitter: 0.008 }),
  ...[0, 1].map((k) => ring(7, (i, a) => cone(0.035, 0.1, { mat: k ? "furD" : "fur",
    pos: [Math.sin(rad(a + k * 25)) * (0.12 - k * 0.05), 0.07 + k * 0.06, Math.cos(rad(a + k * 25)) * (0.12 - k * 0.05) - 0.02],
    rot: [-Math.cos(rad(a + k * 25)) * (60 - k * 25), 0, Math.sin(rad(a + k * 25)) * (60 - k * 25)], sides: 4 }))),
  sym("x", sphere(0.035, { mat: "white", pos: [0.065, 0.06, 0.145], detail: 0 })),
  sym("x", sphere(0.018, { mat: "dark", pos: [0.068, 0.06, 0.175], detail: 0 })))

// 133 El Cascruj: a helmet of stacked stones with moss
model("hat_stones", { pivot: "origin" },
  lathe([0.155, -0.02, 0.165, 0.05, 0.12, 0.13, 0, 0.15], { mat: "stoneD", sides: 8 }),
  ring(6, (i, a) => rock(0.07, { mat: "stone", pos: [Math.sin(rad(a)) * 0.13, 0.04 + (i % 2) * 0.03, Math.cos(rad(a)) * 0.13], seed: i + 1 })),
  rock(0.08, { mat: "stone", pos: [0, 0.17, 0], seed: 9, squash: 1.4 }),
  rock(0.05, { mat: "stoneD", pos: [0.02, 0.26, 0.01], seed: 4 }),
  sphere(0.03, { mat: "moss", pos: [-0.08, 0.13, 0.07], scale: [1.4, 0.5, 1], detail: 0 }))

// 157 Corona de Sidán: a steel band with golden spikes
model("hat_sidan", { pivot: "origin" },
  cyl(0.155, 0.07, { mat: "steel", sides: 12, top: 0.15 }),
  cyl(0.145, 0.072, { mat: "dark", sides: 12, pos: [0, 0.002, 0] }),
  ring(8, (i, a) => cone(0.026, 0.09, { mat: "spike", pos: [Math.sin(rad(a)) * 0.15, 0.035, Math.cos(rad(a)) * 0.15], rot: [90, a, 0], sides: 5 })))
