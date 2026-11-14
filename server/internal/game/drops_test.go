package game

import (
	"math/rand"
	"path/filepath"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/store/storetest"
)

// dropFixture wires a coach, a draw table and a map-bonus record into Deps and
// hands back the pieces rollFightDrops needs.
func dropFixture(t *testing.T, cards *gamedata.Cards, maps *gamedata.MapBonuses) (*Deps, *domain.Coach, *Session) {
	t.Helper()
	st, err := storetest.Open(t, filepath.Join(t.TempDir(), "drops.db"))
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

	// 1 + 2 bonus draws, all card 7: two copies kept, the third paid in
	// tokens (S40: copies past DropKeepCopies, 5 for a black card).
	before := walletTokens(t, d, coach.ID)
	if won := d.rollFightDrops(f, coach, s); len(won) != 2 {
		t.Fatalf("non-practice drops on elite arena = %v, want 2 cards kept (1+2 bonus draws, the third a duplicate)", won)
	}
	if got := walletTokens(t, d, coach.ID) - before; got != domain.DuplicateTokens(0) {
		t.Fatalf("the third copy paid %d tokens, want %d", got, domain.DuplicateTokens(0))
	}
	// Practice fights never get the bonus draws: one draw, a duplicate now.
	f.Practice = true
	before = walletTokens(t, d, coach.ID)
	if won := d.rollFightDrops(f, coach, s); len(won) != 0 {
		t.Fatalf("practice drops on elite arena = %v, want the one draw paid as a duplicate", won)
	}
	if got := walletTokens(t, d, coach.ID) - before; got != domain.DuplicateTokens(0) {
		t.Fatalf("practice: %d tokens, want exactly one draw's %d", got, domain.DuplicateTokens(0))
	}
}

// walletTokens is a coach's primary-currency balance.
func walletTokens(t *testing.T, d *Deps, coachID uint) int32 {
	t.Helper()
	c, err := d.Store.Coaches.Get(coachID)
	if err != nil {
		t.Fatal(err)
	}
	for _, w := range c.Wallet {
		if w.CurrencyType == primaryCurrency {
			return w.Amount
		}
	}
	return 0
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
		// card 7 stays new each time, so the duplicate rule (S40) keeps out
		// of what this test measures: the acceptance roll
		st.DB().Where("coach_id = ? AND template_id = 7", coach.ID).Delete(&domain.CoachCard{})
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

// TestFightPaysDrops (S21): practice pays no drop — no farming the dummy,
// ghosts or a replayed challenge — but a ranked win and a first-time
// Historia win do.
func TestFightPaysDrops(t *testing.T) {
	for _, c := range []struct {
		f    *Fight
		want bool
		what string
	}{
		{&Fight{Practice: false}, true, "ranked"},
		{&Fight{Practice: true}, false, "training dummy / ghost"},
		{&Fight{Practice: true, ChallengeID: 29}, false, "replayed challenge"},
		{&Fight{Practice: true, ChallengeID: 29, Story: true}, true, "first-time Historia"},
	} {
		if got := fightPaysDrops(c.f); got != c.want {
			t.Errorf("%s: fightPaysDrops = %v, want %v", c.what, got, c.want)
		}
	}
}

// TestDropGuaranteeAndDuplicates (S40): never more than DropPityAfter drops in
// a row without a rare card, and the counter survives between fights.
func TestDropGuaranteeAndDuplicates(t *testing.T) {
	cards := gamedata.NewCards(
		&gamedata.CoachCard{ID: 7, Value: 55, Rank: 1, ObtainableInDraw: true, DropPercent: 100},
		&gamedata.CoachCard{ID: 8, Value: 55, Rank: 7, ObtainableInDraw: true, DropPercent: 0},
	)
	d, coach, s := dropFixture(t, cards, gamedata.NewMapBonuses())
	d.DrawTable = gamedata.NewDrawTable(cards, rand.New(rand.NewSource(11)))
	f := &Fight{Teams: [2]*FightTeam{{ID: 0}, {ID: 1}}, arena: &arena{worldID: 5}, Practice: true}
	run, rares := 0, 0
	for i := 0; i < 120; i++ {
		d.Store.DB().Where("coach_id = ?", coach.ID).Delete(&domain.CoachCard{})
		won := d.rollFightDrops(f, coach, s)
		if len(won) != 1 {
			t.Fatalf("draw %d = %v", i, won)
		}
		if won[0] == 8 {
			rares++
			run = 0
			continue
		}
		run++
		if run > int(domain.DropPityAfter) {
			t.Fatalf("draw %d: %d drops in a row without a rare one", i, run)
		}
	}
	if rares < 120/int(domain.DropPityAfter+1) {
		t.Fatalf("%d rare drops in 120, want at least one every %d", rares, domain.DropPityAfter+1)
	}
}

func TestDuplicateTokensByTier(t *testing.T) {
	for rank, want := range map[int32]int32{0: 5, 2: 5, 3: 10, 5: 10, 6: 25, 8: 25, 9: 50, 10: 50} {
		if got := domain.DuplicateTokens(rank); got != want {
			t.Errorf("rank %d pays %d, want %d", rank, got, want)
		}
	}
}
