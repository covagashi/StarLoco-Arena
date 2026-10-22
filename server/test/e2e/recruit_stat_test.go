package e2e

import (
	"testing"
	"time"

	"github.com/StarLoco/arena-2.70/internal/testclient"
)

// TestRecruitsCountTowardsStatistic211 (S10): three fighters created over the
// wire put "recruited three warriors" (or_0 211, achievement 276) at 3.
func TestRecruitsCountTowardsStatistic211(t *testing.T) {
	t.Parallel()
	st, addr := testServerWithStore(t)
	c, coachID := dialLogin(t, addr, "recruiter", "Recruiter")
	c.DrainReceived(200 * time.Millisecond)
	for _, name := range []string{"Uno", "Dos", "Tres"} {
		blob := fighterBlob(name)
		payload := testclient.NewW().U8(0).U16(0).U16(uint16(len(blob))).Raw(blob).Bytes()
		_ = c.Send(2, opFighterCreate, payload)
		if _, _, err := c.WaitFor(opFighterCreateResult, testclient.DefaultTimeout); err != nil {
			t.Fatalf("create %s: %v", name, err)
		}
	}
	c.DrainReceived(200 * time.Millisecond)
	if got := st.Coaches.StatValue(uint(coachID), 211); got != 3 {
		t.Errorf("statistic 211 = %d after three recruits, want 3", got)
	}
}
