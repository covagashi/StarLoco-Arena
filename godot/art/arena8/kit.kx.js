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
  // the dead pines' bleached trunks (kit.tx.js deadwood), thin branches a
  // shade darker
  ["deadwood" + s, { tex: "out/deadwood" + s, uv: 0.8, rough: 0.85 }],
  ["deadwoodD" + s, { tex: "out/deadwood" + s, uv: 0.8, rough: 0.85, color: "#c8bca8" }],
  // the volcanic spikes and horns (kit.tx.js horn), their tips darker
  ["horn" + s, { tex: "out/horn" + s, uv: 0.9, rough: 0.5 }],
  ["hornD" + s, { tex: "out/horn" + s, uv: 0.9, rough: 0.5, color: "#8a6a5a" }],
])))
// moss on the spires' ledges: [a, b, c]
const MOSS = { moss: ["#5e6e24", "#4a6432", "#585a24"], mossL: ["#7e9030", "#64843e", "#787630"],
  // the dead pines' last tufts of needles: dry gold (retail), rust, ash
  needle: ["#b08a24", "#8a4a1a", "#6a645a"], needleL: ["#d8b040", "#b0642a", "#8e887c"] }
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
// embers glowing at the spikes' feet
FALL.ember = ["#ffb020", "#ffc840", "#ff5a14"]
const GLOW = { ember: 2, molten: 0.9, fall0: 1.3, fall1: 1.1, fall2: 0.8, fall3: 0.5, fall4: 0.15 }
pal(Object.fromEntries(LOOMS.flatMap((s, i) => Object.entries(FALL).map(([k, v]) =>
  [k + s, GLOW[k] ? { color: v[i], emit: v[i], glow: GLOW[k], rough: 0.35 } : { color: v[i], rough: 0.9 }]))))
const SKINNED = ["softPumice", "softPumiceL", "softMolten", "cliff", "cliffL", "cliffD", "deadwood", "deadwoodD", "horn", "hornD", ...Object.keys(FALL), ...Object.keys(MOSS)]
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

// --- loose rocks (1761, 1762, 1764, 1767, 1817) -----------------------------
// the same sandstone as the spires, in five shapes, as wide as the retail
// ones (about 1.3-1.7 m across the screen, a little over the cell). Built of
// chunky faceted boulders placed in screen terms like the floor stones:
// u across the screen, v towards the camera, y its centre height; su, sy, sv
// its half extents; tilt leans it back (degrees)
const boulder = (u, y, v, r, su, sy, sv, mat, seed, tilt = 0) =>
  tf({ pos: [(u + v) * R2, y, (v - u) * R2], rot: [0, 45, 0] },
    rock(r, { mat, rough: 0.1, scale: [su, sy, sv], rot: [-tilt, 0, 0], seed }))
// a crag: an angular sandstone block that narrows to a blunt slanted top:
// a faceted lathe (5-6 sides), flattened to rw across the screen and rd
// towards the camera, h tall from its foot at y, leaned back by tilt and
// sideways by roll (degrees)
const crag = (u, y, v, rw, rd, h, mat, seed, { tilt = 0, roll = 0, sides = 5, turn = 0 } = {}) =>
  tf({ pos: [(u + v) * R2, y, (v - u) * R2], rot: [0, 45 + turn, 0] },
    tf({ rot: [-tilt, 0, roll], scale: [rw, 1, rd] },
      lathe([1, 0, 0.97, h * 0.5, 0.82, h * 0.82, 0.4, h * 0.97, 0, h], { mat, sides, jitter: 0.04, seed })))
// tall rock (1764): about 3.3 m, a short spire of tall blocks: the tallest
// at the back, a broad plate in front of it, a lower block at each side
model("rock_tall",
  crag(-0.1, 0, -0.2, 0.55, 0.42, 3.3, "cliff", 1, { roll: 2 }),
  crag(0.1, 0, 0.18, 0.5, 0.22, 2.4, "cliff", 2, { tilt: 3, roll: -3, sides: 6 }),
  crag(-0.52, 0, 0.0, 0.28, 0.36, 2.7, "cliffD", 3, { roll: 5, turn: 10 }),
  crag(0.55, 0, -0.05, 0.28, 0.36, 1.7, "cliff", 4, { roll: -6, turn: -10 }),
  moss(-0.25, 2.65, 0.15, 0.14, 6), moss(0.3, 1.62, 0.28, 0.13, 7))
