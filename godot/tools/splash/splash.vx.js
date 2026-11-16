// S44: the Pippop Arena splash / loading screen, 1280 x 720, drawn in vex.
// Style B backdrop (light grey-lavender, a coral band, thin technical lines, a
// ghost word, the "PPA //" code tag), the logo in condensed ink with the coral
// accent, and three of the game's fighters in an action composition, each
// finished like the Nilo portrait: heavy ink silhouette, lighter inner ink,
// three cel tones per material from one top-left light, a rim light on the
// shadow side. The band y 600-700 stays calm for the progress bar.
//   node <vex>/bin/vex.js build splash.vx.js --only splash --scales 1,2

pal({
  k: "#1c2030",                                                 // style B ink
  cr: "#ff4d6d", cr0: "#d12d4e", cr2: "#ff8aa0", cr3: "#ffd3dc", // coral
  bg0: "#dfe2ea", bg1: "#eceef3", bg2: "#ffffff",               // the backdrop
  mu: "#6b7183", fa: "#9aa0b0",                                  // mute, faint
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
  rm: "#ffc2cd",                                                // the rim light, tinted by the coral band
  // the brawler: orange hair, brown shirt, blue jeans, big paws
  h0: "#b8460e", h1: "#f07a22", h2: "#ffa23c", h3: "#ffd27a",   // orange hair
  n0: "#5a3418", n1: "#8a5a30", n2: "#b07c4a", n3: "#d9a86e",   // brown shirt
  q0: "#b8893f", q1: "#e8c070", q2: "#f6dd9c",                  // the shirt's tan yoke
  j0: "#16407a", j1: "#2a6ac4", j2: "#4b8fe6", j3: "#8dc0ff",   // jeans
  f0: "#3e2210", f1: "#6a3f1f", f2: "#8f5a2e", f3: "#b98044",   // fur paws
  e1: "#8a4a12",                                                // brawler's eyes
  // fighter B: the masked white suit
  u0: "#aeb9cc", u1: "#eef2f8", u2: "#ffffff",                  // suit
  v0: "#146a6a", v1: "#2a9a98", v2: "#5fc9c3", v3: "#aef0ea",   // teal
  i0: "#0f4b50", i1: "#1e7d80", i2: "#3bb0ad",                  // the mask (dark teal)
  p1: "#d9aab8",                                                // B's lips/blush
  // the chick
  y0: "#c98f10", y1: "#ffcf2e", y2: "#ffe878", y3: "#fff7c4",
})

const LIGHT = 315
const EDGE = (sw = 2) => ({ fill: "none", stroke: "k", sw, join: "round" })
const INK = (w = 2, taper = 0.45) => ({ ink: { c: "k", w, taper, wobble: 0, vary: 0.25 } })
const sh = (pts, dx, dy) => pts.map((v, i) => v + (i % 2 ? dy : dx))
const S = (st, extra) => ({ ...extra, ...(typeof st === "string" ? { fill: st } : st) })

// cel shading from one shape factory mk(dx, dy, style): base, a shadow
// crescent away from the light, a light crescent toward it, a rim light just
// inside the shadow edge; all clipped to the shape.
function cel(mk, [c0, c1, c2, cr], { sd = 5, hd = 6, rim = 0, hi = true } = {}) {
  const out = []
  if (rim > 0) { out.push(mk(0, 0, cr || c2)); out.push(clip(mk(-rim, -rim * 0.6, "k"), mk(0, 0, c0))) }
  else out.push(mk(0, 0, c0))
  out.push(clip(mk(-sd, -sd * 0.8, "k"), mk(0, 0, c1)))
  if (hi) out.push(clip(mk(-sd, -sd * 0.8, "k"), clip(mk(0, 0, "k"), mk(0, 0, c2), mk(hd, hd * 0.9, c1))))
  return out
}

