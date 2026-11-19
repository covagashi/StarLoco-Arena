package game

import (
	"fmt"
	"os"
	"testing"
)

// TestTurnChoiceSim (S46, on demand) measures what opening is worth: the side
// with +30 initiative on all three chooses, with the AI's pick and with each
// fixed policy, against the naked mirror.
//
//	S46_SIM=400 go test ./internal/game/ -run TestTurnChoiceSim -v
func TestTurnChoiceSim(t *testing.T) {
	n := 0
	fmt.Sscan(os.Getenv("S46_SIM"), &n)
	if n <= 0 {
		t.Skip("set S46_SIM=<fights per policy>")
	}
	d := simDeps(t)
	fast := simTeam(d, 2, []int32{89}, len(simBreeds)) // +30 initiative on all three
	naked := simTeam(d, 1, nil, 0)
	keep := serverChooserOpens
	t.Cleanup(func() { serverChooserOpens = keep })
	opened, settled := 0, 0
	serverChooserOpens = func(f *Fight) bool {
		o := keep(f)
		settled++
		if o {
			opened++
		}
		return o
	}
	t.Logf("AI's pick: %.2f (opened %d of %d)", winRate(t, d, fast, naked, n), opened, settled)
	serverChooserOpens = func(*Fight) bool { return true }
	t.Logf("always open: %.2f", winRate(t, d, fast, naked, n))
	serverChooserOpens = func(*Fight) bool { return false }
	t.Logf("always cede: %.2f", winRate(t, d, fast, naked, n))
	serverChooserOpens = keep

	// the opener's first-turn MP: the mirror with the opener fixed, each amount
	keepMP := openerFirstTurnMP
	t.Cleanup(func() { openerFirstTurnMP = keepMP })
	for _, mp := range []int32{0, 1, 2, 3, 4} {
		openerFirstTurnMP = mp
		serverChooserOpens = func(*Fight) bool { return true }
		o := winRate(t, d, fast, naked, n)
		serverChooserOpens = keep
		ai := winRate(t, d, fast, naked, n)
		t.Logf("opener +%d MP: opening %.2f, chooser with the AI's pick %.2f", mp, o, ai)
	}
}
