package game

import (
	"testing"
	"time"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// Block B of S09: what a finished edition leaves behind (points, statistics)
// and the carry-over to the next edition (28618 / 28617).

func TestTournamentPointsTable(t *testing.T) {
	for _, tc := range []struct {
		won    int
		winner bool
		want   int32
	}{
		{0, false, 1}, {1, false, 3}, {2, false, 6}, {3, false, 10},
		{4, true, 20}, {1, true, 20},
		// Carried to the root by byes alone: scored like anyone who won nothing.
		{0, true, 1},
	} {
		if got := tournamentPoints(tc.won, tc.winner); got != tc.want {
			t.Errorf("tournamentPoints(%d, %v) = %d, want %d", tc.won, tc.winner, got, tc.want)
		}
	}
}

func (r *schedRig) stat(coach uint, id int16) int32 {
	return r.d.Store.Coaches.StatValue(coach, id)
}

func (r *schedRig) registration(t *testing.T, coach uint, tid int64) domain.TournamentRegistration {
	t.Helper()
	rows, err := r.st.Tournaments.ListRegistrations()
	if err != nil {
		t.Fatal(err)
	}
	for _, reg := range rows {
		if reg.CoachID == coach && reg.TournamentWireID == tid {
			return reg
		}
	}
	t.Fatalf("no registration for coach %d in %d", coach, tid)
	return domain.TournamentRegistration{}
}

// TestFinishedEditionScoresItsEntrants walks the forfeit lifecycle of
// TestScheduledTournamentRunsToItsEnd and checks what each coach is left with.
func TestFinishedEditionScoresItsEntrants(t *testing.T) {
	r := newSchedRig(t, 1, 4, nil)
	tid := r.tr.WireID()
	a, _, c := r.online(t, 0), r.online(t, 1), r.online(t, 2)
	r.at(time.Minute)
	r.d.TickTournaments()
	_ = handleTournamentSearchRequest(a, readyFrame(tid, r.coaches[0], 0))
	_ = handleTournamentSearchRequest(c, readyFrame(tid, r.coaches[2], 0))
	r.at(31 * time.Minute)
	r.d.TickTournaments() // A beats B, C beats D, by forfeit
	r.at(61 * time.Minute)
	r.d.TickTournaments()
	_ = handleTournamentSearchRequest(a, readyFrame(tid, r.coaches[0], 0))
	r.at(91 * time.Minute)
	r.d.TickTournaments() // A beats C: the final

	want := []struct {
		points, wins int32
	}{{20, 1}, {1, 0}, {3, 0}, {1, 0}}
	for i, w := range want {
		coach := r.coaches[i]
		if got := r.registration(t, coach, tid).Points; got != w.points {
			t.Errorf("coach %d: %d points on the entry, want %d", i, got, w.points)
		}
		if got := r.stat(coach, statTournamentPoints); got != w.points {
			t.Errorf("coach %d: statistic 183 = %d, want %d", i, got, w.points)
		}
		if got := r.stat(coach, statOfficialWins); got != w.wins {
			t.Errorf("coach %d: statistic 187 = %d, want %d", i, got, w.wins)
		}
		if got := r.stat(coach, statTournamentWins); got != w.wins {
			t.Errorf("coach %d: statistic 190 = %d, want %d", i, got, w.wins)
		}
	}
	// A forfeit is not a duel: nobody fought.
	if got := r.stat(r.coaches[0], statTournamentDuels); got != 0 {
		t.Errorf("statistic 188 = %d after forfeits only, want 0", got)
	}
}

// TestByeWinnerIsNotScoredAsAWinner: signing up alone to an empty tournament
// must not be worth a win.
func TestByeWinnerIsNotScoredAsAWinner(t *testing.T) {
	r := newSchedRig(t, 1, 1, nil)
	r.at(time.Second)
	r.d.TickTournaments()
	if got := r.reload(t); got.WinnerCoachID != r.coaches[0] {
		t.Fatalf("winner %d, want the lone entrant", got.WinnerCoachID)
	}
	if got := r.stat(r.coaches[0], statOfficialWins); got != 0 {
		t.Errorf("statistic 187 = %d for a win by byes alone, want 0", got)
	}
	if got := r.stat(r.coaches[0], statTournamentPoints); got != 1 {
		t.Errorf("statistic 183 = %d, want the 1 point for taking part", got)
	}
}

// TestPlayedFixtureCountsAsADuel: statistic 188 moves when a fixture is
// actually fought and won.
func TestPlayedFixtureCountsAsADuel(t *testing.T) {
	r := newSchedRig(t, 1, 2, nil)
	tid := r.tr.WireID()
	a, b := r.online(t, 0), r.online(t, 1)
	r.at(time.Minute)
	r.d.TickTournaments()
	_ = handleTournamentSearchRequest(a, readyFrame(tid, r.coaches[0], 0))
	_ = handleTournamentSearchRequest(b, readyFrame(tid, r.coaches[1], 0))
	f := r.d.Fights.ByCoach(r.coaches[0])
	if f == nil {
		t.Fatal("no fixture")
	}
	var teamA uint8
	for _, ft := range f.Teams {
		if ft.Coach().ID == r.coaches[0] {
			teamA = ft.ID
		}
	}
	r.d.advanceTournamentBracket(f, teamA)
	if got := r.stat(r.coaches[0], statTournamentDuels); got != 1 {
		t.Errorf("winner's statistic 188 = %d, want 1", got)
	}
	if got := r.stat(r.coaches[1], statTournamentDuels); got != 0 {
		t.Errorf("loser's statistic 188 = %d, want 0", got)
	}
}

// TestRegistrationCountsAnEntry: statistic 189, once per tournament.
func TestRegistrationCountsAnEntry(t *testing.T) {
	r := newSchedRig(t, 1, 0, nil)
	acc, _ := r.st.Accounts.CreateAccount("reg", "pw", false)
	co, _ := r.st.Coaches.Create(acc.ID, "Reg", 0, 0, 0)
	s := tmSession(r.d, co.ID, "Reg")
	for i := 0; i < 2; i++ {
		w := protocol.NewWriter().I64(r.tr.WireID()).I64(int64(co.ID)).U16(0xFFFF).I32(0)
		_ = handleTournamentRegister(s, &protocol.C2SFrame{Opcode: protocol.OpTournamentRegister, Payload: w.Bytes()})
	}
	if got := r.stat(co.ID, statTournamentEntries); got != 1 {
		t.Errorf("statistic 189 = %d after registering twice for one tournament, want 1", got)
	}
}

// carryRig: a repeating edition that ends with nobody having played, so both
// entrants are left unfinished and the next edition exists.
func carryRig(t *testing.T) (*schedRig, *domain.Tournament) {
	t.Helper()
	r := newSchedRig(t, 1, 2, func(tr *domain.Tournament) {
		tr.SearchPeriods = 1
		tr.RepeatDays = 7
	})
	r.at(time.Minute)
	r.d.TickTournaments()
	r.at(31 * time.Minute)
	r.d.TickTournaments()
	if !r.reload(t).Finished() {
		t.Fatal("edition did not finish")
	}
	next, err := r.st.Tournaments.NextEdition(r.tr.ID)
	if err != nil {
		t.Fatalf("no next edition: %v", err)
	}
	return r, next
}

func listFrame() *protocol.C2SFrame {
	return &protocol.C2SFrame{Opcode: protocol.OpTournamentListReq, Arch: 2}
}

// TestCarryOverIsOfferedOnceWithTheNextEditionsID.
func TestCarryOverIsOfferedOnceWithTheNextEditionsID(t *testing.T) {
	r, next := carryRig(t)
	if reg := r.registration(t, r.coaches[0], r.tr.WireID()); !reg.Unfinished {
		t.Fatal("an entrant still in contention was not marked unfinished")
	}
	a := r.online(t, 0)
	_ = handleTournamentListRequest(a, listFrame())
	p := drainPayload(t, a, protocol.OpTournamentUnfinished)
	if len(p) != 8 {
		t.Fatalf("no 28618 after the list")
	}
	if got, _ := protocol.NewReader(p).I64(); got != next.WireID() {
		t.Errorf("28618 names %d, want the next edition %d: the client drops an id "+
			"it does not have in its 28602 registry", got, next.WireID())
	}
	_ = handleTournamentListRequest(a, listFrame())
	if p := drainPayload(t, a, protocol.OpTournamentUnfinished); p != nil {
		t.Error("asked a second time: a NO sends nothing back, so asking again is nagging")
	}
}

// TestCarryOverYesRegistersAndSeedsFirst.
func TestCarryOverYesRegistersAndSeedsFirst(t *testing.T) {
	r, next := carryRig(t)
	// Coach B (higher id) accepts; a newcomer with a LOWER id than B registers
	// directly. Coach A does not answer.
	early := r.coaches[0]
	b := r.online(t, 1)
	_ = handleTournamentListRequest(b, listFrame())
	drain(t, b)
	r.d.Tournaments.Register(early, next.WireID())

	yes := &protocol.C2SFrame{Opcode: protocol.OpTournamentCarryStanding, Arch: 2,
		Payload: protocol.NewWriter().I64(next.WireID()).Bytes()}
	if err := handleTournamentCarryStanding(b, yes); err != nil {
		t.Fatal(err)
	}
	if !r.d.Tournaments.IsRegistered(r.coaches[1], next.WireID()) {
		t.Fatal("accepting the carry-over did not register the coach")
	}
	if ops := drain(t, b); !hasOp(ops, protocol.OpTournamentList) {
		t.Errorf("no refreshed 28602 after the carry-over: %v", ops)
	}
	if got := r.d.Tournaments.EntrantsFor(next.WireID()); len(got) != 2 || got[0] != r.coaches[1] {
		t.Errorf("seeding %v, want the carried coach %d first", got, r.coaches[1])
	}
	if !r.registration(t, r.coaches[1], next.WireID()).Carried {
		t.Error("the carried flag was not stored, so a restart would lose the seeding")
	}
}

// TestCarryOverNeedsAnOffer: 28617 from a coach that was never asked does
// nothing, and neither does one for an edition that no longer takes entrants.
func TestCarryOverNeedsAnOffer(t *testing.T) {
	r, next := carryRig(t)
	acc, _ := r.st.Accounts.CreateAccount("sneak", "pw", false)
	co, _ := r.st.Coaches.Create(acc.ID, "Sneak", 0, 0, 0)
	s := tmSession(r.d, co.ID, "Sneak")
	yes := &protocol.C2SFrame{Opcode: protocol.OpTournamentCarryStanding, Arch: 2,
		Payload: protocol.NewWriter().I64(next.WireID()).Bytes()}
	_ = handleTournamentCarryStanding(s, yes)
	if r.d.Tournaments.IsRegistered(co.ID, next.WireID()) {
		t.Error("a coach that was never offered the carry-over got it")
	}

	a := r.online(t, 0)
	_ = handleTournamentListRequest(a, listFrame())
	drain(t, a)
	r.now = next.SearchPeriodStart.Add(time.Minute) // the next draw has started
	_ = handleTournamentCarryStanding(a, yes)
	if r.d.Tournaments.IsRegistered(r.coaches[0], next.WireID()) {
		t.Error("carried into an edition whose draw had already started")
	}
}

// TestTournamentLadderRanksThePeriodsPoints: the Tournoi tab (27507) ranks the
// points of the editions that finished in each picked period.
func TestTournamentLadderRanksThePeriodsPoints(t *testing.T) {
	r := newSchedRig(t, 1, 4, nil)
	tid := r.tr.WireID()
	a, _, c := r.online(t, 0), r.online(t, 1), r.online(t, 2)
	r.at(time.Minute)
	r.d.TickTournaments()
	_ = handleTournamentSearchRequest(a, readyFrame(tid, r.coaches[0], 0))
	_ = handleTournamentSearchRequest(c, readyFrame(tid, r.coaches[2], 0))
	r.at(31 * time.Minute)
	r.d.TickTournaments()
	r.at(61 * time.Minute)
	r.d.TickTournaments()
	_ = handleTournamentSearchRequest(a, readyFrame(tid, r.coaches[0], 0))
	r.at(91 * time.Minute)
	r.d.TickTournaments()
	drain(t, c)

	ask := func(month, trim uint8, year uint16) *ladderCur {
		w := protocol.NewWriter().I32(0).I32(0).I32(0).U8(month).U8(trim).U16(year)
		if err := handleTournamentLadderRequest(c, &protocol.C2SFrame{
			Opcode: protocol.OpTournamentLadderRequest, Payload: w.Bytes()}); err != nil {
			t.Fatal(err)
		}
		p := drainPayload(t, c, protocol.OpTournamentLadder)
		if p == nil {
			t.Fatal("no 27507")
		}
		return &ladderCur{b: p, t: t}
	}

	// The edition finished in October 2026 (month 9, trimester 3).
	fin := r.reload(t).FinishedAt.In(time.Local)
	month, year := uint8(fin.Month()-1), uint16(fin.Year())
	cur := ask(month, month/3, year)
	cur.u8()
	cur.u8()
	cur.i16()
	for i := 0; i < 3; i++ {
		if pts := cur.i32(); pts != 3 {
			t.Errorf("window %d: C's own points = %d, want 3", i, pts)
		}
	}
	wantNames := []string{"CoachA", "CoachC", "CoachB", "CoachD"}
	wantPts := []int32{20, 3, 1, 1}
	for blk := 0; blk < 3; blk++ {
		count, start, end, rank := cur.i32(), cur.i32(), cur.i32(), cur.i32()
		if count != tournamentLadderPage || start != 0 || end != 4 || rank != 2 {
			t.Fatalf("window %d: count=%d start=%d end=%d myRank=%d, want %d/0/4/2",
				blk, count, start, end, rank, tournamentLadderPage)
		}
		for i := 0; i < 4; i++ {
			n := int(cur.i32())
			name := string(cur.b[cur.i : cur.i+n])
			cur.i += n
			if pts := cur.i32(); name != wantNames[i] || pts != wantPts[i] {
				t.Errorf("window %d row %d = %s/%d, want %s/%d", blk, i, name, pts, wantNames[i], wantPts[i])
			}
		}
		cur.u8()
	}

	// Another month of the same year: the month window is empty, the year
	// window still holds the edition.
	other := (month + 6) % 12
	cur = ask(other, other/3, year)
	cur.u8()
	cur.u8()
	cur.i16()
	monthPts, _, yearPts := cur.i32(), cur.i32(), cur.i32()
	if monthPts != 0 || yearPts != 3 {
		t.Errorf("other month: my points month=%d year=%d, want 0 and 3", monthPts, yearPts)
	}
	if count, _, end := cur.i32(), cur.i32(), cur.i32(); count != 0 || end != 0 {
		t.Errorf("other month: month window count=%d end=%d, want empty", count, end)
	}
}

// TestTournamentAchievementsAreReachable: the 25 achievements that waited on
// tournaments (182-206) are thresholds on 183, 187, 188 and 189, which the
// server now moves; and one of them, "register for 5 tournaments" (182),
// unlocks through the real 4607 handler and its 22000 toast.
func TestTournamentAchievementsAreReachable(t *testing.T) {
	r := newSchedRig(t, 1, 0, nil)
	achs, err := openRealGameData(t).LoadAchievements()
	if err != nil {
		t.Fatal(err)
	}
	r.d.Achievements = achs
	moved := map[int16]bool{statTournamentPoints: true, statOfficialWins: true,
		statTournamentDuels: true, statTournamentEntries: true}
	n := 0
	for id := int16(182); id <= 206; id++ {
		a := achs.Get(id)
		if a == nil {
			t.Fatalf("achievement %d missing from the data", id)
		}
		for _, c := range a.Conditions {
			if !moved[c.StatID] {
				t.Errorf("achievement %d waits on statistic %d, which nothing moves", id, c.StatID)
			}
		}
		n++
	}
	if n != 25 {
		t.Fatalf("%d achievements, want 25", n)
	}

	acc, _ := r.st.Accounts.CreateAccount("fan", "pw", false)
	co, _ := r.st.Coaches.Create(acc.ID, "Fan", 0, 0, 0)
	s := tmSession(r.d, co.ID, "Fan")
	for i := 0; i < 5; i++ {
		tr := &domain.Tournament{DefID: 1, Name: "T", Short: "T", Enabled: true, RegistrationOpen: true}
		if err := r.st.Tournaments.Create(tr); err != nil {
			t.Fatal(err)
		}
		w := protocol.NewWriter().I64(tr.WireID()).I64(int64(co.ID)).U16(0xFFFF).I32(0)
		_ = handleTournamentRegister(s, &protocol.C2SFrame{Opcode: protocol.OpTournamentRegister, Payload: w.Bytes()})
	}
	p := drainPayload(t, s, protocol.OpAchievementUnlocked)
	if len(p) != 2 || int16(p[0])<<8|int16(p[1]) != 182 {
		t.Fatalf("22000 payload %x, want achievement 182 after five registrations", p)
	}
}
