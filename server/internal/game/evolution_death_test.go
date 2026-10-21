package game

import (
	"math/rand"
	"path/filepath"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/store"
	"github.com/StarLoco/arena-2.70/internal/store/storetest"
)

// evoDeathHarness builds a real store with a coach and two persisted titular
// fighters, plus a Deps ready to run checkFightEnd. The wound catalogue is wired
// in because without it the post-fight roll is skipped entirely.
func evoDeathHarness(t *testing.T) (*Deps, uint, *domain.Fighter, *domain.Fighter, *store.Store) {
	t.Helper()
	st, err := storetest.Open(t, filepath.Join(t.TempDir(), "evodeath.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })

	acc, _ := st.Accounts.CreateAccount("evoA", "pw", false)
	coach, _ := st.Coaches.Create(acc.ID, "Evo", 0, 0, 0)
	downed := &domain.Fighter{CoachID: coach.ID, BreedID: 1, Name: "Downed", State: domain.FighterStateTitular, Budget: 400}
	survivor := &domain.Fighter{CoachID: coach.ID, BreedID: 1, Name: "Survivor", State: domain.FighterStateTitular, Budget: 400}
	for _, fr := range []*domain.Fighter{downed, survivor} {
		if err := st.Fighters.Create(fr); err != nil {
			t.Fatalf("create fighter: %v", err)
		}
	}
	d := &Deps{Store: st, Fights: NewFightManager(), World: NewRegistry(150),
		Conditions: woundCatalogue(), Log: testLogger()}
	return d, coach.ID, downed, survivor, st
}

// buildEvoFight assembles a finished fight: the real coach's team (one fighter at
// 0 HP = downed, one alive) beats a synthetic sparring team. evolution toggles
// the progression mode. The RNG is seeded so the rolls are reproducible.
func buildEvoFight(d *Deps, coachID uint, downed, survivor *domain.Fighter, evolution bool) *Fight {
	teamA := &FightTeam{
		ID: 0, Members: []*FightMember{{Coach: &domain.Coach{ID: coachID, Name: "Evo"}}},
		Fighters: []*FightFighter{
			{WireID: FighterWireIDBase + int64(downed.ID)*16, CoachID: coachID, TeamID: 0, Fighter: downed, MaxHP: 100, HP: 0},
			{WireID: FighterWireIDBase + int64(survivor.ID)*16 + 1, CoachID: coachID, TeamID: 0, Fighter: survivor, MaxHP: 100, HP: 80},
		},
	}
	teamB := buildSparringTeam(1, Pos{})
	for _, ff := range teamB.Fighters {
		ff.HP = 0 // synthetic opponent wiped -> team A wins
	}
	f := &Fight{
		Evolution: evolution, Practice: true,
		Teams:        [2]*FightTeam{teamA, teamB},
		deps:         d,
		rng:          rand.New(rand.NewSource(1)),
		readyPresent: map[uint]bool{}, readyObserve: map[uint]bool{}, readyAction: map[uint]bool{},
	}
	f.setPhase(PhaseAction)
	d.Fights.Create(f)
	return f
}

// TestDownedFighterIsNotKilled is the B-097 regression guard: falling to 0 HP in
// an evolution fight is a KNOCKDOWN, not a permanent death.
//
// Both fighters here are rookies (TotalXP 0), so the client's formula gives them
// injury% = 0 and death% = 0 — nothing can kill them this fight, whichever way
// the dice fall. Before B-097 the downed one died anyway, because an invented
// `HP <= 0 -> dead` override ran instead of the roll. See `deathIsRolledNotDealt`
// for the client evidence that a KO is not a death.
func TestDownedFighterIsNotKilled(t *testing.T) {
	d, coachID, downed, survivor, st := evoDeathHarness(t)
	f := buildEvoFight(d, coachID, downed, survivor, true)

	d.checkFightEnd(f)

	if got := fighterStateOf(t, st, downed.ID); got != domain.FighterStateTitular {
		t.Errorf("downed rookie state = %d, want titular(0): a 0-HP KO must not kill "+
			"(death%% is 0 at TotalXP 0)", got)
	}
	if got := fighterStateOf(t, st, survivor.ID); got != domain.FighterStateTitular {
		t.Errorf("survivor state = %d, want titular(0)", got)
	}
}

// TestVeteranDiesFromTheRoll is the other half, and the one that proves removing
// the HP override did not simply remove death from the game: a fighter whose
// lifetime XP puts the death chance at 100% dies — while STANDING at full HP.
//
// death% = (totalXp*100/100000)² / 100, so 100 000 lifetime XP = 100%. That the
// dead one is the untouched fighter and the survivor is the one who hit the floor
// is precisely the point: the roll keys off XP, never off HP.
func TestVeteranDiesFromTheRoll(t *testing.T) {
	d, coachID, downed, survivor, st := evoDeathHarness(t)
	survivor.TotalXP = deathXPScale // 100% death chance
	if err := d.Store.Fighters.SaveProgress(survivor); err != nil {
		t.Fatalf("seed veteran xp: %v", err)
	}
	f := buildEvoFight(d, coachID, downed, survivor, true)

	d.checkFightEnd(f)

	if got := fighterStateOf(t, st, survivor.ID); got != domain.FighterStateDead {
		t.Errorf("veteran at 100%% death chance state = %d, want dead(2) — the "+
			"post-fight roll is not running", got)
	}
	if got := fighterStateOf(t, st, downed.ID); got != domain.FighterStateTitular {
		t.Errorf("downed rookie state = %d, want titular(0)", got)
	}
}

// TestDeathIsReportedForTheRosterPush: whoever the roll kills must come back in
// runPostFightMeta's per-coach dead list, because that list — not "who is at 0
// HP" — is what drives the 6006 roster refresh. Before B-097 the push was gated
// on a DOWNED fighter existing, so a fighter killed by the roll alone stayed
// alive on the player's screen until relog.
func TestDeathIsReportedForTheRosterPush(t *testing.T) {
	d, coachID, downed, survivor, _ := evoDeathHarness(t)
	survivor.TotalXP = deathXPScale
	if err := d.Store.Fighters.SaveProgress(survivor); err != nil {
		t.Fatalf("seed veteran xp: %v", err)
	}
	f := buildEvoFight(d, coachID, downed, survivor, true)

	_, _, killed, _, diedByCoach := d.runPostFightMeta(f, 0)

	if killed != 1 {
		t.Errorf("killed tally = %d, want 1", killed)
	}
	dead := diedByCoach[coachID]
	if len(dead) != 1 || dead[0] != survivor.Name {
		t.Errorf("diedByCoach[%d] = %v, want [%q] — the roster push is keyed off this",
			coachID, dead, survivor.Name)
	}
}

// TestNonEvolutionFightKeepsFightersAlive: an ordinary (non-evolution) fight must
// NOT persist deaths, however badly a fighter was beaten and however veteran it
// is — no progression pass runs at all outside evolution mode.
func TestNonEvolutionFightKeepsFightersAlive(t *testing.T) {
	d, coachID, downed, survivor, st := evoDeathHarness(t)
	survivor.TotalXP = deathXPScale // would be certain death IN an evolution fight
	if err := d.Store.Fighters.SaveProgress(survivor); err != nil {
		t.Fatalf("seed veteran xp: %v", err)
	}
	f := buildEvoFight(d, coachID, downed, survivor, false) // evolution OFF

	d.checkFightEnd(f)

	if got := fighterStateOf(t, st, downed.ID); got != domain.FighterStateTitular {
		t.Errorf("downed fighter state = %d in a NON-evolution fight, want titular(0)", got)
	}
	if got := fighterStateOf(t, st, survivor.ID); got != domain.FighterStateTitular {
		t.Errorf("veteran state = %d in a NON-evolution fight, want titular(0)", got)
	}
}

// TestEvolutionDeathSkipsSyntheticFighters: the synthetic opponent (sparring
// dummy / challenge demon) has no DB row, so no state write must ever be
// attempted for it (a 0-id write would corrupt the table). Guard: the losing
// synthetic team is all at 0 HP, yet no persistence error occurs and the real
// roster is the only thing touched.
func TestEvolutionDeathSkipsSyntheticFighters(t *testing.T) {
	d, coachID, downed, survivor, st := evoDeathHarness(t)
	f := buildEvoFight(d, coachID, downed, survivor, true)

	// Sanity: the synthetic team's fighters have no real DB id.
	for _, ff := range f.Teams[1].Fighters {
		if ff.Fighter != nil && ff.Fighter.ID != 0 {
			t.Fatalf("sparring fighter unexpectedly has a DB id %d", ff.Fighter.ID)
		}
	}
	d.checkFightEnd(f)

	// The coach still owns exactly its two fighters (nothing phantom created).
	fighters, _ := st.Fighters.ListByCoach(coachID)
	if len(fighters) != 2 {
		t.Errorf("coach fighter count = %d, want 2 (no phantom rows)", len(fighters))
	}
}
