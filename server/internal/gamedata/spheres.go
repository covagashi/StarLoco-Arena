package gamedata

import "sort"

// spheres.go decodes the SPHERE BOARD - the "Kanodo" (client string `sphereboard`)
// - from record types 900 (boards, client class `bg_0`) and 901 (nodes, `aeI`).
//
// The Kanodo is a per-fighter talent tree, and the client's own help text
// (content.59.53) is the clearest statement of the mechanic: a board is made of
// spheres BOUGHT with the experience a fighter has earned. A sphere can only be
// bought if it has a direct path to the sphere the progression cursor currently
// sits on - the cursor being drawn as the fighter's own head. Buying one grants
// its payload: a characteristic bonus, a new spell, or a set of equipment the
// fighter may then wear. Some spheres are deliberately a MALUS, "a sacrifice a
// fighter must make to continue its learning". Portal spheres teleport the cursor
// elsewhere on the board, and barrier spheres demand a card be sacrificed to open
// the way.
//
// What the client does and does not own here matters for the server's job:
//
//   - The board LAYOUT is client-side data. `vj_2`/`dq_1` load these same records
//     out of the client's own data files and register them in `akp_1`, so the
//     server never sends the graph.
//   - The fighter's PROGRESS is server state, and the fighter blob already carries
//     it: `[i32 sphereBoardId][i32 xp][i32 totalXp] ... [i16 sphereX][i16 sphereY]
//     [i16 sphereCount]{[i32 sphereId]}` (see game/fighter_codec.go). The cursor is
//     that (sphereX, sphereY) pair and the list is the bought nodes - `ee_2.NE()`
//     on the client side.
//   - Buying is C2S 23009 (`aow_2`, arch 3): [i64 fighterId][i32 sphereId]
//     [i32 cardTemplateId], the card being the barrier sacrifice and 0 otherwise.
//
// The node's TYPE (Bonus / Malus / Spell / Item / Summon / Teleport / Barrier /
// DeadEnd) is NOT stored: `ayr_0.aKZ()` derives it from the node's own contents -
// a spell id makes it a Spell, otherwise the FIRST effect's action id is matched
// against fixed sets. So this package stores what the record holds and leaves the
// classification to whoever needs it.

// SphereBoard is one decoded board (`bg_0` -> runtime `Ei`).
//
// Three of its fields are named by the client itself: `Ei.getFieldValue` maps
// "breed" to the byte, "season" to the first i32 after the id, and "spheres" to
// the id list.
type SphereBoard struct {
	ID int32
	// Season is `Ei`'s "season" property. Boards are versioned by season, which is
	// why 15 of them exist for far fewer breeds.
	Season int32
	// Breed is the class this board belongs to, resolved by the client through the
	// breed name table (content type 5).
	Breed uint8
	// RootX and RootY are the ROOT sphere's grid position - where a fighter's
	// cursor begins. `ks_2.Xm()` is literally `X(fs, ft)`, and `Ei.MQ()` calls it
	// to build the board's graph outward from that node.
	//
	// They are reached as fields rather than through the cx()/cy() accessors, which
	// is why searching for callers of those accessors finds none and makes the pair
	// look inert. They are not: without them the server has nowhere to start a
	// fighter, and no other record in the data says where that is.
	RootX int16
	RootY int16

	// The remaining two fields are decoded for completeness and read by nothing.
	// `ks_2` exposes them as Xp() and Xo() and a case-sensitive search finds no
	// caller of either, nor any internal use like Xm()'s. Every plausible meaning
	// is refuted by the data: the i32 is 5 on every breed board and 0 on the three
	// others, and the id list holds three small numbers that resolve to no node on
	// any board. Kept raw rather than given invented meanings.
	UnreadInt int32
	UnreadIDs []int32
	leftover  int
}

// Leftover reports unconsumed bytes; 0 means the record was fully accounted for.
func (b *SphereBoard) Leftover() int { return b.leftover }

