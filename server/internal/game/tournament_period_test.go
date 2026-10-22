package game

import (
	"testing"
	"time"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// 28630 is the message that makes the whole Tournois tab reachable: it creates
// the client's tournament NOTIFICATION (zN builds a td_0), and clicking that is
// the only thing that sets the selected tournament (agz_1 -> vk_1.ad(tid)).
// Without it "Combattre" refuses with error.noTournamentSelected forever.
func TestSearchPeriodWireIsExact(t *testing.T) {
	for _, tc := range []struct {
		tid  int64
		open bool
		want byte
	}{
		{7, true, 1},
		{9, false, 0},
	} {
		frame, err := buildTournamentSearchPeriod(tc.tid, tc.open)
		if err != nil {
			t.Fatalf("build: %v", err)
		}
		r := protocol.NewReader(frame[4:]) // skip [u16 len][u16 opcode]
		tid, err := r.I64()
		if err != nil {
			t.Fatalf("tid: %v", err)
		}
		open, err := r.U8()
		if err != nil {
			t.Fatalf("open flag: %v", err)
		}
		if tid != tc.tid || open != tc.want {
			t.Errorf("28630(%d,%v) = tid %d flag %d, want tid %d flag %d",
				tc.tid, tc.open, tid, open, tc.tid, tc.want)
		}
		if r.Remaining() != 0 {
			t.Errorf("%d trailing bytes - dg_0 reads exactly 9", r.Remaining())
		}
	}
}

// TestSearchPeriodOpcode: it must be 28630 and not the neighbouring 28644/28646,
// which build a DIFFERENT notification (a countdown, not a selectable tournament).
func TestSearchPeriodOpcode(t *testing.T) {
	frame, err := buildTournamentSearchPeriod(1, true)
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	if got := uint16(frame[2])<<8 | uint16(frame[3]); got != protocol.OpTournamentSearchPeriod {
		t.Errorf("opcode = %d, want %d", got, protocol.OpTournamentSearchPeriod)
	}
	if protocol.OpTournamentSearchPeriod != 28630 {
		t.Errorf("OpTournamentSearchPeriod = %d, want 28630",
			protocol.OpTournamentSearchPeriod)
	}
}

// --- scheduled opponent-search period (28644) ---

// TestSearchPeriodDrivesTheAdvertisedSchedule: the calendar's "phase" pair used
// to be invented as now+1h..now+2h on every request, so what the player was shown
// drifted each time the window was opened and matched nothing the server knew.
// With a real schedule the advertised window must BE that schedule.
func TestSearchPeriodDrivesTheAdvertisedSchedule(t *testing.T) {
	start := time.Now().Add(3 * time.Hour).Truncate(time.Second)
	tr := &domain.Tournament{
		ID: 1, DefID: 1, Name: "Sched", Short: "S", Enabled: true,
		SearchPeriodStart: start, SearchPeriodMinutes: 30,
	}
	w := protocol.NewWriter()
	writeTournamentEvent(w, tr, time.Now())

	phaseStart, phaseEnd := phasePairFromEvent(t, w.Bytes())
	if phaseStart != start.UnixMilli() {
		t.Errorf("advertised phase start = %d, want %d (the tournament's own "+
			"schedule, not an invented window)", phaseStart, start.UnixMilli())
	}
	if want := start.Add(30 * time.Minute).UnixMilli(); phaseEnd != want {
		t.Errorf("advertised phase end = %d, want %d", phaseEnd, want)
	}
}

// TestUnscheduledTournamentKeepsTheOldWindow: rows created before the schedule
// existed have a zero start, and must still render rather than advertising 1970.
func TestUnscheduledTournamentKeepsTheOldWindow(t *testing.T) {
	now := time.Now()
	tr := &domain.Tournament{ID: 1, DefID: 1, Name: "Old", Short: "O", Enabled: true}
	w := protocol.NewWriter()
	writeTournamentEvent(w, tr, now)

	phaseStart, phaseEnd := phasePairFromEvent(t, w.Bytes())
	if phaseStart <= now.UnixMilli() || phaseEnd <= phaseStart {
		t.Errorf("unscheduled tournament advertised %d..%d, want a sane future "+
			"window", phaseStart, phaseEnd)
	}
}

// phasePairFromEvent walks a qr_0 calendar body to its schedule pair.
func phasePairFromEvent(t *testing.T, b []byte) (int64, int64) {
	t.Helper()
	r := protocol.NewReader(b)
	mustI32 := func() int32 {
		v, err := r.I32()
		if err != nil {
			t.Fatalf("i32: %v", err)
		}
		return v
	}
	mustI64 := func() int64 {
		v, err := r.I64()
		if err != nil {
			t.Fatalf("i64: %v", err)
		}
		return v
	}
	mustU8 := func() uint8 {
		v, err := r.U8()
		if err != nil {
			t.Fatalf("u8: %v", err)
		}
		return v
	}

	mustI32() // typeId
	mustI64() // eventId
	mustI64() // startDate slot
	mustI64() // endDate
	mustI64() // recurrence
	mustI32() // label
	mustI64() // extraDate
	mustI64() // tournamentId
	if _, err := r.StringU8(); err != nil {
		t.Fatalf("name: %v", err)
	}
	dlen, err := r.U16()
	if err != nil {
		t.Fatalf("description len: %v", err)
	}
	if _, err := r.String(int(dlen)); err != nil {
		t.Fatalf("description: %v", err)
	}
	if _, err := r.StringU8(); err != nil {
		t.Fatalf("short: %v", err)
	}
	if n := mustU8(); n < 1 {
		t.Fatalf("schedule pairs = %d, want at least 1", n)
	}
	return mustI64(), mustI64()
}

// TestCalendarCarriesEveryPeriod: a scheduled edition sends one phase pair per
// search period (S09; the native calendar places the tournament on those days)
// and its registration window ends where the first period starts.
func TestCalendarCarriesEveryPeriod(t *testing.T) {
	start := time.Now().Add(24 * time.Hour).Truncate(time.Second)
	tr := &domain.Tournament{
		ID: 1, DefID: 1, Name: "Multi", Short: "M", Enabled: true,
		SearchPeriodStart: start, SearchPeriodMinutes: 60,
		SearchPeriods: 3, PeriodIntervalMinutes: 24 * 60,
	}
	w := protocol.NewWriter()
	writeTournamentEvent(w, tr, time.Now())
	b := w.Bytes()
	// Skip to the phase list: everything phasePairFromEvent reads, minus the
	// count it consumes, is fixed except the three strings.
	r := protocol.NewReader(b)
	_, _ = r.I32()
	for i := 0; i < 3; i++ {
		_, _ = r.I64()
	}
	_, _ = r.I64()
	_, _ = r.I32()
	_, _ = r.I64()
	_, _ = r.I64()
	_, _ = r.StringU8()
	dl, _ := r.U16()
	_, _ = r.String(int(dl))
	_, _ = r.StringU8()
	n, _ := r.U8()
	if n != 3 {
		t.Fatalf("phase pairs = %d, want 3", n)
	}
	for i := 0; i < 3; i++ {
		s, _ := r.I64()
		e, _ := r.I64()
		want := start.Add(time.Duration(i) * 24 * time.Hour)
		if s != want.UnixMilli() || e != want.Add(time.Hour).UnixMilli() {
			t.Errorf("period %d = %d..%d, want %d..%d", i, s, e, want.UnixMilli(), want.Add(time.Hour).UnixMilli())
		}
	}
	if rn, _ := r.U8(); rn != 1 {
		t.Fatalf("registration pairs = %d, want 1", rn)
	}
	_, _ = r.I64()
	if regEnd, _ := r.I64(); regEnd != start.UnixMilli() {
		t.Errorf("registration ends %d, want the first period's start %d", regEnd, start.UnixMilli())
	}
}
