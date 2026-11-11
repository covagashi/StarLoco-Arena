// S35c: the 23 fighter weapons (fightercards type 1). Own designs; the retail
// illustrations (capturas/s35/flow/accesorios) only gave the idea.
// Convention (Fighter3D._grip): pivot "origin", the middle of the grip at the
// origin, the weapon along +Y (blade, head or top up), flat side facing +Z.
// The name's prefix is the family: sword_, dagger_ (a pair, one per hand),
// bow_ (left hand, upright; the belly bulges +Z), staff_ (upright),
// hammer_, axe_. A fighter is 1.45 m: swords ~0.65, daggers ~0.32, bows
// ~0.85, staffs ~1.0, hammers and axes ~0.75.
pal({
  blade: { color: "#dfe6ee", metal: 0.5, rough: 0.3 }, bladeD: "#9aa6b4",
  blue: "#3b74c9", blueL: "#7fb4ee", navy: "#26346e",
  wood: "#8a5a36", woodD: "#5e3b22", wrap: "#c9b07a", leafG: "#8cbf4a", leafD: "#5a8a30",
  bone: "#e8ddc0", boneD: "#b9a982", dark: "#2a2630", darkL: "#4a4554",
  fire: { color: "#f08a24", emit: "#ff8a20", glow: 1.2 }, fireR: { color: "#d8401c", emit: "#e04a18", glow: 0.8 },
  crystal: { color: "#9fd8e8", rough: 0.15, metal: 0.1 }, violet: "#5a3aa8", magic: { color: "#8fd0ff", emit: "#7fc8ff", glow: 1.5 },
  orange: "#d98a2a", stripe: "#4a2b1e", ivory: "#efe6d2",
  gold: { color: "#e8b440", metal: 0.4, rough: 0.35 }, glowY: { color: "#ffd860", emit: "#ffc840", glow: 2 },
  pink: "#e28ab8", pinkD: "#b85e90", eye: "#3aa0d8", fruit: "#f0a040",
  stone: "#bdb7a8", stoneD: "#8f897c", iron: { color: "#5a5f6a", metal: 0.4, rough: 0.5 },
  teal: "#2f6e6a", tealL: "#5aa8a0", red: "#d23a2c", redD: "#9e2a20",
})

const grip = (len, r, mat) => cyl(r, len, { mat, pos: [0, -len / 2, 0], sides: 6 })

// 1 Raciela: a broad sword, blue fuller and guard
model("sword_raciela", { pivot: "origin" },
  grip(0.12, 0.018, "navy"),
  sphere(0.026, { mat: "gold", pos: [0, -0.07, 0], detail: 0 }),
  box(0.17, 0.03, 0.045, { mat: "blue", pos: [0, 0.06, 0] }),
  extrude([-0.045, 0, 0.045, 0, 0.04, 0.44, 0, 0.53, -0.04, 0.44], 0.016, { mat: "blade", pos: [0, 0.09, -0.008] }),
  box(0.022, 0.36, 0.02, { mat: "blueL", pos: [0, 0.1, 0] }))

// 2 Kwakhoja: a curved saber with a leafy guard
model("sword_kwakhoja", { pivot: "origin" },
  grip(0.12, 0.016, "wood"),
  ...[0, 1, 2, 3, 4].map((i) => box(0.05, 0.012, 0.025, { mat: i % 2 ? "leafD" : "leafG", pos: [0, 0.06, 0], rot: [0, 0, -60 + i * 30] })),
  extrude([-0.02, 0, 0.025, 0, 0.06, 0.22, 0.085, 0.42, 0.07, 0.56, 0.045, 0.42, 0.015, 0.22], 0.012, { mat: "blade", pos: [0, 0.07, -0.006] }))

// 11 Llyoda Da: a cleaver with an eye on the spine and a feather
model("sword_llyoda", { pivot: "origin" },
  grip(0.13, 0.017, "wrap"),
  extrude([-0.03, 0, 0.03, 0, 0.09, 0.3, 0.05, 0.46, -0.05, 0.4, -0.04, 0.2], 0.018, { mat: "blade", pos: [0, 0.06, -0.009] }),
  cyl(0.03, 0.03, { mat: "boneD", pos: [-0.035, 0.15, -0.015], rot: [90, 0, 0], sides: 8 }),
  sphere(0.014, { mat: "dark", pos: [-0.035, 0.15, 0.02], detail: 0 }),
  cone(0.02, 0.14, { mat: "dark", pos: [0, -0.07, 0], rot: [180, 0, 15], sides: 4 }))

