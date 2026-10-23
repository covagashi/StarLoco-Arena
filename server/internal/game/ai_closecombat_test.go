package game

import (
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// aiMeleeFight builds a fight with the two fighters ALREADY adjacent, so the
// close-combat path is reachable without relying on pathfinding.
func aiMeleeFight(t *testing.T) (*Fight, *FightFighter, *FightFighter) {
	t.Helper()
	f, caster, enemy := summonTestFight()
	caster.Pos = Pos{X: 11, Y: 15} // adjacent to the (12,15) enemy
	caster.Fighter = &domain.Fighter{BreedID: 8}
	enemy.Fighter = &domain.Fighter{BreedID: 8}
	f.deps.Spells = gamedata.NewSpells()
	f.deps.Fights = NewFightManager()
	f.deps.Log = testLogger()
	return f, caster, enemy
}

// TestBlockerAIAttacksInsteadOfIdling is the behaviour this adds. A fighter with
// no castable spell used to walk adjacent and then do NOTHING for the rest of
// the fight — which is also what happens to any fighter with an empty loadout.
func TestBlockerAIAttacksInsteadOfIdling(t *testing.T) {
	f, caster, enemy := aiMeleeFight(t)
	caster.SummonSpellID = 0 // blocker
	caster.AP, caster.MaxAP = 6, 6
	enemy.HP, enemy.MaxHP = 200, 200

	if got := f.classifyAI(caster); got != behaviorBlocker {
		t.Fatalf("classifyAI = %d, want blocker", got)
	}
	// Drive the REAL entry point, not closeCombatAI directly — otherwise this
	// passes even when the archetype never calls it, which is the whole point.
	f.Timeline = []*FightFighter{caster, enemy}
	f.turnIndex = 0
	caster.MP, caster.MaxMP = 0, 0 // already adjacent; don't let it wander off
	f.runAITurn(caster)

	if caster.AP != 6-closeCombatAP {
		t.Errorf("AP = %d, want %d (one weapon attack at %d AP)",
			caster.AP, 6-closeCombatAP, closeCombatAP)
	}
	if enemy.HP >= 200 {
		t.Errorf("enemy HP = %d, want < 200 (the blocker never attacked)", enemy.HP)
	}
}

// TestCloseCombatAINeedsAdjacencyAndAP pins the two guards, so the AI cannot
// flail at nothing or spin when a strike is refused.
func TestCloseCombatAINeedsAdjacencyAndAP(t *testing.T) {
	// Not adjacent: no attack, no AP spent.
	f, caster, enemy := aiMeleeFight(t)
	caster.Pos = Pos{X: 7, Y: 15} // 5 cells away
	caster.AP = 6
	enemy.HP, enemy.MaxHP = 200, 200
	f.closeCombatAI(caster)
	if caster.AP != 6 || enemy.HP != 200 {
		t.Errorf("attacked at range: AP %d, enemy HP %d", caster.AP, enemy.HP)
	}

	// Adjacent but under the AP floor: no attack.
	f2, c2, e2 := aiMeleeFight(t)
	c2.AP = closeCombatAP - 1
	e2.HP, e2.MaxHP = 200, 200
	f2.closeCombatAI(c2)
	if c2.AP != closeCombatAP-1 || e2.HP != 200 {
		t.Errorf("attacked below the AP floor: AP %d, enemy HP %d", c2.AP, e2.HP)
	}

	// A dead enemy is not a target.
	f3, c3, e3 := aiMeleeFight(t)
	c3.AP = 6
	e3.HP = 0
	f3.closeCombatAI(c3)
	if c3.AP != 6 {
		t.Errorf("attacked a corpse: AP %d, want 6", c3.AP)
	}
}

// TestKiteAIDoesNotMeleeGuards the one archetype deliberately excluded: kiting
// exists to break contact, so trading blows would undo the retreat.
func TestKiteAIDoesNotMelee(t *testing.T) {
	// 1 AP and capped at one cast per turn, so the kite still has 5 AP left —
	// enough for a weapon attack. Without that headroom this test would pass
	// even if kiting DID melee, because casting would have drained the AP.
	sp := &gamedata.Spell{ // a debuff -> kite
		ID: 500, AP: 1, RangeMin: 1, RangeMax: 6, CastMaxPerTurn: 1,
		Effects: []gamedata.Effect{{ActionID: 16, EffectID: 5000, Params: []float32{2}}},
	}
	f, caster, enemy := aiMeleeFight(t)
	f.deps.Spells = gamedata.NewSpells(sp)
	caster.SummonSpellID = 500
	caster.AP, caster.MaxAP = 6, 6
	caster.MP, caster.MaxMP = 0, 0 // pinned, so it cannot retreat away either
	enemy.HP, enemy.MaxHP = 200, 200

	if got := f.classifyAI(caster); got != behaviorKite {
		t.Fatalf("classifyAI = %d, want kite", got)
	}
	f.Timeline = []*FightFighter{caster, enemy}
	f.turnIndex = 0
	before := enemy.HP
	f.runAITurn(caster)

	// It may have cast the debuff, but must not have swung a weapon: close combat
	// is the only thing here that removes HP.
	if enemy.HP != before {
		t.Errorf("kite archetype dealt melee damage (%d -> %d)", before, enemy.HP)
	}
	// Guard the guard, checked AFTER the real assertion so a genuine melee is
	// reported as such: if casting had drained the AP there would be nothing to
	// melee WITH, and this test would pass regardless of the archetype rule.
	if caster.AP < closeCombatAP {
		t.Errorf("AP left = %d (< %d): this test could not have detected a melee",
			caster.AP, closeCombatAP)
	}
}

// TestPlayerFighterAICastsItsLoadout: a player's fighter has no SummonSpellID,
// so an AI-played one (its coach left, or /AUTOPILOT) used to classify as a
// blocker and only ever punch, whatever it had equipped. It now reads its
// signature off its loadout — the first spell that harms an enemy — and casts.
func TestPlayerFighterAICastsItsLoadout(t *testing.T) {
	heal := &gamedata.Spell{ID: 601, AP: 2, RangeMin: 0, RangeMax: 0,
		Effects: []gamedata.Effect{{ActionID: 108, EffectID: 6010, Params: []float32{10, 10}}}}
	hit := &gamedata.Spell{ID: 602, AP: 3, RangeMin: 1, RangeMax: 6, CastMaxPerTurn: 1,
		Effects: []gamedata.Effect{{ActionID: 5, EffectID: 6020, Params: []float32{30, 30}}}}
	f, caster, enemy := aiMeleeFight(t)
	f.deps.Spells = gamedata.NewSpells(heal, hit)
	caster.SummonSpellID = 0
	caster.Fighter.Spells = []domain.FighterSpell{{SpellID: 601}, {SpellID: 602}}
	caster.AP, caster.MaxAP = 6, 6
	caster.MP, caster.MaxMP = 0, 0
	enemy.HP, enemy.MaxHP = 500, 500

	if got := f.loadoutSignature(caster); got != 602 {
		t.Fatalf("loadoutSignature = %d, want 602 (the heal is skipped)", got)
	}
	if got := f.classifyAI(caster); got != behaviorAggressive {
		t.Fatalf("classifyAI = %d, want aggressive", got)
	}
	f.Timeline = []*FightFighter{caster, enemy}
	f.turnIndex = 0
	f.runAITurn(caster)
	if caster.AP > 6-3 {
		t.Errorf("AP = %d: the loadout spell (3 AP) was never cast", caster.AP)
	}
	if enemy.HP >= 500 {
		t.Errorf("enemy HP = %d, want < 500", enemy.HP)
	}

	// No harmful spell at all: still a blocker, as before.
	caster.Fighter.Spells = []domain.FighterSpell{{SpellID: 601}}
	if got := f.classifyAI(caster); got != behaviorBlocker {
		t.Errorf("heal-only loadout: classifyAI = %d, want blocker", got)
	}
}