// Sphere is one decoded node (`aeI` -> runtime `ayr_0`).
type Sphere struct {
	ID int32
	// BoardID is the board this node belongs to: `vj_2` registers each node under
	// `aeI.NH()`, so it is the grouping key rather than anything on the board side.
	BoardID int32
	// XPCost is what buying costs in fighter experience (`aus()`). A fighter that
	// already owns the node pays a TENTH of this - the client's own re-purchase
	// discount in afb_1 case 16926.
	XPCost int32
	// X and Y are the node's 1-BASED grid position (`aut()`, `auu()`). The cursor
	// on the wire is 0-based: the client sets it with `aLe() = aut()-1` and renders
	// it with `MU() = cursor+1`.
	X int16
	Y int16
	// SpellID is the spell this node unlocks, 0 when it unlocks none. Non-zero is
	// also what makes `aKZ()` classify the node as a Spell sphere, before it looks
	// at any effect.
	SpellID int32
	// EquipmentPoolID points at a record-type-251 equipment pool - the "ensemble
	// d'equipements qui se debloque" of the help text. 0 when the node grants none.
	EquipmentPoolID int32
	// Effects are `Ht` rows, the same structure spells and cards use, and are what
	// a Bonus or Malus node actually applies.
	Effects []Effect
	// BarrierCards are the card templates that open this node when it is a Barrier
	// (`auv()`); the client accepts any one of them and consumes it.
	BarrierCards []int32
	// DeadEnd is `auw()`: the node is impassable ("Cette sphere est
	// infranchissable"). It is the last thing `aKZ()` tests before falling through
	// to an empty node.
	DeadEnd bool
	// TeleportX and TeleportY are a portal node's arrival cell, 1-based like X/Y.
	// Zero on every node that is not a portal.
	TeleportX int16
	TeleportY int16
	// leftover is how many bytes of the record the decoder did not consume. Zero on
	// every shipped row is what proves the field layout, independently of what the
	// fields are called.
	leftover int
}

// Leftover reports unconsumed bytes; 0 means the record was fully accounted for.
func (s *Sphere) Leftover() int { return s.leftover }

// The client derives a node's KIND from its contents rather than storing one.
// `ayr_0.aKZ()` tests, strictly in this order:
//
//	SpellID != 0            -> "Spell"
//	len(Effects) > 0        -> "Malus" / "Summon" / "Bonus", split on the FIRST
//	                           effect's action id against two fixed sets
//	len(BarrierCards) > 0   -> "Barrier"
//	TeleportX != 0          -> "Teleport"
//	EquipmentPoolID != 0    -> "Item"
//	DeadEnd                 -> "DeadEndType"
//	otherwise               -> "EmptyType"
//
// Order matters: a node carrying both a spell and effects is a Spell sphere, and
// the teleport test is on X alone. The predicates below cover every branch that
// is a simple field test; the Bonus/Malus/Summon split needs the effect action
// tables and is left to whoever needs it.

// IsSpell reports the first branch: the node unlocks a spell.
func (s *Sphere) IsSpell() bool { return s != nil && s.SpellID != 0 }

// IsBarrier reports whether the node demands a card sacrifice, which is exactly
// "it lists cards that open it".
func (s *Sphere) IsBarrier() bool { return s != nil && len(s.BarrierCards) > 0 }

// IsTeleport reports whether the node is a portal. The client tests the X
// coordinate ALONE, so this does too - a portal arriving at column 0 would be
// classified as something else by the client, and the server must agree with it
// rather than be more correct than it.
func (s *Sphere) IsTeleport() bool { return s != nil && s.TeleportX != 0 }

// IsItem reports that the node unlocks an equipment pool (record type 251).
func (s *Sphere) IsItem() bool { return s != nil && s.EquipmentPoolID != 0 }

// SphereBoards is the decoded catalogue.
type SphereBoards struct {
	boards       map[int32]*SphereBoard
	spheres      map[int32]*Sphere
	byBoard      map[int32][]*Sphere
	byBoardCell  map[boardCell]*Sphere
	boardIDs     []int32
	boardByBreed map[uint8][]*SphereBoard
}

