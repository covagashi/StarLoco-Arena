// Arena 8 (retail world 39: a volcano) — the pieces it doesn't share with the
// other kits, each in three looms: <name> (a), <name>_b, <name>_c. Build
// kit.tx.js first. Retail gfx in brackets.
include("../common/shapes.kx.js")

const LOOMS = ["", "_b", "_c"]
pal(Object.fromEntries(LOOMS.flatMap((s) => [
  // the volcanic floor stones: pumice (kit.tx.js), smooth normals (soft*);
  // the worn smooth stone of the 2285 cluster a shade paler
  ["softPumice" + s, { tex: "out/pumice" + s, uv: 1.1, rough: 0.8 }],
  ["softPumiceL" + s, { tex: "out/pumice" + s, uv: 1.6, rough: 0.7, color: "#d8d0c8" }],
  // lava (kit.tx.js molten): the cushion top smooth (soft*), the sides a
  // little deeper in tone
  ["softMolten" + s, { tex: "out/molten" + s, uv: 1.7, rough: 0.3 }],
])))
// the lava fall cools as it drops: palette glows, [a, b, c] per key
// the lava sides and drips (molten), a deeper orange than the top; the lava
// fall cools as it drops (fall0 to fall4) to near black
const FALL = {
  molten: ["#e07810", "#f4b028", "#b8300a"],
  fall0: ["#f8a818", "#ffd040", "#f06018"], fall1: ["#e88010", "#f8b428", "#c8380c"],
  fall2: ["#c44e0a", "#d88818", "#8a1c08"], fall3: ["#7a2408", "#9a4a0c", "#4e0e06"],
  fall4: ["#2e0c06", "#4a2208", "#220604"], crust: ["#3a2418", "#4a3a2a", "#2a1410"],
}
const GLOW = { molten: 0.9, fall0: 1.3, fall1: 1.1, fall2: 0.8, fall3: 0.5, fall4: 0.15 }
pal(Object.fromEntries(LOOMS.flatMap((s, i) => Object.entries(FALL).map(([k, v]) =>
  [k + s, GLOW[k] ? { color: v[i], emit: v[i], glow: GLOW[k], rough: 0.35 } : { color: v[i], rough: 0.9 }]))))
const SKINNED = ["softPumice", "softPumiceL", "softMolten", ...Object.keys(FALL)]
const looms = (name) => threeLooms(name, SKINNED)

// a rounded floor stone placed in screen terms: u along the screen's
// horizontal (world (1, 0, -1)), v towards the camera (world (1, 0, 1));
// ru its half length along u, rv along v, h its half thickness, a a small
// extra turn (degrees). A squashed sphere, a little lumpy.
const R2 = Math.SQRT1_2
// a repeatable pseudo-random number in 0..1 for (i, k, seed)
const rnd = (i, k, seed) => ((Math.sin((i + 1) * 12.9898 * k + seed * 78.233) * 43758.5453) % 1 + 1) % 1
const stone = (u, v, ru, rv, h, a, mat, seed) =>
  sphere(1, { mat, detail: 2, pos: [(u + v) * R2, h, (v - u) * R2], rot: [0, 45 + a, 0], scale: [ru, h, rv], jitter: 0.012, seed })

// --- volcanic floor -----------------------------------------------------------
// volcanic slab (2285): three rounded pumice stones lying side by side across
// the cell, two long ones at the back and a smaller, smoother one in front
model("volcanic_slab",
  stone(-0.26, -0.18, 0.48, 0.25, 0.16, 6, "softPumice", 1),
  stone(0.3, -0.06, 0.44, 0.25, 0.15, -8, "softPumice", 2),
  stone(-0.04, 0.27, 0.34, 0.2, 0.1, 4, "softPumiceL", 3))
// volcanic rock (2280): one big domed pumice stone across the cell, its
// crown towards the back, the front falling steeper
model("volcanic_rock",
  stone(0, 0.04, 0.55, 0.4, 0.2, 0, "softPumice", 4),
  stone(-0.04, -0.1, 0.42, 0.28, 0.27, 4, "softPumice", 5))
for (const n of ["volcanic_slab", "volcanic_rock"]) looms(n)

// --- lava ---------------------------------------------------------------------
// a lava cell: a short glowing body under a puffy rounded cushion that fills
// the cell (top at 0.24); the cushion is square, so the body keeps tight
// corners to cover it
const lavaCell = (seed) => [
  prismUp(roundSquare(CELL_HALF - 0.01, 0.04), 0.09, 0, "molten", 0.004),
  terrain(2 * (CELL_HALF - 0.025), 2 * (CELL_HALF - 0.025),
    { res: 18, height: 0.15, fn: cushionFn(CELL_HALF - 0.025, 0.16, 0.2, 0.12, seed), mat: "softMolten", pos: [0, 0.085, 0] }),
]
// drips hanging from the rim, along the two sides the camera sees (+x, +z);
// a lathe sits on its base, so each is placed to end just under the body's
// top (0.09) and never pierce the cushion
const drips = (seed) => [[0.48, -0.28], [0.48, 0.1], [0.48, 0.34], [-0.3, 0.48], [0.02, 0.48], [0.24, 0.48]].map(([x, z], i) => {
  const len = 0.12 + rnd(i, 3, seed) * 0.06
  return lathe([0, 0, 0.03, len - 0.09, 0.04, len - 0.05, 0.035, len - 0.01, 0, len],
    { mat: "molten", sides: 6, pos: [x, 0.08 - len, z], scale: [x > 0.4 ? 0.6 : 1, 1, z > 0.4 ? 0.6 : 1] })
})
// lava cell (2278): smooth lava filling the cell
model("lava_cell", lavaCell(1))
// lava cell with blotches (2277, 2279, 2270, 2271; arena 2's 142, 143): the
// same cell, the cooler blotches of the texture, a few drips over the rim
model("lava_spots", { pivot: "origin" }, lavaCell(2), drips(5))
// lava sheet (2276): the molten floor itself, flat, filling the cell
model("lava_sheet", prismUp(roundSquare(0.5, 0.08), 0.03, 0, "softMolten", 0.003))
// lava fall (146): a lava cell spilling over its +x side, two streams split
// by a dark rock, cooling to dull red as they fall about two metres
const FALL_BANDS = ["fall0", "fall1", "fall2", "fall3", "fall4"]
const stream = (z, w, seed) => [
  // the lip: lava rolling over the edge, round
  tube([0.36, 0.2, z, 0.52, 0.18, z, 0.6, 0.04, z, 0.61, -0.14, z], w * 0.75, { mat: "fall0", sides: 8 }),
  // the stream, five bands, each cooler and a little thinner, flattened
  // against the face
  FALL_BANDS.map((m, i) => cyl(w * 0.75 * (1 - i * 0.05), 0.46, {
    mat: m, sides: 8, pos: [0.61, -0.14 - (i + 1) * 0.45, z], scale: [0.45, 1, 1], jitter: 0.006, seed: seed + i })),
]
model("lava_fall", { pivot: "origin" },
  lavaCell(3),
  stream(-0.2, 0.24, 7), stream(0.27, 0.18, 9),
  rock(0.15, { mat: "crust", pos: [0.58, 0.02, 0.06], squash: 0.9, seed: 11 }),
  drips(13))
for (const n of ["lava_cell", "lava_spots", "lava_sheet", "lava_fall"]) looms(n)
