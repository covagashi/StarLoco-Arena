// S38b: the talk window's NPC portraits, drawn in vex (owner 2026-11-13: no
// 3D figure for them). Our own drawing after each retail portrait's shape,
// in the screens' style B: an ink outline, two tones per material, the light
// from the top left. 170 x 200 units = talk_panel.gd FACE_SIZE.
//   node <vex>/bin/vex.js build tools/portraits/npc_portraits.vx.js --scales 2

const EDGE = { stroke: "k", sw: 2.4, join: "round" }   // inner ink between the pieces

pal({
  k: "#1c2030",                                   // style B ink
  b: "#8fd3ee", B: "#5aa6d4", l: "#d2f3fc",       // Nilo's skin
  w: "#ffffff", W: "#c9deeb",                     // white hair
  h: "#a8642e", H: "#6e3d1a", y: "#f4bb34",       // horns, their gold
  p: "#7b3f9e", g: "#f6f1fb", G: "#d9cdea",       // glasses
  o: "#f28c2c", O: "#b4521b", s: "#5b3519",       // staff and its stone
})

// A tapered band along a spine: the spine's points with a width at each,
// offset both ways → one closed polygon (horns, tufts, moustache).
function band(spine, widths) {
  const L = [], R = []
  for (let i = 0; i < spine.length; i++) {
    const [x, y] = spine[i]
    const [ax, ay] = spine[Math.max(0, i - 1)], [bx, by] = spine[Math.min(spine.length - 1, i + 1)]
    let nx = -(by - ay), ny = bx - ax
    const n = Math.hypot(nx, ny) || 1
    nx /= n; ny /= n
    const w = widths(i / (spine.length - 1)) / 2
    L.push(x + nx * w, y + ny * w)
    R.unshift(x - nx * w, y - ny * w)
  }
  return [...L, ...R]
}

// a spiral spine around (cx, cy), angle a0 → a1 (degrees), radius r0 → r1
function spiral(cx, cy, a0, a1, r0, r1, n = 28) {
  return Array.from({ length: n }, (_, i) => {
    const t = i / (n - 1), a = (a0 + (a1 - a0) * t) * Math.PI / 180, r = r0 + (r1 - r0) * t
    return [cx + r * Math.cos(a), cy + r * Math.sin(a)]
  })
}

const NILO_HEAD = [85, 60, 112, 64, 127, 80, 130, 101, 124, 122, 108, 137, 85, 141, 62, 137, 46, 122, 40, 101, 43, 80, 58, 64]
const hornL = spiral(33, 64, 12, -318, 24, 8)
const tuftL = [[76, 66], [73, 52], [67, 40], [58, 31], ...spiral(48, 32, -60, -400, 10, 2, 22)]

