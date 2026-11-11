// S35c: the 6 fighter dofus (fightercards type 5). Own designs; the retail
// illustrations (capturas/s35/flow/accesorios) only gave the idea.
// Convention (Fighter3D.hang): base on y = 0, ~0.19 m tall; the dofus
// floats beside the fighter (DOFUS_AT), bobbing and turning.
{ // the helpers below stay local to this include
pal({
  emerald: "#b8d23a", emeraldD: "#6f8a1c", emeraldL: "#e8f070",
  slate: "#5f8a9a", slateD: "#2f5566", frost: "#d8eef2",
  ember: "#c4421e", emberD: "#7e2614", flame: { color: "#ffb030", emit: "#ff9a20", glow: 1.6 }, flameR: { color: "#ff6a1c", emit: "#ff5a10", glow: 1.2 },
  carrot: "#f08a1c", carrotD: "#c25a12", carrotL: "#ffc060",
  vulbis: "#c8281c", vulbisD: "#6e140e", vulbisL: "#ff6a4a", soot: "#2a1412",
  ice: { color: "#a8e4ec", rough: 0.15, metal: 0.1 }, iceD: "#4fa8b8", iceL: "#e8fbff",
})

const EGG = [0, 0, 0.042, 0.012, 0.064, 0.06, 0.064, 0.11, 0.046, 0.16, 0.02, 0.185, 0, 0.19]
const egg = (mat, o = {}) => lathe(EGG, { mat, sides: 10, ...o })
const ring = (n, f) => Array.from({ length: n }, (_, i) => f(i, (i * 360) / n))
const rad = (a) => (a * Math.PI) / 180
// a path winding round the egg's surface (radius follows the egg's profile)
const eggR = (y) => { for (let i = 2; i < EGG.length; i += 2) if (y <= EGG[i + 1]) {
  const t = (y - EGG[i - 1]) / (EGG[i + 1] - EGG[i - 1]); return EGG[i - 2] + (EGG[i] - EGG[i - 2]) * t } return 0 }
const spiral = (y0, y1, turns, out, n = 20) => Array.from({ length: n + 1 }, (_, i) => {
  const t = i / n, y = y0 + (y1 - y0) * t, a = t * turns * 2 * Math.PI, r = eggR(y) + out
  return [Math.sin(a) * r, y, Math.cos(a) * r] }).flat()

// 118 Esmeralda: a yellow-green egg, a darker swirl winding up it, light spots
model("dofus_emerald",
  egg("emerald"),
  tube(spiral(0.02, 0.17, 1.3, -0.002, 28), 0.008, { mat: "emeraldD", sides: 5 }),
  ...[[0.04, 0.05, 60], [-0.03, 0.1, 230], [0.02, 0.145, 330]].map(([dx, y, a]) =>
    sphere(0.011, { mat: "emeraldL", pos: [Math.sin(rad(a)) * eggR(y), y, Math.cos(rad(a)) * eggR(y)], scale: [1, 1, 0.5], rot: [0, a, 0], detail: 0 })))

// 119 Turquesa: a slate-blue egg under a frosted cap that drips down
model("dofus_turquoise",
  egg("slate"),
  lathe([0.05, 0.135, 0.054, 0.14, 0.044, 0.165, 0.022, 0.186, 0, 0.193], { mat: "frost", sides: 10 }),
  ring(5, (i, a) => cone(0.012, 0.03 + (i % 2) * 0.02, { mat: "frost", sides: 4,
    pos: [Math.sin(rad(a)) * 0.07, 0.102, Math.cos(rad(a)) * 0.07], rot: [180, 0, 0] })),
  sphere(0.03, { mat: "slateD", pos: [0, 0.05, 0.05], scale: [1, 1.2, 0.4], detail: 0 }))

// 120 Púrpura: a cracked ember of rock with flames licking up its sides
model("dofus_ember",
  rock(0.07, { mat: "ember", seed: 4, squash: 1.2, pos: [0, 0.08, 0] }),
  rock(0.035, { mat: "emberD", seed: 7, pos: [0.03, 0.03, 0.03] }),
  ...[[0.055, 0.07, 0.03, 0.08, -25], [-0.06, 0.06, 0.01, 0.09, 28], [0.0, 0.13, 0.0, 0.08, 0], [0.02, 0.06, -0.06, 0.07, -12], [-0.02, 0.08, 0.06, 0.06, 15]].map(([x, y, z, h, r], i) =>
    cone(0.026, h, { mat: i % 2 ? "flameR" : "flame", sides: 4, pos: [x, y, z], rot: [r * Math.sign(z || 1) * 0.5, 30 + i * 40, -r] })))

// 121 Zanahowia: a carrot-orange egg with a tilted ring and a pale swirl
model("dofus_carrot",
  egg("carrot"),
  torus(0.088, 0.007, { mat: "carrotD", pos: [0, 0.075, 0], rot: [18, 0, 12], sides: 5, rings: 18 }),
  tube(spiral(0.05, 0.12, 0.8, 0.002, 12), 0.007, { mat: "carrotL", sides: 4 }))

// 122 Vulbis: a deep red egg rising from a crown of dark flame leaves
model("dofus_vulbis",
  egg("vulbis", { pos: [0, 0.02, 0] }),
  sphere(0.016, { mat: "vulbisL", pos: [0.03, 0.14, 0.04], detail: 0 }),
  ring(9, (i, a) => tf({ pos: [Math.sin(rad(a)) * 0.055, 0.0, Math.cos(rad(a)) * 0.055], rot: [0, a, 0] },
    cone(0.022, 0.1 + (i % 3) * 0.025, { mat: i % 2 ? "vulbisD" : "soot", sides: 3, rot: [14, 0, 0], scale: [1, 1, 0.5] }))))

// 123 de los Hielos: a cluster of ice crystals
model("dofus_ice", { scale: 1.3 },
  cyl(0.026, 0.12, { mat: "ice", sides: 6, top: 0.0 }),
  ...[[0.04, 0.0, 0.01, 0.08, -22, 0], [-0.04, 0.0, 0.015, 0.09, 20, 10], [0.01, 0.0, -0.04, 0.075, 0, 22],
      [-0.015, 0.0, 0.045, 0.06, -10, -20], [0.035, 0, -0.03, 0.055, 15, 25]].map(([x, y, z, h, rz, rx], i) =>
    cyl(0.016, h, { mat: i % 2 ? "iceD" : "iceL", sides: 6, top: 0.0, pos: [x, y, z], rot: [rx, 0, rz] })),
  cyl(0.05, 0.015, { mat: "iceD", sides: 6 }))
}
