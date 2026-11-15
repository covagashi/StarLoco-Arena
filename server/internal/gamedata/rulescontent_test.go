package gamedata

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"

	"github.com/StarLoco/arena-2.70/content"
)

// TestRulesContentParity: the embedded rules content is exactly the retail
// tables, record by record (S43). A redesign that changes rules on purpose
// (S46: spells) retires the comparison for that table.
func TestRulesContentParity(t *testing.T) {
	if _, err := os.Stat(filepath.Join(clientBdataDir, "data.bdat")); err != nil {
		t.Skip("no client data")
	}
	retail, err := LoadRetailRulesContent(clientBdataDir)
	if err != nil {
		t.Fatal(err)
	}
	own, err := LoadRulesContent(content.Rules)
	if err != nil {
		t.Fatal(err)
	}
	same := func(what string, got, want any) {
		t.Helper()
		if !reflect.DeepEqual(got, want) {
			t.Errorf("%s: content and retail differ", what)
		}
	}
	same("spells", own.Spells.All(), retail.Spells.All())
	same("summonings", own.Summonings.All(), retail.Summonings.All())
	same("static effects", own.StaticEffects.All(), retail.StaticEffects.All())
	same("challenges", own.Challenges.All(), retail.Challenges.All())
	same("achievements", own.Achievements, retail.Achievements)
	same("conditions", own.Conditions, retail.Conditions)
	same("fusion labs", own.FusionLabs.All(), retail.FusionLabs.All())
	same("map bonuses", own.MapBonuses, retail.MapBonuses)
	same("tournaments", own.Tournaments, retail.Tournaments)
	same("sphere boards", own.SphereBoards, retail.SphereBoards)
	same("equipment pools", own.EquipmentPools, retail.EquipmentPools)
}

// TestRulesContentLoads: the embedded tree loads whole without client data,
// which is what a server with no data-dist runs on.
func TestRulesContentLoads(t *testing.T) {
	r, err := LoadRulesContent(content.Rules)
	if err != nil {
		t.Fatal(err)
	}
	if r.Spells.Len() == 0 || r.Challenges.Len() == 0 || r.Achievements.Len() == 0 ||
		r.SphereBoards.BoardCount() == 0 || len(r.Tournaments.Levels()) == 0 {
		t.Fatalf("rules content is missing tables: %d spells, %d challenges, %d achievements, "+
			"%d boards, %d tournament levels", r.Spells.Len(), r.Challenges.Len(),
			r.Achievements.Len(), r.SphereBoards.BoardCount(), len(r.Tournaments.Levels()))
	}
}
