package game

import (
	"sort"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// arena is a dedicated fight map — a maps.jar "world" that ships an .fmd
// start-point definition (contents/maps/fight/<world>.jar!/<world>.fmd) and a
// topology (contents/maps/tplg/<world>.jar!/<i>_<j>). Fights render on the
// client's own topology for this world, so three things must hold:
//  1. the client must have STREAMED the arena world (via EnterInstance/4600 with
//     this world id) before CREATE_FIGHT, so its .dam tiles are resident;
//  2. the fight-grid (cLr) must mark VOID cells as "not part of arena" (0xFEFF),
//     or the client treats them as floor at the sentinel altitude and the map
//     geometry/camera break; and
//  3. every fighter must stand on a real cell with the cell's real altitude
//     (aoq_0.F(x,y,z) rejects a fighter whose z != the topology altitude).
//
// Every arena is described by one flat cell grid over its bounding box. A cell
// either has floor (Ground), is solid scenery (no Ground, real altitude — ice
// spikes, trees, the coach pedestals) or is void (no Ground, sentinel altitude).
// The distinction matters on the wire: scenery must be advertised as an obstacle,
// void as "not part of the arena".
type arena struct {
	worldID          uint16
	minX, minY       int32  // bounding-box origin (a map need not start at 0,0)
	width, height    int32  //
	centerX, centerY int32  // camera center / battlefield centroid (cLw/cLx + EnterInstance focus)
	team0, team1     []Pos  // per-side fighter start cells (x,y,z) from the arena shape
	coachCells       []Pos  // coach pedestal cells from the arena shape
	cells            []cell // row-major over the bounding box
	// specials are the map-authored special cells (from the .fmd), which fire an
	// effect on a fighter that STARTS its turn on one. See specialcells.go.
	specials []specialCell
	// fallbackTopo/fallbackObstacles describe the hand-decoded world 5 only. They
	// are folded into cells by init() and are unused for maps loaded from client
	// data. They exist so the server (and the whole test suite) still has a working
	// arena when the map files are absent.
	fallbackTopo      []int16
	fallbackObstacles map[[2]int32]bool
}

// cell is one arena square.
type cell struct {
	alt    int16
	ground bool
	void   bool
}

// voidCell is the sentinel altitude of a cell with no floor at all.
const voidCell int16 = -32768

// at returns the cell at absolute (x,y); anything outside the box reads as void.
func (a *arena) at(x, y int32) cell {
	if x < a.minX || y < a.minY || x >= a.minX+a.width || y >= a.minY+a.height {
		return cell{alt: voidCell, void: true}
	}
	return a.cells[(y-a.minY)*a.width+(x-a.minX)]
}

// newArenaFromMap builds an arena from decoded client map data.
func newArenaFromMap(m *gamedata.FightMap) *arena {
	a := &arena{
		worldID: uint16(m.ID),
		minX:    m.MinX, minY: m.MinY,
		width: m.Width, height: m.Height,
		cells: make([]cell, m.Width*m.Height),
	}
	for y := int32(0); y < m.Height; y++ {
		for x := int32(0); x < m.Width; x++ {
			c := m.At(m.MinX+x, m.MinY+y)
			a.cells[y*m.Width+x] = cell{alt: c.Alt, ground: c.Ground, void: c.Void}
		}
	}
	conv := func(src []gamedata.MapPos) []Pos {
		out := make([]Pos, 0, len(src))
		for _, p := range src {
			out = append(out, Pos{X: p.X, Y: p.Y, Z: p.Z})
		}
		return out
	}
	a.team0, a.team1 = conv(m.Team0), conv(m.Team1)
	// The .fmd always stores SIX pedestal slots, but only 28 of the 47 shipped
	// arenas populate them all: 15 populate none and 4 populate some. An empty
	// slot decodes to the unpacked-zero sentinel (-2047, -2047, -127), which we
	// used to keep and hand out like a real cell - so on a pedestal-less arena a
	// coach was placed 2047 tiles off the map.
	for _, p := range m.CoachCells {
		if p.X == emptyPedestalXY && p.Y == emptyPedestalXY {
			continue
		}
		a.coachCells = append(a.coachCells, Pos{X: p.X, Y: p.Y, Z: p.Z})
	}
	for _, s := range m.Specials {
		a.specials = append(a.specials, specialCell{
			Pos: Pos{X: s.X, Y: s.Y, Z: s.Z}, Template: int64(s.Template),
		})
	}
	a.centerX, a.centerY = a.battlefieldCentre()
	return a
}

// battlefieldCentre is the midpoint of the two teams' start cells — the point the
// camera focuses on and the point sudden death collapses toward. Using the start
// cells rather than the bounding box keeps the focus on the playable area even on
// maps whose grid extends well beyond it.
func (a *arena) battlefieldCentre() (int32, int32) {
	var sx, sy, n int32
	for _, p := range append(append([]Pos{}, a.team0...), a.team1...) {
		sx += p.X
		sy += p.Y
		n++
	}
	if n == 0 {
		return a.minX + a.width/2, a.minY + a.height/2
	}
	return sx / n, sy / n
}

// startCells returns the start cells for a team side (0 or 1).
func (a *arena) startCells(side uint8) []Pos {
	if side == 1 {
		return a.team1
	}
	return a.team0
}

// emptyPedestalXY is the x and y an unused .fmd pedestal slot decodes to: the
// packed value 0 unpacks to (0-2047, 0-2047, 0-127).
const emptyPedestalXY = -2047

// pedestalsFor returns the coach pedestals that belong to a side, nearest-first.
//
// The .fmd does not label them, so the side is derived geometrically: a pedestal
// belongs to whichever side owns the start cell it sits closest to. Index parity
// very nearly works (22 of the 28 six-pedestal arenas alternate 0,1,0,1,0,1) but
// not quite, and the exceptions are the lopsided maps where getting it wrong is
// most visible - so geometry wins over the pattern.
//
// 24 of those 28 arenas split their six pedestals exactly 3/3, which is the real
// shape of the feature: up to THREE coaches a side. 2v2 therefore needs no new
// map format, only an arena that actually populates the slots.
func (a *arena) pedestalsFor(side uint8) []Pos {
	type scored struct {
		p Pos
		d int32
	}
	var out []scored
	for _, p := range a.coachCells {
		mine, theirs := a.nearestStart(p, side), a.nearestStart(p, 1-side)
		if mine <= theirs {
			out = append(out, scored{p, mine})
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].d < out[j].d })
	ps := make([]Pos, 0, len(out))
	for _, s := range out {
		ps = append(ps, s.p)
	}
	return ps
}

