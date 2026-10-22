package game

import (
	"encoding/binary"
	"errors"
	"testing"
	"time"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store"
)

// testTournaments is the line-up a fresh install ships with, which is what these
// wire tests exercise. Row ids are assigned as if freshly inserted so WireID()
// matches what a real database would produce.
func testTournaments() []domain.Tournament {
	ts := store.DefaultTournaments()
	for i := range ts {
		ts[i].ID = uint(i + 1)
	}
	return ts
}

// noCardDefIDs are the retail 2.70 tournament definition ids (data.bdat type-1000
// aub records) whose referenceCardId == 0 — i.e. a coach can register without
// owning a card. A 28602 row MUST use one of the 22 real definition ids or the
// client NPEs dereferencing it; sticking to the no-card subset also lets
// registration complete without a card check. See BUGS.md B-044.
var noCardDefIDs = map[uint16]bool{
	1: true, 4: true, 5: true, 6: true, 7: true, 8: true, 9: true, 10: true,
	11: true, 12: true, 14: true, 15: true, 16: true, 17: true, 18: true,
	20: true, 21: true, 22: true, 23: true, 24: true,
}

// TestStandingTournamentsAreCrashSafe locks the invariants that keep the retail
// client from throwing: every standing tournament must reference a real no-card
// definition id, ids must be unique, and the name must fit the qr_0 i8 length
// prefix (a name > 127 bytes presents a negative length and crashes the decoder).
func TestStandingTournamentsAreCrashSafe(t *testing.T) {
	ts := testTournaments()
	if len(ts) == 0 {
		t.Fatal("no standing tournaments defined")
	}
	seen := map[int64]bool{}
	for _, tr := range ts {
		if !noCardDefIDs[tr.DefID] {
			t.Errorf("tournament %q defID %d is not a real no-card definition -> client would NPE", tr.Name, tr.DefID)
		}
		if tr.WireID() == 0 {
			t.Errorf("tournament %q has a zero wire id", tr.Name)
		}
		if seen[tr.WireID()] {
			t.Errorf("duplicate tournament wire id %d", tr.WireID())
		}
		seen[tr.WireID()] = true
		if len(tr.Name) > 127 {
			t.Errorf("name %q is %d bytes; exceeds the qr_0 i8 length prefix (127)", tr.Name, len(tr.Name))
		}
		if len(tr.Short) > 127 {
			t.Errorf("short %q is %d bytes; exceeds the qr_0 i8 length prefix (127)", tr.Short, len(tr.Short))
		}
	}
}

// TestTournamentCalendarWireIsExact re-decodes 17003 exactly the way the client's
// awa_0/qr_0 decoders do and asserts nothing is left over: a byte too many or too
// few silently drops the frame in the client and the calendar never opens. It also
// enforces the two crash traps: typeId must be 4 (the tournament content prototype)
// and each event must carry at least one registration-period pair (qr_0 reads
// element 0 of that list unguarded).
func TestTournamentCalendarWireIsExact(t *testing.T) {
	ts := testTournaments()
	nowMs := time.Now().UnixMilli()
	frame, err := buildTournamentCalendar(ts)
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	if got := binary.BigEndian.Uint16(frame[2:4]); got != protocol.OpTournamentCalendar {
		t.Fatalf("opcode = %d, want %d", got, protocol.OpTournamentCalendar)
	}
	r := protocol.NewReader(frame[4:])
	count, err := r.U16()
	if err != nil {
		t.Fatalf("count: %v", err)
	}
	if int(count) != len(ts) {
		t.Fatalf("event count = %d, want %d", count, len(ts))
	}
	for i := 0; i < int(count); i++ {
		typeID, _ := r.I32()
		if typeID != tournamentContentTypeID {
			t.Errorf("event %d typeId = %d, want %d (qr_0 prototype)", i, typeID, tournamentContentTypeID)
		}
		// iz_0 base + th_2 extra date.
		r.I64()                 // eventId
		startDate, _ := r.I64() // OV slot: the runs-until bound
		endDate, _ := r.I64()
		recurrence, _ := r.I64()
		r.I32()                 // labelIndex
		extraDate, _ := r.I64() // bOF slot: the already-started bound

		// These two bounds are a silent-failure trap, which is why they are
		// asserted rather than skipped: the client filters a non-recurring
		// event in when its OV slot is still in the future AND its bOF slot is
		// already past. Swap them and the event vanishes from the calendar with
		// no error anywhere — the tournament window simply comes up empty.
		if startDate <= nowMs {
			t.Errorf("event %d startDate (OV) = %d is not in the future (now %d); "+
				"the client filters the event out and the calendar shows nothing",
				i, startDate, nowMs)
		}
		if extraDate >= nowMs {
			t.Errorf("event %d extraDate (bOF) = %d is not in the past (now %d); "+
				"the client treats the event as not yet started and hides it",
				i, extraDate, nowMs)
		}
		if endDate != startDate {
			t.Errorf("event %d endDate = %d, want it mirroring startDate %d", i, endDate, startDate)
		}
		if recurrence != 0 {
			t.Errorf("event %d recurrence = %d, want 0 (single occurrence)", i, recurrence)
		}
		// qr_0 fields.
		r.I64() // tournamentId
		name, _ := r.StringU8()
		descLen, _ := r.U16()
		r.String(int(descLen))
		r.StringU8() // short
		sched, _ := r.U8()
		for j := 0; j < int(sched); j++ {
			r.I64()
			r.I64()
		}
		reg, _ := r.U8()
		if reg < 1 {
			t.Errorf("event %d has %d registration-period pairs; must be >=1 (client reads element 0 unguarded)", i, reg)
		}
		for j := 0; j < int(reg); j++ {
			r.I64()
			r.I64()
		}
		if name == "" {
			t.Errorf("event %d has an empty name", i)
		}
	}
	if r.Remaining() != 0 {
		t.Errorf("calendar has %d trailing bytes; the client reads exactly the declared entries", r.Remaining())
	}
}