// 12 Jaley: a flame blade
model("sword_jaley", { pivot: "origin" },
  grip(0.12, 0.016, "dark"),
  box(0.12, 0.03, 0.04, { mat: "darkL", pos: [0, 0.06, 0] }),
  extrude([-0.035, 0, 0.035, 0, 0.06, 0.12, 0.03, 0.2, 0.07, 0.3, 0.025, 0.36, 0.04, 0.5, -0.01, 0.4, -0.05, 0.28, -0.02, 0.18, -0.05, 0.1], 0.016, { mat: "fire", pos: [0, 0.08, -0.008] }),
  extrude([-0.015, 0, 0.015, 0, 0.02, 0.2, 0, 0.3, -0.02, 0.2], 0.02, { mat: "fireR", pos: [0, 0.09, -0.01] }))

// 15 Bashers: a pair of blue crystal daggers
model("dagger_bashers", { pivot: "origin" },
  grip(0.1, 0.014, "navy"),
  box(0.09, 0.022, 0.03, { mat: "darkL", pos: [0, 0.05, 0] }),
  extrude([-0.025, 0, 0.025, 0, 0.012, 0.2, 0, 0.26, -0.012, 0.2], 0.014, { mat: "blue", pos: [0, 0.06, -0.007] }),
  sphere(0.016, { mat: "magic", pos: [0, 0.06, 0.012], detail: 0 }))

// 21 Taimadagas: a pair of black segmented daggers
model("dagger_taima", { pivot: "origin" },
  grip(0.1, 0.014, "darkL"),
  ...[0, 1, 2, 3].map((i) => cyl(0.018 - i * 0.003, 0.055, { mat: i % 2 ? "darkL" : "dark", pos: [0, 0.05 + i * 0.055, 0], sides: 5, top: 0.016 - i * 0.003 })),
  cone(0.01, 0.05, { mat: "blade", pos: [0, 0.27, 0], sides: 4 }))

// 22 Ajadoras: a pair of pale crystal daggers
model("dagger_ajadoras", { pivot: "origin" },
  grip(0.1, 0.015, "wrap"),
  cyl(0.026, 0.03, { mat: "crystal", pos: [0, 0.04, 0], sides: 6 }),
  ...[[0, 0.26, 0], [-0.025, 0.17, -14], [0.025, 0.17, 14]].map(([x, h, r]) =>
    cone(0.022, h, { mat: "crystal", pos: [x, 0.06, 0], rot: [0, 0, r], sides: 4 })))

// 23 Olynaa: a pair of silver daggers with spikes at the guard
model("dagger_olynaa", { pivot: "origin" },
  grip(0.1, 0.014, "tealL"),
  extrude([-0.022, 0, 0.022, 0, 0.01, 0.22, 0, 0.28, -0.01, 0.22], 0.012, { mat: "blade", pos: [0, 0.06, -0.006] }),
  ...[-60, -25, 25, 60].map((r) => cone(0.008, 0.05, { mat: "bladeD", pos: [0, 0.055, 0], rot: [0, 0, r], sides: 4 })))

// a bow along +Y: limbs curving back (-Z) from a grip, the belly +Z
const bow = (h, bend, r, mat, extra = []) => [
  tube([0, 0, 0, 0, h * 0.25, -bend * 0.4, 0, h * 0.42, -bend, 0, h * 0.5, -bend * 1.2], r, { mat, sides: 5 }),
  tube([0, 0, 0, 0, -h * 0.25, -bend * 0.4, 0, -h * 0.42, -bend, 0, -h * 0.5, -bend * 1.2], r, { mat, sides: 5 }),
  tube([0, h * 0.5, -bend * 1.2, 0, -h * 0.5, -bend * 1.2], 0.003, { mat: "ivory", sides: 3 }),
  ...extra]

// 28 La Cuerda: an orange bow with a striped grip
model("bow_cuerda", { pivot: "origin" },
  ...bow(0.85, 0.12, 0.016, "orange", [0, 1, 2].map((i) => cyl(0.02, 0.018, { mat: "stripe", pos: [0, -0.05 + i * 0.035, 0], sides: 6 }))))

// 29 Arco Desade: a black bow with thorns
model("bow_desade", { pivot: "origin" },
  ...bow(0.9, 0.14, 0.018, "dark", [[0.2, -1], [-0.2, 1], [0.33, -1], [-0.33, 1]].map(([y, s]) =>
    cone(0.012, 0.07, { mat: "darkL", pos: [0, y, -0.06 + Math.abs(y) * -0.1], rot: [s * 60, 0, 0], sides: 4 }))))