// a tapered band along a spine of [x, y] with a width per index → one polygon
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
// a limb: a band from spine points, cel shaded, inner edge
const limb = (spine, wfn, ramp, opts = {}) => {
  const mk = (dx, dy, st) => poly(sh(band(spine, wfn, opts.cap !== false), dx, dy), st)
  return [...cel(mk, ramp, { sd: opts.sd || 5, hd: opts.hd || 6, rim: opts.rim ?? 1.6 }), mk(0, 0, EDGE(opts.sw || 2))]
}
// a smooth blob, cel shaded, with its edge
const part = (pts, ramp, opts = {}) => {
  const mk = (dx, dy, st) => blob(sh(pts, dx, dy), S(st, { smooth: opts.smooth ?? 1 }))
  return [...cel(mk, ramp, { sd: opts.sd || 5, hd: opts.hd || 6, rim: opts.rim ?? 1.6 }), mk(0, 0, S(EDGE(opts.sw || 2), { smooth: opts.smooth ?? 1 }))]
}
// a polygon (spiky hair), cel shaded, with its edge
const spiky = (pts, ramp, opts = {}) => {
  const mk = (dx, dy, st) => poly(sh(pts, dx, dy), st)
  return [...cel(mk, ramp, { sd: opts.sd || 6, hd: opts.hd || 7, rim: opts.rim ?? 1.6 }), mk(0, 0, EDGE(opts.sw || 2))]
}
// an eye looking toward (lx, ly): white, iris, pupil, a spark; a heavy lid
const eye = (cx, cy, rx, ry, iris, lx = 0.35, ly = 0.1, tilt = 0) => tf({ rot: tilt, origin: [cx, cy] },
  ellipse(cx, cy, rx, ry, "w2"),
  circle(cx + rx * lx, cy + ry * ly, ry * 0.72, iris), circle(cx + rx * lx, cy + ry * ly, ry * 0.42, "k"),
  circle(cx + rx * lx - ry * 0.3, cy + ry * ly - ry * 0.35, ry * 0.2, "w2"),
  ellipse(cx, cy, rx, ry, EDGE(1.6)),
  curve([cx - rx * 1.05, cy - ry * 0.2, cx, cy - ry * 1.15, cx + rx * 1.05, cy - ry * 0.35], INK(3, 0.25)),
)

// a tapered segment between two points with round caps at both ends
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
// a crease at a joint: a short ink tick on the inside of the bend
const crease = (x, y, dx, dy, w = 2) => curve([x - dx, y - dy, x, y, x + dx, y + dy], INK(w, 0.5))

// a frontal fist: four knuckles along the top, the thumb lying across the lower half
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
      curve([cx + r * 0.3, cy + r * 0.22, cx + r * 0.52, cy + r * 0.44, cx + r * 0.34, cy + r * 0.64], INK(r * 0.05, 0.5)),   // the thumb's tip
    ),
    mkf(0, 0, S(EDGE(2.4), { smooth: 0.5 })),
  )
}
// an open hand: a palm blob and three or four finger segments
const hand = (cx, cy, r, ramp, rot = 0) => tf({ rot, origin: [cx, cy] },
  ...seg(cx - r * 0.4, cy + r * 0.4, cx + r * 0.7, cy + r * 0.3, r * 0.5, r * 0.4, ramp, { sw: 2 }),      // thumb
  ...[-0.55, -0.15, 0.25, 0.6].map((t) => seg(cx + r * 0.2, cy + t * r * 0.4, cx + r * 1.2, cy + t * r, r * 0.42, r * 0.36, ramp, { sw: 1.8 })),
  ...part([cx - r * 0.9, cy - r * 0.6, cx + r * 0.3, cy - r * 0.75, cx + r * 0.55, cy, cx + r * 0.3, cy + r * 0.75, cx - r * 0.6, cy + r * 0.7, cx - r * 1.0, cy + r * 0.1], ramp, { sd: r * 0.3, hd: r * 0.3, rim: r * 0.08, smooth: 0.7 }),
)
// a head with a neck: the neck first (under), then the face blob
const neck = (x1, y1, x2, y2, w, ramp) => seg(x1, y1, x2, y2, w, w * 0.9, ramp, { sw: 2 })