// TestTournamentListWireIsExact re-decodes 28602 field-by-field and asserts an exact
// consume plus the values that make a row registerable: not-registered status, an
// open registration flag, a real definition id and no special fight params.
func TestTournamentListWireIsExact(t *testing.T) {
	ts := testTournaments()
	frame, err := buildTournamentList(999, nil, ts) // no manager -> everyone not registered
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	if got := binary.BigEndian.Uint16(frame[2:4]); got != protocol.OpTournamentList {
		t.Fatalf("opcode = %d, want %d", got, protocol.OpTournamentList)
	}
	r := protocol.NewReader(frame[4:])
	count, err := r.I32()
	if err != nil {
		t.Fatalf("count: %v", err)
	}
	if int(count) != len(ts) {
		t.Fatalf("row count = %d, want %d", count, len(ts))
	}
	for i := 0; i < int(count); i++ {
		want := ts[i]
		tid, _ := r.I64()
		search, _ := r.U8()
		status, _ := r.U8()
		defID, _ := r.U16()
		regOpen, _ := r.U8()
		fp, _ := r.I32()
		name, _ := r.StringU32()
		r.StringU32() // desc
		r.StringU32() // organizer
		kind, _ := r.U8()

		if tid != want.WireID() {
			t.Errorf("row %d id = %d, want %d", i, tid, want.WireID())
		}
		if search != 0 {
			t.Errorf("row %d openedSearch = %d, want 0", i, search)
		}
		if int8(status) != tournamentCoachNotRegistered {
			t.Errorf("row %d status = %d, want %d (not registered)", i, int8(status), tournamentCoachNotRegistered)
		}
		if defID != want.DefID {
			t.Errorf("row %d defID = %d, want %d", i, defID, want.DefID)
		}
		if regOpen != boolByte(want.RegistrationOpen) {
			t.Errorf("row %d registrationOpen = %d, want %d", i, regOpen, boolByte(want.RegistrationOpen))
		}
		if fp != 0 {
			t.Errorf("row %d fightParamCount = %d, want 0", i, fp)
		}
		if name != want.Name {
			t.Errorf("row %d name = %q, want %q", i, name, want.Name)
		}
		if kind != domain.TournamentKindPrivate {
			t.Errorf("row %d kind = %d, want %d", i, kind, domain.TournamentKindPrivate)
		}
	}
	if r.Remaining() != 0 {
		t.Errorf("list has %d trailing bytes", r.Remaining())
	}
}

