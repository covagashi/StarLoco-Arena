// Arena 10 (retail world 41: a butcher's kitchen) — loom textures for its own
// broad surfaces, three looms each (mat, mat_b, mat_c).
const SUF = { a: "", b: "_b", c: "_c" }
const skins = (sets) => {
  for (const [k, s] of Object.entries(sets))
    pal(Object.fromEntries(Object.entries(s).map(([n, v]) => [n + k, v])))
}

// --- paver: the fired bricks of the kitchen floor (2736) ----------------------
// a smooth fired clay face: broad soft clouds of tone, a mid scale of worn
// smears and shallow chips, fine grit and a few pin holes; paler where it is
// worn high, a little grime in the hollows. Kept light: kit.kx.js tints the
// bricks darker than the joints.
//   a cream (retail)   b grey slate   c terracotta
skins({
  a: { p0: "#8c8466", p1: "#cfc6a2", p2: "#e2dab8", p3: "#f2ecd2" },
  b: { p0: "#5e605e", p1: "#a6a8a4", p2: "#bebfba", p3: "#d4d4ce" },
  c: { p0: "#7a3e28", p1: "#c47a56", p2: "#d6906a", p3: "#e6a882" },
})
{
  const cloud = noise({ scale: 3, octaves: 3, seed: 1001 }).warp(noise({ scale: 2, seed: 1002 }), 0.15).as("cloud")
  const smear = noise({ scale: 11, octaves: 3, seed: 1003 }).warp(noise({ scale: 5, seed: 1004 }), 0.08).as("smear")
  const fine = noise({ scale: 70, octaves: 2, seed: 1005 })
  const chips = dots({ scale: 9, radius: 0.18, jitter: 1, soft: 0.3, seed: 1006 })
    .mul(noise({ scale: 4, seed: 1007 }).threshold(0.62, 0.1)).as("chips")
  const pins = dots({ scale: 22, radius: 0.08, jitter: 1, seed: 1008 }).mul(noise({ scale: 3, seed: 1009 }).threshold(0.5, 0.2)).as("pins")
  const h = cloud.mul(0.25).add(smear.mul(0.3)).add(fine.mul(0.08)).sub(chips.mul(0.2)).sub(pins.mul(0.12)).as("paverH")
  const worn = h.convex(0.01, 10).as("worn")
  const grime = h.cavity(0.008, 10).max(chips.mul(0.5)).as("grime")
  for (const k of "abc") {
    const col = (n) => n + k
    material("paver" + SUF[k], { size: 512, depth: 0.012, ao: 0.5 }, {
      height: h,
      color: ramp(cloud.mix(smear, 0.4).levels(0.3, 0.7, 0, 1), [col("p1"), col("p2"), col("p2"), col("p3")])
        .mix(col("p3"), worn.mul(0.35)).mix(col("p0"), grime.mul(0.45)).mix(col("p0"), pins.mul(0.5)),
      rough: worn.levels(0, 1, 0.85, 0.6),
    })
  }
}

// --- blood: the river of blood, its gutters and falls (2458, 2459, 2461-2472,
// 474) ------------------------------------------------------------------------
// a thick, glossy liquid: broad slow swirls of darker and brighter red, a mid
// scale of ripples, a fine sheen; bloodFlow is the same liquid stretched into
// streaks along v (down a box-projected wall), for the falls. The colours follow arena 9's blood drain.
//   a red blood (retail)   b black ichor   c green slime
skins({
  a: { b0: "#3a0806", b1: "#640c08", b2: "#8c140e", b3: "#c0302a" },
  b: { b0: "#121014", b1: "#26222a", b2: "#3a3440", b3: "#5a5262" },
  c: { b0: "#16240a", b1: "#22380e", b2: "#38581a", b3: "#5e8a30" },
})
{
  for (const [name, sc] of [["blood", (s) => s], ["bloodFlow", (s) => [s * 3, Math.max(1, Math.round(s / 3))]]]) {
    const swirl = noise({ scale: sc(3), octaves: 3, seed: 1101 }).warp(noise({ scale: sc(2), seed: 1102 }), 0.25).as("swirl")
    const ripple = noise({ scale: sc(9), octaves: 2, seed: 1103 }).warp(noise({ scale: sc(4), seed: 1104 }), 0.1).as("ripple")
    const fine = noise({ scale: sc(40), octaves: 2, seed: 1105 })
    const h = swirl.mul(0.4).add(ripple.mul(0.4)).add(fine.mul(0.05)).as("bloodH")
    const sheen = ripple.levels(0.62, 0.8, 0, 1).mul(swirl.levels(0.4, 0.7, 0.3, 1)).as("sheen")
    for (const k of "abc") {
      const col = (n) => n + k
      material(name + SUF[k], { size: 512, depth: 0.006, ao: 0.2 }, {
        height: h,
        color: ramp(swirl.mix(ripple, 0.35).levels(0.25, 0.75, 0, 1), [col("b1"), col("b1"), col("b2"), col("b2")])
          .mix(col("b3"), sheen.mul(0.55)),
        rough: sheen.levels(0, 1, 0.3, 0.12),
      })
    }
  }
}

