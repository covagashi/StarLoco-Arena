package gamedata

import (
	"os"
	"path/filepath"
	"testing"
)

func realSphereBoards(t *testing.T) *SphereBoards {
	t.Helper()
	if _, err := os.Stat(filepath.Join(clientBdataDir, "data.bdat")); err != nil {
		t.Skip("no client data")
	}
	st, err := Open(clientBdataDir)
	if err != nil {
		t.Fatal(err)
	}
	sb, err := st.LoadSphereBoards()
	if err != nil {
		t.Fatalf("load: %v", err)
	}
	return sb
}

// TestLoadSphereBoardsReal locks the type-900/901 decode against the shipped data.
//
// The load-bearing assertion is Leftover(): a record layout that is merely
// plausible will still decode into plausible-looking numbers, and the only thing
// that distinguishes it from the right one is whether it accounts for every byte
// of every record. 17 542 records with nothing left over is the proof.
func TestLoadSphereBoardsReal(t *testing.T) {
	sb := realSphereBoards(t)

	if got, want := sb.BoardCount(), 15; got != want {
		t.Errorf("decoded %d boards, want %d", got, want)
	}
	if got, want := sb.Len(), 17527; got != want {
		t.Errorf("decoded %d spheres, want %d", got, want)
	}

	for _, id := range sb.BoardIDs() {
		b := sb.Board(id)
		if lo := b.Leftover(); lo != 0 {
			t.Errorf("board %d: %d bytes unconsumed - the layout is wrong", id, lo)
		}
		if b.Season != 1 {
			t.Errorf("board %d: season %d, every shipped board is season 1", id, b.Season)
		}
		if len(sb.SpheresOf(id)) == 0 {
			t.Errorf("board %d has no nodes", id)
		}
	}

	var leftover, badBoard, dupCell int
	seen := map[boardCell]int32{}
	for _, id := range sb.BoardIDs() {
		for _, s := range sb.SpheresOf(id) {
			if s.Leftover() != 0 {
				leftover++
			}
			if sb.Board(s.BoardID) == nil {
				badBoard++
			}
			// A grid cell holds at most one node, which is what makes At() a
			// well-defined lookup for the adjacency rule.
			k := boardCell{s.BoardID, s.X, s.Y}
			if prev, ok := seen[k]; ok {
				dupCell++
				if dupCell == 1 {
					t.Errorf("board %d cell (%d,%d) holds both node %d and %d",
						s.BoardID, s.X, s.Y, prev, s.ID)
				}
			}
			seen[k] = s.ID
			if s.X <= 0 || s.Y <= 0 {
				t.Errorf("node %d has a non-positive cell (%d,%d); coordinates are 1-based",
					s.ID, s.X, s.Y)
			}
			if s.XPCost < 0 {
				t.Errorf("node %d has a negative xp cost %d", s.ID, s.XPCost)
			}
		}
	}
	if leftover != 0 {
		t.Errorf("%d sphere records had unconsumed bytes - the layout is wrong", leftover)
	}
	if badBoard != 0 {
		t.Errorf("%d spheres reference a board that does not exist", badBoard)
	}
}

// TestSphereBoardsCoverEveryPlayableBreed: the twelve boards that carry a real
// breed are one per breed, which is what makes "the board for this fighter" a
// well-defined lookup. The other three are breed 127, a sentinel rather than a
// class.
func TestSphereBoardsCoverEveryPlayableBreed(t *testing.T) {
	sb := realSphereBoards(t)

	const sentinelBreed = 127
	breeds := map[uint8]int{}
	for _, id := range sb.BoardIDs() {
		breeds[sb.Board(id).Breed]++
	}
	for breed := uint8(1); breed <= 12; breed++ {
		if breeds[breed] != 1 {
			t.Errorf("breed %d has %d boards, want exactly 1", breed, breeds[breed])
		}
	}
	if breeds[sentinelBreed] != 3 {
		t.Errorf("breed %d (sentinel) has %d boards, want 3", sentinelBreed, breeds[sentinelBreed])
	}
	if len(breeds) != 13 {
		t.Errorf("boards span %d distinct breed values, want 13 (12 real + sentinel)", len(breeds))
	}
}