// TestTournamentListReportsClosedRegistration covers the admin-controlled half
// of the row that the seed line-up cannot exercise: every default tournament is
// open, so the "registration open" byte would look correct even if it were
// hardcoded. Closing registration from the console has to actually reach the
// client, or the button stays live and the player gets refused with no
// explanation.
//
// The tournament must still be LISTED — closing registration hides the button,
// not the event. Hiding it entirely is what Enabled does, and that is filtered
// in the query rather than on the wire.
func TestTournamentListReportsClosedRegistration(t *testing.T) {
	ts := testTournaments()
	ts[1].RegistrationOpen = false

	frame, err := buildTournamentList(1, nil, ts)
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	r := protocol.NewReader(frame[4:])
	count, _ := r.I32()
	if int(count) != len(ts) {
		t.Fatalf("row count = %d, want %d — a closed tournament must still be listed", count, len(ts))
	}
	for i := 0; i < int(count); i++ {
		r.I64() // id
		r.U8()  // search
		r.U8()  // status
		r.U16() // defID
		regOpen, _ := r.U8()
		r.I32()
		r.StringU32()
		r.StringU32()
		r.StringU32()
		r.U8()

		want := boolByte(ts[i].RegistrationOpen)
		if regOpen != want {
			t.Errorf("row %d (%q) registrationOpen = %d, want %d",
				i, ts[i].Name, regOpen, want)
		}
	}
	if r.Remaining() != 0 {
		t.Errorf("list has %d trailing bytes", r.Remaining())
	}
}

// fakeRegStore is an in-process stand-in for the registration store, so the
// write-through and load-back paths can be tested without a database.
type fakeRegStore struct {
	rows     []domain.TournamentRegistration
	slots    []domain.TournamentSlot
	addErr   error
	loadErr  error
	slotErr  error
	slotSets int
}

func (f *fakeRegStore) MarkCarried(coachID uint, tid int64) error {
	for i := range f.rows {
		if f.rows[i].CoachID == coachID && f.rows[i].TournamentWireID == tid {
			f.rows[i].Carried = true
		}
	}
	return nil
}

func (f *fakeRegStore) ListSlots() ([]domain.TournamentSlot, error) {
	return f.slots, f.slotErr
}

func (f *fakeRegStore) SetSlot(tid int64, slot int32, coachID uint) error {
	f.slotSets++
	if f.slotErr != nil {
		return f.slotErr
	}
	for i := range f.slots {
		if f.slots[i].TournamentWireID == tid && f.slots[i].Slot == slot {
			f.slots[i].CoachID = coachID
			return nil
		}
	}
	f.slots = append(f.slots, domain.TournamentSlot{
		TournamentWireID: tid, Slot: slot, CoachID: coachID,
	})
	return nil
}

func (f *fakeRegStore) ListRegistrations() ([]domain.TournamentRegistration, error) {
	return f.rows, f.loadErr
}

func (f *fakeRegStore) AddRegistration(coachID uint, tid int64) error {
	if f.addErr != nil {
		return f.addErr
	}
	for _, r := range f.rows {
		if r.CoachID == coachID && r.TournamentWireID == tid {
			return nil
		}
	}
	f.rows = append(f.rows, domain.TournamentRegistration{CoachID: coachID, TournamentWireID: tid})
	return nil
}

func (f *fakeRegStore) RemoveRegistration(coachID uint, tid int64) error {
	out := f.rows[:0]
	for _, r := range f.rows {
		if r.CoachID == coachID && r.TournamentWireID == tid {
			continue
		}
		out = append(out, r)
	}
	f.rows = out
	return nil
}

// TestTournamentRegistrationSurvivesRestart is the B-101 guard: a registration
// must be written through to the store and come back when a fresh manager is
// built from it. Before this, every restart silently un-registered everybody.
func TestTournamentRegistrationSurvivesRestart(t *testing.T) {
	st := &fakeRegStore{}
	tid := testTournaments()[0].WireID()
	const coach = uint(9)

	first, err := NewTournamentManagerWithStore(st)
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	if !first.Register(coach, tid) {
		t.Fatal("first Register returned false")
	}
	if len(st.rows) != 1 {
		t.Fatalf("store holds %d rows, want 1 — the registration was not written "+
			"through, so a restart would lose it", len(st.rows))
	}

	// "Restart": a brand-new manager over the same store.
	second, err := NewTournamentManagerWithStore(st)
	if err != nil {
		t.Fatalf("rebuild: %v", err)
	}
	if !second.IsRegistered(coach, tid) {
		t.Error("registration did not survive the restart")
	}
	if second.Loaded() != 1 {
		t.Errorf("Loaded() = %d, want 1", second.Loaded())
	}
	if second.CountFor(tid) != 1 {
		t.Errorf("CountFor = %d, want 1", second.CountFor(tid))
	}
}

// TestTournamentUnregisterIsPersisted: withdrawing must also reach the store, or
// a restart would resurrect a registration the player cancelled.
func TestTournamentUnregisterIsPersisted(t *testing.T) {
	st := &fakeRegStore{}
	tid := testTournaments()[0].WireID()
	const coach = uint(9)

	tm, _ := NewTournamentManagerWithStore(st)
	tm.Register(coach, tid)
	if !tm.Unregister(coach, tid) {
		t.Fatal("Unregister returned false for a live registration")
	}
	if tm.Unregister(coach, tid) {
		t.Error("second Unregister should return false (idempotent)")
	}
	if len(st.rows) != 0 {
		t.Errorf("store still holds %d rows after unregister", len(st.rows))
	}
	if again, _ := NewTournamentManagerWithStore(st); again.IsRegistered(coach, tid) {
		t.Error("a cancelled registration came back after restart")
	}
}