type boardCell struct {
	board int32
	x, y  int16
}

// NewSphereBoards builds a catalogue from explicit definitions (tests/tooling).
func NewSphereBoards(boards []*SphereBoard, spheres []*Sphere) *SphereBoards {
	out := &SphereBoards{
		boards:       make(map[int32]*SphereBoard, len(boards)),
		spheres:      make(map[int32]*Sphere, len(spheres)),
		byBoard:      make(map[int32][]*Sphere),
		byBoardCell:  make(map[boardCell]*Sphere),
		boardByBreed: make(map[uint8][]*SphereBoard),
	}
	for _, b := range boards {
		if b != nil {
			out.boards[b.ID] = b
		}
	}
	for _, sp := range spheres {
		if sp != nil {
			out.spheres[sp.ID] = sp
		}
	}
	out.reindex()
	return out
}

func (c *SphereBoards) reindex() {
	c.byBoard = make(map[int32][]*Sphere, len(c.boards))
	c.byBoardCell = make(map[boardCell]*Sphere, len(c.spheres))
	c.boardIDs = make([]int32, 0, len(c.boards))
	c.boardByBreed = make(map[uint8][]*SphereBoard, len(c.boards))

	for id, b := range c.boards {
		c.boardIDs = append(c.boardIDs, id)
		c.boardByBreed[b.Breed] = append(c.boardByBreed[b.Breed], b)
	}
	sort.Slice(c.boardIDs, func(i, j int) bool { return c.boardIDs[i] < c.boardIDs[j] })
	for _, list := range c.boardByBreed {
		sort.Slice(list, func(i, j int) bool { return list[i].ID < list[j].ID })
	}

	for _, sp := range c.spheres {
		c.byBoard[sp.BoardID] = append(c.byBoard[sp.BoardID], sp)
		c.byBoardCell[boardCell{sp.BoardID, sp.X, sp.Y}] = sp
	}
	for _, list := range c.byBoard {
		sort.Slice(list, func(i, j int) bool { return list[i].ID < list[j].ID })
	}
}

// Board returns a board by id.
func (c *SphereBoards) Board(id int32) *SphereBoard {
	if c == nil {
		return nil
	}
	return c.boards[id]
}

// Sphere returns a node by id.
func (c *SphereBoards) Sphere(id int32) *Sphere {
	if c == nil {
		return nil
	}
	return c.spheres[id]
}

// SpheresOf returns every node of a board, ascending by id.
func (c *SphereBoards) SpheresOf(boardID int32) []*Sphere {
	if c == nil {
		return nil
	}
	return c.byBoard[boardID]
}

// At returns the node occupying a board cell, using the record's own 1-based
// coordinates. This is the lookup the adjacency rule needs: "a direct path to the
// sphere the cursor sits on" is a neighbourhood in this grid.
func (c *SphereBoards) At(boardID int32, x, y int16) *Sphere {
	if c == nil {
		return nil
	}
	return c.byBoardCell[boardCell{boardID, x, y}]
}

// Root returns the board's root sphere - where a fighter starts. nil when the
// board names a cell no node occupies, which is true only of the unfinished
// breed-127 boards.
func (c *SphereBoards) Root(boardID int32) *Sphere {
	b := c.Board(boardID)
	if b == nil {
		return nil
	}
	return c.At(b.ID, b.RootX, b.RootY)
}

// BoardForBreed returns the single board a breed plays on, or nil.
//
// Every playable breed (1..12) has exactly one, which is what makes "the board
// for this fighter" a well-defined lookup; the three breed-127 boards are a
// sentinel rather than a class and are never returned here.
func (c *SphereBoards) BoardForBreed(breed uint8) *SphereBoard {
	if c == nil || breed == sentinelBreed {
		return nil
	}
	list := c.boardByBreed[breed]
	if len(list) != 1 {
		return nil
	}
	return list[0]
}

// sentinelBreed marks the three unfinished boards that belong to no class.
const sentinelBreed = 127

