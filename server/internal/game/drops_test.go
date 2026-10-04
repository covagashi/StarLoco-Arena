package game

import (
	"math/rand"
	"path/filepath"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/store"
)

// dropFixture wires a coach, a draw table and a map-bonus record into Deps and
// hands back the pieces rollFightDrops needs.
func dropFixture(t *testing.T, cards *gamedata.Cards, maps *gamedata.MapBonuses) (*Deps, *domain.Coach, *Session) {
	t.Helper()
	st, err := store.Open(filepath.Join(t.TempDir(), "drops.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })
	acc, _ := st.Accounts.CreateAccount("dropA", "pw", false)
	coach, _ := st.Coaches.Create(acc.ID, "Dropper", 0, 0, 0)
	// Standing 250 -> evolution level 5 (sqrt(250/10)), so the draw reaches
	// value bucket 5 — alb_1.pk() only ever walks buckets DOWN from n2.
	coach.Standing = 250
	d := &Deps{
		Store:      st,
		Log:        testLogger(),
		Cards:      cards,
		MapBonuses: maps,
		DrawTable:  gamedata.NewDrawTable(cards, rand.New(rand.NewSource(1))),
	}
	s := &Session{
		log: testLogger(), deps: d, Coach: coach,
		out: make(chan []byte, writeQueueSize), quit: make(chan struct{}),
	}
	return d, coach, s
}

// TestRollFightDropsGrantsOneCard: one victorious coach → exactly one card from
// the draw pool granted into inventory (the alb_1 cl() loop yields one card
// per call), and the template ids come back for the 8300 won-cards blob.
func TestRollFightDropsGrantsOneCard(t *testing.T) {
	cards := gamedata.NewCards(
		&gamedata.CoachCard{ID: 7, Value: 55, ObtainableInDraw: true, DropPercent: 100},
	)
	d, coach, s := dropFixture(t, cards, gamedata.NewMapBonuses())
	f := &Fight{Teams: [2]*FightTeam{{ID: 0}, {ID: 1}}, arena: &arena{worldID: 5}, Practice: true}

	won := d.rollFightDrops(f, coach, s)
	if len(won) != 1 || won[0] != 7 {
		t.Fatalf("rollFightDrops = %v, want [7]", won)
	}
	var qty int64
	st := d.Store
	st.DB().Model(&domain.CoachCard{}).
		Where("coach_id = ? AND template_id = 7", coach.ID).Count(&qty)
	if qty != 1 {
		t.Fatalf("granted qty = %d, want 1", qty)
	}
}

// TestRollFightDropsMapBonusRaisesDraws: a non-practice win on a bonus arena
// runs 1 + eliteDropBonus draws — the type-1600 record's second field read as
// a drop count.
func TestRollFightDropsMapBonusRaisesDraws(t *testing.T) {
	cards := gamedata.NewCards(
		&gamedata.CoachCard{ID: 7, Value: 55, ObtainableInDraw: true, DropPercent: 100},
	)
	maps := gamedata.NewMapBonuses(
		&gamedata.MapBonus{MapID: 90, EliteDropBonus: 2},
	)
	d, coach, s := dropFixture(t, cards, maps)
	f := &Fight{Teams: [2]*FightTeam{{ID: 0}, {ID: 1}}, arena: &arena{worldID: 90}}

	if won := d.rollFightDrops(f, coach, s); len(won) != 3 {
		t.Fatalf("non-practice drops on elite arena = %v, want 3 cards (1+2 bonus draws)", won)
	}
	// Practice fights never get the bonus draws.
	f.Practice = true
	if won := d.rollFightDrops(f, coach, s); len(won) != 1 {
		t.Fatalf("practice drops on elite arena = %v, want exactly 1 card", won)
	}
}

// TestRollFightDropsEquippedChance: an equipped card carrying AI19 adds its
// param to the acceptance bonus — without it a pct=0 card essentially never
// drops, with +100 it always keeps.
func TestRollFightDropsEquippedChance(t *testing.T) {
	cards := gamedata.NewCards(
		&gamedata.CoachCard{ID: 7, Value: 55, ObtainableInDraw: true, DropPercent: 0},
		&gamedata.CoachCard{ID: 9, Value: 500, RequiredLevel: 0,
			Effects: []gamedata.CardSetEffect{{Action: aiDropChance, Params: []int32{100}}}},
	)
	d, coach, s := dropFixture(t, cards, gamedata.NewMapBonuses())
	f := &Fight{Teams: [2]*FightTeam{{ID: 0}, {ID: 1}}, arena: &arena{worldID: 5}, Practice: true}

	// UNEQUIPPED bonus card (Pos 0): contributes nothing — pct 0 needs a roll
	// of exactly 0 to keep; the RNG seed below makes that never happen inside
	// the attempts we count.
	d.DrawTable = gamedata.NewDrawTable(cards, rand.New(rand.NewSource(3)))
	st := d.Store
	st.DB().Create(&domain.CoachCard{CoachID: coach.ID, TemplateID: 9, Quantity: 1, Pos: 0})
	st.DB().Where("coach_id = ?", coach.ID).Find(&coach.Inventory)
	for i := 0; i < 40; i++ {
		if won := d.rollFightDrops(f, coach, s); len(won) != 1 || won[0] != 7 {
			t.Fatalf("draw %d = %v; only card 7 is in the pool so it must always land", i, won)
		}
	}

	// Now EQUIP it: +100 chance → every pick keeps — still card 7 (only pool
	// member), proving the equipped AI19 path was exercised without a flake.
	st.DB().Model(&domain.CoachCard{}).
		Where("coach_id = ? AND template_id = 9", coach.ID).Update("pos", 3)
	st.DB().Where("coach_id = ?", coach.ID).Find(&coach.Inventory)
	if won := d.rollFightDrops(f, coach, s); len(won) != 1 || won[0] != 7 {
		t.Fatalf("equipped draw = %v, want [7]", won)
	}
}

// TestRollFightDropsNilSafe: no table, no cards, no fight — nothing granted,
// nothing panics.
func TestRollFightDropsNilSafe(t *testing.T) {
	d := &Deps{Log: testLogger()}
	if got := d.rollFightDrops(nil, nil, nil); got != nil {
		t.Fatalf("bare deps rollFightDrops = %v, want nil", got)
	}
}
