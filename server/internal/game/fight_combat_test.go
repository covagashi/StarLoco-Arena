package game

import (
	"io"
	"log/slog"
	"testing"
)

func testLogger() *slog.Logger {
	return slog.New(slog.NewTextHandler(io.Discard, nil))
}

// TestRunningEffectLayout verifies the 2.70 8120 wire layout:
// header(8) + mustExec(1) + triggered(1) + Nx(4) + effId(4) + blobLen(2) + blob.
// The blob is the Ankama part-serialized form (aJj.ad): [i8 numParts] +
// numParts×{[i8 idx][i32 off]} + per-part [i8 idx][payload]. For an HP-loss /
// AP-use / MP-use effect (parts 0/1/2, sizes 34/8/8) the blob is
// 1 + 3*5 + (1+34) + (1+8) + (1+8) = 69 bytes.
func TestRunningEffectLayout(t *testing.T) {
	frame, err := buildRunningEffect(1, 9, 7, 100, 200, Pos{X: 5, Y: 6, Z: 1}, 250, 0, false)
	if err != nil {
		t.Fatalf("buildRunningEffect: %v", err)
	}
	// frame = [u16 len][u16 op][payload]. payload = 8+1+1+4+4+2+69 = 89 bytes.
	payload := frame[4:]
	if len(payload) != 89 {
		t.Fatalf("payload len = %d, want 89", len(payload))
	}
	be32 := func(b []byte) uint32 {
		return uint32(b[0])<<24 | uint32(b[1])<<16 | uint32(b[2])<<8 | uint32(b[3])
	}
	be64 := func(b []byte) uint64 { return uint64(be32(b))<<32 | uint64(be32(b[4:])) }
	// Outer running-effect id at payload[14:18].
	if id := be32(payload[14:18]); id != 9 {
		t.Errorf("runningEffectId = %d, want 9", id)
	}
	// blobLen at payload[18:20] should be 69.
	if blobLen := uint16(payload[18])<<8 | uint16(payload[19]); blobLen != 69 {
		t.Fatalf("blobLen = %d, want 69", blobLen)
	}
	blob := payload[20:]
	if blob[0] != 3 {
		t.Fatalf("numParts = %d, want 3", blob[0])
	}
	// Part 0 payload begins after [count(1) + dir(15) + part0 idx byte(1)] = 17.
	// Layout: [i64 caster][i64 target][i32 genericId][x][y][z][i32 value].
	p0 := blob[17:]
	if c := be64(p0[0:8]); c != 100 {
		t.Errorf("part0 caster = %d, want 100", c)
	}
	if tg := be64(p0[8:16]); tg != 200 {
		t.Errorf("part0 target = %d, want 200", tg)
	}
	if v := be32(p0[30:34]); v != 250 {
		t.Errorf("part0 value = %d, want 250", v)
	}
	// Part 2 (target fighter) block: idx byte at blob[60], id at blob[61:69].
	if tg := be64(blob[61:69]); tg != 200 {
		t.Errorf("part2 target = %d, want 200", tg)
	}
}

