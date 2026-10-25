// Shared shapes for every biome kit (M7, S36). 1 m = one cell; a ground
// block is about 0.85 m tall; columns are 1 m bodies stacked under it.
//   include("../common/shapes.kx.js")

const CELL_HALF = 0.48   // a block body's half width (just inside the cell)

// rounded-square outline (XY, for extrude), corner radius r; `wave` wobbles it
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

// vertical prism from an XY outline, base on y, h tall
const prismUp = (pts, h, y, mat, jitter = 0) =>
  extrude(pts, h, { mat, rot: [90, 0, 0], pos: [0, y + h / 2, 0], jitter })

// a cushion over a square top: 0 at the rim, 1 inside, soft lumps (amp 0..1)
function cushionFn(half, r = 0.12, edge = 0.06, lumps = 0.25, seed = 1) {
  return (x, z) => {
    const a = half - r
    const qx = Math.abs(x) - a, qz = Math.abs(z) - a
    const dist = Math.hypot(Math.max(qx, 0), Math.max(qz, 0)) + Math.min(Math.max(qx, qz), 0) - r
    const e = Math.min(1, Math.max(0, -dist / edge))
    const lip = e * e * (3 - 2 * e)
    const lump = 0.5 + 0.5 * Math.sin(x * 9 + seed) * Math.sin(z * 8 + seed * 1.7)
    return lip * (1 - lumps + lumps * lump)
  }
}

// a ground block: body + a cap terrain (grass, sand, snow, moss...)
//   top = where it is walked on (m); body mat; cap mat; capH = cap bulge
function groundBlock(bodyMat, capMat, { h = 0.75, capH = 0.12, lumps = 0.25, seed = 1, jitter = 0.004 } = {}) {
  return [
    prismUp(roundSquare(CELL_HALF, 0.07), h, 0, bodyMat, jitter),
    terrain(2 * (CELL_HALF - 0.01), 2 * (CELL_HALF - 0.01),
      { res: 32, height: capH, fn: cushionFn(CELL_HALF - 0.01, 0.12, 0.06, lumps, seed), mat: capMat, pos: [0, h - 0.04, 0] }),
  ]
}

// the b and c looms of a piece: same model, every listed material swapped
// for <mat>_b / <mat>_c (define those in the palette)
function threeLooms(name, mats) {
  for (const s of ["_b", "_c"])
    model(name + s, { base: name, swap: Object.fromEntries(mats.map((m) => [m, m + s])) })
}