// --- cloth: the checked tablecloths (2651) ------------------------------------
// a cotton cloth in big checks: the weave fine, the checks a touch uneven in
// tone, a few stains and soft creases; eight checks to a tile
//   a red and white (retail)   b blue and white   c green and cream
skins({
  a: { c0: "#b03a12", c1: "#d24a18", w0: "#e8e2da", w1: "#faf8f2", st: "#7a3020" },
  b: { c0: "#2a4a8a", c1: "#3a5ea6", w0: "#e2e4ea", w1: "#f8f8fc", st: "#4a3a30" },
  c: { c0: "#3a6a2e", c1: "#4c823a", w0: "#e8e2c8", w1: "#f8f2dc", st: "#5a4a2a" },
})
{
  const chk = checker({ cols: 8 }).as("checks")
  const thread = weave({ threads: 64, gap: 0.2, seed: 1201 }).as("thread")
  const tone = noise({ scale: 6, octaves: 2, seed: 1202 })
  const crease = noise({ scale: [2, 5], octaves: 2, seed: 1203 }).warp(noise({ scale: 3, seed: 1204 }), 0.1).as("crease")
  const stain = noise({ scale: 4, octaves: 3, seed: 1205 }).threshold(0.7, 0.06).as("stain")
  const h = crease.mul(0.6).add(thread.mul(0.15)).as("clothH")
  for (const k of "abc") {
    const col = (n) => n + k
    material("cloth" + SUF[k], { size: 512, depth: 0.008, ao: 0.4 }, {
      height: h,
      color: ramp(tone, [col("w0"), col("w1")]).mix(ramp(tone, [col("c0"), col("c1")]), chk)
        .mul(thread.levels(0, 1, 0.9, 1)).mix(col("st"), stain.mul(0.35)),
      rough: 0.92,
    })
  }
}

// --- pine: the bright golden boards of the meat crates and boxes (2743, 2744,
// 1620, 2740) -----------------------------------------------------------------
// fresh sawn pine: long soft grain streaks, a few knots and dark splits,
// warm and bright; pineV runs the grain along v for upright boards
//   a golden pine (retail)   b pale ash   c dark stained
skins({
  a: { g0: "#7a4a14", g1: "#c8862a", g2: "#e0a440", g3: "#f4c464" },
  b: { g0: "#6a5e48", g1: "#b8a888", g2: "#cec0a0", g3: "#e2d6b8" },
  c: { g0: "#2e1a0e", g1: "#6a3e20", g2: "#80502c", g3: "#9a6640" },
})
{
  const grain = noise({ scale: [2, 28], octaves: 2, seed: 1301 }).warp(noise({ scale: [3, 6], seed: 1302 }), 0.05).as("grain")
  const split = noise({ scale: [3, 22], octaves: 1, seed: 1303 }).threshold(0.9, 0.03)
    .mul(noise({ scale: [4, 2], seed: 1304 }).threshold(0.55, 0.1)).as("split")
  const knots = dots({ scale: 4, radius: 0.06, jitter: 1, seed: 1305 }).mul(noise({ scale: 3, seed: 1306 }).threshold(0.6, 0.1)).as("knots")
  const blot = noise({ scale: 3, octaves: 2, seed: 1307 })
  const h = grain.mul(0.6).add(blot.mul(0.2)).sub(split.mul(0.4)).sub(knots.mul(0.3)).as("pineH")
  for (const [name, r] of [["pine", (f) => f], ["pineV", (f) => f.rotate(90)]])
    for (const k of "abc") {
      const col = (n) => n + k
      material(name + SUF[k], { size: 512, depth: 0.012, ao: 0.4 }, {
        height: r(h),
        color: ramp(r(grain.mix(blot, 0.4)), [col("g1"), col("g2"), col("g2"), col("g3")])
          .mix(col("g0"), r(split).mul(0.8)).mix(col("g0"), r(knots).mul(0.6)),
        rough: r(grain.levels(0, 1, 0.65, 0.8)),
      })
    }
}

