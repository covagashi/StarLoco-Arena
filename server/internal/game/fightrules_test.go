package game

import (
	"testing"
	"time"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// TestFightRulesFromParameters pins the np_1 -> ruleset mapping.
func TestFightRulesFromParameters(t *testing.T) {
	def := defaultFightRules()

	// No parameters -> the defaults, untouched. (Compared field by field: the
	// ruleset now carries slices, so it is no longer a comparable struct.)
	if got := rulesFromParameters(nil); got.TurnClock != def.TurnClock ||
		got.SuddenDeathTurn != def.SuddenDeathTurn ||
		got.BonusCellMultiplier != def.BonusCellMultiplier ||
		len(got.StartEffects) != 0 || len(got.Victory) != 0 {
		t.Errorf("empty parameter list = %+v, want the defaults %+v", got, def)
	}

	// TIMING RULES ARE DELTAS. The client's label table is explicit:
	// content.54.10 "[N] secondes en plus/moins pour jouer chaque combattant" and
	// content.54.11 "La mort subite a lieu [N] tours plus tard/tôt". Treating
	// either as an absolute silently produces a different fight.
	//
	// Challenge 46 ("Tuto de Baan") carries +3 600 000 ms — an hour ADDED to the
	// turn, which is what a tutorial wants: it must not time out on a player who
	// is reading.
	r := rulesFromParameters([]gamedata.Parameter{
		{Type: gamedata.ParamTypeTurnDurationMS, Params: []int32{3600000}},
	})
	if want := def.TurnClock + time.Hour; r.TurnClock != want {
		t.Errorf("turn clock = %v, want %v (default + 1h, not 1h flat)", r.TurnClock, want)
	}
	if r.SuddenDeathTurn != def.SuddenDeathTurn {
		t.Errorf("an unrelated rule changed sudden death to %d", r.SuddenDeathTurn)
	}

	// A NEGATIVE delta shortens things — that is the whole point of the
	// "plus/moins" wording.
	r = rulesFromParameters([]gamedata.Parameter{
		{Type: gamedata.ParamTypeTurnDurationMS, Params: []int32{-10000}},
		{Type: gamedata.ParamTypeSuddenDeathTurn, Params: []int32{-5}},
	})
	if want := def.TurnClock - 10*time.Second; r.TurnClock != want {
		t.Errorf("negative delta gave %v, want %v", r.TurnClock, want)
	}
	if want := def.SuddenDeathTurn - 5; r.SuddenDeathTurn != want {
		t.Errorf("sudden death = %d, want %d", r.SuddenDeathTurn, want)
	}

	// Sudden death later, and the bonus-cell multiplier (which IS absolute:
	// "Effets des cases bonus multipliés par [#1]").
	r = rulesFromParameters([]gamedata.Parameter{
		{Type: gamedata.ParamTypeSuddenDeathTurn, Params: []int32{10}},
		{Type: gamedata.ParamTypeBonusCellMult, Params: []int32{10}},
	})
	if want := def.SuddenDeathTurn + 10; r.SuddenDeathTurn != want {
		t.Errorf("sudden death turn = %d, want %d", r.SuddenDeathTurn, want)
	}
	if r.BonusCellMultiplier != 10 {
		t.Errorf("bonus cell multiplier = %d, want 10 (absolute, not a delta)", r.BonusCellMultiplier)
	}

	// A delta big enough to go non-positive must be ignored, not applied: a
	// zero-or-negative turn clock would end every turn instantly, and a
	// sudden-death turn of 0 would shrink the arena from the first turn.
	r = rulesFromParameters([]gamedata.Parameter{
		{Type: gamedata.ParamTypeTurnDurationMS, Params: []int32{-99999999}},
		{Type: gamedata.ParamTypeSuddenDeathTurn, Params: []int32{-9999}},
	})
	if r.TurnClock != def.TurnClock || r.SuddenDeathTurn != def.SuddenDeathTurn {
		t.Errorf("an over-large negative delta was applied: %v / %d", r.TurnClock, r.SuddenDeathTurn)
	}

	// Missing or zero values leave the default.
	for _, bad := range [][]int32{{}, {0}} {
		r = rulesFromParameters([]gamedata.Parameter{
			{Type: gamedata.ParamTypeTurnDurationMS, Params: bad},
		})
		if r.TurnClock != def.TurnClock {
			t.Errorf("turn duration %v gave clock %v, want the default %v", bad, r.TurnClock, def.TurnClock)
		}
	}

	// An unimplemented rule type is inert, not fatal — the client behaves the
	// same way (np_1.co falls back to a generic holder).
	r = rulesFromParameters([]gamedata.Parameter{{Type: 1000, Params: []int32{7}}})
	if r.TurnClock != def.TurnClock || r.SuddenDeathTurn != def.SuddenDeathTurn ||
		r.BonusCellMultiplier != def.BonusCellMultiplier ||
		len(r.StartEffects) != 0 || len(r.Victory) != 0 {
		t.Errorf("an unknown rule type changed the ruleset: %+v", r)
	}
}

// TestFightRulesArePerFight guards the reason this is not a package global: one
// fight's ruleset must never affect another.
func TestFightRulesArePerFight(t *testing.T) {
	def := defaultFightRules()
	slow := &Fight{Rules: rulesFromParameters([]gamedata.Parameter{
		{Type: gamedata.ParamTypeTurnDurationMS, Params: []int32{3600000}},
		{Type: gamedata.ParamTypeSuddenDeathTurn, Params: []int32{-13}},
	})}
	normal := &Fight{Rules: defaultFightRules()}

	if want := def.TurnClock + time.Hour; slow.turnClockFor() != want {
		t.Errorf("custom fight clock = %v, want %v", slow.turnClockFor(), want)
	}
	if normal.turnClockFor() != turnClock {
		t.Errorf("normal fight clock = %v, want the default %v", normal.turnClockFor(), turnClock)
	}
	if want := def.SuddenDeathTurn - 13; slow.suddenDeathTurnFor() != want {
		t.Errorf("custom sudden death = %d, want %d", slow.suddenDeathTurnFor(), want)
	}
	if normal.suddenDeathTurnFor() != suddenDeathTurn {
		t.Errorf("normal sudden death = %d, want the default %d", normal.suddenDeathTurnFor(), suddenDeathTurn)
	}

	// A zero-valued Fight (as several unit tests build) must still be playable.
	var bare Fight
	if bare.turnClockFor() != turnClock || bare.suddenDeathTurnFor() != suddenDeathTurn {
		t.Errorf("a fight with no rules set = %v / %d, want the defaults",
			bare.turnClockFor(), bare.suddenDeathTurnFor())
	}
}

// TestPlacementClockFollowsNoClockRules (S52): Nilo's practice (challenge 46,
// +1 h per turn) places at the player's pace; every other fight keeps the
// 30-second window, a shorter or slightly longer turn included.
func TestPlacementClockFollowsNoClockRules(t *testing.T) {
	practice := &Fight{Rules: rulesFromParameters([]gamedata.Parameter{
		{Type: gamedata.ParamTypeTurnDurationMS, Params: []int32{3600000}},
	})}
	if got := practice.placementClockFor(); got != practice.Rules.TurnClock || got < time.Hour {
		t.Errorf("practice placement window = %v, want the turn clock (%v)", got, practice.Rules.TurnClock)
	}
	for _, delta := range []int32{0, 10000, -10000} {
		f := &Fight{Rules: rulesFromParameters([]gamedata.Parameter{
			{Type: gamedata.ParamTypeTurnDurationMS, Params: []int32{delta}},
		})}
		if got := f.placementClockFor(); got != placementClock {
			t.Errorf("turn delta %d ms: placement window = %v, want %v", delta, got, placementClock)
		}
	}
	if got := (*Fight)(nil).placementClockFor(); got != placementClock {
		t.Errorf("nil fight: %v", got)
	}
}
