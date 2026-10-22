package e2e

import (
	"testing"
	"time"

	"github.com/StarLoco/arena-2.70/internal/game"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/testclient"
)

// TestFightStatisticsUnlockAchievements: a real fight ended by a give-up moves
// the statistics only the server can see, and their achievements are announced
// live (S19). Before, nothing ever wrote 165 or 170, so an achievement on them
// could not unlock.
func TestFightStatisticsUnlockAchievements(t *testing.T) {
	t.Parallel()
	if raceEnabled {
		t.Skip("timing-sensitive full-fight E2E; flaky under -race's slowdown")
	}
	_, addr := testServerWithDeps(t, func(d *game.Deps) {
		d.Achievements = gamedata.NewAchievements(
			&gamedata.Achievement{ID: 7101, Points: 5, // like 176 "rage kit", at 1
				Conditions: []gamedata.AchievementCondition{{StatID: 170, Threshold: 1}}},
			&gamedata.Achievement{ID: 7102, Points: 5, // like 1 "Marcha", at 1
				Conditions: []gamedata.AchievementCondition{{StatID: 165, Threshold: 1}}},
		)
	})
	a, b := startFightForCombat(t, addr)
	a.DrainReceived(200 * time.Millisecond)
	b.DrainReceived(200 * time.Millisecond)

	_ = a.Send(3, testclient.OpGiveUp, nil)
	for _, w := range []struct {
		c    *testclient.Client
		want uint16
		who  string
	}{{a, 7101, "the coach that gave up"}, {b, 7102, "the winner"}} {
		f, _, err := w.c.WaitFor(opAchievementUnlocked, testclient.DefaultTimeout)
		if err != nil {
			t.Fatalf("%s got no 22000: %v", w.who, err)
		}
		if got := testclient.NewR(f.Payload).U16(); got != w.want {
			t.Errorf("%s: achievement %d, want %d", w.who, got, w.want)
		}
	}
}
