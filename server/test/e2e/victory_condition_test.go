package e2e

import (
	"path/filepath"
	"testing"
	"time"

	"github.com/StarLoco/arena-2.70/internal/game"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/testclient"
)

// TestChallengeVictoryConditionEndsFight drives a real challenge fight over a
// real socket until its np_1 type-14 victory condition fires, and asserts the
// server declares the coach the winner.
//
// This is the end-to-end complement to the unit tests in internal/game: those
// prove the predicate and the arbitration in isolation, while this one proves
// the whole chain — challenge record -> np_1 decode -> per-fight ruleset -> the
// round-advance hook -> checkFightEnd's decided-winner path -> END_FIGHT(8300)
// actually reaching a client.
//
// The shipped conditions ask for 20 or 30 rounds, which would take minutes of
// wall clock against AI turn clocks, so the challenge's ruleset is rebuilt here
// with a threshold of 1 (win as round 2 opens). The parameter is the only thing
// changed: the record, the decoder, the ruleset resolution and the evaluator are
// all the production ones, and the real-data canary
// (TestShippedTimeChallengesResolveToSurvivalRules) separately pins the shipped
// values at 20/30.
func TestChallengeVictoryConditionEndsFight(t *testing.T) {
	t.Parallel()
	if raceEnabled {
		t.Skip("timing-sensitive full-fight E2E; flaky under -race's slowdown")
	}
	st, err := gamedata.Open(filepath.Join("..", "..", "data-dist"))
	if err != nil {
		t.Skipf("game data not available: %v", err)
	}
	all, err := st.LoadChallenges()
	if err != nil {
		t.Fatalf("LoadChallenges: %v", err)
	}
	spells, err := st.LoadSpells()
	if err != nil {
		t.Fatalf("LoadSpells: %v", err)
	}

	// Challenge 35 is a known-playable minute demon (see TestChallengeFightIsPlayable).
	base := all.Get(35)
	if base == nil {
		t.Skip("challenge 35 absent from this data set")
	}
	quick := *base
	quick.Bonuses = append([]gamedata.Parameter(nil), base.Bonuses...)
	quick.Bonuses = append(quick.Bonuses, gamedata.Parameter{
		Type: gamedata.ParamTypeVictoryCondition,
		Victory: &gamedata.VictoryCondition{
			Type: gamedata.VictoryReachTurn, Params: []int32{1},
			IsNecessary: true, AffectedTeam: 0, // team 0 is the coach in a PvE challenge
		},
	})

	db, addr := testServerWithDeps(t, func(d *game.Deps) {
		d.ChallengeDefs = gamedata.NewChallenges(&quick)
		d.Spells = spells
	})

	c, coachID := dialLogin(t, addr, "vict1", "Victor1")
	reachWorld(t, c)

	if err := c.Send(2, testclient.OpTeamTest, challengeLaunch(35)); err != nil {
		t.Fatal(err)
	}
	if _, _, err := c.WaitFor(testclient.OpCreateFight, testclient.DefaultTimeout); err != nil {
		t.Fatalf("challenge 35 did not start: %v", err)
	}
	c.DrainReceived(200 * time.Millisecond)

	for _, op := range []uint16{
		testclient.OpReadyForPlacement,
		testclient.OpReadyForObservation,
	} {
		_ = c.Send(3, op, nil)
		c.DrainReceived(300 * time.Millisecond)
	}
	_ = c.Send(3, testclient.OpReadyForAction, nil)
	if _, _, err := c.WaitFor(testclient.OpStartAction, testclient.DefaultTimeout); err != nil {
		t.Fatalf("never reached the action phase: %v", err)
	}

	// Pass turns until the condition fires. The coach's fighters simply end
	// their turns; the session-less demon side is driven by the AI clock. With a
	// threshold of 1 this needs at most one full round of the timeline.
	//
	// Wait on turn-begin OR end-fight in the SAME call: END_FIGHT arrives on the
	// heels of the last turn, and a loop that only watched for turn-begin would
	// consume and discard it while waiting for a turn that is never coming.
	var end *testclient.Frame
	deadline := time.Now().Add(25 * time.Second)
	for time.Now().Before(deadline) {
		f, _, err := c.WaitFor2(testclient.OpFighterTurnBegin, testclient.OpEndFight, 5*time.Second)
		if err != nil {
			break
		}
		if f.Opcode == testclient.OpEndFight {
			end = f
			break
		}
		_ = c.EndTurn(testclient.ParseFighterTurnBegin(f))
	}
	if end == nil {
		t.Fatal("victory condition never ended the fight")
	}
	if len(end.Payload) == 0 {
		t.Fatal("END_FIGHT carried an empty payload")
	}

	// END_FIGHT(8300) opens with [i32 actionUid][u8 winnerCount] then the winning
	// coaches. The coach must be among the winners: it won by surviving, with the
	// demon team still standing, which is precisely what the old survivor-count
	// path could not express.
	r := testclient.NewR(end.Payload)
	_ = r.I32()
	if winners := r.U8(); winners == 0 {
		t.Error("END_FIGHT declared no winner; the coach should have won on the victory condition")
	}

	// The fight just ran to completion through the production victory path, so
	// it is the cheapest place to prove lifetime time-in-fight is actually
	// credited there — the unit tests cover the arithmetic, not the wiring.
	var inFight int64
	waitFor := time.Now().Add(5 * time.Second)
	for time.Now().Before(waitFor) {
		if coach, err := db.Coaches.Get(uint(coachID)); err == nil && coach.TimeInFightSecs > 0 {
			inFight = coach.TimeInFightSecs
			break
		}
		time.Sleep(50 * time.Millisecond)
	}
	if inFight == 0 {
		t.Error("TimeInFightSecs is still 0 after a full fight — the statistics panel's " +
			"'time in fight' would never move")
	}
}
