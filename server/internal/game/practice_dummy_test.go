package game

import (
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// S52 (owner, 2026-11-25: «1 contra 1 con un muñeco»): Nilo's practice is the
// coach's first titular alone against a training dummy on world 15.

// The launch: one fighter a side, the dummy on world 15, a few steps away,
// on nobody's start cell; other challenges are built as before.
func TestPracticeIsOneOnOneAgainstTheDummy(t *testing.T) {
	d, st := fightCreationDeps(t)
	defs, err := openRealGameData(t).LoadChallenges()
	if err != nil {
		t.Fatal(err)
	}
	d.ChallengeDefs = defs
	maps, err := gamedata.LoadFightMaps()
	if err != nil {
		t.Fatal(err)
	}
	d.FightMaps = maps
	d.initArenas()
	acc, _ := st.Accounts.CreateAccount("nilo", "pw", false)
	coach, _ := st.Coaches.Create(acc.ID, "NiloPupil", 0, 0, 0)
	for _, b := range []uint8{8, 9, 1} {
		f := &domain.Fighter{CoachID: coach.ID, BreedID: b, Name: "F", State: domain.FighterStateTitular}
		if err := st.Fighters.Create(f); err != nil {
			t.Fatal(err)
		}
	}
	s := fcSession(d, coach)
	if err := handleTeamTest(s, &protocol.C2SFrame{Payload: protocol.NewWriter().I32(46).U16(9).Bytes()}); err != nil {
		t.Fatal(err)
	}
	f := d.Fights.ByCoach(coach.ID)
	if f == nil {
		t.Fatal("no fight for challenge 46")
	}
	if f.suddenDeathTurnFor() != practiceNoSuddenDeath {
		t.Errorf("sudden death on turn %d in the practice", f.suddenDeathTurnFor())
	}
	if f.Arena().worldID != practiceWorld {
		t.Errorf("arena %d, want world %d", f.Arena().worldID, practiceWorld)
	}
	if n0, n1 := len(f.Teams[0].Fighters), len(f.Teams[1].Fighters); n0 != 1 || n1 != 1 {
		t.Fatalf("fighters %d vs %d, want 1 vs 1", n0, n1)
	}
	me, dummy := f.Teams[0].Fighters[0], f.Teams[1].Fighters[0]
	if !dummy.Dummy || dummy.Fighter.Name != dummyName || dummy.MaxAP != 0 || dummy.MaxMP != 0 {
		t.Errorf("the other side is not the dummy: %+v", dummy)
	}
	if fighterInit(dummy) >= fighterInit(me) || initiativeChooser(f) != 0 {
		t.Error("the player's side must choose who opens")
	}
	steps := pathSteps(f.Arena(), me.Pos, dummy.Pos)
	if steps != dummySteps {
		t.Errorf("the dummy stands %d steps from the player, want %d", steps, dummySteps)
	}
	for _, c := range append(f.Arena().startCells(0), f.Arena().startCells(1)...) {
		if c.X == dummy.Pos.X && c.Y == dummy.Pos.Y {
			t.Errorf("the dummy stands on a start cell %v", c)
		}
	}
	f.stopClock()
}

// pathSteps counts the steps on foot from a to b (4-connected floor), -1 if none.
func pathSteps(a *arena, from, to Pos) int {
	type n struct {
		x, y int32
		d    int
	}
	seen := map[[2]int32]bool{{from.X, from.Y}: true}
	q := []n{{from.X, from.Y, 0}}
	for len(q) > 0 {
		c := q[0]
		q = q[1:]
		if c.x == to.X && c.y == to.Y {
			return c.d
		}
		for _, s := range [][2]int32{{1, 0}, {-1, 0}, {0, 1}, {0, -1}} {
			x, y := c.x+s[0], c.y+s[1]
			if !seen[[2]int32{x, y}] && (a.walkable(x, y) || (x == to.X && y == to.Y)) {
				seen[[2]int32{x, y}] = true
				q = append(q, n{x, y, c.d + 1})
			}
		}
	}
	return -1
}

// From every start cell of world 15, the cell beside the dummy is within 3 MP
// of the start cell nearest it (the one the practice makes blink): the first
// turn reaches it.
func TestPracticeDummyIsReachableTheFirstTurn(t *testing.T) {
	d := loadArenaRegistry(t)
	a := d.arenaByID(practiceWorld)
	for _, start := range a.startCells(0) {
		dummy := dummyCell(a, start)
		best := 1 << 30
		for _, c := range a.startCells(0) {
			if s := pathSteps(a, c, dummy); s >= 0 && s < best {
				best = s
			}
		}
		if best-1 > 3 {
			t.Errorf("from %v the dummy at %v is %d steps from the nearest start cell", start, dummy, best)
		}
	}
}

// Two blows, whatever they are: the first never fells it, the second always.
func TestPracticeDummyFallsToExactlyTwoBlows(t *testing.T) {
	for _, hp := range []int32{10, 11, 37, 400} {
		for _, hit := range []int32{1, 5, 7, 60, 5000} {
			f := buildTestFight()
			me, dummy := f.Teams[0].Fighters[0], f.Teams[1].Fighters[0]
			dummy.Dummy, dummy.MaxHP, dummy.HP = true, hp, hp
			f.applyHPDelta(me, dummy, protocol.RunEffectHPLoss, 0, -hit)
			if dummy.HP <= 0 {
				t.Errorf("HP %d, hit %d: the first blow felled it", hp, hit)
			}
			f.applyHPDelta(me, dummy, protocol.RunEffectHPLoss, 0, -hit)
			if dummy.HP > 0 {
				t.Errorf("HP %d, hit %d: still up after two blows (%d left)", hp, hit, dummy.HP)
			}
		}
	}
	// a heal still heals, and nobody else is touched
	f := buildTestFight()
	me := f.Teams[0].Fighters[0]
	f.applyHPDelta(me, me, protocol.RunEffectHPLoss, 0, -7)
	if me.HP != 993 {
		t.Errorf("a fighter took %d, want 7", 1000-me.HP)
	}
}

// Its turn: it ends at once, doing nothing.
func TestPracticeDummyPassesItsTurn(t *testing.T) {
	f, caster, dummy := summonTestFight()
	dummy.Dummy, dummy.AP, dummy.MP = true, 6, 3 // even with AP and MP to spend
	dummy.Pos = Pos{X: 8, Y: 15}                 // beside the caster
	f.turnIndex = 0                              // the dummy's turn
	f.runAITurn(dummy)
	if f.turnIndex == 0 {
		t.Error("the dummy kept its turn")
	}
	if caster.HP != 75 || dummy.Pos != (Pos{X: 8, Y: 15}) {
		t.Errorf("the dummy acted: caster HP %d, dummy at %v", caster.HP, dummy.Pos)
	}
}

// The dummy's life follows the player's lesson attack: twice its base damage.
func TestPracticeDummyLifeFollowsTheLessonAttack(t *testing.T) {
	spells, err := openRealGameData(t).LoadSpells()
	if err != nil {
		t.Fatal(err)
	}
	d := &Deps{Spells: spells}
	bare := &FightFighter{Fighter: &domain.Fighter{}, MaxAP: 6}
	if got := d.lessonDamage(bare); got != closeCombatDamages {
		t.Errorf("no spells: %d, want the bare-hand %d", got, closeCombatDamages)
	}
	for b := uint8(1); b <= 12; b++ {
		fr := &domain.Fighter{BreedID: b, Spells: breedSpellRepertoire(spells, b)}
		dmg := d.lessonDamage(&FightFighter{Fighter: fr, MaxAP: 6})
		team := d.buildDummyTeam(1, &practiceArena, &FightTeam{Fighters: []*FightFighter{{Fighter: fr, MaxAP: 6}}})
		hp := team.Fighters[0].MaxHP
		if dmg <= 0 || hp != max(dummyMinHP, 2*dmg) {
			t.Errorf("breed %d: lesson damage %d, dummy life %d", b, dmg, hp)
		}
	}
}

// On the wire the dummy's hpLost is its own, like anyone's, and the 8000's
// maxima block (read from the end) carries every fighter's real maximum life,
// AP and MP — the dummy's life, a wounded fighter's AP.
func TestPracticeDummyLifeOnTheWire(t *testing.T) {
	f := buildTestFight()
	dummy := f.Teams[1].Fighters[0]
	dummy.Dummy, dummy.MaxHP, dummy.HP = true, 10, 5
	w := protocol.NewWriter()
	writeCombatFighterBlob(w, dummy)
	b := w.Bytes()
	if v, _ := protocol.NewReader(b[len(b)-12:]).I32(); v != 5 {
		t.Errorf("dummy hpLost %d, want 5 (its life − its HP)", v)
	}
	me := f.Teams[0].Fighters[0]
	me.MaxAP, me.MaxMP = 5, 2 // a wound took one of each
	frame, err := buildCreateFight(f, nil, false)
	if err != nil {
		t.Fatal(err)
	}
	if string(frame[len(frame)-4:]) != fighterMaximaMagic {
		t.Fatalf("8000 ends %q, want the maxima magic", frame[len(frame)-4:])
	}
	n := int(frame[len(frame)-5])
	want := 0
	for _, tm := range f.Teams {
		want += len(tm.Fighters)
	}
	if n != want {
		t.Fatalf("maxima rows %d, want %d", n, want)
	}
	rows := protocol.NewReader(frame[len(frame)-5-20*n : len(frame)-5])
	got := map[int64][3]int32{}
	for range n {
		id, _ := rows.I64()
		hp, _ := rows.I32()
		ap, _ := rows.I32()
		mp, _ := rows.I32()
		got[id] = [3]int32{hp, ap, mp}
	}
	if g := got[dummy.WireID]; g[0] != 10 {
		t.Errorf("dummy maxima %v, want life 10", g)
	}
	if g := got[me.WireID]; g != [3]int32{me.MaxHP, 5, 2} {
		t.Errorf("fighter maxima %v, want [%d 5 2]", g, me.MaxHP)
	}
}