// leaning rock (1762): three blocks leaning back one behind the other, each
// lower towards the front, a small block at the foot
model("rock_leaning",
  crag(-0.08, 0, -0.3, 0.72, 0.28, 1.4, "cliff", 1, { tilt: 18 }),
  crag(0.04, 0, -0.02, 0.64, 0.26, 1.05, "cliff", 2, { tilt: 18, roll: -5, sides: 6 }),
  crag(0.16, 0, 0.26, 0.55, 0.24, 0.7, "cliff", 3, { tilt: 15, roll: 4 }),
  crag(-0.66, 0, 0.12, 0.2, 0.22, 0.5, "cliffD", 4),
  moss(-0.2, 0.5, 0.4, 0.11, 5))
// peaked rock (1761): one five-sided rock narrowing to a blunt peak, leaning
// a little back
model("rock_peak",
  tf({ rot: [-6, 20, 4] },
    lathe([0.62, 0, 0.58, 0.45, 0.44, 0.95, 0.17, 1.28, 0, 1.33], { mat: "cliff", sides: 5, jitter: 0.05, seed: 1 })),
  moss(0.42, 0.5, 0.24, 0.13, 2), moss(0.26, 0.22, 0.44, 0.11, 3))
// blocky rock (1767): a big back block, a smaller block stacked in front of
// it, a rounded boulder at the front corner and a shard at its foot
model("rock_blocky",
  crag(-0.05, 0, -0.22, 0.78, 0.5, 1.45, "cliff", 1, { roll: 3, sides: 6 }),
  crag(-0.15, 0, 0.18, 0.55, 0.32, 1.0, "cliff", 2, { tilt: 4 }),
  boulder(0.42, 0.3, 0.32, 0.34, 1.0, 0.95, 0.9, "cliff", 3),
  crag(0.68, 0, 0.0, 0.14, 0.16, 0.5, "cliffD", 4, { roll: -12 }),
  moss(-0.12, 0.98, 0.3, 0.12, 5))
// low rock (1817): a low heap of rounded flat slabs, the tallest at the back
model("rock_low",
  boulder(-0.1, 0.3, -0.16, 0.45, 1.5, 0.75, 0.9, "cliff", 1),
  boulder(0.34, 0.22, 0.08, 0.38, 1.3, 0.7, 0.9, "cliff", 2),
  boulder(-0.26, 0.15, 0.28, 0.3, 1.4, 0.6, 0.8, "cliffD", 3),
  moss(0.05, 0.42, 0.42, 0.12, 4))
for (const n of ["rock_tall", "rock_leaning", "rock_peak", "rock_blocky", "rock_low"]) looms(n)

// --- dead pines (1729, 1730, 1731) ------------------------------------------
// bleached barkless trunks, broken snags, a few long bare branches, small
// fans of dry needles left at some tips, roots splayed at the foot, moss in
// patches. The volcano map tints them almost black (loom c is charred).
// screen directions: a = 0 points right across the screen, 90 towards the
// camera, 180 left
const sdir = (a) => {
  const c = Math.cos(a * Math.PI / 180), s = Math.sin(a * Math.PI / 180)
  return [(c + s) * R2, (s - c) * R2]
}
// the trunk: six-sided, the foot swelling, barely thinner up high, its top
// broken off flat; three sections chained, each kinked a few degrees (wave),
// so it wavers like the retail ones. The branches are placed on a straight
// axis; the kinks are small enough not to part them from the wood.
const trunk = (h, r, wave, seed) => {
  const hs = [h * 0.36, h * 0.34, h * 0.3], rs = [r, r * 0.86, r * 0.72, r * 0.48]
  const sec = (i) => i > 2 ? [] : tf({ pos: [0, i ? hs[i - 1] : 0, 0], rot: i ? [wave * (i % 2 ? 1 : -1), 0, wave * 0.7 * (i % 2 ? -1 : 1)] : [0, 0, 0] },
    lathe(i ? [rs[i] * 1.04, -0.02, rs[i + 1], hs[i]] : [r * 1.6, 0, r * 1.05, 0.35, rs[1], hs[0]],
      { mat: "deadwood", sides: 6, jitter: 0.01, seed: seed + i }), sec(i + 1))
  return sec(0)
}
// splayed roots: n low wedges round the foot
const roots = (r, n, seed) => Array.from({ length: n }, (_, i) => {
  const a = i * 360 / n + rnd(i, 7, seed) * 30
  return tf({ rot: [0, a, 0] }, cone(r * 0.8, r * 2.2 + rnd(i, 8, seed) * r, { mat: "deadwood", sides: 4, pos: [r * 1.1, r * 0.6, 0], rot: [0, 0, -62], scale: [1, 1, 0.6], jitter: 0.008, seed: seed + i }))
})
// a branch from the trunk at height y towards screen direction a: len long,
// rising by up, kinked once; r its radius
const branch = (y, a, len, up, r, kink = 0.15) => {
  const [dx, dz] = sdir(a), [kx, kz] = sdir(a + 90)
  const mx = dx * len * 0.5 + kx * kink * len, mz = dz * len * 0.5 + kz * kink * len, my = y + up * 0.4
  const out = [tube([0, y, 0, mx, my, mz, dx * len, y + up, dz * len], r, { mat: "deadwoodD", sides: 4 })]
  // a long branch forks: a twig from its middle, up and aside
  if (len > 0.55) {
    const [fx, fz] = sdir(a + (kink >= 0 ? 35 : -35))
    out.push(tube([mx, my, mz, mx + fx * len * 0.3, my + len * 0.22, mz + fz * len * 0.3], r * 0.6, { mat: "deadwoodD", sides: 3 }))
  }
  return out
}
// a fan of dry needles at (x, y, z), opening towards screen direction a:
// n blades in a half circle, size long
const tuft = (x, y, z, a, size, seed) => tf({ pos: [x, y, z], rot: [0, a - 45, 0] },
  Array.from({ length: 10 }, (_, i) => cone(0.045, size * (0.75 + rnd(i, 9, seed) * 0.35),
    { mat: i % 2 ? "needle" : "needleL", sides: 3, rot: [rnd(i, 10, seed) * 20 - 10, 0, -80 + i * 17], scale: [1, 1, 0.3] })))