sprite("nilo", { w: 170, h: 200, scale: 2, outline: "k", ow: 3 },
  // body below the head, the staff behind the hand
  blob([71, 134, 99, 134, 106, 156, 113, 200, 57, 200, 64, 156], { fill: "b", ...EDGE }),
  clip(blob([71, 134, 99, 134, 106, 156, 113, 200, 57, 200, 64, 156], "k"), ellipse(114, 186, 22, 36, "B")),
  line([154, 200, 141, 126], { stroke: "s", sw: 6, cap: "round" }),
  // horns (mirrored), ridged, with gold triangles
  sym(85,
    poly(band(hornL, (t) => 17 - 11 * t), { fill: "h", ...EDGE }),
    clip(poly(band(hornL, (t) => 17 - 11 * t), "k"), poly(band(hornL.map(([x, y]) => [x + 3, y + 3]), (t) => 9 - 6 * t), { fill: "H" })),
    ...[3, 8, 13, 18].map((i) => {
      const [x, y] = hornL[i]
      return star(x, y, 3, 2.6, 1.2, { fill: "y", rot: i * 21 })
    }),
    // pointed ear and its gold ring
    blob([46, 90, 26, 84, 10, 82, 24, 96, 46, 110], { fill: "b", smooth: 0.3, ...EDGE }),
    clip(blob([46, 90, 26, 84, 10, 82, 24, 96, 46, 110], { fill: "k", smooth: 0.3 }), ellipse(36, 106, 16, 8, "B")),
    // a white tuft rising from the crown, ending in a curl
    poly(band(tuftL, (t) => 19 * (1 - t) ** 0.8 + 5.5), { fill: "l", ...EDGE }),
    clip(poly(band(tuftL, (t) => 19 * (1 - t) ** 0.8 + 5.5), "k"),
      poly(band(tuftL.map(([x, y]) => [x - 2.5, y - 1]), (t) => 8 * (1 - t) + 1), { fill: "w" })),
  ),
  // the head, shaded away from the light
  blob(NILO_HEAD, { fill: "b", ...EDGE }),
  clip(blob(NILO_HEAD, "k"), ellipse(124, 126, 52, 44, "B"), ellipse(62, 74, 18, 10, { fill: "l", opacity: 0.8 })),
  // the swirl on the forehead
  curve(spiral(85, 84, 0, 400, 1, 7, 20).flat(), { stroke: "l", sw: 2.2, cap: "round" }),
  // glasses
  sym(85,
    circle(67, 108, 16, { fill: "g", stroke: "p", sw: 4.5 }),
    clip(circle(67, 108, 14, "k"), ellipse(74, 117, 15, 9, "G")),
    circle(64, 102, 2.2, { fill: "w", opacity: 0.9 })),
  line([81, 106, 89, 106], { stroke: "p", sw: 4, cap: "round" }),
  // both eyes glance to his right, a sly look
  circle(62, 111, 3.8, "k"), circle(96, 111, 3.8, "k"),
  // bushy white brows over the lenses, jagged
  sym(85, poly([46, 96, 50, 85, 56, 89, 59, 79, 65, 86, 70, 76, 74, 85, 80, 79, 83, 88, 81, 96, 66, 94, 52, 99], { fill: "w", ...EDGE }),
    clip(poly([46, 96, 50, 85, 56, 89, 59, 79, 65, 86, 70, 76, 74, 85, 80, 79, 83, 88, 81, 96, 66, 94, 52, 99], "k"), ellipse(66, 99, 20, 5, "W"))),
  // mouth, and the long moustache hanging both sides
  line([80, 132, 90, 132], { stroke: "k", sw: 2, cap: "round" }),
  sym(85,
    poly(band([[83, 125], [74, 129], [66, 138], [61, 152], [61, 168], [65, 180], [71, 184], [74, 180]], (t) => 9 * (1 - t) + 2.5), { fill: "w", ...EDGE }),
    clip(poly(band([[83, 125], [74, 129], [66, 138], [61, 152], [61, 168], [65, 180], [71, 184], [74, 180]], (t) => 9 * (1 - t) + 2.5), "k"),
      ellipse(68, 170, 6, 14, "W"))),
  // the stone on the staff and the hand on it
  ellipse(142, 112, 13, 17, { fill: "o", ...EDGE }),
  clip(ellipse(142, 112, 13, 17, "k"), ellipse(150, 120, 12, 16, "O"), ellipse(137, 104, 4, 6, { fill: "#ffd08a", opacity: 0.9 })),
  curve(spiral(142, 113, 0, 330, 1.5, 7, 16).flat(), { stroke: "s", sw: 2.4, cap: "round" }),
  poly(band([[102, 150], [114, 157], [126, 157], [134, 154]], (t) => 9 - 2 * t), { fill: "b", ...EDGE }),
  blob([132, 150, 140, 146, 146, 152, 143, 160, 134, 160], { fill: "b", ...EDGE }),
  curve([135, 152, 141, 151], { stroke: "B", sw: 1.6, cap: "round" }),
)
