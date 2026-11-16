// S44: the menu figures of Pippop Arena, drawn in vex in the splash's style
// (flat paper-cutout fighters, heavy ink silhouette, three cel tones per
// material from one top-left light, a coral-tinted rim light). The heads,
// hair, faces, fists and paws are the splash's own code (splash.vx.js), so
// they are the same people; only the bodies are posed standing.
//   node <vex>/bin/vex.js build scene.vx.js
// Then pad.py crops each figure to 32 px of padding and adds the contact
// shadow (the game's layout convention: figure height = image height - 64).

const PAL = {
  k: "#1c2030",                                                 // style B ink
  cr: "#ff4d6d", cr0: "#d12d4e", cr2: "#ff8aa0", cr3: "#ffd3dc", // coral
  bg2: "#ffffff",
  // fighter A: the white-spiked elf
  s0: "#c4845c", s1: "#eab789", s2: "#f8d7b6", s3: "#fff0e0",   // skin
  w0: "#9fb0c8", w1: "#e3ebf5", w2: "#ffffff",                  // white hair
  t0: "#b3bbcf", t1: "#eef1f7", t2: "#ffffff",                  // the white coat
  r0: "#7d1a26", r1: "#c92a3a", r2: "#ef5d64", r3: "#ff9a98",   // red ornament
  g0: "#173d33", g1: "#2a6652", g2: "#3f8f72", g3: "#73bf9d",   // green
  o0: "#9a3a0c", o1: "#e8702a", o2: "#ffa44e", o3: "#ffd39a",   // orange
  b0: "#4a2d1a", b1: "#7a4e2c", b2: "#a9774a", b3: "#d1a06c",   // leather
  e0: "#1f5f6e",                                                // A's eyes
  bl: "#e07a7a",                                                // blush
  rm: "#ffc2cd",                                                // the rim light
  // the coach: orange hair, brown shirt, blue jeans, big paws
  h0: "#b8460e", h1: "#f07a22", h2: "#ffa23c", h3: "#ffd27a",
  n0: "#5a3418", n1: "#8a5a30", n2: "#b07c4a", n3: "#d9a86e",
  q0: "#b8893f", q1: "#e8c070", q2: "#f6dd9c", q3: "#fff3c4",   // tan / brass
  j0: "#16407a", j1: "#2a6ac4", j2: "#4b8fe6", j3: "#8dc0ff",   // jeans / armour blue
  f0: "#3e2210", f1: "#6a3f1f", f2: "#8f5a2e", f3: "#b98044",   // fur paws
  e1: "#8a4a12",
  // fighter B: the masked white suit
  u0: "#aeb9cc", u1: "#eef2f8", u2: "#ffffff",
  v0: "#146a6a", v1: "#2a9a98", v2: "#5fc9c3", v3: "#aef0ea",
  i0: "#0f4b50", i1: "#1e7d80", i2: "#3bb0ad",
  p1: "#d9aab8",
  // the doll: burlap and stitches
  d0: "#8f6b3e", d1: "#c9a066", d2: "#e6c48f", d3: "#fff0d0", st: "#4a2e16",
  // the clock minion: indigo skin, a brass clock face, yellow eyes
  m0: "#2e1f52", m1: "#4d3484", m2: "#7656bb", m3: "#b39ae8", ye: "#ffd35c", yd: "#c98a10",
  // the ghost
  gh: "#e0e2e9", gk: "#d0d3dc",
}
pal(PAL)

const EDGE = (sw = 2) => ({ fill: "none", stroke: "k", sw, join: "round" })
const INK = (w = 2, taper = 0.45) => ({ ink: { c: "k", w, taper, wobble: 0, vary: 0.25 } })
const sh = (pts, dx, dy) => pts.map((v, i) => v + (i % 2 ? dy : dx))
const S = (st, extra) => ({ ...extra, ...(typeof st === "string" ? { fill: st } : st) })