// ============================================================================
// Fighter A: the white-spiked elf, a flying kick to the right. Box 380 x 400.
// ============================================================================
const A_HEAD = [128, 60, 160, 66, 180, 90, 184, 120, 174, 150, 150, 168, 120, 168, 96, 152, 86, 122, 90, 90, 104, 68]
const A_HAIR = [100, 70, 72, 42, 96, 46, 92, 10, 118, 36, 130, 0, 142, 36, 170, 6, 168, 46, 198, 26, 190, 62, 214, 70, 186, 92, 168, 78, 146, 70, 120, 74]
const A_TORSO = [146, 160, 176, 150, 214, 142, 240, 164, 256, 200, 254, 240, 262, 270, 222, 282, 184, 276, 160, 258, 150, 232, 140, 196]
const A_SKIN = ["s0", "s1", "s2", "rm"], A_GREEN = ["g1", "g2", "g3", "rm"], A_ORANGE = ["o1", "o2", "o3", "o3"], A_WHITE = ["w0", "w1", "w2", "rm"]
sprite("fighter_a", { w: 380, h: 400, outline: "k", ow: 4 }, tf({ x: 0, y: 0 },
  // back arm (his left), swinging back-down: upper arm, forearm, an open hand
  ...seg(156, 182, 116, 226, 32, 28, A_GREEN), ...seg(116, 226, 88, 268, 28, 24, A_GREEN),
  hand(82, 282, 18, A_SKIN, 110),
  crease(116, 226, 6, 4),
  // trailing leg, folded under: thigh down, shin back, boot
  ...seg(206, 262, 186, 322, 40, 34, A_GREEN), ...seg(186, 322, 222, 350, 34, 30, A_GREEN),
  crease(186, 322, 6, -2),
  ...part([214, 334, 248, 330, 270, 350, 266, 376, 234, 384, 208, 370, 202, 350], A_ORANGE, { sd: 9, hd: 9, rim: 1.8, smooth: 0.6 }),  // boot
  // the kicking leg: thigh, shin, the boot flying right
  ...seg(238, 248, 300, 240, 44, 36, A_GREEN), ...seg(300, 240, 344, 224, 36, 30, A_GREEN),
  ...part([282, 222, 316, 216, 326, 238, 314, 260, 284, 262, 270, 242], A_ORANGE, { sd: 7, hd: 7, rim: 1.5 }),   // knee pad
  ...part([330, 200, 364, 192, 380, 212, 378, 242, 352, 254, 324, 246, 316, 222], A_ORANGE, { sd: 10, hd: 10, rim: 1.8, smooth: 0.6 }),  // boot
  clip(blob([330, 200, 364, 192, 380, 212, 378, 242, 352, 254, 324, 246, 316, 222], { fill: "k", smooth: 0.6 }), poly([314, 226, 384, 220, 384, 234, 316, 240], { fill: "o0", opacity: 0.45 })),
  // the neck and the torso: a white tunic leaning into the kick
  ...neck(142, 148, 166, 170, 30, A_SKIN),
  ...part(A_TORSO, ["t0", "t1", "t2", "rm"], { sd: 10, hd: 11, rim: 2, smooth: 0.45 }),
  clip(blob(A_TORSO, { fill: "k", smooth: 0.45 }),
    poly([160, 156, 182, 150, 246, 254, 228, 270], "r1"), poly([168, 156, 180, 152, 238, 256, 232, 262], { fill: "r2", opacity: 0.7 }),
    poly([160, 156, 182, 150, 246, 254, 228, 270], EDGE(1.6)),
    blob([150, 236, 190, 230, 236, 248, 230, 270, 180, 268, 150, 250], { fill: "t0", opacity: 0.6 }),   // the tunic's hem shadow
  ),
  star(202, 212, 5, 22, 10, { fill: "r1", rot: 15 }),
  clip(star(202, 212, 5, 22, 10, { fill: "k", rot: 15 }), circle(194, 204, 10, "r2"), poly([180, 200, 230, 236, 230, 240, 180, 240], { fill: "r0", opacity: 0.4 })),
  star(202, 212, 5, 22, 10, { ...EDGE(1.6), rot: 15 }),
  circle(202, 212, 5, "o2"), circle(202, 212, 5, EDGE(1.2)),
  // front arm: a punch up and to the right, fist leading
  ...seg(210, 168, 252, 136, 34, 30, A_GREEN), ...seg(252, 136, 282, 102, 30, 26, A_GREEN),
  crease(252, 136, 5, 5),
  fist(292, 88, 22, A_SKIN, -40, 1),
  // the head
  ...part(A_HEAD, A_SKIN, { sd: 10, hd: 11, rim: 2 }),
  clip(blob(A_HEAD, "k"), ellipse(166, 132, 10, 6, { fill: "bl", opacity: 0.35 }), ellipse(104, 136, 10, 6, { fill: "bl", opacity: 0.3 }),
    blob([96, 74, 180, 74, 186, 100, 150, 96, 118, 104, 90, 100], { fill: "s0", opacity: 0.45 })),
  blob(A_HEAD, EDGE(2.2)),
  // the long ear
  ...part([98, 112, 60, 100, 22, 110, 58, 126, 98, 134], A_SKIN, { sd: 5, hd: 5, rim: 1.4, smooth: 0.4 }),
  clip(blob([98, 112, 60, 100, 22, 110, 58, 126, 98, 134], { fill: "k", smooth: 0.4 }), blob([96, 120, 60, 112, 36, 116, 62, 128, 96, 132], { fill: "s0", opacity: 0.6, smooth: 0.4 })),
  // face: a fierce grin, eyes to the right
  eye(140, 124, 11, 9, "e0", 0.4, 0.05, -6), eye(170, 122, 9, 8, "e0", 0.35, 0.05, -6),
  curve([126, 106, 140, 102, 150, 108], INK(3.2, 0.3)), curve([160, 104, 172, 100, 182, 106], INK(3, 0.3)),
  curve([170, 140, 176, 146, 170, 150], INK(1.8, 0.5)),
  blob([132, 150, 150, 148, 174, 150, 170, 162, 150, 166, 134, 160], { fill: "k", smooth: 0.5 }),
  clip(blob([132, 150, 150, 148, 174, 150, 170, 162, 150, 166, 134, 160], { fill: "k", smooth: 0.5 }), rect(130, 146, 48, 9, "w2"), ellipse(152, 172, 12, 7, "r1")),
  // the hair, in spikes
  ...spiky(A_HAIR, A_WHITE, { sd: 10, hd: 12, rim: 2 }),
  clip(poly(A_HAIR, "k"), ...[[104, 60, 112, 30], [136, 60, 134, 20], [164, 62, 174, 26], [184, 78, 200, 50]].map((l) => curve(l, { stroke: "w0", sw: 2, opacity: 0.6 }))),
))

