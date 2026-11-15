package gamedata

import "testing"

func equipEffect(effectID, actionID int32, container string, param float32) Effect {
	return Effect{EffectID: effectID, ActionID: actionID, ContainerType: container, Params: []float32{param}}
}

// TestSumEquipBonus: the EQUIP effects fold into the passive stat bonus; a
// FIGHTER_CARD_USE (active) effect and a stat the summary does not cover do not.
func TestSumEquipBonus(t *testing.T) {
	got := sumEquipBonus([]Effect{
		equipEffect(9001, actionHPBoost, "FIGHTER_CARD_EQUIP", 40),
		equipEffect(9002, actionAPBoost, "FIGHTER_CARD_EQUIP", 1),
		equipEffect(9003, 5, "FIGHTER_CARD_USE  ", 15), // active ability: must be ignored
		equipEffect(9004, actionMPBoost, "FIGHTER_CARD_EQUIP", 2),
		equipEffect(9005, actionInitBoost, "FIGHTER_CARD_EQUIP", 60),
		equipEffect(9006, actionRangeGain, "FIGHTER_CARD_EQUIP", 2),
		equipEffect(9007, 33, "FIGHTER_CARD_EQUIP", 15), // dmg%: not covered, ignored
	})
	want := FighterStatBonus{HP: 40, AP: 1, MP: 2, Init: 60, Range: 2}
	if got != want {
		t.Errorf("bonus = %+v, want %+v", got, want)
	}
	if !sumEquipBonus(nil).IsZero() {
		t.Error("no effects should give a zero bonus")
	}
}
