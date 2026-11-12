package main

import (
	"testing"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

func TestSpellVfx(t *testing.T) {
	fx := func(ap, rmax int8, efs ...gamedata.Effect) vfxRecipe {
		return spellVfx(&gamedata.Spell{AP: ap, RangeMax: rmax, Effects: efs})
	}
	cases := []struct {
		name string
		got  vfxRecipe
		want vfxRecipe
	}{
		{"ranged fire", fx(4, 6, gamedata.Effect{ActionID: 131}), vfxRecipe{"bolt", "fire", 2, 0}},
		{"melee water", fx(2, 1, gamedata.Effect{ActionID: 133}), vfxRecipe{"hit", "water", 1, 0}},
		{"earth zone", fx(5, 5, gamedata.Effect{ActionID: 132, AreaShape: 3, AreaSize: []int32{1}}),
			vfxRecipe{"area", "earth", 3, 1}},
		{"heal", fx(3, 2, gamedata.Effect{ActionID: 69}), vfxRecipe{"heal", "neutral", 2, 0}},
		{"summon", fx(5, 1, gamedata.Effect{ActionID: 67}), vfxRecipe{"summon", "neutral", 3, 0}},
		{"teleport", fx(2, 2, gamedata.Effect{ActionID: 39}), vfxRecipe{"tp", "neutral", 1, 0}},
		{"AP loss", fx(3, 4, gamedata.Effect{ActionID: 16}), vfxRecipe{"curse", "neutral", 2, 0}},
		{"buff", fx(2, 0, gamedata.Effect{ActionID: 82}), vfxRecipe{"aura", "neutral", 1, 0}},
		{"crit-only damage ignored", fx(2, 0, gamedata.Effect{ActionID: 131, IsCritical: true}),
			vfxRecipe{"aura", "neutral", 1, 0}},
	}
	for _, c := range cases {
		if c.got != c.want {
			t.Errorf("%s: got %+v want %+v", c.name, c.got, c.want)
		}
	}
}

// Every class spell in the shipped data gets a recipe the client can draw.
func TestSpellVfxRealData(t *testing.T) {
	st, err := gamedata.Open("../../data-dist")
	if err != nil {
		t.Skip("no data-dist:", err)
	}
	sp, err := st.LoadSpells()
	if err != nil {
		t.Fatal(err)
	}
	shapes := map[string]int{}
	for _, s := range sp.All() {
		if s.BreedID < 1 || s.BreedID > 12 {
			continue
		}
		r := spellVfx(s)
		if r.Shape == "" || r.Elem == "" || r.K < 1 || r.K > 3 {
			t.Errorf("spell %d: bad recipe %+v", s.ID, r)
		}
		shapes[r.Shape]++
	}
	t.Logf("shapes: %v", shapes)
	for _, want := range []string{"bolt", "hit", "area", "aura", "heal", "summon"} {
		if shapes[want] == 0 {
			t.Errorf("no class spell drawn as %q", want)
		}
	}
}