// nearestStart is the squared distance from p to the closest start cell of side.
func (a *arena) nearestStart(p Pos, side uint8) int32 {
	best := int32(1) << 30
	for _, c := range a.startCells(side) {
		dx, dy := p.X-c.X, p.Y-c.Y
		if d := dx*dx + dy*dy; d < best {
			best = d
		}
	}
	return best
}

// coachCapacity is the smaller of the two sides' pedestal counts - i.e. how many
// coaches per side this arena can seat. A 2v2 needs at least 2.
func (a *arena) coachCapacity() int {
	n0, n1 := len(a.pedestalsFor(0)), len(a.pedestalsFor(1))
	if n0 < n1 {
		return n0
	}
	return n1
}

// cellFlag returns the fight-grid short (cLr) for cell (x,y). The client's
// aoq_0 decodes this word bitwise:
//
//	bits 0-5   topology layer index (0 here; 63 = none)
//	bit 7      0x0080 — cell is NOT a valid arena position
//	bit 8      0x0100 — blocks LINE OF SIGHT      (aoq_0.bE)
//	bit 9      0x0200 — blocks MOVEMENT           (aoq_0.bD)
//	bits 10-15 dynamic obstacle id; 63 (0xFC00) = none
//
// So: 0xFC00 = plain walkable floor on layer 0; 0xFEFF = open void (unwalkable,
// LoS passes); 0xFFFF = solid void (unwalkable AND blocks LoS).
//
// Scenery obstacles must be 0xFFFF, not 0xFE00/0xFD00: those leave bit 7 clear,
// so the client still treats the cell as a valid arena position — it draws a
// walkable grid tile on top of the ice spike and assigns it a team side.
func (a *arena) cellFlag(x, y int32) uint16 {
	c := a.at(x, y)
	switch {
	case c.ground:
		return 0xFC00
	case c.void:
		return 0xFEFF
	default:
		return 0xFFFF // real altitude, but no ground: blocks movement and sight
	}
}

// blocksLineOfSight reports whether cell (x,y) stops a ray: both true void and
// scenery obstacles do (the client's aoq_0.bE tests bit 8, which 0xFEFF leaves
// clear but 0xFFFF sets — and an out-of-arena cell is never traversable anyway).
func (a *arena) blocksLineOfSight(x, y int32) bool {
	return a.cellFlag(x, y) == 0xFFFF
}