// BoardsForBreed returns the boards defined for a breed (one per season).
func (c *SphereBoards) BoardsForBreed(breed uint8) []*SphereBoard {
	if c == nil {
		return nil
	}
	return c.boardByBreed[breed]
}

// BoardIDs returns every board id, ascending.
func (c *SphereBoards) BoardIDs() []int32 {
	if c == nil {
		return nil
	}
	return c.boardIDs
}

// Len reports how many nodes were decoded.
func (c *SphereBoards) Len() int {
	if c == nil {
		return 0
	}
	return len(c.spheres)
}

// BoardCount reports how many boards were decoded.
func (c *SphereBoards) BoardCount() int {
	if c == nil {
		return 0
	}
	return len(c.boards)
}

// HasPayload reports the client's `ajM.azm()`: the node does something. It is the
// exact disjunction the client uses, and it is load-bearing twice over - it is
// what makes a node a "real" sphere rather than a segment of path, and a node with
// a payload BLOCKS a route through it.
func (s *Sphere) HasPayload() bool {
	return s != nil && (s.SpellID != 0 || len(s.Effects) > 0 || len(s.BarrierCards) > 0 ||
		s.EquipmentPoolID != 0 || s.TeleportX != 0 || s.DeadEnd)
}

// Neighbours returns the nodes orthogonally adjacent to a cell. `ks_2.a` links a
// node to whichever of (x, y+-1) and (x+-1, y) exist, so the board graph is plain
// grid 4-adjacency and nothing else.
func (c *SphereBoards) Neighbours(boardID int32, s *Sphere) []*Sphere {
	if c == nil || s == nil {
		return nil
	}
	out := make([]*Sphere, 0, 4)
	for _, d := range [4][2]int16{{0, 1}, {0, -1}, {1, 0}, {-1, 0}} {
		if n := c.At(boardID, s.X+d[0], s.Y+d[1]); n != nil {
			out = append(out, n)
		}
	}
	return out
}

// Reachable reports whether a fighter standing on `from` may buy `to`.
//
// This mirrors `ajM.a(from, true)`, which searches from the TARGET back towards
// the cursor, in the client's own order because the order is what decides the
// edge cases:
//
//  1. a dead-end node fails immediately - tested BEFORE anything else, so a
//     dead end can neither be bought nor walked through;
//  2. arriving at `from` succeeds - tested BEFORE the payload check, so the node
//     you are standing on does not block the route out of itself;
//  3. any OTHER node carrying a payload fails - you may only cross empty path
//     cells, which is what "un chemin direct" means: the next sphere along, never
//     one behind it;
//  4. otherwise recurse into the four neighbours.
//
// A portal counts as a route too: standing on a teleport node whose arrival cell
// is the node under test reaches it in one step (`Ei.b`, and the same test again
// inside the search).
//
// Buying the node you already stand on is refused, matching `Ei.b`'s first line.
func (c *SphereBoards) Reachable(boardID int32, from, to *Sphere) bool {
	if c == nil || from == nil || to == nil || from.ID == to.ID {
		return false
	}
	reachesFrom := func(n *Sphere) bool {
		return n.ID == from.ID || (from.TeleportX == n.X && from.TeleportY == n.Y)
	}
	if reachesFrom(to) {
		return true
	}

	visited := map[int32]bool{to.ID: true}
	stack := []*Sphere{to}
	first := true
	for len(stack) > 0 {
		n := stack[len(stack)-1]
		stack = stack[:len(stack)-1]
		if n.DeadEnd {
			continue
		}
		if !first && n.HasPayload() {
			continue
		}
		first = false
		for _, nb := range c.Neighbours(boardID, n) {
			if visited[nb.ID] {
				continue
			}
			if nb.DeadEnd {
				continue
			}
			if reachesFrom(nb) {
				return true
			}
			visited[nb.ID] = true
			stack = append(stack, nb)
		}
	}
	return false
}

// sortInt32Slice sorts ascending in place.
func sortInt32Slice(v []int32) {
	sort.Slice(v, func(i, j int) bool { return v[i] < v[j] })
}
