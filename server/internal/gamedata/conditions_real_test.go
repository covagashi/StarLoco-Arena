package gamedata

import (
	"os"
	"path/filepath"
	"testing"
)

// TestLoadConditionsReal locks the type-902 decode against the shipped data.
func TestLoadConditionsReal(t *testing.T) {
	if _, err := os.Stat(filepath.Join(clientBdataDir, "data.bdat")); err != nil {
		t.Skip("no client data")
	}
	st, err := Open(clientBdataDir)
	if err != nil {
		t.Fatal(err)
	}
	conds, err := st.LoadConditions()
	if err != nil {
		t.Fatal(err)
	}

	// Population canary: the shipped catalogue is 111 records. A decoder that
	// silently drops records is the failure mode this catches.
	if conds.Len() != 111 {
		t.Errorf("decoded %d conditions, want 111", conds.Len())
	}

	// EVERY record must carry effects, and never both kinds. That invariant is
	// what lets the apply path route a condition by inspecting only one list.
	var meta, fight, both, neither int
	for _, id := range conds.IDs() {
		c := conds.Get(id)
		switch {
		case len(c.MetaEffects) > 0 && len(c.FightEffects) > 0:
			both++
		case len(c.MetaEffects) > 0:
			meta++
		case len(c.FightEffects) > 0:
			fight++
		default:
			neither++
		}
	}
	if both != 0 {
		t.Errorf("%d conditions carry BOTH meta and in-fight effects; the apply path assumes never", both)
	}
	if neither != 0 {
		t.Errorf("%d conditions carry no effects at all (likely a truncated decode)", neither)
	}
	if meta != 54 || fight != 57 {
		t.Errorf("meta-only=%d fight-only=%d, want 54/57", meta, fight)
	}

	// The 10 wounds are the heart of the layer. Their ids, types and payloads are
	// pinned individually: these are what the wound roller inflicts, so a decode
	// shift here would silently change what a wound DOES.
	wounds := []struct {
		id     int16
		typ    int16
		action int32
		param  float32
		isMeta bool
		what   string
	}{
		{1, 1, 123, 20, false, "light leg: -20% dodge"},
		{3, 11, 18, 1, false, "serious leg: -1 MP"},
		{4, 2, 121, 20, false, "light arm: -20% block"},
		{5, 12, 14, 1, false, "serious arm: -1 AP"},
		{6, 3, 1, -10, true, "light head: -10% XP (meta)"},
		{7, 13, 1, -20, true, "serious head: -20% XP (meta)"},
		{8, 4, 81, 5, false, "light torso: -5% resistance"},
		{9, 14, 81, 20, false, "serious torso: -20% resistance"},
		{10, 5, 77, 10, false, "light other: -10 initiative"},
		{11, 15, 9, -1, true, "serious other: -1 morale (meta)"},
	}
	for _, w := range wounds {
		c := conds.Get(w.id)
		if c == nil {
			t.Errorf("wound %d (%s) missing", w.id, w.what)
			continue
		}
		if c.Type != w.typ {
			t.Errorf("wound %d type = %d, want %d (%s)", w.id, c.Type, w.typ, w.what)
		}
		if c.Duration != DurationPermanent {
			t.Errorf("wound %d duration = %d, want -1: a wound lasts until healed", w.id, c.Duration)
		}
		if w.isMeta {
			if len(c.MetaEffects) != 1 || c.MetaEffects[0].Action != w.action ||
				len(c.MetaEffects[0].Params) != 1 || float32(c.MetaEffects[0].Params[0]) != w.param {
				t.Errorf("wound %d meta = %+v, want action %d param %v (%s)",
					w.id, c.MetaEffects, w.action, w.param, w.what)
			}
		} else {
			if len(c.FightEffects) != 1 || c.FightEffects[0].ActionID != w.action ||
				len(c.FightEffects[0].Params) != 1 || c.FightEffects[0].Params[0] != w.param {
				t.Errorf("wound %d fight = %+v, want action %d param %v (%s)",
					w.id, c.FightEffects, w.action, w.param, w.what)
			}
		}
	}

	// The light/serious split must be complete and symmetric: exactly one wound
	// per body part per severity, and serious == light + 10. The roller relies on
	// that offset to upgrade a wound in place.
	for lightType := int16(condTypeLightFirst); lightType <= condTypeLightLast; lightType++ {
		light := conds.OfType(lightType)
		serious := conds.OfType(SeriousTypeOf(lightType))
		if len(light) != 1 || len(serious) != 1 {
			t.Errorf("body part %d has %d light and %d serious wounds, want 1 and 1",
				lightType, len(light), len(serious))
			continue
		}
		if !light[0].IsLightWound() || light[0].IsSeriousWound() {
			t.Errorf("condition %d misclassified as light", light[0].ID)
		}
		if !serious[0].IsSeriousWound() || serious[0].IsLightWound() {
			t.Errorf("condition %d misclassified as serious", serious[0].ID)
		}
	}

	// Every in-fight row is a FIGHTER_CONDITION that lasts the whole fight. If
	// this ever fails, conditions have started behaving like timed spell buffs.
	for _, id := range conds.IDs() {
		for _, ef := range conds.Get(id).FightEffects {
			if ef.ContainerType != "FIGHTER_CONDITION" {
				t.Errorf("condition %d effect container = %q, want FIGHTER_CONDITION", id, ef.ContainerType)
			}
		}
	}
}