// 34 Cotazo: a bone-white bow, blade tips
model("bow_cotazo", { pivot: "origin" },
  ...bow(0.85, 0.1, 0.017, "bone", [cone(0.02, 0.07, { mat: "blade", pos: [0, 0.43, -0.12], sides: 4 }),
    cone(0.02, 0.07, { mat: "blade", pos: [0, -0.43, -0.12], rot: [180, 0, 0], sides: 4 }), cyl(0.022, 0.08, { mat: "redD", pos: [0, -0.04, 0], sides: 6 })]))

// 37 Arco Ángel: a beaded cream bow
model("bow_angel", { pivot: "origin" },
  ...bow(0.88, 0.12, 0.012, "ivory", Array.from({ length: 10 }, (_, i) => {
    const t = (i < 5 ? i + 1 : -(i - 4)) / 6, y = t * 0.44, z = -0.12 * Math.pow(Math.abs(t) / 0.83, 2) * 1.0
    return sphere(0.028, { mat: i % 2 ? "ivory" : "wrap", pos: [0, y, z], detail: 0 })
  })))

// 40 Celestina: a twisted wooden staff with a glowing hook
model("staff_celestina", { pivot: "origin" },
  tube([0, -0.4, 0, 0.02, -0.15, 0.01, -0.015, 0.1, -0.01, 0.02, 0.35, 0.01, 0.0, 0.52, 0], 0.022, { mat: "wood", sides: 6 }),
  tube([0.0, 0.52, 0, 0.05, 0.6, 0, 0.09, 0.56, 0, 0.08, 0.5, 0], 0.016, { mat: "woodD", sides: 6 }),
  sphere(0.04, { mat: "glowY", pos: [0.05, 0.55, 0.0], detail: 1 }))

// 43 Varita de Líder: a pink double-axe wand with an eye gem
model("staff_leader", { pivot: "origin" },
  cyl(0.014, 0.75, { mat: "dark", pos: [0, -0.3, 0], sides: 6 }),
  sym("x", extrude([0.02, 0.38, 0.14, 0.32, 0.17, 0.42, 0.14, 0.52, 0.02, 0.46], 0.03, { mat: "pink", pos: [0, 0, -0.015] })),
  sphere(0.035, { mat: "eye", pos: [0, 0.42, 0], detail: 1 }),
  cone(0.025, 0.06, { mat: "pinkD", pos: [0, 0.46, 0], sides: 5 }))

// 49 Pataflón: a stick with an orange fruit and leaves
model("staff_pataflon", { pivot: "origin" },
  tube([0, -0.42, 0, 0.01, 0, 0.005, 0, 0.45, 0], 0.02, { mat: "wood", sides: 6 }),
  tube([0, 0.3, 0, 0.07, 0.38, 0.01], 0.008, { mat: "woodD", sides: 4 }),
  sphere(0.06, { mat: "fruit", pos: [0.08, 0.33, 0.02], detail: 1 }),
  ...[[0.05, 0.42, 30], [-0.05, 0.36, -40], [0.03, 0.48, 70]].map(([x, y, r]) =>
    box(0.06, 0.008, 0.03, { mat: r > 0 ? "leafG" : "leafD", pos: [x, y, 0], rot: [0, 0, r] })))

// a hafted head: a handle along Y, the head at its top
const haft = (len, r, mat) => cyl(r, len, { mat, pos: [0, -0.2, 0], sides: 6 })

// 65 Cerbero: a stone hammer with a carved face
model("hammer_cerbero", { pivot: "origin" },
  haft(0.64, 0.016, "woodD"),
  box(0.2, 0.15, 0.13, { mat: "stone", pos: [0, 0.42, 0] }),
  box(0.07, 0.05, 0.14, { mat: "stoneD", pos: [-0.06, 0.48, 0.005] }),
  sym("x", box(0.035, 0.025, 0.01, { mat: "dark", pos: [0.04, 0.51, 0.066] })),
  box(0.1, 0.02, 0.01, { mat: "dark", pos: [0, 0.45, 0.066] }))

// 69 Falistos: a black block hammer, bone spikes, a screw handle
model("hammer_falistos", { pivot: "origin" },
  haft(0.62, 0.016, "bone"),
  ...[0, 1, 2, 3, 4].map((i) => torus(0.02, 0.006, { mat: "boneD", pos: [0, -0.05 - i * 0.04, 0], sides: 4, rings: 8 })),
  box(0.24, 0.14, 0.1, { mat: "dark", pos: [0, 0.4, 0] }),
  box(0.25, 0.02, 0.11, { mat: "gold", pos: [0, 0.4, 0] }),
  sym("x", cone(0.03, 0.08, { mat: "bone", pos: [0.12, 0.47, 0], rot: [0, 0, -90], sides: 4 })))

