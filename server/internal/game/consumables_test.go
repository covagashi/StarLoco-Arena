package game

import (
	"path/filepath"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/store"
	"github.com/StarLoco/arena-2.70/internal/store/storetest"
)

// consumableHarness builds a session with a living, wounded, exhausted fighter
// and a catalogue of the consumable card kinds the shipped data actually has.
func consumableHarness(t *testing.T) (*Session, *domain.Fighter, *store.Store) {
	t.Helper()
	st, err := storetest.Open(t, filepath.Join(t.TempDir(), "cons.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })

	acc, _ := st.Accounts.CreateAccount("consA", "pw", false)
	coach, _ := st.Coaches.Create(acc.ID, "Medic", 0, 0, 0)

	eff := func(action int32, params ...int32) gamedata.CardSetEffect {
		return gamedata.CardSetEffect{Action: action, Params: params}
	}
	cards := gamedata.NewCards(
		// 320: heal ALL light wounds (the shipped healing cards are all 100%).
		&gamedata.CoachCard{ID: 320, HasUsableAction: true,
			Effects: []gamedata.CardSetEffect{eff(aiCancelWound, 100)}},
		// 340: heal ALL serious wounds.
		&gamedata.CoachCard{ID: 340, HasUsableAction: true,
			Effects: []gamedata.CardSetEffect{eff(aiWound, 100)}},
		// 401: "Baume de repos" — remove 50 fatigue.
		&gamedata.CoachCard{ID: 401, HasUsableAction: true,
			Effects: []gamedata.CardSetEffect{eff(aiTiredness, -50)}},
		// 402: morale +20.
		&gamedata.CoachCard{ID: 402, HasUsableAction: true,
			Effects: []gamedata.CardSetEffect{eff(aiMorale, 20)}},
		// 403: +500 permanent XP.
		&gamedata.CoachCard{ID: 403, HasUsableAction: true,
			Effects: []gamedata.CardSetEffect{eff(aiXPFlat, 500)}},
		// 404: apply condition 74 ("Rapide", +1 MP) for 3 fights.
		&gamedata.CoachCard{ID: 404, HasUsableAction: true,
			Effects: []gamedata.CardSetEffect{eff(aiApplyCondition, 74, 3)}},
		// 405: carries a healing effect but is NOT flagged usable — must be refused.
		&gamedata.CoachCard{ID: 405, HasUsableAction: false,
			Effects: []gamedata.CardSetEffect{eff(aiCancelWound, 100)}},
	)
	for _, id := range []int32{320, 340, 401, 402, 403, 404, 405} {
		if err := st.DB().Create(&domain.CoachCard{
			CoachID: coach.ID, TemplateID: id, Quantity: 3, Pos: 0,
		}).Error; err != nil {
			t.Fatalf("stock card %d: %v", id, err)
		}
	}

	f := &domain.Fighter{CoachID: coach.ID, BreedID: 8, Name: "Patient",
		State: domain.FighterStateTitular, Evolution: true, Budget: 600,
		Tiredness: 80, Morale: 30, XP: 100, TotalXP: 100}
	if err := st.Fighters.Create(f); err != nil {
		t.Fatalf("create fighter: %v", err)
	}
	// A light leg wound and a serious arm wound.
	if err := st.Fighters.SaveConditions(f.ID, []domain.FighterCondition{
		{ConditionID: 1, Remaining: -1},
		{ConditionID: 5, Remaining: -1},
	}); err != nil {
		t.Fatalf("seed conditions: %v", err)
	}

	d := &Deps{Store: st, Cards: cards, Conditions: woundCatalogue(), Log: testLogger()}
	s := &Session{log: testLogger(), deps: d, out: make(chan []byte, writeQueueSize),
		quit: make(chan struct{}), Coach: coach}
	return s, f, st
}

func cardCount(t *testing.T, st *store.Store, coachID uint, templateID int32) int {
	t.Helper()
	var c domain.CoachCard
	if err := st.DB().Where("coach_id = ? AND template_id = ?", coachID, templateID).
		First(&c).Error; err != nil {
		return 0
	}
	return int(c.Quantity)
}

// TestConsumableHealsWounds is the whole point: a wounded roster must be
// repairable, or the wound layer is a one-way ratchet.
func TestConsumableHealsWounds(t *testing.T) {
	SeedResurrectRand(1)
	s, f, st := consumableHarness(t)

	// A LIGHT-wound potion clears the light wound and leaves the serious one.
	useItemOn(t, s, f.ID, 320)
	got, _ := st.Fighters.Get(f.ID)
	if got.HasCondition(1) {
		t.Error("light leg wound survived a light-wound potion")
	}
	if !got.HasCondition(5) {
		t.Error("a light-wound potion removed a SERIOUS wound")
	}
	if n := cardCount(t, st, s.Coach.ID, 320); n != 2 {
		t.Errorf("card count = %d, want 2 (one consumed)", n)
	}

	// The serious potion then clears the rest.
	useItemOn(t, s, f.ID, 340)
	got, _ = st.Fighters.Get(f.ID)
	if len(got.Conditions) != 0 {
		t.Errorf("%d conditions left after both potions, want 0", len(got.Conditions))
	}
}

// TestConsumableNotSpentWhenUseless: dropping a healing card on a healthy
// fighter must NOT destroy the card.
func TestConsumableNotSpentWhenUseless(t *testing.T) {
	SeedResurrectRand(2)
	s, f, st := consumableHarness(t)
	// Clear the wounds first so the healing card has nothing to do.
	_ = st.Fighters.SaveConditions(f.ID, nil)

	useItemOn(t, s, f.ID, 320)
	if n := cardCount(t, st, s.Coach.ID, 320); n != 3 {
		t.Errorf("card count = %d, want 3 — a card that changes nothing must not be consumed", n)
	}
}

// TestConsumableRestAndMorale covers the fatigue/morale potions and their clamps.
func TestConsumableRestAndMorale(t *testing.T) {
	SeedResurrectRand(3)
	s, f, st := consumableHarness(t)

	useItemOn(t, s, f.ID, 401) // -50 fatigue from 80
	got, _ := st.Fighters.Get(f.ID)
	if got.Tiredness != 30 {
		t.Errorf("fatigue = %d, want 30", got.Tiredness)
	}
	useItemOn(t, s, f.ID, 402) // +20 morale from 30
	got, _ = st.Fighters.Get(f.ID)
	if got.Morale != 50 {
		t.Errorf("morale = %d, want 50", got.Morale)
	}

	// Clamping: a second rest balm cannot drive fatigue below zero.
	useItemOn(t, s, f.ID, 401)
	got, _ = st.Fighters.Get(f.ID)
	if got.Tiredness != 0 {
		t.Errorf("fatigue = %d, want 0 (clamped, not wrapped)", got.Tiredness)
	}
	// And once at 0 the card does nothing, so it is not consumed.
	before := cardCount(t, st, s.Coach.ID, 401)
	useItemOn(t, s, f.ID, 401)
	if after := cardCount(t, st, s.Coach.ID, 401); after != before {
		t.Errorf("a no-op rest balm was consumed (%d -> %d)", before, after)
	}
}

// TestConsumableGrantsXPAndCondition covers the XP card and the AI-15 blessing,
// which is the most common consumable action in the shipped data (165 cards).
func TestConsumableGrantsXPAndCondition(t *testing.T) {
	SeedResurrectRand(4)
	s, f, st := consumableHarness(t)

	useItemOn(t, s, f.ID, 403) // +500 XP
	got, _ := st.Fighters.Get(f.ID)
	if got.XP != 600 || got.TotalXP != 600 {
		t.Errorf("XP/TotalXP = %d/%d, want 600/600", got.XP, got.TotalXP)
	}

	useItemOn(t, s, f.ID, 404) // apply condition 74 for 3 fights
	got, _ = st.Fighters.Get(f.ID)
	if !got.HasCondition(74) {
		t.Fatal("the blessing was not applied")
	}
	for _, c := range got.Conditions {
		if c.ConditionID == 74 && c.Remaining != 3 {
			t.Errorf("blessing duration = %d, want 3 (the consumable path adds no +1)", c.Remaining)
		}
	}
	// Re-applying the same condition is refused by the exclusion rule, so the
	// second card must survive.
	before := cardCount(t, st, s.Coach.ID, 404)
	useItemOn(t, s, f.ID, 404)
	if after := cardCount(t, st, s.Coach.ID, 404); after != before {
		t.Errorf("a duplicate blessing was consumed (%d -> %d)", before, after)
	}
}

// TestConsumableRequiresUsableFlag: a card carrying the same effect but not
// flagged usable must be refused (it is a passive/equip card).
func TestConsumableRequiresUsableFlag(t *testing.T) {
	SeedResurrectRand(5)
	s, f, st := consumableHarness(t)

	useItemOn(t, s, f.ID, 405)
	got, _ := st.Fighters.Get(f.ID)
	if !got.HasCondition(1) {
		t.Error("a non-usable card healed a wound; only HasUsableAction cards are consumables")
	}
	if n := cardCount(t, st, s.Coach.ID, 405); n != 3 {
		t.Errorf("card count = %d, want 3 (not consumed)", n)
	}
}

// TestConsumableRefusedForOtherCoach guards ownership.
func TestConsumableRefusedForOtherCoach(t *testing.T) {
	SeedResurrectRand(6)
	s, f, st := consumableHarness(t)

	acc, _ := st.Accounts.CreateAccount("thief", "pw", false)
	other, _ := st.Coaches.Create(acc.ID, "Thief", 0, 0, 0)
	s.Coach = other

	useItemOn(t, s, f.ID, 320)
	got, _ := st.Fighters.Get(f.ID)
	if !got.HasCondition(1) {
		t.Error("another coach healed a fighter that is not theirs")
	}
}

// TestConsumableRefusedOnEliteFighter (S21, no pay-to-win): an Elite fighter
// is "everyone at the same level"; a potion on it does nothing and is kept.
func TestConsumableRefusedOnEliteFighter(t *testing.T) {
	SeedResurrectRand(3)
	s, f, st := consumableHarness(t)
	f.Evolution = false
	if err := st.DB().Model(f).Update("evolution", false).Error; err != nil {
		t.Fatal(err)
	}
	useItemOn(t, s, f.ID, 320)
	got, _ := st.Fighters.Get(f.ID)
	if !got.HasCondition(1) {
		t.Error("a potion healed an Elite fighter")
	}
	if n := cardCount(t, st, s.Coach.ID, 320); n != 3 {
		t.Errorf("card count = %d, want 3 (none spent)", n)
	}
}
