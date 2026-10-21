package game

import (
	"path/filepath"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store"
	"github.com/StarLoco/arena-2.70/internal/store/storetest"
)

// TestRollResurrect covers the roll itself: deterministic boundaries and a
// ~correct rate for a mid percent.
func TestRollResurrect(t *testing.T) {
	if !rollResurrect(100) {
		t.Error("100% must always succeed")
	}
	if rollResurrect(0) {
		t.Error("0% must never succeed")
	}
	if rollResurrect(-5) {
		t.Error("negative percent must never succeed")
	}
	SeedResurrectRand(12345)
	const n = 20000
	wins := 0
	for i := 0; i < n; i++ {
		if rollResurrect(50) {
			wins++
		}
	}
	if rate := float64(wins) / n; rate < 0.47 || rate > 0.53 {
		t.Errorf("50%% win rate = %.3f over %d rolls, want ~0.5", rate, n)
	}
}

// resurrectHarness builds a session backed by a real store plus a small card
// catalogue of Evolution (type 24) consumables: 900 = certain (100%),
// 901 = not a resurrection card (0%), 902 = 1% gamble; and 903, an equipment
// card (type 10) whose 1% "come back during a fight" effect must not work here.
func resurrectHarness(t *testing.T) (*Session, *domain.Coach, *store.Store) {
	t.Helper()
	st, err := storetest.Open(t, filepath.Join(t.TempDir(), "res.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })

	acc, _ := st.Accounts.CreateAccount("resA", "pw", false)
	coach, _ := st.Coaches.Create(acc.ID, "Necro", 0, 0, 0)

	cards := gamedata.NewCards(
		&gamedata.CoachCard{ID: 900, Type: gamedata.CardTypeEvolution, ResurrectPercent: 100},
		&gamedata.CoachCard{ID: 901, Type: gamedata.CardTypeEvolution, ResurrectPercent: 0},
		&gamedata.CoachCard{ID: 902, Type: gamedata.CardTypeEvolution, ResurrectPercent: 1},
		&gamedata.CoachCard{ID: 903, Type: 10, ResurrectPercent: 1},
	)
	for _, id := range []int32{900, 901, 902, 903} {
		if err := st.DB().Create(&domain.CoachCard{
			CoachID: coach.ID, TemplateID: id, Quantity: 5, Pos: 0,
		}).Error; err != nil {
			t.Fatalf("stock card %d: %v", id, err)
		}
	}

	d := &Deps{Store: st, Cards: cards, Log: testLogger()}
	s := &Session{
		log:   testLogger(),
		deps:  d,
		out:   make(chan []byte, writeQueueSize),
		quit:  make(chan struct{}),
		Coach: coach,
	}
	return s, coach, st
}

func makeDeadFighter(t *testing.T, st *store.Store, coachID uint, state uint8) uint {
	t.Helper()
	f := &domain.Fighter{CoachID: coachID, BreedID: 1, Name: "Corpse", State: state, Budget: 400}
	if err := st.Fighters.Create(f); err != nil {
		t.Fatalf("create fighter: %v", err)
	}
	return f.ID
}

func useItemOn(t *testing.T, s *Session, fighterID uint, cardID int32) {
	t.Helper()
	p := protocol.NewWriter().I64(int64(fighterID)).I32(cardID).Bytes()
	if err := handleFighterUseItemOn(s, &protocol.C2SFrame{Payload: p}); err != nil {
		t.Fatalf("handler: %v", err)
	}
}

func fighterStateOf(t *testing.T, st *store.Store, id uint) uint8 {
	t.Helper()
	f, err := st.Fighters.Get(id)
	if err != nil {
		t.Fatalf("get fighter: %v", err)
	}
	return f.State
}

func cardQtyOf(t *testing.T, st *store.Store, coachID uint, tmpl int32) int16 {
	t.Helper()
	c, err := st.Coaches.Get(coachID)
	if err != nil {
		t.Fatalf("get coach: %v", err)
	}
	for _, card := range c.Inventory {
		if card.TemplateID == tmpl {
			return card.Quantity
		}
	}
	return 0
}

// TestResurrectCertainCardRevives: a 100% card revives, with the right state
// transition, and is consumed.
func TestResurrectCertainCardRevives(t *testing.T) {
	s, coach, st := resurrectHarness(t)
	dead := makeDeadFighter(t, st, coach.ID, domain.FighterStateDead)
	grave := makeDeadFighter(t, st, coach.ID, domain.FighterStateGraveyard)

	useItemOn(t, s, dead, 900)
	if got := fighterStateOf(t, st, dead); got != domain.FighterStateTitular {
		t.Errorf("dead + 100%% -> state %d, want titular(0)", got)
	}
	useItemOn(t, s, grave, 900)
	if got := fighterStateOf(t, st, grave); got != domain.FighterStateBench {
		t.Errorf("graveyard + 100%% -> state %d, want bench(1)", got)
	}
	if q := cardQtyOf(t, st, coach.ID, 900); q != 3 {
		t.Errorf("card 900 qty = %d, want 3 (two consumed)", q)
	}
}

// TestResurrectNonResurrectionCardRefused: dropping a card with no resurrection
// effect does nothing AND does not consume the card (matches the client's aaF
// gate).
func TestResurrectNonResurrectionCardRefused(t *testing.T) {
	s, coach, st := resurrectHarness(t)
	dead := makeDeadFighter(t, st, coach.ID, domain.FighterStateDead)

	useItemOn(t, s, dead, 901)
	if got := fighterStateOf(t, st, dead); got != domain.FighterStateDead {
		t.Errorf("non-resurrection card changed state to %d, want dead(2)", got)
	}
	if q := cardQtyOf(t, st, coach.ID, 901); q != 5 {
		t.Errorf("non-resurrection card qty = %d, want 5 (must NOT be consumed)", q)
	}
}

// TestResurrectFailedRollConsumesButKeepsDead: a real resurrection card whose
// roll fails is consumed (the gamble) but the fighter stays dead.
func TestResurrectFailedRollConsumesButKeepsDead(t *testing.T) {
	s, coach, st := resurrectHarness(t)
	dead := makeDeadFighter(t, st, coach.ID, domain.FighterStateDead)

	// Find a seed whose first roll fails a 1% card (almost every seed does). Doing
	// it deterministically avoids a flaky "1% almost always fails" assumption.
	var seed int64
	for seed = 1; seed <= 100; seed++ {
		SeedResurrectRand(seed)
		if !rollResurrect(1) { // consumes one value; reseed identically below
			break
		}
	}
	SeedResurrectRand(seed) // same seed -> the handler's roll will also fail

	useItemOn(t, s, dead, 902)
	if got := fighterStateOf(t, st, dead); got != domain.FighterStateDead {
		t.Errorf("failed roll changed state to %d, want dead(2)", got)
	}
	if q := cardQtyOf(t, st, coach.ID, 902); q != 4 {
		t.Errorf("card 902 qty = %d, want 4 (consumed despite the failed roll)", q)
	}
}

// TestResurrectEquipmentCardRefused: the retail graveyard only offers cards of
// the Evolution sets (type 24: aij_0 evolutionSets, aMK.dYy). An equipment card
// also carries the resurrection effect (its chance to come back during a
// fight), and accepting it here let a modified client gamble cheap equipment
// (Weerdtrot Jacket: value 57, 1%) instead of a Resurrection (33200, 100%).
// It must be refused and NOT consumed, even when the roll would have passed.
func TestResurrectEquipmentCardRefused(t *testing.T) {
	s, coach, st := resurrectHarness(t)
	dead := makeDeadFighter(t, st, coach.ID, domain.FighterStateDead)
	for i := 0; i < 5; i++ {
		SeedResurrectRand(int64(i))
		useItemOn(t, s, dead, 903)
	}
	if got := fighterStateOf(t, st, dead); got != domain.FighterStateDead {
		t.Errorf("state = %d, want %d (still dead)", got, domain.FighterStateDead)
	}
	if q := cardQtyOf(t, st, coach.ID, 903); q != 5 {
		t.Errorf("card 903 qty = %d, want 5 (an equipment card is never spent here)", q)
	}
}
