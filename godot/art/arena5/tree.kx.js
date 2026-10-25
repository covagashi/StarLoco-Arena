// Snowy tree (3D, kiln), built from what the retail piece showed: a broad old
// stump in two faceted masses, thin gnarled limbs out of the top, big round
// snow clumps on the broken tops and limb ends. No snow skirt at the foot.
// "snow*" materials get smoothed normals in build_tile.gd; the bark keeps its
// facets, like the planes of the retail trunk.
include("block.kx.js")
pal({
  bark: { tex: "out/bark_paint", uv: 0.45, color: "#cfcab0", rough: 0.9 },
  barkD: { tex: "out/bark_paint", uv: 0.45, color: "#a19d84", rough: 0.9 },
  snowT: { tex: "out/snow_paint", uv: 0.5, rough: 0.9 },
})

// a limb that thins as it goes: one tube per segment, radius stepping down
function limb(pts, r0, r1, mat = "barkD") {
  const n = pts.length / 3 - 1, out = []
  for (let i = 0; i < n; i++) {
    const r = r0 + (r1 - r0) * (i / Math.max(1, n - 1))
    out.push(tube(pts.slice(i * 3, i * 3 + 6), r, { mat, sides: 6 }))
    if (i < n - 1) out.push(sphere(r, { mat, detail: 1, pos: pts.slice(i * 3 + 3, i * 3 + 6) }))
  }
  return out
}
// a cap of snow sitting on a broken top or a limb end: flattened, lumpy,
// spilling a couple of thin drips over its rim
const clump = (x, y, z, r) => [
  sphere(r, { mat: "snowT", detail: 3, pos: [x, y, z], scale: [1.1, 0.55, 1.1] }),
  sphere(r * 0.55, { mat: "snowT", detail: 2, pos: [x - r * 0.35, y + r * 0.22, z - r * 0.2], scale: [1, 0.7, 1] }),
  sphere(r * 0.22, { mat: "snowT", detail: 2, pos: [x + r * 0.62, y - r * 0.45, z + r * 0.6], scale: [0.8, 1.9, 0.8] }),
  sphere(r * 0.17, { mat: "snowT", detail: 2, pos: [x - r * 0.75, y - r * 0.4, z + r * 0.45], scale: [0.8, 1.7, 0.8] }),
]

model("tree",
  // back mass: tall, leaning a little, broken top
  lathe([0.4, 0, 0.33, 0.12, 0.27, 0.45, 0.23, 0.85, 0.21, 1.12, 0.14, 1.16, 0, 1.17],
    { mat: "bark", sides: 7, pos: [-0.1, 0, -0.1], rot: [0, 10, -4], jitter: 0.035, seed: 3 }),
  // front mass: lower and wider, standing against the first
  lathe([0.44, 0, 0.36, 0.1, 0.3, 0.35, 0.27, 0.6, 0.18, 0.65, 0, 0.66],
    { mat: "bark", sides: 7, pos: [0.14, 0, 0.13], rot: [0, 30, 3], jitter: 0.035, seed: 8 }),
  // roots spreading into the ground
  [[0.42, 0, 0.0, 30], [-0.38, 0, 0.12, -40], [0.05, 0, 0.45, 80], [-0.15, 0, -0.38, 200]].map(([x, y, z, ry]) =>
    cone(0.12, 0.42, { mat: "barkD", sides: 5, pos: [x * 0.7, 0.02, z * 0.7], rot: [0, ry, -72], jitter: 0.02 })),
  // limbs: thin, gnarled, climbing out of the tops
  limb([-0.15, 0.95, -0.12, -0.35, 1.12, -0.1, -0.52, 1.18, -0.05, -0.66, 1.32, -0.02], 0.07, 0.03),
  limb([-0.42, 1.14, -0.08, -0.45, 1.3, -0.2, -0.4, 1.42, -0.28], 0.035, 0.02),
  limb([-0.05, 1.08, -0.1, 0.02, 1.3, -0.15, 0.06, 1.5, -0.12], 0.065, 0.028),
  limb([0.22, 0.58, 0.18, 0.4, 0.75, 0.25, 0.48, 0.92, 0.2], 0.065, 0.03),
  limb([0.3, 0.45, 0.1, 0.55, 0.52, 0.0, 0.78, 0.6, -0.05], 0.065, 0.028),
  limb([0.6, 0.54, 0.0, 0.66, 0.66, -0.1], 0.03, 0.018),
  // snow: the broken tops and the limb ends
  clump(-0.1, 1.17, -0.1, 0.21), clump(0.14, 0.67, 0.13, 0.29),
  clump(-0.68, 1.34, -0.02, 0.08), clump(0.06, 1.52, -0.12, 0.075), clump(0.5, 0.94, 0.2, 0.075),
  clump(0.8, 0.61, -0.05, 0.07),
)

// the tree standing on the ice block (block top ~0.86)
model("tree_on_block", stamp("ice_block"), stamp("tree", { pos: [0, 0.84, 0], scale: 0.95 }))
