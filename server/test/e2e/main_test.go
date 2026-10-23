package e2e

import (
	"os"
	"testing"
	"time"

	"github.com/StarLoco/arena-2.70/internal/game"
)

// TestMain sets the e2e turn clock once for the whole package.
//
// It used to be a per-test override restored by t.Cleanup. That is correct for a
// sequential suite and a data race for a parallel one - `turnClock` is a
// package-level variable in internal/game, so two tests overlapping would write
// it concurrently and a third could observe either value mid-fight.
//
// Every test asked for the same 12s, so there is nothing to preserve per test.
//
// Why 12s specifically (kept from the original comment, because the reasoning is
// easy to lose): long enough that a test can act inside its OWN turn on a loaded
// machine - the server silently refuses a cast from a fighter whose turn has
// expired, and a 6s clock lost that race - but short enough that a test waiting
// through a turn nobody ends still gets control back inside its budget.
func TestMain(m *testing.M) {
	restore := game.SetTurnClockForTest(12 * time.Second)
	restoreAI := game.SetAITurnClockForTest(200 * time.Millisecond)
	code := m.Run()
	restoreAI()
	restore()
	os.Exit(code)
}
