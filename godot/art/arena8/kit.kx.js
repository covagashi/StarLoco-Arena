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
])))
const SKINNED = ["softPumice", "softPumiceL"]
const looms = (name) => threeLooms(name, SKINNED)

// a rounded floor stone placed in screen terms: u along the screen's
// horizontal (world (1, 0, -1)), v towards the camera (world (1, 0, 1));
// ru its half length along u, rv along v, h its half thickness, a a small
// extra turn (degrees). A squashed sphere, a little lumpy.
const R2 = Math.SQRT1_2
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
