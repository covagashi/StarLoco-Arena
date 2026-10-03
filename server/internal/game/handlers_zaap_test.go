package game

import (
	"path/filepath"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store"
)

// TestZaapClanIslandRefusalToasts25000: the clan-island Zaap (card 859) used by a
// coach whose clan holds no island must answer 25000 (`az`) with the client's
// noIsland code — a refusal it cannot predict, so it must not fail silently.
func TestZaapClanIslandRefusalToasts25000(t *testing.T) {
	st, err := store.Open(filepath.Join(t.TempDir(), "zaap.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })

	acc, _ := st.Accounts.CreateAccount("zaapA", "pw", false)
	coach, _ := st.Coaches.Create(acc.ID, "Coach", 0, 0, 0)
	if err := st.DB().Create(&domain.CoachCard{CoachID: coach.ID, TemplateID: clanIslandZaapCard, Quantity: 1}).Error; err != nil {
		t.Fatalf("grant card 859: %v", err)
	}
	if err := st.DB().Where("coach_id = ?", coach.ID).Find(&coach.Inventory).Error; err != nil {
		t.Fatalf("load inventory: %v", err)
	}

	d := &Deps{Store: st, Log: testLogger()}
	s := &Session{log: testLogger(), deps: d, out: make(chan []byte, writeQueueSize), quit: make(chan struct{}), Coach: coach}

	p := protocol.NewWriter().I32(clanIslandZaapCard).Bytes()
	if err := handleZaapTeleport(s, &protocol.C2SFrame{Payload: p}); err != nil {
		t.Fatalf("handleZaapTeleport: %v", err)
	}

	select {
	case fr := <-s.out:
		if len(fr) < 5 {
			t.Fatalf("short frame: %d bytes", len(fr))
		}
		if op := uint16(fr[2])<<8 | uint16(fr[3]); op != protocol.OpErrorNotice {
			t.Fatalf("opcode = %d, want %d", op, protocol.OpErrorNotice)
		}
		if fr[4] != protocol.FightErrNoIsland {
			t.Fatalf("code = %d, want %d", fr[4], protocol.FightErrNoIsland)
		}
	default:
		t.Fatal("no ErrorNotice(25000) frame emitted for the island-less Zaap use")
	}
}
