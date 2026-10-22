package game

import (
	"testing"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// trapTestFight builds a caster (team 0, current turn) vs an enemy (team 1) on
// the real practice arena, with a trap-template catalog on deps.
func trapTestFight(templates ...*gamedata.StaticEffect) (*Fight, *FightFighter, *FightFighter) {
	caster := &FightFighter{WireID: 1, TeamID: 0, Pos: Pos{X: 7, Y: 15}, HP: 75, MaxHP: 75, AP: 6, MaxAP: 6, MP: 3, MaxMP: 3, Init: 40}
	enemy := &FightFighter{WireID: 2, TeamID: 1, Pos: Pos{X: 12, Y: 15}, HP: 70, MaxHP: 70, AP: 6, MaxAP: 6, MP: 6, MaxMP: 6, Init: 50}
	f := &Fight{
		Teams: [2]*FightTeam{
			{ID: 0, Fighters: []*FightFighter{caster}},
			{ID: 1, Fighters: []*FightFighter{enemy}},
		},
		// A logger is required, not optional: a trap that kills the last enemy
		// reaches endFight, which logs unguarded. Before forced displacement
		// armed traps, no trap test could ever end a fight, so this was never hit.
		deps: &Deps{StaticEffects: gamedata.NewStaticEffects(templates...),
			Fights: NewFightManager(), Log: testLogger()},
	}
	f.Timeline = []*FightFighter{enemy, caster}
	f.turnIndex = 1 // caster's turn
	f.setPhase(PhaseAction)
	return f, caster, enemy
}

// walkOnTrap is a single-use point trap that deals 20 neutral damage (action 1)
// to whoever walks onto it (trigger 10001).
func walkOnTrap() *gamedata.StaticEffect {
	return &gamedata.StaticEffect{
		ID: 1, Type: "TRAP", AreaShape: 1, MaxExec: 1,
		AppTriggers: []int32{trapTriggerWalkOn},
		Effects:     []gamedata.Effect{{ActionID: 1, Params: []float32{20}}},
	}
}

func TestApplySetEffectAreaPlacesTrap(t *testing.T) {
	f, caster, _ := trapTestFight(walkOnTrap())

	// Cast action 66 (params[0]=template 1) at an empty cell.
	f.resolveEffect(caster, gamedata.Effect{ActionID: 66, EffectID: 900, Params: []float32{1}}, Pos{X: 10, Y: 15})

	if len(f.effectAreas) != 1 {
		t.Fatalf("effectAreas = %d, want 1", len(f.effectAreas))
	}
	a := f.effectAreas[0]
	if a.center.X != 10 || a.center.Y != 15 {
		t.Errorf("trap cell = (%d,%d), want (10,15)", a.center.X, a.center.Y)
	}
	if a.templateID != 1 || a.maxExec != 1 {
		t.Errorf("trap template=%d maxExec=%d, want 1/1", a.templateID, a.maxExec)
	}
	if a.id <= FighterWireIDBase+trapWireIDOffset {
		t.Errorf("trap id %d not in the area namespace", a.id)
	}

	// Unknown template id -> no area placed (cast still a no-op).
	f.resolveEffect(caster, gamedata.Effect{ActionID: 66, Params: []float32{999}}, Pos{X: 8, Y: 15})
	if len(f.effectAreas) != 1 {
		t.Errorf("unknown-template trap was placed: areas=%d", len(f.effectAreas))
	}
}

func TestTrapTriggersOnWalkOnAndExhausts(t *testing.T) {
	f, caster, enemy := trapTestFight(walkOnTrap())
	f.resolveEffect(caster, gamedata.Effect{ActionID: 66, Params: []float32{1}}, Pos{X: 11, Y: 15})

	// Enemy walks onto the trap cell: it fires (20 damage) and, being single-use,
	// removes itself.
	enemy.Pos = Pos{X: 11, Y: 15}
	f.checkEffectAreasMove(Pos{X: 12, Y: 15}, Pos{X: 11, Y: 15}, enemy)

	if enemy.HP != 50 {
		t.Errorf("enemy HP = %d, want 50 (took 20 trap damage)", enemy.HP)
	}
	if len(f.effectAreas) != 0 {
		t.Errorf("single-use trap not removed after firing: areas=%d", len(f.effectAreas))
	}

	// A fighter merely passing NEAR (not onto) a point trap does not trigger it.
	f2, caster2, enemy2 := trapTestFight(walkOnTrap())
	f2.resolveEffect(caster2, gamedata.Effect{ActionID: 66, Params: []float32{1}}, Pos{X: 11, Y: 15})
	f2.checkEffectAreasMove(Pos{X: 13, Y: 15}, Pos{X: 12, Y: 15}, enemy2) // 12,15 is adjacent, not on it
	if enemy2.HP != 70 || len(f2.effectAreas) != 1 {
		t.Errorf("point trap fired for an adjacent cell: hp=%d areas=%d", enemy2.HP, len(f2.effectAreas))
	}
}

func TestTrapWalkOnViaApplyFighterMove(t *testing.T) {
	// End-to-end through the move applier: the per-step hook must spring the trap.
	f, caster, enemy := trapTestFight(walkOnTrap())
	f.resolveEffect(caster, gamedata.Effect{ActionID: 66, Params: []float32{1}}, Pos{X: 11, Y: 15})

	f.applyFighterMove(enemy, []Pos{{X: 11, Y: 15}}) // 12,15 -> 11,15 onto the trap
	if enemy.HP != 50 {
		t.Errorf("enemy HP = %d, want 50 (walked onto trap via applyFighterMove)", enemy.HP)
	}
}

func TestTrapUnlimitedNotRemoved(t *testing.T) {
	tmpl := walkOnTrap()
	tmpl.MaxExec = 63 // unlimited
	f, caster, enemy := trapTestFight(tmpl)
	f.resolveEffect(caster, gamedata.Effect{ActionID: 66, Params: []float32{1}}, Pos{X: 11, Y: 15})

	// Fire twice (enter, leave, re-enter): the area persists both times.
	enemy.Pos = Pos{X: 11, Y: 15}
	f.checkEffectAreasMove(Pos{X: 12, Y: 15}, Pos{X: 11, Y: 15}, enemy)
	enemy.Pos = Pos{X: 12, Y: 15}
	f.checkEffectAreasMove(Pos{X: 11, Y: 15}, Pos{X: 12, Y: 15}, enemy) // leaving does not fire a walk-on trap
	enemy.Pos = Pos{X: 11, Y: 15}
	f.checkEffectAreasMove(Pos{X: 12, Y: 15}, Pos{X: 11, Y: 15}, enemy)

	if len(f.effectAreas) != 1 {
		t.Errorf("unlimited trap removed: areas=%d, want 1", len(f.effectAreas))
	}
	if enemy.HP != 30 {
		t.Errorf("enemy HP = %d, want 30 (two walk-on triggers × 20)", enemy.HP)
	}
}

// B-185: a fixed trap placed by an effect with a finite duration dies when that
// running effect ends (client ds_1.aK removes the area), even with an unlimited
// maxExec — Bruma (spell 153, template 2) and Bruma mortal (427, 1015) used to
// stay on the board for the rest of the fight. An infinite duration (Trampa
// Mortal, [63 0]) or none leaves the area to maxExec.
func TestTimedTrapExpiresWithItsEffect(t *testing.T) {
	tmpl := walkOnTrap()
	tmpl.MaxExec = 63
	f, caster, _ := trapTestFight(tmpl)
	f.resolveEffect(caster, gamedata.Effect{ActionID: 66, Params: []float32{1}, Duration: []int32{3, 1}}, Pos{X: 11, Y: 15})
	f.resolveEffect(caster, gamedata.Effect{ActionID: 66, Params: []float32{1}, Duration: []int32{63, 0}}, Pos{X: 10, Y: 15})
	f.resolveEffect(caster, gamedata.Effect{ActionID: 66, Params: []float32{1}}, Pos{X: 9, Y: 15})
	for round := 1; round <= 2; round++ {
		f.tickEffectAreas()
		if len(f.effectAreas) != 3 {
			t.Fatalf("after %d rounds: areas=%d, want 3", round, len(f.effectAreas))
		}
	}
	f.tickEffectAreas()
	if len(f.effectAreas) != 2 {
		t.Fatalf("after 3 rounds: areas=%d, want 2 (the 3-turn trap gone)", len(f.effectAreas))
	}
	for _, a := range f.effectAreas {
		if a.center.X == 11 {
			t.Errorf("the 3-turn trap at (11,15) is still on the board")
		}
	}
	for i := 0; i < 70; i++ {
		f.tickEffectAreas()
	}
	if len(f.effectAreas) != 2 {
		t.Errorf("infinite / untimed traps aged out: areas=%d, want 2", len(f.effectAreas))
	}
}

// Trigger 10008 (he_1.a: in the FROM and the TO footprint) fires on a step
// taken inside the area; entering only fires 10001 and stepping out fires
// neither. Template 1015 (Bruma mortal) carries both.
func TestStayTriggerFiresOnAStepInside(t *testing.T) {
	stay := &gamedata.StaticEffect{
		ID: 1015, Type: "TRAP", AreaShape: areaShapeCircle, AreaSize: []int32{2}, MaxExec: 63,
		AppTriggers: []int32{trapTriggerStay},
		Effects:     []gamedata.Effect{{ActionID: 1, Params: []float32{5}}},
	}
	f, caster, enemy := trapTestFight(stay)
	f.resolveEffect(caster, gamedata.Effect{ActionID: 66, Params: []float32{1015}}, Pos{X: 9, Y: 15})

	f.applyFighterMove(enemy, []Pos{{X: 11, Y: 15}, {X: 10, Y: 15}, {X: 9, Y: 15}})
	// 12 -> 11: entering (no 10001 on this template) — nothing; 11 -> 10 and
	// 10 -> 9: two steps inside, 5 each.
	if enemy.HP != 60 {
		t.Errorf("enemy HP = %d, want 60 (two steps inside × 5)", enemy.HP)
	}
	enemy.Pos = Pos{X: 8, Y: 15}
	f.checkEffectAreasMove(Pos{X: 9, Y: 15}, Pos{X: 8, Y: 15}, enemy) // still inside: radius 2
	f.checkEffectAreasMove(Pos{X: 8, Y: 15}, Pos{X: 7, Y: 14}, enemy) // out
	if enemy.HP != 55 {
		t.Errorf("enemy HP = %d, want 55 (one more step inside, none for leaving)", enemy.HP)
	}
}
