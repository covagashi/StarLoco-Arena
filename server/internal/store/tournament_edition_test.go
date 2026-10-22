package store

import (
	"testing"
	"time"

	"github.com/StarLoco/arena-2.70/internal/domain"
)

// Editions (S09): the schedule is saved by Update, an edition finishes once and
// leaves the player list, and deleting one takes its bracket with it.

func TestTournamentEditionLifecycle(t *testing.T) {
	st := newTestStore(t)
	start := time.Date(2026, 11, 1, 20, 0, 0, 0, time.UTC)
	tr := &domain.Tournament{DefID: 1, Name: "Ed", Short: "Ed", Enabled: true, RegistrationOpen: true}
	if err := st.Tournaments.Create(tr); err != nil {
		t.Fatal(err)
	}

	tr.SearchPeriodStart, tr.SearchPeriodMinutes = start, 45
	tr.SearchPeriods, tr.PeriodIntervalMinutes, tr.RepeatDays = 4, 1440, 7
	if err := st.Tournaments.Update(tr); err != nil {
		t.Fatal(err)
	}
	got, _ := st.Tournaments.Get(tr.ID)
	if !got.SearchPeriodStart.Equal(start) || got.SearchPeriodMinutes != 45 ||
		got.SearchPeriods != 4 || got.PeriodIntervalMinutes != 1440 || got.RepeatDays != 7 {
		t.Fatalf("schedule not saved: %+v", got)
	}

	ok, err := st.Tournaments.MarkFinished(tr.ID, 9, start.Add(time.Hour))
	if err != nil || !ok {
		t.Fatalf("first finish: %v %v", ok, err)
	}
	if ok, _ := st.Tournaments.MarkFinished(tr.ID, 10, start.Add(2*time.Hour)); ok {
		t.Error("an edition finished twice")
	}
	got, _ = st.Tournaments.Get(tr.ID)
	if !got.Finished() || got.WinnerCoachID != 9 {
		t.Errorf("finished=%v winner=%d, want the first finish to stand", got.Finished(), got.WinnerCoachID)
	}
	live, _ := st.Tournaments.ListEnabled()
	for _, l := range live {
		if l.ID == tr.ID {
			t.Error("a finished edition is still offered to players")
		}
	}

	next := *got
	next.ID, next.FinishedAt, next.PreviousID = 0, nil, tr.ID
	if err := st.Tournaments.Create(&next); err != nil {
		t.Fatal(err)
	}
	if n, err := st.Tournaments.NextEdition(tr.ID); err != nil || n.ID != next.ID {
		t.Errorf("NextEdition = %+v, %v; want %d", n, err, next.ID)
	}

	if err := st.Tournaments.SetSlot(next.WireID(), 8, 3); err != nil {
		t.Fatal(err)
	}
	if err := st.Tournaments.Delete(next.ID); err != nil {
		t.Fatal(err)
	}
	slots, _ := st.Tournaments.ListSlots()
	for _, s := range slots {
		if s.TournamentWireID == next.WireID() {
			t.Error("deleting a tournament left its bracket behind for the next row to inherit")
		}
	}
}
