package game

import "testing"

// TestReachableCells checks the BFS movement flood: bounded by MP, 4-directional,
// blocked by fighters, over real arena floor.
func TestReachableCells(t *testing.T) {
	f, caster, _ := summonTestFight()
	// MP 0 -> nothing reachable.
	if got := f.reachableCells(caster, caster.Pos, 0); len(got) != 0 {
		t.Errorf("reachable at MP0 = %d cells, want 0", len(got))
	}
	// MP 1 from (7,15): the four cardinal floor neighbours (6,15)(8,15)(7,14)(7,16).
	r1 := f.reachableCells(caster, caster.Pos, 1)
	if len(r1) != 4 {
		t.Errorf("reachable at MP1 = %d cells, want 4", len(r1))
	}
	if p, ok := r1[[2]int32{8, 15}]; !ok || len(p) != 1 || p[0].X != 8 {
		t.Errorf("path to (8,15) = %v, want single step to (8,15)", p)
	}
	// A living fighter blocks its cell: put an ally on (8,15); it drops out.
	f.Teams[0].Fighters = append(f.Teams[0].Fighters, &FightFighter{WireID: 9, TeamID: 0, Pos: Pos{X: 8, Y: 15}, HP: 10})
	r1b := f.reachableCells(caster, caster.Pos, 1)
	if _, ok := r1b[[2]int32{8, 15}]; ok {
		t.Errorf("(8,15) held by a fighter should be unreachable")
	}
}

func TestNearestOpponent(t *testing.T) {
	f, caster, enemy := summonTestFight()
	// Add a closer enemy on team 1.
	closer := &FightFighter{WireID: 3, TeamID: 1, Pos: Pos{X: 9, Y: 15}, HP: 60, Init: 20}
	f.Teams[1].Fighters = append(f.Teams[1].Fighters, closer)

	if got := f.nearestOpponent(caster); got != closer {
		t.Errorf("nearestOpponent = %v, want the closer enemy at (9,15)", got)
	}
	// A dead nearer enemy is skipped.
	closer.HP = 0
	if got := f.nearestOpponent(caster); got != enemy {
		t.Errorf("nearestOpponent (closer dead) = %v, want the (12,15) enemy", got)
	}
	// An ally is never a target.
	if f.areOpponents(caster, f.Teams[0].Fighters[0]) {
		t.Errorf("a fighter is not its own opponent")
	}
}

func TestMoveTowardNearestOpponent(t *testing.T) {
	f, caster, _ := summonTestFight()
	// caster at (7,15), enemy at (12,15), MP 3 -> should advance east toward it.
	start := caster.Pos
	f.moveTowardNearestOpponent(caster)
	if caster.Pos == start {
		t.Fatalf("blocker did not advance from %v", start)
	}
	if manhattanDist(caster.Pos, Pos{X: 12, Y: 15}) >= manhattanDist(start, Pos{X: 12, Y: 15}) {
		t.Errorf("moved to %v (dist %d), not closer than start (dist %d)",
			caster.Pos, manhattanDist(caster.Pos, Pos{X: 12, Y: 15}), manhattanDist(start, Pos{X: 12, Y: 15}))
	}
	if caster.MP >= 3 {
		t.Errorf("MP not debited by the move: %d", caster.MP)
	}

	// Already adjacent -> no move.
	f2, c2, _ := summonTestFight()
	c2.Pos = Pos{X: 11, Y: 15} // adjacent to the (12,15) enemy
	before := c2.Pos
	f2.moveTowardNearestOpponent(c2)
	if c2.Pos != before {
		t.Errorf("moved while already adjacent: %v -> %v", before, c2.Pos)
	}
}

func TestClassifyAIBlocker(t *testing.T) {
	f, _, _ := summonTestFight()
	// A spell-less summon is a blocker (no gamedata needed).
	blocker := &FightFighter{WireID: 5, TeamID: 0, SummonSpellID: 0, Father: &FightFighter{}}
	if got := f.classifyAI(blocker); got != behaviorBlocker {
		t.Errorf("classifyAI(spell-less) = %d, want blocker", got)
	}
}

// TestRunAITurnBlockerEndsTurn: a blocker summon on its turn moves and the turn
// advances to the next fighter (no client input, no dead-wait).
func TestRunAITurnBlockerEndsTurn(t *testing.T) {
	f, caster, enemy := summonTestFight()
	// Make the summon the current fighter: insert it right after caster and point
	// the turn at it.
	summon := &FightFighter{WireID: 7, TeamID: 0, Pos: Pos{X: 7, Y: 15}, HP: 20, MaxHP: 20, MP: 3, MaxMP: 3, Father: caster}
	caster.Pos = Pos{X: 6, Y: 16} // move caster out of the summon's way
	f.Teams[0].Fighters = append(f.Teams[0].Fighters, summon)
	f.Timeline = []*FightFighter{summon, caster, enemy}
	f.turnIndex = 0

	f.runAITurn(summon)

	if f.turnIndex == 0 {
		t.Errorf("AI turn did not advance the timeline (still on the summon)")
	}
	if summon.Pos == (Pos{X: 7, Y: 15}) {
		t.Errorf("blocker summon did not move toward the enemy")
	}
}

// TestRunAITurnEndsTheTurnOfAFighterThatDiedOnIt (S40, found by the balance
// simulation): a fighter killed on its own turn — the damage its attack
// bounced back, a lethal trap — still has the turn, since a death only
// announces itself. runAITurn used to return without ending it, so an offline
// match looped forever on the dead fighter. It must move the turn on.
func TestRunAITurnEndsTheTurnOfAFighterThatDiedOnIt(t *testing.T) {
	f, caster, enemy := summonTestFight()
	f.Timeline = []*FightFighter{caster, enemy}
	f.turnIndex = 0
	caster.HP = 0 // died during its own turn, before the AI's end-of-turn

	f.runAITurn(caster)

	if f.turnIndex != 1 || f.currentFighter() != enemy {
		t.Fatalf("the turn stayed on the dead fighter (turnIndex %d)", f.turnIndex)
	}
}
