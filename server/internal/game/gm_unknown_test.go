package game

import (
	"strings"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// TestUnknownCommandUsesTranslatedFrame: an unrecognised slash-command used to
// answer with the invented English string "unknown command: X", shown verbatim
// in a German client. Retail has a translated frame for exactly this - 3206,
// error.chat.malformedCommand -> "Commande incorrecte." - and it was already
// wired for the bare-slash case.
func TestUnknownCommandUsesTranslatedFrame(t *testing.T) {
	d := tmDeps()
	d.Log = testLogger()
	s := tmSession(d, 1, "Admin")
	s.Account = &domain.Account{ID: 1, Name: "Admin", IsAdmin: true}

	if err := handleGMCommand(s, "/zzzznotacommand"); err != nil {
		t.Fatalf("handleGMCommand: %v", err)
	}
	ops := drain(t, s)
	found := false
	for _, op := range ops {
		if op == protocol.OpChatErrMalformedCommand {
			found = true
		}
	}
	if !found {
		t.Errorf("got opcodes %v, want %d (3206) among them",
			ops, protocol.OpChatErrMalformedCommand)
	}
}

// TestUnknownCommandSendsNoInventedText is the other half: no server-authored
// English may reach the player for this case. A frame AND a text line would be
// worse than either alone.
func TestUnknownCommandSendsNoInventedText(t *testing.T) {
	d := tmDeps()
	d.Log = testLogger()
	s := tmSession(d, 1, "Admin")
	s.Account = &domain.Account{ID: 1, Name: "Admin", IsAdmin: true}

	if err := handleGMCommand(s, "/zzzznotacommand"); err != nil {
		t.Fatalf("handleGMCommand: %v", err)
	}
	for _, frame := range drainFrames(t, s) {
		if strings.Contains(string(frame), "unknown command") {
			t.Error("the invented English string is still being sent")
		}
	}
}

// drainFrames returns the raw frames queued on a session.
func drainFrames(t *testing.T, s *Session) [][]byte {
	t.Helper()
	var out [][]byte
	for {
		select {
		case f := <-s.out:
			out = append(out, f)
		default:
			return out
		}
	}
}

// TestArenaPin: /ARENA pins only a loaded arena, 0 clears it, and a pinned
// session's practice fights would use it.
func TestArenaPin(t *testing.T) {
	d := tmDeps()
	d.Log = testLogger()
	d.arenas.cache = map[uint16]*arena{81: &practiceArena}
	d.arenas.ids = []uint16{81}
	s := tmSession(d, 1, "Admin")
	s.Account = &domain.Account{ID: 1, Name: "Admin", IsAdmin: true}

	_ = handleGMCommand(s, "/ARENA 999")
	if s.gmArena != 0 {
		t.Fatalf("pinned an arena that is not loaded: %d", s.gmArena)
	}
	_ = handleGMCommand(s, "/ARENA 81")
	if s.gmArena != 81 {
		t.Fatalf("pin = %d, want 81", s.gmArena)
	}
	_ = handleGMCommand(s, "/ARENA 0")
	if s.gmArena != 0 {
		t.Fatalf("pin = %d after /ARENA 0, want 0", s.gmArena)
	}

	player := tmSession(d, 2, "Player")
	player.Account = &domain.Account{ID: 2, Name: "Player"}
	_ = handleGMCommand(player, "/ARENA 81")
	if player.gmArena != 0 {
		t.Error("a non-admin pinned an arena")
	}
}
