package game

import (
	"path/filepath"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store"
)

// fightCreationDeps builds a Deps backed by a temp store with the managers the
// fight-creation handlers need.
func fightCreationDeps(t *testing.T) (*Deps, *store.Store) {
	t.Helper()
	st, err := store.Open(filepath.Join(t.TempDir(), "fc.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })
	d := &Deps{
		Store:      st,
		World:      NewRegistry(150),
		Matchmaker: NewMatchmaker(),
		Challenges: NewChallengeManager(),
		Fights:     NewFightManager(),
		Sessions:   NewSessionRegistry(),
		Log:        testLogger(),
	}
	return d, st
}

func fcSession(d *Deps, coach *domain.Coach) *Session {
	return &Session{
		log:   testLogger(),
		deps:  d,
		out:   make(chan []byte, writeQueueSize),
		quit:  make(chan struct{}),
		Coach: coach,
	}
}

// coachWithTeam creates a coach with two fighters and a saved 1v1 preset holding
// them, returning the coach and the preset id.
func coachWithTeam(t *testing.T, st *store.Store, login string) (*domain.Coach, uint) {
	t.Helper()
	acc, err := st.Accounts.CreateAccount(login, "pw", false)
	if err != nil {
		t.Fatalf("create account: %v", err)
	}
	coach, err := st.Coaches.Create(acc.ID, login+"C", 0, 0, 0)
	if err != nil {
		t.Fatalf("create coach: %v", err)
	}
	f1 := &domain.Fighter{CoachID: coach.ID, BreedID: 1, Name: "F1", Budget: 400}
	f2 := &domain.Fighter{CoachID: coach.ID, BreedID: 8, Name: "F2", Budget: 400}
	for _, f := range []*domain.Fighter{f1, f2} {
		if err := st.Fighters.Create(f); err != nil {
			t.Fatalf("create fighter: %v", err)
		}
	}
	team := &domain.Team{CoachID: coach.ID, Name: "T", Type: -6, GameMode: 1}
	if err := st.Teams.Upsert(team); err != nil {
		t.Fatalf("upsert team: %v", err)
	}
	for _, f := range []*domain.Fighter{f1, f2} {
		if err := st.Teams.AddMember(team.ID, f.ID); err != nil {
			t.Fatalf("add member: %v", err)
		}
	}
	return coach, team.ID
}

// stopTestFight tears a running fight actor down deterministically: it first
// drains the start-up event (so the presentation clock is armed) then ends the
// fight and waits for the goroutine to exit — no leaked timer/goroutine.
func stopTestFight(d *Deps, f *Fight) {
	if f == nil {
		return
	}
	barrier := make(chan struct{})
	if f.Post(func(*Fight) { close(barrier) }) {
		<-barrier
	}
	d.endFight(f)
	f.waitStopped()
}

// TestTeamTestLaunchesPracticeFight: pressing "Tester" (26330) starts an unranked
// fight of the caller's team against the synthetic sparring opponent — with no
// second coach — and never persists stats for the dummy side.
func TestTeamTestLaunchesPracticeFight(t *testing.T) {
	d, st := fightCreationDeps(t)
	coach, teamID := coachWithTeam(t, st, "tester")
	s := fcSession(d, coach)

	payload := protocol.NewWriter().I32(12).U16(uint16(teamID)).Bytes()
	if err := handleTeamTest(s, &protocol.C2SFrame{Payload: payload}); err != nil {
		t.Fatalf("handleTeamTest: %v", err)
	}

	f := d.Fights.ByCoach(coach.ID)
	if f == nil {
		t.Fatal("no fight created for the coach")
	}
	defer stopTestFight(d, f)

	if !f.Practice {
		t.Error("Tester fight must be flagged Practice (unranked)")
	}
	// Team A (side 0) is the real coach with both roster fighters.
	teamA := f.Teams[0]
	if teamA == nil || teamA.Coach() == nil || teamA.Coach().ID != coach.ID {
		t.Fatalf("team A is not the caller: %+v", teamA)
	}
	if len(teamA.Fighters) != 2 {
		t.Errorf("team A fighters = %d, want 2 (roster)", len(teamA.Fighters))
	}
	// Team B (side 1) is the session-less sparring opponent.
	teamB := f.Teams[1]
	if teamB == nil || teamB.Session() != nil {
		t.Fatalf("team B should be the session-less sparring team: %+v", teamB)
	}
	if teamB.Coach() == nil || teamB.Coach().ID != sparringCoachID {
		t.Errorf("team B coach = %+v, want sparring id %d", teamB.Coach(), sparringCoachID)
	}
	if len(teamB.Fighters) != 1 {
		t.Errorf("sparring fighters = %d, want 1", len(teamB.Fighters))
	}
}

// TestTeamTestIgnoresForeignTeam: a team id the caller does not own must not leak
// that team's fighters; the fight falls back to the caller's own roster.
func TestTeamTestIgnoresForeignTeam(t *testing.T) {
	d, st := fightCreationDeps(t)
	owner, foreignTeam := coachWithTeam(t, st, "owner")
	_ = owner
	attacker, _ := coachWithTeam(t, st, "attacker")
	s := fcSession(d, attacker)

	payload := protocol.NewWriter().I32(12).U16(uint16(foreignTeam)).Bytes()
	if err := handleTeamTest(s, &protocol.C2SFrame{Payload: payload}); err != nil {
		t.Fatalf("handleTeamTest: %v", err)
	}
	f := d.Fights.ByCoach(attacker.ID)
	if f == nil {
		t.Fatal("no fight created")
	}
	defer stopTestFight(d, f)

	// Every fighter on the attacker's side must belong to the attacker.
	for _, ff := range f.Teams[0].Fighters {
		if ff.CoachID != attacker.ID {
			t.Fatalf("IDOR: foreign fighter %d (coach %d) on attacker's team", ff.WireID, ff.CoachID)
		}
	}
}

// TestClassicReadyPairsTwoCoaches: two coaches pressing "Combattre" (23103) are
// paired into a single (ranked) fight; the first waits, the second triggers it,
// and the matchmaker's pending state is cleared afterwards.
func TestClassicReadyPairsTwoCoaches(t *testing.T) {
	d, st := fightCreationDeps(t)
	coachA, teamA := coachWithTeam(t, st, "alpha")
	coachB, teamB := coachWithTeam(t, st, "bravo")
	sA := fcSession(d, coachA)
	sB := fcSession(d, coachB)

	ready := func(s *Session, coach *domain.Coach, teamID uint) {
		t.Helper()
		p := protocol.NewWriter().I64(int64(coach.ID)).U16(uint16(teamID)).Bytes()
		if err := handleClassicReadyForFight(s, &protocol.C2SFrame{Payload: p}); err != nil {
			t.Fatalf("combattre %s: %v", coach.Name, err)
		}
	}

	// First coach: queued, no fight yet.
	ready(sA, coachA, teamA)
	if f := d.Fights.ByCoach(coachA.ID); f != nil {
		t.Fatal("first Combattre should wait, not start a fight")
	}

	// Second coach: pairs and launches one shared fight for both.
	ready(sB, coachB, teamB)
	fA := d.Fights.ByCoach(coachA.ID)
	fB := d.Fights.ByCoach(coachB.ID)
	if fA == nil || fB == nil {
		t.Fatalf("both coaches should be in a fight (A=%v B=%v)", fA, fB)
	}
	if fA != fB {
		t.Fatal("the two coaches must share the same fight")
	}
	defer stopTestFight(d, fA)

	if fA.Practice {
		t.Error("Combattre fight must be ranked, not Practice")
	}
	// Ready-room bypasses the accept handshake: no pending match must linger.
	if pm := d.Matchmaker.Pending(coachA.ID); pm != nil {
		t.Error("pending match not discarded after pairing")
	}
}

// TestTeamTestIllegalRosterAnswers26310 pins the refusal path end to end: a
// "Tester" launch naming a preset that breaks the breed cap must be answered
// with FIGHT_CREATION_ERROR (26310) carrying the violation's retail code, and
// must NOT propagate — the session loop drops the connection on any returned
// error, which turned an over-bred titular roster's challenge launch into a
// silent disconnect (regression).
func TestTeamTestIllegalRosterAnswers26310(t *testing.T) {
	d, st := fightCreationDeps(t)
	acc, err := st.Accounts.CreateAccount("breeds", "pw", false)
	if err != nil {
		t.Fatalf("create account: %v", err)
	}
	coach, err := st.Coaches.Create(acc.ID, "breedsC", 0, 0, 0)
	if err != nil {
		t.Fatalf("create coach: %v", err)
	}
	// Three titular fighters of ONE breed — over maxSameBreedPerTeam.
	team := &domain.Team{CoachID: coach.ID, Name: "T", Type: -6, GameMode: 1}
	if err := st.Teams.Upsert(team); err != nil {
		t.Fatalf("upsert team: %v", err)
	}
	for i := 0; i < 3; i++ {
		f := &domain.Fighter{CoachID: coach.ID, BreedID: 8, Name: "Iop", Budget: 400}
		if err := st.Fighters.Create(f); err != nil {
			t.Fatalf("create fighter: %v", err)
		}
		if err := st.Teams.AddMember(team.ID, f.ID); err != nil {
			t.Fatalf("add member: %v", err)
		}
	}
	s := fcSession(d, coach)

	payload := protocol.NewWriter().I32(12).U16(uint16(team.ID)).Bytes()
	if err := handleTeamTest(s, &protocol.C2SFrame{Payload: payload}); err != nil {
		t.Fatalf("handleTeamTest propagated %v — that drops the session "+
			"instead of answering 26310", err)
	}
	body := drainPayload(t, s, protocol.OpFightCreationError)
	if body == nil {
		t.Fatal("no 26310 queued for the refused launch")
	}
	r := protocol.NewReader(body)
	if _, err := r.I64(); err != nil {
		t.Fatalf("26310 fightId: %v", err)
	}
	code, err := r.U8()
	if err != nil {
		t.Fatalf("26310 code: %v", err)
	}
	if code != protocol.FightErrTooManySameBreed {
		t.Errorf("26310 code = %d, want %d (tooManySameBreed)", code,
			protocol.FightErrTooManySameBreed)
	}
	if f := d.Fights.ByCoach(coach.ID); f != nil {
		t.Fatal("a refused launch must not leave a fight behind")
	}
}

// TestTitularRosterCapsSameBreed: when the SERVER picks the lineup (overworld
// challenges carry no preset id), a titular list holding more than
// maxSameBreedPerTeam of one breed — a state the retail roster UI cannot reach
// but a dev database can — must be trimmed to a legal team rather than refused
// downstream at validateRoster.
func TestTitularRosterCapsSameBreed(t *testing.T) {
	d, st := fightCreationDeps(t)
	acc, err := st.Accounts.CreateAccount("cap", "pw", false)
	if err != nil {
		t.Fatalf("create account: %v", err)
	}
	coach, err := st.Coaches.Create(acc.ID, "capC", 0, 0, 0)
	if err != nil {
		t.Fatalf("create coach: %v", err)
	}
	for i := 0; i < 4; i++ {
		f := &domain.Fighter{CoachID: coach.ID, BreedID: 8, Name: "Iop", Budget: 400}
		if err := st.Fighters.Create(f); err != nil {
			t.Fatalf("create fighter: %v", err)
		}
	}
	// A second breed interleaved proves the cap is per breed, not "first N".
	f := &domain.Fighter{CoachID: coach.ID, BreedID: 1, Name: "Feca", Budget: 400}
	if err := st.Fighters.Create(f); err != nil {
		t.Fatalf("create fighter: %v", err)
	}
	got := d.titularRoster(coach.ID, 6)
	if len(got) != 3 { // 2 Iops + 1 Feca
		t.Fatalf("titularRoster = %v, want 3 ids (2 capped Iops + Feca)", got)
	}
}

// TestNPCDialogChallengeLaunch: the record-1500 "Lancer un défi" reply action
// (client th_0) sends 26330 [i32 challengeId][i16 challenge.Qu()] — the second
// field is the challenge's own mode (Fields[1]), NOT the bubble/breedmaster
// literal 99 and NOT a teamId. The handler must still route it to the PvE
// challenge path rather than the "Tester" roster lookup.
func TestNPCDialogChallengeLaunch(t *testing.T) {
	d, st := fightCreationDeps(t)
	d.ChallengeDefs = gamedata.NewChallenges(&gamedata.Challenge{ID: 46})
	coach, _ := coachWithTeam(t, st, "npc")
	s := fcSession(d, coach)

	// Challenge 46's real record: Fields = [63, 9, 110, 0, 5, 0] — Qu() = 9.
	payload := protocol.NewWriter().I32(46).U16(9).Bytes()
	if err := handleTeamTest(s, &protocol.C2SFrame{Payload: payload}); err != nil {
		t.Fatalf("handleTeamTest: %v", err)
	}
	f := d.Fights.ByCoach(coach.ID)
	if f == nil {
		t.Fatal("NPC-dialog challenge launch created no fight")
	}
	defer stopTestFight(d, f)
	teamB := f.Teams[1]
	if teamB == nil || teamB.Coach() == nil || teamB.Coach().ID != challengeCoachID {
		t.Fatalf("team B should be the challenge side, got %+v", teamB)
	}

	// And the practice path is untouched: first==12 keeps meaning "Tester"
	// even though 12 also exists as a challenge id in the data table.
	d.ChallengeDefs = gamedata.NewChallenges(&gamedata.Challenge{ID: 12})
	coach2, team2 := coachWithTeam(t, st, "npc2")
	s2 := fcSession(d, coach2)
	p2 := protocol.NewWriter().I32(12).U16(uint16(team2)).Bytes()
	if err := handleTeamTest(s2, &protocol.C2SFrame{Payload: p2}); err != nil {
		t.Fatalf("handleTeamTest (practice): %v", err)
	}
	f2 := d.Fights.ByCoach(coach2.ID)
	if f2 == nil {
		t.Fatal("practice launch created no fight")
	}
	defer stopTestFight(d, f2)
	if got := f2.Teams[1].Coach().ID; got != sparringCoachID {
		t.Errorf("first==12 must still spawn the sparring side, got coach %d", got)
	}
}
