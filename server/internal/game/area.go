package game

import "github.com/StarLoco/arena-2.70/internal/gamedata"

// area.go resolves an effect's area-of-effect: which fighters a cell-targeting
// effect lands on. AoE is server-authoritative — the server expands the aimed
// cell to the zone, finds every fighter inside, and applies the effect to each
// (each broadcasting its own RUNNING_EFFECT, which the client renders per
// fighter), so no new wire format is needed. Ported from the v2.04b combat
// area.go shape hit-tests.
//
// Shapes (mh_2 AreaOfEffectEnum / client zg_1). The radius/size ALWAYS comes
// from the effect's areaSize params — it is NEVER baked into the ordinal — and a
// Dofus "circle" is a Manhattan DIAMOND, not a Euclidean disk (client nw_0).
// Ordinals seen in real 2.70 spell data: 1 point, 2 circle, 3 cross, 4 T, 5 ring,
// 6 square, 8 point-list, 9 inverted-T, 32767 "all". Directional shapes (T /
// inverted-T) orient their stem along the caster→target cardinal step.
const (
	areaShapePoint  int32 = 1
	areaShapeCircle int32 = 2 // filled diamond, radius size[0]
	areaShapeCross  int32 = 3 // row + column arms, length size[0]
	areaShapeT      int32 = 4 // directional: stem size[1] toward target + bar size[0] at the tip
	areaShapeRing   int32 = 5 // diamond annulus [size[0]..size[1]]
	areaShapeSquare int32 = 6 // filled square/rect, half-extents size[0](,size[1])
	areaShapeTInv   int32 = 9 // directional: bar size[0] through center + stem size[1] toward target
	// areaShapePointList (8, client acg_0 "forme à base de points") is an explicit
	// list of (dx,dy) offsets from the centre rather than a parametric shape.
	areaShapePointList int32 = 8
	areaShapeEmpty     int32 = 32767
)

// areaFighters returns every living fighter an effect aimed at `center` (cast
// from the caster) affects: just the fighter on the target cell for a point /
// no-size effect, every living fighter for an "empty" (all) area, otherwise every
// living fighter standing inside the zone shape. An area damage/heal/buff thus
// lands on allies AND enemies AND the caster if they fall in the zone (authentic
// friendly-fire — you position to spare your team).
func (f *Fight) areaFighters(caster *FightFighter, ef gamedata.Effect, center Pos) []*FightFighter {
	var src Pos
	if caster != nil {
		src = caster.Pos
	}
	return f.areaFightersFrom(caster, src, ef, center)
}

// areaFightersFrom is areaFighters evaluated from an ARBITRARY origin rather than
// the caster's current cell. Only the directional shapes actually read the
// origin, but the AI needs it to ask "who would this catch if I cast it from over
// there?" while planning a move, without having to move first.
func (f *Fight) areaFightersFrom(caster *FightFighter, from Pos, ef gamedata.Effect, center Pos) []*FightFighter {
	shape := ef.AreaShape
	// Point, unknown, or a zone shape with no radius/size -> only the fighter on
	// the target cell, and only if this effect's target conditions allow it. The
	// client validated the aim against the SPELL's masks; each effect still
	// picks its own targets. S46: weapon 34 carries one damage effect per target
	// breed (bit 16+k), and with no filter here all fourteen landed on whoever
	// it hit: 112 damage instead of 8.
	// An effect only the caster may take (every condition has IS_CASTER: the
	// self-boost or the cost riding on an attack, spells 30 and 443) goes to the
	// caster wherever the spell was aimed; before, it landed on the target.
	if shape != areaShapeEmpty && (shape == areaShapePoint || shape == 0 || len(ef.AreaSize) == 0) {
		if casterOnly(ef.Targets) {
			if caster != nil && caster.HP > 0 {
				return []*FightFighter{caster}
			}
			return nil
		}
		if v := f.fighterAtCell(center); v != nil && effectTargetAllowed(caster, v, ef.Targets) {
			return []*FightFighter{v}
		}
		return nil
	}
	// Multi-target: gather every candidate in the shape (or every living fighter
	// for an "empty"/all area), then keep only those the effect's target
	// conditions allow — the client validated only the centre cell, so the server
	// decides who each EXPANDED target legitimately affects. Without this a
	// "Target: All" self-buff (32767 + IS_CASTER) would wrongly buff everyone.
	var candidates []*FightFighter
	if shape == areaShapeEmpty {
		candidates = f.livingFighters()
	} else {
		src := from
		for _, ff := range f.allFighters() {
			if ff.HP > 0 && pointInArea(shape, ef.AreaSize, src, center, ff.Pos) {
				candidates = append(candidates, ff)
			}
		}
	}
	var out []*FightFighter
	for _, ff := range candidates {
		if effectTargetAllowed(caster, ff, ef.Targets) {
			out = append(out, ff)
		}
	}
	return out
}

