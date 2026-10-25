// Hero ice block (3D version): one cell (1 m), faceted ice body, soft snow
// cap with drips. Snow parts use the "snow" material: build_tile.gd smooths
// their normals. The painted version is paint/ice_block.mjs.
pal({
  ice: { tex: "out/ice_body", uv: 0.75, rough: 0.25 },
  snow: { tex: "out/snow_soft", uv: 0.9, rough: 0.9 },
})

const H = 0.75        // ice body height
const HALF = 0.48     // body half width
const TAU = Math.PI * 2

// rounded-square outline (XY, for extrude), corner radius r
function roundSquare(half, r, seg = 4, wave = 0, seed = 1) {
  const pts = []
  const cs = [[1, 1], [-1, 1], [-1, -1], [1, -1]]
  cs.forEach(([sx, sy], c) => {
    for (let i = 0; i <= seg; i++) {
      const a = (c * 90 + (i / seg) * 90) * Math.PI / 180
      let x = sx * (half - r) + Math.cos(a) * r, y = sy * (half - r) + Math.sin(a) * r
      if (wave) {
        const k = 1 + wave * Math.sin(a * 3 + seed + c * 1.7)
        x *= k; y *= k
      }
      pts.push(x, y)
    }
  })
  return pts
}

// vertical prism from an XY outline: extrude along Z, then stand it up
const prism = (pts, h, y, mat, jitter = 0) =>
  extrude(pts, h, { mat, rot: [90, 0, 0], pos: [0, y + h / 2, 0], jitter })   // extrude is centred on its depth

// a drip of snow spilling over the edge: wide where it leaves the cap, a
// rounded tip below, flattened against the side
const drip = (x, z, len, r, faceRot) => lathe(
  [0, -len, r * 0.55, -len * 0.9, r * 0.85, -len * 0.62, r, -len * 0.3, r * 1.15, 0, r * 1.1, 0.05, 0, 0.07],
  { mat: "snow", sides: 10, pos: [x, H + 0.04, z], rot: [0, faceRot, 0], scale: [1, 1, 0.55] })

// cushion height 0..1: rounded-square falloff to the edge, soft lumps on top
const CAP = 0.47   // just inside the body: the flat rim stays hidden under the ice
function cushion(x, z) {
  const r = 0.13, a = CAP - r
  const qx = Math.abs(x) - a, qz = Math.abs(z) - a
  const dist = Math.hypot(Math.max(qx, 0), Math.max(qz, 0)) + Math.min(Math.max(qx, qz), 0) - r
  const e = Math.min(1, Math.max(0, -dist / 0.055))
  const lip = e * e * (3 - 2 * e)
  const lump = 0.5 + 0.5 * Math.sin(x * 9 + 1.3) * Math.sin(z * 8 + 2.1)
  return lip * (0.72 + 0.28 * lump)
}

// drips per side: [offset along the side, length, radius]
const D = [[-0.4, 0.08, 0.06], [-0.27, 0.15, 0.07], [-0.12, 0.07, 0.065], [0.02, 0.21, 0.08],
  [0.17, 0.09, 0.06], [0.3, 0.13, 0.07], [0.42, 0.06, 0.055]]
const drips = [0, 90, 180, 270].map((rot, s) => tf({ rot: [0, rot, 0] },
  D.map(([o, len, r], i) => drip(o + ((s * 13 + i * 7) % 5 - 2) * 0.015, HALF + 0.025,
    len * (0.8 + ((s * 5 + i * 3) % 4) * 0.12), r, 0))))

model("ice_block",
  prism(roundSquare(HALF, 0.07), H, 0, "ice", 0.004),
  // the cap: one cushion of snow, rounding down to a lip over the body edge
  terrain(2 * CAP, 2 * CAP, { res: 48, height: 0.3, fn: cushion, mat: "snow", pos: [0, H - 0.12, 0] }),
  drips)

// clear ice block (retail 154, also replaces 155 and 156): the same body as
// ice_block without the snow, standing as tall as the snow-capped one, with
// a lighter top bevelled in from the edge
pal({
  iceClear: { tex: "out/ice_clear", uv: 0.86, rough: 0.15 },
  iceClearTop: { tex: "out/ice_clear_top", uv: 0.9, rough: 0.12 },
})
const HC = 0.84   // body height: the snow cap of ice_block peaks about here
// a low rounded bevel over the top, like ice worn smooth (cushion's lip, no lumps)
function bevel(x, z) {
  const r = 0.1, a = HALF - r
  const qx = Math.abs(x) - a, qz = Math.abs(z) - a
  const dist = Math.hypot(Math.max(qx, 0), Math.max(qz, 0)) + Math.min(Math.max(qx, qz), 0) - r
  const e = Math.min(1, Math.max(0, -dist / 0.09))
  return e * e * (3 - 2 * e)
}
model("ice_clear",
  prism(roundSquare(HALF, 0.07), HC, 0, "iceClear", 0.004),
  terrain(2 * HALF, 2 * HALF, { res: 40, height: 0.05, fn: bevel, mat: "iceClearTop", pos: [0, HC - 0.005, 0] }))

// columns: the bare bodies, 1 m tall, stacked under a block down to the
// arena's foot (build_arena.gd scales the last one)
model("ice_col", prism(roundSquare(HALF, 0.07), 1, 0, "ice", 0.004))
model("ice_clear_col", prism(roundSquare(HALF, 0.07), 1, 0, "iceClear", 0.004))
