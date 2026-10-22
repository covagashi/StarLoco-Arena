package e2e

import (
	"path/filepath"
	"testing"
	"time"

	"github.com/StarLoco/arena-2.70/internal/game"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/testclient"
)

// challengeLaunch builds the 26330 payload the client sends when a
// DemonChallenge bubble's "accept" or a BreedMaster's "test this breed" button
// is pressed: [i32 challengeId][i16 99]. Sent with arch 2.
func challengeLaunch(challengeID int32) []byte {
	return testclient.NewW().I32(challengeID).U16(99).Bytes()
}

// challengeServer starts a test server with the REAL challenge table and spell
// data loaded. Without them every challenge is refused, so a test using the bare
// harness would "pass" the refusal case for the wrong reason and could never
// exercise a successful launch.
func challengeServer(t *testing.T) string {
	t.Helper()
	st, err := gamedata.Open(filepath.Join("..", "..", "data-dist"))
	if err != nil {
		t.Skipf("game data not available: %v", err)
	}
	defs, err := st.LoadChallenges()
	if err != nil {
		t.Fatalf("LoadChallenges: %v", err)
	}
	spells, err := st.LoadSpells()
	if err != nil {
		t.Fatalf("LoadSpells: %v", err)
	}
	_, addr := testServerWithDeps(t, func(d *game.Deps) {
		d.ChallengeDefs = defs
		d.Spells = spells
	})
	return addr
}

// TestChallengeFightStarts: a single coach launches an overworld challenge and
// gets a real fight — CREATE_FIGHT(8000) — with no second client involved. This
// is the whole point of the challenge system: the opponent side is built by the
// server and is session-less, so one client is enough.
//
// Challenge 34 is the "Démon de la 58ème minute" on Totem Arena / world 79.
func TestChallengeFightStarts(t *testing.T) {
	t.Parallel()
	addr := challengeServer(t)
	c, _ := dialLogin(t, addr, "chal1", "Challenger1")
	reachWorld(t, c)

	if err := c.Send(2, testclient.OpTeamTest, challengeLaunch(34)); err != nil {
		t.Fatal(err)
	}
	if _, _, err := c.WaitFor(testclient.OpCreateFight, testclient.DefaultTimeout); err != nil {
		t.Fatalf("challenge 34 did not start a fight: %v", err)
	}
}

// TestBreedMasterChallengeFightStarts: the twelve world-35 breed masters use the
// same opcode with their own challenge id. Challenge 17 is the Iop master.
func TestBreedMasterChallengeFightStarts(t *testing.T) {
	t.Parallel()
	addr := challengeServer(t)
	c, _ := dialLogin(t, addr, "chal2", "Challenger2")
	reachWorld(t, c)

	if err := c.Send(2, testclient.OpTeamTest, challengeLaunch(17)); err != nil {
		t.Fatal(err)
	}
	if _, _, err := c.WaitFor(testclient.OpCreateFight, testclient.DefaultTimeout); err != nil {
		t.Fatalf("breed-master challenge 17 did not start a fight: %v", err)
	}
}

// TestUnknownChallengeIsRefused: an id absent from the type-400 table must come
// back as FIGHT_CREATION_ERROR(26310), never silence. By the time the client
// sends 26330 it has already armed its fight handlers, so dropping the message
// would leave it waiting forever with no way out.
func TestUnknownChallengeIsRefused(t *testing.T) {
	t.Parallel()
	addr := challengeServer(t)
	c, _ := dialLogin(t, addr, "chal3", "Challenger3")
	reachWorld(t, c)

	if err := c.Send(2, testclient.OpTeamTest, challengeLaunch(31337)); err != nil {
		t.Fatal(err)
	}
	f, _, err := c.WaitFor(testclient.OpFightCreationError, testclient.DefaultTimeout)
	if err != nil {
		t.Fatalf("unknown challenge was not refused: %v", err)
	}
	// [i64 fightId][i8 errorCode]
	r := testclient.NewR(f.Payload)
	_ = r.I64()
	if code := r.U8(); code == 0 {
		t.Errorf("refusal error code = %d, want a non-zero reason", code)
	}
}

// TestChallengeFightUsesTitularRoster: a challenge launch carries no teamId, so
// the server must field the coach's TITULAR line-up rather than a single
// fighter. Regression guard — the first implementation asked for team preset id
// 0, which never exists, and silently sent one fighter against a demon team.
func TestChallengeFightUsesTitularRoster(t *testing.T) {
	t.Parallel()
	addr := challengeServer(t)
	c, _ := dialLogin(t, addr, "chal5", "Challenger5")
	reachWorld(t, c)

	// Give the coach three titular fighters (state 0 is the creation default).
	// FighterCreate: [u8 flag][i16 slot][i16 blobLen][blob].
	for i := 0; i < 3; i++ {
		blob := buildFighterBlob("Champ", uint8(i+1))
		req := testclient.NewW().U8(0).U16(uint16(i)).U16(uint16(len(blob))).Raw(blob).Bytes()
		_ = c.Send(3, testclient.OpFighterCreate, req)
		if _, _, err := c.WaitFor(testclient.OpFighterCreateResult, testclient.DefaultTimeout); err != nil {
			t.Fatalf("fighter %d not created: %v", i, err)
		}
	}
	c.DrainReceived(150 * time.Millisecond)

	if err := c.Send(2, testclient.OpTeamTest, challengeLaunch(34)); err != nil {
		t.Fatal(err)
	}
	f, _, err := c.WaitFor(testclient.OpCreateFight, testclient.DefaultTimeout)
	if err != nil {
		t.Fatalf("challenge did not start: %v", err)
	}
	// The coach must field more than the single-fighter fallback. Counting
	// fighters in the 8000 blob is brittle, so assert on the cheap proxy: the
	// frame grows with each fighter the blob carries.
	if len(f.Payload) < 200 {
		t.Errorf("CREATE_FIGHT payload = %d bytes, too small to carry a multi-fighter team",
			len(f.Payload))
	}
}

// TestChallengeFightIsPlayable drives the challenge fight through every phase
// gate to the action phase with a SINGLE client. The opponent team is
// session-less, so the engine must pre-mark it ready in all three gates —
// otherwise the fight would stall at presentation forever.
func TestChallengeFightIsPlayable(t *testing.T) {
	t.Parallel()
	if raceEnabled {
		t.Skip("timing-sensitive full-fight E2E; flaky under -race's slowdown")
	}
	addr := challengeServer(t)
	c, _ := dialLogin(t, addr, "chal4", "Challenger4")
	reachWorld(t, c)

	if err := c.Send(2, testclient.OpTeamTest, challengeLaunch(35)); err != nil {
		t.Fatal(err)
	}
	if _, _, err := c.WaitFor(testclient.OpCreateFight, testclient.DefaultTimeout); err != nil {
		t.Fatalf("challenge 35 did not start: %v", err)
	}
	c.DrainReceived(200 * time.Millisecond)

	for _, op := range []uint16{
		testclient.OpReadyForPlacement,
		testclient.OpReadyForObservation,
	} {
		_ = c.Send(3, op, nil)
		c.DrainReceived(300 * time.Millisecond)
	}
	_ = c.Send(3, testclient.OpReadyForAction, nil)

	// START_ACTION(8040) only arrives once BOTH teams are ready — proving the
	// session-less challenge team was auto-readied.
	if _, _, err := c.WaitFor(testclient.OpStartAction, testclient.DefaultTimeout); err != nil {
		t.Fatalf("challenge fight never reached the action phase: %v", err)
	}
}