// --- linen: the dress, the aprons (2749, 2763) -----------------------------------
// a worn cotton cloth, kept near white so kit.kx.js tints it: a fine plain
// weave, soft creases, darker grime in the folds, a few faded stains and
// worn pale patches. One texture; the colours are tints.
{
  const thread = weave({ threads: 48, gap: 0.18, seed: 1401 }).as("thread")
  const crease = noise({ scale: [3, 7], octaves: 3, seed: 1402 }).warp(noise({ scale: 3, seed: 1403 }), 0.12).as("crease")
  const blot = noise({ scale: 5, octaves: 3, seed: 1404 }).as("blot")
  const stain = noise({ scale: 3, octaves: 4, seed: 1405 }).warp(noise({ scale: 5, seed: 1406 }), 0.2).threshold(0.72, 0.12).as("stain")
  const h = crease.mul(0.75).add(thread.mul(0.05)).add(blot.mul(0.12)).as("linenH")
  const fold = h.cavity(0.01, 12).as("fold")
  const worn = h.convex(0.01, 12).as("worn")
  material("linen", { size: 512, depth: 0.012, ao: 0.6 }, {
    height: h,
    color: ramp(blot, ["#d8d4cc", "#eceae4", "#f6f4ee"]).mul(thread.levels(0, 1, 0.95, 1))
      .mix("#a8a094", fold.mul(0.5)).mix("#fbfaf6", worn.mul(0.3)).mix("#b09a78", stain.mul(0.15)),
    rough: 0.92,
  })
}

// --- knit: the knitting in the headless woman's lap (2763) -------------------------
// stocking stitch: columns of little V loops, row by row, fluffy; near white,
// tinted green in kit.kx.js
{
  const cols = stripes({ count: 24, dir: "v", soft: 0.6 }).as("cols")
  const rows = stripes({ count: 32, dir: "h", soft: 0.8 }).as("rows")
  const loops = cols.mul(rows.levels(0, 1, 0.25, 1)).warp(noise({ scale: 24, seed: 1501 }), 0.004).as("loops")
  const fuzz = noise({ scale: 90, octaves: 2, seed: 1502 })
  const h = loops.mul(0.8).add(fuzz.mul(0.15)).as("knitH")
  material("knit", { size: 512, depth: 0.01, ao: 0.6 }, {
    height: h,
    color: ramp(h, ["#a8a8a0", "#e4e4dc", "#f8f8f2"]),
    rough: 0.97,
  })
}

// --- bone: the bloody skull (2764) ---------------------------------------------------
// old bone: smooth ivory with broad yellowed blotches, fine pores, hairline
// cracks; light, tinted in kit.kx.js
{
  const blot = noise({ scale: 4, octaves: 3, seed: 1601 }).warp(noise({ scale: 2, seed: 1602 }), 0.15).as("blot")
  const pores = dots({ scale: 30, radius: 0.12, jitter: 1, seed: 1603 }).mul(noise({ scale: 4, seed: 1604 }).threshold(0.45, 0.2)).as("pores")
  const crack = cells({ scale: 4, jitter: 0.9, seed: 1605 }).edge.invert().threshold(0.97, 0.015)
    .mul(noise({ scale: 3, seed: 1606 }).threshold(0.6, 0.1)).as("crack")
  const fine = noise({ scale: 60, octaves: 2, seed: 1607 })
  const h = blot.mul(0.4).add(fine.mul(0.1)).sub(pores.mul(0.15)).sub(crack.mul(0.3)).as("boneH")
  const grime = h.cavity(0.008, 10).max(crack).as("grime")
  material("boneTex", { size: 512, depth: 0.01, ao: 0.6 }, {
    height: h,
    color: ramp(blot, ["#e8dcb4", "#f2eacc", "#faf4e0"]).mix("#a8946a", grime.mul(0.6)).mix("#c8b488", pores.mul(0.4)),
    rough: blot.levels(0, 1, 0.55, 0.4),
  })
}
