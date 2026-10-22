package gamedata

import (
	"os"
	"path/filepath"
	"testing"
)

// achievementDataDir is the shipped subset, which carries types 800/801/802, so
// this test does not need a local client tree. It still skips rather than fails
// if the directory is missing.
var achievementDataDir = filepath.Join("..", "..", "data-dist")

func openAchievements(t *testing.T) *Achievements {
	t.Helper()
	if _, err := os.Stat(filepath.Join(achievementDataDir, "data.bdat")); err != nil {
		t.Skip("no data-dist")
	}
	st, err := Open(achievementDataDir)
	if err != nil {
		t.Fatal(err)
	}
	ach, err := st.LoadAchievements()
	if err != nil {
		t.Fatal(err)
	}
	return ach
}

// TestAchievementRecordsAreConsumedExactly is the load-bearing test for the
// type-800 layout. Every record must be consumed to the byte: a short read means
// a field is missing or mis-sized, and an overrun means the decoder invented one.
// Since achievement completion is evaluated FROM these records, a silent
// mis-parse would make the server unlock the wrong things.
func TestAchievementRecordsAreConsumedExactly(t *testing.T) {
	if _, err := os.Stat(filepath.Join(achievementDataDir, "data.bdat")); err != nil {
		t.Skip("no data-dist")
	}
	st, err := Open(achievementDataDir)
	if err != nil {
		t.Fatal(err)
	}
	entries := st.EntriesOf(TypeAchievement)
	if len(entries) == 0 {
		t.Fatal("no type-800 records")
	}
	for _, e := range entries {
		rec, err := st.ReadRecord(e.Position)
		if err != nil {
			t.Fatalf("read record at %d: %v", e.Position, err)
		}
		a := decodeAchievement(rec.Data)
		if a == nil {
			t.Fatalf("record at %d (%d bytes) failed to decode", e.Position, len(rec.Data))
		}
		// Recompute the exact serialized size from what we decoded.
		want := 16 + 1 + len(a.Conditions)*4 + 1 + len(a.Cards)*4 + 1 + 4 + 1
		if want != len(rec.Data) {
			t.Errorf("achievement %d: decoded %d bytes but the record is %d "+
				"(conds=%d cards=%d)", a.ID, want, len(rec.Data),
				len(a.Conditions), len(a.Cards))
		}
	}
}

// TestAchievementCatalogueShape pins the shipped table so a data swap that
// changes it is noticed.
func TestAchievementCatalogueShape(t *testing.T) {
	ach := openAchievements(t)
	if got, want := ach.Len(), 332; got != want {
		t.Errorf("achievements = %d, want %d", got, want)
	}
	if got, want := len(ach.CategoryIDs()), 5; got != want {
		t.Errorf("categories = %d, want %d", got, want)
	}
	var subs int
	for _, id := range ach.CategoryIDs() {
		subs += len(ach.Category(id).Subcategories)
	}
	if got, want := subs, 13; got != want {
		t.Errorf("subcategories = %d, want %d", got, want)
	}
	// Every achievement must reference a category that exists, or the client's
	// tab strip would have nowhere to file it.
	for _, id := range ach.IDs() {
		a := ach.Get(id)
		if ach.Category(a.Category) == nil {
			t.Errorf("achievement %d references unknown category %d", a.ID, a.Category)
		}
	}
	// Every achievement is gated by something; one with no conditions at all
	// would complete for everyone the moment evaluation runs.
	for _, id := range ach.IDs() {
		a := ach.Get(id)
		if len(a.Conditions) == 0 && len(a.Cards) == 0 {
			t.Errorf("achievement %d has no conditions: it would unlock for free", a.ID)
		}
	}
}

// TestAchievementDoneAndProgress checks the two evaluation helpers against the
// client's rules, including the >= boundary and the mean-of-parts percentage.
func TestAchievementDoneAndProgress(t *testing.T) {
	a := &Achievement{
		ID:         1,
		Conditions: []AchievementCondition{{StatID: 10, Threshold: 4}},
		Cards:      []int32{99},
	}
	stat := func(v int32) func(int16) int32 { return func(int16) int32 { return v } }
	yes := func(int32) bool { return true }
	no := func(int32) bool { return false }

	if a.Done(stat(3), yes) {
		t.Error("below threshold must not be done")
	}
	if !a.Done(stat(4), yes) {
		t.Error("exactly at threshold must be done (client uses <)")
	}
	if !a.Done(stat(9), yes) {
		t.Error("overshooting the threshold must still be done")
	}
	if a.Done(stat(9), no) {
		t.Error("a missing card must block completion")
	}
	// 50% of the stat + 0% for the card, averaged over two parts.
	if got := a.Progress(stat(2), no); got != 25 {
		t.Errorf("progress = %d%%, want 25%%", got)
	}
	// The stat part clamps at 100 rather than running away.
	if got := a.Progress(stat(400), no); got != 50 {
		t.Errorf("progress = %d%%, want 50%% (stat part must clamp)", got)
	}
	if got := a.Progress(stat(4), yes); got != 100 {
		t.Errorf("progress = %d%%, want 100%%", got)
	}
}
