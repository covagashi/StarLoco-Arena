// S35c: the 15 fighter pets (fightercards type 2). Own designs; the retail
// illustrations (capturas/s35/flow/accesorios) only gave the idea.
// Convention (Fighter3D.hang): pivot "origin", the pet stands with its feet
// at the origin facing +Z, ~0.16 m tall: it rides the fighter's left
// shoulder. Chibi: a big head, a small body, big eyes.
{ // the helpers below stay local to this include
pal({
  eyeW: "#f8f6f0", pupil: "#1e1a1a", cheek: "#ef9a8a", nose: "#2a2020",
  dog: "#4a4a50", dogD: "#2e2e34", dogL: "#7a7a82", tongue: "#e07a8a",
  cat: "#f2ece0", catD: "#3a3030", catP: "#e8b0b0",
  wabbit: "#8a5636", wabbitD: "#64391f", wabbitW: "#f4f0e8", fang: "#f8f4e8",
  beak: "#f0902a", beakD: "#c8641a", feet: "#f4e2c0",
  bwakE: "#8ac43a", bwakED: "#c8a020", bwakF: "#e2402a", bwakFD: "#f0b030",
  bwakA: "#f4f0e8", bwakAD: "#a87ac8", bwakW: "#8ab8ec", bwakWD: "#3a6ab8",
  monkey: "#a8683a", monkeyD: "#7a4826", monkeyL: "#e0b088",
  owl: "#ec7a2a", owlD: "#c4402a", owlL: "#f8c060", owlEye: "#f8d830",
  shellG: "#b0a83a", shellGD: "#80782a", ray: "#8aa098", rayD: "#6a807a", rayE: "#c8e0b8",
  ghost: "#f4e8d8", ghostD: "#dcc8b0",
  kwoko: "#8a8238", kwokoD: "#5e5822", kwokoY: "#f0b030",
  crow: "#2a2a34", crowD: "#1a1a22", crowL: "#4a4a5a", crowY: "#f0c020",
  turtle: "#a8c03a", turtleD: "#7a8a28", tshell: "#5a5030", tshellR: "#c83a2a",
  stump: "#a8703a", stumpD: "#6e4426", stumpL: "#d8a060", ring: "#e8c890",
})

const range = (n, f) => Array.from({ length: n }, (_, i) => f(i))
// a pair of big eyes on a face looking +Z: centred x = ±dx, at y, z
const eyes = (dx, y, z, r = 0.022, look = 0) => sym("x",
  sphere(r, { mat: "eyeW", pos: [dx, y, z], scale: [1, 1.15, 0.6], detail: 1 }),
  sphere(r * 0.45, { mat: "pupil", pos: [dx - look, y - r * 0.15, z + r * 0.5], detail: 0 }))
const legs = (mat, dx = 0.025, r = 0.014, h = 0.035) => sym("x", cyl(r, h, { mat, pos: [dx, 0, 0], sides: 5 }))

// 88 Wauwau: a dark grey pup, pointed ears, white eyes, a stub tail
model("pet_wauwau", { pivot: "origin" },
  legs("dogD"),
  sphere(0.045, { mat: "dog", pos: [0, 0.06, -0.01], scale: [1, 0.9, 1.2], detail: 1 }),
  sphere(0.06, { mat: "dog", pos: [0, 0.13, 0.01], detail: 1 }),
  sphere(0.03, { mat: "dogL", pos: [0, 0.11, 0.055], scale: [1.1, 0.7, 0.8], detail: 1 }),
  sphere(0.012, { mat: "nose", pos: [0, 0.13, 0.08], detail: 0 }),
  eyes(0.026, 0.15, 0.05),
  sym("x", cone(0.024, 0.07, { mat: "dogD", pos: [0.035, 0.17, -0.01], rot: [-10, 0, -25], sides: 3 })),
  cone(0.015, 0.06, { mat: "dogD", pos: [0, 0.06, -0.06], rot: [-120, 0, 0], sides: 4 }))

// 89 Miaumiau: a white cat, tall ears, one dark ear tip, a long tail
model("pet_miaumiau", { pivot: "origin" },
  legs("cat"),
  sphere(0.04, { mat: "cat", pos: [0, 0.06, -0.01], scale: [1, 1, 1.15], detail: 1 }),
  sphere(0.055, { mat: "cat", pos: [0, 0.13, 0.01], scale: [1.1, 0.95, 1], detail: 1 }),
  eyes(0.025, 0.135, 0.05, 0.02),
  sphere(0.008, { mat: "catP", pos: [0, 0.115, 0.065], detail: 0 }),
  cone(0.022, 0.06, { mat: "cat", pos: [0.035, 0.165, 0], rot: [0, 0, -20], sides: 3 }),
  cone(0.022, 0.06, { mat: "catD", pos: [-0.035, 0.165, 0], rot: [0, 0, 20], sides: 3 }),
  tube([0, 0.05, -0.05, 0, 0.06, -0.09, 0, 0.11, -0.1, 0, 0.14, -0.08], 0.009, { mat: "cat", sides: 5 }))

// 90 Wabbit: a brown sack of a rabbit, ears in one point, fangs, white tail
model("pet_wabbit", { pivot: "origin" },
  legs("wabbitD", 0.022),
  lathe([0.035, 0.02, 0.06, 0.06, 0.055, 0.12, 0.03, 0.18, 0, 0.21], { mat: "wabbit", sides: 6 }),
  sym("x", cone(0.02, 0.07, { mat: "wabbitD", pos: [0.025, 0.16, 0], rot: [0, 0, -18], sides: 3 })),
  eyes(0.02, 0.12, 0.045, 0.016),
  sym("x", cone(0.008, 0.02, { mat: "fang", pos: [0.012, 0.08, 0.055], rot: [180, 0, 0], sides: 3 })),
  sphere(0.025, { mat: "wabbitW", pos: [0, 0.05, -0.055], detail: 0 }))

// 91–94 Bwak: a round bird, a big beak, two head plumes and a tail fan
const bwak = (body, plume) => [
  legs("feet", 0.02, 0.01, 0.025),
  sym("x", box(0.02, 0.008, 0.03, { mat: "feet", pos: [0.02, 0, 0.01] })),
  sphere(0.065, { mat: body, pos: [0, 0.09, 0], scale: [1, 0.95, 1], detail: 1 }),
  cone(0.035, 0.07, { mat: "beak", pos: [0, 0.08, 0.05], rot: [80, 0, 0], sides: 4, scale: [1.2, 1, 0.7] }),
  eyes(0.03, 0.115, 0.05, 0.018),
  sym("x", cone(0.012, 0.08, { mat: plume, pos: [0.015, 0.14, -0.01], rot: [-15, 0, -15], sides: 3 })),
  ...[-1, 0, 1].map((s) => cone(0.016, 0.09, { mat: plume, pos: [s * 0.02, 0.08, -0.05], rot: [-60, s * 20, 0], sides: 3 })),
  sym("x", sphere(0.025, { mat: body, pos: [0.06, 0.08, -0.005], scale: [0.5, 1, 1.3], detail: 0 }))]
model("pet_bwak_earth", { pivot: "origin" }, ...bwak("bwakE", "bwakED"))
model("pet_bwak_fire", { pivot: "origin" }, ...bwak("bwakF", "bwakFD"))
model("pet_bwak_air", { pivot: "origin" }, ...bwak("bwakA", "bwakAD"))
model("pet_bwak_water", { pivot: "origin" }, ...bwak("bwakW", "bwakWD"))

// 95 Moon: a little monkey, a pale face, round ears, a curled tail
model("pet_moon", { pivot: "origin" },
  legs("monkeyD", 0.022),
  sphere(0.038, { mat: "monkey", pos: [0, 0.06, 0], scale: [1, 1.1, 0.9], detail: 1 }),
  sphere(0.052, { mat: "monkey", pos: [0, 0.13, 0.005], detail: 1 }),
  sphere(0.038, { mat: "monkeyL", pos: [0, 0.12, 0.03], scale: [1.1, 0.9, 0.7], detail: 1 }),
  eyes(0.02, 0.14, 0.05, 0.016),
  sym("x", sphere(0.018, { mat: "monkeyL", pos: [0.055, 0.14, 0], scale: [0.5, 1, 1], detail: 0 })),
  tube([0, 0.04, -0.035, 0, 0.03, -0.08, 0, 0.07, -0.11, 0, 0.1, -0.09, 0, 0.09, -0.07], 0.007, { mat: "monkeyD", sides: 4 }))

// 158 Buhordilla: an orange owl, wings up, ear tufts, big yellow eyes
model("pet_owl", { pivot: "origin" },
  legs("beak", 0.02, 0.008, 0.02),
  lathe([0.03, 0.015, 0.06, 0.05, 0.062, 0.11, 0.045, 0.16, 0, 0.17], { mat: "owl", sides: 8 }),
  sphere(0.04, { mat: "owlL", pos: [0, 0.08, 0.035], scale: [1, 1.2, 0.5], detail: 1 }),
  sym("x", sphere(0.022, { mat: "owlEye", pos: [0.024, 0.13, 0.045], scale: [1, 1, 0.5], detail: 1 }),
    sphere(0.01, { mat: "pupil", pos: [0.024, 0.13, 0.055], detail: 0 }),
    cone(0.018, 0.05, { mat: "owlD", pos: [0.04, 0.155, 0], rot: [0, 0, -30], sides: 3 }),
    cone(0.03, 0.1, { mat: "owlD", pos: [0.06, 0.09, -0.01], rot: [0, 0, -50], sides: 3, scale: [1, 1, 0.4] })),
  cone(0.012, 0.025, { mat: "beak", pos: [0, 0.115, 0.06], rot: [160, 0, 0], sides: 3 }))

// 159 Rayalkulo: a small grey-green critter under a big round shell
model("pet_rayalkulo", { pivot: "origin" },
  legs("rayD", 0.028, 0.012, 0.025),
  lathe([0.06, 0.03, 0.075, 0.08, 0.06, 0.14, 0.03, 0.17, 0, 0.18], { mat: "shellG", sides: 7, pos: [0, 0, -0.03] }),
  ...range(5, (k) => sphere(0.02, { mat: "shellGD", pos: [Math.sin(k * 1.26) * 0.06, 0.1 + (k % 2) * 0.04, -0.03 + Math.cos(k * 1.26) * 0.06], scale: [1, 1, 0.4], detail: 0 })),
  sphere(0.045, { mat: "ray", pos: [0, 0.06, 0.03], detail: 1 }),
  eyes(0.02, 0.075, 0.065, 0.014),
  sym("x", cone(0.015, 0.07, { mat: "rayE", pos: [0.02, 0.09, 0.03], rot: [-10, 0, -30], sides: 3 })),
  box(0.016, 0.014, 0.006, { mat: "fang", pos: [0, 0.045, 0.074] }))

// 162 Fotasma: a pale ghost, dark eyes, pink cheeks, a curled tail
model("pet_ghost", { pivot: "origin" },
  lathe([0.035, 0.0, 0.055, 0.04, 0.058, 0.1, 0.04, 0.15, 0, 0.165], { mat: "ghost", sides: 8, pos: [0, 0.02, 0] }),
  cone(0.03, 0.08, { mat: "ghostD", pos: [0, 0.035, -0.035], rot: [-105, 0, 0], sides: 5 }),
  sym("x", sphere(0.01, { mat: "pupil", pos: [0.022, 0.13, 0.05], scale: [1, 1.4, 0.6], detail: 0 }),
    sphere(0.012, { mat: "cheek", pos: [0.035, 0.11, 0.045], scale: [1, 0.7, 0.4], detail: 0 })))

// 163 Kwoko: a squat olive dragonling, spines, fangs, a yellow belly
model("pet_kwoko", { pivot: "origin" },
  legs("kwokoD", 0.028, 0.016, 0.03),
  sphere(0.05, { mat: "kwoko", pos: [0, 0.07, 0], scale: [1, 1, 1.1], detail: 1 }),
  sphere(0.035, { mat: "kwokoY", pos: [0, 0.06, 0.03], scale: [1, 1.2, 0.6], detail: 0 }),
  sphere(0.045, { mat: "kwoko", pos: [0, 0.13, 0.03], scale: [1.1, 0.9, 1.1], detail: 1 }),
  eyes(0.022, 0.15, 0.06, 0.014),
  sym("x", cone(0.008, 0.02, { mat: "fang", pos: [0.015, 0.11, 0.07], rot: [180, 0, 0], sides: 3 })),
  ...range(4, (k) => cone(0.015, 0.04, { mat: "kwokoD", pos: [0, 0.17 - k * 0.035, -0.0 - k * 0.02], rot: [-30 - k * 15, 0, 0], sides: 3 })),
  cone(0.02, 0.06, { mat: "kwokoD", pos: [0, 0.04, -0.05], rot: [-110, 0, 0], sides: 4 }))

// 164 Cuerbako: a black crow, a big yellow beak, yellow feet
model("pet_crow", { pivot: "origin" },
  legs("crowY", 0.018, 0.007, 0.025),
  sym("x", box(0.018, 0.006, 0.03, { mat: "crowY", pos: [0.018, 0, 0.012] })),
  sphere(0.05, { mat: "crow", pos: [0, 0.08, 0], scale: [1, 1.1, 1.1], detail: 1 }),
  sphere(0.042, { mat: "crowL", pos: [0, 0.135, 0.01], detail: 1 }),
  cone(0.025, 0.07, { mat: "crowY", pos: [0, 0.125, 0.04], rot: [85, 0, 0], sides: 4, scale: [1, 1, 0.6] }),
  eyes(0.022, 0.15, 0.03, 0.013),
  sym("x", cone(0.025, 0.08, { mat: "crowD", pos: [0.045, 0.09, -0.01], rot: [-20, 0, -40], sides: 3, scale: [1, 1, 0.4] })),
  cone(0.02, 0.07, { mat: "crowD", pos: [0, 0.06, -0.05], rot: [-100, 0, 0], sides: 3 }))

// 165 Tortuga: a green turtle standing up, a dark shell with a red rim
model("pet_turtle", { pivot: "origin" },
  legs("turtleD", 0.028, 0.014, 0.035),
  lathe([0.05, 0.02, 0.065, 0.07, 0.05, 0.13, 0, 0.15], { mat: "tshell", sides: 8, pos: [0, 0, -0.025] }),
  torus(0.06, 0.008, { mat: "tshellR", pos: [0, 0.075, -0.025], rot: [80, 0, 0], sides: 4, rings: 12 }),
  sphere(0.045, { mat: "turtle", pos: [0, 0.07, 0.015], scale: [1, 1.1, 0.8], detail: 1 }),
  sphere(0.045, { mat: "turtle", pos: [0, 0.14, 0.02], detail: 1 }),
  eyes(0.022, 0.15, 0.055, 0.016),
  sym("x", cyl(0.012, 0.05, { mat: "turtleD", pos: [0.05, 0.09, 0.02], rot: [0, 0, 60], sides: 5 })))

// 166 Abra: a grumpy tree stump on twig legs, twig arms, a hollow top
model("pet_abra", { pivot: "origin" },
  sym("x", tube([0.02, 0.03, 0, 0.035, 0.012, 0.01, 0.045, 0, 0.025], 0.008, { mat: "stumpD", sides: 4 }),
    tube([0.05, 0.08, 0, 0.08, 0.09, 0.01, 0.1, 0.07, 0.02], 0.008, { mat: "stumpD", sides: 4 })),
  cyl(0.055, 0.12, { mat: "stump", sides: 7, top: 0.05, pos: [0, 0.025, 0], jitter: 0.003 }),
  torus(0.047, 0.01, { mat: "ring", pos: [0, 0.145, 0], sides: 4, rings: 10 }),
  cyl(0.04, 0.005, { mat: "stumpD", pos: [0, 0.142, 0], sides: 7 }),
  eyes(0.02, 0.1, 0.05, 0.016, 0.004),
  sym("x", box(0.03, 0.008, 0.01, { mat: "stumpD", pos: [0.02, 0.122, 0.052], rot: [0, 0, -18] })))
}