// ============================================================================
// The brawler: orange hair, a cross punch straight at us. Box 480 x 580.
// ============================================================================
const C_HEAD = [226, 86, 262, 84, 294, 104, 306, 140, 300, 180, 276, 210, 240, 218, 204, 204, 188, 170, 186, 132, 198, 102]
const C_HAIR = [200, 110, 150, 104, 184, 80, 142, 56, 196, 60, 180, 14, 230, 50, 258, 14, 272, 54, 322, 24, 300, 74, 352, 74, 316, 106, 312, 134, 292, 114, 258, 98, 224, 106]
const C_TORSO = [176, 236, 252, 222, 330, 236, 348, 292, 326, 350, 254, 366, 182, 350, 160, 292]
const C_SKIN = ["s0", "s1", "s2", "rm"], C_JEANS = ["j1", "j2", "j3", "rm"], C_FUR = ["f1", "f2", "f3", "rm"]
sprite("brawler", { w: 480, h: 580, outline: "k", ow: 4 }, tf({ x: 0, y: 0 },
  // back leg (his left), planted right: thigh, shin, paw
  ...seg(286, 350, 352, 428, 64, 50, C_JEANS), ...seg(352, 428, 388, 492, 50, 44, C_JEANS),
  crease(352, 428, -4, 8),
  ...part([352, 476, 404, 468, 440, 494, 444, 526, 410, 542, 362, 536, 342, 508], C_FUR, { sd: 10, hd: 10, rim: 2, smooth: 0.7 }),
  ...[[364, 532], [388, 538], [414, 536]].map(([x, y]) => curve([x, y - 10, x + 2, y + 4], INK(2.2, 0.4))),
  // back arm (his left) chambered at the hip
  ...seg(326, 262, 390, 300, 46, 38, C_SKIN), ...seg(390, 300, 380, 352, 38, 34, C_SKIN),
  crease(390, 300, 6, -2),
  fist(372, 372, 30, C_SKIN, 25, 1),
  // the neck, then the torso: the brown shirt with the tan yoke
  ...neck(246, 200, 252, 240, 44, C_SKIN),
  ...part(C_TORSO, ["n1", "n2", "n3", "rm"], { sd: 13, hd: 13, rim: 2.4, smooth: 0.7 }),
  clip(blob(C_TORSO, { fill: "k", smooth: 0.7 }),
    blob([160, 230, 252, 214, 350, 232, 342, 268, 268, 284, 170, 272], { fill: "q1", smooth: 0.6 }),
    blob([170, 234, 252, 220, 340, 240, 332, 258, 268, 268, 178, 258], { fill: "q2", smooth: 0.6, opacity: 0.6 }),
    curve([164, 272, 268, 286, 344, 268], INK(2.2)),
    curve([262, 288, 258, 346], { stroke: "n0", sw: 2.4, opacity: 0.45 }),
    blob([252, 222, 300, 228, 280, 262, 252, 258, 230, 262, 210, 228], { fill: "q0", opacity: 0.35, smooth: 0.6 }),   // the collar's shadow
  ),
  curve([226, 236, 252, 258, 280, 234], INK(2.4, 0.3)),   // the collar
  // the belt
  blob([180, 340, 254, 358, 328, 340, 330, 358, 254, 378, 178, 358], { fill: "j0", smooth: 0.5 }),
  clip(blob([180, 340, 254, 358, 328, 340, 330, 358, 254, 378, 178, 358], { fill: "k", smooth: 0.5 }), blob([182, 340, 254, 356, 326, 340, 326, 346, 254, 366, 182, 348], { fill: "j1", smooth: 0.5 })),
  rect(240, 352, 28, 18, { fill: "q1", r: 3 }), rect(240, 352, 28, 18, { ...EDGE(1.6), r: 3 }),
  // front leg (his right) striding at us, left: thigh, shin, the big paw
  ...seg(222, 352, 160, 432, 74, 56, C_JEANS), ...seg(160, 432, 116, 498, 56, 50, C_JEANS),
  crease(162, 430, 8, 6),
  clip(poly(segpts(222, 352, 160, 432, 74, 56), "k"), curve([200, 380, 170, 420], { stroke: "j0", sw: 2.4, opacity: 0.45 })),
  ...part([66, 482, 120, 466, 160, 484, 164, 524, 130, 546, 80, 540, 52, 512], C_FUR, { sd: 12, hd: 12, rim: 2.2, smooth: 0.7 }),
  ...[[78, 534], [106, 542], [136, 540]].map(([x, y]) => curve([x, y - 12, x + 2, y + 4], INK(2.4, 0.4))),
  clip(blob([66, 482, 120, 466, 160, 484, 164, 524, 130, 546, 80, 540, 52, 512], { fill: "k", smooth: 0.7 }), ...[[72, 496], [96, 488], [122, 486], [148, 496]].map(([x, y]) => curve([x, y, x - 4, y - 14], { stroke: "f0", sw: 2, opacity: 0.6 }))),
  // the head
  ...part(C_HEAD, C_SKIN, { sd: 12, hd: 12, rim: 2.2 }),
  clip(blob(C_HEAD, "k"), blob([186, 104, 306, 104, 310, 134, 280, 118, 244, 130, 212, 122, 186, 134], { fill: "s0", opacity: 0.45 }),
    ellipse(208, 178, 12, 7, { fill: "bl", opacity: 0.3 }), ellipse(284, 174, 12, 7, { fill: "bl", opacity: 0.3 })),
  blob(C_HEAD, EDGE(2.4)),
  // the ear (his left side shows), pointed
  ...part([298, 142, 330, 126, 352, 138, 326, 160, 298, 164], C_SKIN, { sd: 5, hd: 5, rim: 1.4, smooth: 0.4 }),
  // face: a cocky grin, eyes narrowed at us
  eye(228, 158, 14, 11, "e1", 0.1, 0.15, 4), eye(274, 156, 13, 11, "e1", 0.05, 0.15, 4),
  // heavy half-closed lids: a cocky squint
  ...[[228, 158, 14, 11, 4], [274, 156, 13, 11, 4]].map(([cx, cy, rx, ry, t]) => tf({ rot: t, origin: [cx, cy] },
    clip(ellipse(cx, cy, rx + 1, ry + 1, "k"), poly([cx - rx - 2, cy - ry - 3, cx + rx + 2, cy - ry - 3, cx + rx + 2, cy - ry * 0.35, cx - rx - 2, cy - ry * 0.05], "s1")),
    curve([cx - rx * 1.05, cy - ry * 0.1, cx, cy - ry * 0.45, cx + rx * 1.05, cy - ry * 0.4], INK(3.2, 0.25)))),
  curve([206, 140, 228, 136, 246, 146], INK(3.8, 0.3)), curve([256, 144, 276, 134, 294, 136], INK(3.6, 0.3)),
  curve([250, 172, 254, 182, 246, 186], INK(2, 0.5)),
  // a lopsided grin, the right corner up, teeth
  blob([214, 192, 248, 190, 286, 178, 282, 196, 250, 210, 218, 204], { fill: "k", smooth: 0.5 }),
  clip(blob([214, 192, 248, 190, 286, 178, 282, 196, 250, 210, 218, 204], { fill: "k", smooth: 0.5 }), poly([212, 190, 290, 176, 290, 186, 212, 198], "w2"), ellipse(250, 212, 22, 8, "r1")),
  curve([284, 176, 292, 172], INK(2.2, 0.5)),
  // the hair, big orange spikes
  ...spiky(C_HAIR, ["h1", "h2", "h3", "rm"], { sd: 14, hd: 14, rim: 2.4 }),
  clip(poly(C_HAIR, "k"), ...[[190, 104, 186, 70], [224, 104, 214, 56], [252, 98, 258, 44], [286, 108, 300, 62], [306, 124, 334, 86]].map((l) => curve(l, { stroke: "h0", sw: 2.4, opacity: 0.6 }))),
  // the punching arm (his right) straight at us: the sleeve, upper arm, forearm, the big fist
  ...seg(190, 262, 132, 296, 54, 46, C_SKIN), ...seg(132, 296, 100, 324, 46, 44, C_SKIN),
  ...part([168, 238, 206, 240, 218, 268, 196, 290, 166, 282, 156, 256], ["n1", "n2", "n3", "n3"], { sd: 7, hd: 7, rim: 1.6, smooth: 0.8 }),   // sleeve
  crease(132, 296, 4, 6),
  fist(90, 342, 58, C_SKIN, 15, -1),
))