// where a branch of len towards a ends (the tuft goes there)
const tip = (y, a, len, up) => { const [dx, dz] = sdir(a); return [dx * len, y + up, dz * len] }
// a moss patch on the trunk at height y, on the seen side: a few small
// lumps hugging the wood, h tall
const trunkMoss = (y, r, h, seed) => Array.from({ length: 4 }, (_, i) => {
  const a = (rnd(i, 11, seed) - 0.5) * 80 * Math.PI / 180, yy = y - h / 2 + (i + 0.5) * h / 4
  return sphere(r * 0.6, { mat: (seed + i) % 2 ? "moss" : "mossL", detail: 1,
    pos: [Math.cos(Math.PI / 4 + a) * r * 0.85, yy, Math.sin(Math.PI / 4 + a) * r * 0.85], scale: [0.6, 1.4 + rnd(i, 12, seed), 0.6], jitter: 0.02, seed: seed + i })
})

// tall dead pine (1731): about 9 m and very slim; two long bare arms at
// mid-height, short broken snags all the way up, two tufts high on the left,
// a broken fork at the top
model("dead_pine_tall",
  trunk(8.6, 0.11, 2, 1), roots(0.11, 5, 2),
  branch(4.3, 20, 1.45, 0.9, 0.035, 0.08), branch(4.0, 160, 1.15, 0.6, 0.03, -0.1),
  branch(6.6, 170, 0.5, 0.3, 0.03), branch(2.6, 175, 0.85, 0.15, 0.03), branch(5.1, 10, 0.6, 0.15, 0.03),
  branch(3.1, 160, 0.45, 0.25, 0.04), branch(7.4, 30, 0.3, 0.15, 0.03), branch(8.2, 15, 0.45, 0.5, 0.025),
  branch(6.15, 165, 0.3, 0.1, 0.025),
  // the top narrows into a thin fork
  tf({ pos: [0, 8.5, 0] }, cone(0.05, 0.8, { mat: "deadwood", sides: 5, rot: [3, 0, -6] }), cone(0.03, 0.45, { mat: "deadwoodD", sides: 4, rot: [-10, 0, 25] })),
  tuft(...tip(6.6, 170, 0.5, 0.3), 160, 0.42, 3), tuft(...tip(6.25, 165, 0.3, 0.1), 175, 0.34, 4),
  trunkMoss(1.0, 0.13, 0.7, 5), trunkMoss(3.2, 0.11, 0.6, 6))