function cel(mk, [c0, c1, c2, cr], { sd = 5, hd = 6, rim = 0, hi = true } = {}) {
  const out = []
  if (rim > 0) { out.push(mk(0, 0, cr || c2)); out.push(clip(mk(-rim, -rim * 0.6, "k"), mk(0, 0, c0))) }
  else out.push(mk(0, 0, c0))
  out.push(clip(mk(-sd, -sd * 0.8, "k"), mk(0, 0, c1)))
  if (hi) out.push(clip(mk(-sd, -sd * 0.8, "k"), clip(mk(0, 0, "k"), mk(0, 0, c2), mk(hd, hd * 0.9, c1))))
  return out
}
function band(spine, width, cap = true) {
  const L = [], R = [], n = spine.length
  for (let i = 0; i < n; i++) {
    const [x, y] = spine[i]
    const [ax, ay] = spine[Math.max(0, i - 1)], [bx, by] = spine[Math.min(n - 1, i + 1)]
    let nx = -(by - ay), ny = bx - ax
    const m = Math.hypot(nx, ny) || 1
    nx /= m; ny /= m
    const w = width(i, i / (n - 1)) / 2
    L.push(x + nx * w, y + ny * w)
    R.unshift(x - nx * w, y - ny * w)
  }
  if (cap) {
    const [x, y] = spine[n - 1], [ax, ay] = spine[n - 2]
    const w = width(n - 1, 1) / 2, a0 = Math.atan2(y - ay, x - ax) + Math.PI / 2
    for (let j = 1; j < 6; j++) { const a = a0 - (Math.PI * j) / 6; L.push(x + w * Math.cos(a), y + w * Math.sin(a)) }
  }
  return [...L, ...R]
}
const part = (pts, ramp, opts = {}) => {
  const mk = (dx, dy, st) => blob(sh(pts, dx, dy), S(st, { smooth: opts.smooth ?? 1 }))
  return [...cel(mk, ramp, { sd: opts.sd || 5, hd: opts.hd || 6, rim: opts.rim ?? 1.6 }), mk(0, 0, S(EDGE(opts.sw || 2), { smooth: opts.smooth ?? 1 }))]
}
const spiky = (pts, ramp, opts = {}) => {
  const mk = (dx, dy, st) => poly(sh(pts, dx, dy), st)
  return [...cel(mk, ramp, { sd: opts.sd || 6, hd: opts.hd || 7, rim: opts.rim ?? 1.6 }), mk(0, 0, EDGE(opts.sw || 2))]
}
const eye = (cx, cy, rx, ry, iris, lx = 0.35, ly = 0.1, tilt = 0) => tf({ rot: tilt, origin: [cx, cy] },
  ellipse(cx, cy, rx, ry, "w2"),
  circle(cx + rx * lx, cy + ry * ly, ry * 0.72, iris), circle(cx + rx * lx, cy + ry * ly, ry * 0.42, "k"),
  circle(cx + rx * lx - ry * 0.3, cy + ry * ly - ry * 0.35, ry * 0.2, "w2"),
  ellipse(cx, cy, rx, ry, EDGE(1.6)),
  curve([cx - rx * 1.05, cy - ry * 0.2, cx, cy - ry * 1.15, cx + rx * 1.05, cy - ry * 0.35], INK(3, 0.25)),
)
function segpts(x1, y1, x2, y2, w1, w2) {
  const a = Math.atan2(y2 - y1, x2 - x1), pts = []
  for (let j = 0; j <= 8; j++) { const t = a - Math.PI / 2 - (Math.PI * j) / 8; pts.push(x1 + (w1 / 2) * Math.cos(t), y1 + (w1 / 2) * Math.sin(t)) }
  for (let j = 0; j <= 8; j++) { const t = a + Math.PI / 2 - (Math.PI * j) / 8; pts.push(x2 + (w2 / 2) * Math.cos(t), y2 + (w2 / 2) * Math.sin(t)) }
  return pts
}
const seg = (x1, y1, x2, y2, w1, w2, ramp, o = {}) => {
  const mk = (dx, dy, st) => poly(sh(segpts(x1, y1, x2, y2, w1, w2), dx, dy), st)
  const sd = o.sd || Math.max(4, Math.min(w1, w2) * 0.22)
  return [...cel(mk, ramp, { sd, hd: sd * 1.1, rim: o.rim ?? Math.max(1.4, sd * 0.25) }), mk(0, 0, EDGE(o.sw || 2.2))]
}
const crease = (x, y, dx, dy, w = 2) => curve([x - dx, y - dy, x, y, x + dx, y + dy], INK(w, 0.5))
const fist = (cx, cy, r, ramp, rot = 0, thumbSide = -1) => {
  const top = []
  for (let i = 0; i < 4; i++) { const x = cx - r * 0.72 + i * r * 0.48; top.push(x - r * 0.16, cy - r * 0.86, x + r * 0.1, cy - r * 1.0) }
  const P = [...top, cx + r * 0.95, cy - r * 0.6, cx + r * 1.0, cy + r * 0.2, cx + r * 0.7, cy + r * 0.9, cx, cy + r * 1.0, cx - r * 0.72, cy + r * 0.9, cx - r * 1.0, cy + r * 0.2, cx - r * 0.95, cy - r * 0.6]
  const mkf = (dx, dy, st) => blob(sh(P, dx, dy), S(st, { smooth: 0.5 }))
  const T = segpts(cx - r * 0.78, cy + r * 0.3, cx + r * 0.55, cy + r * 0.42, r * 0.5, r * 0.44)
  return tf({ rot, origin: [cx, cy], flip: thumbSide > 0 ? "x" : undefined },
    ...cel(mkf, ramp, { sd: r * 0.28, hd: r * 0.3, rim: r * 0.06 }),
    clip(mkf(0, 0, "k"),
      ...[0, 1, 2].map((i) => { const x = cx - r * 0.48 + i * r * 0.48; return curve([x, cy - r * 0.92, x + r * 0.03, cy - r * 0.5, x - r * 0.02, cy - r * 0.02], INK(r * 0.065, 0.45)) }),
      ...[0, 1, 2, 3].map((i) => { const x = cx - r * 0.72 + i * r * 0.48; return ellipse(x, cy - r * 0.74, r * 0.14, r * 0.09, { fill: ramp[2], opacity: 0.75 }) }),
      poly(T, ramp[1]), clip(poly(T, "k"), poly(sh(T, 0, r * 0.18), ramp[0]), poly(sh(T, -r * 0.08, -r * 0.3), ramp[2])),
      poly(T, EDGE(r * 0.06)),
      curve([cx + r * 0.3, cy + r * 0.22, cx + r * 0.52, cy + r * 0.44, cx + r * 0.34, cy + r * 0.64], INK(r * 0.05, 0.5)),
    ),
    mkf(0, 0, S(EDGE(2.4), { smooth: 0.5 })),
  )
}
const hand = (cx, cy, r, ramp, rot = 0) => tf({ rot, origin: [cx, cy] },
  ...seg(cx - r * 0.4, cy + r * 0.4, cx + r * 0.7, cy + r * 0.3, r * 0.5, r * 0.4, ramp, { sw: 2 }),
  ...[-0.55, -0.15, 0.25, 0.6].map((t) => seg(cx + r * 0.2, cy + t * r * 0.4, cx + r * 1.2, cy + t * r, r * 0.42, r * 0.36, ramp, { sw: 1.8 })),
  ...part([cx - r * 0.9, cy - r * 0.6, cx + r * 0.3, cy - r * 0.75, cx + r * 0.55, cy, cx + r * 0.3, cy + r * 0.75, cx - r * 0.6, cy + r * 0.7, cx - r * 1.0, cy + r * 0.1], ramp, { sd: r * 0.3, hd: r * 0.3, rim: r * 0.08, smooth: 0.7 }),
)
const neck = (x1, y1, x2, y2, w, ramp) => seg(x1, y1, x2, y2, w, w * 0.9, ramp, { sw: 2 })
// a big furry paw (the coach's feet), toes to the left or right
const paw = (pts, toes, ramp = C_FUR) => [
  ...part(pts, ramp, { sd: 11, hd: 11, rim: 2.2, smooth: 0.7 }),
  ...toes.map(([x, y]) => curve([x, y - 11, x + 2, y + 4], INK(2.4, 0.4))),
]

const SKIN = ["s0", "s1", "s2", "rm"], WHITE = ["w0", "w1", "w2", "rm"], GREEN = ["g1", "g2", "g3", "rm"]
const ORANGE = ["o1", "o2", "o3", "o3"], COAT = ["t0", "t1", "t2", "rm"], RED = ["r1", "r2", "r3", "r3"]
const C_JEANS = ["j1", "j2", "j3", "rm"], C_FUR = ["f1", "f2", "f3", "rm"], SHIRT = ["n1", "n2", "n3", "rm"]
const SUIT = ["u0", "u1", "u2", "rm"], TEAL = ["v1", "v2", "v3", "v3"]
const BRASS = ["q0", "q1", "q2", "q3"], BURLAP = ["d1", "d2", "d3", "rm"], INDIGO = ["m1", "m2", "m3", "rm"]