// ============================================================================
// Fighter B: the masked white suit, crouched low, hair whipping. Box 440 x 380.
// ============================================================================
const B_HEAD = [206, 70, 236, 74, 254, 96, 258, 126, 248, 152, 226, 166, 200, 166, 180, 150, 172, 122, 176, 94, 188, 76]
const B_MASK = [184, 86, 200, 60, 226, 52, 252, 60, 266, 82, 258, 106, 236, 94, 216, 90, 200, 100]
const B_TORSO = [168, 192, 236, 178, 270, 214, 274, 262, 246, 290, 200, 292, 174, 264]
const B_SUIT = ["u0", "u1", "u2", "rm"], B_TEAL = ["v1", "v2", "v3", "v3"], B_SKIN = ["s0", "s1", "s2", "rm"], B_WHITE = ["w0", "w1", "w2", "rm"]
// a lock of hair: a tapered band along a curve
const lock = (spine, w0, w1 = 4) => {
  const mk = (dx, dy, st) => blob(sh(band(spine, (i, t) => w0 - (w0 - w1) * t), dx, dy), S(st, { smooth: 0.5 }))
  return [...cel(mk, B_WHITE, { sd: w0 * 0.25, hd: w0 * 0.3, rim: 1.6 }), mk(0, 0, S(EDGE(2), { smooth: 0.5 }))]
}
sprite("fighter_b", { w: 440, h: 380, outline: "k", ow: 4 }, tf({ x: 0, y: 0 },
  // the mane behind, whipping right in three locks
  ...lock([[236, 84], [284, 64], [330, 62], [364, 84]], 42, 8),
  ...lock([[240, 104], [292, 102], [334, 122], [362, 150]], 40, 8),
  ...lock([[236, 120], [276, 138], [306, 168], [322, 200]], 34, 6),
  // the back leg, stretched out right: thigh, shin, boot
  ...seg(256, 266, 330, 292, 42, 34, B_SUIT), ...seg(330, 292, 394, 316, 34, 30, B_SUIT),
  clip(poly(segpts(256, 266, 330, 292, 42, 34), "k"), curve([262, 262, 330, 288], { stroke: "v1", sw: 5 })),
  clip(poly(segpts(330, 292, 394, 316, 34, 30), "k"), curve([334, 290, 390, 312], { stroke: "v1", sw: 4 })),
  ...part([384, 302, 424, 298, 440, 318, 432, 342, 400, 348, 374, 334], B_TEAL, { sd: 6, hd: 6, rim: 1.6, smooth: 0.6 }),
  // the back arm, flung right and up, an open hand
  ...seg(244, 196, 296, 192, 30, 26, B_SUIT), ...seg(296, 192, 338, 168, 26, 22, B_SUIT),
  clip(poly(segpts(244, 196, 296, 192, 30, 26), "k"), curve([250, 196, 294, 192], { stroke: "v1", sw: 3.5 })),
  crease(296, 192, 2, 5),
  hand(352, 160, 18, B_SKIN, -30),
  // the neck and the torso crouched: a white suit with teal lines
  ...neck(208, 150, 212, 190, 30, B_SKIN),
  ...part(B_TORSO, B_SUIT, { sd: 10, hd: 10, rim: 2, smooth: 0.8 }),
  clip(blob(B_TORSO, { fill: "k", smooth: 0.8 }),
    curve([214, 180, 232, 230, 224, 290], { stroke: "v1", sw: 6 }), curve([214, 180, 232, 230, 224, 290], { stroke: "v2", sw: 2.2, opacity: 0.6 }),
    curve([172, 238, 214, 246, 268, 236], { stroke: "v1", sw: 4 }),
    curve([250, 196, 264, 220], { stroke: "v1", sw: 3 }),
    blob([168, 180, 240, 176, 236, 200, 204, 206, 172, 204], { fill: "u0", opacity: 0.5, smooth: 0.6 }),   // under the chin
  ),
  // the front leg folded, the knee forward-left, the boot flat
  ...seg(198, 270, 124, 284, 44, 36, B_SUIT), ...seg(124, 284, 98, 330, 36, 30, B_SUIT),
  clip(poly(segpts(198, 270, 124, 284, 44, 36), "k"), curve([190, 266, 128, 280], { stroke: "v1", sw: 5 })),
  crease(124, 284, 6, 2),
  ...part([66, 320, 104, 314, 128, 332, 124, 358, 94, 366, 62, 352], B_TEAL, { sd: 7, hd: 7, rim: 1.6, smooth: 0.6 }),
  // the front arm, down to the ground
  ...seg(182, 208, 130, 236, 30, 26, B_SUIT), ...seg(130, 236, 88, 276, 26, 22, B_SUIT),
  clip(poly(segpts(182, 208, 130, 236, 30, 26), "k"), curve([176, 208, 134, 234], { stroke: "v1", sw: 3.5 })),
  crease(130, 236, 4, -4),
  hand(74, 292, 17, B_SKIN, 150),
  // the head
  ...part(B_HEAD, B_SKIN, { sd: 10, hd: 10, rim: 2 }),
  clip(blob(B_HEAD, "k"), blob([174, 90, 260, 90, 262, 114, 236, 106, 204, 108, 174, 114], { fill: "s0", opacity: 0.4 }), ellipse(196, 136, 9, 5, { fill: "p1", opacity: 0.4 })),
  blob(B_HEAD, EDGE(2.2)),
  // the ear
  ...part([252, 114, 280, 106, 296, 118, 274, 132, 252, 134], B_SKIN, { sd: 4, hd: 4, rim: 1.2, smooth: 0.4 }),
  // face: a cool, sharp look to the left; a hair lock over the other eye
  eye(198, 122, 10, 8, "v1", -0.4, 0.05, 6),
  curve([184, 108, 198, 104, 210, 110], INK(2.8, 0.3)),
  curve([188, 138, 184, 144], INK(1.6, 0.5)),
  curve([190, 152, 202, 156, 214, 152], INK(2, 0.4)),
  ...spiky([200, 80, 232, 66, 254, 80, 252, 114, 246, 140, 234, 110, 222, 134, 214, 102], B_WHITE, { sd: 6, hd: 6, rim: 1.6 }),
  ...spiky(B_MASK, ["i1", "i2", "v2", "v3"], { sd: 6, hd: 6, rim: 1.8 }),
  clip(poly(B_MASK, "k"), circle(214, 78, 5, "k"), circle(240, 76, 5, "k"), curve([200, 92, 226, 84, 254, 92], { stroke: "i0", sw: 2, opacity: 0.6 })),
  ...spiky([186, 80, 170, 50, 196, 66, 204, 38, 222, 64, 240, 32, 246, 66, 270, 50, 260, 82], B_WHITE, { sd: 8, hd: 8, rim: 1.6 }),
))