// 70 Parteghuls: a stone hammer with hooks and a wrapped handle
model("hammer_parteghuls", { pivot: "origin" },
  haft(0.62, 0.018, "stoneD"),
  ...[0, 1, 2].map((i) => cyl(0.024, 0.03, { mat: "ivory", pos: [0, -0.06 + i * 0.045, 0], sides: 6 })),
  box(0.22, 0.12, 0.11, { mat: "stone", pos: [0, 0.4, 0] }),
  sym("x", box(0.03, 0.09, 0.05, { mat: "stoneD", pos: [0.1, 0.51, 0] })),
  box(0.06, 0.03, 0.01, { mat: "blueL", pos: [0, 0.46, 0.056] }))

// 73 Xelorillo: a hammer with a horned bone head
model("hammer_xelorillo", { pivot: "origin" },
  haft(0.62, 0.014, "darkL"),
  sphere(0.02, { mat: "darkL", pos: [0, -0.2, 0], detail: 0 }),
  box(0.18, 0.13, 0.12, { mat: "bone", pos: [0, 0.4, 0] }),
  cyl(0.05, 0.03, { mat: "boneD", pos: [-0.1, 0.465, 0], rot: [0, 0, 90], sides: 8 }),
  tube([0.07, 0.52, 0, 0.11, 0.58, 0.0, 0.15, 0.6, 0], 0.016, { mat: "boneD", sides: 5 }))

// 79 Pala Enredaderada: a shovel with a vine round the handle
model("axe_shovel", { pivot: "origin" },
  haft(0.64, 0.016, "woodD"),
  tube(Array.from({ length: 13 }, (_, i) => [Math.cos(i * 1.6) * 0.022, -0.3 + i * 0.055, Math.sin(i * 1.6) * 0.022]).flat(), 0.009, { mat: "leafG", sides: 4 }),
  extrude([-0.08, 0.0, 0.08, 0.0, 0.07, 0.12, 0, 0.2, -0.07, 0.12], 0.012, { mat: "blade", pos: [0, 0.52, -0.006], rot: [0, 0, 180] }),
  box(0.04, 0.05, 0.03, { mat: "bladeD", pos: [0, 0.48, 0] }))

// 82 Enterradora Infiel: a teal glyph blade on a pole
model("axe_enterradora", { pivot: "origin" },
  haft(0.64, 0.015, "bladeD"),
  ...[0, 1].map((i) => cyl(0.02, 0.015, { mat: "gold", pos: [0, 0.3 + i * 0.03, 0], sides: 6 })),
  extrude([-0.12, 0.0, -0.04, 0.03, 0, 0.0, 0.04, 0.03, 0.12, 0.0, 0.1, 0.09, 0.04, 0.07, 0, 0.12, -0.04, 0.07, -0.1, 0.09], 0.02, { mat: "teal", pos: [0, 0.4, -0.01] }),
  box(0.2, 0.015, 0.024, { mat: "tealL", pos: [0, 0.43, 0] }))

// 84 Luna Roja: a dark blade with red ribbons on a long pole
model("axe_lunaroja", { pivot: "origin" },
  haft(0.66, 0.012, "dark"),
  extrude([0, 0.0, 0.14, 0.06, 0.2, 0.16, 0.1, 0.12, 0.02, 0.14], 0.012, { mat: "darkL", pos: [0, 0.38, -0.006] }),
  ...[[-20, 0.17], [10, 0.2], [40, 0.15], [-50, 0.13]].map(([r, l], i) =>
    box(0.035, l, 0.006, { mat: i % 2 ? "redD" : "red", pos: [0.0, 0.42, 0.012], rot: [0, 0, 180 + r] })))

// 85 Solitaria: a double-bladed axe, silver and green
model("axe_solitaria", { pivot: "origin" },
  haft(0.64, 0.015, "teal"),
  ...[0, 1, 2].map((i) => cyl(0.019, 0.012, { mat: "gold", pos: [0, -0.05 + i * 0.12, 0], sides: 6 })),
  sym("x", extrude([0.02, 0.33, 0.14, 0.27, 0.17, 0.4, 0.14, 0.53, 0.02, 0.47], 0.016, { mat: "blade", pos: [0, 0, -0.008] })),
  sym("x", extrude([0.03, 0.36, 0.11, 0.33, 0.12, 0.4, 0.11, 0.47, 0.03, 0.44], 0.02, { mat: "teal", pos: [0, 0, -0.01] })),
  cone(0.022, 0.08, { mat: "blade", pos: [0, 0.5, 0], sides: 4 }))