// specialAt returns the map-authored special cell at (x,y) and its 1-based
// instance id (the id the client keys its EffectArea by, and which an
// EFFECT_AREA_ACTION must reference), or ok=false when the cell is ordinary.
func (a *arena) specialAt(x, y int32) (specialCell, int64, bool) {
	for i, sc := range a.specials {
		if sc.Pos.X == x && sc.Pos.Y == y {
			return sc, int64(i + 1), true
		}
	}
	return specialCell{}, 0, false
}

// walkable reports whether (x,y) is a real, in-bounds floor cell a fighter may
// stand on. This is the same grid the server streams to the client as the
// fight-grid (writeFightGrid/cellFlag), so the client's own pathfinder only ever
// routes across walkable cells — the server can validate moves against it without
// ever rejecting a legitimate client path.
func (a *arena) walkable(x, y int32) bool { return a.at(x, y).ground }

// scenery reports whether (x,y) is solid map furniture — an ice spike, a tree, a
// coach pedestal: a real cell with a real altitude that cannot be stood on. It is
// distinct from void, which is simply not part of the arena.
func (a *arena) scenery(x, y int32) bool {
	c := a.at(x, y)
	return !c.ground && !c.void
}

// altitudeAt returns the topology altitude of cell (x,y) — the z a fighter
// standing there must carry — or 0 for an out-of-bounds or void cell. Used by
// positioning effects (teleport/push/pull) to snap a moved fighter to the real
// floor height and to enforce the client's "cannot be shoved up a >2 step" rule.
func (a *arena) altitudeAt(x, y int32) int16 {
	if c := a.at(x, y); !c.void {
		return c.alt
	}
	return 0
}