// ============================================================================
// The chick mascot. Box 120 x 120.
// ============================================================================
sprite("_chick", { w: 120, h: 120, outline: "k", ow: 3 },
  ...spiky([52, 40, 44, 6, 60, 30, 66, 2, 74, 32, 88, 12, 80, 44], ["y0", "y1", "y2", "y2"], { sd: 5, hd: 5, rim: 1.2 }),
  ...part([34, 78, 50, 108, 50, 114, 26, 114, 20, 100], ["o1", "o2", "o3", "o3"], { sd: 4, hd: 4, rim: 1, smooth: 0.5 }),
  ...part([80, 78, 96, 108, 100, 114, 76, 114, 68, 100], ["o1", "o2", "o3", "o3"], { sd: 4, hd: 4, rim: 1, smooth: 0.5 }),
  ...part([62, 32, 94, 40, 108, 66, 102, 94, 76, 106, 44, 104, 22, 86, 18, 58, 34, 38], ["y0", "y1", "y2", "y3"], { sd: 9, hd: 10, rim: 1.8 }),
  circle(86, 62, 15, "w2"), circle(86, 62, 15, EDGE(1.8)), circle(92, 64, 7, "k"), circle(90, 61, 2.5, "w2"),
  circle(60, 60, 10, "w2"), circle(60, 60, 10, EDGE(1.6)), circle(64, 62, 4.5, "k"), circle(62.5, 60, 1.6, "w2"),
  ...part([96, 72, 118, 76, 100, 86], ["o1", "o2", "o3", "o3"], { sd: 3, hd: 3, rim: 0, smooth: 0.2 }),
)

