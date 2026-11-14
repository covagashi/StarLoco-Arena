package e2e

import (
	"context"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/game"
	"github.com/StarLoco/arena-2.70/internal/testclient"
	"github.com/StarLoco/arena-2.70/internal/wsconn"
)

// testServerWS starts the e2e server and, on the same Deps, the WebSocket
// door the browser client uses (S44); it returns the ws:// URL.
func testServerWS(t *testing.T) string {
	t.Helper()
	var deps *game.Deps
	testServerWithDeps(t, func(d *game.Deps) { deps = d })
	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	ln, err := wsconn.Listen(ctx, "127.0.0.1:0")
	if err != nil {
		t.Fatalf("ws listen: %v", err)
	}
	srv := game.NewServer(ln.Addr().String(), deps)
	go func() { _ = srv.Serve(ctx, ln) }()
	return "ws://" + ln.Addr().String() + "/"
}

// TestLoginToWorldOverWebSocket: the browser's transport carries the same
// protocol — a fresh account logs in, creates its coach and reaches the
// world (EnterInstance 4600), as TestLoginToWorld does over TCP.
func TestLoginToWorldOverWebSocket(t *testing.T) {
	t.Parallel()
	url := testServerWS(t)

	c, err := testclient.DialWS(url)
	if err != nil {
		t.Fatalf("dial ws: %v", err)
	}
	defer c.Close()

	if err := c.Login("wsalice", "pw"); err != nil {
		t.Fatalf("login: %v", err)
	}
	coachID, err := c.CreateCoach("WsAlice")
	if err != nil {
		t.Fatalf("create coach: %v", err)
	}
	if coachID == 0 {
		t.Error("coach id should be non-zero")
	}
	if _, _, err := c.WaitFor(testclient.OpEnterInstance, testclient.DefaultTimeout); err != nil {
		t.Fatalf("did not reach world (4600) over WebSocket: %v", err)
	}
}