// TestEndFightLayout verifies the 2.70 8300 layout carries the winners'/losers'
// per-coach ladder strength maps (bA/bB) the client reads to update Level/Rank.
func TestEndFightLayout(t *testing.T) {
	frame, err := buildEndFight(1, []endFightCoach{{ID: 10, Strength: 1525}}, []endFightCoach{{ID: 20, Strength: 1475}})
	if err != nil {
		t.Fatalf("buildEndFight: %v", err)
	}
	payload := frame[4:]
	be32 := func(b []byte) uint32 {
		return uint32(b[0])<<24 | uint32(b[1])<<16 | uint32(b[2])<<8 | uint32(b[3])
	}
	be64 := func(b []byte) uint64 { return uint64(be32(b))<<32 | uint64(be32(b[4:])) }

	if payload[8] != 0 {
		t.Errorf("flee byte = %d, want 0", payload[8])
	}
	// Winners strength map: count 1, then {coachId 10, strength 1525}.
	if c := be32(payload[9:13]); c != 1 {
		t.Fatalf("winners strength-map count = %d, want 1", c)
	}
	if id := be64(payload[13:21]); id != 10 {
		t.Errorf("winner coachId = %d, want 10", id)
	}
	if s := be32(payload[21:25]); s != 1525 {
		t.Errorf("winner strength = %d, want 1525", s)
	}
	// Losers strength map: count 1, then {coachId 20, strength 1475}.
	if c := be32(payload[25:29]); c != 1 {
		t.Fatalf("losers strength-map count = %d, want 1", c)
	}
	if id := be64(payload[29:37]); id != 20 {
		t.Errorf("loser coachId = %d, want 20", id)
	}
	if s := be32(payload[37:41]); s != 1475 {
		t.Errorf("loser strength = %d, want 1475", s)
	}
	// bw winner list count follows the two maps.
	if payload[41] != 1 {
		t.Errorf("winner list count = %d, want 1", payload[41])
	}
}

// TestCheckFightEndDeclaresWinner: killing one team's fighters ends the fight
// with the other team as winner and records stats.
func TestCheckFightEndDeclaresWinner(t *testing.T) {
	f := buildTestFight()
	f.setPhase(PhaseAction)
	d := &Deps{Fights: NewFightManager(), World: NewRegistry(150), Log: testLogger()}
	d.Fights.Create(f)

	// Kill team B (side 1).
	for _, ff := range f.allFighters() {
		if ff.TeamID == 1 {
			ff.HP = 0
		}
	}
	d.checkFightEnd(f)

	if f.Phase() != PhaseEnded {
		t.Error("fight should be ended")
	}
	// Team A coach should have a win recorded.
	if f.Teams[0].Coach().StatWins != 1 {
		t.Errorf("winner StatWins = %d, want 1", f.Teams[0].Coach().StatWins)
	}
	if f.Teams[1].Coach().StatLosses != 1 {
		t.Errorf("loser StatLosses = %d, want 1", f.Teams[1].Coach().StatLosses)
	}
	// Ranked ladder: an unranked (0) winner seeds to 1000 then +25 = 1025; the
	// loser seeds to 1000 then -25 = 975 -> clamped to the 1000 floor.
	if f.Teams[0].Coach().Strength != 1025 {
		t.Errorf("winner Strength = %d, want 1025", f.Teams[0].Coach().Strength)
	}
	if f.Teams[1].Coach().Strength != 1000 {
		t.Errorf("loser Strength = %d, want 1000 (clamped floor)", f.Teams[1].Coach().Strength)
	}
}

// TestEvolutionFightLeavesStrength: Evolution is the story mode, so a won or
// lost evolution fight records the stats but never moves the ranking (S20).
func TestEvolutionFightLeavesStrength(t *testing.T) {
	f := buildTestFight()
	f.Evolution = true
	f.setPhase(PhaseAction)
	d := &Deps{Fights: NewFightManager(), World: NewRegistry(150), Log: testLogger()}
	d.Fights.Create(f)
	f.Teams[0].Coach().Strength = 1500
	f.Teams[1].Coach().Strength = 1500
	for _, ff := range f.allFighters() {
		if ff.TeamID == 1 {
			ff.HP = 0
		}
	}
	d.checkFightEnd(f)

	if f.Phase() != PhaseEnded {
		t.Fatal("fight should be ended")
	}
	if f.Teams[0].Coach().StatWins != 1 || f.Teams[1].Coach().StatLosses != 1 {
		t.Errorf("stats not recorded: wins=%d losses=%d",
			f.Teams[0].Coach().StatWins, f.Teams[1].Coach().StatLosses)
	}
	for i, want := range []int{1500, 1500} {
		if got := int(f.Teams[i].Coach().Strength); got != want {
			t.Errorf("team %d Strength = %d, want %d (evolution must not move it)", i, got, want)
		}
	}
}
