package game

import (
	"testing"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// S46: the AI plays its weapon's attack. Before, an AI fighter only ever
// punched (closeCombatAI), so a weapon counted for nothing but its passive
// bonuses and the card balance simulations could not measure weapons.

// A blocker (no damage spell) with a weapon in range attacks with it.
func TestAIBlockerUsesItsWeapon(t *testing.T) {
	f, attacker, enemy := cardUseFight(weaponCard(85, 4, 1, 3))
	f.deps.Spells = gamedata.NewSpells()
	f.deps.Log = testLogger()
	attacker.MP, attacker.MaxMP = 0, 0 // stay put: the enemy is 2 cells away, in range
	f.runAITurn(attacker)
	if enemy.HP >= 70 {
		t.Errorf("enemy HP = %d: the blocker never used its weapon", enemy.HP)
	}
	if attacker.AP != 2 {
		t.Errorf("AP = %d, want 2 (one weapon attack at 4 AP)", attacker.AP)
	}
}

// Out of the weapon's range, nothing is played and no AP is spent.
func TestAIWeaponNeedsRange(t *testing.T) {
	f, attacker, enemy := cardUseFight(weaponCard(85, 4, 1, 1))
	f.deps.Spells = gamedata.NewSpells()
	f.deps.Log = testLogger()
	if id, _, _ := f.bestWeaponAgainst(attacker, enemy); id != 0 {
		t.Errorf("a melee weapon was offered against an enemy 2 cells away (card %d)", id)
	}
}

// Against a spell, the weapon is chosen only when it is worth more per AP;
// on a tie the spell keeps the turn.
func TestAIWeaponVersusSpell(t *testing.T) {
	f, attacker, enemy := cardUseFight(weaponCard(85, 4, 1, 3))
	f.deps.Log = testLogger()
	sp := &gamedata.Spell{ID: 7, AP: 2, RangeMin: 1, RangeMax: 3, Effects: []gamedata.Effect{
		{ActionID: 5, AreaShape: 1, Params: []float32{10}}}}
	f.deps.Spells = gamedata.NewSpells(sp)
	enemy.HP, enemy.MaxHP = 500, 500
	// spell: 10 for 2 AP beats the weapon's 10 for 4
	if got := f.aiWeaponOverSpell(attacker, enemy, 7); got != 0 {
		t.Errorf("weapon %d chosen over a spell worth twice as much per AP", got)
	}
	// a weapon worth more per AP wins
	strong := weaponCard(86, 2, 1, 3)
	strong.UseEffects[0].Params = []float32{40}
	f.deps.FighterCards = gamedata.NewFighterCards(strong)
	attacker.Fighter.Objects[0].TemplateID = 86
	if got := f.aiWeaponOverSpell(attacker, enemy, 7); got != 86 {
		t.Errorf("weapon = %d, want 86 (40 for 2 AP beats the spell's 10)", got)
	}
}

// A point effect keeps to its own target conditions (S46). Weapon 34 carries
// one damage effect per target breed (enemy + "breed is k+1"): only the
// matching one may land. With no filter on a point all fourteen did, 112
// damage instead of 8, which the AI found as soon as it played weapons.
func TestPointEffectHonoursItsTargetBreed(t *testing.T) {
	enemyOfBreed := func(br int64) int64 { return condIsEnemy | 1<<(16+br-1) }
	card := &gamedata.FighterCard{ID: 34, Type: 1, APCost: 5, RangeMin: 1, RangeMax: 5,
		UseEffects: []gamedata.Effect{
			{ActionID: 5, AreaShape: 1, Params: []float32{8}, Targets: []int64{enemyOfBreed(1)}},
			{ActionID: 5, AreaShape: 1, Params: []float32{8}, Targets: []int64{enemyOfBreed(2)}},
			{ActionID: 5, AreaShape: 1, Params: []float32{8}, Targets: []int64{enemyOfBreed(9)}},
		}}
	f, attacker, enemy := cardUseFight(card) // the enemy is breed 1
	if !f.useFighterCard(attacker, 34, enemy.Pos) {
		t.Fatal("weapon use refused")
	}
	if lost := 70 - enemy.HP; lost <= 0 || lost > 12 {
		t.Errorf("the breed-1 enemy lost %d HP, want one 8-damage hit (not one per breed)", lost)
	}
}

// An effect only the caster may take, riding on an attack aimed at an enemy,
// lands on the caster (spells 30 and 443), not on the enemy hit.
func TestCasterOnlyPointEffectGoesToTheCaster(t *testing.T) {
	f, attacker, enemy := cardUseFight()
	ef := gamedata.Effect{ActionID: 5, AreaShape: 1, Params: []float32{1}, Targets: []int64{condIsCaster}}
	got := f.areaFightersFrom(attacker, attacker.Pos, ef, enemy.Pos)
	if len(got) != 1 || got[0] != attacker {
		t.Errorf("caster-only effect aimed at the enemy reached %v, want the caster", got)
	}
	// and an enemy-only effect aimed at an ally reaches nobody
	ef.Targets = []int64{condIsEnemy}
	if got := f.areaFightersFrom(attacker, attacker.Pos, ef, attacker.Pos); len(got) != 0 {
		t.Errorf("an enemy-only effect aimed at the caster's own cell reached %d fighters", len(got))
	}
}