// TestSphereKindsAreConsistentWithTheClientOrder checks the shipped population
// against the branches of ayr_0.aKZ(). It is a decode check dressed as a
// classification check: if a field were read at the wrong offset, these counts
// would collapse or explode rather than stay in the ranges the UI implies.
func TestSphereKindsAreConsistentWithTheClientOrder(t *testing.T) {
	sb := realSphereBoards(t)

	var spell, barrier, teleport, item, deadEnd, effects, plain int
	for _, id := range sb.BoardIDs() {
		for _, s := range sb.SpheresOf(id) {
			switch {
			case s.IsSpell():
				spell++
			case len(s.Effects) > 0:
				effects++
			case s.IsBarrier():
				barrier++
			case s.IsTeleport():
				teleport++
			case s.IsItem():
				item++
			case s.DeadEnd:
				deadEnd++
			default:
				plain++
			}
		}
	}
	// Every kind the UI has a help string for must actually occur, or the field it
	// keys off is being read from the wrong place.
	for _, c := range []struct {
		name string
		n    int
	}{
		{"Spell", spell}, {"Bonus/Malus/Summon", effects}, {"Barrier", barrier},
		{"Teleport", teleport}, {"Item", item}, {"DeadEnd", deadEnd},
	} {
		if c.n == 0 {
			t.Errorf("no %s spheres decoded; the client ships a help string for them", c.name)
		}
	}
	// Path nodes (no payload at all) are the bulk of a board: the tree is drawn on
	// a grid, so most cells are the segments joining the spheres that pay out.
	if plain <= sb.Len()/2 {
		t.Errorf("only %d of %d nodes are plain path cells; expected the majority", plain, sb.Len())
	}
}