// dead pine (1730): about 6 m; a crown of three bare branches arcing out
// near the top, a curled snag, five tufts of needles, moss on a bulge and a
// mossy pad round the foot
model("dead_pine",
  trunk(6.1, 0.12, 3, 11), roots(0.12, 5, 12),
  branch(5.0, 175, 0.9, 0.55, 0.03, 0.1), branch(5.15, 10, 0.95, 0.45, 0.03, -0.1), branch(5.6, 30, 0.6, 0.3, 0.025),
  branch(3.6, 160, 0.8, 0.3, 0.035), branch(3.9, 15, 1.0, 0.25, 0.035, 0.25), branch(2.3, 10, 0.55, 0.2, 0.035),
  branch(1.9, 170, 0.4, 0.05, 0.03), branch(4.6, 20, 0.45, 0.2, 0.03),
  tuft(...tip(5.6, 30, 0.6, 0.3), 40, 0.36, 13), tuft(...tip(3.6, 160, 0.8, 0.3), 160, 0.48, 14),
  tuft(...tip(4.6, 20, 0.45, 0.2), 30, 0.36, 15), tuft(...tip(2.3, 10, 0.55, 0.2), 20, 0.36, 16),
  trunkMoss(1.4, 0.15, 0.6, 17), trunkMoss(2.5, 0.13, 0.35, 18),
  sphere(0.5, { mat: "moss", detail: 1, pos: [0.1, 0, 0.1], scale: [1, 0.12, 0.8], jitter: 0.02, seed: 19 }),
  sphere(0.3, { mat: "mossL", detail: 1, pos: [0.4, 0, 0.0], scale: [1, 0.14, 0.8], jitter: 0.02, seed: 20 }))
// short dead pine (1729): about 4 m, thick for its height, its top broken
// into three spikes, two twisted branches, two tufts, roots splayed wide
model("dead_pine_short",
  trunk(3.0, 0.15, 4, 21), roots(0.15, 6, 22),
  tf({ pos: [0, 2.85, 0] },
    cone(0.07, 1.2, { mat: "deadwood", sides: 5, rot: [4, 0, 8], jitter: 0.008 }),
    cone(0.06, 1.0, { mat: "deadwood", sides: 5, pos: [0.07, 0, -0.06], rot: [-6, 0, -10], jitter: 0.008 }),
    cone(0.05, 0.7, { mat: "deadwood", sides: 5, pos: [-0.06, 0, 0.05], rot: [8, 0, 14], jitter: 0.008 })),
  branch(2.5, 165, 0.7, 0.35, 0.035, 0.35), branch(2.1, 15, 0.6, 0.35, 0.035, -0.3), branch(1.7, 175, 0.5, 0.25, 0.03),
  branch(1.5, 20, 0.35, 0.3, 0.03),
  tuft(...tip(2.5, 165, 0.7, 0.35), 170, 0.36, 23), tuft(0.12, 3.2, -0.08, 20, 0.3, 24),
  trunkMoss(2.2, 0.17, 0.3, 25))
for (const n of ["dead_pine_tall", "dead_pine", "dead_pine_short"]) looms(n)

// --- volcanic spikes and horns (2290-2295, 2297) -----------------------------
// angular spikes of glassy volcanic rock, leaning or curling, embers glowing
// round their feet (the halo of light round them goes to S37, VFX).
// A horn: segs five-sided sections chained, each narrower and bent a further
// `bend` degrees, the last one coming to a point; it stands at (u, v) in
// screen terms and leans `lean` degrees towards the screen's right (negative:
// left), turned `turn` degrees about its own axis
const horn = (u, v, len, r, lean, bend, seed, { segs = 4, turn = 0, y = 0 } = {}) => {
  const sl = len / segs
  const sec = (i) => i >= segs ? [] : tf({ pos: [0, i ? sl : 0, 0], rot: [0, 0, i ? -bend : 0] },
    lathe([r * (1 - i / segs) * 1.04, -0.01, r * (1 - (i + 1) / segs) + (i === segs - 1 ? 0 : 0.004), sl],
      { mat: i >= segs - 1 ? "hornD" : "horn", sides: 5, jitter: 0.01, seed: seed + i }), sec(i + 1))
  return tf({ pos: [(u + v) * R2, y, (v - u) * R2], rot: [0, 45, 0] }, tf({ rot: [0, turn, -lean] }, sec(0)))
}
// embers: glowing nuggets heaped round the foot, in screen terms; each spot
// is a little cluster of three
const embers = (spots, seed) => spots.flatMap(([u, v, r], i) => [0, 1, 2].map((k) => {
  const du = (rnd(i, 13 + k, seed) - 0.5) * r * 3, dv = (rnd(i, 17 + k, seed) - 0.5) * r * 2, rr = r * (1.4 - k * 0.3)
  return sphere(rr, { mat: "ember", detail: 0, pos: [(u + du + v + dv) * R2, rr * 0.4, (v + dv - u - du) * R2], scale: [1, 0.6, 1], jitter: 0.004, seed: seed + i * 3 + k })
}))

