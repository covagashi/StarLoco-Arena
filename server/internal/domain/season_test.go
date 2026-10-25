package domain

import (
	"testing"
	"time"
)

func TestSeasonPrize(t *testing.T) {
	for rank, want := range map[int32]int32{0: 0, 1: 500, 2: 300, 3: 300, 4: 150, 10: 150, 11: 50, 50: 50, 51: 0} {
		if got := SeasonPrize(rank); got != want {
			t.Errorf("SeasonPrize(%d) = %d, want %d", rank, got, want)
		}
	}
}

func TestSoftReset(t *testing.T) {
	if got := SoftReset(1400, 1000); got != 1200 {
		t.Errorf("1400 → %d, want 1200", got)
	}
	if got := SoftReset(800, 1000); got != 900 {
		t.Errorf("800 → %d, want 900 (a low rating climbs back too)", got)
	}
}

// TestSeasonBounds: a season ends on the first of a month, and never less
// than 14 days after it starts.
func TestSeasonBounds(t *testing.T) {
	for _, tc := range []struct{ now, end string }{
		{"2026-10-01T00:00:00Z", "2026-11-01T00:00:00Z"},
		{"2026-10-17T12:00:00Z", "2026-11-01T00:00:00Z"},
		{"2026-10-25T12:00:00Z", "2026-12-01T00:00:00Z"},
		{"2026-12-20T00:00:00Z", "2027-02-01T00:00:00Z"},
	} {
		now, _ := time.Parse(time.RFC3339, tc.now)
		_, end := SeasonBounds(now)
		if got := end.Format(time.RFC3339); got != tc.end {
			t.Errorf("SeasonBounds(%s) ends %s, want %s", tc.now, got, tc.end)
		}
	}
}
