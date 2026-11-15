package main

import (
	"os"
	"path/filepath"
	"testing"
)

// checkTables reads every table through the App and checks the getters agree
// with the counts and come back sorted.
func checkTables(t *testing.T, a *App) {
	t.Helper()
	counts := a.GetDataCounts()
	if counts.Error != "" {
		t.Fatalf("GetDataCounts error: %s", counts.Error)
	}
	// The content carries all of these; a zero count means a load regression.
	for name, n := range map[string]int{
		"spells":        counts.Spells,
		"coachCards":    counts.CoachCards,
		"fighterCards":  counts.FighterCards,
		"summonings":    counts.Summonings,
		"staticEffects": counts.StaticEffects,
	} {
		if n <= 0 {
			t.Errorf("expected some %s, got %d", name, n)
		}
	}

	spells, err := a.GetSpells()
	if err != nil {
		t.Fatalf("GetSpells: %v", err)
	}
	if len(spells) != counts.Spells {
		t.Errorf("GetSpells len %d != count %d", len(spells), counts.Spells)
	}
	for i := 1; i < len(spells); i++ {
		if spells[i-1].ID > spells[i].ID {
			t.Fatalf("spells not sorted ascending at %d: %d > %d", i, spells[i-1].ID, spells[i].ID)
		}
	}

	cc, err := a.GetCoachCards()
	if err != nil || len(cc) != counts.CoachCards {
		t.Errorf("GetCoachCards len=%d err=%v (count %d)", len(cc), err, counts.CoachCards)
	}
	fc, err := a.GetFighterCards()
	if err != nil || len(fc) != counts.FighterCards {
		t.Errorf("GetFighterCards len=%d err=%v (count %d)", len(fc), err, counts.FighterCards)
	}
	sm, err := a.GetSummonings()
	if err != nil || len(sm) != counts.Summonings {
		t.Errorf("GetSummonings len=%d err=%v (count %d)", len(sm), err, counts.Summonings)
	}
	se, err := a.GetStaticEffects()
	if err != nil || len(se) != counts.StaticEffects {
		t.Errorf("GetStaticEffects len=%d err=%v (count %d)", len(se), err, counts.StaticEffects)
	}
}

// Away from a checkout the studio reads the content embedded in the binary.
func TestApp_ReadsEmbeddedContent(t *testing.T) {
	checkTables(t, &App{})
}

// Inside a checkout it reads server/content, so it shows what the server loads.
func TestApp_ReadsCheckoutContent(t *testing.T) {
	a := NewApp() // the tests run in server/cmd/studio, inside the checkout
	if a.paths.RulesDir == "" || a.paths.ContentDir == "" {
		t.Fatalf("content not detected from the checkout: %+v", a.paths)
	}
	checkTables(t, a)
}

// A broken rules tree is an error, not an empty table.
func TestApp_BrokenRulesErrors(t *testing.T) {
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "spells.json"), []byte("not json"), 0o644); err != nil {
		t.Fatal(err)
	}
	a := &App{paths: Paths{RulesDir: dir}}
	if counts := a.GetDataCounts(); counts.Error == "" {
		t.Error("expected an error for a broken rules tree")
	}
	if _, err := a.GetSpells(); err == nil {
		t.Error("GetSpells should error on a broken rules tree")
	}
}

func TestDetectRulesDirFromCheckout(t *testing.T) {
	dir := detectRulesDir()
	if dir == "" || !fileExists(filepath.Join(dir, "spells.json")) {
		t.Fatalf("detectRulesDir = %q", dir)
	}
}
