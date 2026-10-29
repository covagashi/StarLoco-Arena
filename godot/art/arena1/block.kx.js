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

// a soft rounded block body: rounded-square prisms stacked so its sides
// swell out in the middle and pull in at the foot and the top, as the
// retail draws its blocks; rows: [y, half, corner r] from the foot up
const swell = (rows, mat, wave = 0.02, seed = 1) => rows.slice(0, -1).map(([y0, h0, r0], i) => {
  const [y1] = rows[i + 1]
  return prism(roundSquare(h0, r0, 5, wave, seed + i), y1 - y0 + 0.004, y0, mat, 0.008)
})
// lumps of snow rolling over a block's rim, n per side
const rimLumps = (y, half, n, r, seed, mat = "snow") => [0, 1, 2, 3].flatMap((side) => Array.from({ length: n }, (_, i) => {
  const t = -half * 0.8 + (i + 0.5) * (1.6 * half / n) + (((side * 7 + i * 3 + seed) % 5) - 2) * 0.012
  const [x, z] = [[t, half], [half, -t], [-t, -half], [-half, t]][side]
  const k = 0.8 + ((side * 5 + i * 7 + seed) % 5) * 0.1
  return sphere(r * k, { mat, detail: 1, pos: [x, y - r * 0.15 * k, z], scale: [1.25, 0.75, 1.25] })
}))
// ice block (153): a block of ice a little over a metre, its faceted sides
// swelling out, a thick lumpy snow cap overhanging the rim, drips down the
// sides
const HB = 0.8
model("ice_block",
  swell([[0, 0.45, 0.1], [0.3, 0.5, 0.12], [HB, 0.49, 0.12]], "ice", 0.03, 3),
  terrain(2 * CAP, 2 * CAP, { res: 40, height: 0.34, fn: cushion, mat: "snow", pos: [0, HB - 0.1, 0] }),
  rimLumps(HB + 0.07, 0.45, 3, 0.17, 2),
  tf({ pos: [0, HB - H + 0.04, 0] }, drips))
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
// arena's foot; their textures have no top or foot band, so they stack
pal({
  iceCol: { tex: "out/ice_col", uv: 1, rough: 0.25 },
  iceClearCol: { tex: "out/ice_clear_col", uv: 1, rough: 0.15 },
})
model("ice_col", prism(roundSquare(HALF, 0.07), 1, 0, "iceCol", 0.004))
model("ice_clear_col", prism(roundSquare(HALF, 0.07), 1, 0, "iceClearCol", 0.004))
