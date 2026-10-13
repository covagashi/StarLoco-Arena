package game

import (
	"fmt"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// fightercard_use.go resolves a fighter playing its equipment's ACTIVE ability
// (FIGHTER_CARD_USE, opcode 8107) — in the shipped data this is the weapon
// attack: 23 of the 75 fighter cards carry use-effects, and they are elemental
// damage with a normal and a critical variant, an AP cost and a range band.
//
// It deliberately mirrors castSpellByFighter (the client treats the two the same
// way — 8108 and 8110 share a layout) so both paths debit AP, roll fumble/crit,
// broadcast, resolve and flush identically.
//
// Provenance: 8107 is sent by the client's abt_1 targeting mode, which carries a
// `ve_0` — fighter EQUIPMENT (its icon path is `fighterEquipmentIconsPath`), not a
// coach card. Its effects are ordinary `xj_0` effects, the same structure spells
// use, which is why the existing effect resolver handles them unchanged. (The
// long-standing note that card effects needed a separate action enum, `AI`, was a
// misreading: `AI` is the COACH-card meta enum — XP, wounds, morale, fatigue,
// drops — and has nothing to do with in-fight equipment.)

// useFighterCard plays `cardID`'s active ability from `user` at `target`.
// Returns whether the play actually fired. Must run on the fight goroutine.
func (f *Fight) useFighterCard(user *FightFighter, cardID int32, target Pos) bool {
	if user == nil || !f.isCurrentTurn(user.WireID) {
		return false
	}
	if !fighterHasEquipped(user, cardID) {
		f.logCardUse("refused: not equipped on this fighter", user, cardID)
		return false
	}
	if f.deps == nil || f.deps.FighterCards == nil {
		return false
	}
	card := f.deps.FighterCards.Get(cardID)
	if !card.Usable() {
		// Equipment with no FIGHTER_CARD_USE effects is passive-only; the client
		// does not offer it as an action (jb_2.isUsable), so this is a forged play.
		f.logCardUse("refused: card has no active ability", user, cardID)
		return false
	}
	if user.CarriedByFighter != nil && !card.UsableWhenCarried {
		f.logCardUse("refused: not usable while carried", user, cardID)
		return false
	}
	if !f.cardTargetValid(user, card, target) {
		f.logCardUse("refused: illegal target", user, cardID)
		return false
	}
	if user.effectiveAP() < card.APCost {
		f.logCardUse("refused: not enough AP", user, cardID)
		return false
	}

	// Roll fumble, then crit (a fumble precludes a crit). A fumble spends the AP
	// but applies no effects; a crit runs the card's IsCritical effect subset —
	// every shipped weapon ships both variants.
	fumble := user.rollFumble(f.rngSource())
	crit := !fumble && user.rollCrit(f.rngSource())

	msg, err := buildFighterCardUse(f.nextActionUID(), user.WireID, cardID, target, fumble, crit)
	if err != nil {
		return false
	}
	f.broadcast(msg)

	user.AP -= card.APCost
	ap, _ := buildRunningEffect(f.nextActionUID(), protocol.RunEffectAPUse, 0,
		0, user.WireID, user.Pos, card.APCost, 0, true)
	f.broadcast(ap)

	if !fumble {
		var ouchBefore map[int64]int32
		if crit {
			ouchBefore = f.hpSnapshot()
		}
		for _, ef := range selectEffectsForCrit(card.UseEffects, crit) {
			f.resolveEffect(user, ef, target)
		}
		if crit {
			f.broadcastOuchForDamaged(ouchBefore)
		}
	}

	seq, _ := buildActionSequenceExecute()
	f.broadcast(seq)

	f.logAction(user, decisionCard, fmt.Sprintf("card=%d target=(%d,%d) fumble=%v crit=%v ap=%d",
		cardID, target.X, target.Y, fumble, crit, card.APCost))

	if f.deps != nil {
		f.deps.checkFightEnd(f)
	}
	return true
}

// cardTargetValid mirrors the client's own equipment-targeting validator
// (mv_1.a(gn_0, jb_2, ry)): a real undestroyed arena cell, Manhattan distance
// inside the card's range band (max extended by the fighter's Range stat only when
// the base max is > 1, so a melee weapon never reaches), plus the record's three
// targeting flags — straight line only, line of sight, and free cell.
func (f *Fight) cardTargetValid(user *FightFighter, card *gamedata.FighterCard, target Pos) bool {
	if !f.Arena().walkable(target.X, target.Y) || f.cellDestroyed(target.X, target.Y) {
		return false
	}
	maxRange := card.RangeMax
	if maxRange > 1 {
		maxRange += user.Range
		if maxRange < card.RangeMin {
			maxRange = card.RangeMin
		}
	}
	if dist := manhattanDist(user.Pos, target); dist < card.RangeMin || dist > maxRange {
		return false
	}
	if card.OnlyLine && target.X != user.Pos.X && target.Y != user.Pos.Y {
		return false
	}
	if card.NeedFreeCell && f.cellOccupied(target) {
		return false
	}
	if card.TestLoS && !f.Arena().hasLineOfSight(user.Pos, target) {
		return false
	}
	return true
}

func (f *Fight) logCardUse(why string, user *FightFighter, cardID int32) {
	if f.deps == nil || f.deps.Log == nil {
		return
	}
	f.deps.Log.Debug("fighter card use "+why, "wireID", user.WireID, "card", cardID)
}
