package game

import (
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// S21: Historia. The first win of a campaign challenge counts like an
// evolution fight; a replay of a won one is practice.

// launchStory starts challenge ch over the wire and returns its Fight (removed
// from the manager afterwards, so the next launch can start).
func launchStory(t *testing.T, d *Deps, s *Session, coachID uint, ch int32) *Fight {
	t.Helper()
	drain(t, s)
	w := protocol.NewWriter().I32(ch).U16(challengeAcceptBreed)
	_ = handleTeamTest(s, &protocol.C2SFrame{Opcode: protocol.OpTeamTest, Payload: w.Bytes()})
	f := d.Fights.ByCoach(coachID)
	if f != nil {
		d.Fights.Remove(f)
	}
	return f
}

func TestStoryFirstWinCountsReplayIsPractice(t *testing.T) {
	d, coachID, fr := tutorialDeps(t)
	d.Matchmaker = NewMatchmaker()
	d.Sessions = NewSessionRegistry()
	coach, _ := d.Store.Coaches.Get(coachID)
	s := tmSession(d, coachID, coach.Name)

	f := launchStory(t, d, s, coachID, 29)
	if f == nil {
		t.Fatal("challenge 29 did not start")
	}
	if !f.Story || !fightFeedsProgression(f) || f.Evolution || f.ChallengeID != 29 {
		t.Errorf("first try of 29: Story=%v feeds=%v Evolution=%v challenge=%d, want a story challenge",
			f.Story, fightFeedsProgression(f), f.Evolution, f.ChallengeID)
	}
	winTutorialChallenge(t, d, coachID, fr, 29)
	f = launchStory(t, d, s, coachID, 29)
	if f == nil {
		t.Fatal("won challenge 29 did not start again")
	}
	if f.Story || fightFeedsProgression(f) {
		t.Errorf("replay of a won 29: Story=%v feeds=%v, want practice", f.Story, fightFeedsProgression(f))
	}
	// a challenge outside the campaign never counts
	if g := launchStory(t, d, s, coachID, 17); g != nil && g.Story {
		t.Error("a class master's trial (17) is not a story fight")
	}
}

// TestStoryFightBanksXP: a won first-time story fight runs the META pass —
// the fighter banks base XP like an evolution fight.
func TestStoryFightBanksXP(t *testing.T) {
	d, coachID, fr := tutorialDeps(t)
	before := xpOf(t, d, fr.ID)
	f := buildTestFight()
	f.Teams[0].Coach().ID = coachID
	f.Teams[0].Fighters[0].Fighter = fr
	f.Teams[0].Fighters[0].CoachID = coachID
	f.ChallengeID = 46
	f.Practice = true
	f.Story = true
	f.setPhase(PhaseAction)
	d.Fights.Create(f)
	for _, ff := range f.allFighters() {
		if ff.TeamID == 1 {
			ff.HP = 0
		}
	}
	d.checkFightEnd(f)
	if after := xpOf(t, d, fr.ID); after <= before {
		t.Errorf("TotalXP %d → %d after a story win, want more", before, after)
	}
}

// TestStoryHandlerListsWon: 60020 answers the campaign challenges won.
func TestStoryHandlerListsWon(t *testing.T) {
	d, coachID, fr := tutorialDeps(t)
	d.Sessions = NewSessionRegistry()
	coach, _ := d.Store.Coaches.Get(coachID)
	s := tmSession(d, coachID, coach.Name)
	winTutorialChallenge(t, d, coachID, fr, 46)
	winTutorialChallenge(t, d, coachID, fr, 29)
	drain(t, s)
	if err := handleStoryRequest(s, &protocol.C2SFrame{Opcode: protocol.OpStoryRequest}); err != nil {
		t.Fatal(err)
	}
	var got []int32
	if p := drainPayload(t, s, protocol.OpStory); p != nil {
		r := protocol.NewReader(p)
		n, _ := r.U16()
		for i := 0; i < int(n); i++ {
			id, _ := r.I32()
			got = append(got, id)
		}
	}
	sort.Slice(got, func(i, j int) bool { return got[i] < got[j] })
	if len(got) != 2 || got[0] != 29 || got[1] != 46 {
		t.Errorf("60021 lists %v, want [29 46]", got)
	}
}

// TestStoryChallengesMatchClient: the Godot client lays out the same
// campaign (godot/src/gamedata/story.gd), chapter by chapter.
func TestStoryChallengesMatchClient(t *testing.T) {
	src, err := os.ReadFile(filepath.Join("..", "..", "..", "godot", "src", "gamedata", "story.gd"))
	if err != nil {
		t.Skip("no Godot client in this checkout")
	}
	re := regexp.MustCompile(`"challenges":\s*\[([0-9,\s]*)\]`)
	m := re.FindAllStringSubmatch(string(src), -1)
	if len(m) != len(storyChapters) {
		t.Fatalf("story.gd has %d chapters, the server %d", len(m), len(storyChapters))
	}
	num := regexp.MustCompile(`[0-9]+`)
	for i, ch := range m {
		ids := num.FindAllString(ch[1], -1)
		if len(ids) != len(storyChapters[i]) {
			t.Fatalf("chapter %d: client %v, server %v", i, ids, storyChapters[i])
		}
		for j, s := range ids {
			v, _ := strconv.Atoi(s)
			if int32(v) != storyChapters[i][j] {
				t.Errorf("chapter %d: client %v, server %v", i, ids, storyChapters[i])
				break
			}
		}
	}
}

// TestStoryRosterFieldsHistoriaStarters: a classic Elite fighter is a
// titular too (state 0), but a story challenge fields the Historia starters;
// with none yet, the titulars so a challenge never starts empty.
func TestStoryRosterFieldsHistoriaStarters(t *testing.T) {
	d, coachID, fr := tutorialDeps(t) // fr: a titular with no Evolution flag
	if got := d.storyRoster(coachID, 6); len(got) != 1 || got[0] != int64(fr.ID) {
		t.Errorf("no Historia starter yet: roster %v, want the titular %d", got, fr.ID)
	}
	evo := &domain.Fighter{CoachID: coachID, BreedID: 2, Name: "Historia", State: domain.FighterStateTitular, Evolution: true}
	if err := d.Store.Fighters.Create(evo); err != nil {
		t.Fatal(err)
	}
	if got := d.storyRoster(coachID, 6); len(got) != 1 || got[0] != int64(evo.ID) {
		t.Errorf("roster %v, want only the Historia starter %d", got, evo.ID)
	}
	if got := d.titularRoster(coachID, 6); len(got) != 2 {
		t.Errorf("titularRoster %v, want both titulars (ghosts and tournaments keep using it)", got)
	}
}

// TestRankedFightLeavesFighters (S21, no pay-to-win): a ranked Elite fight
// banks no XP, fatigue or wounds on the fighters — Elite is everyone at the
// same level — but the coach still earns its reputation.
func TestRankedFightLeavesFighters(t *testing.T) {
	d, coachID, fr := tutorialDeps(t)
	before := xpOf(t, d, fr.ID)
	f := buildTestFight()
	f.Teams[0].Coach().ID = coachID
	f.Teams[0].Fighters[0].Fighter = fr
	f.Teams[0].Fighters[0].CoachID = coachID
	f.Practice = false
	f.setPhase(PhaseAction)
	d.Fights.Create(f)
	for _, ff := range f.allFighters() {
		if ff.TeamID == 1 {
			ff.HP = 0
		}
	}
	d.checkFightEnd(f)
	if after := xpOf(t, d, fr.ID); after != before {
		t.Errorf("TotalXP %d → %d after a ranked win, want unchanged", before, after)
	}
	if f.Teams[0].Coach().Standing <= 0 {
		t.Errorf("coach standing = %d after a ranked win, want the fight's reputation", f.Teams[0].Coach().Standing)
	}
}
