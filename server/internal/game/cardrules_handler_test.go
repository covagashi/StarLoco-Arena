package game

import (
	"log/slog"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/store"
	"github.com/StarLoco/arena-2.70/internal/store/storetest"
)

// cardRuleFixture builds a session with a real store and a small card table.
//
// Card 100 is a hat (type 11 -> slot 0). Card 200 is a Zaap (type 20 -> not
// equippable at all). Card 300 is unique. Card 400 is undestructible.
func cardRuleFixture(t *testing.T) (*Session, *store.Store) {
	t.Helper()
	st, err := storetest.Open(t, t.TempDir()+"/cardrules.db")
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })

	acc, _ := st.Accounts.CreateAccount("cardrules", "pw", false)
	coach, _ := st.Coaches.Create(acc.ID, "CardRules", 0, 0, 0)

	cards := gamedata.NewCards(
		&gamedata.CoachCard{ID: 100, Type: 11, Value: 10, Price: map[uint8]int32{1: 5}},
		&gamedata.CoachCard{ID: 200, Type: 20, Value: 10, Price: map[uint8]int32{1: 5}},
		&gamedata.CoachCard{ID: 300, Type: 11, Value: 10, IsUnique: true, Price: map[uint8]int32{1: 5}},
		&gamedata.CoachCard{ID: 400, Type: 11, Value: 10, Undestructible: true},
	)
	d := &Deps{Store: st, Cards: cards, Log: slog.Default(), World: NewRegistry(50)}
	return &Session{Coach: coach, deps: d, log: slog.Default()}, st
}

func ownedRows(t *testing.T, st *store.Store, coachID uint) []domain.CoachCard {
	t.Helper()
	var rows []domain.CoachCard
	if err := st.DB().Where("coach_id = ?", coachID).Find(&rows).Error; err != nil {
		t.Fatalf("load inventory: %v", err)
	}
	return rows
}

// TestEquipRefusesWrongSlotType drives applyEquipment, not just the table.
//
// A mutation bypassing the slot check survived my pure-function test, because
// nothing exercised the handler - the same gap that hid an unguarded coach-name
// handler earlier in this work.
func TestEquipRefusesWrongSlotType(t *testing.T) {
	s, st := cardRuleFixture(t)
	for _, tmpl := range []int32{100, 200} {
		if err := st.DB().Create(&domain.CoachCard{
			CoachID: s.Coach.ID, TemplateID: tmpl, Quantity: 1,
		}).Error; err != nil {
			t.Fatalf("seed card %d: %v", tmpl, err)
		}
	}
	coach, _ := st.Coaches.Get(s.Coach.ID)

	// Slot 0 is the hat slot. Put the HAT there (legal) and the ZAAP in slot 1.
	var slots [14]int32
	slots[0] = 100
	slots[1] = 200
	s.applyEquipment(coach, slots)

	for _, row := range ownedRows(t, st, s.Coach.ID) {
		switch row.TemplateID {
		case 100:
			if row.Pos != 1 {
				t.Errorf("hat should be equipped at Pos 1, got %d", row.Pos)
			}
		case 200:
			if row.Pos != 0 {
				t.Errorf("a Zaap card (type 20, {-1} in the client) was equipped at "+
					"Pos %d; fourteen cards of one set unlock every set threshold", row.Pos)
			}
		}
	}
}

// TestFusionRefusesUndestructibleInput drives handleFusionRequest's guard through
// the predicate the handler uses.
func TestFusionRefusesUndestructibleInput(t *testing.T) {
	s, _ := cardRuleFixture(t)
	if s.deps.cardIsTradable(400) {
		t.Error("card 400 is undestructible; cardIsTradable must refuse it, or " +
			"fusion/demon/barter will consume it")
	}
	if !s.deps.cardIsTradable(100) {
		t.Error("an ordinary card must remain consumable")
	}
}

// TestUniqueCardCannotBeBoughtTwice drives the shop guard's predicate pair.
func TestUniqueCardCannotBeBoughtTwice(t *testing.T) {
	s, st := cardRuleFixture(t)
	if !s.deps.cardIsUnique(300) {
		t.Fatal("fixture broken: card 300 must be unique")
	}
	if s.coachOwnsCard(300) {
		t.Fatal("fixture broken: the coach should not own it yet")
	}
	if err := st.DB().Create(&domain.CoachCard{
		CoachID: s.Coach.ID, TemplateID: 300, Quantity: 1,
	}).Error; err != nil {
		t.Fatalf("seed: %v", err)
	}
	reloaded, _ := st.Coaches.Get(s.Coach.ID)
	s.Coach = reloaded
	if !s.coachOwnsCard(300) {
		t.Error("ownership lookup does not see the card, so the shop guard " +
			"(cardIsUnique && coachOwnsCard) can never fire")
	}
}
