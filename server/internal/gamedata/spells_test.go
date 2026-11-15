package gamedata

import "testing"

// spellEffect is one SPELL effect for a test spell.
func spellEffect(effectID, actionID int32, params ...float32) Effect {
	return Effect{EffectID: effectID, ActionID: actionID, ContainerType: "SPELL", Params: params}
}

func TestSpellDamage(t *testing.T) {
	// Fire spell: 25 fire damage (action 131 = "…par sort" fire) + an AP-loss
	// rider (16) which must NOT count as damage.
	sp := &Spell{ID: 4, BreedID: 8, Value: 200, AP: 3, RangeMin: 1, RangeMax: 5,
		Effects: []Effect{spellEffect(9001, 131, 25), spellEffect(9002, 16, 1)}}
	amount, elem, ok := sp.Damage()
	if !ok || amount != 25 || elem != ElementFire {
		t.Errorf("Damage() = %d elem=%d ok=%v, want 25/fire", amount, elem, ok)
	}
	if sp.IsHeal() {
		t.Error("fire spell wrongly flagged as heal")
	}
}

func TestSpellDamageDirectAndLeech(t *testing.T) {
	// Two direct-damage effects (neutral loss id 1 + water leech id 9) sum.
	sp := &Spell{ID: 50, Effects: []Effect{spellEffect(1, 1, 10), spellEffect(2, 9, 7)}}
	if amount, _, ok := sp.Damage(); !ok || amount != 17 {
		t.Errorf("Damage() = %d ok=%v, want 17 (10 loss + 7 leech)", amount, ok)
	}
}

func TestSpellUtilityAndHeal(t *testing.T) {
	// Utility spell: only a DMG% buff (action 82) — deals no flat damage.
	util := &Spell{ID: 99, Effects: []Effect{spellEffect(1, 82, 15)}}
	if _, _, ok := util.Damage(); ok {
		t.Error("utility spell should deal 0 flat damage")
	}
	if util.IsHeal() {
		t.Error("buff spell wrongly flagged as heal")
	}
	heal := &Spell{ID: 100, Effects: []Effect{spellEffect(1, actionHeal, 20)}}
	if !heal.IsHeal() {
		t.Error("heal spell not detected")
	}
	if _, _, ok := heal.Damage(); ok {
		t.Error("heal spell should deal 0 flat damage")
	}
}
