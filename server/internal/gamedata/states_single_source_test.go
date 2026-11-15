package gamedata

import (
	"sort"
	"testing"
)

// stateActionIDs mirrors internal/game/states.go's stateByAction. Duplicated
// deliberately: gamedata must not import game, and the point of this test is to
// catch the two tables drifting apart along with everything else.
var stateActionIDs = map[int32]string{
	65: "rooted", 96: "petrified", 94: "stabilized", 127: "anchored",
	128: "intransposable", 57: "invisible", 95: "immune", 124: "immune",
	56: "skipTurn", 111: "skipTurn", 126: "drunk",
	173: "maskClass", 174: "maskCoward", 175: "maskBerzerk",
}

// TestStatesTargetedBy149AreSingleSourced pins the data property that lets
// internal/game/states.go get away with a SINGLE-VALUED stateSrc map
// (state -> the effect id that set it).
//
// The client does not model states that way. A fighter's states live in the
// refcounted store Kt (gn_0.baR, an aLM extends Kt): g() increments a per-key
// byte, h() decrements and deletes at zero, c() reads the count. There is no
// duration in that store at all — only "how many sources are applying this".
// Our map instead holds remaining TURNS and keeps max(existing, new), so two
// overlapping sources collapse into one entry and one remembered effect id.
//
// That divergence is only OBSERVABLE if something removes one source of a
// multi-source state early, and the only mechanism that removes a state by
// source is action 149. This test asserts the property that makes that
// unreachable: every state effect id targeted by a 149 is the ONLY source of
// its state in the whole spell table.
//
// Overlap itself is real and shipped — spell 419 applies five states at
// duration 63, and spells 147 and 170 each apply `rooted` twice in one cast
// (170 with two different durations) — so this is a genuine property of which
// states 149 touches, not an accident of there being no overlap anywhere.
//
// If this test ever fails, the max()-and-last-writer model is no longer safe
// and states must become properly source-counted, the way Kt does it.
func TestStatesTargetedBy149AreSingleSourced(t *testing.T) {
	st, err := openContent(t)
	if err != nil {
		t.Fatal(err)
	}
	spells, err := st.LoadSpells()
	if err != nil {
		t.Fatal(err)
	}
	all := spells.All()
	if len(all) == 0 {
		t.Fatal("no spells decoded")
	}

	// effectId -> state action id, and state action id -> set of source effect ids.
	stateEffect := map[int32]int32{}
	sourcesOf := map[int32]map[int32]bool{}
	for _, sp := range all {
		for _, ef := range sp.Effects {
			if _, ok := stateActionIDs[ef.ActionID]; !ok {
				continue
			}
			stateEffect[ef.EffectID] = ef.ActionID
			if sourcesOf[ef.ActionID] == nil {
				sourcesOf[ef.ActionID] = map[int32]bool{}
			}
			sourcesOf[ef.ActionID][ef.EffectID] = true
		}
	}
	if len(stateEffect) == 0 {
		t.Fatal("no state effects found — the action-id table or the decode is wrong")
	}

	targeted := 0
	for _, sp := range all {
		for _, ef := range sp.Effects {
			if ef.ActionID != 149 {
				continue
			}
			for _, pv := range ef.Params {
				eid := int32(pv)
				act, ok := stateEffect[eid]
				if !ok {
					continue // a 149 aimed at a buff/aura, not a state
				}
				targeted++
				if n := len(sourcesOf[act]); n != 1 {
					srcs := make([]int, 0, n)
					for s := range sourcesOf[act] {
						srcs = append(srcs, int(s))
					}
					sort.Ints(srcs)
					t.Errorf("spell %d's action-149 targets state effect %d (action %d = %s), "+
						"but that state has %d sources %v — a single-valued stateSrc can no longer "+
						"identify which one to strip; states must become source-counted (see Kt)",
						sp.ID, eid, act, stateActionIDs[act], n, srcs)
				}
			}
		}
	}
	if targeted == 0 {
		t.Fatal("no action-149 row targets a state effect id — either the mask spells " +
			"stopped decoding or the param layout changed; this test would silently pass forever")
	}
	t.Logf("%d action-149 rows target a state effect id; all single-sourced", targeted)
}
