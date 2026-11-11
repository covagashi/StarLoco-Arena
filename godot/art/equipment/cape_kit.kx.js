// S35c: the shape every cape is built from (capes.kx.js, coach_capes.kx.js),
// included once by kit.kx.js before them. A cape is a few flat strips round
// a cylinder so it wraps the back; the hem is shaped per cape.
const CapeKit = (() => {
  const T = 0.02   // cloth thickness
  // The cape body: n strips round a cylinder of radius r (its axis in front,
  // at z = r), w0 across at the top and w1 at the bottom, len long; hem(u)
  // lifts the bottom edge at u (-0.5..0.5 across) and mat(i) colours strip i.
  function cape({ len = 0.6, w0 = 0.34, w1 = 0.46, n = 5, r = 0.24, hem = () => 0, mat, steps = 3 }) {
    const a0 = w0 / r / n, out = []
    for (let i = 0; i < n; i++) {
      const phi = (i - (n - 1) / 2) * a0
      const t0 = w0 / n / 2, t1 = (w1 / n / 2) * 1.04
      const pts = [-t0, 0, t0, 0]
      for (let k = 0; k <= steps; k++) {
        const s = 1 - k / steps, x = -t1 + 2 * t1 * s
        const u = (i + s) / n - 0.5
        pts.push(x, -len + hem(u))
      }
      out.push(tf({ pos: [r * Math.sin(phi), 0, r - r * Math.cos(phi)], rot: [0, -phi * 180 / Math.PI, 0] },
        extrude(pts, T, { mat: typeof mat === "function" ? mat(i) : mat, pos: [0, 0, -T] })))
    }
    return out
  }
  // an item placed on the cape's outer side at u (-0.5..0.5 across) and y
  // (0 at the collar, -len at the hem), facing out (-Z)
  function on(u, y, items, { w0 = 0.34, w1 = 0.46, len = 0.6, r = 0.24, lift = 0.006 } = {}) {
    const phi = (u * w0) / r
    const k = 1 + ((w1 / w0 - 1) * -y) / len   // the strips widen downwards
    const x = r * Math.sin(phi) * k, z = r - r * Math.cos(phi)
    return tf({ pos: [x, y, z - T - lift], rot: [0, -phi * 180 / Math.PI, 0] }, items)
  }
  const back = (tilt, ...items) => tf({ rot: [tilt, 0, 0] }, ...items)
  const collar = (mat, w = 0.3) => box(w, 0.035, 0.05, { mat, pos: [0, -0.02, -0.01] })
  return { cape, on, back, collar }
})()