// casterOnly reports whether every target condition demands the caster.
func casterOnly(targets []int64) bool {
	if len(targets) == 0 {
		return false
	}
	for _, c := range targets {
		if c&condIsCaster == 0 {
			return false
		}
	}
	return true
}

// livingFighters returns every living fighter across both teams.
func (f *Fight) livingFighters() []*FightFighter {
	var out []*FightFighter
	for _, ff := range f.allFighters() {
		if ff.HP > 0 {
			out = append(out, ff)
		}
	}
	return out
}

// pointInArea reports whether `point` lies inside a zone of `shape`/`size`
// centered on `center` and cast from `source` (source sets the direction for the
// directional T shapes). Non-directional shapes ignore source. A missing size
// element reads as 0, degrading a mis-sized zone to its center cell.
func pointInArea(shape int32, size []int32, source, center, point Pos) bool {
	dx, dy := point.X-center.X, point.Y-center.Y
	switch shape {
	case areaShapeCircle:
		return abs32(dx)+abs32(dy) <= areaSz(size, 0) // Manhattan diamond (client nw_0)
	case areaShapeCross:
		return crossContains(size, dx, dy)
	case areaShapeRing:
		lo, hi := areaSz(size, 0), areaSz(size, 1)
		if hi < lo {
			lo, hi = hi, lo
		}
		d := abs32(dx) + abs32(dy)
		return d >= lo && d <= hi
	case areaShapeSquare:
		hw := areaSz(size, 0)
		hh := hw
		if len(size) >= 2 {
			hh = size[1]
		}
		return abs32(dx) <= hw && abs32(dy) <= hh
	case areaShapeT:
		return tZoneContains(source, center, point, areaSz(size, 1), areaSz(size, 0), false)
	case areaShapeTInv:
		return tZoneContains(source, center, point, areaSz(size, 1), areaSz(size, 0), true)
	case areaShapePointList:
		return pointListContains(source, center, size, dx, dy)
	default: // point (1), unknown; "all" (32767) is handled by areaFighters
		return dx == 0 && dy == 0
	}
}

// tZoneContains tests membership of a directional T (or inverted-T): a stem of
// `stemLen` cells running from the center toward the target, and a perpendicular
// bar of half-width `barHalf` — at the stem TIP for a T, or THROUGH the center
// for an inverted-T (client sp_2 / arG). Direction is the caster→target cardinal
// step (the client quantises to the same 4 iso-diagonals); a zero direction
// (caster on the target cell) degenerates to the center cell only.
func tZoneContains(source, center, point Pos, stemLen, barHalf int32, inverted bool) bool {
	dirX, dirY := cardinalStep(center.X-source.X, center.Y-source.Y)
	if dirX == 0 && dirY == 0 {
		return point.X == center.X && point.Y == center.Y
	}
	perpX, perpY := -dirY, dirX
	dx, dy := point.X-center.X, point.Y-center.Y
	along := dx*dirX + dy*dirY // steps toward the target (the stem axis)
	across := dx*perpX + dy*perpY
	if along == 0 && across == 0 {
		return true // center
	}
	if across == 0 && along >= 1 && along <= stemLen {
		return true // stem
	}
	barAt := stemLen // T: bar at the tip
	if inverted {
		barAt = 0 // inverted-T: bar through the center
	}
	return along == barAt && abs32(across) >= 1 && abs32(across) <= barHalf
}

// areaSz returns size[i] or 0 if absent.
func areaSz(size []int32, i int) int32 {
	if i >= 0 && i < len(size) {
		return size[i]
	}
	return 0
}

func abs32(v int32) int32 {
	if v < 0 {
		return -v
	}
	return v
}

