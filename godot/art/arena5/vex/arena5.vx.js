// Arena 5 (Entrenamiento), painted with vex: soft organic shapes, painted
// form shadows from one light, a thin line in each material's own dark tone
// (never black), like the retail art. Units = game pixels: a cell is 86 wide,
// its top diamond 43 tall. Exported at 4x.
pal({
  // ice body
  c0: "#2a5596", c1: "#4f92cc", c2: "#8ccbec", c3: "#d4f1fb",
  // snow
  s0: "#5f79a6", s1: "#a9bdd9", s2: "#e3ecf6", s3: "#ffffff",
  // lilac ice (the spike)
  l0: "#6e6aa6", l1: "#a9a6d6", l2: "#dcd9f3", l3: "#f8f7ff",
  // bark (pale, grey-green)
  t0: "#5e5a43", t1: "#8e896a", t2: "#c2bc98", t3: "#e4dfc2",
})
ramps("c0 c1 c2 c3", "s0 s1 s2 s3", "l0 l1 l2 l3", "t0 t1 t2 t3")

const LIGHT = 315
const ink = (c, w = 1.3) => ({ c, w, light: LIGHT, wobble: 0.45, vary: 0.4 })
const lit = (x = {}) => ({ light: LIGHT, brush: 0.2, ...x })

// ---------------------------------------------------------------- ice block
const CX = 50, TY = 16, HW = 43, HH = 21.5, H = 37
const T = [CX, TY], R = [CX + HW, TY + HH], B = [CX, TY + 2 * HH], L = [CX - HW, TY + HH]
const at = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t]
const down = (p, d) => [p[0], p[1] + d]
const flat = (...ps) => ps.flat()
// a flat [x, y, x, y, ...] list walked backwards, keeping each x before its y
const back = (a) => a.flatMap((_, i) => (i % 2 ? [] : [a[a.length - 2 - i], a[a.length - 1 - i]]))

// the front lip of the snow: walk L -> B -> R, dropping drips of chosen lengths
function lip(drips) {
  const out = []
  const edge = (a, b, list) => list.forEach(([t, len]) => {
    // shoulder, side, round tip (two points), side, shoulder
    out.push(...down(at(a, b, t - 0.05), 3.5), ...down(at(a, b, t - 0.028), 3.5 + len * 0.65),
      ...down(at(a, b, t - 0.01), 3.5 + len), ...down(at(a, b, t + 0.01), 3.5 + len),
      ...down(at(a, b, t + 0.028), 3.5 + len * 0.65), ...down(at(a, b, t + 0.05), 3.5))
  })
  edge(L, B, drips[0])
  out.push(...down(B, 4.5))
  edge(B, R, drips[1])
  return out
}
const DRIPS = [[[0.12, 3], [0.3, 7], [0.47, 2.5], [0.66, 9], [0.86, 4]], [[0.14, 5], [0.34, 8.5], [0.53, 3], [0.72, 6.5], [0.9, 3.5]]]

sprite("ice_block", { w: 100, h: 100, scale: 4 },
  ellipse(CX, 92, 40, 8, { fill: "#14305e33", blur: 3 }),
  // left face lit, right face in shadow
  blob(flat(L, B, down(B, H), down(L, H)), { smooth: 0.12, fill: "c2", shade: lit({ c: "c1", depth: 0.4, rim: "c3" }), ink: ink("c0", 1.3) }),
  blob(flat(B, R, down(R, H), down(B, H)), { smooth: 0.12, fill: "c1", shade: lit({ c: "c0", depth: 0.35 }), ink: ink("c0", 1.4) }),
  // deep foot of the ice, wavy where it meets the lighter body
  clip(poly(flat(L, B, R, down(R, H), down(B, H), down(L, H)), "c2"),
    blob([L[0] - 4, L[1] + H * 0.68, 22, L[1] + H * 0.76, B[0] - 6, B[1] + H * 0.7, B[0] + 14, B[1] + H * 0.62,
      R[0] + 4, R[1] + H * 0.66, R[0] + 4, R[1] + H + 6, B[0], B[1] + H + 6, L[0] - 4, L[1] + H + 6], { smooth: 0.6, fill: "c0", opacity: 0.4 }),
    // light trapped in the ice
    blob([16, 46, 22, 44, 24, 64, 18, 70, 14, 60], { fill: "c3", opacity: 0.45, blur: 1.2 }),
    blob([36, 58, 40, 57, 40, 74, 36, 77], { fill: "c3", opacity: 0.35, blur: 1 }),
    blob([66, 52, 70, 50, 71, 64, 67, 67], { fill: "c3", opacity: 0.25, blur: 1 }),
    line([B[0], B[1] + 2, B[0], B[1] + H - 3], { stroke: "c3", sw: 1.1, opacity: 0.6, blur: 0.4 })),
  // the snow: one soft mass over the top, spilling over the front edges
  ...snowCap(),
)

