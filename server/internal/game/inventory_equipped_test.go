package game

import (
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// TestInventoryPushListsEquippedCards: 5200's first section is the retail
// client's "equipped" list — rb_2 places each {i16 slot, wy_2 card} into the
// coach's 14-slot equipment container (sj_1.yD(), 0-based like 5201). It used to
// be sent empty, so a client that logged in never learned what its coach wore,
// and its next 5201 (which carries all 14 slots) stripped everything (B-179).
func TestInventoryPushListsEquippedCards(t *testing.T) {
	s, st := cardRuleFixture(t)
	s.out = make(chan []byte, writeQueueSize)
	s.quit = make(chan struct{})
	if err := st.DB().Create(&domain.CoachCard{CoachID: s.Coach.ID, TemplateID: 100, Quantity: 2}).Error; err != nil {
		t.Fatalf("seed: %v", err)
	}
	coach, _ := st.Coaches.Get(s.Coach.ID)
	var slots [14]int32
	slots[0] = 100 // the hat slot
	s.applyEquipment(coach, slots)
	coach, _ = st.Coaches.Get(s.Coach.ID)
	drainFrames(t, s)
	if err := s.pushInventory(coach); err != nil {
		t.Fatalf("pushInventory: %v", err)
	}
	var frame []byte
	for _, f := range drainFrames(t, s) {
		if len(f) > 4 && uint16(f[2])<<8|uint16(f[3]) == protocol.OpCoachInventoryUpdate {
			frame = f
		}
	}
	if frame == nil {
		t.Fatal("no 5200 sent")
	}
	r := protocol.NewReader(frame[4:])
	n, _ := r.U16()
	if n != 1 {
		t.Fatalf("equipped section has %d entries, want 1 (the hat)", n)
	}
	slotU, _ := r.U16()
	slot := int16(slotU)
	card, _ := r.I32()
	if slot != 0 || card != 100 {
		t.Errorf("equipped entry = slot %d card %d, want slot 0 card 100", slot, card)
	}
	if removed, _ := r.U16(); removed != 0 {
		t.Errorf("removed section has %d entries, want 0 (it also clears inventory positions)", removed)
	}
	inv, _ := r.U16()
	if inv != 1 {
		t.Fatalf("unequipped section has %d entries, want 1 (the second hat)", inv)
	}
	if id, _ := r.I32(); id != 100 {
		t.Errorf("unequipped card = %d, want 100", id)
	}
	if q, _ := r.U16(); q != 1 {
		t.Errorf("unequipped quantity = %d, want 1 (one of two is worn)", q)
	}
}
