package game

import (
	"testing"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// TestStateTargetConditionsAreEvaluated covers the client's SECOND target
// evaluator (aLc.java:89-131), whose whole bit bank used to be unrepresentable.
//
// SECURITY: an unrepresentable bit makes spellTargetMaskAllows hit its escape
// hatch and skip the ENTIRE mask, so a spell whose mask used any of these was
// cast with no target validation at all. Harmless while no shipped spell relies
// on them, dangerous the moment one does.
func TestStateTargetConditionsAreEvaluated(t *testing.T) {
	newFighter := func() *FightFighter {
		return &FightFighter{HP: 50, MaxHP: 100, AP: 6, MP: 3, TeamID: 1}
	}

	cases := []struct {
		name   string
		cond   int64
		set    func(caster, target *FightFighter)
		reject bool
	}{
		{"intransposable target", condTargetIntransposable,
			func(c, tg *FightFighter) { tg.addState(stateIntransposable, 2) }, true},
		{"intransposable CASTER (bit 49 reads both)", condTargetIntransposable,
			func(c, tg *FightFighter) { c.addState(stateIntransposable, 2) }, true},
		{"stabilized", condTargetStabilized,
			func(c, tg *FightFighter) { tg.addState(stateStabilized, 2) }, true},
		{"anchored", condTargetAnchored,
			func(c, tg *FightFighter) { tg.addState(stateAnchored, 2) }, true},
		{"at full HP", condTargetAtFullHP,
			func(c, tg *FightFighter) { tg.HP = tg.MaxHP }, true},
		{"below full HP is fine", condTargetAtFullHP,
			func(c, tg *FightFighter) { tg.HP = tg.MaxHP - 1 }, false},
		{"no AP", condTargetNoAP,
			func(c, tg *FightFighter) { tg.AP = 0 }, true},
		{"has AP is fine", condTargetNoAP, func(c, tg *FightFighter) {}, false},
		{"no MP", condTargetNoMP,
			func(c, tg *FightFighter) { tg.MP = 0 }, true},
		{"rooted", condTargetRooted,
			func(c, tg *FightFighter) { tg.addState(stateRooted, 2) }, true},
		{"petrified", condTargetPetrified,
			func(c, tg *FightFighter) { tg.addState(statePetrified, 2) }, true},
		{"state absent means no rejection", condTargetPetrified,
			func(c, tg *FightFighter) {}, false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			caster, target := newFighter(), newFighter()
			tc.set(caster, target)
			if got := stateConditionRejects(caster, target, tc.cond); got != tc.reject {
				t.Errorf("stateConditionRejects = %v, want %v", got, tc.reject)
			}
		})
	}
}

// TestStateBitsAreInsideTheEvaluableSet is the point of the change: these bits
// must no longer trip the escape hatch that skipped the whole mask.
func TestStateBitsAreInsideTheEvaluableSet(t *testing.T) {
	for _, bit := range []int64{
		condTargetIntransposable, condTargetStabilized, condTargetAnchored,
		condTargetAtFullHP, condTargetNoAP, condTargetNoMP,
		condTargetRooted, condTargetPetrified,
	} {
		if bit&^evaluableTargetBits != 0 {
			t.Errorf("bit %#x is still outside evaluableTargetBits, so a mask using "+
				"it skips ALL target validation", bit)
		}
	}
	// S19: 55 and 58-61 are decided too; only 62 (a ground area) and 63 stay out.
	for bit := 49; bit <= 61; bit++ {
		if int64(1)<<bit&^evaluableTargetBits != 0 {
			t.Errorf("bit %d is outside evaluableTargetBits", bit)
		}
	}
	for _, bit := range []int{62, 63} {
		if int64(1)<<bit&^evaluableTargetBits == 0 {
			t.Errorf("bit %d is claimed evaluable but nothing evaluates it", bit)
		}
	}
}

// Bit 55: a fighter under a damage redirect (139) is rejected; and the 139
// effect is what sets it.
func TestRedirectedTargetBit(t *testing.T) {
	f, caster, enemy := trapTestFight()
	f.resolveEffect(caster, gamedata.Effect{ActionID: actionDamageRedirect, Duration: []int32{2, 0}}, enemy.Pos)
	if !enemy.hasState(stateRedirected) {
		t.Fatal("139 left no redirect state")
	}
	if !stateConditionRejects(caster, enemy, condTargetRedirected) {
		t.Error("a redirected target passed bit 55")
	}
	if stateConditionRejects(caster, caster, condTargetRedirected) {
		t.Error("a fighter with no redirect failed bit 55")
	}
}

// Bits 58-61, ig_1.a: rejected when the target's resistance beats the
// caster's damage by more than 60 in that element, all-element stats included.
func TestElementalResistBits(t *testing.T) {
	caster := &FightFighter{}
	target := &FightFighter{}
	target.Stats.resPct[elemFire] = 50
	target.Stats.resPctAll = 20 // fire: 70 against 0
	if !stateConditionRejects(caster, target, condTargetResistsFire) {
		t.Error("fire 70 vs 0 passed bit 61")
	}
	if stateConditionRejects(caster, target, condTargetResistsWater) {
		t.Error("water 20 vs 0 failed bit 60")
	}
	caster.Stats.dmgPctAll = 15 // 15 - 70 = -55: no longer below -60
	if stateConditionRejects(caster, target, condTargetResistsFire) {
		t.Error("fire edge -55 failed bit 61")
	}
	target.Stats.resPct[elemEarth] = 2000 // clamped to 1000 before the difference
	if elementalEdge(caster, target, elemEarth) != 15-1000 {
		t.Errorf("earth edge = %d, want %d", elementalEdge(caster, target, elemEarth), 15-1000)
	}
	// The AP / MP halves: a target fully resistant to the loss is rejected too.
	full := &FightFighter{AP: 6, MP: 3}
	full.Stats.resAPLoss = 100
	if !stateConditionRejects(nil, full, condTargetNoAP) || stateConditionRejects(nil, full, condTargetNoMP) {
		t.Error("AP-loss resist 100 should reject bit 53 and only bit 53")
	}
}

// TestStateConditionIgnoresUnsetBits guards against over-rejection: a condition
// that sets none of these bits must never be refused by this bank.
func TestStateConditionIgnoresUnsetBits(t *testing.T) {
	target := &FightFighter{HP: 100, MaxHP: 100, AP: 0, MP: 0}
	target.addState(statePetrified, 2)
	target.addState(stateRooted, 2)
	if stateConditionRejects(nil, target, condIsEnemy) {
		t.Error("a condition with no state bits rejected a target that happens to " +
			"be petrified, rooted, at full HP and out of AP/MP")
	}
	if stateConditionRejects(nil, nil, condTargetPetrified) {
		t.Error("a nil target must not be rejected by the state bank")
	}
}