// ============================================================================
// The splash
// ============================================================================
const W = 1280, H = 720
const GHOST = { font: "Saira Condensed", weight: 800, size: 560, anchor: "middle" }
const DISPLAY = (size, extra = {}) => ({ font: "Saira Condensed", weight: 800, size, anchor: "start", ...extra })
const cross = (x, y, c = "k", s = 7, o = 0.4) => [line([x - s, y, x + s, y], { stroke: c, sw: 1, opacity: o }), line([x, y - s, x, y + s], { stroke: c, sw: 1, opacity: o })]
const spark = (x, y, r, c = "cr") => star(x, y, 4, r, r * 0.3, { fill: c })
// the fight's energy: ink speed strokes behind a fighter
const dashes = (x, y, dir, n, c = "k", o = 0.35) => Array.from({ length: n }, (_, i) =>
  curve([x + i * 6, y + i * 26, x + dir * (90 + (i % 3) * 40) + i * 6, y + i * 26 - dir * 10], { ink: { c, w: 4, taper: 0.5, wobble: 0 }, opacity: o }))

// an impact burst: a jagged white star with an ink edge, coral inside
const burst = (cx, cy, r, n = 14, seed = 1) => {
  const pts = []
  for (let i = 0; i < n * 2; i++) { const a = (Math.PI * 2 * i) / (n * 2) - Math.PI / 2, rr = i % 2 ? r * 0.55 : r * (0.85 + 0.3 * Math.abs(Math.sin(i * 2.3 + seed))); pts.push(cx + rr * Math.cos(a), cy + rr * Math.sin(a)) }
  const sc = (k) => pts.map((v, i) => (i % 2 ? cy + (v - cy) * k : cx + (v - cx) * k))
  return [poly(sc(1.12), { fill: "cr", opacity: 0.35 }), poly(pts, { fill: "cr", opacity: 0.9 }),
    poly(sc(0.6), { fill: "cr2", opacity: 0.9 }), poly(sc(0.3), { fill: "bg2", opacity: 0.95 })]
}
// radiating ink speed lines from a point
const rays = (cx, cy, r0, r1, n, c = "k", o = 0.3, seed = 0) => Array.from({ length: n }, (_, i) => {
  const a = (Math.PI * 2 * i) / n + seed + 0.3 * Math.sin(i * 7.1 + seed), l = r1 + 30 * Math.sin(i * 3.7 + seed)
  return curve([cx + r0 * Math.cos(a), cy + r0 * Math.sin(a), cx + l * Math.cos(a), cy + l * Math.sin(a)], { ink: { c, w: 3.5, taper: 0.6, wobble: 0 }, opacity: o })
})

