package game

import (
	"bytes"
	"compress/gzip"
	"encoding/binary"
	"io"
	"testing"
	"time"

	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// offlineRig is a schedule rig on a classic definition (1) whose coaches each
// saved a ghost: a filler line-up, owned by them.
func offlineRig(t *testing.T, n int) *schedRig {
	t.Helper()
	r := newSchedRig(t, 1, n, nil)
	r.d.OfflineTournaments = true
	spells, err := openRealGameData(t).LoadSpells()
	if err != nil {
		t.Fatalf("LoadSpells: %v", err)
	}
	r.d.Spells = spells
	for i, id := range r.coaches {
		g := r.d.fillerGhost(i)
		g.CoachID = id
		if err := r.st.Ghosts.Create(g); err != nil {
			t.Fatalf("ghost: %v", err)
		}
	}
	return r
}

// replayFrames unpacks a stored recording into its opcodes.
func replayFrames(t *testing.T, blob []byte) []uint16 {
	t.Helper()
	zr, err := gzip.NewReader(bytes.NewReader(blob))
	if err != nil {
		t.Fatalf("gzip: %v", err)
	}
	raw, err := io.ReadAll(zr)
	if err != nil {
		t.Fatalf("gunzip: %v", err)
	}
	if len(raw) < 9 || string(raw[:4]) != "SLRP" || raw[4] != 1 {
		t.Fatalf("not an SLRP v1 file: % x", raw[:min(9, len(raw))])
	}
	at := 9 + int(binary.BigEndian.Uint32(raw[5:9]))
	var ops []uint16
	for at+10 <= len(raw) {
		op := binary.BigEndian.Uint16(raw[at+4 : at+6])
		n := int(binary.BigEndian.Uint32(raw[at+6 : at+10]))
		at += 10 + n
		ops = append(ops, op)
	}
	if at != len(raw) {
		t.Fatalf("trailing bytes: frame walk ended at %d of %d", at, len(raw))
	}
	return ops
}

// TestOfflineTournamentPlaysTheWholeBracket (S29): once the draw is fixed, one
// tick plays all three fixtures of a four-coach bracket AI against AI with
// nobody online, records each as a replay that opens on CREATE_FIGHT and ends
// on END_FIGHT, finishes the edition and pays the winner; no real coach is
// ever left in a fight, and a second tick changes nothing.
func TestOfflineTournamentPlaysTheWholeBracket(t *testing.T) {
	r := offlineRig(t, 4)
	tid := r.tr.WireID()
	r.d.TickTournaments() // before the draw: nothing
	if ms, _ := r.st.Tournaments.Matches(tid); len(ms) != 0 {
		t.Fatalf("played %d fixtures before the draw", len(ms))
	}

	r.at(time.Minute)
	start := time.Now()
	r.d.TickTournaments()
	t.Logf("bracket played in %s", time.Since(start).Round(time.Millisecond))

	got := r.reload(t)
	if got.FinishedAt == nil || got.WinnerCoachID == 0 {
		t.Fatalf("edition not finished: %+v", got)
	}
	ms, err := r.st.Tournaments.Matches(tid)
	if err != nil || len(ms) != 3 {
		t.Fatalf("%d fixtures recorded (%v), want 3", len(ms), err)
	}
	// Matches lists the first round first, so the final is last. With four
	// entrants it is played for slot 4; byes carry the winner on to slot 1.
	final := ms[len(ms)-1]
	if final.WinnerCoachID != got.WinnerCoachID {
		t.Errorf("final won by %d, edition winner %d", final.WinnerCoachID, got.WinnerCoachID)
	}
	for _, m := range ms {
		full, _ := r.st.Tournaments.Match(tid, m.Slot)
		ops := replayFrames(t, full.Replay)
		if ops[0] != protocol.OpCreateFight || ops[len(ops)-1] != protocol.OpEndFight {
			t.Errorf("slot %d: replay runs %d → %d over %d frames, want 8000 → 8300",
				m.Slot, ops[0], ops[len(ops)-1], len(ops))
		}
		if m.WinnerName == "" || m.LoserName == "" || m.Rounds < 1 {
			t.Errorf("slot %d: %+v", m.Slot, m)
		}
		t.Logf("slot %d: %s beat %s in %d rounds, %d frames, %d bytes",
			m.Slot, m.WinnerName, m.LoserName, m.Rounds, len(ops), len(full.Replay))
	}
	if tokenBalance(t, r.d, got.WinnerCoachID) != tournamentWinTokens {
		t.Errorf("winner holds %d tokens, want the %d prize", tokenBalance(t, r.d, got.WinnerCoachID), tournamentWinTokens)
	}
	for _, id := range r.coaches {
		if r.d.Fights.ByCoach(id) != nil {
			t.Errorf("coach %d is left inside a fight", id)
		}
	}
	r.d.TickTournaments()
	if again, _ := r.st.Tournaments.Matches(tid); len(again) != 3 {
		t.Errorf("a second tick recorded %d fixtures", len(again))
	}
}

// TestOfflineFixtureWithoutAGhostIsAWalkover: a coach who deleted its ghost
// loses its fixture without a fight; registration asks for one up front.
func TestOfflineFixtureWithoutAGhostIsAWalkover(t *testing.T) {
	r := offlineRig(t, 2)
	g, _ := r.st.Ghosts.LatestByCoach(r.coaches[0])
	if err := r.st.Ghosts.Delete(g.ID); err != nil {
		t.Fatal(err)
	}
	r.at(time.Minute)
	r.d.TickTournaments()
	got := r.reload(t)
	if got.WinnerCoachID != r.coaches[1] {
		t.Errorf("winner %d, want the coach that still has a ghost (%d)", got.WinnerCoachID, r.coaches[1])
	}
	if ms, _ := r.st.Tournaments.Matches(r.tr.WireID()); len(ms) != 0 {
		t.Errorf("a walkover recorded %d replays", len(ms))
	}
}

// TestOfflineRegistrationNeedsAGhost: 4607 on a classic tournament without a
// ghost answers 28608 code 3, and does not register.
func TestOfflineRegistrationNeedsAGhost(t *testing.T) {
	r := newSchedRig(t, 1, 0, nil)
	r.d.OfflineTournaments = true
	s := tmSession(r.d, 0, "Nadie")
	acc, _ := r.st.Accounts.CreateAccount("nadie", "pw", false)
	c, _ := r.st.Coaches.Create(acc.ID, "Nadie", 0, 0, 0)
	s.Coach = c
	p := protocol.NewWriter().I64(r.tr.WireID()).I64(int64(c.ID)).U16(0xFFFF).I32(0).Bytes()
	if err := handleTournamentRegister(s, &protocol.C2SFrame{Payload: p}); err != nil {
		t.Fatal(err)
	}
	reply := drainPayload(t, s, protocol.OpTournamentRegisterReply)
	if len(reply) != 9 || reply[8] != regNeedsGhost {
		t.Errorf("28608 = % x, want code %d", reply, regNeedsGhost)
	}
	if r.d.Tournaments.IsRegistered(c.ID, r.tr.WireID()) {
		t.Error("registered without a ghost")
	}
}