// volcanic spike (2291): one spike rising steeply to the right off a long
// thick foot, a lesser one behind it
const spikeParts = (seed) => [
  horn(-0.2, 0.05, 1.25, 0.24, 40, 5, seed),
  horn(0.0, -0.12, 0.8, 0.16, 30, 6, seed + 10, { turn: 30 }),
  embers([[-0.4, 0.2, 0.05], [0.1, 0.25, 0.04], [0.3, 0.1, 0.035], [-0.15, 0.3, 0.03]], seed + 20),
]
model("volcanic_spike", spikeParts(1))
// small volcanic spike (2292): the same, about half its size
model("volcanic_spike_small", tf({ scale: 0.55 }, spikeParts(31)))
// low volcanic spikes (2290): three spikes slanting to the right, side by side
model("volcanic_spikes_low",
  horn(-0.35, 0.0, 0.75, 0.16, 46, 4, 41), horn(-0.05, 0.1, 0.95, 0.18, 40, 5, 45),
  horn(0.2, -0.08, 1.1, 0.18, 30, 6, 49, { turn: 20 }),
  embers([[-0.5, 0.2, 0.04], [-0.1, 0.32, 0.035], [0.35, 0.2, 0.04], [0.05, 0.25, 0.03]], 53))
// volcanic claws (2293): three curved claws, the outer one reaching far to
// the right
model("volcanic_claws",
  horn(-0.3, 0.0, 1.05, 0.12, -14, 12, 61), horn(-0.08, -0.05, 1.15, 0.12, -6, 12, 65),
  horn(0.0, 0.1, 1.6, 0.13, 30, 10, 69, { segs: 5 }), horn(-0.42, 0.12, 0.35, 0.08, -10, 0, 74),
  embers([[-0.5, 0.25, 0.05], [-0.2, 0.3, 0.04], [0.2, 0.3, 0.035], [0.5, 0.15, 0.03]], 76))
// volcanic palisade (2294): a cluster of straight spikes standing up
model("volcanic_palisade",
  [[-0.3, 0.0, 0.7, 0.07, -6], [-0.15, -0.1, 1.05, 0.08, -3], [0.0, 0.05, 0.6, 0.07, 4], [0.1, -0.12, 1.25, 0.09, 3],
   [0.25, 0.02, 0.85, 0.08, 6], [-0.05, 0.2, 0.45, 0.06, -4], [0.35, -0.15, 0.6, 0.07, 8]].map(([u, v, l, r, lean], i) =>
    horn(u, v, l, r, lean, 1, 81 + i * 3, { segs: 2 })),
  embers([[-0.35, 0.25, 0.05], [0.0, 0.3, 0.04], [0.3, 0.2, 0.04], [-0.15, 0.32, 0.03]], 110))
// volcanic horn (2295): one horn rising and curling over to the right, a
// stub at its foot
model("volcanic_horn",
  horn(0.0, 0.0, 1.7, 0.22, -12, 16, 121, { segs: 5 }), horn(-0.22, 0.12, 0.4, 0.09, -25, 0, 127),
  embers([[-0.3, 0.25, 0.05], [0.0, 0.3, 0.045], [0.25, 0.2, 0.04], [0.1, 0.35, 0.03]], 130))
// big volcanic horn (2297): a split foot of thick spikes, out of which a long
// horn climbs, curving to the right, about three metres
model("volcanic_horn_big",
  horn(-0.3, 0.05, 1.0, 0.24, -14, 4, 141), horn(0.25, 0.1, 0.9, 0.22, 16, 4, 145), horn(0.0, -0.15, 1.2, 0.26, 2, 0, 149),
  horn(0.02, -0.05, 2.4, 0.2, 6, 7, 153, { segs: 5, y: 0.9 }),
  embers([[-0.45, 0.25, 0.06], [-0.1, 0.35, 0.05], [0.3, 0.3, 0.05], [0.5, 0.1, 0.04], [0.1, 0.2, 0.035]], 160))
for (const n of ["volcanic_spike", "volcanic_spike_small", "volcanic_spikes_low", "volcanic_claws", "volcanic_palisade", "volcanic_horn", "volcanic_horn_big"]) looms(n)
