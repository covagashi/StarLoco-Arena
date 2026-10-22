package game

import (
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// S10: the tutorial chain on the server — the Demon III's challenges 29/30/31
// mark criteria 198/199/200, pay their XP up to a limit and open in order;
// Baan's 46 marks 226; every recruit counts towards 211.

// winChallenge plays a won challenge fight for coachID with one real fighter.
func winTutorialChallenge(t *testing.T, d *Deps, coachID uint, fr *domain.Fighter, challengeID int32) {
	t.Helper()
	f := buildTestFight()
	f.Teams[0].Coach().ID = coachID
	f.Teams[0].Fighters[0].Fighter = fr
	f.Teams[0].Fighters[0].CoachID = coachID
	f.ChallengeID = challengeID
	f.Practice = true
	f.setPhase(PhaseAction)
	d.Fights.Create(f)
	for _, ff := range f.allFighters() {
		if ff.TeamID == 1 {
			ff.HP = 0
		}
	}
	d.checkFightEnd(f)
}

func tutorialDeps(t *testing.T) (*Deps, uint, *domain.Fighter) {
	t.Helper()
	d, coachID := challengeRewardDeps(t)
	achs, err := openRealGameData(t).LoadAchievements()
	if err != nil {
		t.Fatal(err)
	}
	d.Achievements = achs
	fr := &domain.Fighter{CoachID: coachID, BreedID: 1, Name: "Novato", State: domain.FighterStateTitular}
	if err := d.Store.Fighters.Create(fr); err != nil {
		t.Fatal(err)
	}
	return d, coachID, fr
}

func statOf(d *Deps, coachID uint, id int16) int32 { return d.Store.Coaches.StatValue(coachID, id) }

func xpOf(t *testing.T, d *Deps, id uint) int32 {
	t.Helper()
	fr, err := d.Store.Fighters.Get(id)
	if err != nil {
		t.Fatal(err)
	}
	return fr.TotalXP
}

func TestDemonIIIChainMarksItsCriteria(t *testing.T) {
	d, coachID, fr := tutorialDeps(t)
	for i, ch := range []int32{29, 30, 31} {
		winTutorialChallenge(t, d, coachID, fr, ch)
		if got := statOf(d, coachID, int16(198+i)); got != 1 {
			t.Errorf("criterion %d = %d after winning %d, want 1", 198+i, got, ch)
		}
	}
}

// TestChallengeXPStopsAtItsLimit: 29 pays 1 XP up to 1 total; 30 pays 2 up to
// 10. A second win of 29 pays nothing more.
func TestChallengeXPStopsAtItsLimit(t *testing.T) {
	d, coachID, fr := tutorialDeps(t)
	winTutorialChallenge(t, d, coachID, fr, 29)
	if got := xpOf(t, d, fr.ID); got != 1 {
		t.Fatalf("XP after 29 = %d, want 1", got)
	}
	fr, _ = d.Store.Fighters.Get(fr.ID)
	winTutorialChallenge(t, d, coachID, fr, 29)
	if got := xpOf(t, d, fr.ID); got != 1 {
		t.Errorf("XP after 29 twice = %d, want 1 (its limit)", got)
	}
	fr, _ = d.Store.Fighters.Get(fr.ID)
	winTutorialChallenge(t, d, coachID, fr, 30)
	if got := xpOf(t, d, fr.ID); got != 3 {
		t.Errorf("XP after 30 = %d, want 3", got)
	}
}

// TestDemonIIIChainOpensInOrder: 30 is refused until achievement 280
// (criterion 198), 31 until 281 (199).
func TestDemonIIIChainOpensInOrder(t *testing.T) {
	d, coachID, fr := tutorialDeps(t)
	d.Matchmaker = NewMatchmaker()
	d.Sessions = NewSessionRegistry()
	coach, _ := d.Store.Coaches.Get(coachID)
	s := tmSession(d, coachID, coach.Name)
	launch := func(ch int32) bool {
		drain(t, s)
		w := protocol.NewWriter().I32(ch).U16(challengeAcceptBreed)
		_ = handleTeamTest(s, &protocol.C2SFrame{Opcode: protocol.OpTeamTest, Payload: w.Bytes()})
		started := d.Fights.ByCoach(coachID) != nil
		if f := d.Fights.ByCoach(coachID); f != nil {
			d.Fights.Remove(f)
		}
		return started
	}
	if launch(30) {
		t.Error("challenge 30 started without achievement 280")
	}
	if launch(31) {
		t.Error("challenge 31 started without achievement 281")
	}
	winTutorialChallenge(t, d, coachID, fr, 29)
	if !launch(30) {
		t.Error("challenge 30 refused after winning 29")
	}
	if launch(31) {
		t.Error("challenge 31 started after only 29")
	}
	winTutorialChallenge(t, d, coachID, fr, 30)
	if !launch(31) {
		t.Error("challenge 31 refused after winning 30")
	}
}

func TestBaanTutorialMarks226(t *testing.T) {
	d, coachID, fr := tutorialDeps(t)
	winTutorialChallenge(t, d, coachID, fr, 46)
	if got := statOf(d, coachID, 226); got != 1 {
		t.Errorf("statistic 226 = %d after winning Baan's tutorial, want 1", got)
	}
}
