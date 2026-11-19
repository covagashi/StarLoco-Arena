package game

import (
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// S46: the AI calls its creature onto the free cell nearest the enemy, once
// (the cap), and only with the AP for it.
func TestAISummonCast(t *testing.T) {
	f, caster, _ := summonTestFight(&gamedata.Summoning{ID: 1, HP: 20, AP: 6, MP: 3})
	summon := &gamedata.Spell{ID: 900, AP: 3, RangeMin: 1, RangeMax: 1,
		Effects: []gamedata.Effect{{EffectID: 500, ActionID: 67, Params: []float32{1}, Targets: []int64{1}}}}
	f.deps.Spells = gamedata.NewSpells(summon)
	caster.Fighter = &domain.Fighter{Spells: []domain.FighterSpell{{SpellID: 900}}}

	caster.AP = 2
	if f.aiSummonCast(caster) {
		t.Fatal("summoned with 2 AP for a 3 AP spell")
	}
	caster.AP = 6
	if !f.aiSummonCast(caster) {
		t.Fatal("did not summon")
	}
	if n := len(f.Teams[0].Fighters); n != 2 {
		t.Fatalf("team 0 has %d fighters, want the caster and its creature", n)
	}
	if p := f.Teams[0].Fighters[1].Pos; p.X != 8 || p.Y != 15 {
		t.Errorf("creature at (%d,%d), want (8,15), the free cell toward the enemy", p.X, p.Y)
	}
	if caster.AP != 3 {
		t.Errorf("caster AP = %d, want 3 after a 3 AP summon", caster.AP)
	}
	if f.aiSummonCast(caster) {
		t.Error("summoned a second creature past the cap")
	}
	f.Teams[0].Fighters[1].AP = 6
	if f.aiSummonCast(f.Teams[0].Fighters[1]) {
		t.Error("a creature summoned")
	}
}
