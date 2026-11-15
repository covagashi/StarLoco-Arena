package game

import (
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// TestPostFightXPCountsTheEquippedCardsOwnEffect (S41): a coach wearing one
// "+10 % XP" card, of no complete set, banks 10 % more fight XP than one with
// nothing on — the card's own effect counts, as its text says.
func TestPostFightXPCountsTheEquippedCardsOwnEffect(t *testing.T) {
	gained := func(withCard bool) int32 {
		d, coachID, downed, survivor, st := evoDeathHarness(t)
		d.Cards = gamedata.NewCards(&gamedata.CoachCard{ID: 77, Type: 8, CardSet: 3,
			Effects: []gamedata.CardSetEffect{{Action: aiXPPercent, Params: []int32{10}, Threshold: 127}}})
		f := buildEvoFight(d, coachID, downed, survivor, true)
		coach := f.Teams[0].Members[0].Coach
		if withCard {
			coach.Inventory = []domain.CoachCard{{TemplateID: 77, Pos: 1, Quantity: 1}}
		}
		f.Teams[0].Members[0].Session = &Session{Coach: coach, deps: d, log: testLogger()}
		d.runPostFightMeta(f, 0)
		after, err := st.Fighters.Get(survivor.ID)
		if err != nil {
			t.Fatalf("reload: %v", err)
		}
		return after.XP
	}
	base, geared := gained(false), gained(true)
	if base <= 0 {
		t.Fatalf("base fight XP = %d, want some", base)
	}
	if want := base + base*10/100; geared != want {
		t.Errorf("XP with the +10 %% card = %d, want %d (base %d)", geared, want, base)
	}
}
