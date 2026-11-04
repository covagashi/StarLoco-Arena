// S35: fighter 1's cloth, leather, hair and skin. Albedos are light greys:
// fighter1.py multiplies them by each material's colour (kiln's way), so a
// class or a cosmetic recolours the same maps.
//   loom build godot/art/characters/fighter1.tx.js

// vest: felted wool, no visible threads at this size: a soft mottle and a
// faint nap
{
  const nap = noise({ scale: [40, 12], octaves: 3, seed: 12 }).as("vestNap")
  const mottle = noise({ scale: 5, octaves: 3, seed: 13 }).as("vestMottle")
  const h = mottle.mul(0.6).add(nap.mul(0.4)).as("vestH")
  material("vestTex", { size: 512, depth: 0.004, ao: 0.3 }, {
    height: h,
    color: ramp(mottle.mix(nap, 0.3), ["#d6d6d6", "#e8e8e8", "#f6f6f6"]),
    rough: nap.levels(0, 1, 0.82, 0.95),
  })
}

// trousers: soft cotton; the folds are in the mesh (fighter1.py wrinkle()),
// projected stripes would turn into flames on the round legs
{
  const tw = weave({ threads: 48, gap: 0.08, seed: 23 }).as("twill")
  const mottle = noise({ scale: 6, octaves: 3, seed: 21 }).as("pantsMottle")
  const grain = noise({ scale: 64, octaves: 2, seed: 22 })
  const h = mottle.mul(0.6).add(tw.mul(0.15)).add(grain.mul(0.25)).as("pantsH")
  material("pantsTex", { size: 512, depth: 0.003, ao: 0.3 }, {
    height: h,
    color: ramp(mottle.mix(grain, 0.2), ["#dcdcdc", "#ececec", "#fafafa"]),
    rough: grain.levels(0, 1, 0.8, 0.92),
  })
}

// sleeves: plain linen, slubby and lightly creased
{
  const slub = noise({ scale: [48, 6], octaves: 2, seed: 32 }).as("slub")
  const crease = waves({ count: 3, dir: "h", warp: 0.8, scale: 2, seed: 33 }).as("crease")
  const h = slub.mul(0.3).add(crease.mul(0.7)).as("shirtH")
  material("shirtTex", { size: 512, depth: 0.006, ao: 0.4 }, {
    height: h,
    color: ramp(slub.mix(crease, 0.5), ["#e8e8e8", "#f4f4f4", "#ffffff"]),
    rough: slub.levels(0, 1, 0.75, 0.9),
  })
}

// boots and belt: pebbled leather, scuffed paler on the high spots
{
  const pebble = cells({ scale: 40, jitter: 0.9, seed: 41 }).as("pebble")
  const scuff = noise({ scale: 6, octaves: 4, seed: 42 }).threshold(0.62, 0.08).as("scuff")
  const h = pebble.mul(0.6).add(noise({ scale: 12, seed: 43 }).mul(0.4)).as("leatherH")
  material("leatherTex", { size: 512, depth: 0.01, ao: 0.5 }, {
    height: h,
    color: ramp(h, ["#b4b4b4", "#dcdcdc", "#f0f0f0"]).mix("#ffffff", scuff.mul(h.convex(0.004, 8)).mul(0.6)),
    rough: ramp(scuff, [[0, "#c8c8c8"], [1, "#7a7a7a"]]).luma(),
  })
}

// hair: soft clumps with a faint streak; the model is box-projected, so no
// long stripes (they come out as ridges across the spikes)
{
  const clump = cells({ scale: 6, jitter: 1, seed: 51 }).as("clump")
  const streak = noise({ scale: 24, octaves: 3, seed: 52 }).as("streak")
  const h = clump.mul(0.6).add(streak.mul(0.4)).as("hairH")
  material("hairTex", { size: 512, depth: 0.008, ao: 0.4 }, {
    height: h,
    color: ramp(h, ["#d0d0d0", "#ececec", "#ffffff"]),
    rough: streak.levels(0, 1, 0.5, 0.7),
  })
}

// skin: barely there, a soft blotch so it isn't plastic
{
  const blotch = noise({ scale: 6, octaves: 4, seed: 61 }).as("blotch")
  const pore = dots({ scale: 64, radius: 0.2, jitter: 0.8, soft: 0.3, seed: 62 })
  material("skinTex", { size: 256, depth: 0.003, ao: 0.3 }, {
    height: pore.mul(-0.3).add(blotch.mul(0.2)),
    color: ramp(blotch, ["#ece4e2", "#f8f4f0", "#ffffff"]),
    rough: blotch.levels(0, 1, 0.55, 0.7),
  })
}

// gold collar and buckle: hammered metal (not flagged metal: the arenas have
// no reflections to show, and an unlit metal reads black)
{
  const dents = noise({ scale: 8, octaves: 2, seed: 71 }).as("dents")
  material("goldTex", { size: 256, depth: 0.003, ao: 0.2 }, {
    height: dents,
    color: ramp(dents, ["#d8d8d8", "#ffffff"]),
    rough: dents.levels(0, 1, 0.25, 0.45),
  })
}
