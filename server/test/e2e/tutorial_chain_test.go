package e2e

import (
	"testing"
	"time"

	"github.com/StarLoco/arena-2.70/internal/game"
	"github.com/StarLoco/arena-2.70/internal/store"
	"github.com/StarLoco/arena-2.70/internal/testclient"
)

// TestTutorialChainOverTheWire (S10) is the tutorial's server half end to end,
// on the real game data: a new coach recruits three fighters (211 → 276), is
// refused the Demon III's 30 before its time, wins 29 → 30 → 31 (198/199/200 →
// 280, 281, 284, with their XP), and Baan's 46 (226 → 446). The wins use the
// GM /ENDFIGHT, so the account is an admin; everything else is a player's.
func TestTutorialChainOverTheWire(t *testing.T) {
	t.Parallel()
	var st *store.Store
	addr := testServerWithData(t, func(d *game.Deps) {
		st = d.Store
		if _, err := st.Accounts.CreateAccount("tuto", "pw", true); err != nil {
			t.Fatalf("seed admin: %v", err)
		}
	})
	c, coachID := dialLogin(t, addr, "tuto", "Novato")
	reachWorld(t, c)
	c.DrainReceived(300 * time.Millisecond)

	// The 22000 can go out before the reply the client is waiting for (the
	// recruit's 6000, the fight's 8300), and WaitFor drops frames it skips.
	// The unlock table is written in the same step that sends the 22000
	// (evaluateAchievements), so it is what is polled.
	expectAchievement := func(want int16, what string) {
		t.Helper()
		deadline := time.Now().Add(testclient.DefaultTimeout)
		for time.Now().Before(deadline) {
			if unl, _ := st.Coaches.UnlockedAchievements(uint(coachID)); unl[want] {
				return
			}
			time.Sleep(50 * time.Millisecond)
		}
		t.Fatalf("%s: achievement %d never announced", what, want)
	}

	// Recruit three.
	for _, name := range []string{"Uno", "Dos", "Tres"} {
		blob := fighterBlob(name)
		_ = c.Send(2, opFighterCreate, testclient.NewW().U8(0).U16(0).U16(uint16(len(blob))).Raw(blob).Bytes())
		if _, _, err := c.WaitFor(opFighterCreateResult, testclient.DefaultTimeout); err != nil {
			t.Fatalf("create %s: %v", name, err)
		}
	}
	expectAchievement(276, "three recruits")

	challenge := func(id int32) {
		_ = c.Send(2, testclient.OpTeamTest, testclient.NewW().I32(id).U16(99).Bytes())
	}
	// 30 before 29: refused, no fight.
	challenge(30)
	if _, _, err := c.WaitFor(testclient.OpCreateFight, 800*time.Millisecond); err == nil {
		t.Fatal("challenge 30 started before 29 was won")
	}

	win := func(id int32) {
		t.Helper()
		c.DrainReceived(100 * time.Millisecond)
		challenge(id)
		if _, _, err := c.WaitFor(testclient.OpCreateFight, testclient.DefaultTimeout); err != nil {
			t.Fatalf("challenge %d did not start: %v", id, err)
		}
		_ = c.Send(3, 3153, testclient.NewW().StrU16("/ENDFIGHT win").Bytes())
		if _, _, err := c.WaitFor(testclient.OpEndFight, testclient.DefaultTimeout); err != nil {
			t.Fatalf("challenge %d never ended: %v", id, err)
		}
		_ = c.Send(3, testclient.OpEndFightDone, nil)
	}
	win(29)
	expectAchievement(280, "challenge 29")
	win(30)
	expectAchievement(281, "challenge 30")
	win(31)
	expectAchievement(284, "challenge 31")

	// Their XP: the challenges' own 1 (cap 1), +2 (cap 10), +3 (cap 15) for
	// each fighter fielded — and, since S21 (Historia), each FIRST win also
	// runs the evolution META pass, worth at least the base 100 a fight.
	fighters, _ := st.Fighters.ListByCoach(uint(coachID))
	best := int32(0)
	for _, fr := range fighters {
		if fr.TotalXP > best {
			best = fr.TotalXP
		}
	}
	if best < 6+3*100 {
		t.Errorf("best fighter XP after the chain = %d, want at least 306 (1+2+3 and three story wins)", best)
	}

	win(46)
	expectAchievement(446, "Baan's tutorial")
}
