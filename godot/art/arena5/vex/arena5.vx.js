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
  l0: "#55548c", l1: "#8b8ac2", l2: "#c4c3ec", l3: "#f4f3ff",
  // bark (pale, grey-green)
  t0: "#5d5b46", t1: "#8f8d6f", t2: "#bdbb9b", t3: "#e2e0c6",
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
// a tall lilac shard with softer shards around it, inner planes painted in
sprite("ice_spike", { w: 48, h: 110, scale: 4 },
  ellipse(24, 102, 20, 5, { fill: "#14305e33", blur: 2.5 }),
  blob([10, 98, 7, 80, 12, 74, 15, 88, 18, 98], { smooth: 0.3, fill: "l1", shade: lit({ depth: 0.4 }), ink: ink("l0", 1) }),
  blob([30, 98, 33, 70, 38, 62, 40, 78, 38, 98], { smooth: 0.3, fill: "l1", shade: lit({ depth: 0.4 }), ink: ink("l0", 1) }),
  // the main shard: narrow tip, a kink half way, wide foot
  blob([24, 8, 26, 20, 30, 44, 33, 62, 35, 80, 36, 98, 12, 98, 13, 82, 17, 60, 18, 46, 21, 24], { smooth: 0.28, fill: "l2", shade: lit({ depth: 0.42, rim: "l3", brush: 0.3 }), ink: ink("l0", 1.2) }),
  clip(blob([24, 8, 26, 20, 30, 44, 33, 62, 35, 80, 36, 98, 12, 98, 13, 82, 17, 60, 18, 46, 21, 24], { smooth: 0.28, fill: "l2" }),
    blob([25, 30, 29, 46, 31, 70, 27, 86, 24, 64], { smooth: 0.5, fill: "l1", opacity: 0.7 }),
    blob([20, 52, 24, 58, 23, 84, 17, 92, 16, 74], { smooth: 0.5, fill: "l3", opacity: 0.55, blur: 0.8 }),
    blob([28, 76, 33, 84, 32, 96, 27, 96], { smooth: 0.5, fill: "l0", opacity: 0.35 })),
  circle(24, 9, 2.2, { fill: "l3", glow: { r: 4, color: "l3" } }),
  // snow at the foot
  blob([2, 100, 8, 93, 16, 95, 24, 91, 32, 95, 41, 93, 46, 100, 36, 104, 12, 104], { smooth: 0.8, fill: "s2", shade: lit({ c: "s1", rim: "s3", depth: 0.4 }), ink: ink("s0", 1.1) }),
)

// ---------------------------------------------------------------- snowy tree
// a stout, crooked pale trunk, short thick limbs, big snow clumps on the ends
const clump = (x, y, r) => blob([x - r, y + r * 0.2, x - r * 0.7, y - r * 0.6, x - r * 0.1, y - r * 0.85, x + r * 0.6, y - r * 0.7,
  x + r, y, x + r * 0.5, y + r * 0.55, x + r * 0.1, y + r * 0.85, x - r * 0.5, y + r * 0.5], { smooth: 0.9, fill: "s2", shade: lit({ c: "s1", rim: "s3", depth: 0.3, brush: 0.2 }), ink: ink("s0", 1) })
const limb = (pts) => blob(pts, { smooth: 0.55, fill: "t2", shade: lit({ depth: 0.45, rim: "t3" }), ink: ink("t0", 1.1) })

sprite("snow_tree", { w: 80, h: 100, scale: 4 },
  ellipse(40, 93, 26, 6, { fill: "#14305e33", blur: 2.5 }),
  // limbs behind the trunk
  limb([30, 44, 18, 34, 10, 24, 13, 21, 22, 30, 33, 37]),
  limb([46, 40, 52, 26, 56, 16, 60, 18, 57, 30, 50, 44]),
  // trunk
  blob([22, 92, 25, 76, 27, 60, 25, 44, 24, 30, 30, 18, 38, 18, 41, 30, 44, 46, 47, 62, 52, 78, 58, 92],
    { smooth: 0.55, fill: "t2", shade: lit({ depth: 0.5, rim: "t3", brush: 0.45 }), ink: ink("t0", 1.4) }),
  // bark strokes
  curve([34, 84, 33, 72, 35, 60], { ink: { c: "t1", w: 0.9, taper: 0.5 } }),
  curve([40, 52, 39, 42, 41, 34], { ink: { c: "t1", w: 0.8, taper: 0.5 } }),
  // limbs in front
  limb([44, 62, 56, 56, 66, 50, 70, 53, 60, 60, 47, 68]),
  limb([28, 66, 18, 60, 12, 62, 13, 58, 20, 55, 30, 59]),
  // snow: on the broken top, the limb ends and the forks
  clump(34, 18, 9), clump(11, 21, 5.5), clump(58, 15, 5.5), clump(70, 51, 5), clump(12, 58, 4.5), clump(46, 41, 6),
  // snow and ice at the foot
  blob([10, 94, 16, 86, 26, 88, 40, 84, 54, 88, 66, 86, 72, 94, 58, 99, 22, 99], { smooth: 0.8, fill: "s2", shade: lit({ c: "s1", rim: "s3", depth: 0.4 }), ink: ink("s0", 1.1) }),
)