// ============================================================================
// Fighter A: the white-spiked elf. Head, ear, face and hair from the splash;
// standing, feet apart, one fist up by the cheek, the other on the hip.
// ============================================================================
const A_HEAD = [128, 60, 160, 66, 180, 90, 184, 120, 174, 150, 150, 168, 120, 168, 96, 152, 86, 122, 90, 90, 104, 68]
const A_HAIR = [100, 70, 72, 42, 96, 46, 92, 10, 118, 36, 130, 0, 142, 36, 170, 6, 168, 46, 198, 26, 190, 62, 214, 70, 186, 92, 168, 78, 146, 70, 120, 74]
const A_EAR = [98, 112, 60, 100, 22, 110, 58, 126, 98, 134]
const A_TORSO = [120, 180, 156, 176, 182, 186, 190, 220, 186, 256, 176, 290, 136, 296, 100, 290, 90, 256, 92, 220, 100, 190]
const A_BELT = [94, 276, 180, 276, 182, 296, 94, 296]
const A_BOOT_L = [78, 392, 122, 388, 134, 408, 128, 430, 96, 434, 66, 426, 60, 406]
const A_BOOT_R = [150, 388, 194, 392, 216, 412, 208, 432, 172, 434, 146, 426, 142, 406]
const headA = () => [
  ...part(A_HEAD, SKIN, { sd: 10, hd: 11, rim: 2 }),
  clip(blob(A_HEAD, "k"), ellipse(166, 132, 10, 6, { fill: "bl", opacity: 0.35 }), ellipse(104, 136, 10, 6, { fill: "bl", opacity: 0.3 }),
    blob([96, 74, 180, 74, 186, 100, 150, 96, 118, 104, 90, 100], { fill: "s0", opacity: 0.45 })),
  blob(A_HEAD, EDGE(2.2)),
  ...part(A_EAR, SKIN, { sd: 5, hd: 5, rim: 1.4, smooth: 0.4 }),
  clip(blob(A_EAR, { fill: "k", smooth: 0.4 }), blob([96, 120, 60, 112, 36, 116, 62, 128, 96, 132], { fill: "s0", opacity: 0.6, smooth: 0.4 })),
  eye(140, 124, 11, 9, "e0", 0.4, 0.05, -6), eye(170, 122, 9, 8, "e0", 0.35, 0.05, -6),
  curve([126, 106, 140, 102, 150, 108], INK(3.2, 0.3)), curve([160, 104, 172, 100, 182, 106], INK(3, 0.3)),
  curve([170, 140, 176, 146, 170, 150], INK(1.8, 0.5)),
  blob([132, 150, 150, 148, 174, 150, 170, 162, 150, 166, 134, 160], { fill: "k", smooth: 0.5 }),
  clip(blob([132, 150, 150, 148, 174, 150, 170, 162, 150, 166, 134, 160], { fill: "k", smooth: 0.5 }), rect(130, 146, 48, 9, "w2"), ellipse(152, 172, 12, 7, "r1")),
  ...spiky(A_HAIR, WHITE, { sd: 10, hd: 12, rim: 2 }),
  clip(poly(A_HAIR, "k"), ...[[104, 60, 112, 30], [136, 60, 134, 20], [164, 62, 174, 26], [184, 78, 200, 50]].map((l) => curve(l, { stroke: "w0", sw: 2, opacity: 0.6 }))),
]
sprite("_a", { w: 240, h: 436 },
  // back (his left) arm: raised, fist up by the cheek
  ...seg(174, 198, 212, 236, 32, 28, GREEN), ...seg(212, 236, 214, 196, 28, 24, GREEN),
  crease(212, 236, 5, -3),
  // legs: green leggings, orange knee pads and boots
  ...seg(116, 288, 108, 350, 42, 34, GREEN), ...seg(108, 350, 104, 400, 34, 30, GREEN),
  ...seg(158, 288, 166, 350, 42, 34, GREEN), ...seg(166, 350, 170, 400, 34, 30, GREEN),
  ...part(A_BOOT_L, ORANGE, { sd: 9, hd: 9, rim: 1.8, smooth: 0.6 }),
  ...part(A_BOOT_R, ORANGE, { sd: 9, hd: 9, rim: 1.8, smooth: 0.6 }),
  clip(blob(A_BOOT_L, { fill: "k", smooth: 0.6 }), rect(56, 420, 90, 20, { fill: "o0", opacity: 0.45 })),
  clip(blob(A_BOOT_R, { fill: "k", smooth: 0.6 }), rect(140, 420, 90, 20, { fill: "o0", opacity: 0.45 })),
  curve([70, 410, 96, 406, 122, 412], INK(1.8, 0.4)), curve([150, 410, 176, 406, 204, 414], INK(1.8, 0.4)),
  ...part([90, 334, 122, 332, 130, 352, 118, 370, 92, 370, 82, 352], ORANGE, { sd: 6, hd: 6, rim: 1.4 }),
  ...part([148, 332, 182, 334, 190, 354, 180, 370, 154, 370, 144, 352], ORANGE, { sd: 6, hd: 6, rim: 1.4 }),
  // neck, the white tunic with the red sash and the star
  ...neck(136, 150, 138, 188, 30, SKIN),
  ...part(A_TORSO, COAT, { sd: 10, hd: 11, rim: 2, smooth: 0.6 }),
  clip(blob(A_TORSO, { fill: "k", smooth: 0.6 }),
    poly([96, 190, 118, 184, 190, 276, 170, 292], "r1"), poly([104, 190, 116, 186, 182, 278, 176, 284], { fill: "r2", opacity: 0.7 }),
    poly([96, 190, 118, 184, 190, 276, 170, 292], EDGE(1.6)),
    blob([90, 250, 140, 246, 190, 258, 186, 292, 136, 298, 92, 292], { fill: "t0", opacity: 0.5 }),
  ),
  star(146, 236, 5, 22, 10, { fill: "r1", rot: 15 }),
  clip(star(146, 236, 5, 22, 10, { fill: "k", rot: 15 }), circle(138, 228, 10, "r2"), poly([124, 224, 174, 260, 174, 264, 124, 264], { fill: "r0", opacity: 0.4 })),
  star(146, 236, 5, 22, 10, { ...EDGE(1.6), rot: 15 }),
  circle(146, 236, 5, "o2"), circle(146, 236, 5, EDGE(1.2)),
  // belt
  poly(A_BELT, "b1"), clip(poly(A_BELT, "k"), poly(sh(A_BELT, 0, 10), "b0"), rect(94, 278, 90, 4, "b2")),
  rect(126, 274, 22, 24, { fill: "q1", r: 3 }), rect(126, 274, 22, 24, { ...EDGE(1.6), r: 3 }),
  poly(A_BELT, EDGE(1.8)),
  // front (his right) arm down, fist on the hip
  ...seg(104, 198, 82, 246, 32, 28, GREEN), ...seg(82, 246, 80, 288, 28, 24, GREEN),
  crease(82, 246, -4, -4),
  fist(78, 302, 17, SKIN, 10, -1),
  fist(214, 180, 17, SKIN, -15, 1),
  ...headA(),
)

