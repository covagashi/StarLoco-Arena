package game

import (
	"log/slog"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/store/storetest"
)

// TestStoredIllegalSpellsAreDroppedAtFightBuild covers the RETROACTIVE half of
// the 6011 fix.
//
// Filtering on save stops an illegal loadout being STORED; it does nothing about
// one already in the database. A fighter whose spells were written before the
// guard existed - or by any path that bypasses it - would still cast them,
// because castSpellByFighter trusts Fighter.Spells. The door was closed and the
// room never cleaned.
func TestStoredIllegalSpellsAreDroppedAtFightBuild(t *testing.T) {
	st, err := storetest.Open(t, t.TempDir()+"/legacy.db")
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })

	acc, _ := st.Accounts.CreateAccount("legacy", "pw", false)
	coach, _ := st.Coaches.Create(acc.ID, "Legacy", 0, 0, 0)

	d := &Deps{
		Store: st, Log: slog.Default(), World: NewRegistry(50),
		Spells: gamedata.NewSpells(
			&gamedata.Spell{ID: 10, BreedID: 1},  // legal for breed 1
			&gamedata.Spell{ID: 20, BreedID: 2},  // another breed
			&gamedata.Spell{ID: 428, BreedID: 0}, // monster/summon material
			&gamedata.Spell{ID: 193, BreedID: 99},
		),
	}

	// A breed-1 fighter with spells that were somehow already persisted.
	fr := &domain.Fighter{CoachID: coach.ID, BreedID: 1, Name: "Cheat", Budget: 100}
	if err := st.Fighters.Create(fr); err != nil {
		t.Fatalf("seed fighter: %v", err)
	}
	fr.Spells = []domain.FighterSpell{
		{SpellID: 10}, {SpellID: 20}, {SpellID: 428}, {SpellID: 193},
	}
	if len(fr.Spells) != 4 {
		t.Fatal("fixture broken")
	}

	got := fighterWithLegalSpells(d, fr)
	if len(got.Spells) != 1 || got.Spells[0].SpellID != 10 {
		var ids []int32
		for _, s := range got.Spells {
			ids = append(ids, s.SpellID)
		}
		t.Errorf("fight build kept spells %v, want only [10]: a loadout stored "+
			"before the 6011 guard still casts boss and cross-breed spells", ids)
	}

	// The original must not be mutated - it is the caller's row, and the fight
	// gets a copy.
	if len(fr.Spells) != 4 {
		t.Error("the stored fighter was mutated; filtering must not rewrite the DB row")
	}

	// A clean loadout is returned untouched, so the common case allocates nothing.
	clean := &domain.Fighter{ID: 2, BreedID: 1,
		Spells: []domain.FighterSpell{{SpellID: 10}}}
	if fighterWithLegalSpells(d, clean) != clean {
		t.Error("a legal loadout should be returned as-is, not copied")
	}
}

// TestBuildFightTeamDropsStoredIllegalSpells drives the CALL SITE through
// buildFightTeamFor, because a helper-only test lets a mutation delete the call
// and pass - the mistake this codebase has made repeatedly.
func TestBuildFightTeamDropsStoredIllegalSpells(t *testing.T) {
	st, err := storetest.Open(t, t.TempDir()+"/legacy2.db")
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })

	acc, _ := st.Accounts.CreateAccount("legacy2", "pw", false)
	coach, _ := st.Coaches.Create(acc.ID, "Legacy2", 0, 0, 0)

	d := &Deps{
		Store: st, Log: slog.Default(), World: NewRegistry(50),
		Spells: gamedata.NewSpells(
			&gamedata.Spell{ID: 10, BreedID: 1},
			&gamedata.Spell{ID: 428, BreedID: 0},
		),
	}
	sess := &Session{Coach: coach, deps: d, log: slog.Default()}

	fr := &domain.Fighter{CoachID: coach.ID, BreedID: 1, Name: "Cheat", Budget: 100}
	if err := st.Fighters.Create(fr); err != nil {
		t.Fatalf("seed fighter: %v", err)
	}
	// Persist an illegal spell directly, as a pre-fix row would look.
	if err := st.DB().Create(&domain.FighterSpell{
		FighterID: fr.ID, SpellID: 428, Slot: 0,
	}).Error; err != nil {
		t.Fatalf("seed spell: %v", err)
	}

	team, err := d.buildFightTeamFor(sess, 0, []Pos{{X: 1, Y: 1}}, []int64{int64(fr.ID)})
	if err != nil {
		t.Fatalf("build team: %v", err)
	}
	if len(team.Fighters) == 0 {
		t.Fatal("fixture broken: no fighter was fielded")
	}
	for _, sp := range team.Fighters[0].Fighter.Spells {
		if sp.SpellID == 428 {
			t.Error("a fighter went into the fight knowing spell 428 (pseudo-breed 0, " +
				"monster material): the stored loadout was not filtered at fight build")
		}
	}
}