scene("splash", { w: W, h: H, bg: "bg0" },
  // ---- the light ----
  rect(0, 0, W, H, { fill: rad(["bg2", "bg1", "bg0"], { cx: 0.5, cy: 0.45, r: 0.72 }) }),
  // the ghost word, far back
  text(820, 560, "ARENA", { ...GHOST, fill: "none", stroke: "k", sw: 2, opacity: 0.035 }),
  text(820, 560, "ARENA", { ...GHOST, fill: "k", opacity: 0.015 }),
  // the coral band, slanted across behind the fighters, and a thinner echo
  poly([560, 0, 1280, 0, 1280, 140, 880, 580, 620, 580], { fill: "cr", opacity: 0.15 }),
  circle(800, 340, 330, { fill: rad(["#ffffffee", "#ffffff99", "#ffffff00"], { r: 0.5 }) }),
  poly([1120, 0, 1280, 0, 1280, 40, 1190, 300], { fill: "cr", opacity: 0.1 }),
  // a dotted field on the right, like the lobby's cards
  ...Array.from({ length: 11 }, (_, j) => Array.from({ length: 8 }, (_, i) => circle(1070 + i * 24, 300 + j * 24, 1.6, { fill: "k", opacity: 0.12 }))),
  // technical lines, crosses and the code tag
  line([48, 72, 1232, 72], { stroke: "k", sw: 1, opacity: 0.25 }),
  line([48, 596, 1232, 596], { stroke: "k", sw: 1, opacity: 0.18 }),
  ...cross(48, 72), ...cross(1232, 72), ...cross(48, 596), ...cross(1232, 596),
  text(1232, 60, "PPA // SPLASH · 00", { font: "Nunito", weight: 700, size: 12, anchor: "end", fill: "fa", opacity: 0.9 }),
  // ---- the ground shadows ----
  ellipse(1080, 590, 150, 12, { fill: "k", opacity: 0.1, blur: 4 }),
  ellipse(800, 592, 210, 16, { fill: "k", opacity: 0.16, blur: 5 }),
  // ---- the logo ----
  tf({ rot: -6, origin: [80, 330] },
    poly([74, 150, 318, 150, 306, 212, 62, 212], "cr0"),
    poly([70, 144, 314, 144, 302, 206, 58, 206], "cr"),
    poly([70, 144, 314, 144, 302, 206, 58, 206], EDGE(2.5)),
    text(92, 194, "PIPPOP", { ...DISPLAY(66), fill: "bg2" }),
    text(70, 360, "ARENA", { ...DISPLAY(190), fill: "cr", stroke: "cr", sw: 10 }),
    text(60, 350, "ARENA", { ...DISPLAY(190), fill: "k", stroke: "k", sw: 10 }),
    text(60, 350, "ARENA", { ...DISPLAY(190), fill: "bg2", stroke: "bg2", sw: 4 }),
    text(60, 350, "ARENA", { ...DISPLAY(190), fill: "k" }),
    poly([64, 372, 420, 372, 416, 382, 60, 382], "cr"),
    // the chick mascot perched on the corner of the tag, looking at the fight
    stamp("_chick", 296, 150, { anchor: "bottom", scale: 0.72 }),
  ),
  spark(452, 128, 12), spark(482, 168, 7), spark(420, 100, 6, "k"),
  // ---- the fighters: A leaping behind-left, B dashing behind-right, the brawler in front ----
  ...dashes(430, 130, -1, 3, "k", 0.2),
  stamp("fighter_a", 590, 318, { anchor: "bottom", scale: 0.66 }),
  ...dashes(1000, 250, 1, 5, "cr", 0.5),
  stamp("fighter_b", 1090, 580, { anchor: "bottom", scale: 0.7 }),
  // the impact behind the fist
  ...rays(650, 360, 100, 160, 16, "k", 0.2, 0.4).map((r) => clip(rect(0, 80, 1280, 512, "k"), r)),
  ...burst(646, 356, 118, 12, 2),
  stamp("brawler", 800, 592, { anchor: "bottom", scale: 1.0 }),
  spark(548, 400, 12), spark(700, 540, 9, "k"), spark(530, 470, 8),
  spark(150, 470, 9), spark(200, 440, 5, "k"), spark(118, 520, 5),
)
