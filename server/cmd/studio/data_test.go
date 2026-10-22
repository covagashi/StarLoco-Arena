package main

import (
	"path/filepath"
	"testing"
)

// realDataDir resolves the v2.70 server's data store (data.bdat + indexes.bdat)
// relative to this package. Real-data tests skip (not fail) when it is absent,
// matching the repo convention.
func realDataDir(t *testing.T) string {
	t.Helper()
	dir := filepath.Join("..", "..", "data-dist")
	if !looksLikeDataDir(dir) {
		t.Skipf("v2.70 .bdat store not found at %s; skipping real-data test", dir)
	}
	return dir
}

func TestApp_ReadsRealBdatStore(t *testing.T) {
	dir := realDataDir(t)
	a := NewApp()
	if p := a.SetDataDir(dir); !p.DataDirValid {
		t.Fatalf("SetDataDir(%q) reported invalid", dir)
	}

	counts := a.GetDataCounts()
	if counts.Error != "" {
		t.Fatalf("GetDataCounts error: %s", counts.Error)
	}
	// The shipped store carries all of these; a zero count means a decode regression.
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

	// Every other getter must succeed and agree with its count.
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

func TestApp_InvalidDataDirErrors(t *testing.T) {
	a := NewApp()
	a.SetDataDir(t.TempDir()) // valid path, but no .bdat pair
	counts := a.GetDataCounts()
	if counts.Error == "" {
		t.Error("expected an error for a directory with no .bdat store")
	}
	if _, err := a.GetSpells(); err == nil {
		t.Error("GetSpells should error when no valid data dir is selected")
	}
}

func TestLooksLikeDataDir_EmptyDir(t *testing.T) {
	if looksLikeDataDir(t.TempDir()) {
		t.Error("an empty dir should not look like a .bdat store")
	}
}
