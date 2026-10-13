package game

import (
	"fmt"
	"math/rand"
	"strings"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// determinism_test.go is the proof behind the claim "same seed = same fight".
//
// The valuable assertion is not that rngSource() returns the right stream — it
// is that a WHOLE FIGHT, dice and decisions together, replays identically from
// a stored seed, and visibly differently from a different one. The second half
// matters as much as the first: a determinism test whose fight never rolls
// anything passes trivially, so TestFightDeterminismDifferentSeedsDiffer exists
// to make sure the dice are actually load-bearing in the fight being compared.

// determinismSpellID is the 3d6+2 dice spell both sides fight with. Three
// params is what makes gamedata.Effect.Roll take the DICE path rather than a
// fixed value — without it the fight would be deterministic for the wrong
// reason.
const determinismSpellID int32 = 7701

func determinismSpells() *gamedata.Spells {
	return gamedata.NewSpells(&gamedata.Spell{
		ID: determinismSpellID, AP: 3, RangeMin: 1, RangeMax: 6,
		Effects: []gamedata.Effect{
			{ActionID: 3, EffectID: 77010, Params: []float32{3, 6, 2}},
		},
	})
}

// determinismFight builds a 2v2 of session-less fighters on the practice arena,
// all four driven by the built-in AI, with the given stored seed.
//
// Every fighter carries the dice spell as its DEFINING spell (so classifyAI
// reads "aggressive": close into range, cast until dry, then spend leftover AP
// on close combat) plus a crit and a fumble rate, so a turn consumes the RNG
// for the fumble roll, the crit roll and the damage dice. HP is deliberately
// large: the fight is compared after a fixed number of turns rather than at a
// death, so the comparison is of accumulated rolls and not of who happened to
// die first.
func determinismFight(seed int64) *Fight {
	mk := func(wire int64, coach uint, team uint8, name string, x, y, init int32) *FightFighter {
		return &FightFighter{
			WireID: wire, CoachID: coach, TeamID: team,
			Pos:           Pos{X: x, Y: y},
			SummonSpellID: determinismSpellID,
			Fighter: &domain.Fighter{
				ID: uint(wire), BreedID: 1, Name: name,
				Spells: []domain.FighterSpell{{SpellID: determinismSpellID}},
			},
			HP: 4000, MaxHP: 4000, AP: 6, MaxAP: 6, MP: 3, MaxMP: 3,
			Init: init, CritRate: 25, FumbleRate: 15,
		}
	}
	f := &Fight{
		Teams: [2]*FightTeam{
			{ID: 0, Fighters: []*FightFighter{
				mk(101, 1, 0, "A0", 7, 15, 80),
				mk(102, 1, 0, "A1", 7, 16, 60),
			}},
			{ID: 1, Fighters: []*FightFighter{
				mk(201, 2, 1, "B0", 12, 15, 70),
				mk(202, 2, 1, "B1", 12, 16, 50),
			}},
		},
		deps: &Deps{
			Spells: determinismSpells(),
			Fights: NewFightManager(),
			Log:    testLogger(),
		},
		readyPresent: map[uint]bool{}, readyObserve: map[uint]bool{}, readyAction: map[uint]bool{},
	}
	f.SetSeed(seed)
	f.Timeline = buildTimeline(f)
	f.turnIndex = 0
	f.tableTurn = 1
	f.setPhase(PhaseAction)
	return f
}

// runDeterminismFight plays `turns` AI turns synchronously on the caller's
// goroutine (no actor, no clocks) so the run is repeatable by construction.
func runDeterminismFight(f *Fight, turns int) {
	for i := 0; i < turns && f.Phase() == PhaseAction; i++ {
		cur := f.currentFighter()
		if cur == nil {
			break
		}
		f.runAITurn(cur)
	}
	f.stopClock() // drop the turn timer beginTurn armed for the next fighter
}

// determinismDigest renders everything a replay has to reproduce: each
// fighter's HP/AP/MP/cell, where the fight is in its turn order, and the whole
// decision log. Including the log means the digest also catches two runs that
// reach the same HP by a different sequence of actions.
func determinismDigest(f *Fight) string {
	var b strings.Builder
	for _, ff := range f.allFighters() {
		fmt.Fprintf(&b, "wire=%d hp=%d ap=%d mp=%d pos=(%d,%d)\n",
			ff.WireID, ff.HP, ff.AP, ff.MP, ff.Pos.X, ff.Pos.Y)
	}
	fmt.Fprintf(&b, "round=%d turnIndex=%d\n", f.tableTurn, f.turnIndex)
	for _, d := range f.decisionLog() {
		b.WriteString(d.String())
		b.WriteByte('\n')
	}
	return b.String()
}

// TestFightRngSeededFromStoredSeed: the fight's dice come from the STORED seed,
// not from the clock. Two fights holding the same seed roll the same sequence,
// and that sequence is exactly math/rand's for that seed — which is what makes
// a seed written down today replay the same fight later.
func TestFightRngSeededFromStoredSeed(t *testing.T) {
	const seed int64 = 0x5EED1234

	want := make([]int, 16)
	ref := rand.New(rand.NewSource(seed))
	for i := range want {
		want[i] = ref.Intn(1000)
	}

	for _, name := range []string{"first", "second"} {
		f := &Fight{}
		f.SetSeed(seed)
		for i, w := range want {
			if got := f.rngSource().Intn(1000); got != w {
				t.Fatalf("%s fight roll %d = %d, want %d (seed %d)", name, i, got, w, seed)
			}
		}
	}
}

// TestFightSeedAssignedAtCreation: every fight gets a seed at creation, through
// the one choke point all creation paths share, and an already-seeded fight (a
// replay) keeps the seed it was given.
func TestFightSeedAssignedAtCreation(t *testing.T) {
	m := NewFightManager()

	a, b := buildTestFight(), buildTestFight()
	m.Create(a)
	m.Create(b)
	if a.Seed() == 0 || b.Seed() == 0 {
		t.Fatalf("seeds after Create = %d / %d, want both non-zero", a.Seed(), b.Seed())
	}
	if a.Seed() == b.Seed() {
		t.Errorf("two fights got the same seed %d; each fight must roll its own dice", a.Seed())
	}

	// A seed set beforehand is a replay instruction: Create must not clobber it.
	replay := buildTestFight()
	replay.SetSeed(99)
	m.Create(replay)
	if replay.Seed() != 99 {
		t.Errorf("preset seed = %d after Create, want 99 (a replay's seed is not reassigned)", replay.Seed())
	}

	// A fight that never went through Create still has a seed once it rolls, so
	// there is always one value that reproduces what it rolled.
	loose := &Fight{}
	_ = loose.rngSource()
	if loose.Seed() == 0 {
		t.Error("a fight that has rolled still reports seed 0; the roll is unreproducible")
	}
}

// TestNewFightSeedIsNonZeroAndVaries: 0 is the "unassigned" sentinel, so a
// drawn seed is never 0 — and the draw is not a constant.
func TestNewFightSeedIsNonZeroAndVaries(t *testing.T) {
	seen := map[int64]bool{}
	for i := 0; i < 64; i++ {
		s := newFightSeed()
		if s == 0 {
			t.Fatal("newFightSeed returned 0, which is the unassigned sentinel")
		}
		if s < 0 {
			t.Fatalf("newFightSeed returned %d, want a non-negative seed", s)
		}
		seen[s] = true
	}
	if len(seen) < 60 {
		t.Errorf("64 draws produced only %d distinct seeds; the seed must not be predictable", len(seen))
	}
}

// TestFightDeterminismSameSeedSameOutcome is the core guarantee: the same seed
// plus the same inputs replays the same fight, down to each fighter's HP, cell
// and every action taken.
func TestFightDeterminismSameSeedSameOutcome(t *testing.T) {
	const seed int64 = 20260413
	const turns = 24

	first := determinismFight(seed)
	runDeterminismFight(first, turns)
	a := determinismDigest(first)

	second := determinismFight(seed)
	runDeterminismFight(second, turns)
	b := determinismDigest(second)

	if a != b {
		t.Fatalf("same seed produced different fights\n--- run 1 ---\n%s\n--- run 2 ---\n%s", a, b)
	}
	// Guard against the whole thing passing because nothing happened.
	if len(first.decisionLog()) == 0 {
		t.Fatal("the fight recorded no decisions at all; the comparison proves nothing")
	}
	dealt := int32(0)
	for _, ff := range first.allFighters() {
		dealt += ff.MaxHP - ff.HP
	}
	if dealt == 0 {
		t.Fatalf("no damage was dealt over %d turns; the dice are not being exercised", turns)
	}
}

// TestFightDeterminismSameSeedRepeats runs the same seed a handful of times, so
// a difference that only shows up occasionally (a map iteration order deciding
// something) cannot slip through a single comparison.
func TestFightDeterminismSameSeedRepeats(t *testing.T) {
	const seed int64 = 777
	const turns = 20

	base := determinismFight(seed)
	runDeterminismFight(base, turns)
	want := determinismDigest(base)

	for i := 0; i < 8; i++ {
		f := determinismFight(seed)
		runDeterminismFight(f, turns)
		if got := determinismDigest(f); got != want {
			t.Fatalf("run %d diverged from the first run on seed %d\n--- want ---\n%s\n--- got ---\n%s",
				i, seed, want, got)
		}
	}
}

// TestFightDeterminismDifferentSeedsDiffer: a different seed must produce a
// different fight. Without this the determinism test above could pass with the
// RNG unused entirely.
func TestFightDeterminismDifferentSeedsDiffer(t *testing.T) {
	const turns = 24

	digests := map[string][]int64{}
	seeds := []int64{1, 2, 3, 5, 8, 13, 21, 34}
	for _, seed := range seeds {
		f := determinismFight(seed)
		runDeterminismFight(f, turns)
		d := determinismDigest(f)
		digests[d] = append(digests[d], seed)
	}
	if len(digests) < 2 {
		t.Fatalf("all %d seeds produced the identical fight; the stored seed is not reaching the dice",
			len(seeds))
	}
	// Most seeds should give their own fight: a near-collapse would mean the seed
	// barely influences the outcome.
	if len(digests) < len(seeds)-1 {
		t.Errorf("%d seeds produced only %d distinct fights: %v", len(seeds), len(digests), digests)
	}
}

// TestFightDecisionLogRecordsTurnFighterAction covers the log's shape: one row
// per action, each carrying the round, the acting fighter and what it did, with
// the AI's chosen plan recorded before the actions it leads to.
func TestFightDecisionLogRecordsTurnFighterAction(t *testing.T) {
	f := determinismFight(4242)
	runDeterminismFight(f, 8)

	log := f.decisionLog()
	if len(log) == 0 {
		t.Fatal("decision log is empty after 8 AI turns")
	}

	kinds := map[fightDecisionKind]int{}
	wires := map[int64]bool{}
	for i, d := range log {
		if d.Round < 1 {
			t.Errorf("row %d (%s) has round %d, want the 1-indexed table turn", i, d, d.Round)
		}
		if d.WireID == 0 {
			t.Errorf("row %d (%s) names no fighter", i, d)
		}
		if d.Kind == "" {
			t.Errorf("row %d (%s) records no action", i, d)
		}
		if !d.AI {
			t.Errorf("row %d (%s) is not marked AI-driven, but no fighter here has a session", i, d)
		}
		if d.Name == "" {
			t.Errorf("row %d (%s) lost the fighter's name", i, d)
		}
		kinds[d.Kind]++
		wires[d.WireID] = true
	}

	if kinds[decisionBehavior] == 0 {
		t.Error("no behavior row: the log does not record which plan the AI played")
	}
	if kinds[decisionCast] == 0 && kinds[decisionCloseCombat] == 0 {
		t.Error("no cast or close-combat row: the log records no action taken")
	}
	if len(wires) < 2 {
		t.Errorf("log covers %d fighter(s); 8 turns should reach several", len(wires))
	}
	// The first row of the fight is the first fighter's plan, on round 1.
	if log[0].Kind != decisionBehavior || log[0].Round != 1 {
		t.Errorf("first row = %s, want a round-1 behavior row", log[0])
	}
}

// TestFightDecisionLogRecordsPass: a turn that ends having done nothing is
// still a decision — the log must not silently skip it, or a replay would lose
// a turn.
func TestFightDecisionLogRecordsPass(t *testing.T) {
	f := buildTestFight() // no spells, no gamedata: nobody can act
	f.deps = &Deps{Log: testLogger(), Fights: NewFightManager()}
	f.setPhase(PhaseAction)
	f.tableTurn = 1
	f.turnIndex = 0
	cur := f.currentFighter()
	if cur == nil {
		t.Fatal("test fight has no current fighter")
	}
	f.turnActions = 0

	f.endTurn(cur.WireID)
	f.stopClock()

	log := f.decisionLog()
	if len(log) == 0 {
		t.Fatal("a turn ended with no action and nothing was logged")
	}
	first := log[0]
	if first.Kind != decisionPass {
		t.Fatalf("first row = %s, want a pass", first)
	}
	if first.WireID != cur.WireID {
		t.Errorf("pass recorded for wire %d, want %d", first.WireID, cur.WireID)
	}
	if first.Round != 1 {
		t.Errorf("pass round = %d, want 1 (the round the pass happened on)", first.Round)
	}
}

// TestFightDecisionLogCapped: the log is bounded. A fight cannot grow it without
// limit, and the EARLY rows are the ones kept — a replay runs forwards.
func TestFightDecisionLogCapped(t *testing.T) {
	f := buildTestFight()
	f.deps = &Deps{Log: testLogger()}
	ff := f.Timeline[0]
	for i := 0; i < maxFightDecisions+100; i++ {
		f.tableTurn = int32(i + 1)
		f.logDecision(ff, decisionPass, "")
	}
	log := f.decisionLog()
	if len(log) != maxFightDecisions {
		t.Fatalf("log length = %d, want the cap %d", len(log), maxFightDecisions)
	}
	if log[0].Round != 1 {
		t.Errorf("first retained row is round %d, want 1 (the cap keeps the earliest rows)", log[0].Round)
	}
}

// TestRemoveEffectByIDLimitIsDeterministic: action 149 with a FINITE limit used
// to pick which of two states sharing one source effect died by ranging a map,
// so Go's randomised iteration order decided it and the same seed could replay
// a different fight. The choice is now fixed (lowest state id first).
func TestRemoveEffectByIDLimitIsDeterministic(t *testing.T) {
	const src int32 = 4242
	// stateRooted < stateIntransposable, so the limit must always take rooted.
	for i := 0; i < 200; i++ {
		f := buildTestFight()
		ff := f.Timeline[0]
		ff.States = map[fighterState]int32{stateRooted: 3, stateIntransposable: 3}
		ff.stateSrc = map[fighterState]int32{stateRooted: src, stateIntransposable: src}

		f.removeEffectByID(ff, src, 1)

		if len(ff.States) != 1 {
			t.Fatalf("iteration %d: %d states left, want exactly 1 removed under limit 1", i, len(ff.States))
		}
		if _, stillRooted := ff.States[stateRooted]; stillRooted {
			t.Fatalf("iteration %d: the limited removal took intransposable, not the lowest state id; "+
				"the choice is map-order dependent", i)
		}
	}

	// An unlimited removal still strips every match.
	f := buildTestFight()
	ff := f.Timeline[0]
	ff.States = map[fighterState]int32{stateRooted: 3, stateIntransposable: 3}
	ff.stateSrc = map[fighterState]int32{stateRooted: src, stateIntransposable: src}
	f.removeEffectByID(ff, src, -1)
	if len(ff.States) != 0 || len(ff.stateSrc) != 0 {
		t.Errorf("unlimited removal left states %v / srcs %v, want both empty", ff.States, ff.stateSrc)
	}
}
