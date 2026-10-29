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
  // the rock spires: arena 6's cliff sandstone (vertical strata; build its
  // kit.tx.js first), the tops a shade lighter
  ["cliff" + s, { tex: "../arena6/out/cliff" + s, uv: 2.2, rough: 0.9 }],
  ["cliffL" + s, { tex: "../arena6/out/cliff" + s, uv: 2.2, rough: 0.9, color: "#fff4dc" }],
  // the recessed core between the plates, in shade
  ["cliffD" + s, { tex: "../arena6/out/cliff" + s, uv: 2.2, rough: 0.95, color: "#a89a82" }],
])))
// moss on the spires' ledges: [a, b, c]
const MOSS = { moss: ["#7a8a2a", "#5a7a3a", "#6a6a2a"], mossL: ["#a8b83c", "#7ea050", "#94923a"] }
pal(Object.fromEntries(LOOMS.flatMap((s, i) => Object.entries(MOSS).map(([k, v]) => [k + s, v[i]]))))
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
const SKINNED = ["softPumice", "softPumiceL", "softMolten", "cliff", "cliffL", "cliffD", ...Object.keys(FALL), ...Object.keys(MOSS)]
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

// --- rock spires (1765, 1766) -----------------------------------------------
// tall standing sandstone rocks, about five metres, that wall the arena's back
// edges: a dark recessed core with plates and boulders standing out of the
// two faces the camera sees (+x, +z), so the silhouette is ragged and the
// clefts between them fall into shade.
// A slab: a vertical plate w wide, d thick, h tall from y, its top cut on a
// slant, turned a degrees, a little lumpy
const slab = (x, y, z, w, d, h, slant, a, mat, seed) =>
  extrude([-w / 2, 0, w / 2, 0, w / 2 - 0.03, h - slant, w * 0.15, h - slant * 0.4, -w / 2 + 0.04, h],
    d, { mat, pos: [x, y, z], rot: [0, a, 0], jitter: 0.02, seed })
// a pad of moss on a ledge
const moss = (x, y, z, r, seed) => sphere(r, { mat: seed % 2 ? "moss" : "mossL", detail: 1, pos: [x, y, z], scale: [1, 0.4, 1], jitter: 0.015, seed })
// rock spire (1765): a narrow dark core, plates of different heights round
// it (the tallest at the back), a broken chunk standing proud near the top,
// a tall rounded boulder leaning at the foot of the seen corner
model("rock_spire",
  slab(-0.06, 0, -0.06, 0.6, 0.6, 4.7, 0.3, 45, "cliffD", 1),
  slab(-0.16, 0, -0.18, 0.58, 0.34, 5.0, 0.35, 45, "cliff", 2),
  slab(0.26, 0, 0.04, 0.34, 0.3, 4.2, 0.35, 75, "cliff", 3),
  slab(0.1, 0, 0.27, 0.42, 0.26, 3.5, 0.3, 20, "cliff", 4),
  slab(-0.3, 0, 0.18, 0.3, 0.26, 2.9, 0.25, 35, "cliff", 5),
  slab(0.38, 0, -0.26, 0.28, 0.24, 2.4, 0.2, 80, "cliff", 6),
  box(0.16, 0.6, 0.14, { mat: "cliffL", pos: [0.12, 4.25, 0.06], rot: [0, 40, 6], jitter: 0.015, seed: 7 }),
  rock(0.3, { mat: "cliff", pos: [0.3, 0.5, 0.3], rough: 0.1, scale: [1, 1.7, 1], seed: 8 }),
  rock(0.2, { mat: "cliffD", pos: [-0.02, 0.3, 0.42], rough: 0.1, scale: [1, 1.4, 1], seed: 9 }),
  moss(0.22, 3.52, 0.3, 0.13, 10), moss(-0.32, 2.92, 0.22, 0.12, 11))
// wide rock spire (1766): a broad mass of three big blocks stacked, each
// with deeply rounded, bulging corners and pushed a little towards the seen
// corner, a dark recessed neck between them so the ledges read; vertical
// plates down the +x side, a slanted crown, moss on the ledges
const bulge = (y, half, h, dx, dz, seed) => tf({ pos: [dx, y, dz] },
  prismUp(roundSquare(half, 0.24, 5, 0.07, seed), h, 0, "cliff", 0.035))
model("rock_spire_wide",
  prismUp(roundSquare(0.36, 0.1, 4, 0.05, 1), 4.5, 0, "cliffD", 0.03),
  bulge(0, 0.5, 1.5, 0.03, 0.03, 2),
  bulge(1.6, 0.47, 1.6, 0.05, 0.05, 3),
  bulge(3.3, 0.42, 1.05, 0.02, 0.06, 4),
  slab(0.42, 0, -0.16, 0.36, 0.22, 3.9, 0.3, 90, "cliff", 5),
  slab(-0.3, 0, -0.32, 0.5, 0.3, 4.6, 0.3, 45, "cliff", 7),
  tf({ pos: [0.02, 4.38, 0.04] }, slab(0, 0, 0, 0.9, 0.84, 0.55, 0.32, 45, "cliffL", 8)),
  moss(0.26, 1.52, 0.4, 0.16, 9), moss(-0.18, 3.32, 0.4, 0.13, 10), moss(0.12, 0.08, 0.52, 0.16, 11))
for (const n of ["rock_spire", "rock_spire_wide"]) looms(n)