// TestTournamentManagerWithoutStoreStillWorks: the store is optional, and a
// manager built without one must behave exactly as the old in-memory tracker did
// (unit tests and any store-less dev run depend on it).
func TestTournamentManagerWithoutStoreStillWorks(t *testing.T) {
	tm, err := NewTournamentManagerWithStore(nil)
	if err != nil {
		t.Fatalf("nil store returned an error: %v", err)
	}
	tid := testTournaments()[0].WireID()
	if !tm.Register(1, tid) || !tm.IsRegistered(1, tid) {
		t.Error("registration does not work without a store")
	}
}

// TestTournamentManagerRegister covers the registration tracker:
// Register is idempotent and IsRegistered reflects it.
func TestTournamentManagerRegister(t *testing.T) {
	tm := NewTournamentManager()
	const coach = uint(42)
	tid := testTournaments()[0].WireID()

	if tm.IsRegistered(coach, tid) {
		t.Error("fresh manager reports coach registered")
	}
	if !tm.Register(coach, tid) {
		t.Error("first Register should return true")
	}
	if tm.Register(coach, tid) {
		t.Error("second Register should return false (idempotent)")
	}
	if !tm.IsRegistered(coach, tid) {
		t.Error("IsRegistered false after Register")
	}
	if tm.IsRegistered(coach+1, tid) {
		t.Error("registration leaked to another coach")
	}
}

// TestTournamentListReflectsRegistration proves that after a coach registers, the
// re-built list marks exactly that tournament as registered (status "first round")
// and leaves the others not-registered — so a re-opened window is consistent.
func TestTournamentListReflectsRegistration(t *testing.T) {
	tm := NewTournamentManager()
	const coach = uint(7)
	ts := testTournaments()
	target := ts[1].WireID()
	tm.Register(coach, target)

	frame, err := buildTournamentList(coach, tm, ts)
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	r := protocol.NewReader(frame[4:])
	count, _ := r.I32()
	for i := 0; i < int(count); i++ {
		tid, _ := r.I64()
		r.U8() // search
		status, _ := r.U8()
		r.U16() // defID
		r.U8()  // regOpen
		r.I32() // fightParamCount
		r.StringU32()
		r.StringU32()
		r.StringU32()
		r.U8() // kind
		want := tournamentCoachNotRegistered
		if tid == target {
			want = tournamentCoachFirstRound
		}
		if int8(status) != want {
			t.Errorf("tid %d status = %d, want %d", tid, int8(status), want)
		}
	}
	if r.Remaining() != 0 {
		t.Errorf("list has %d trailing bytes", r.Remaining())
	}
}

// TestBracketSurvivesRestart: registrations were persisted while the bracket they
// feed was not, so a restart reset every tournament to its first round - which
// looked exactly like the results had been thrown away, because they had.
func TestBracketSurvivesRestart(t *testing.T) {
	st := &fakeRegStore{rows: []domain.TournamentRegistration{
		{CoachID: 1, TournamentWireID: 7},
		{CoachID: 2, TournamentWireID: 7},
	}}
	m, err := NewTournamentManagerWithStore(st)
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	// Two entrants seed into 16/17, so this one match decides slot 8 and the
	// byes above it carry the winner to the root.
	if got := m.RecordMatchResult(7, 1, 2); got != bracketWinnerSlot {
		t.Fatalf("advanced to %d, want %d", got, bracketWinnerSlot)
	}
	if st.slotSets == 0 {
		t.Fatal("the result was never written through to the store")
	}

	// Reboot from the same store.
	m2, err := NewTournamentManagerWithStore(st)
	if err != nil {
		t.Fatalf("rebuild: %v", err)
	}
	if got := m2.BracketSlots(7)[8]; got != 1 {
		t.Errorf("after restart slot 8 = coach %d, want 1 - the bracket was reset", got)
	}
}

// TestBracketLoadFailureIsReported: starting with a silently empty bracket is
// indistinguishable from every entrant having been knocked back to round one.
func TestBracketLoadFailureIsReported(t *testing.T) {
	st := &fakeRegStore{slotErr: errors.New("boom")}
	if _, err := NewTournamentManagerWithStore(st); err == nil {
		t.Error("a bracket load failure was swallowed")
	}
}
