// Arena 12 (retail world 44: a swamp) — the pieces it doesn't share with the
// other kits, each in three looms: <name> (a), <name>_b, <name>_c. Build
// kit.tx.js first (and arena 6's, for the planks). Retail gfx in brackets.
include("../common/shapes.kx.js")

const LOOMS = ["", "_b", "_c"]
// loom-textured materials: [key, loom, uv, rough, tints a/b/c]
const TEX = (rows) => pal(Object.fromEntries(rows.flatMap(([k, tex, uv, rough, tint]) => LOOMS.map((s, i) =>
  [k + s, { tex: tex + s, uv, rough, ...(tint ? { color: tint[i] } : {}) }]))))
TEX([
  // the peat block: moss cushions on top, streaks down the sides (soft*:
  // smooth normals in the game)
  ["softPeat", "out/peat", 0.9, 0.9], ["softPeatSide", "out/peatSide", 0.9, 0.9],
  // the mud of the slabs, its sides in shade, the pale crests of 2659
  ["softMud", "out/mud", 1.4, 0.6], ["softMudSide", "out/mud", 1.6, 0.7, ["#c4b8a0", "#c0bcb4", "#c8b0a4"]],
  ["softMudPale", "out/mud", 0.6, 0.5, ["#fff4d0", "#f4f0e8", "#ffe4d4"]],
  // duckweed
  ["softWeed", "out/duckweed", 1.6, 0.4],
  // arena 6's boards for the walkways
  ["board", "../arena6/out/board", 0.8, 0.8, ["#d8d0a0", "#c8c8c0", "#d0b8a0"]],
  ["boardD", "../arena6/out/board", 0.8, 0.85, ["#988c60", "#8a8a84", "#8a7060"]],
  ["boardV", "../arena6/out/boardV", 0.8, 0.8, ["#d8d0a0", "#c8c8c0", "#d0b8a0"]],
])
const SET = (o, rough = 0.8) =>
  pal(Object.fromEntries(LOOMS.flatMap((s, i) => Object.entries(o).map(([k, v]) => [k + s, { color: v[i], rough }]))))
// the swamp grass on the slabs: olive (retail), fresh green, autumn straw
const REED = {
  reedD: ["#343c10", "#1e3c18", "#4e3a14"], reed: ["#4e5a18", "#30582a", "#765a20"], reedL: ["#6e7a28", "#4a7a36", "#9a7a30"],
  reedP: ["#a2a650", "#7aa45a", "#c4a856"],
}
SET(REED, 0.75)
const SKINNED = ["softPeat", "softPeatSide", "softMud", "softMudSide", "softMudPale", "softWeed", "board", "boardD", "boardV", ...Object.keys(REED)]
const looms = (name) => threeLooms(name, SKINNED)

// Screen terms, as in the arena 8, 9 and 11 kits: u along the screen's
// horizontal (world (1, 0, -1)), v towards the camera (world (1, 0, 1)), in
// metres (61 px a metre along u, 52.7 px a metre up, at 1×).
const R2 = Math.SQRT1_2
const DEG = 180 / Math.PI
const at = (u, v) => [(u + v) * R2, (v - u) * R2]
const sp = (u, y, v) => { const [x, z] = at(u, v); return [x, y, z] }
const rnd = (i, k, seed) => ((Math.sin((i + 1) * 12.9898 * k + seed * 78.233) * 43758.5453) % 1 + 1) % 1
const smooth = (e) => { const t = Math.min(1, Math.max(0, e)); return t * t * (3 - 2 * t) }

