package game

import (
	"path/filepath"
	"testing"
	"time"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store"
	"github.com/StarLoco/arena-2.70/internal/store/storetest"
)

// The scheduler walks a scheduled edition through its life on the clock alone:
// registration, search periods that open and close, forfeits, a winner, the
// finished state and the next edition. These drive it with a fake clock.

var schedT0 = time.Date(2026, 10, 22, 20, 0, 0, 0, time.UTC)

type schedRig struct {
	d   *Deps
	st  *store.Store
	now time.Time
	tr  *domain.Tournament
	// coaches in seeding order (sorted ids): 0-1 and 2-3 face each other.
	coaches []uint
}

func (r *schedRig) at(d time.Duration) { r.now = schedT0.Add(d) }

// newSchedRig builds a store-backed Deps with one scheduled edition on defID
// and n coaches, each with one titular fighter, all registered.
func newSchedRig(t *testing.T, defID uint16, n int, edit func(*domain.Tournament)) *schedRig {
	t.Helper()
	st, err := storetest.Open(t, filepath.Join(t.TempDir(), "sched.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })
	defs, err := openRealGameData(t).LoadTournaments()
	if err != nil {
		t.Fatalf("LoadTournaments: %v", err)
	}
	tm, err := NewTournamentManagerWithStore(st.Tournaments)
	if err != nil {
		t.Fatalf("manager: %v", err)
	}
	r := &schedRig{st: st, now: schedT0.Add(-time.Hour)}
	r.d = &Deps{
		Store: st, TournamentDefs: defs, Tournaments: tm,
		World: NewRegistry(150), Fights: NewFightManager(), Matchmaker: NewMatchmaker(),
		Sessions: NewSessionRegistry(), Log: testLogger(),
		TournamentClock: func() time.Time { return r.now },
	}
	r.tr = &domain.Tournament{
		DefID: defID, Name: "Coupe", Short: "C", Enabled: true, RegistrationOpen: true,
		SearchPeriodStart: schedT0, SearchPeriodMinutes: 30,
		SearchPeriods: 2, PeriodIntervalMinutes: 60,
	}
	if edit != nil {
		edit(r.tr)
	}
	if err := st.Tournaments.Create(r.tr); err != nil {
		t.Fatalf("create tournament: %v", err)
	}
	for i := 0; i < n; i++ {
		acc, _ := st.Accounts.CreateAccount("acc"+string(rune('a'+i)), "pw", false)
		c, err := st.Coaches.Create(acc.ID, "Coach"+string(rune('A'+i)), 0, 0, 0)
		if err != nil {
			t.Fatalf("coach: %v", err)
		}
		fr := &domain.Fighter{CoachID: c.ID, BreedID: 1, Name: "F" + c.Name, State: domain.FighterStateTitular}
		if err := st.Fighters.Create(fr); err != nil {
			t.Fatalf("fighter: %v", err)
		}
		tm.Register(c.ID, r.tr.WireID())
		r.coaches = append(r.coaches, c.ID)
	}
	return r
}

func (r *schedRig) online(t *testing.T, i int) *Session {
	t.Helper()
	return tmSession(r.d, r.coaches[i], "Coach"+string(rune('A'+i)))
}

func (r *schedRig) reload(t *testing.T) *domain.Tournament {
	t.Helper()
	got, err := r.st.Tournaments.Get(r.tr.ID)
	if err != nil {
		t.Fatalf("reload: %v", err)
	}
	return got
}

// editionsOf lists the rig's tournament and its successors (the store also
// seeds the default line-up, which is not part of the test).
func editionsOf(t *testing.T, r *schedRig, listedOnly bool) []domain.Tournament {
	t.Helper()
	list := r.st.Tournaments.List
	if listedOnly {
		list = r.st.Tournaments.ListEnabled
	}
	all, err := list()
	if err != nil {
		t.Fatal(err)
	}
	var out []domain.Tournament
	for _, tr := range all {
		if tr.Name == r.tr.Name {
			out = append(out, tr)
		}
	}
	return out
}

func hasOp(ops []uint16, op uint16) bool {
	for _, o := range ops {
		if o == op {
			return true
		}
	}
	return false
}

// TestScheduledTournamentRunsToItsEnd is the whole lifecycle, no hand on it.
func TestScheduledTournamentRunsToItsEnd(t *testing.T) {
	r := newSchedRig(t, 1, 4, func(tr *domain.Tournament) { tr.RepeatDays = 7 })
	tid := r.tr.WireID()
	a, b, c := r.online(t, 0), r.online(t, 1), r.online(t, 2) // coach D stays offline

	// Before the start: nothing happens, and the search is refused.
	r.d.TickTournaments()
	if err := handleTournamentSearchRequest(a, readyFrame(tid, r.coaches[0], 0)); err != nil {
		t.Fatal(err)
	}
	if ops := drain(t, a); len(ops) != 1 || ops[0] != protocol.OpTournamentSearchError {
		t.Fatalf("search before the first period: got %v, want a 28616 refusal", ops)
	}

	// Period 1 opens: every online entrant hears 28646.
	r.at(time.Minute)
	r.d.TickTournaments()
	for i, s := range []*Session{a, b, c} {
		if ops := drain(t, s); !hasOp(ops, protocol.OpTournamentSearchOpening) {
			t.Fatalf("coach %d got %v at the opening, want 28646", i, ops)
		}
	}
	// A second tick in the same period announces nothing again: 28646 has no
	// duplicate guard in the client.
	r.d.TickTournaments()
	if ops := drain(t, a); len(ops) != 0 {
		t.Fatalf("second tick sent %v", ops)
	}
	// Registration closed with the draw.
	if r.reload(t).RegistrationOpenAt(r.now) {
		t.Error("registration still open after the first period started")
	}

	// A and C search; B (online) and D (offline) do not.
	for _, s := range []*Session{a, c} {
		if err := handleTournamentSearchRequest(s, readyFrame(tid, s.Coach.ID, 0)); err != nil {
			t.Fatal(err)
		}
		if ops := drain(t, s); !hasOp(ops, protocol.OpTournamentSearchResult) {
			t.Fatalf("search inside the period: got %v, want 28612", ops)
		}
	}

	// Period 1 closes: A and C win by forfeit, B is told it forfeited, and the
	// alert row is withdrawn from everyone.
	r.at(31 * time.Minute)
	r.d.TickTournaments()
	if ops := drain(t, a); !hasOp(ops, protocol.OpTournamentSearchEnded) || !hasOp(ops, protocol.OpTournamentSearchPeriod) {
		t.Fatalf("A at the close: %v, want 28648 and 28630", ops)
	}
	if ops := drain(t, b); !hasOp(ops, protocol.OpTournamentSearchEnded) {
		t.Fatalf("B at the close: %v, want its 28648 forfeit", ops)
	}
	drain(t, c)
	slots := r.d.Tournaments.BracketSlots(tid)
	if slots[8] != r.coaches[0] || slots[9] != r.coaches[2] {
		t.Fatalf("after period 1: slots 8/9 = %d/%d, want A/C", slots[8], slots[9])
	}

	// Between periods the search is refused again.
	r.at(45 * time.Minute)
	_ = handleTournamentSearchRequest(a, readyFrame(tid, r.coaches[0], 0))
	if ops := drain(t, a); len(ops) != 1 || ops[0] != protocol.OpTournamentSearchError {
		t.Fatalf("search between periods: %v", ops)
	}

	// Period 2: only A searches, so A takes the final by forfeit.
	r.at(61 * time.Minute)
	r.d.TickTournaments()
	drain(t, a)
	_ = handleTournamentSearchRequest(a, readyFrame(tid, r.coaches[0], 0))
	drain(t, a)
	r.at(91 * time.Minute)
	r.d.TickTournaments()

	got := r.reload(t)
	if !got.Finished() || got.WinnerCoachID != r.coaches[0] {
		t.Fatalf("after the last period: finished=%v winner=%d, want finished, won by A",
			got.Finished(), got.WinnerCoachID)
	}
	if r.d.Tournaments.IsRegistered(r.coaches[0], tid) {
		t.Error("a finished edition is still held in memory")
	}

	// It is no longer offered, and the next edition is, a week on.
	live := editionsOf(t, r, true)
	if len(live) != 1 || live[0].ID == r.tr.ID || live[0].PreviousID != r.tr.ID {
		t.Fatalf("listed after the finish: %+v, want only the next edition", live)
	}
	if want := schedT0.Add(7 * 24 * time.Hour); !live[0].SearchPeriodStart.Equal(want) {
		t.Errorf("next edition starts %v, want %v", live[0].SearchPeriodStart, want)
	}
	if !live[0].RegistrationOpenAt(r.now) || r.d.Tournaments.CountFor(live[0].WireID()) != 0 {
		t.Error("the next edition should be open with an empty draw")
	}
	// Ticking again neither finishes twice nor opens a third edition.
	r.d.TickTournaments()
	if all := editionsOf(t, r, false); len(all) != 2 {
		t.Errorf("%d editions after a second tick, want 2", len(all))
	}
}

// TestUndecidedTournamentFinishesWithoutAWinner: nobody turns up, the last
// period closes, and the edition still ends rather than sitting open forever.
func TestUndecidedTournamentFinishesWithoutAWinner(t *testing.T) {
	r := newSchedRig(t, 1, 2, nil)
	r.at(time.Minute)
	r.d.TickTournaments()
	r.at(31 * time.Minute)
	r.d.TickTournaments()
	if r.reload(t).Finished() {
		t.Fatal("finished after the first of two periods")
	}
	r.at(91 * time.Minute)
	r.d.TickTournaments()
	got := r.reload(t)
	if !got.Finished() || got.WinnerCoachID != 0 {
		t.Fatalf("finished=%v winner=%d, want finished with no winner", got.Finished(), got.WinnerCoachID)
	}
	if all := editionsOf(t, r, false); len(all) != 1 {
		t.Errorf("a non-repeating edition opened a successor: %d editions", len(all))
	}
}

// TestLoneEntrantWinsAtTheStart: byes carry a single entrant to the root as
// soon as the draw is fixed, so the edition ends then.
func TestLoneEntrantWinsAtTheStart(t *testing.T) {
	r := newSchedRig(t, 1, 1, nil)
	r.d.TickTournaments()
	if r.reload(t).Finished() {
		t.Fatal("finished while still taking entrants")
	}
	r.at(time.Second)
	r.d.TickTournaments()
	if got := r.reload(t); !got.Finished() || got.WinnerCoachID != r.coaches[0] {
		t.Fatalf("finished=%v winner=%d, want won by the lone entrant", got.Finished(), got.WinnerCoachID)
	}
}

// TestRestartMidPeriodDoesNotSettleThePastWithTodaysSearchers: the first tick
// after a restart must not treat the current period's searchers as the
// previous period's, or it hands out forfeits mid-search.
func TestRestartMidPeriodDoesNotSettleThePastWithTodaysSearchers(t *testing.T) {
	r := newSchedRig(t, 1, 4, func(tr *domain.Tournament) { tr.SearchPeriods = 3 })
	tid := r.tr.WireID()
	a := r.online(t, 0)
	r.online(t, 1)
	// First sight of the tournament is in period 2 (as after a restart); A is
	// already searching in it.
	r.at(65 * time.Minute)
	_ = handleTournamentSearchRequest(a, readyFrame(tid, r.coaches[0], 0))
	r.d.TickTournaments()
	if _, decided := r.d.Tournaments.BracketSlots(tid)[8]; decided {
		t.Fatal("period 1 was settled with period 2's searchers")
	}
}

// TestRegistrationClosesWithTheDraw goes through the real 4607 handler.
func TestRegistrationClosesWithTheDraw(t *testing.T) {
	r := newSchedRig(t, 1, 1, nil)
	acc, _ := r.st.Accounts.CreateAccount("late", "pw", false)
	late, _ := r.st.Coaches.Create(acc.ID, "Late", 0, 0, 0)
	s := tmSession(r.d, late.ID, "Late")
	register := func() uint8 {
		w := protocol.NewWriter().I64(r.tr.WireID()).I64(int64(late.ID)).U16(0xFFFF).I32(0)
		_ = handleTournamentRegister(s, &protocol.C2SFrame{Opcode: protocol.OpTournamentRegister, Payload: w.Bytes()})
		p := drainPayload(t, s, protocol.OpTournamentRegisterReply)
		if len(p) != 9 {
			t.Fatalf("28608 payload %x", p)
		}
		return p[8]
	}
	r.at(time.Second)
	if code := register(); code == 0 {
		t.Fatal("registered after the draw started")
	}
	r.d.Tournaments.Unregister(late.ID, r.tr.WireID())
	r.at(-time.Minute)
	if code := register(); code != 0 {
		t.Fatalf("refused before the start: code %d", code)
	}
}

// TestTournamentTeamKind: the preset must be the one the definition's team
// kind sends (agz_1 routes the entrant to that tab or dialog).
func TestTournamentTeamKind(t *testing.T) {
	r := newSchedRig(t, 1, 0, nil)
	defs := r.d.TournamentDefs
	byKind := map[uint8]uint16{}
	for id, def := range defs.All() {
		if def != nil && def.InscriptionCard == 0 {
			if _, ok := byKind[def.TeamType]; !ok {
				byKind[def.TeamType] = uint16(id)
			}
		}
	}
	cases := []struct {
		kind  uint8
		ok    uint16
		wrong uint16
	}{
		{gamedata.TournamentTeamClassic, 3, evolutionTeamPreset},
		{gamedata.TournamentTeamEvolution, evolutionTeamPreset, 3},
		{gamedata.TournamentTeamGraveyard, graveyardTeamPreset, evolutionTeamPreset},
		{gamedata.TournamentTeamLegendary, legendTeamPreset, 3},
	}
	for _, tc := range cases {
		defID, ok := byKind[tc.kind]
		if !ok {
			continue // no free definition of this kind in the data
		}
		tr := &domain.Tournament{DefID: defID, Name: "K", Short: "K", Enabled: true}
		if err := r.st.Tournaments.Create(tr); err != nil {
			t.Fatal(err)
		}
		if !r.d.tournamentPresetAllowed(tr.WireID(), tc.ok) {
			t.Errorf("kind %d (def %d) refused its own preset %d", tc.kind, defID, tc.ok)
		}
		if r.d.tournamentPresetAllowed(tr.WireID(), tc.wrong) {
			t.Errorf("kind %d (def %d) accepted preset %d", tc.kind, defID, tc.wrong)
		}
	}
	if len(byKind) < 2 {
		t.Fatalf("only %d team kinds among the free definitions: %v", len(byKind), byKind)
	}
}

// TestFixtureFieldsEachSidesOwnPreset: the second searcher's preset used to be
// applied to both sides, so the first fielded one fighter (the preset was not
// its own) and the second always its titular line-up.
func TestFixtureFieldsEachSidesOwnPreset(t *testing.T) {
	r := newSchedRig(t, 1, 2, nil)
	tid := r.tr.WireID()
	// A also owns a second titular fighter, and a preset holding only it.
	extra := &domain.Fighter{CoachID: r.coaches[0], BreedID: 2, Name: "Extra", State: domain.FighterStateTitular}
	if err := r.st.Fighters.Create(extra); err != nil {
		t.Fatal(err)
	}
	team := &domain.Team{CoachID: r.coaches[0], Name: "Solo",
		Members: []domain.TeamFighter{{FighterID: extra.ID}}}
	if err := r.st.Teams.Upsert(team); err != nil {
		t.Fatal(err)
	}
	a, b := r.online(t, 0), r.online(t, 1)
	r.at(time.Minute)
	r.d.TickTournaments()
	_ = handleTournamentSearchRequest(a, readyFrame(tid, r.coaches[0], uint16(team.ID)))
	_ = handleTournamentSearchRequest(b, readyFrame(tid, r.coaches[1], 0))

	f := r.d.Fights.ByCoach(r.coaches[0])
	if f == nil {
		t.Fatalf("no fixture started; A got %v, B got %v", drain(t, a), drain(t, b))
	}
	if f.TournamentID != tid {
		t.Errorf("fight tagged %d, want %d", f.TournamentID, tid)
	}
	for _, ft := range f.Teams {
		coach := ft.Members[0].Coach.ID
		var ids []uint
		for _, ff := range ft.Fighters {
			ids = append(ids, ff.Fighter.ID)
		}
		if coach == r.coaches[0] && (len(ids) != 1 || ids[0] != extra.ID) {
			t.Errorf("A fielded %v, want only its preset's fighter %d", ids, extra.ID)
		}
		if coach == r.coaches[1] && len(ids) != 1 {
			t.Errorf("B fielded %v, want its one titular fighter", ids)
		}
	}
}

// TestLastPeriodWaitsForAFixtureInPlay: a final still being fought when the
// last period closes can decide the tournament, so the edition must not end
// (and forget its draw) under it.
func TestLastPeriodWaitsForAFixtureInPlay(t *testing.T) {
	r := newSchedRig(t, 1, 2, func(tr *domain.Tournament) { tr.SearchPeriods = 1 })
	tid := r.tr.WireID()
	a, b := r.online(t, 0), r.online(t, 1)
	r.at(time.Minute)
	r.d.TickTournaments()
	_ = handleTournamentSearchRequest(a, readyFrame(tid, r.coaches[0], 0))
	_ = handleTournamentSearchRequest(b, readyFrame(tid, r.coaches[1], 0))
	f := r.d.Fights.ByCoach(r.coaches[0])
	if f == nil {
		t.Fatal("the final did not start")
	}
	r.at(31 * time.Minute)
	r.d.TickTournaments()
	if r.reload(t).Finished() {
		t.Fatal("the edition ended with its final still being played")
	}
	// The final ends: A wins it, and the next tick finishes with A as winner.
	r.d.Tournaments.RecordMatchResult(tid, r.coaches[0], r.coaches[1])
	r.d.Fights.Remove(f)
	r.d.TickTournaments()
	if got := r.reload(t); !got.Finished() || got.WinnerCoachID != r.coaches[0] {
		t.Fatalf("finished=%v winner=%d, want won by A", got.Finished(), got.WinnerCoachID)
	}
}