// ============================================================================
// The coach: head, hair, grin, sleeves, fists and paws from the splash;
// standing square at us, fists loose at his sides.
// ============================================================================
const C_HEAD = [226, 86, 262, 84, 294, 104, 306, 140, 300, 180, 276, 210, 240, 218, 204, 204, 188, 170, 186, 132, 198, 102]
const C_HAIR = [200, 110, 150, 104, 184, 80, 142, 56, 196, 60, 180, 14, 230, 50, 258, 14, 272, 54, 322, 24, 300, 74, 352, 74, 316, 106, 312, 134, 292, 114, 258, 98, 224, 106]
const C_TORSO = [176, 236, 252, 222, 330, 236, 348, 292, 326, 350, 254, 366, 182, 350, 160, 292]
const C_BELT = [180, 340, 254, 358, 328, 340, 330, 358, 254, 378, 178, 358]
const C_PAW_L = [162, 494, 222, 480, 256, 500, 258, 538, 224, 556, 174, 552, 150, 524]
const C_PAW_R = [256, 494, 318, 480, 354, 500, 356, 538, 322, 556, 270, 552, 248, 524]
const headC = (grin = true) => [
  ...part(C_HEAD, SKIN, { sd: 12, hd: 12, rim: 2.2 }),
  clip(blob(C_HEAD, "k"), blob([186, 104, 306, 104, 310, 134, 280, 118, 244, 130, 212, 122, 186, 134], { fill: "s0", opacity: 0.45 }),
    ellipse(208, 178, 12, 7, { fill: "bl", opacity: 0.3 }), ellipse(284, 174, 12, 7, { fill: "bl", opacity: 0.3 })),
  blob(C_HEAD, EDGE(2.4)),
  ...part([298, 142, 330, 126, 352, 138, 326, 160, 298, 164], SKIN, { sd: 5, hd: 5, rim: 1.4, smooth: 0.4 }),
  ...part([194, 142, 162, 126, 140, 138, 166, 160, 194, 164], SKIN, { sd: 5, hd: 5, rim: 1.4, smooth: 0.4 }),
  eye(228, 158, 14, 11, "e1", 0.1, 0.15, 4), eye(274, 156, 13, 11, "e1", 0.05, 0.15, 4),
  ...[[228, 158, 14, 11, 4], [274, 156, 13, 11, 4]].map(([cx, cy, rx, ry, t]) => tf({ rot: t, origin: [cx, cy] },
    clip(ellipse(cx, cy, rx + 1, ry + 1, "k"), poly([cx - rx - 2, cy - ry - 3, cx + rx + 2, cy - ry - 3, cx + rx + 2, cy - ry * 0.35, cx - rx - 2, cy - ry * 0.05], "s1")),
    curve([cx - rx * 1.05, cy - ry * 0.1, cx, cy - ry * 0.45, cx + rx * 1.05, cy - ry * 0.4], INK(3.2, 0.25)))),
  curve([206, 140, 228, 136, 246, 146], INK(3.8, 0.3)), curve([256, 144, 276, 134, 294, 136], INK(3.6, 0.3)),
  curve([250, 172, 254, 182, 246, 186], INK(2, 0.5)),
  blob([214, 192, 248, 190, 286, 178, 282, 196, 250, 210, 218, 204], { fill: "k", smooth: 0.5 }),
  clip(blob([214, 192, 248, 190, 286, 178, 282, 196, 250, 210, 218, 204], { fill: "k", smooth: 0.5 }), poly([212, 190, 290, 176, 290, 186, 212, 198], "w2"), ellipse(250, 212, 22, 8, "r1")),
  curve([284, 176, 292, 172], INK(2.2, 0.5)),
  ...spiky(C_HAIR, ["h1", "h2", "h3", "rm"], { sd: 14, hd: 14, rim: 2.4 }),
  clip(poly(C_HAIR, "k"), ...[[190, 104, 186, 70], [224, 104, 214, 56], [252, 98, 258, 44], [286, 108, 300, 62], [306, 124, 334, 86]].map((l) => curve(l, { stroke: "h0", sw: 2.4, opacity: 0.6 }))),
]
sprite("_c", { w: 520, h: 560 },
  // legs: jeans, the big furry paws
  ...seg(218, 356, 214, 440, 72, 58, C_JEANS), ...seg(214, 440, 212, 508, 58, 50, C_JEANS),
  ...seg(292, 356, 300, 440, 72, 58, C_JEANS), ...seg(300, 440, 302, 508, 58, 50, C_JEANS),
  clip(poly(segpts(218, 356, 214, 440, 72, 58), "k"), curve([232, 380, 226, 430], { stroke: "j0", sw: 2.4, opacity: 0.45 })),
  clip(poly(segpts(292, 356, 300, 440, 72, 58), "k"), curve([282, 380, 290, 430], { stroke: "j0", sw: 2.4, opacity: 0.45 })),
  crease(214, 440, 8, 2), crease(300, 440, 8, -2),
  ...paw(C_PAW_L, [[176, 548], [200, 554], [224, 552]]), ...paw(C_PAW_R, [[270, 548], [294, 554], [318, 552]]),
  clip(blob(C_PAW_L, { fill: "k", smooth: 0.7 }), ...[[168, 508], [192, 498], [216, 496], [240, 506]].map(([x, y]) => curve([x, y, x - 4, y - 14], { stroke: "f0", sw: 2, opacity: 0.6 }))),
  clip(blob(C_PAW_R, { fill: "k", smooth: 0.7 }), ...[[262, 508], [286, 498], [312, 496], [338, 506]].map(([x, y]) => curve([x, y, x - 4, y - 14], { stroke: "f0", sw: 2, opacity: 0.6 }))),
  // arms, down and a little out, the big fists
  ...seg(186, 262, 166, 322, 54, 46, SKIN), ...seg(166, 322, 160, 372, 46, 42, SKIN),
  ...seg(324, 262, 346, 322, 54, 46, SKIN), ...seg(346, 322, 354, 372, 46, 42, SKIN),
  crease(166, 322, 6, 2), crease(346, 322, -6, 2),
  // neck, the brown shirt with the tan yoke, the collar, the belt
  ...neck(246, 200, 252, 240, 44, SKIN),
  ...part(C_TORSO, SHIRT, { sd: 13, hd: 13, rim: 2.4, smooth: 0.7 }),
  clip(blob(C_TORSO, { fill: "k", smooth: 0.7 }),
    blob([160, 230, 252, 214, 350, 232, 342, 268, 268, 284, 170, 272], { fill: "q1", smooth: 0.6 }),
    blob([170, 234, 252, 220, 340, 240, 332, 258, 268, 268, 178, 258], { fill: "q2", smooth: 0.6, opacity: 0.6 }),
    curve([164, 272, 268, 286, 344, 268], INK(2.2)),
    curve([262, 288, 258, 346], { stroke: "n0", sw: 2.4, opacity: 0.45 }),
    blob([252, 222, 300, 228, 280, 262, 252, 258, 230, 262, 210, 228], { fill: "q0", opacity: 0.35, smooth: 0.6 }),
  ),
  curve([226, 236, 252, 258, 280, 234], INK(2.4, 0.3)),
  ...part([168, 238, 206, 240, 218, 268, 196, 290, 166, 282, 156, 256], ["n1", "n2", "n3", "n3"], { sd: 7, hd: 7, rim: 1.6, smooth: 0.8 }),
  ...part([304, 240, 342, 238, 354, 256, 344, 282, 314, 290, 292, 268], ["n1", "n2", "n3", "n3"], { sd: 7, hd: 7, rim: 1.6, smooth: 0.8 }),
  blob(C_BELT, { fill: "j0", smooth: 0.5 }),
  clip(blob(C_BELT, { fill: "k", smooth: 0.5 }), blob([182, 340, 254, 356, 326, 340, 326, 346, 254, 366, 182, 348], { fill: "j1", smooth: 0.5 })),
  rect(240, 352, 28, 18, { fill: "q1", r: 3 }), rect(240, 352, 28, 18, { ...EDGE(1.6), r: 3 }),
  fist(158, 400, 31, SKIN, 8, -1), fist(356, 400, 31, SKIN, -8, 1),
  ...headC(),
)

