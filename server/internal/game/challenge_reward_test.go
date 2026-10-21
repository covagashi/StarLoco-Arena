package game

import (
	"path/filepath"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/store/storetest"
)

// challengeRewardDeps builds a Deps with a real store and the real challenge +
// card tables, plus the persisted coach that will win.
func challengeRewardDeps(t *testing.T) (*Deps, uint) {
	t.Helper()
	st, err := storetest.Open(t, filepath.Join(t.TempDir(), "chalreward.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })

	gd := openRealGameData(t)
	defs, err := gd.LoadChallenges()
	if err != nil {
		t.Fatalf("LoadChallenges: %v", err)
	}
	cards, err := gd.LoadCards()
	if err != nil {
		t.Fatalf("LoadCards: %v", err)
	}

	acc, _ := st.Accounts.CreateAccount("chalwin", "pw", false)
	coach, _ := st.Coaches.Create(acc.ID, "ChalWinner", 0, 0, 0)

	d := &Deps{
		Store: st, ChallengeDefs: defs, Cards: cards,
		Fights: NewFightManager(), World: NewRegistry(150), Log: testLogger(),
	}
	return d, coach.ID
}

// ownedQty totals a coach's unequipped quantity of a card template.
func ownedQty(t *testing.T, d *Deps, coachID uint, templateID int32) int16 {
	t.Helper()
	c, err := d.Store.Coaches.Get(coachID)
	if err != nil {
		t.Fatalf("get coach: %v", err)
	}
	var n int16
	for _, card := range c.Inventory {
		if card.TemplateID == templateID {
			n += card.Quantity
		}
	}
	return n
}

// TestChallengeVictoryGrantsRewards: beating a challenge grants the reward cards
// its type-400 record lists. Challenge 33 (the gated 12th-minute demon) awards
// cards 186 and 189.
func TestChallengeVictoryGrantsRewards(t *testing.T) {
	d, coachID := challengeRewardDeps(t)

	ch := d.ChallengeDefs.Get(33)
	if ch == nil || len(ch.RewardCards) == 0 {
		t.Fatal("challenge 33 has no rewards; pick another id for this test")
	}
	for _, cardID := range ch.RewardCards {
		if got := ownedQty(t, d, coachID, cardID); got != 0 {
			t.Fatalf("precondition: coach already owns card %d (%d)", cardID, got)
		}
	}

	f := buildTestFight()
	f.Teams[0].Coach().ID = coachID
	f.ChallengeID = 33
	f.Practice = true // challenges are unranked, like the real launch
	f.setPhase(PhaseAction)
	d.Fights.Create(f)

	// Kill the opponent side so the player's team wins.
	for _, ff := range f.allFighters() {
		if ff.TeamID == 1 {
			ff.HP = 0
		}
	}
	d.checkFightEnd(f)

	for _, cardID := range ch.RewardCards {
		if got := ownedQty(t, d, coachID, cardID); got < 1 {
			t.Errorf("after victory, coach owns %d of reward card %d, want >= 1", got, cardID)
		}
	}
}

// TestChallengeDefeatGrantsNothing: losing must award nothing.
func TestChallengeDefeatGrantsNothing(t *testing.T) {
	d, coachID := challengeRewardDeps(t)
	ch := d.ChallengeDefs.Get(33)

	f := buildTestFight()
	f.Teams[0].Coach().ID = coachID
	f.ChallengeID = 33
	f.Practice = true
	f.setPhase(PhaseAction)
	d.Fights.Create(f)

	// Kill the PLAYER's side (team 0) so the challenge wins.
	for _, ff := range f.allFighters() {
		if ff.TeamID == 0 {
			ff.HP = 0
		}
	}
	d.checkFightEnd(f)

	for _, cardID := range ch.RewardCards {
		if got := ownedQty(t, d, coachID, cardID); got != 0 {
			t.Errorf("after DEFEAT, coach owns %d of card %d, want 0", got, cardID)
		}
	}
}

// TestNonChallengeFightGrantsNoCards: an ordinary fight (ChallengeID 0) must not
// grant challenge cards — the reward hook must be gated on the challenge id, not
// merely on winning.
func TestNonChallengeFightGrantsNoCards(t *testing.T) {
	d, coachID := challengeRewardDeps(t)
	ch := d.ChallengeDefs.Get(33)

	f := buildTestFight()
	f.Teams[0].Coach().ID = coachID
	f.ChallengeID = 0
	f.Practice = true
	f.setPhase(PhaseAction)
	d.Fights.Create(f)

	for _, ff := range f.allFighters() {
		if ff.TeamID == 1 {
			ff.HP = 0
		}
	}
	d.checkFightEnd(f)

	for _, cardID := range ch.RewardCards {
		if got := ownedQty(t, d, coachID, cardID); got != 0 {
			t.Errorf("ordinary fight granted %d of challenge card %d, want 0", got, cardID)
		}
	}
}

// winChallenge drives a full victory over the given challenge for a coach.
func winChallenge(t *testing.T, d *Deps, coachID uint, challengeID int32) {
	t.Helper()
	f := buildTestFight()
	f.Teams[0].Coach().ID = coachID
	f.Teams[1].Coach().ID = challengeCoachID
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

// statValue reads one persisted stat/criterion for a coach.
func statValue(t *testing.T, d *Deps, coachID uint, statID int16) int32 {
	t.Helper()
	c, err := d.Store.Coaches.Get(coachID)
	if err != nil {
		t.Fatalf("get coach: %v", err)
	}
	for _, st := range c.Stats {
		if st.StatID == statID {
			return st.Value
		}
	}
	return 0
}

// TestRewardsGrantedOnlyOnFirstClear: repeat wins must not keep paying out, or a
// challenge is an infinite card faucet.
func TestRewardsGrantedOnlyOnFirstClear(t *testing.T) {
	d, coachID := challengeRewardDeps(t)
	ch := d.ChallengeDefs.Get(33)

	winChallenge(t, d, coachID, 33)
	after1 := map[int32]int16{}
	for _, cardID := range ch.RewardCards {
		after1[cardID] = ownedQty(t, d, coachID, cardID)
		if after1[cardID] < 1 {
			t.Fatalf("first clear did not grant card %d", cardID)
		}
	}

	// Two more clears must change nothing.
	winChallenge(t, d, coachID, 33)
	winChallenge(t, d, coachID, 33)
	for _, cardID := range ch.RewardCards {
		if got := ownedQty(t, d, coachID, cardID); got != after1[cardID] {
			t.Errorf("card %d: %d after 3 clears, want %d (rewards must not repeat)",
				cardID, got, after1[cardID])
		}
	}
}

// TestMinuteDemonCriteriaAreSet: beating a minute demon must set the client
// criterion that gates achievement 278 — which is what makes the 12th-minute
// boss reachable at all.
func TestMinuteDemonCriteriaAreSet(t *testing.T) {
	d, coachID := challengeRewardDeps(t)

	for challengeID, criterion := range challengeCriterion {
		if got := statValue(t, d, coachID, int16(criterion)); got != 0 {
			t.Fatalf("precondition: criterion %d already %d", criterion, got)
		}
		winChallenge(t, d, coachID, challengeID)
		if got := statValue(t, d, coachID, int16(criterion)); got != 1 {
			t.Errorf("after beating challenge %d, criterion %d = %d, want 1",
				challengeID, criterion, got)
		}
	}
	// The four criteria of achievement 278 are all set, but the aggregate (213)
	// also needs the BOSS (33), which has not been beaten.
	if got := statValue(t, d, coachID, int16(criterionAllMinuteDemons)); got != 0 {
		t.Errorf("criterion 213 = %d before the boss was beaten, want 0", got)
	}
	winChallenge(t, d, coachID, 33)
	if got := statValue(t, d, coachID, int16(criterionAllMinuteDemons)); got != 1 {
		t.Errorf("criterion 213 = %d after all five minute demons, want 1", got)
	}
}

// TestCompletionFlagsStayOutOfTheClientBlob: the server's per-challenge
// bookkeeping must never be sent as a criterion — it lives above the client's
// or_0 enum on purpose.
func TestCompletionFlagsStayOutOfTheClientBlob(t *testing.T) {
	d, coachID := challengeRewardDeps(t)
	winChallenge(t, d, coachID, 34)

	c, err := d.Store.Coaches.Get(coachID)
	if err != nil {
		t.Fatalf("get coach: %v", err)
	}
	// The bookkeeping flag IS persisted...
	if got := statValue(t, d, coachID, challengeDoneStat(34)); got != 1 {
		t.Errorf("completion flag for challenge 34 = %d, want 1", got)
	}
	// ...but must not appear in what 2052 carries, while the real criterion does.
	var sawBookkeeping, sawCriterion bool
	for _, cr := range coachCriteria(c) {
		if cr.ID == uint16(challengeDoneStat(34)) {
			sawBookkeeping = true
		}
		if cr.ID == challengeCriterion[34] {
			sawCriterion = true
		}
	}
	if sawBookkeeping {
		t.Errorf("server bookkeeping stat %d leaked into the 2052 criteria blob",
			challengeDoneStat(34))
	}
	if !sawCriterion {
		t.Errorf("client criterion %d missing from the 2052 criteria blob",
			challengeCriterion[34])
	}
}

// TestDisconnectedWinnerStillGetsRewards: a coach whose fight continues after it
// dropped (the reconnect grace period) has no Session, but is still a real coach
// and must be paid if it wins. Regression guard — the first version gated the
// grant on `t.Session != nil`, silently voiding the reward.
func TestDisconnectedWinnerStillGetsRewards(t *testing.T) {
	d, coachID := challengeRewardDeps(t)
	ch := d.ChallengeDefs.Get(33)

	f := buildTestFight()
	f.Teams[0].Coach().ID = coachID
	f.Teams[0].Members[0].Session = nil // dropped mid-fight
	f.ChallengeID = 33
	f.Practice = true
	f.setPhase(PhaseAction)
	d.Fights.Create(f)
	for _, ff := range f.allFighters() {
		if ff.TeamID == 1 {
			ff.HP = 0
		}
	}
	d.checkFightEnd(f)

	for _, cardID := range ch.RewardCards {
		if got := ownedQty(t, d, coachID, cardID); got < 1 {
			t.Errorf("disconnected winner got %d of card %d, want >= 1", got, cardID)
		}
	}
}

// TestSyntheticOpponentNeverGetsRewards: when the challenge side WINS, the reward
// path must not write inventory rows for the synthetic opponent coach, which has
// no account and no DB row.
func TestSyntheticOpponentNeverGetsRewards(t *testing.T) {
	d, coachID := challengeRewardDeps(t)

	f := buildTestFight()
	f.Teams[0].Coach().ID = coachID
	f.Teams[1].Coach().ID = challengeCoachID // the demon side
	f.ChallengeID = 33
	f.Practice = true
	f.setPhase(PhaseAction)
	d.Fights.Create(f)
	// The player loses: the synthetic side wins.
	for _, ff := range f.allFighters() {
		if ff.TeamID == 0 {
			ff.HP = 0
		}
	}
	d.checkFightEnd(f)

	if _, err := d.Store.Coaches.Get(challengeCoachID); err == nil {
		t.Errorf("synthetic coach %d was persisted to the store", challengeCoachID)
	}
	if got := ownedQty(t, d, coachID, 186); got != 0 {
		t.Errorf("loser was granted %d of card 186, want 0", got)
	}
}

// TestDanglingRewardCardIsNotGranted: challenge 9 awards card 184, which the game
// data does not define. Granting it would leave an inventory row the client
// cannot render, so it must be filtered — and the rest of the grant must still
// proceed (challenge 37 awards 184 AND the real card 193).
func TestDanglingRewardCardIsNotGranted(t *testing.T) {
	d, coachID := challengeRewardDeps(t)

	const dangling int32 = 184
	if d.Cards.Get(dangling) != nil {
		t.Skipf("card %d now exists; this test's premise is gone", dangling)
	}
	ch := d.ChallengeDefs.Get(37)
	if ch == nil {
		t.Fatal("challenge 37 missing")
	}

	f := buildTestFight()
	f.Teams[0].Coach().ID = coachID
	f.ChallengeID = 37
	f.Practice = true
	f.setPhase(PhaseAction)
	d.Fights.Create(f)
	for _, ff := range f.allFighters() {
		if ff.TeamID == 1 {
			ff.HP = 0
		}
	}
	d.checkFightEnd(f)

	if got := ownedQty(t, d, coachID, dangling); got != 0 {
		t.Errorf("phantom card %d was granted (%d) — it is not in the card table", dangling, got)
	}
	// Every OTHER reward on that challenge must still have landed.
	for _, cardID := range ch.RewardCards {
		if cardID == dangling {
			continue
		}
		if got := ownedQty(t, d, coachID, cardID); got < 1 {
			t.Errorf("real reward %d was dropped along with the phantom one", cardID)
		}
	}
}