function snowCap() {
  // several points along the back edges so the smoothing keeps them straight
  const pts = [L[0] - 2, L[1] - 1, ...[0.2, 0.45, 0.7, 0.9].flatMap((t) => down(at(L, T, t), -1)), T[0], T[1] - 1.5,
    ...[0.1, 0.3, 0.55, 0.8].flatMap((t) => down(at(T, R, t), -1)), R[0] + 2, R[1] - 1, ...back(lip(DRIPS))]
  return [
    blob(pts, { smooth: 0.75, fill: "s2", shade: lit({ c: "s1", depth: 0.22, rim: "s3", brush: 0.25 }), ink: ink("s0", 1.2) }),
    // soft light on the snow, kept inside it
    clip(blob(pts, { smooth: 0.75, fill: "s2" }), blob([28, 24, 44, 19, 56, 22, 46, 29, 32, 30], { fill: "s3", opacity: 0.8, blur: 2.2 })),
  ]
}

// ---------------------------------------------------------------- ice spike
// big planes: a lit face almost white, a lilac shadow face, a darker lens in
// the middle; small shards at the foot, snow lumps caught on its edges
const MAIN = [32, 8, 36, 30, 42, 58, 46, 86, 50, 118, 14, 118, 18, 90, 22, 62, 27, 34]
sprite("ice_spike", { w: 64, h: 130, scale: 4 },
  ellipse(32, 122, 26, 6, { fill: "#14305e33", blur: 2.5 }),
  blob([12, 118, 9, 98, 15, 84, 21, 100, 24, 118], { smooth: 0.2, fill: "l1", shade: lit({ c: "l0", depth: 0.4 }), ink: ink("l0", 1) }),
  blob(MAIN, { smooth: 0.18, fill: "l2", shade: lit({ c: "l1", depth: 0.3, rim: "l3", brush: 0.15 }), ink: ink("l0", 1.2) }),
  clip(blob(MAIN, { smooth: 0.18, fill: "l2" }),
    blob([27, 34, 32, 10, 33, 42, 28, 80, 20, 106, 17, 92, 22, 62], { smooth: 0.25, fill: "l3", opacity: 0.95 }),
    blob([35, 36, 42, 58, 46, 86, 50, 118, 38, 118, 37, 80, 33, 50], { smooth: 0.25, fill: "l1", opacity: 0.9 }),
    blob([30, 58, 36, 70, 37, 96, 31, 106, 27, 86], { smooth: 0.5, fill: "l0", opacity: 0.45 }),
    blob([31, 64, 34, 72, 34, 90, 31, 96, 29, 84], { smooth: 0.5, fill: "l1", opacity: 0.6 })),
  blob([42, 118, 45, 98, 52, 86, 55, 104, 53, 118], { smooth: 0.2, fill: "l2", shade: lit({ c: "l1", depth: 0.35, rim: "l3" }), ink: ink("l0", 1) }),
  // a glint at the tip
  circle(32, 9, 2.3, { fill: "l3", glow: { r: 4, color: "l3" } }),
  skirt(32, 121, 27),
)

// ---------------------------------------------------------------- snowy tree
// a broad old stump in two masses split by vertical planes, thin gnarled
// limbs climbing out of the top, big round snow clumps that drip over the
// edges, a skirt of snow and ice at the foot
const BACK = [22, 114, 28, 104, 31, 86, 33, 62, 36, 40, 45, 31, 57, 31, 62, 42, 64, 70, 66, 100, 68, 114]
const FRONT = [42, 118, 49, 108, 51, 94, 56, 78, 66, 67, 82, 66, 90, 76, 93, 94, 96, 108, 104, 118]
const bark = (pts) => blob(pts, { smooth: 0.45, fill: "t2", shade: lit({ c: "t1", depth: 0.42, rim: "t3", brush: 0.4 }), ink: ink("t0", 1.3) })
const planes = (mask, lightPts, darkPts) => clip(blob(mask, { smooth: 0.45, fill: "t2" }),
  blob(lightPts, { smooth: 0.4, fill: "t3", opacity: 0.55 }), blob(darkPts, { smooth: 0.4, fill: "t0", opacity: 0.35 }))
