package e2e

import (
	"testing"
	"time"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/game"
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store"
	"github.com/StarLoco/arena-2.70/internal/testclient"
)

// TestGhostFightReplaysWithItsSeed is S12's closing criterion over the wire:
// an admin saves a ghost of its line-up (60010), lists it (60012), fights it
// (60014) with /AUTOPILOT so the server AI plays BOTH sides, and then plays the
// recorded fight again from its seed (60014 + fight id). The two fights must
// come out the same: winner, rounds, arena and decision-log hash.
func TestGhostFightReplaysWithItsSeed(t *testing.T) {
	t.Parallel()
	if raceEnabled {
		t.Skip("full AI-vs-AI fights; too slow under -race")
	}
	b := realBundle(t)
	st, addr := testServerWithDeps(t, func(d *game.Deps) { d.UseGameData(b) })
	c, coachID := dialLogin(t, addr, "ghost_admin", "GhostAdmin") // first account: admin
	reachWorld(t, c)
	createFighter(t, c, st, uint(coachID), "Fantasmon", 8)
	second := createFighter(t, c, st, uint(coachID), "Espectra", 9)
	c.DrainReceived(200 * time.Millisecond)

	// 60010: save, with a close-combat rule for the second fighter
	rules := []byte(`{"version":1,"rules":[{"if":{"kind":"always"},"do":{"kind":"close_combat"}}]}`)
	save := testclient.NewW().U8(uint8(len("Mi fantasma"))).Raw([]byte("Mi fantasma")).
		U8(1).I64(int64(second)).U16(uint16(len(rules))).Raw(rules).Bytes()
	_ = c.Send(3, protocol.OpGhostSave, save)
	f, _, err := c.WaitFor(protocol.OpGhostResult, testclient.DefaultTimeout)
	if err != nil {
		t.Fatalf("no 60011 after save: %v", err)
	}
	r := protocol.NewReader(f.Payload)
	action, _ := r.U8()
	code, _ := r.U8()
	gid, _ := r.I64()
	if action != 1 || code != 0 || gid <= 0 {
		t.Fatalf("save: action=%d code=%d id=%d", action, code, gid)
	}

	// 60012 → 60013 lists it as ours
	_ = c.Send(3, protocol.OpGhostListRequest, nil)
	lf, _, err := c.WaitFor(protocol.OpGhostList, testclient.DefaultTimeout)
	if err != nil {
		t.Fatalf("no 60013: %v", err)
	}
	lr := protocol.NewReader(lf.Payload)
	n, _ := lr.U16()
	id, _ := lr.I64()
	name, _ := lr.StringU8UTF8()
	_, _ = lr.StringU8UTF8()
	fighters, _ := lr.U8()
	_, _ = lr.I32()
	mine, _ := lr.U8()
	if n != 1 || id != gid || name != "Mi fantasma" || fighters != 2 || mine != 1 {
		t.Fatalf("list: n=%d id=%d name=%q fighters=%d mine=%d", n, id, name, fighters, mine)
	}

	first := fightGhost(t, c, st, gid, 0)
	again := fightGhost(t, c, st, gid, int64(first.ID))
	t.Logf("fight %d: seed=%d arena=%d winner=%d rounds=%d hash=%s",
		first.ID, first.Seed, first.ArenaID, first.WinnerTeam, first.Rounds, first.DecisionHash[:12])
	if again.ReplayOf != first.ID || again.Seed != first.Seed || again.ArenaID != first.ArenaID {
		t.Fatalf("the replay did not reuse seed/arena: %+v vs %+v", again, first)
	}
	if again.WinnerTeam != first.WinnerTeam || again.Rounds != first.Rounds ||
		again.DecisionHash != first.DecisionHash {
		t.Errorf("replay differs: winner %d/%d rounds %d/%d hash %s/%s",
			first.WinnerTeam, again.WinnerTeam, first.Rounds, again.Rounds,
			first.DecisionHash[:12], again.DecisionHash[:12])
	}
	if first.Rounds < 1 || first.WinnerTeam < 0 || first.WinnerTeam > 1 {
		t.Errorf("the fight did not really happen: %+v", first)
	}
}

// fightGhost plays one fight against ghost gid (replaying fight replayOf when
// non-zero) with the AI on our side too, and returns its ghost_fights row.
func fightGhost(t *testing.T, c *testclient.Client, st *store.Store, gid, replayOf int64) domain.GhostFight {
	t.Helper()
	before, _ := st.Ghosts.FightsByGhost(uint(gid))
	c.DrainReceived(200 * time.Millisecond)
	_ = c.Send(3, protocol.OpGhostFight, testclient.NewW().I64(gid).I64(replayOf).Bytes())
	if _, _, err := c.WaitFor(testclient.OpCreateFight, testclient.DefaultTimeout); err != nil {
		t.Fatalf("ghost fight (replay of %d) did not start: %v", replayOf, err)
	}
	c.DrainReceived(200 * time.Millisecond)
	for _, op := range []uint16{testclient.OpReadyForPlacement, testclient.OpReadyForObservation} {
		_ = c.Send(3, op, nil)
		c.DrainReceived(300 * time.Millisecond)
	}
	_ = c.Send(3, testclient.OpReadyForAction, nil)
	if _, _, err := c.WaitFor(testclient.OpStartAction, testclient.DefaultTimeout); err != nil {
		t.Fatalf("no action phase: %v", err)
	}
	_ = c.Send(3, opUserVicinity, testclient.NewW().StrU16("/AUTOPILOT on").Bytes())
	if _, seen, err := c.WaitFor(testclient.OpEndFight, 120*time.Second); err != nil {
		counts := map[uint16]int{}
		for _, fr := range seen {
			counts[fr.Opcode]++
		}
		t.Fatalf("the ghost fight never ended: %v (frames seen: %v)", err, counts)
	}
	_ = c.Send(3, testclient.OpEndFightDone, nil)
	c.DrainReceived(500 * time.Millisecond)
	after, _ := st.Ghosts.FightsByGhost(uint(gid))
	if len(after) != len(before)+1 {
		t.Fatalf("ghost_fights rows %d → %d, want one more", len(before), len(after))
	}
	return after[0] // newest first
}
