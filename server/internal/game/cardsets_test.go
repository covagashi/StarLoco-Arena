package game

import (
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// TestSetBonusFor pins the card-set aggregation: a bonus counts only once the
// coach has the effect's threshold worth of that set's cards EQUIPPED, and
// several sources of the same action sum.
func TestSetBonusFor(t *testing.T) {
	deps := &Deps{
		Cards: gamedata.NewCards(
			&gamedata.CoachCard{ID: 10, CardSet: 1},
			&gamedata.CoachCard{ID: 11, CardSet: 1},
			&gamedata.CoachCard{ID: 12, CardSet: 1},
			&gamedata.CoachCard{ID: 20, CardSet: 2},
			&gamedata.CoachCard{ID: 30}, // no set
		),
		CardSets: gamedata.NewCardSets(
			&gamedata.CardSet{ID: 1, Effects: []gamedata.CardSetEffect{
				{Action: aiActionResurrect, Params: []int32{5}, Threshold: 2},
				{Action: aiActionResurrect, Params: []int32{20}, Threshold: 3},
				{Action: 1, Params: []int32{99}, Threshold: 2}, // a different action
			}},
			&gamedata.CardSet{ID: 2, Effects: []gamedata.CardSetEffect{
				{Action: aiActionResurrect, Params: []int32{7}, Threshold: 1},
			}},
		),
	}
	sess := func(equipped ...int32) *Session {
		coach := &domain.Coach{ID: 1, Name: "T"}
		for i, id := range equipped {
			coach.Inventory = append(coach.Inventory,
				domain.CoachCard{TemplateID: id, Pos: int16(i + 1)})
		}
		return &Session{Coach: coach, deps: deps}
	}

	// One card of set 1: below every threshold.
	if got := sess(10).setBonusFor(aiActionResurrect); got != 0 {
		t.Errorf("1 card = %d, want 0", got)
	}
	// Two cards: unlocks the threshold-2 effect only.
	if got := sess(10, 11).setBonusFor(aiActionResurrect); got != 5 {
		t.Errorf("2 cards = %d, want 5", got)
	}
	// Three: both set-1 effects, summed.
	if got := sess(10, 11, 12).setBonusFor(aiActionResurrect); got != 25 {
		t.Errorf("3 cards = %d, want 25 (5+20)", got)
	}
	// Adding a card of another set adds that set's bonus too.
	if got := sess(10, 11, 12, 20).setBonusFor(aiActionResurrect); got != 32 {
		t.Errorf("3 of set 1 + 1 of set 2 = %d, want 32 (5+20+7)", got)
	}
	// A different action id is not mixed in.
	if got := sess(10, 11).setBonusFor(1); got != 99 {
		t.Errorf("action 1 bonus = %d, want 99", got)
	}
	// UNEQUIPPED cards must not count (Pos 0).
	unequipped := &Session{deps: deps, Coach: &domain.Coach{ID: 1, Inventory: []domain.CoachCard{
		{TemplateID: 10, Pos: 0}, {TemplateID: 11, Pos: 0}, {TemplateID: 12, Pos: 0},
	}}}
	if got := unequipped.setBonusFor(aiActionResurrect); got != 0 {
		t.Errorf("unequipped cards granted %d, want 0", got)
	}
	// No catalogue (server without data files) must be inert, not a panic.
	if got := (&Session{Coach: &domain.Coach{}, deps: &Deps{}}).setBonusFor(aiActionResurrect); got != 0 {
		t.Errorf("no catalogue = %d, want 0", got)
	}
}

// TestCoachBonusCountsTheCardsOwnEffects (S41): an equipped card's own effect
// counts without completing its set, on top of the set's unlocked effects;
// an unequipped card, or one above the coach's level, adds nothing.
func TestCoachBonusCountsTheCardsOwnEffects(t *testing.T) {
	deps := &Deps{
		Cards: gamedata.NewCards(
			&gamedata.CoachCard{ID: 10, CardSet: 1, Effects: []gamedata.CardSetEffect{
				{Action: 1, Params: []int32{4}, Threshold: 127}}},
			&gamedata.CoachCard{ID: 11, CardSet: 1, Effects: []gamedata.CardSetEffect{
				{Action: 1, Params: []int32{3}, Threshold: 127}}},
			&gamedata.CoachCard{ID: 12, RequiredLevel: 99, Effects: []gamedata.CardSetEffect{
				{Action: 1, Params: []int32{10}, Threshold: 127}}},
		),
		CardSets: gamedata.NewCardSets(&gamedata.CardSet{ID: 1, Effects: []gamedata.CardSetEffect{
			{Action: 1, Params: []int32{2}, Threshold: 2}}}),
	}
	sess := func(inv ...domain.CoachCard) *Session {
		return &Session{Coach: &domain.Coach{ID: 1, Inventory: inv}, deps: deps}
	}
	if got := sess(domain.CoachCard{TemplateID: 10, Pos: 1}).coachBonusFor(1); got != 4 {
		t.Errorf("one card = %d, want its own 4", got)
	}
	if got := sess(domain.CoachCard{TemplateID: 10, Pos: 1}, domain.CoachCard{TemplateID: 11, Pos: 2}).coachBonusFor(1); got != 9 {
		t.Errorf("two cards of the set = %d, want 4 + 3 + the set's 2", got)
	}
	if got := sess(domain.CoachCard{TemplateID: 10, Pos: 0}).coachBonusFor(1); got != 0 {
		t.Errorf("unequipped card = %d, want 0", got)
	}
	if got := sess(domain.CoachCard{TemplateID: 12, Pos: 1}).coachBonusFor(1); got != 0 {
		t.Errorf("card above the coach's level = %d, want 0", got)
	}
}

// TestResurrectChanceCapsTheGear (S41): three equipped 25 % capes add at most
// ResurrectGearBonusCap to a 25 % resurrection card, never a sure 100 %.
func TestResurrectChanceCapsTheGear(t *testing.T) {
	cape := func(id int32) *gamedata.CoachCard {
		return &gamedata.CoachCard{ID: id, Type: 10, Effects: []gamedata.CardSetEffect{
			{Action: aiActionResurrect, Params: []int32{25}, Threshold: 127}}}
	}
	potion := &gamedata.CoachCard{ID: 900, Type: gamedata.CardTypeEvolution, ResurrectPercent: 25}
	s := &Session{deps: &Deps{Cards: gamedata.NewCards(cape(1), cape(2), cape(3), potion)},
		Coach: &domain.Coach{ID: 1}}
	if got := s.resurrectChance(potion); got != 25 {
		t.Errorf("no gear = %d, want 25", got)
	}
	s.Coach.Inventory = []domain.CoachCard{{TemplateID: 1, Pos: 1}}
	if got := s.resurrectChance(potion); got != 50 {
		t.Errorf("one cape = %d, want 50", got)
	}
	s.Coach.Inventory = append(s.Coach.Inventory, domain.CoachCard{TemplateID: 2, Pos: 2}, domain.CoachCard{TemplateID: 3, Pos: 3})
	if got := s.resurrectChance(potion); got != 25+gamedata.ResurrectGearBonusCap {
		t.Errorf("three capes = %d, want %d", got, 25+gamedata.ResurrectGearBonusCap)
	}
}