// pointListContains implements AoE shape 8 (client acg_0, "forme à base de
// points"): an explicit list of (dx,dy) offsets from the centre rather than a
// parametric shape. `acg_0.a(int[])` rejects an odd-length array outright and
// reads consecutive pairs, and its parameter labels name them x1,y1,x2,y2,…
// ("Liste de N points").
//
// It is DIRECTIONAL. The client's shapes carry a symmetry flag `fi()` — true for
// the circle and the point, which look the same whichever way you face, and
// FALSE for the T, the inverted T and this one. The authored offsets are written
// in a fixed reference frame, which the labels state outright: "prendre l'axe
// sud-est pour construire". So the list is rotated by the caster→centre cardinal
// step, exactly as tZoneContains rotates its stem, and a zero direction (caster
// standing on the centre) degenerates to the centre cell only — the same
// degradation the T shapes already use.
//
// One shipped row uses this: spell 469's action-125 effect, size [0 0 -1 0] —
// the centre cell plus the cell one step behind it along the reference axis.
func pointListContains(source, center Pos, size []int32, dx, dy int32) bool {
	if len(size) < 2 {
		return dx == 0 && dy == 0 // malformed: degrade to the centre cell
	}
	dirX, dirY := cardinalStep(center.X-source.X, center.Y-source.Y)
	if dirX == 0 && dirY == 0 {
		return dx == 0 && dy == 0
	}
	// Rotate each authored offset from the reference axis (+x) onto the cast
	// direction. For a cardinal step this is the standard integer rotation:
	//	(ox,oy) -> (ox*dirX - oy*dirY, ox*dirY + oy*dirX)
	// which is the identity when the cast runs along +x, and matches the quarter
	// turns tZoneContains applies for the other three cardinals.
	for i := 0; i+1 < len(size); i += 2 {
		ox, oy := size[i], size[i+1]
		rx := ox*dirX - oy*dirY
		ry := ox*dirY + oy*dirX
		if rx == dx && ry == dy {
			return true
		}
	}
	return false
}

// crossContains implements AoE shape 3 (client qv, "cross"), which accepts ONE,
// TWO or FOUR arm lengths — `qv.a(int[])` rejects any other count outright:
//
//	1 param  "Croix (deux barres de tailles identiques)"   all four arms alike
//	2 params "Croix (deux barres de tailles différentes)"  face-à-soi, then côté
//	4 params "Croix (4 barres de tailles différentes)"     haut, bas, gauche, droite
//
// The arm-to-axis mapping is read off the cell list qv builds, and confirmed by
// its own debug name `"cross-h"+aeD+"b"+aeF+"-g"+aeG+"d"+aeE`:
//
//	aeD = haut    -> (+n, 0)
//	aeF = bas     -> (-n, 0)
//	aeG = gauche  -> (0, -n)
//	aeE = droite  -> (0, +n)
//
// with the 2-param form assigning aeD=aeF=p0 and aeG=aeE=p1.
//
// The cross is NOT directional: `qv.fi()` returns true, the client's
// symmetry flag (true for the circle and the point, false for the T shapes and
// the point list), so the arms sit on the grid axes and are not rotated by the
// cast direction.
//
// No shipped record uses the 2- or 4-param forms — every shape-3 row in the
// spell and static-effect tables carries exactly one size — so this is forward
// safety rather than a live fix. It replaces an approximation that applied
// size[0] to all four arms, which would have been silently WRONG for those forms
// rather than merely unimplemented.
func crossContains(size []int32, dx, dy int32) bool {
	if len(size) == 0 {
		return dx == 0 && dy == 0
	}
	up, down, left, right := areaSz(size, 0), areaSz(size, 0), areaSz(size, 0), areaSz(size, 0)
	switch {
	case len(size) >= 4:
		up, down, left, right = size[0], size[1], size[2], size[3]
	case len(size) >= 2:
		up, down = size[0], size[0]
		left, right = size[1], size[1]
	}
	switch {
	case dx == 0 && dy == 0:
		return true
	case dy == 0 && dx > 0:
		return dx <= up
	case dy == 0 && dx < 0:
		return -dx <= down
	case dx == 0 && dy < 0:
		return -dy <= left
	case dx == 0 && dy > 0:
		return dy <= right
	}
	return false
}
