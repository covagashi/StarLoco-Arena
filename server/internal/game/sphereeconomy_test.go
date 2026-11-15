package game

import (
	"testing"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// sphereeconomy_test.go ties the two halves of fighter progression together. The
// Sphere Board is the only thing that SPENDS fighter experience and the post-fight
// report is the only thing that grants it, and until now nothing checked that the
// numbers meet: a board whose cheapest node costs more than a fight pays would be
// unreachable forever, and no test of either half alone would notice.
//
// It reads server/content, which carries all 15 boards, so it runs in CI
// rather than only where a client is installed.

// sentinelBreedID is the breed the three unfinished boards carry; it is not a
// class. gamedata keeps its own unexported copy for the same reason.
const sentinelBreedID = 127

func economyBoards(t *testing.T) *gamedata.SphereBoards {
	t.Helper()
	boards, err := openRealGameData(t).LoadSphereBoards()
	if err != nil {
		t.Fatalf("boards: %v", err)
	}
	return boards
}

// TestANewFighterCanAffordItsFirstSphere is the entry condition of the whole
// system. A fighter starts on the board's root with no experience; if the
// cheapest node it can actually REACH from there costs more than a fight pays, the
// Kanodo is decorative.
//
// Reachability matters here rather than the cheapest node anywhere: a 2 xp node on
// the far side of the board is no use to a fighter that cannot walk to it.
func TestANewFighterCanAffordItsFirstSphere(t *testing.T) {
	boards := economyBoards(t)
	checked := 0
	for _, id := range boards.BoardIDs() {
		// Playable breeds only. Two of the three breed-127 boards do resolve a
		// root, so filtering on that would quietly pull unfinished content into a
		// rule about real fighters.
		if boards.Board(id).Breed == sentinelBreedID {
			continue
		}
		root := boards.Root(id)
		if root == nil {
			t.Errorf("board %d (breed %d) has no root", id, boards.Board(id).Breed)
			continue
		}
		checked++
		cheapest := int32(1 << 30)
		for _, s := range boards.SpheresOf(id) {
			if s.XPCost > 0 && s.XPCost < cheapest && boards.Reachable(id, root, s) {
				cheapest = s.XPCost
			}
		}
		if cheapest == 1<<30 {
			t.Errorf("board %d: no priced node is reachable from the root at all", id)
			continue
		}
		if cheapest > DefaultRules().BaseXPPerFight {
			t.Errorf("board %d: the cheapest reachable node costs %d xp but a fight pays %d - "+
				"a new fighter could never start", id, cheapest, DefaultRules().BaseXPPerFight)
		}
	}
	if checked != 12 {
		t.Fatalf("checked %d playable boards, want 12", checked)
	}
}

// TestTheMostExpensiveSphereIsBuyable: bank() refuses further gains once spendable
// XP reaches maxSpendableXP, so a node costing more than that ceiling could never
// be paid for however long the fighter fought.
func TestTheMostExpensiveSphereIsBuyable(t *testing.T) {
	boards := economyBoards(t)
	var dearest int32
	for _, id := range boards.BoardIDs() {
		for _, s := range boards.SpheresOf(id) {
			if s.XPCost > dearest {
				dearest = s.XPCost
			}
		}
	}
	if dearest == 0 {
		t.Fatal("no priced nodes; this proves nothing")
	}
	if dearest >= maxSpendableXP {
		t.Errorf("the dearest node costs %d but a fighter may bank only %d - it is unbuyable",
			dearest, maxSpendableXP)
	}
}

// TestABoardOutlastsAFightersLevelLadder records the shape of the mechanic: a full
// board costs far more than the experience that carries a fighter to the top of
// its level ladder, so the Kanodo is a series of CHOICES rather than a checklist -
// "apprendre a parcourir intelligemment le kanodo", as the client puts it.
//
// A tripwire, not a rule of nature: if someone retunes DefaultRules().BaseXPPerFight or the level
// steps until a fighter can simply buy everything, that is a design change and
// should have to be made deliberately.
func TestABoardOutlastsAFightersLevelLadder(t *testing.T) {
	boards := economyBoards(t)
	maxLevelXP := fighterLevelSteps[len(fighterLevelSteps)-1]

	for _, id := range boards.BoardIDs() {
		if boards.Board(id).Breed == sentinelBreedID {
			continue
		}
		var total int64
		for _, s := range boards.SpheresOf(id) {
			total += int64(s.XPCost)
		}
		if total <= int64(maxLevelXP) {
			t.Errorf("board %d costs %d xp in total, but a fighter reaches its top level at %d - "+
				"the board can be bought out", id, total, maxLevelXP)
		}
	}
}