// ============================================================================
// Fighter B: the masked white suit; head, mask, hair and eye from the splash.
// Standing, weight on one hip, a fist on the hip, the mane falling behind.
// ============================================================================
const B_HEAD = [206, 70, 236, 74, 254, 96, 258, 126, 248, 152, 226, 166, 200, 166, 180, 150, 172, 122, 176, 94, 188, 76]
const B_MASK = [184, 86, 200, 60, 226, 52, 252, 60, 266, 82, 258, 106, 236, 94, 216, 90, 200, 100]
const B_TORSO = [176, 184, 240, 180, 258, 200, 258, 260, 250, 300, 214, 306, 182, 298, 170, 262, 170, 210]
const B_BOOT_L = [160, 398, 204, 394, 214, 414, 208, 436, 178, 440, 150, 432, 144, 412]
const B_BOOT_R = [222, 394, 266, 398, 282, 414, 276, 436, 246, 440, 214, 432, 210, 412]
const lock = (spine, w0, w1 = 4) => {
  const mk = (dx, dy, st) => blob(sh(band(spine, (i, t) => w0 - (w0 - w1) * t), dx, dy), S(st, { smooth: 0.5 }))
  return [...cel(mk, WHITE, { sd: w0 * 0.25, hd: w0 * 0.3, rim: 1.6 }), mk(0, 0, S(EDGE(2), { smooth: 0.5 }))]
}
const headB = () => [
  ...part(B_HEAD, SKIN, { sd: 10, hd: 10, rim: 2 }),
  clip(blob(B_HEAD, "k"), blob([174, 90, 260, 90, 262, 114, 236, 106, 204, 108, 174, 114], { fill: "s0", opacity: 0.4 }), ellipse(196, 136, 9, 5, { fill: "p1", opacity: 0.4 })),
  blob(B_HEAD, EDGE(2.2)),
  ...part([252, 114, 280, 106, 296, 118, 274, 132, 252, 134], SKIN, { sd: 4, hd: 4, rim: 1.2, smooth: 0.4 }),
  eye(198, 122, 10, 8, "v1", -0.4, 0.05, 6),
  curve([184, 108, 198, 104, 210, 110], INK(2.8, 0.3)),
  curve([188, 138, 184, 144], INK(1.6, 0.5)),
  curve([190, 152, 202, 156, 214, 152], INK(2, 0.4)),
  ...spiky([200, 80, 232, 66, 254, 80, 252, 114, 246, 140, 234, 110, 222, 134, 214, 102], WHITE, { sd: 6, hd: 6, rim: 1.6 }),
  ...spiky(B_MASK, ["i1", "i2", "v2", "v3"], { sd: 6, hd: 6, rim: 1.8 }),
  clip(poly(B_MASK, "k"), circle(214, 78, 5, "k"), circle(240, 76, 5, "k"), curve([200, 92, 226, 84, 254, 92], { stroke: "i0", sw: 2, opacity: 0.6 })),
  ...spiky([186, 80, 170, 50, 196, 66, 204, 38, 222, 64, 240, 32, 246, 66, 270, 50, 260, 82], WHITE, { sd: 8, hd: 8, rim: 1.6 }),
]
const stripe = (x1, y1, x2, y2, w1, w2, sw) => clip(poly(segpts(x1, y1, x2, y2, w1, w2), "k"),
  curve([x1 + (x2 - x1) * 0.1, y1 + (y2 - y1) * 0.1, x2 - (x2 - x1) * 0.1, y2 - (y2 - y1) * 0.1], { stroke: "v1", sw }))
sprite("_b", { w: 340, h: 444 },
  // the mane, falling behind to her left
  ...lock([[236, 84], [282, 84], [304, 120], [296, 162]], 42, 8),
  ...lock([[240, 104], [284, 126], [294, 170], [282, 212]], 40, 8),
  ...lock([[236, 120], [264, 154], [266, 196], [252, 236]], 34, 6),
  // legs: the suit, teal stripes, teal boots
  ...seg(198, 300, 190, 356, 42, 34, SUIT), ...seg(190, 356, 188, 406, 34, 30, SUIT),
  ...seg(232, 300, 240, 356, 42, 34, SUIT), ...seg(240, 356, 244, 406, 34, 30, SUIT),
  stripe(198, 300, 190, 356, 42, 34, 5), stripe(232, 300, 240, 356, 42, 34, 5),
  stripe(190, 356, 188, 406, 34, 30, 4), stripe(240, 356, 244, 406, 34, 30, 4),
  ...part(B_BOOT_L, TEAL, { sd: 7, hd: 7, rim: 1.6, smooth: 0.6 }), ...part(B_BOOT_R, TEAL, { sd: 7, hd: 7, rim: 1.6, smooth: 0.6 }),
  clip(blob(B_BOOT_L, { fill: "k", smooth: 0.6 }), rect(140, 428, 90, 20, { fill: "v0", opacity: 0.45 })),
  clip(blob(B_BOOT_R, { fill: "k", smooth: 0.6 }), rect(206, 428, 90, 20, { fill: "v0", opacity: 0.45 })),
  // her left arm (viewer's right), hanging a little out, an open hand
  ...seg(250, 198, 272, 246, 30, 26, SUIT), ...seg(272, 246, 270, 290, 26, 22, SUIT),
  stripe(250, 198, 272, 246, 30, 26, 3.5), crease(272, 246, -4, -4),
  hand(272, 312, 19, SKIN, 95),
  // neck, the torso, the teal lines
  ...neck(208, 150, 212, 188, 30, SKIN),
  ...part(B_TORSO, SUIT, { sd: 10, hd: 10, rim: 2, smooth: 0.8 }),
  clip(blob(B_TORSO, { fill: "k", smooth: 0.8 }),
    curve([214, 184, 222, 240, 216, 304], { stroke: "v1", sw: 6 }), curve([214, 184, 222, 240, 216, 304], { stroke: "v2", sw: 2.2, opacity: 0.6 }),
    curve([170, 248, 214, 256, 258, 246], { stroke: "v1", sw: 4 }),
    curve([240, 196, 250, 222], { stroke: "v1", sw: 3 }), curve([188, 196, 180, 222], { stroke: "v1", sw: 3 }),
    blob([170, 180, 244, 176, 240, 202, 206, 208, 172, 206], { fill: "u0", opacity: 0.5, smooth: 0.6 }),
  ),
  // her right arm (viewer's left), the fist on the hip
  ...seg(180, 198, 144, 238, 30, 26, SUIT), ...seg(144, 238, 170, 262, 26, 22, SUIT),
  stripe(180, 198, 144, 238, 30, 26, 3.5), crease(144, 238, -4, 4),
  fist(180, 268, 15, SKIN, 60, -1),
  ...headB(),
)

