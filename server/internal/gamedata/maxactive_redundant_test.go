package gamedata

import (
	"testing"
)

// TestMaxActiveIsRedundantInShippedData is why `MaxActive` (spell record field 8)
// is decoded but deliberately NOT enforced.
//
// The client's model is clear enough to implement: the counter is `sH.akV` on the
// per-fighter cast-history tracker, keyed by spell id, checked against the TARGET
// (`mv_1` runs cooldown/per-turn against the caster's `sH` but calls the
// max-active check on `gn_03`, which the following line proves is the target),
// incremented on cast by `d()` and decremented by `e()`. No wire work is involved:
// the decrement is driven by `amt_2`, which looks like a packet (it extends
// `yd_2`) but has `TI()` returning 0, EMPTY serialization bodies and no opcode —
// a client-local timeline event.
//
// The reason not to implement it is that in the shipped data it can never change
// an outcome. Its decay window is ONE TURN — `mv_1` schedules the decrement with
// `arm_0.lQ(1)`, a literal, and the very next line schedules a different event
// with `arm_0.lQ(fv2.et())`, i.e. a spell-derived duration, so the literal is
// deliberate. A counter that resets every turn is exactly the granularity
// `CastMaxPerTarget` already has.
//
// And every shipped MaxActive spell is already capped at least as tightly by a
// limit the server DOES enforce: five of the six have
// `CastMaxPerTarget == MaxActive`, and the sixth (spell 8) is a range-0 self-cast
// already limited to one cast per turn.
//
// Enforcing it would therefore add a second, subtly different gate that changes
// no legal cast — and getting the window wrong would REJECT casts the client
// believes are legal, which is a visible regression. If this test ever fails, a
// spell has appeared whose MaxActive really does bind tighter than the limits we
// enforce, and it becomes worth implementing.
func TestMaxActiveIsRedundantInShippedData(t *testing.T) {
	st, err := openContent(t)
	if err != nil {
		t.Fatal(err)
	}
	spells, err := st.LoadSpells()
	if err != nil {
		t.Fatal(err)
	}

	checked := 0
	for id, sp := range spells.All() {
		if sp == nil || sp.MaxActive == 0 {
			continue
		}
		checked++
		// An enforced limit binds at least as tightly if it allows no more
		// simultaneous casts than MaxActive does, within the same one-turn window.
		perTargetBinds := sp.CastMaxPerTarget > 0 && sp.CastMaxPerTarget <= sp.MaxActive
		perTurnBinds := sp.CastMaxPerTurn > 0 && sp.CastMaxPerTurn <= sp.MaxActive
		if !perTargetBinds && !perTurnBinds {
			t.Errorf("spell %d: MaxActive=%d but CastMaxPerTarget=%d / CastMaxPerTurn=%d "+
				"do not bind it — MaxActive would now change which casts are legal and "+
				"is worth enforcing (see the client's sH.akV / mv_1)",
				id, sp.MaxActive, sp.CastMaxPerTarget, sp.CastMaxPerTurn)
		}
	}
	if checked == 0 {
		t.Fatal("no spell carries MaxActive — field 8 decode probably broke; " +
			"this test would otherwise pass forever without checking anything")
	}
	t.Logf("%d spells carry MaxActive; all already bound by an enforced limit", checked)
}