// a gnarled limb: dark body, a lighter top line; tapering
const twig = (pts, w) => [curve(pts, { ink: { c: "t0", w: w * 1.6 + 1.4, taper: 0.45, wobble: 0.5 } }),
  curve(pts, { ink: { c: "t1", w: w * 1.3, taper: 0.45, wobble: 0.4 } }),
  curve(pts.map((v, i) => v - 0.7), { ink: { c: "t3", w: w * 0.45, taper: 0.5, wobble: 0.3 } })]

sprite("snow_tree", { w: 124, h: 132, scale: 4 },
  ellipse(62, 121, 46, 8, { fill: "#14305e33", blur: 3 }),
  // limbs behind the stump
  twig([38, 52, 26, 45, 15, 41, 6, 34], 2.4), twig([24, 45, 20, 36, 22, 28], 1.4),
  twig([55, 35, 61, 22, 64, 10], 2.2), twig([61, 22, 68, 17, 74, 18], 1.3),
  bark(BACK),
  planes(BACK, [37, 46, 44, 38, 46, 88, 40, 106, 35, 90], [56, 38, 61, 46, 63, 96, 58, 106, 55, 70]),
  twig([66, 68, 70, 54, 70, 40], 2), twig([70, 52, 76, 46], 1.2),
  bark(FRONT),
  planes(FRONT, [58, 86, 66, 73, 71, 75, 64, 112, 56, 114], [84, 72, 91, 80, 92, 112, 85, 114, 82, 90]),
  twig([82, 70, 87, 57, 88, 44], 2.2), twig([91, 84, 102, 81, 113, 76], 2), twig([102, 81, 106, 88], 1.2),
  // snow
  clumpD(47, 29, 12, 9), clumpD(73, 63, 15, 12), clumpD(35, 74, 7, 5.5),
  clumpD(64, 8, 5.5, 5), clumpD(88, 41, 5.5, 5), clumpD(114, 74, 5, 4.5), clumpD(6, 32, 4.6, 4.2),
  skirt(62, 118, 46),
)

// a round snow clump whose lower edge drips: [x, y] centre, radius, how far it hangs
function clumpD(x, y, r, hang) {
  const pts = []
  for (let i = 0; i < 28; i++) {
    const a = (i / 28) * Math.PI * 2, below = Math.max(0, Math.sin(a))
    const drip = below * (0.2 + 0.5 * Math.max(0, Math.sin(a * 4 + x)) ** 2)
    pts.push(x + Math.cos(a) * r * (1 + 0.06 * Math.sin(a * 5 + y)), y + Math.sin(a) * r * 0.8 + drip * hang)
  }
  return [blob(pts, { smooth: 0.85, fill: "s2", shade: lit({ c: "s1", depth: 0.35, rim: "s3", brush: 0.15 }), ink: ink("s0", 1) }),
    clip(blob(pts, { smooth: 0.85, fill: "s2" }), ellipse(x - r * 0.3, y - r * 0.35, r * 0.45, r * 0.3, { fill: "s3", opacity: 0.85, blur: r * 0.15 }))]
}
// snow and ice skirt at the foot: an icy blue rim showing under ragged snow
function skirt(x, y, r) {
  const ragged = (k, dy) => Array.from({ length: 22 }, (_, i) => {
    const a = (i / 22) * Math.PI * 2, rr = r * (1 + 0.1 * Math.sin(a * 5 + k))
    return [x + Math.cos(a) * rr, y + Math.sin(a) * rr * 0.17 + dy + (Math.sin(a) > 0 ? 1.5 * Math.abs(Math.sin(a * 5 + k)) : -1.2 * Math.abs(Math.sin(a * 3 + k)))]
  }).flat()
  return [blob(ragged(2, 2.5), { smooth: 0.6, fill: "c2", shade: lit({ c: "c1", depth: 0.5 }), ink: ink("c0", 1) }),
    blob(ragged(5, 0), { smooth: 0.7, fill: "s2", shade: lit({ c: "s1", depth: 0.3, rim: "s3" }), ink: ink("s0", 1.1) })]
}