// a soft-edged block: a rounded-square body (half wide, corners r, a
// little wobble) and a heightfield top inscribed in it (its corners stay
// inside the corner arcs): flat at its border, `top(x, z, e)` metres higher inside
// (e = depth inside the heightfield's border).
function pillow({ half = 0.5, r = 0.2, h = 0.28, top = () => 0, extra = 0.2, res = 40, seed = 1, wave = 0.015, mats = ["softMud", "softMudSide"] }) {
  const th = half * (1 - wave) - 0.293 * r - 0.005
  return [
    prismUp(roundSquare(half, r, 6, wave, seed), h, 0, mats[1], 0.004),
    terrain(2 * th, 2 * th, { res, height: extra, mat: mats[0], pos: [0, h - 0.004, 0],
      fn: (x, z) => Math.max(0, Math.min(1, top(x, z, th - Math.max(Math.abs(x), Math.abs(z))) / extra)) }),
  ]
}
// a smooth curve through points [a, b, c] (Catmull-Rom), n per span
function spline(pts, n = 5) {
  const out = []
  for (let i = 0; i < pts.length - 1; i++) {
    const p0 = pts[Math.max(0, i - 1)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[Math.min(pts.length - 1, i + 2)]
    for (let k = 0; k < n; k++) {
      const t = k / n, t2 = t * t, t3 = t2 * t
      out.push([0, 1, 2].map((c) => 0.5 * (2 * p1[c] + (-p0[c] + p2[c]) * t + (2 * p0[c] - 5 * p1[c] + 4 * p2[c] - p3[c]) * t2 + (-p0[c] + 3 * p1[c] - 3 * p2[c] + p3[c]) * t3)))
    }
  }
  out.push(pts[pts.length - 1])
  return out
}
// a stem through [x, y, z, r] points: tapering cylinders, a joint ball at
// each bend (arena 11's helper)
function stem(pts, mat, sides = 5) {
  const out = []
  for (let i = 0; i < pts.length - 1; i++) {
    const [x0, y0, z0, r0] = pts[i], [x1, y1, z1, r1] = pts[i + 1]
    const dx = x1 - x0, dy = y1 - y0, dz = z1 - z0, len = Math.hypot(dx, dy, dz)
    out.push(tf({ pos: [x0, y0, z0], rot: [0, Math.atan2(-dz, dx) * DEG, 0] },
      lathe([r0, 0, r1, len], { mat, sides, rot: [0, 0, -Math.acos(dy / len) * DEG] })))
    if (i) out.push(sphere(r0 * Math.cos(Math.PI / sides), { mat, detail: r0 > 0.03 ? 1 : 0, pos: [x0, y0, z0] }))
  }
  return out
}

// --- the peat block under every cell (619) ------------------------------------
// a cell-wide block of moss-grown earth, a metre tall: its top a crowd of
// soft moss cushions that bulge a little past the edges, the moss hanging
// down the sides in streaks. The slabs (caps below) sit on it.
const PEAT_H = 0.92
// lumps: [x, z, r, h] cushions on the top
const PEAT_LUMPS = [[-0.3, -0.3, 0.24, 0.1], [0.05, -0.32, 0.22, 0.12], [0.33, -0.26, 0.22, 0.09], [-0.32, 0.02, 0.22, 0.11],
  [0.0, 0.0, 0.26, 0.13], [0.3, 0.06, 0.22, 0.1], [-0.28, 0.32, 0.22, 0.09], [0.04, 0.32, 0.24, 0.11], [0.33, 0.34, 0.2, 0.09],
  [-0.12, -0.14, 0.16, 0.06], [0.18, 0.2, 0.16, 0.06]]
const lumpsFn = (lumps) => (x, z) => {
  let h = 0
  for (const [lx, lz, r, a] of lumps) {
    const d = Math.hypot(x - lx, z - lz) / r
    if (d < 1) h = Math.max(h, a * Math.sqrt(1 - d * d))
  }
  return 0.25 + h / 0.13 * 0.75
}
model("peat_block",
  pillow({ half: 0.49, r: 0.16, h: PEAT_H, extra: 0.16, seed: 3, mats: ["softPeat", "softPeatSide"],
    top: (x, z, e) => 0.15 * lumpsFn(PEAT_LUMPS)(x, z) * smooth(e / 0.08) }),
  // cushions rolling over the rim
  Array.from({ length: 16 }, (_, i) => {
    const side = i % 4, t = -0.36 + (Math.floor(i / 4)) * 0.24 + (rnd(i, 1, 7) - 0.5) * 0.08
    const [x, z] = [[t, 0.47], [0.47, t], [t, -0.47], [-0.47, t]][side]
    return sphere(0.1 + rnd(i, 2, 7) * 0.04, { mat: "softPeat", detail: 1, pos: [x, PEAT_H - 0.04 - rnd(i, 3, 7) * 0.05, z], scale: [1.2, 0.8, 1.2] })
  }))
looms("peat_block")

// --- the slabs on the peat (groups «losa de tierra» 2654-2656, 2692 and
// «losa de barro» 1501, 2657, 2659, 2660) -------------------------------------
// y = 0 is the peat block's top. A slab of mud a quarter of a metre thick,
// its edge lumpy; the earth slabs have a raised lip round a lower middle
// where the swamp grass grows, the mud slabs a domed top.
const SLAB_H = 0.28
// the earth slabs' top: a raised lip at the rim, a lower middle
const lipTop = (seed) => (x, z, e) => {
  const wob = 0.5 + 0.5 * Math.sin(x * 11 + seed) * Math.sin(z * 9 + seed * 1.3)
  return 0.09 * smooth(e / 0.04) - 0.07 * smooth((e - 0.07) / 0.1) + 0.03 * wob * smooth(e / 0.04)
}
// the mud slabs' top: swelling to the middle, three winding ridges of
// pushed-up mud across it (the retail's pale crests)
const domeTop = (seed) => (x, z, e) => {
  let r = 0
  for (let k = 0; k < 3; k++) {
    const c = -0.28 + k * 0.28 + 0.05 * Math.sin(seed * 3 + k)
    const d = (x + z) * R2 * 0.3 + (z - x) * R2 - c - 0.07 * Math.sin(((x + z) * R2) * (8 + k * 2) + seed + k)
    r = Math.max(r, Math.exp(-((d / 0.05) ** 2)))
  }
  return smooth(e / 0.25) * (0.1 + r * 0.06)
}

// swamp grass: long blades, each a flat lance arcing to one side, in tufts
const blade = (h, w, arc, mat) => {
  const pts = [], n = 6
  for (let k = 0; k <= n; k++) { const t = k / n; pts.push(arc * t * t + w / 2 * Math.sin(Math.PI * (0.1 + 0.9 * t)) ** 0.7 * (t < 1 ? 1 : 0), h * t) }
  for (let k = n - 1; k >= 0; k--) { const t = k / n; pts.push(arc * t * t - w / 2 * Math.sin(Math.PI * (0.1 + 0.9 * t)) ** 0.7, h * t) }
  return extrude(pts, 0.006, { mat })
}
// a patch of n blades over an area (screen terms: u0..u1, v0..v1) at height y
function reeds(n, [u0, u1], [v0, v1], y, lo, hi, seed, tones = ["reedD", "reed", "reed", "reedL"]) {
  return Array.from({ length: n }, (_, i) => {
    const r = (k) => rnd(i, k, seed)
    const u = u0 + (u1 - u0) * r(1), v = v0 + (v1 - v0) * r(2), h = lo + (hi - lo) * r(3)
    const lean = (r(4) - 0.5) * 50, arc = (r(5) - 0.5) * h * 0.5
    const [x, z] = at(u, v)
    // each blade turned to the camera give or take 35°
    return tf({ pos: [x, y, z], rot: [0, 45 + (r(6) - 0.5) * 70, 0] }, tf({ rot: [0, 0, lean] },
      blade(h, 0.026 + r(7) * 0.014, arc, tones[Math.floor(r(8) * tones.length)])))
  })
}
// short dark tufts poking out of the slab's rim
const rimTufts = (seed) => [[-0.5, 0.0], [-0.25, 0.25], [0.0, 0.48], [0.25, 0.25], [0.5, 0.0]].map(([u, v], i) =>
  reeds(4, [u - 0.06, u + 0.06], [v + 0.02, v + 0.05], SLAB_H, 0.08, 0.16, seed + i, ["reedD", "reed"]))

const earthSlab = (seed) => pillow({ half: 0.505, r: 0.16, top: lipTop(seed), extra: 0.12, seed })
// earth slab with grass (2654, 2655): the grass all over its middle
model("earth_slab_grass", earthSlab(1),
  reeds(70, [-0.42, 0.42], [-0.28, 0.28], SLAB_H, 0.35, 0.7, 11), rimTufts(13))
// earth slab, sparse (2656): fewer, paler blades
model("earth_slab_sparse", earthSlab(2),
  reeds(34, [-0.42, 0.4], [-0.28, 0.25], SLAB_H, 0.3, 0.6, 21, ["reed", "reedL", "reedP"]), rimTufts(23))
// earth slab, grass behind (2692, 1501): dense dark grass on its back half,
// the bare mud in front
model("earth_slab_half", earthSlab(3),
  reeds(60, [-0.45, 0.3], [-0.38, 0.0], SLAB_H, 0.45, 0.8, 31, ["reedD", "reedD", "reed", "reedL"]), rimTufts(33))
for (const n of ["earth_slab_grass", "earth_slab_sparse", "earth_slab_half"]) looms(n)

const mudSlab = (seed) => pillow({ half: 0.52, r: 0.24, top: domeTop(seed), extra: 0.17, seed })
// mud slab (2657, 2660): a domed slab of wet mud
model("mud_slab", mudSlab(4))
// mud slab with drips (2659): pale crests along its front edges, running
// down the sides in drips
const drips = (seed) => {
  const out = []
  for (const [dx, dz, ex, ez, n] of [[1, 0, 0, 1, 3], [0, 1, 1, 0, 4]]) {
    const ts = Array.from({ length: n }, (_, i) => -0.36 + (i + 0.5) * 0.72 / n + (rnd(i, 1, seed + dx) - 0.5) * 0.12)
    ts.forEach((t, i) => {
      const len = 0.08 + rnd(i, 2, seed + dx) * 0.14, rr = 0.032 + rnd(i, 3, seed + dx) * 0.018
      const x = dx * 0.5 + ex * t, z = dz * 0.5 + ez * t
      out.push(tube([x - dx * 0.02, SLAB_H + 0.03, z - dz * 0.02, x + dx * 0.025, SLAB_H - 0.02, z + dz * 0.025, x + dx * 0.025, SLAB_H - 0.02 - len, z + dz * 0.025], rr, { mat: "softMudPale", sides: 6 }),
        sphere(rr * 1.3, { mat: "softMudPale", detail: 1, pos: [x + dx * 0.025, SLAB_H - 0.02 - len, z + dz * 0.025], scale: [1, 1.2, 1] }))
    })
    // the crest along that edge: a run of soft lumps
    for (let k = 0; k < 9; k++) {
      const t = -0.4 + k * 0.1 + (rnd(k, 4, seed + dz) - 0.5) * 0.04
      out.push(sphere(0.05 + rnd(k, 5, seed + dz) * 0.025, { mat: "softMudPale", detail: 1, pos: [dx * 0.47 + ex * t, SLAB_H + 0.015, dz * 0.47 + ez * t], scale: [1.3, 0.55, 1.3] }))
    }
  }
  return out
}
model("mud_slab_drip", mudSlab(5), drips(51))
for (const n of ["mud_slab", "mud_slab_drip"]) looms(n)

// --- the swamp water's film (group «líquido verde»: duckweed 2662-2664,
// 2666, 2667; tendrils 2627, 2630, 2632) and the murky puddle (2661) --------
// Flat pieces lying on whatever is under them (y = 0). Sizes from the retail
// sprites: u = px / 61, v = ground px / 30.4.
// a soft blob outline in screen terms: centre (u, v), radii (ru, rv), lobes
const blobPts = (u0, v0, ru, rv, seed, n = 28) => {
  const pts = []
  for (let k = 0; k < n; k++) {
    const a = k / n * Math.PI * 2
    const f = 1 + 0.18 * Math.sin(a * 3 + seed) + 0.1 * Math.sin(a * 5 + seed * 2.3) + 0.06 * Math.sin(a * 9 + seed * 4.1)
    const [x, z] = at(u0 + Math.cos(a) * ru * f, v0 + Math.sin(a) * rv * f)
    // extrude's XY plane, turned flat: y = -z
    pts.push(x, -z)
  }
  return pts
}
const flatBlob = (u, v, ru, rv, seed, mat, t = 0.014, y = 0) => extrude(blobPts(u, v, ru, rv, seed), t, { mat, rot: [-90, 0, 0], pos: [0, y, 0] })
// loose fronds round a patch: little discs, a few in pairs
const fronds = (n, ru, rv, inner, seed, mat = "softWeed") => Array.from({ length: n }, (_, i) => {
  const a = rnd(i, 1, seed) * Math.PI * 2, d = inner + (1 - inner) * rnd(i, 2, seed)
  const r = 0.025 + rnd(i, 3, seed) * 0.03
  return cyl(r, 0.012, { mat, sides: 7, pos: sp(Math.cos(a) * ru * d, 0, Math.sin(a) * rv * d), scale: [1, 1, 0.85] })
})
// duckweed patches: one mat (or a few), loose fronds round it
model("duckweed_patch", { pivot: "origin" },   // 2666
  flatBlob(-0.05, 0.0, 0.5, 0.42, 3, "softWeed"), flatBlob(0.3, 0.25, 0.25, 0.2, 5, "softWeed", 0.016),
  fronds(26, 0.74, 0.7, 0.75, 31))
model("duckweed_patch_dense", { pivot: "origin" },   // 2662, 2664
  flatBlob(0.08, 0.0, 0.55, 0.45, 7, "softWeed"), flatBlob(-0.35, -0.2, 0.2, 0.18, 9, "softWeed", 0.016),
  fronds(18, 0.72, 0.62, 0.8, 37))
model("duckweed_ring", { pivot: "origin" },   // 2663: a ring round open water
  Array.from({ length: 7 }, (_, i) => { const a = i / 7 * Math.PI * 2 + 0.3
    return flatBlob(Math.cos(a) * 0.55, Math.sin(a) * 0.55, 0.32, 0.28, 11 + i, "softWeed", 0.014 + (i % 2) * 0.002) }),
  fronds(24, 0.95, 0.95, 0.85, 41))
model("duckweed_bits", { pivot: "origin" },   // 2667: a scatter of fronds
  fronds(22, 0.45, 0.38, 0.0, 47), flatBlob(0.05, -0.05, 0.12, 0.09, 13, "softWeed"))
for (const n of ["duckweed_patch", "duckweed_patch_dense", "duckweed_ring", "duckweed_bits"]) looms(n)

// tendrils floating on the water: a flat stem curling, its end split into
// curls, a few round leaves along it
const WATER = { tendril: ["#9c9a1a", "#3e7a2e", "#8a4a20"], tendrilL: ["#c2bc34", "#5e9a40", "#b06a32"],
  murk: ["#56503e", "#464a4c", "#563e34"], glint: ["#e4dcbc", "#d8dce0", "#e8d4c4"] }
SET(WATER, 0.35)
SKINNED.push(...Object.keys(WATER))
// a flat ribbon through screen points [u, v] (y = 0.012): one tube in
// three stretches tapering from r0 to r1, squashed flat
const flatStem = (pts, r0, r1, mat = "tendril") => {
  const c = spline(pts.map(([u, v]) => [u, 0, v]), 5), n = c.length, out = []
  for (let k = 0; k < 3; k++) {
    const seg = c.slice(Math.floor(k * (n - 1) / 3), Math.floor((k + 1) * (n - 1) / 3) + 1)
    out.push(tube(seg.flatMap((p) => sp(p[0], 0.012, p[2])), r0 + (r1 - r0) * (k + 0.5) / 3, { mat, sides: 6, scale: [1, 0.35, 1] }))
  }
  return out
}
// a curl: a spiral in screen terms from (u, v), R across, turning `dir`
const curlPts = (u, v, R, dir, turns = 1.2, a0 = 0) => Array.from({ length: 10 }, (_, i) => {
  const t = i / 9, a = a0 + dir * t * turns * Math.PI * 2, r = R * (1 - 0.75 * t)
  return [u + Math.cos(a) * r, v + Math.sin(a) * r * 0.9]
})
const padLeaf = (u, v, r, mat = "tendrilL") => cyl(r, 0.01, { mat, sides: 8, pos: sp(u, 0.006, v), scale: [1, 1, 0.8] })
// S-tendril with a split end (2627): 0.65 m
model("tendril_s", { pivot: "origin" },
  flatStem([[-0.32, 0.16], [-0.1, 0.16], [-0.04, 0.05], [-0.14, -0.05], [0.04, -0.14], [0.2, -0.15]], 0.05, 0.03),
  flatStem([[0.2, -0.15], [0.3, -0.24], [0.26, -0.28]], 0.025, 0.015), flatStem([[0.2, -0.15], [0.34, -0.1]], 0.025, 0.015))
// big curl (2630): a long stem sweeping in from the top right into a loop
model("tendril_loop", { pivot: "origin" },
  flatStem([[0.32, -0.62], [0.22, -0.3], [-0.05, -0.05], [-0.3, 0.15], [-0.25, 0.4], [0.05, 0.45], [0.3, 0.3], [0.2, 0.1], [0.02, 0.15]], 0.07, 0.03),
  flatStem(curlPts(0.22, 0.28, 0.13, -1, 1.1, 0), 0.03, 0.018), padLeaf(0.38, 0.4, 0.06))
// small curls (2632): two curls on one short stem
model("tendril_curls", { pivot: "origin" },
  flatStem([[-0.36, 0.08], [-0.1, 0.02], [0.15, -0.04], [0.36, 0.0]], 0.035, 0.02),
  flatStem(curlPts(-0.15, -0.16, 0.16, 1, 1.1, Math.PI / 2), 0.028, 0.015), flatStem(curlPts(0.2, -0.2, 0.15, -1, 1.1, Math.PI / 2), 0.028, 0.015))
for (const n of ["tendril_s", "tendril_loop", "tendril_curls"]) looms(n)

// murky puddle (2661, owner: «mancha o líquido»): a shallow pool of dark
// water, 1 m across, light catching the ripples along its far rims
model("murky_puddle", { pivot: "origin" },
  flatBlob(0.0, 0.0, 0.5, 0.36, 17, "murk", 0.008),
  [[-0.36, -0.08, 0.2, -30], [-0.12, -0.24, 0.24, -8], [0.18, -0.24, 0.18, 12], [0.38, -0.06, 0.12, 40], [-0.2, 0.1, 0.14, -12], [0.1, 0.02, 0.12, 5]].map(([u, v, l, a], i) =>
    tf({ pos: sp(u, 0.008, v), rot: [0, 45 + a, 0] }, flatBlob(0, 0, l / 2, 0.025, 50 + i, "glint", 0.006))))
looms("murky_puddle")

// --- stumps with shelf mushrooms (group «planta de setas»: 2678-2682) ---------
// Mossy green stumps along the arena's edge, roots spreading over the ground,
// crowned by flat shelf mushrooms: round caps stacked and overlapping, pale
// with darker spots and a rust rim on 2678. 2681 and 2682 are 2678 and 2679
// in the shade of the edge (the map's light, not another plant).
const STUMP = { bark: ["#3a5626", "#4a3a26", "#2e3a3a"], barkL: ["#56763a", "#6a5434", "#465454"], barkD: ["#26381a", "#30261a", "#1e2828"],
  cap: ["#aca062", "#b88a48", "#987a9c"], capG: ["#9aa45e", "#a48e58", "#808ca8"], capRim: ["#8a5a2e", "#7a3e20", "#5a3e6a"],
  capUnder: ["#7e7a46", "#8a6a3a", "#6a5a7a"], spot: ["#9a9a6a", "#a07a44", "#8a7aa0"] }
SET(STUMP, 0.8)
SKINNED.push(...Object.keys(STUMP))
// a shelf cap at p (world), r across, tilted `tilt` degrees towards yaw;
// rim and underside below, the pale top, a few spots
const shelf = (p, r, mats = ["cap", "capRim"], tilt = 0, yaw = 0, seed = 1) => tf({ pos: p, rot: [0, yaw, 0] }, tf({ rot: [tilt, 0, 0] },
  cyl(r, 0.05, { mat: mats[1], sides: 12, top: r * 0.98, pos: [0, -0.05, 0] }),
  cyl(r * 0.97, 0.035, { mat: mats[0], sides: 12, top: r * 0.8, pos: [0, 0, 0] }),
  cyl(r * 0.7, 0.03, { mat: "capUnder", sides: 9, pos: [0, -0.075, 0] }),
  Array.from({ length: 3 + Math.round(r * 8) }, (_, i) => {
    const a = rnd(i, 1, seed) * Math.PI * 2, d = rnd(i, 2, seed) * r * 0.65
    return cyl(0.025 + rnd(i, 3, seed) * 0.03, 0.006, { mat: "spot", sides: 6, pos: [Math.cos(a) * d, 0.033, Math.sin(a) * d], scale: [1, 1, 0.8] })
  })))
// the caps of a stump h tall: [p, r, mats, tilt, yaw, seed] each; a cap
// whose underside clears the stump's cut top stands on its own stalk down
// into it, so nothing floats (the side shelves bite into the trunk)
const caps = (h, list) => list.map(([p, r, mats, tilt, yaw, seed]) => {
  const under = p[1] - 0.08
  return [shelf(p, r, mats, tilt, yaw, seed),
    under > h - 0.02 ? cyl(0.035 + r * 0.12, under - h + 0.06, { mat: "capUnder", sides: 6, top: 0.03 + r * 0.1, pos: [p[0], h - 0.03, p[2]] }) : []]
})
// a stump r wide at the foot, h tall: a flared lathe, root ridges down its
// sides running out over the ground
const stump = (r, h, seed, nRoots = 11) => [
  lathe([r * 1.2, 0, r * 1.02, 0.1, r * 0.95, h * 0.5, r * 0.92, h], { mat: "bark", sides: 8, jitter: 0.015, seed }),
  Array.from({ length: nRoots }, (_, i) => {
    const a = (i / nRoots + rnd(i, 1, seed) * 0.06) * Math.PI * 2, c = Math.cos(a), s = Math.sin(a)
    const top = h * (0.5 + rnd(i, 2, seed) * 0.45), out = r * (1.45 + rnd(i, 3, seed) * 0.45), bend = (rnd(i, 5, seed) - 0.5) * 0.5
    const cb = Math.cos(a + bend), sb = Math.sin(a + bend), rr = 0.018 + rnd(i, 4, seed) * 0.014
    return tube([c * r * 0.9, top, s * r * 0.9, c * r * 1.0, h * 0.35, s * r * 1.0, c * r * 1.18, 0.06, s * r * 1.18, cb * out, 0.012, sb * out],
      rr, { mat: i % 3 ? "barkL" : "barkD", sides: 5 })
  }),
  // the cut top, a little darker
  cyl(r * 0.88, 0.02, { mat: "barkD", sides: 8, pos: [0, h - 0.005, 0] }),
]
// squat stump crowned by a heap of caps (2678, 2681): 1.3 m
const CAP = ["cap", "capRim"], CAPG = ["capG", "capRim"]
model("mushroom_stump", stump(0.42, 0.55, 601), caps(0.55, [
  [[-0.18, 0.62, 0.22], 0.34, CAP, 10, 30, 1], [[0.26, 0.64, 0.1], 0.32, CAP, -12, 80, 2],
  [[0.02, 0.6, -0.28], 0.3, CAP, 12, 160, 3], [[-0.36, 0.5, -0.12], 0.26, CAP, -14, 220, 4],
  [[0.28, 0.45, 0.3], 0.22, CAP, 15, 10, 5], [[0.0, 0.8, 0.02], 0.3, CAP, -6, 50, 6],
  [[-0.12, 0.95, -0.08], 0.22, CAPG, 5, 0, 7], [[0.2, 0.92, -0.12], 0.18, CAPG, -8, 0, 10],
  [[-0.2, 1.1, 0.12], 0.12, CAPG, 0, 0, 8], [[0.08, 1.16, -0.18], 0.15, CAPG, 0, 0, 12],
  [[0.36, 0.28, -0.22], 0.15, CAP, -18, 270, 9], [[-0.34, 0.25, 0.26], 0.12, CAP, 15, 30, 11]]))
// tall stump (2679, 2682): a big cap on top, shelves round its sides at
// several heights; 1.5 m
model("mushroom_stump_tall", stump(0.3, 1.0, 611), caps(1.0, [
  [[0.0, 1.12, 0.0], 0.38, CAPG, 4, 20, 11],
  [[-0.3, 0.72, 0.1], 0.26, CAPG, -10, 200, 12], [[0.28, 0.8, 0.16], 0.24, CAPG, 10, 0, 13],
  [[0.1, 0.62, 0.32], 0.24, CAPG, 12, 40, 14], [[-0.1, 0.88, -0.3], 0.2, CAPG, -8, 130, 15],
  [[0.22, 0.35, 0.2], 0.1, CAPG, 8, 0, 16]]))
// shorter stump (2680): the caps bunched on top; 1.25 m
model("mushroom_stump_low", stump(0.32, 0.8, 621), caps(0.8, [
  [[-0.08, 0.98, 0.05], 0.34, CAPG, 6, 10, 21], [[0.26, 0.9, -0.1], 0.24, CAPG, -10, 90, 22],
  [[-0.28, 0.82, -0.05], 0.22, CAPG, 10, 200, 23], [[0.15, 0.78, 0.28], 0.24, CAPG, 12, 30, 24],
  [[-0.2, 0.62, 0.26], 0.12, CAPG, 8, 0, 25], [[0.1, 1.12, -0.16], 0.2, CAPG, -4, 0, 26]]))
for (const n of ["mushroom_stump", "mushroom_stump_tall", "mushroom_stump_low"]) looms(n)

// --- small marsh plants (group «plantita»: 2683, 2684, 2686) ------------------
// a low cushion of dark moss on the ground, round moss balls on it, and a few
// upright paddle leaves, spikes or fiddleheads
const MARSH = { moss: ["#4a6624", "#5a5a24", "#3a5a40"], mossL: ["#6e8a34", "#7e7a34", "#567a56"], mossD: ["#2e4416", "#3a3a16", "#24382a"],
  paddle: ["#5e8a2c", "#7a8a2e", "#4a7a52"], paddleL: ["#86ac40", "#a0aa42", "#6a9a6e"],
  stalk: ["#6a5a3a", "#5e5a4a", "#6a4a3a"], plume: ["#f4f2ea", "#f2e8d0", "#ece4f0"], plumeD: ["#c8c4b4", "#cab890", "#bcb0c4"],
  clod: ["#6a5e28", "#5a5446", "#6a3e2a"] }
SET(MARSH, 0.8)
SKINNED.push(...Object.keys(MARSH))
// the moss cushion: a flat blob, ru by rv (screen), with balls on it
const mossBed = (ru, rv, seed, balls) => [
  flatBlob(0, 0, ru, rv, seed, "mossD", 0.03),
  ...balls.map(([u, v, r], i) => sphere(r, { mat: i % 3 ? "moss" : "mossL", detail: 1, pos: sp(u, r * 0.5, v), scale: [1, 0.75, 1] })),
]
// an upright paddle leaf at (u, v): an oval slab h tall, leaning `lean`
// degrees to screen right, facing the camera
const paddleLeaf = (u, v, h, w, lean, mat = "paddle") => tf({ pos: sp(u, 0.02, v), rot: [0, 45, 0] }, tf({ rot: [0, 0, -lean] },
  sphere(0.5, { mat, detail: 1, pos: [0, h / 2, 0], scale: [w, h, 0.06] })))
// a thin spike or stalk through screen points, curling at its tip
const fiddle = (u, v, h, dir, seed) => {
  const pts = [[u, 0, v], [u + dir * 0.02, h * 0.6, v], [u + dir * 0.04, h * 0.95, v], [u + dir * 0.12, h * 1.02, v], [u + dir * 0.13, h * 0.9, v], [u + dir * 0.08, h * 0.88, v]]
  return stem(spline(pts, 3).map((p, i, a) => [...sp(...p), 0.018 * (1 - 0.6 * i / (a.length - 1))]), "paddle", 5)
}
// moss clump (2683): balls in a cushion, paddle leaves on the right, two
// thin spikes on the left; 1.2 m across
model("marsh_clump",
  mossBed(0.6, 0.38, 3, [[-0.25, 0.0, 0.12], [-0.05, 0.05, 0.16], [0.12, 0.12, 0.1], [-0.38, 0.12, 0.08], [0.0, -0.18, 0.1], [0.2, -0.08, 0.08]]),
  paddleLeaf(0.3, -0.05, 0.42, 0.2, -10, "paddleL"), paddleLeaf(0.45, 0.08, 0.32, 0.17, -25), paddleLeaf(0.15, 0.15, 0.26, 0.14, 5),
  stem([[...sp(-0.2, 0, -0.1), 0.02], [...sp(-0.24, 0.45, -0.1), 0.01]], "paddle", 4),
  stem([[...sp(-0.1, 0, -0.12), 0.02], [...sp(-0.06, 0.52, -0.12), 0.01]], "paddleL", 4))
// fiddleheads (2684): a small cushion, a stalk curled at its tip and a club
// stalk; 0.7 m
model("marsh_fiddle",
  mossBed(0.36, 0.24, 5, [[-0.12, 0.04, 0.08], [0.05, 0.08, 0.1], [0.18, -0.02, 0.07], [-0.02, -0.1, 0.07]]),
  fiddle(-0.08, -0.05, 0.55, -1, 1),
  stem([[...sp(0.12, 0, -0.06), 0.018], [...sp(0.15, 0.4, -0.06), 0.014], [...sp(0.2, 0.62, -0.06), 0.012]], "paddle", 5),
  sphere(0.035, { mat: "paddleL", detail: 1, pos: sp(0.2, 0.64, -0.06), scale: [0.8, 1.4, 0.8] }),
  paddleLeaf(0.25, 0.06, 0.18, 0.1, -20, "paddleL"))
// paddle plant (2686): two tall paddle leaves, a curved one, dark moss
model("marsh_paddles",
  mossBed(0.62, 0.42, 7, [[-0.3, 0.08, 0.12], [-0.1, 0.18, 0.1], [0.3, 0.12, 0.09], [-0.42, -0.05, 0.08]]),
  paddleLeaf(0.02, -0.08, 0.55, 0.22, 8), paddleLeaf(0.2, -0.12, 0.75, 0.24, -6, "paddleL"),
  paddleLeaf(0.28, 0.12, 0.35, 0.14, -30), paddleLeaf(-0.12, 0.05, 0.3, 0.14, 20, "paddleL"))
for (const n of ["marsh_clump", "marsh_fiddle", "marsh_paddles"]) looms(n)

// --- cotton grass (group «flor blanca»: 2668, 2669, 2670) ---------------------
// a few thin brown stems rising out of a muddy clod, bowing to the right,
// each topped by a white feathery plume that droops to the right
// a plume: feather strips hung along the top of a stem (screen points),
// each blown out to the right and a little down, longer near the tip
const PLUME = [[0.08, 0.1], [0.11, 0.35], [0.09, 0.65], [0.05, 0.88], [0, 1]]
const featherStrip = (p, len, ang, mat, seed) => {
  const pts = [0, 0, ...PLUME.flatMap(([w, y]) => [w * len * 1.0, y * len]), ...PLUME.slice(0, -1).reverse().flatMap(([w, y]) => [-w * len * 0.7, y * len])]
  // in the plane facing the camera: rot z turns it from up towards the right
  return tf({ pos: p, rot: [0, 45, 0] }, tf({ rot: [(rnd(1, 3, seed) - 0.5) * 40, 0, -ang] }, extrude(pts, 0.01, { mat })))
}
// a stem from (u, v) rising h, bowing `bow` metres to screen right, its top
// third hung with feather strips s long
const cottonStem = (u, v, h, bow, s, seed) => {
  const pts = spline([[u, 0, v], [u + bow * 0.15, h * 0.4, v], [u + bow * 0.55, h * 0.8, v], [u + bow, h, v]], 4)
  const n = pts.length, feathers = []
  for (let k = 0; k < 6; k++) {
    const i = n - 1 - Math.floor(k * n * 0.3 / 6), t = k / 5
    const len = s * (1 - t * 0.45) * (0.85 + rnd(k, 1, seed) * 0.3)
    feathers.push(featherStrip(sp(...pts[i]), len, 55 + t * 45 + (rnd(k, 2, seed) - 0.5) * 20, k % 3 === 2 ? "plumeD" : "plume", seed * 7 + k))
  }
  return [stem(pts.map((p, i) => [...sp(...p), 0.014 - 0.006 * i / (n - 1)]), "stalk", 4), feathers]
}
const clods = (n, r, seed) => Array.from({ length: n }, (_, i) => {
  const a = rnd(i, 1, seed) * Math.PI * 2, d = r * (0.3 + rnd(i, 2, seed) * 0.7)
  return cyl(0.04 + rnd(i, 3, seed) * 0.04, 0.03, { mat: "clod", sides: 6, top: 0.03, pos: sp(Math.cos(a) * d, 0, Math.sin(a) * d * 0.7), scale: [1.4, 1, 1] })
})
// cotton grass (2668): five stems, 1.6 m
model("cotton_grass",
  clods(9, 0.3, 1),
  cottonStem(-0.05, 0, 1.6, 0.15, 0.36, 11), cottonStem(0.02, 0.03, 1.4, 0.32, 0.34, 12), cottonStem(-0.08, -0.02, 1.1, -0.06, 0.26, 13),
  cottonStem(0.05, 0.0, 1.0, 0.34, 0.28, 14), cottonStem(-0.02, 0.02, 0.8, 0.22, 0.24, 15), cottonStem(0.0, -0.03, 1.25, 0.05, 0.28, 16))
// small cotton grass (2669): four stems, 1.35 m
model("cotton_grass_small",
  clods(7, 0.22, 2),
  cottonStem(-0.04, 0, 1.35, 0.08, 0.3, 21), cottonStem(0.02, 0.02, 1.15, 0.24, 0.28, 22), cottonStem(0.0, -0.02, 0.9, 0.3, 0.24, 23),
  cottonStem(0.04, 0.01, 0.7, 0.24, 0.22, 24))
// tall cotton grass (2670): five stems, 2.1 m
model("cotton_grass_tall",
  clods(8, 0.26, 3),
  cottonStem(-0.04, 0, 2.1, 0.1, 0.44, 31), cottonStem(0.02, 0.02, 1.8, 0.36, 0.4, 32), cottonStem(-0.06, -0.02, 1.45, -0.05, 0.32, 33),
  cottonStem(0.04, 0.0, 1.25, 0.32, 0.32, 34), cottonStem(0.0, 0.02, 0.95, 0.26, 0.26, 35))
for (const n of ["cotton_grass", "cotton_grass_small", "cotton_grass_tall"]) looms(n)

// --- walkways of planks over the water (group «tablas»: 1204, 1206, 1296;
// their posts 1207, 1297) -----------------------------------------------------
// a cell-sized raft: two round logs along z, planks laid across them along x
// (a few askew), a plank or two along z on top to hold them; mossy spots
const WOOD = { log: ["#6e5a2a", "#6a6458", "#5a3a22"], logEnd: ["#a08850", "#9a9284", "#8a6a48"], logEndD: ["#6a5a30", "#625c52", "#5a4028"],
  rope: ["#d8cc98", "#c8c0b0", "#c8a878"], ropeD: ["#a89a68", "#9a9284", "#9a7a50"], mossy: ["#6a7a20", "#5a7a3a", "#7a6a20"] }
SET(WOOD, 0.85)
SKINNED.push(...Object.keys(WOOD))
const log = (x, y, z, len, r, seed) => tf({ pos: [x, y, z], rot: [90, 0, 0] },
  cyl(r, len, { mat: "log", sides: 8, pos: [0, -len / 2, 0], jitter: 0.008, seed }),
  cyl(r * 0.96, 0.012, { mat: "logEnd", sides: 8, pos: [0, len / 2 - 0.006, 0] }), cyl(r * 0.45, 0.014, { mat: "logEndD", sides: 6, pos: [0, len / 2 - 0.004, 0] }),
  cyl(r * 0.96, 0.012, { mat: "logEnd", sides: 8, pos: [0, -len / 2 - 0.006, 0] }))
// a plank: len along x (or z when alongZ), w wide, at height y, yaw degrees
const plank = (x, y, z, len, w, yaw, mat = "board", alongZ = false) => tf({ pos: [x, y, z], rot: [0, yaw + (alongZ ? 90 : 0), 0] },
  box(len, 0.045, w, { mat, jitter: 0.005 }))
const mossDots = (n, y, seed) => Array.from({ length: n }, (_, i) =>
  cyl(0.02 + rnd(i, 1, seed) * 0.025, 0.008, { mat: "mossy", sides: 6, pos: [(rnd(i, 2, seed) - 0.5) * 0.8, y, (rnd(i, 3, seed) - 0.5) * 0.8] }))
const RAFT_Y = 0.2   // the top of the logs
const raftLogs = (seed) => [log(-0.3, 0.11, 0, 0.98, 0.11, seed), log(0.28, 0.11, 0.02, 1.0, 0.11, seed + 1)]
// raft (1204): five planks across, one askew, two along z on top
model("plank_raft", raftLogs(1),
  plank(0, RAFT_Y, -0.38, 0.98, 0.16, 2, "boardD"), plank(0.02, RAFT_Y, -0.2, 0.94, 0.15, -3), plank(-0.02, RAFT_Y, -0.02, 1.0, 0.16, 1, "boardD"),
  plank(0.03, RAFT_Y, 0.17, 0.92, 0.15, -4), plank(0, RAFT_Y, 0.36, 0.98, 0.16, 6),
  plank(-0.18, RAFT_Y + 0.045, 0.0, 0.95, 0.15, 3, "board", true), plank(0.2, RAFT_Y + 0.045, -0.05, 0.85, 0.14, -8, "board", true),
  mossDots(10, RAFT_Y + 0.07, 3))
// raft (1206): three wide planks across with gaps, one long plank along z
model("plank_raft_wide", raftLogs(11),
  plank(0, RAFT_Y, -0.32, 1.0, 0.22, 3, "boardD"), plank(0, RAFT_Y, 0.0, 0.96, 0.22, -2), plank(0.02, RAFT_Y, 0.32, 1.0, 0.2, 2, "boardD"),
  plank(0.05, RAFT_Y + 0.045, 0.0, 1.0, 0.18, 4, "board", true), plank(-0.3, RAFT_Y + 0.045, 0.1, 0.6, 0.13, -6, "board", true),
  mossDots(8, RAFT_Y + 0.05, 13))
// raft (1296): planks across with a wide gap, one plank along z over it
model("plank_raft_gap", raftLogs(21),
  plank(0, RAFT_Y, -0.36, 0.96, 0.18, -2), plank(0.03, RAFT_Y, -0.16, 0.9, 0.16, 4, "boardD"),
  plank(0, RAFT_Y, 0.22, 0.98, 0.17, -3), plank(-0.02, RAFT_Y, 0.4, 0.94, 0.15, 2, "boardD"),
  plank(0.0, RAFT_Y + 0.045, 0.0, 1.0, 0.17, -3, "board", true),
  mossDots(8, RAFT_Y + 0.05, 23))
for (const n of ["plank_raft", "plank_raft_wide", "plank_raft_gap"]) looms(n)

// posts under the walkways: round timber posts, their cut tops bevelled,
// coils of rope round their feet (and round the top of the leaning one)
const rope = (y0, n, r, seed) => Array.from({ length: n }, (_, i) =>
  torus(r + 0.03, 0.032, { mat: i % 2 ? "ropeD" : "rope", rings: 12, sides: 5, pos: [0, y0 + 0.02 + i * 0.058, 0], rot: [(rnd(i, 1, seed) - 0.5) * 8, 0, (rnd(i, 2, seed) - 0.5) * 8] }))
const post = (len, r, ropes, seed) => [
  cyl(r, len, { mat: "log", sides: 7, jitter: 0.006, seed }),
  cyl(r * 0.92, 0.02, { mat: "logEnd", sides: 7, pos: [0, len, 0], rot: [12, 0, 0] }),
  ropes.map(([y, n]) => rope(y, n, r, seed + y * 10)),
]
// two posts (1207): one leaning, roped at its foot and near its top; a short
// upright one roped at its foot
model("rope_posts",
  tf({ pos: sp(-0.35, 0, -0.05), rot: [0, 45, 0] }, tf({ rot: [0, 0, -18] }, post(1.25, 0.09, [[0.0, 3], [0.75, 4]], 1))),
  tf({ pos: sp(0.1, 0, 0.12) }, post(0.62, 0.1, [[0.0, 5]], 2)),
  tf({ pos: sp(0.48, 0, -0.1), rot: [0, 45, 0] }, tf({ rot: [0, 0, 8] }, box(0.08, 0.95, 0.06, { mat: "log", jitter: 0.006 }))))
// trestle (1297): two posts leaning together under a crossbeam, one roped at
// its foot; a short roped post beside it
model("rope_trestle",
  tf({ pos: sp(-0.3, 0, 0), rot: [0, 45, 0] }, tf({ rot: [0, 0, -12] }, post(1.05, 0.065, [], 3))),
  tf({ pos: sp(0.18, 0, 0.02), rot: [0, 45, 0] }, tf({ rot: [0, 0, 4] }, post(1.0, 0.075, [[0.02, 4]], 4))),
  tf({ pos: sp(-0.08, 1.0, 0), rot: [0, 45, 0] }, tf({ rot: [0, 0, -8] }, box(0.62, 0.11, 0.11, { mat: "log", jitter: 0.006 }))),
  tf({ pos: sp(0.5, 0, 0.1) }, post(0.5, 0.075, [[0.02, 4]], 5)))
for (const n of ["rope_posts", "rope_trestle"]) looms(n)

// --- shovel stuck in a heap of stones (790) ----------------------------------
// a short spade, its T-grip thick, leaning back and right in red stones
const SHOVEL = { blade: ["#9aa2a4", "#7a7e80", "#a08a60"], bladeD: ["#5e6668", "#4a4e50", "#6a5a3a"], haft: ["#a4702e", "#8a7a62", "#6a4422"],
  haftL: ["#c89040", "#a8987e", "#8a5a30"], stoneR: ["#b45a2e", "#8a8478", "#7a6a5a"], stoneRD: ["#7a3a1e", "#5e5a52", "#52463a"] }
SET(SHOVEL, 0.6)
SKINNED.push(...Object.keys(SHOVEL))
model("shovel",
  // the stones round its foot
  [[-0.14, 0.08, 0.09], [0.12, 0.1, 0.08], [0.02, 0.16, 0.07], [-0.2, -0.08, 0.07], [0.22, -0.06, 0.06], [-0.04, -0.14, 0.065], [0.0, 0.0, 0.08]].map(([u, v, r], i) =>
    rock(r, { mat: i % 3 ? "stoneR" : "stoneRD", seed: 70 + i, pos: sp(u, r * 0.5, v) })),
  // blade buried to a third, leaning a little back and to the right
  tf({ pos: sp(0, 0.0, 0), rot: [0, 45, 0] }, tf({ rot: [-8, 0, -10] },
    extrude([-0.12, 0.0, 0.12, 0.0, 0.13, 0.22, 0.05, 0.3, -0.05, 0.3, -0.13, 0.22], 0.025, { mat: "blade" }),
    box(0.07, 0.12, 0.045, { mat: "bladeD", pos: [0, 0.28, 0] }),
    cyl(0.04, 0.42, { mat: "haft", sides: 6, pos: [0, 0.36, 0] }),
    tf({ pos: [0, 0.8, 0], rot: [0, 0, 90] }, cyl(0.05, 0.3, { mat: "haftL", sides: 6, pos: [0, -0.15, 0] })))))
looms("shovel")

// --- broken canes in the mud (group «tronquito»: 2673-2676) and mud bubbles
// (group «burbuja de barro»: 2671, 2672) ------------------------------------
// a thick olive cane snapped off, leaning, its node rings proud, its broken
// top hollow and jagged; green slime running down one side; pale mud balls
// and grey mud bubbles round its foot on a dark wet stain
const CANE = { cane: ["#848024", "#6a7a34", "#8a6a2a"], caneL: ["#a49e36", "#88984a", "#a8843a"], caneD: ["#5e5a14", "#46561e", "#64481a"],
  slime: ["#a8b414", "#6aa828", "#c49a18"], ball: ["#c4b48a", "#b4b0a4", "#c4a48a"], bubble: ["#5a544a", "#4a4c50", "#5a4840"],
  wet: ["#3a3828", "#2e3030", "#3a2e26"] }
SET(CANE, 0.6)
pal(Object.fromEntries(LOOMS.map((s, i) => ["bubble" + s, { color: CANE.bubble[i], rough: 0.2 }])))
SKINNED.push(...Object.keys(CANE))
// a cane r thick, len long, leaning `lean` degrees towards screen yaw; nodes
// every `node` metres; its top a hollow ring cut jagged
const cane = (p, r, len, lean, yaw, seed, node = 0.45) => tf({ pos: p, rot: [0, yaw + 45, 0] }, tf({ rot: [0, 0, -lean] },
  cyl(r, len, { mat: "cane", sides: 8, jitter: 0.004, seed }),
  Array.from({ length: Math.floor(len / node) }, (_, i) => cyl(r * 1.08, 0.04, { mat: "caneL", sides: 8, pos: [0, (i + 1) * node - 0.02, 0] })),
  // the broken top: five teeth round the rim, the hollow dark inside
  Array.from({ length: 5 }, (_, k) => { const a = k / 5 * Math.PI * 2 + seed
    return tf({ pos: [Math.cos(a) * r * 0.75, len - 0.01, Math.sin(a) * r * 0.75], rot: [Math.sin(a) * 14, 0, -Math.cos(a) * 14] },
      cone(r * 0.5, 0.12 + rnd(k, 1, seed) * 0.2, { mat: k % 2 ? "caneL" : "cane", sides: 3 })) }),
  cyl(r * 0.72, 0.03, { mat: "caneD", sides: 8, pos: [0, len - 0.02, 0] }),
  // slime down its right side
  [0.15, 0.4, 0.62, 0.85].map((t, k) => tube([r * 0.92, len * t, r * 0.3, r * 1.0, len * t - 0.12, r * 0.35, r * 1.02, Math.max(0.02, len * t - 0.28 - k * 0.12), r * 0.3], 0.016 + (k % 2) * 0.008, { mat: "slime", sides: 5 })),
  [0.3, 0.7].map((t) => tube([-r * 0.3, len * t, r * 0.92, -r * 0.35, len * t - 0.2, r * 1.0], 0.015, { mat: "slime", sides: 5 }))))
// a bubble of mud: a glossy grey dome standing on the ground
const bubble = (u, v, r) => lathe([r, 0, r * 0.97, r * 0.25, r * 0.85, r * 0.5, r * 0.6, r * 0.72, r * 0.3, r * 0.83, 0, r * 0.86], { mat: "bubble", sides: 12, pos: sp(u, 0, v) })
const balls = (list) => list.map(([u, v, r], i) => sphere(r, { mat: "ball", detail: 1, pos: sp(u, r * 0.6, v), scale: [1, 0.85, 1] }))
const stain = (ru, rv, seed) => flatBlob(0, 0, ru, rv, seed, "wet", 0.008)
const leafBlade = (p, len, ang, yaw) => tf({ pos: p, rot: [0, yaw + 45, 0] }, tf({ rot: [0, 0, -ang] },
  extrude([0, 0, 0.04, len * 0.3, 0.035, len * 0.7, 0, len, -0.02, len * 0.6, -0.025, len * 0.3], 0.008, { mat: "slime" })))
// tall broken cane (2673): 1.7 m, leaning right, a leaf, mud balls round it
model("broken_cane",
  stain(0.45, 0.3, 1), cane(sp(0, 0, 0), 0.11, 1.75, 12, 0, 1),
  leafBlade(sp(0.12, 0.65, 0.05), 0.4, 70, 0), balls([[0.0, 0.12, 0.09], [0.15, 0.1, 0.07], [-0.3, 0.05, 0.06], [-0.4, 0.14, 0.05]]),
  bubble(-0.38, -0.12, 0.08))
// tall broken cane (2675): 1.7 m, nearly upright, a leaf on the left
model("broken_cane_tall",
  stain(0.45, 0.3, 2), cane(sp(0, 0, 0), 0.12, 1.7, 8, 0, 2),
  leafBlade(sp(0.04, 0.85, 0.05), 0.35, -55, 0), balls([[0.05, 0.12, 0.09], [-0.12, 0.14, 0.06]]), bubble(-0.4, -0.05, 0.08))
// short broken cane (2674): 1 m, leaning right, a big bubble in front
model("broken_cane_short",
  stain(0.45, 0.3, 3), cane(sp(0, 0, 0), 0.1, 1.0, 12, 0, 3, 0.4),
  balls([[-0.08, 0.1, 0.08], [0.06, 0.12, 0.07], [-0.25, 0.05, 0.06]]), bubble(0.3, 0.25, 0.14))
// stub of cane (2676): 0.85 m, a leaf, a big bubble beside it
model("broken_cane_stub",
  stain(0.45, 0.3, 4), cane(sp(0, 0, 0), 0.1, 0.85, 10, 0, 4, 0.4),
  leafBlade(sp(0.02, 0.5, 0.04), 0.3, -60, 0), balls([[-0.1, 0.12, 0.08], [0.1, 0.1, 0.08], [-0.25, 0.0, 0.05]]), bubble(0.35, 0.2, 0.15))
for (const n of ["broken_cane", "broken_cane_tall", "broken_cane_short", "broken_cane_stub"]) looms(n)
// mud bubbles (2671): two domes and a few specks on a wet stain
model("mud_bubbles", stain(0.32, 0.22, 5), bubble(0.0, -0.05, 0.1), bubble(-0.13, 0.05, 0.07),
  bubble(0.15, 0.08, 0.025), bubble(0.2, -0.04, 0.02), bubble(-0.05, 0.14, 0.02))
// a mud bubble (2672): one dome
model("mud_bubble", bubble(0, 0, 0.17))
for (const n of ["mud_bubbles", "mud_bubble"]) looms(n)

// --- the swamp's big vines (group «enredadera»: 2618, 2619, 2621, 2624,
// 2625) and the hanging lianas (2649) ------------------------------------------
// thick olive vines, smooth and fleshy, swelling at the foot, crowded in
// places with lime berries; a thin flat tendril twines round them and ends
// in a hook; the cut ones show pale rings. A clod of mud at their foot.
const VINE = { vine: ["#7e7c12", "#46702a", "#6e5220"], vineL: ["#9c9a1e", "#5e8a36", "#8a6c2a"], vineD: ["#5e5e0c", "#2e5018", "#4e3612"],
  berry: ["#c8d040", "#a4cc4e", "#d8a040"], berryL: ["#e4ea74", "#c8e47a", "#f0c46a"], cut: ["#b89a2a", "#8aa04a", "#b07a3a"], cutD: ["#8a6e14", "#5e7a2e", "#7a4e1e"],
  liana: ["#8ab81a", "#4a9a3a", "#a8a028"], lianaL: ["#c4e83a", "#7ac45a", "#d4cc48"] }
SET(VINE, 0.55)
SKINNED.push(...Object.keys(VINE))
// a fleshy vine through screen points [u, y, v], r0 at the foot to r1
const vine = (pts, r0, r1, mat = "vine", n = 4, taper = 0.7) => {
  const c = spline(pts, n), L = c.length
  return stem(c.map((p, i) => [...sp(...p), r0 + (r1 - r0) * Math.pow(i / (L - 1), taper)]), mat, 8)
}
// a crowd of berries round a point (screen), spread ru x ry
const berries = (u, y, v, ru, ry, n, seed) => Array.from({ length: n }, (_, i) =>
  sphere(0.035 + rnd(i, 1, seed) * 0.03, { mat: i % 3 ? "berry" : "berryL", detail: 1,
    pos: sp(u + (rnd(i, 2, seed) - 0.5) * ru * 2, y + (rnd(i, 3, seed) - 0.5) * ry * 2, v + 0.04 + rnd(i, 4, seed) * 0.06) }))
// the cut face of a vine at its end: pale rings, facing along the last span
const cutEnd = (pts, r) => {
  const a = sp(...pts[pts.length - 2]), b = sp(...pts[pts.length - 1])
  const d = [b[0] - a[0], b[1] - a[1], b[2] - a[2]], len = Math.hypot(...d)
  return tf({ pos: b, rot: [0, Math.atan2(-d[2], d[0]) * DEG, 0] }, tf({ rot: [0, 0, -Math.acos(d[1] / len) * DEG] },
    cyl(r * 0.98, 0.02, { mat: "cut", sides: 8 }), cyl(r * 0.6, 0.026, { mat: "cutD", sides: 8 }), cyl(r * 0.3, 0.03, { mat: "cut", sides: 6 })))
}
const clod = (r, seed) => [flatBlob(0, 0, r, r * 0.7, seed, "wet", 0.008),
  ...Array.from({ length: 9 }, (_, i) => { const a = rnd(i, 1, seed) * Math.PI * 2, d = r * (0.3 + rnd(i, 2, seed) * 0.6)
    return cyl(0.05 + rnd(i, 3, seed) * 0.05, 0.035, { mat: "clod", sides: 6, top: 0.035, pos: sp(Math.cos(a) * d, 0, Math.sin(a) * d * 0.7), scale: [1.4, 1, 1] }) })]
// a thin flat tendril through screen points (r flattened across the view)
const ribbon = (pts, r, mat = "vineL") => {
  const c = spline(pts, 4)
  return tube(c.flatMap((p) => sp(...p)), r, { mat, sides: 6 })
}
// tall vine (2621): 4.3 m, a fat foot crowded with berries, bowing left
// then right, a thin vine twining up it into a hook over the top
const TALL = [[0.05, -0.02, 0], [0.12, 0.6, 0], [0.04, 1.4, 0], [-0.1, 2.2, 0], [-0.12, 2.8, 0], [-0.04, 3.2, 0]]
model("vine_tall", { pivot: "origin" }, clod(0.5, 1),
  vine(TALL, 0.32, 0.07, "vine", 5, 1.3),
  berries(0.3, 0.55, 0.12, 0.1, 0.3, 30, 1), berries(-0.12, 1.75, 0.1, 0.08, 0.22, 18, 2),
  ribbon([[-0.34, 0.0, 0.12], [-0.32, 0.4, 0.2], [0.1, 0.9, 0.3], [0.36, 1.3, 0.05], [0.0, 1.8, 0.22], [-0.25, 2.3, 0.1], [-0.05, 2.75, 0.15], [-0.15, 3.2, 0.08], [0.0, 3.9, 0], [0.3, 4.15, 0], [0.4, 3.85, 0], [0.32, 3.6, 0]], 0.045),
  ribbon([[-0.3, 0.45, 0.1], [-0.48, 0.6, 0.1], [-0.56, 0.5, 0.1]], 0.03))
// vine loop (2625): 2.6 m, rising and curling into a loop to the left, a
// berry crowd at its end; a thin hook rising behind
const LOOP = [[0.15, -0.02, 0], [0.18, 0.9, 0], [0.05, 1.55, 0], [-0.25, 1.75, 0], [-0.55, 1.5, 0], [-0.55, 1.1, 0], [-0.3, 0.95, 0.05]]
model("vine_loop", { pivot: "origin" }, clod(0.45, 2),
  vine(LOOP, 0.2, 0.14, "vine"), berries(-0.62, 1.22, 0.06, 0.08, 0.15, 18, 3),
  ribbon([[0.1, 1.2, -0.05], [0.15, 1.9, -0.05], [0.2, 2.4, -0.05], [0.45, 2.55, -0.05], [0.55, 2.35, -0.05]], 0.06, "vine"))
// cut vine (2618): a thick stem rising aslant from the mud, cut, a thin
// vine looping round it
const CUT = [[-0.25, -0.02, 0], [-0.12, 0.35, 0], [0.12, 0.62, 0], [0.38, 0.72, 0]]
model("vine_cut", { pivot: "origin" }, clod(0.5, 3),
  vine(CUT, 0.24, 0.22, "vine", 3), cutEnd(spline(CUT, 3), 0.22),
  ribbon([[-0.35, 0.05, 0.1], [-0.15, 0.6, 0.18], [0.05, 1.2, 0.05], [0.3, 1.3, -0.1], [0.42, 1.05, -0.1], [0.25, 0.7, 0.15], [0.05, 0.35, 0.2]], 0.035))
// short cut vine (2624): an upright cut stem, a tendril curling round it
const STUB = [[0.0, -0.02, 0], [0.02, 0.45, 0], [-0.02, 0.8, 0], [0.0, 1.0, 0]]
model("vine_stub", { pivot: "origin" }, clod(0.45, 4),
  vine(STUB, 0.2, 0.17, "vine", 3), sphere(0.2, { mat: "vine", detail: 2, pos: sp(-0.01, 0.75, 0), scale: [1, 1.4, 1] }), cutEnd(spline(STUB, 3), 0.15),
  ribbon([[-0.25, 0.25, 0.1], [-0.05, 0.45, 0.2], [0.18, 0.7, 0.1], [0.08, 1.0, 0.0], [0.22, 1.1, 0.05], [0.32, 0.95, 0.1], [0.25, 0.85, 0.12]], 0.03))
// vine over the edge (2619): a fat cut length of vine lying on the top of
// the island's edge (y = 0; the drop is on its +v side, towards the camera,
// at v = 0.15), bent down at its far end, berries on top, leaves hanging
// down the face below it. Turn it to face the drop.
const LYING = [[-0.6, 0.24, 0.0], [-0.15, 0.25, 0.0], [0.28, 0.22, 0.0], [0.52, -0.1, 0.12]]
const hangLeaf = (u, y, v, len, a) => tf({ pos: sp(u, y, v), rot: [0, 45, 0] }, tf({ rot: [0, 0, 180 + a] },
  extrude([0, 0, 0.09, len * 0.3, 0.08, len * 0.7, 0, len, -0.06, len * 0.6, -0.07, len * 0.3], 0.01, { mat: "vineD" })))
model("vine_over_edge", { pivot: "origin" },
  vine(LYING, 0.25, 0.23, "vine", 3), cutEnd(spline(LYING, 3), 0.23), sphere(0.24 * Math.cos(Math.PI / 8), { mat: "vine", detail: 2, pos: sp(-0.6, 0.24, 0.0) }),
  berries(0.15, 0.46, -0.02, 0.22, 0.05, 26, 5),
  [[-0.3, 0.0, 0.6, 8], [-0.15, 0.02, 0.75, -4], [-0.05, 0.01, 0.55, 18], [0.05, 0.03, 0.5, -15], [-0.22, 0.02, 0.45, -20]].map(([u, v, len, a]) => hangLeaf(u, 0.05, v + 0.17, len, a)),
  stem([[...sp(-0.1, 0.08, 0.1), 0.03], [...sp(-0.1, 0.02, 0.18), 0.025], [...sp(-0.08, -0.45, 0.2), 0.02]], "vineD", 5))
for (const n of ["vine_tall", "vine_loop", "vine_cut", "vine_stub", "vine_over_edge"]) looms(n)

// lianas (2649): five strands hanging down a cliff face from its top edge
// (y = 0), each with a little leafy cap lying over the edge, twisting as
// they hang, 1.4 m. The face is the plane x = 0, facing +x, like the arena
// 9 whip.
const strand = (z, len, seed) => {
  const pts = [[-0.12, 0.03, z], [0.0, 0.04, z], [0.05, -0.04, z], ...Array.from({ length: 6 }, (_, i) => { const t = (i + 1) / 6
    return [0.05 + 0.02 * Math.sin(t * 9 + seed), -len * t, z + 0.07 * Math.sin(t * 7 + seed * 2)] })]
  const pts2 = pts.slice(2, 7).map(([x, y, zz], i) => [x + 0.01, y, zz + 0.05 * Math.sin(i * 1.7 + seed)])
  return [tube(spline(pts, 3).flat(), 0.034, { mat: "liana", sides: 6 }), tube(spline(pts2, 3).flat(), 0.022, { mat: "liana", sides: 5 }),
    tube(spline(pts.slice(0, 3), 3).flat(), 0.045, { mat: "lianaL", sides: 6 })]
}
model("lianas", { pivot: "origin" }, strand(-0.32, 1.3, 1), strand(-0.12, 1.5, 4), strand(0.05, 1.4, 2), strand(0.2, 1.2, 5), strand(0.36, 1.1, 3))
looms("lianas")