// TestSphereBoardAtFindsNodesByCell exercises the lookup the purchase rule needs:
// "a direct path to the sphere the cursor sits on" is a neighbourhood in the grid,
// so nodes must be addressable by (board, x, y).
func TestSphereBoardAtFindsNodesByCell(t *testing.T) {
	sb := realSphereBoards(t)

	board := sb.BoardIDs()[0]
	nodes := sb.SpheresOf(board)
	if len(nodes) == 0 {
		t.Fatalf("board %d has no nodes", board)
	}
	for _, s := range nodes[:min(50, len(nodes))] {
		got := sb.At(s.BoardID, s.X, s.Y)
		if got == nil {
			t.Fatalf("node %d at (%d,%d) is not addressable by cell", s.ID, s.X, s.Y)
		}
		if got.ID != s.ID {
			t.Errorf("cell (%d,%d) resolved to node %d, want %d", s.X, s.Y, got.ID, s.ID)
		}
	}
	// A cell no node occupies must resolve to nothing rather than to a neighbour.
	if got := sb.At(board, 32000, 32000); got != nil {
		t.Errorf("an empty cell resolved to node %d", got.ID)
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// TestTeleportTargetsLandOnRealCells pins the COORDINATE ORDER, which nothing
// else can: X and Y are symmetric in every other assertion, so swapping them in
// the decoder leaves a catalogue that looks entirely reasonable.
//
// A portal's arrival cell is decoded from a different offset than the node's own
// cell, and the two must agree about which axis is which: if either pair were
// swapped, arrivals would stop landing on nodes. That makes this a genuine
// cross-check rather than the data confirming itself.
func TestTeleportTargetsLandOnRealCells(t *testing.T) {
	sb := realSphereBoards(t)

	// Split by board, because the three breed-127 boards are unfinished content and
	// one of their portals genuinely points nowhere. Holding the PLAYABLE boards to
	// the strict rule keeps the cross-check sharp instead of loosening it to a
	// tolerance that a real axis swap could hide inside.
	const sentinelBreed = 127
	playable, playableBad, sentinelBad, sentinel := 0, 0, 0, 0
	for _, id := range sb.BoardIDs() {
		isSentinel := sb.Board(id).Breed == sentinelBreed
		for _, s := range sb.SpheresOf(id) {
			if !s.IsTeleport() {
				continue
			}
			ok := sb.At(s.BoardID, s.TeleportX, s.TeleportY) != nil
			switch {
			case isSentinel:
				sentinel++
				if !ok {
					sentinelBad++
				}
			default:
				playable++
				if !ok {
					playableBad++
					if playableBad <= 3 {
						t.Errorf("portal %d on board %d points at (%d,%d), where no node exists",
							s.ID, s.BoardID, s.TeleportX, s.TeleportY)
					}
				}
			}
		}
	}
	if playable == 0 {
		t.Fatal("no portal nodes on playable boards; this proves nothing")
	}
	if playableBad != 0 {
		t.Errorf("%d of %d portals on playable boards point at empty cells", playableBad, playable)
	}
	// The sentinel boards are allowed exactly the one dangling portal the client
	// ships (57355 on board 55). More than that means something really did shift.
	if sentinelBad > 1 {
		t.Errorf("%d of %d portals on the sentinel boards dangle, want at most the 1 shipped",
			sentinelBad, sentinel)
	}
}

// TestSphereSpellIDsResolve pins SpellID against EquipmentPoolID, which are
// adjacent i32s and therefore trivially swappable without any structural
// complaint. The spell catalogue is the independent oracle: a pool id is not a
// spell id.
func TestSphereSpellIDsResolve(t *testing.T) {
	if _, err := os.Stat(filepath.Join(clientBdataDir, "data.bdat")); err != nil {
		t.Skip("no client data")
	}
	st, err := Open(clientBdataDir)
	if err != nil {
		t.Fatal(err)
	}
	sb, err := st.LoadSphereBoards()
	if err != nil {
		t.Fatalf("spheres: %v", err)
	}
	spells, err := st.LoadSpells()
	if err != nil {
		t.Skipf("spells unavailable: %v", err)
	}

	checked, missing := 0, 0
	for _, id := range sb.BoardIDs() {
		for _, s := range sb.SpheresOf(id) {
			if !s.IsSpell() {
				continue
			}
			checked++
			if spells.Get(s.SpellID) == nil {
				missing++
				if missing <= 3 {
					t.Errorf("sphere %d unlocks spell %d, which is not in the spell catalogue",
						s.ID, s.SpellID)
				}
			}
		}
	}
	if checked == 0 {
		t.Fatal("no spell spheres decoded; this proves nothing")
	}
	if missing != 0 {
		t.Errorf("%d of %d spell spheres name a spell that does not exist", missing, checked)
	}
}

// TestBoardRootCoordinatesResolve proves what ks_2.Xm() says: a board's i16 pair
// is the ROOT sphere's grid position - Xm() is literally X(fs, ft), and Ei.MQ()
// calls it to build the graph outward from that node.
func TestBoardRootCoordinatesResolve(t *testing.T) {
	sb := realSphereBoards(t)
	const sentinelBreed = 127

	checked := 0
	for _, id := range sb.BoardIDs() {
		b := sb.Board(id)
		if b.Breed == sentinelBreed {
			continue
		}
		checked++
		root := sb.At(b.ID, b.RootX, b.RootY)
		if root == nil {
			t.Errorf("board %d (breed %d): root (%d,%d) is not a node",
				b.ID, b.Breed, b.RootX, b.RootY)
			continue
		}
		if got := sb.Root(b.ID); got == nil || got.ID != root.ID {
			t.Errorf("board %d: Root() disagrees with At(RootX,RootY)", b.ID)
		}
	}
	if checked != 12 {
		t.Fatalf("checked %d playable boards, want 12", checked)
	}
}
