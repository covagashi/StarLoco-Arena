package game

import (
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
)

// turnChoiceFight is 3 against 3: side 0 Iop/Cra/Feca (init 10+75+20 = 105),
// side 1 Xelor/Eniripsa/Sadida (80+0+30 = 110), so side 1 chooses.
func turnChoiceFight() *Fight {
	mk := func(coachID uint, side uint8, breeds ...uint8) *FightTeam {
		t := &FightTeam{ID: side, Members: []*FightMember{{Coach: &domain.Coach{ID: coachID}}}}
		for i, b := range breeds {
			t.Fighters = append(t.Fighters, &FightFighter{
				WireID: FighterWireIDBase + int64(coachID)*16 + int64(i), CoachID: coachID,
				TeamID: side, Fighter: &domain.Fighter{BreedID: b}, HP: 60, MaxHP: 60,
				MaxAP: 6, MaxMP: 3,
			})
		}
		return t
	}
	f := &Fight{Teams: [2]*FightTeam{mk(1, 0, 8, 9, 1), mk(2, 1, 5, 7, 10)}}
	f.Timeline = buildTimeline(f)
	return f
}

func breedsOf(tl []*FightFighter) []uint8 {
	var out []uint8
	for _, ff := range tl {
		out = append(out, ff.Fighter.BreedID)
	}
	return out
}

func TestTurnOrderAlternatesSides(t *testing.T) {
	f := turnChoiceFight()
	if f.chooser != 1 || f.opener != 1 {
		t.Fatalf("chooser %d opener %d, want side 1 (110 > 105) opening by default", f.chooser, f.opener)
	}
	// each side by its own initiative, the sides alternating
	want := []uint8{5, 9, 10, 1, 7, 8}
	if got := breedsOf(f.Timeline); string(got) != string(want) {
		t.Errorf("opening order = %v, want %v", got, want)
	}
	f.setOpener(0)
	want = []uint8{9, 5, 1, 10, 8, 7}
	if got := breedsOf(f.Timeline); string(got) != string(want) {
		t.Errorf("ceded order = %v, want %v", got, want)
	}
}

func TestTurnOrderUnevenSides(t *testing.T) {
	f := turnChoiceFight()
	f.Teams[1].Fighters = f.Teams[1].Fighters[:1] // Xelor alone
	f.Timeline = buildTimeline(f)
	// 105 against 80: side 0 chooses and opens; its leftovers go last
	if f.chooser != 0 {
		t.Fatalf("chooser = %d, want 0", f.chooser)
	}
	want := []uint8{9, 5, 1, 8}
	if got := breedsOf(f.Timeline); string(got) != string(want) {
		t.Errorf("order = %v, want %v", got, want)
	}
}

func TestTurnChoiceTie(t *testing.T) {
	f := turnChoiceFight()
	f.Teams[1].Fighters = nil
	for _, ff := range f.Teams[0].Fighters {
		c := *ff
		c.TeamID = 1
		c.WireID += 100
		f.Teams[1].Fighters = append(f.Teams[1].Fighters, &c)
	}
	f.Timeline = buildTimeline(f)
	if f.chooser != 0 {
		t.Errorf("a mirror's chooser = %d, want side 0", f.chooser)
	}
}

func TestApplyTurnChoice(t *testing.T) {
	f := turnChoiceFight()
	f.setPhase(PhasePlacement)
	if f.applyTurnChoice(1, false) {
		t.Error("the side that does not choose was allowed to")
	}
	if !f.applyTurnChoice(2, false) || f.opener != 0 || f.Timeline[0].TeamID != 0 {
		t.Errorf("ceding: opener %d, first side %d, want 0", f.opener, f.Timeline[0].TeamID)
	}
	if !f.applyTurnChoice(2, true) || f.opener != 1 {
		t.Errorf("opening again: opener %d, want 1", f.opener)
	}
	f.setPhase(PhaseAction)
	if f.applyTurnChoice(2, false) || f.opener != 1 {
		t.Error("the order changed after placement")
	}
}

func TestOpenerBonusMP(t *testing.T) {
	f := turnChoiceFight()
	f.setOpener(0)
	iop, xelor := f.Teams[0].Fighters[0], f.Teams[1].Fighters[0]
	if got := f.openerBonusMP(iop); got != openerFirstTurnMP {
		t.Errorf("opener's first turn: +%d MP, want +%d", got, openerFirstTurnMP)
	}
	if got := f.openerBonusMP(xelor); got != 0 {
		t.Errorf("the other side: +%d MP, want 0", got)
	}
	iop.turnsTaken = 1
	if got := f.openerBonusMP(iop); got != 0 {
		t.Errorf("second turn: +%d MP, want 0", got)
	}
	iop.turnsTaken = 0
	iop.Father = xelor // a summon never gets it
	if got := f.openerBonusMP(iop); got != 0 {
		t.Errorf("summon: +%d MP, want 0", got)
	}
}

func TestServerChooserCedesOutOfReach(t *testing.T) {
	f := turnChoiceFight()
	for i, ff := range f.Teams[0].Fighters {
		ff.Pos = Pos{X: int32(i), Y: 0}
	}
	for i, ff := range f.Teams[1].Fighters {
		ff.Pos = Pos{X: int32(i), Y: 40}
	}
	if f.aiOpens() {
		t.Error("opened with every enemy 40 cells away")
	}
	f.Teams[1].Fighters[0].Pos = Pos{X: 0, Y: 2} // the Xelor is next to the Iop
	if !f.aiOpens() {
		t.Error("ceded with an enemy in reach")
	}
	f.settleOpener()
	if f.opener != f.chooser {
		t.Errorf("server-driven chooser in reach: opener %d, want %d", f.opener, f.chooser)
	}
}