// ============================================================================
// story_a: the stitched doll with the orange flowers, hopping on one foot,
// a stubby arm up: burlap, X eyes, a stitched grin, an orange patch.
// ============================================================================
const D_HEAD = [200, 40, 290, 70, 330, 150, 320, 240, 260, 300, 180, 306, 110, 270, 80, 190, 100, 100]
const D_BODY = [150, 290, 250, 290, 266, 360, 244, 404, 160, 404, 134, 360]
const stitchX = (x, y, s) => [curve([x - s, y - s, x + s, y + s], INK(4, 0.3)), curve([x + s, y - s, x - s, y + s], INK(4, 0.3))]
const stitches = (pts, n, len = 7) => Array.from({ length: n }, (_, i) => {
  const t = i / (n - 1), j = Math.min(pts.length - 2, Math.floor(t * (pts.length - 1)))
  const u = t * (pts.length - 1) - j, [ax, ay] = pts[j], [bx, by] = pts[j + 1]
  const x = ax + (bx - ax) * u, y = ay + (by - ay) * u, a = Math.atan2(by - ay, bx - ax) + Math.PI / 2
  return line([x - len * Math.cos(a), y - len * Math.sin(a), x + len * Math.cos(a), y + len * Math.sin(a)], { stroke: "st", sw: 3 })
})
const seam = (pts) => [curve(pts.flat(), { stroke: "st", sw: 2.5, opacity: 0.9 }), ...stitches(pts, Math.round(pts.length * 2.5))]
const flower = (cx, cy, r, rot = 0) => tf({ rot, origin: [cx, cy] },
  ...[0, 1, 2, 3, 4, 5].map((i) => { const a = (Math.PI * 2 * i) / 6 - Math.PI / 2; const px = cx + r * 0.55 * Math.cos(a), py = cy + r * 0.55 * Math.sin(a)
    return [...part([px + r * 0.5 * Math.cos(a), py + r * 0.5 * Math.sin(a), px + r * 0.32 * Math.cos(a + 1.1), py + r * 0.32 * Math.sin(a + 1.1), cx, cy, px + r * 0.32 * Math.cos(a - 1.1), py + r * 0.32 * Math.sin(a - 1.1)], ORANGE, { sd: r * 0.12, hd: r * 0.12, rim: 1.2, smooth: 0.5 })] }),
  circle(cx, cy, r * 0.22, "b1"), circle(cx, cy, r * 0.22, EDGE(1.6)),
)
sprite("_d", { w: 480, h: 470 }, tf({ x: 50, y: 6, rot: -8, origin: [200, 440] },
  // the back arm, out to the side; the legs
  ...seg(252, 310, 310, 342, 40, 32, BURLAP, { sw: 2.2 }), ...part([296, 322, 334, 328, 342, 352, 322, 368, 294, 360, 286, 340], BURLAP, { sd: 6, hd: 6, rim: 1.4 }),
  ...seg(172, 392, 166, 440, 40, 36, BURLAP, { sw: 2.2 }), ...part([134, 428, 188, 426, 198, 448, 180, 462, 140, 462, 124, 446], BURLAP, { sd: 7, hd: 7, rim: 1.4, smooth: 0.7 }),
  ...seg(228, 392, 254, 428, 40, 36, BURLAP, { sw: 2.2 }), ...part([236, 416, 290, 406, 304, 426, 292, 446, 252, 450, 232, 440], BURLAP, { sd: 7, hd: 7, rim: 1.4, smooth: 0.7 }),
  // the body, the orange patch, a seam
  ...part(D_BODY, BURLAP, { sd: 9, hd: 9, rim: 1.8, smooth: 0.7 }),
  clip(blob(D_BODY, { fill: "k", smooth: 0.7 }),
    blob([196, 336, 246, 330, 260, 366, 236, 392, 200, 386, 186, 360], { fill: "o1", smooth: 0.6 }),
    blob([204, 340, 240, 336, 250, 362, 232, 380, 206, 376, 196, 358], { fill: "o2", smooth: 0.6, opacity: 0.7 }),
    ...stitches([[196, 336], [246, 330], [260, 366], [236, 392], [200, 386], [186, 360], [196, 336]], 16, 5),
    ...seam([[150, 300], [172, 350], [168, 400]]),
  ),
  // the front arm up, waving
  ...seg(150, 316, 84, 282, 40, 32, BURLAP, { sw: 2.2 }), ...part([42, 252, 80, 250, 94, 274, 80, 298, 48, 298, 32, 276], BURLAP, { sd: 6, hd: 6, rim: 1.4 }),
  // the big head: stitched X eyes, a stitched grin, seams, a patch
  ...part(D_HEAD, BURLAP, { sd: 14, hd: 14, rim: 2.4, smooth: 0.9 }),
  clip(blob(D_HEAD, { fill: "k", smooth: 0.9 }),
    blob([228, 180, 290, 170, 318, 210, 300, 250, 250, 252, 222, 220], { fill: "d1", smooth: 0.6, opacity: 0.6 }),
    ...seam([[130, 60], [190, 130], [230, 230], [226, 300]]),
    ...seam([[290, 74], [280, 140], [310, 200]]),
    ellipse(140, 230, 14, 8, { fill: "bl", opacity: 0.3 }), ellipse(276, 228, 14, 8, { fill: "bl", opacity: 0.3 }),
  ),
  ...stitchX(150, 182, 18), ...stitchX(268, 178, 16),
  // a cheeky stitched grin: a curve with cross stitches and one button tooth
  curve([150, 250, 200, 282, 262, 256], INK(4.5, 0.3)),
  ...stitches([[150, 250], [200, 282], [262, 256]], 7, 7),
  rect(192, 272, 18, 14, { fill: "w2", r: 2 }), rect(192, 272, 18, 14, { ...EDGE(1.6), r: 2 }),
  // the flowers tied at the head, with a brown knot
  ...part([96, 96, 134, 84, 142, 104, 112, 120, 90, 114], ["b0", "b1", "b2", "b3"], { sd: 4, hd: 4, rim: 1.2, smooth: 0.5 }), flower(100, 62, 64, 10),
  ...part([268, 62, 304, 56, 314, 76, 290, 92, 262, 84], ["b0", "b1", "b2", "b3"], { sd: 4, hd: 4, rim: 1.2, smooth: 0.5 }), flower(300, 40, 56, -20),
))

