package e2e

import (
	"context"
	"io"
	"log/slog"
	"net"
	"path/filepath"
	"testing"
	"time"

	"github.com/StarLoco/arena-2.70/internal/game"
	"github.com/StarLoco/arena-2.70/internal/store"
	"github.com/StarLoco/arena-2.70/internal/store/storetest"
	"github.com/StarLoco/arena-2.70/internal/testclient"
)

// testServer spins up an in-process server on a free port with a temp DB and
// returns its address. It shuts down when the test ends.
func testServer(t *testing.T) string {
	_, addr := testServerWithStore(t)
	return addr
}

// testServerWithStore is like testServer but also returns the store, for tests
// that verify persisted state (e.g. an exchange actually moved cards).
func testServerWithStore(t *testing.T) (*store.Store, string) {
	return testServerWithDeps(t, nil)
}

// testServerWithDeps is like testServerWithStore but lets a test customize the
// Deps before the server starts (e.g. inject a gamedata card catalog).
func testServerWithDeps(t *testing.T, customize func(*game.Deps)) (*store.Store, string) {
	t.Helper()

	dbPath := filepath.Join(t.TempDir(), "e2e.db")
	st, err := storetest.Open(t, dbPath)
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })

	// Pick a free port.
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	addr := ln.Addr().String()
	_ = ln.Close()

	// The production turn clock is 30s while the fight tests wait 15s for a turn,
	// so a missed window was a GUARANTEED timeout rather than a slow pass: the next
	// FIGHTER_TURN_BEGIN cannot arrive until the current fighter's clock expires.
	// On a loaded machine that turned the three full-fight tests into rotating
	// false alarms. Shrinking the clock makes a missed window cost seconds, so the
	// tests measure behaviour instead of machine load.
	// Turn clock for e2e. It must satisfy two opposing constraints:
	//   - long enough that a test can act inside its OWN turn on a loaded machine
	//     (the server silently refuses a cast/move from a fighter whose turn has
	//     expired — the old 6s clock lost this race and made combat tests flaky);
	//   - short enough that a test waiting through a turn nobody ends still gets
	//     control back within its WaitForTurn budget.
	// Tests that need fast rotation should end their OTHER client's turns
	// explicitly (see TestCombatSpellDamage) rather than shrink this.
	// The turn clock is set ONCE for the whole package in TestMain, not per test:
	// it is a package-level global in internal/game, so a per-test override is a
	// data race the moment any test runs in parallel. Every test wanted the same
	// 12s anyway, so hoisting it costs nothing and unblocks t.Parallel().

	deps := &game.Deps{
		Store:       st,
		World:       game.NewRegistry(75),
		Exchanges:   game.NewExchangeManager(),
		Matchmaker:  game.NewMatchmaker(),
		Challenges:  game.NewChallengeManager(),
		Fights:      game.NewFightManager(),
		Sessions:    game.NewSessionRegistry(),
		Tournaments: game.NewTournamentManager(),
		Log:         slog.New(slog.NewTextHandler(io.Discard, nil)),
	}
	if customize != nil {
		customize(deps)
	}
	srv := game.NewServer(addr, deps)

	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	go func() { _ = srv.ListenAndServe(ctx) }()

	// Wait until the port accepts connections.
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		if c, err := net.Dial("tcp", addr); err == nil {
			_ = c.Close()
			return st, addr
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatal("server did not come up")
	return nil, ""
}

// dialLogin connects, logs in (auto-creating the account) and creates a coach,
// returning the client + coach id.
func dialLogin(t *testing.T, addr, login, coachName string) (*testclient.Client, int64) {
	t.Helper()
	c, err := testclient.Dial(addr)
	if err != nil {
		t.Fatalf("dial: %v", err)
	}
	t.Cleanup(func() { _ = c.Close() })

	if err := c.Login(login, "pw"); err != nil {
		t.Fatalf("login: %v", err)
	}
	id, err := c.CreateCoach(coachName)
	if err != nil {
		t.Fatalf("create coach: %v", err)
	}
	return c, id
}
