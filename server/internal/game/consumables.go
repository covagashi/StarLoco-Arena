package game

// consumables.go — using a consumable coach card ON a living fighter
// (FIGHTER_USE_ITEM 22099, the "drop a card onto a fighter" gesture).
//
// This is the maintenance half of the META layer: 325 of the 907 coach cards are
// marked usable, and they are how a coach repairs a roster between fights —
// healing wounds, clearing fatigue, lifting morale, granting a blessing.
// Resurrection (AI 13) is handled separately in handlers_evolution.go because it
// is the only one that acts on a DEAD fighter.
//
// Each action's behaviour is transcribed from the client class that implements
// it. Note that every one of these classes has TWO methods: the passive
// `a(et_2)` path, which only annotates the post-fight report, and the consumable
// path, which mutates the fighter for real. We implement the latter here.

import (
	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// aiApplyCondition is AI 15, "Applique une condition" — by a wide margin the most
// common consumable action (165 of the 325 usable cards). Params are
// [conditionId, durationInFights].
const aiApplyCondition int32 = 15

// consumableActions are the AI actions a card may carry that act on a LIVING
// fighter. Ordered as applied.
var consumableActions = []int32{
	aiCancelWound,    // 11 — heal light wounds   (client aic_1.c)
	aiWound,          // 5  — heal serious wounds (client ze_1.c)
	aiTiredness,      // 16 — change fatigue      (client cm_1.c)
	aiMorale,         // 9  — change morale       (client cc_1.e)
	aiXPFlat,         // 2  — grant permanent XP  (client adl_2.c)
	aiApplyCondition, // 15 — apply a condition   (client vm_2.c)
}

// useConsumableOnFighter applies a usable card's effects to a living fighter.
//
// The card is consumed only when it actually DID something — unlike the
// resurrection gamble, where the card is spent on a failed roll because the roll
// itself is the point. Here a card that changes nothing (a healing potion on an
// unwounded fighter) is refused and kept, which is both kinder and what stops a
// mis-drop from destroying an expensive card.
func (s *Session) useConsumableOnFighter(fighter *domain.Fighter, cardID int32) error {
	if s.deps.Cards == nil {
		return nil // no catalogue (dev without data files): nothing to apply
	}
	card := s.deps.Cards.Get(cardID)
	if card == nil || !card.HasUsableAction {
		s.log.Debug("use item: card is not consumable", "coach", s.Coach.Name, "card", cardID)
		return nil
	}

	// Work on a copy of the mutable fields so a refused application leaves the
	// fighter untouched.
	changed := false
	// Reuse the resurrection RNG: it is the same "did this card work" gamble and
	// tests already have a seed hook for it (SeedResurrectRand).
	roll := func(n int) int { return resurrectRand.Intn(n) }

	for _, action := range consumableActions {
		param, ok := card.EffectParam(action)
		if !ok {
			continue
		}
		switch action {
		case aiCancelWound: // heal LIGHT wounds, per-wound roll at param%
			if n := healWounds(s.deps.Conditions, fighter, false, param, roll); n > 0 {
				changed = true
			}
		case aiWound: // heal SERIOUS wounds, per-wound roll at param%
			if n := healWounds(s.deps.Conditions, fighter, true, param, roll); n > 0 {
				changed = true
			}
		case aiTiredness: // cm_1.c: T(clamp(fatigue + param, 0, 100))
			next := uint8(clampInt32(int32(fighter.Tiredness)+param, 0, maxTiredness))
			if next != fighter.Tiredness {
				fighter.Tiredness = next
				changed = true
			}
		case aiMorale: // cc_1.e: U(clamp(morale + param, 0, 100))
			next := uint8(clampInt32(int32(fighter.Morale)+param, 0, maxMorale))
			if next != fighter.Morale {
				fighter.Morale = next
				changed = true
			}
		case aiXPFlat: // adl_2.c: et_2.ft(param) — permanent XP, capped
			if param > 0 && fighter.XP < maxSpendableXP {
				fighter.XP += param
				fighter.TotalXP += param
				changed = true
			}
		case aiApplyCondition: // vm_2.c: apply {conditionId, duration}
			// The consumable path does NOT add the +1 the passive path adds —
			// that +1 exists so an equipped card's condition survives the fight
			// it was applied in, which does not apply to a card used out of
			// combat.
			id, dur := conditionParams(card, action)
			if id != 0 && applyCondition(s.deps.Conditions, fighter, id, dur) {
				changed = true
			}
		}
	}

	if !changed {
		s.log.Debug("use item: card would change nothing; not consumed",
			"coach", s.Coach.Name, "card", cardID, "fighter", fighter.ID)
		return nil
	}
	if !s.consumeCard(cardID) {
		s.log.Debug("use item: card not owned", "coach", s.Coach.Name, "card", cardID)
		return nil
	}
	if fighter.Evolution {
		s.noteStat(statEvoConsumables, 1, false)
	}
	if s.deps.Store != nil {
		_ = s.deps.Store.Fighters.SaveProgress(fighter)
		_ = s.deps.Store.Fighters.SaveConditions(fighter.ID, fighter.Conditions)
	}
	s.refreshAndPushInventory()
	s.log.Info("consumable used", "coach", s.Coach.Name, "card", cardID,
		"fighter", fighter.Name, "conditions", len(fighter.Conditions),
		"fatigue", fighter.Tiredness, "morale", fighter.Morale)
	return s.pushFighterList()
}

// conditionParams pulls the [conditionId, duration] pair out of an AI-15 effect.
// EffectParam only exposes params[0] (it sums magnitudes), so the pair is read
// directly here.
func conditionParams(card *gamedata.CoachCard, action int32) (id int16, duration int8) {
	for _, ef := range card.Effects {
		if ef.Action != action || len(ef.Params) < 2 {
			continue
		}
		return int16(ef.Params[0]), int8(ef.Params[1])
	}
	return 0, 0
}