// ============================================================================
// story_b: a minion of the Gran Reloj, replacing the chick: a round indigo
// imp with clock-hand horns, bat ears, a brass clock face on its belly, one
// big yellow eye and a squint, a fanged grin, a cog on its tail.
// ============================================================================
const M_BODY = [170, 40, 236, 58, 276, 124, 274, 210, 240, 272, 170, 288, 100, 272, 66, 210, 64, 124, 104, 58]
const cog = (cx, cy, r, n = 8) => {
  const pts = []
  for (let i = 0; i < n * 2; i++) { const a = (Math.PI * 2 * i) / (n * 2), rr = i % 2 ? r : r * 0.74; pts.push(cx + rr * Math.cos(a), cy + rr * Math.sin(a)) }
  return [...spiky(pts, BRASS, { sd: r * 0.3, hd: r * 0.3, rim: 1.2, sw: 1.8 }), circle(cx, cy, r * 0.25, "q0"), circle(cx, cy, r * 0.25, EDGE(1.4))]
}
sprite("_m", { w: 340, h: 340 },
  // the tail, curling up behind to a cog
  ...seg(236, 236, 290, 250, 18, 10, INDIGO, { sw: 2 }), ...seg(290, 250, 312, 214, 10, 8, INDIGO, { sw: 2 }), ...cog(316, 196, 22, 7),
  // the legs: stubby, clawed feet
  ...seg(138, 272, 126, 316, 34, 30, INDIGO, { sw: 2.2 }), ...seg(202, 272, 214, 316, 34, 30, INDIGO, { sw: 2.2 }),
  ...part([88, 308, 138, 304, 152, 322, 140, 336, 100, 338, 82, 326], INDIGO, { sd: 6, hd: 6, rim: 1.4, smooth: 0.6 }),
  ...part([196, 304, 246, 308, 260, 326, 244, 338, 206, 336, 190, 322], INDIGO, { sd: 6, hd: 6, rim: 1.4, smooth: 0.6 }),
  ...[[92, 334], [114, 338], [136, 336], [208, 336], [230, 338], [252, 334]].map(([x, y]) => curve([x, y - 10, x - 2, y + 2], INK(2, 0.5))),
  // the ears, bat-like
  ...spiky([86, 110, 30, 70, 50, 140, 92, 150], INDIGO, { sd: 8, hd: 8, rim: 1.4 }),
  ...spiky([254, 110, 312, 72, 294, 142, 252, 150], INDIGO, { sd: 8, hd: 8, rim: 1.4 }),
  clip(poly([86, 110, 30, 70, 50, 140, 92, 150], "k"), poly([84, 118, 50, 92, 60, 136, 88, 142], { fill: "m0", opacity: 0.5 })),
  clip(poly([254, 110, 312, 72, 294, 142, 252, 150], "k"), poly([256, 118, 290, 92, 282, 136, 254, 142], { fill: "m0", opacity: 0.5 })),
  // the arms: one up, pointing (bossy), one on the belly
  ...seg(96, 200, 56, 232, 30, 24, INDIGO, { sw: 2.2 }), ...part([32, 222, 70, 218, 80, 240, 66, 258, 36, 256, 22, 240], INDIGO, { sd: 6, hd: 6, rim: 1.4 }),
  ...seg(246, 190, 290, 150, 30, 24, INDIGO, { sw: 2.2 }), ...seg(290, 150, 300, 108, 24, 16, INDIGO, { sw: 2.2 }),
  ...part([278, 90, 304, 82, 318, 98, 310, 118, 290, 120, 276, 108], INDIGO, { sd: 5, hd: 5, rim: 1.2 }),
  curve([300, 90, 312, 74], INK(5, 0.6)),   // the pointing claw
  // the body, one pear shape: head and belly
  ...part(M_BODY, INDIGO, { sd: 14, hd: 14, rim: 2.4, smooth: 0.9 }),
  clip(blob(M_BODY, { fill: "k", smooth: 0.9 }), blob([80, 190, 170, 170, 262, 190, 258, 266, 170, 290, 84, 266], { fill: "m0", opacity: 0.35, smooth: 0.8 })),
  // the brass clock face on the belly
  circle(170, 216, 50, "q1"), clip(circle(170, 216, 50, "k"), circle(150, 198, 46, "q2"), circle(182, 236, 44, { fill: "q0", opacity: 0.5 }), circle(150, 198, 36, "q2")),
  circle(170, 216, 50, EDGE(2.4)), circle(170, 216, 42, { ...EDGE(1.4), opacity: 0.6 }),
  ...Array.from({ length: 12 }, (_, i) => { const a = (Math.PI * 2 * i) / 12; const l = i % 3 ? 5 : 9
    return line([170 + 38 * Math.cos(a), 216 + 38 * Math.sin(a), 170 + (38 - l) * Math.cos(a), 216 + (38 - l) * Math.sin(a)], { stroke: "k", sw: i % 3 ? 1.6 : 2.6 }) }),
  poly([170, 216, 164, 206, 170, 184, 176, 206], "k"), poly([170, 216, 162, 222, 140, 232, 166, 210], "k"), circle(170, 216, 4, "cr"),
  // the horns: two brass clock hands
  ...spiky([130, 52, 118, 6, 148, 40], BRASS, { sd: 5, hd: 5, rim: 1.2 }), ...spiky([206, 48, 236, 2, 224, 50], BRASS, { sd: 5, hd: 5, rim: 1.2 }),
  // the face: one big eye, one squint, a cheeky fanged grin
  ellipse(136, 108, 24, 26, "w2"), circle(142, 112, 14, "ye"), circle(144, 114, 8, "k"), circle(139, 107, 3.5, "w2"),
  ellipse(136, 108, 24, 26, EDGE(2)), curve([110, 92, 134, 80, 160, 90], INK(3.4, 0.3)),
  curve([186, 104, 206, 98, 226, 108], INK(4, 0.3)), curve([196, 112, 212, 110], { stroke: "ye", sw: 5 }), curve([190, 90, 216, 84], INK(3, 0.4)),
  blob([110, 140, 150, 136, 196, 128, 232, 128, 226, 156, 180, 172, 130, 166], { fill: "k", smooth: 0.6 }),
  clip(blob([110, 140, 150, 136, 196, 128, 232, 128, 226, 156, 180, 172, 130, 166], { fill: "k", smooth: 0.6 }),
    poly([106, 136, 236, 124, 236, 140, 106, 150], "w2"), ellipse(176, 176, 34, 14, "cr0"),
    poly([130, 146, 142, 166, 150, 144], "w2"), poly([196, 140, 206, 162, 214, 138], "w2")),
  curve([110, 140, 106, 134], INK(2, 0.5)), curve([232, 128, 240, 120], INK(2.4, 0.5)),
)