// practiceArena is DofusArena world 5 (fight/5.jar!/5.fmd + tplg/5.jar!/0_0), an
// 18x18 ice arena (173 real cells). Start cells decoded from the .fmd; topology
// decoded from the type-2 .dam tile (altitude = dRS[cell]+wpBase). team0 sits on
// the south lip (z=0), team1 on the north lip (z=3, edge z=0).
var practiceArena = arena{
	worldID: 5,
	width:   18,
	height:  18,
	centerX: 10,
	centerY: 9,
	// Coach pedestals from the .fmd coachCells (elevated spots).
	coachCells: []Pos{{X: 5, Y: 9, Z: 10}, {X: 10, Y: 1, Z: 6}},
	team0: []Pos{
		{X: 7, Y: 15, Z: 0}, {X: 9, Y: 15, Z: 0}, {X: 12, Y: 15, Z: 0}, {X: 13, Y: 15, Z: 0},
		{X: 6, Y: 16, Z: 0}, {X: 8, Y: 16, Z: 0}, {X: 12, Y: 16, Z: 0}, {X: 13, Y: 16, Z: 0},
	},
	team1: []Pos{
		{X: 6, Y: 2, Z: 3}, {X: 9, Y: 2, Z: 3}, {X: 10, Y: 2, Z: 3}, {X: 13, Y: 2, Z: 0},
		{X: 6, Y: 3, Z: 3}, {X: 9, Y: 3, Z: 3}, {X: 10, Y: 3, Z: 3}, {X: 13, Y: 3, Z: 0},
	},
	// The 22 scenery cells of world 5: decoded from tplg/5.jar!0_0, where the
	// per-cell ground-palette entry is -1 ("no walkable ground") while the cell
	// still carries a real altitude. These are the ice spikes / trees / pedestals.
	// They were previously advertised as plain floor, which let displacement
	// spells (e.g. the Iop's Bond) land a fighter on top of an ice spike — and
	// made the streamed grid disagree with the map the player sees. See B-048.
	// The six coach pedestals sit on these cells too (coaches stand on scenery,
	// off the playable floor), which independently confirms the decode.
	fallbackObstacles: map[[2]int32]bool{
		{9, 1}: true, {10, 1}: true, {11, 1}: true, {13, 1}: true,
		{14, 2}: true, {4, 4}: true, {14, 5}: true, {2, 6}: true,
		{2, 7}: true, {9, 7}: true, {5, 8}: true, {5, 9}: true,
		{5, 10}: true, {11, 10}: true, {4, 11}: true, {4, 13}: true,
		{6, 13}: true, {7, 13}: true, {14, 13}: true, {16, 13}: true,
		{5, 15}: true, {12, 17}: true,
	},
	// The 9 map-authored special cells of world 5, from fight/5.jar!5.fmd
	// (packed position + template id, read after the team start lists). Template
	// ids index the client's staticEffect table (SPECIAL 1002-1009). World 5 uses
	// only beneficial cells — no Killer (1002) and no Trap (1003).
	specials: []specialCell{
		{Pos: Pos{X: 5, Y: 6, Z: 6}, Template: 1004},   // eagle eye
		{Pos: Pos{X: 15, Y: 7, Z: 0}, Template: 1004},  // eagle eye
		{Pos: Pos{X: 13, Y: 9, Z: 0}, Template: 1005},  // shield
		{Pos: Pos{X: 12, Y: 9, Z: 0}, Template: 1008},  // motivation
		{Pos: Pos{X: 15, Y: 11, Z: 0}, Template: 1004}, // eagle eye
		{Pos: Pos{X: 8, Y: 9, Z: 0}, Template: 1008},   // motivation
		{Pos: Pos{X: 6, Y: 11, Z: 3}, Template: 1004},  // eagle eye
		{Pos: Pos{X: 7, Y: 9, Z: 0}, Template: 1005},   // shield
		{Pos: Pos{X: 6, Y: 9, Z: 0}, Template: 1006},   // panacea
	},
	// 18x18 altitude grid (row-major idx=y*18+x), 32767 = void. Converted into the
	// shared cell grid by init() below.
	fallbackTopo: []int16{
		32767, 32767, 32767, 32767, 32767, 32767, 32767, 32767, 32767, 32767, 32767, 32767, 32767, 32767, 32767, 32767, 32767, 32767,
		32767, 32767, 32767, 32767, 32767, 32767, 32767, 32767, 32767, 4, 6, 4, 32767, 10, 32767, 32767, 32767, 32767,
		32767, 32767, 32767, 32767, 32767, 32767, 3, 3, 3, 3, 3, 0, 0, 0, 0, 32767, 32767, 32767,
		32767, 32767, 32767, 32767, 32767, 6, 3, 3, 3, 3, 3, 0, 0, 0, 0, 0, 32767, 32767,
		32767, 32767, 32767, 32767, 14, 6, 3, 3, 3, 3, 3, 0, 0, 0, 0, 0, 1, 32767,
		32767, 32767, 32767, 6, 6, 6, 3, 3, 3, 3, 32767, 0, 0, 0, 0, 0, -3, 32767,
		32767, 32767, 16, 6, 32767, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -3, -3,
		32767, 32767, 6, 32767, 32767, 32767, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, -3, -3,
		32767, 32767, 32767, 32767, 32767, 8, 0, 0, 32767, 32767, 32767, 32767, 0, 0, 0, 32767, -3, -3,
		32767, 32767, 32767, 32767, 32767, 10, 0, 0, 0, 32767, 32767, 32767, 0, 0, 32767, 32767, -3, 32767,
		32767, 32767, 32767, 32767, 32767, 8, 32767, 0, 0, 0, 0, 9, 0, 0, 0, 32767, -3, 32767,
		32767, 32767, 32767, 32767, 13, 3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, -3, 32767,
		32767, 32767, 32767, 32767, 3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -3, 32767,
		32767, 32767, 32767, 32767, 12, 3, 0, 8, 0, 32767, 0, 0, 0, 0, 0, 0, 5, 32767,
		32767, 32767, 32767, 32767, 3, 3, 0, 0, 0, -1, 0, 0, 0, 0, 0, 0, 32767, 32767,
		32767, 32767, 32767, 32767, 32767, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 32767, 32767, 32767,
		32767, 32767, 32767, 32767, 32767, 32767, 0, 0, 0, 0, 0, 0, 0, 0, 0, 32767, 32767, 32767,
		32767, 32767, 32767, 32767, 32767, 32767, 32767, 32767, 32767, 32767, 32767, 32767, 10, 32767, 32767, 32767, 32767, 32767,
	},
}

// init folds the hand-decoded world-5 topology into the shared cell grid, so every
// arena — hand-decoded fallback or loaded from client data — is read through one
// code path. The hand-decoded table uses 32767 as its void marker (the loader uses
// the client's own -32768 sentinel); both mean "no cell here".
func init() {
	const handDecodedVoid int16 = 32767
	a := &practiceArena
	a.cells = make([]cell, a.width*a.height)
	for y := int32(0); y < a.height; y++ {
		for x := int32(0); x < a.width; x++ {
			alt := a.fallbackTopo[y*a.width+x]
			switch {
			case alt == handDecodedVoid:
				a.cells[y*a.width+x] = cell{alt: voidCell, void: true}
			case a.fallbackObstacles[[2]int32{x, y}]:
				a.cells[y*a.width+x] = cell{alt: alt} // scenery: real altitude, no floor
			default:
				a.cells[y*a.width+x] = cell{alt: alt, ground: true}
			}
		}
	}
}