// ============================================================================
// tour: the armoured knight, a blue and gold helmet with a striped plume, a
// white face plate with a lit visor, pauldrons, gauntlets, big boots.
// ============================================================================
const K_HELM = [200, 48, 236, 54, 262, 80, 268, 118, 258, 150, 230, 164, 180, 164, 150, 150, 140, 118, 146, 80, 170, 56]
const K_PLATE = [182, 110, 258, 108, 262, 146, 234, 166, 184, 166, 170, 146]
const K_TORSO = [156, 196, 204, 186, 252, 196, 272, 250, 266, 320, 206, 334, 148, 320, 138, 250]
const K_BLUE = ["j1", "j2", "j3", "rm"], K_WHITE = ["t0", "t1", "t2", "rm"]
const K_BOOT_L = [132, 500, 182, 496, 196, 516, 190, 544, 158, 550, 112, 544, 102, 522]
const K_BOOT_R = [226, 496, 278, 500, 304, 522, 296, 546, 256, 550, 220, 544, 214, 518]
sprite("_k", { w: 420, h: 556 },
  // the plume: a striped tail rising from the helmet and falling back-left
  ...lock([[214, 64], [206, 20], [150, 2], [96, 30]], 40, 14),
  clip(blob(band([[214, 64], [206, 20], [150, 2], [96, 30]], (i, t) => 40 - 26 * t), { fill: "k", smooth: 0.5 }),
    ...[[196, 10], [168, 0], [136, 2], [110, 16]].map(([x, y]) => curve([x - 10, y - 20, x + 6, y + 30], { stroke: "b1", sw: 11 }))),
  // legs: blue greaves, white knee plates, the big boots
  ...seg(180, 326, 170, 420, 60, 50, K_BLUE), ...seg(170, 420, 166, 506, 50, 46, K_BLUE),
  ...seg(234, 326, 244, 420, 60, 50, K_BLUE), ...seg(244, 420, 248, 506, 50, 46, K_BLUE),
  ...part([142, 404, 196, 402, 204, 428, 192, 448, 150, 448, 136, 428], K_WHITE, { sd: 7, hd: 7, rim: 1.6 }),
  ...part([218, 402, 272, 404, 280, 428, 266, 448, 224, 448, 212, 428], K_WHITE, { sd: 7, hd: 7, rim: 1.6 }),
  ...part(K_BOOT_L, K_BLUE, { sd: 10, hd: 10, rim: 2, smooth: 0.6 }), ...part(K_BOOT_R, K_BLUE, { sd: 10, hd: 10, rim: 2, smooth: 0.6 }),
  clip(blob(K_BOOT_L, { fill: "k", smooth: 0.6 }), rect(96, 536, 110, 20, { fill: "j0", opacity: 0.6 }), curve([108, 510, 150, 504, 192, 512], { stroke: "q1", sw: 6 })),
  clip(blob(K_BOOT_R, { fill: "k", smooth: 0.6 }), rect(206, 536, 110, 20, { fill: "j0", opacity: 0.6 }), curve([222, 508, 262, 504, 300, 514], { stroke: "q1", sw: 6 })),
  // arms: blue vambraces, white pauldrons, gauntlets as fists
  ...seg(164, 220, 136, 290, 44, 38, K_BLUE), ...seg(136, 290, 128, 350, 38, 34, K_BLUE),
  ...seg(248, 220, 278, 290, 44, 38, K_BLUE), ...seg(278, 290, 288, 350, 38, 34, K_BLUE),
  ...part([112, 334, 150, 332, 158, 360, 146, 386, 112, 388, 98, 362], ["j0", "j1", "j2", "rm"], { sd: 7, hd: 7, rim: 1.6, smooth: 0.6 }),
  ...part([270, 332, 310, 334, 322, 362, 308, 388, 274, 386, 262, 360], ["j0", "j1", "j2", "rm"], { sd: 7, hd: 7, rim: 1.6, smooth: 0.6 }),
  curve([116, 366, 150, 364], INK(1.8)), curve([270, 366, 306, 364], INK(1.8)),
  // the torso: blue cuirass with a gold trim and a sun emblem, the belt
  ...part(K_TORSO, K_BLUE, { sd: 12, hd: 12, rim: 2.2, smooth: 0.6 }),
  clip(blob(K_TORSO, { fill: "k", smooth: 0.6 }),
    curve([140, 250, 206, 262, 270, 250], { stroke: "q1", sw: 5 }), curve([206, 186, 206, 332], { stroke: "j0", sw: 2.4, opacity: 0.4 }),
    blob([150, 196, 262, 196, 266, 230, 206, 246, 146, 230], { fill: "t1", smooth: 0.5 }), curve([146, 232, 206, 248, 266, 232], INK(2)),
  ),
  circle(206, 290, 16, "q1"), clip(circle(206, 290, 16, "k"), circle(200, 284, 12, "q2")), circle(206, 290, 16, EDGE(1.8)), circle(206, 290, 6, "j1"),
  blob([142, 312, 206, 326, 270, 312, 270, 332, 206, 346, 142, 332], { fill: "b1", smooth: 0.5 }), blob([142, 312, 206, 326, 270, 312, 270, 332, 206, 346, 142, 332], { ...EDGE(1.8), smooth: 0.5 }),
  rect(192, 318, 28, 22, { fill: "q1", r: 3 }), rect(192, 318, 28, 22, { ...EDGE(1.6), r: 3 }),
  ...part([126, 190, 176, 182, 192, 206, 178, 234, 136, 236, 116, 214], K_WHITE, { sd: 8, hd: 8, rim: 1.8, smooth: 0.6 }),
  ...part([232, 182, 284, 190, 296, 214, 276, 236, 234, 234, 220, 206], K_WHITE, { sd: 8, hd: 8, rim: 1.8, smooth: 0.6 }),
  clip(blob([126, 190, 176, 182, 192, 206, 178, 234, 136, 236, 116, 214], { fill: "k", smooth: 0.6 }), curve([124, 222, 160, 230, 184, 222], { stroke: "q1", sw: 5 })),
  clip(blob([232, 182, 284, 190, 296, 214, 276, 236, 234, 234, 220, 206], { fill: "k", smooth: 0.6 }), curve([228, 222, 256, 230, 292, 222], { stroke: "q1", sw: 5 })),
  // the neck guard, the helmet: blue dome, gold brow, white face plate, the visor slit with a lit eye
  ...seg(206, 150, 206, 196, 56, 60, ["j0", "j1", "j2", "rm"]),
  ...part(K_PLATE, K_WHITE, { sd: 8, hd: 8, rim: 1.8, smooth: 0.4 }),
  blob([180, 126, 260, 124, 258, 140, 182, 142], { fill: "i0", smooth: 0.3 }),
  circle(232, 133, 7, { fill: "ye", glow: { r: 6, color: "ye" } }), circle(232, 133, 3.5, "bg2"),
  blob([180, 126, 260, 124, 258, 140, 182, 142], { ...EDGE(1.8), smooth: 0.3 }),
  ...part(K_HELM, K_BLUE, { sd: 12, hd: 12, rim: 2.2, smooth: 0.8 }),
  clip(blob(K_HELM, { fill: "k", smooth: 0.8 }),
    blob([178, 108, 262, 106, 268, 124, 170, 126], { fill: "q1", smooth: 0.3 }), blob([178, 108, 262, 106, 268, 124, 170, 126], { ...EDGE(1.6), smooth: 0.3 }),
    rect(166, 124, 100, 60, { fill: "w2", opacity: 0 }),
    curve([206, 50, 206, 108], { stroke: "q1", sw: 5 }),
  ),
  clip(blob(K_HELM, { fill: "k", smooth: 0.8 }), poly([160, 120, 280, 120, 280, 170, 160, 170], { fill: "k", opacity: 0 })),
  // the face plate shows under the brow: re-draw it over the helmet's lower part
  ...part(K_PLATE, K_WHITE, { sd: 8, hd: 8, rim: 1.8, smooth: 0.4 }),
  blob([180, 126, 260, 124, 258, 140, 182, 142], { fill: "i0", smooth: 0.3 }),
  circle(232, 133, 7, { fill: "ye", glow: { r: 6, color: "ye" } }), circle(232, 133, 3.5, "bg2"),
  blob([180, 126, 260, 124, 258, 140, 182, 142], { ...EDGE(1.8), smooth: 0.3 }),
  ...[150, 158].map((y) => curve([188, y, 206, y + 3, 230, y], INK(1.8, 0.4))),
)

// ============================================================================
// The exports: each figure scaled to ~600 px high in a roomy box with the
// splash's heavy outline; pad.py crops to the 32 px convention afterwards.
// ============================================================================
const OW = 5
const fig = (name, partName, scale, w = 520, h = 760) => sprite(name, { w, h, outline: "k", ow: OW }, stamp(partName, w / 2, h - 60, { anchor: "bottom", scale }))
fig("fighter_a", "_a", 1.39)
fig("coach", "_c", 1.155, 600, 760)
fig("fighter_b", "_b", 1.47)
fig("story_a", "_d", 1.4, 640, 760)
fig("story_b", "_m", 1.76, 640, 760)
fig("tour", "_k", 1.08, 520, 760)
// the ghost: the coach in two greys, softened; the game draws it at 55 %
const GHOST = Object.fromEntries(Object.keys(PAL).map((k) => [k, k === "k" ? "gk" : "gh"]))
sprite("coach_ghost", { w: 600, h: 760 }, tf({ blur: 8 }, stamp("coach", 300, 760, { anchor: "bottom", swap: GHOST })))
