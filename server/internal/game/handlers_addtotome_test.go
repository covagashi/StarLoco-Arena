package game

import (
	"path/filepath"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store"
)

// TestAddToTomeInscribesOwnedCard exercises the 5204 (ajm_2) "inscribe in
// grimoire" handler: the i32 is a TEMPLATE id (the wire carries no card uids),
// the client expects no reply, and only owned cards may be inscribed. The tome
// is grow-only, so a second inscription must be idempotent.
func TestAddToTomeInscribesOwnedCard(t *testing.T) {
	st, err := store.Open(filepath.Join(t.TempDir(), "tome.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })

	acc, _ := st.Accounts.CreateAccount("tomeA", "pw", false)
	coach, _ := st.Coaches.Create(acc.ID, "Coach", 0, 0, 0)

	if err := st.DB().Create(&domain.CoachCard{CoachID: coach.ID, TemplateID: 42, Quantity: 1}).Error; err != nil {
		t.Fatalf("grant card: %v", err)
	}
	if err := st.DB().Where("coach_id = ?", coach.ID).Find(&coach.Inventory).Error; err != nil {
		t.Fatalf("load inventory: %v", err)
	}

	d := &Deps{Store: st, Log: testLogger()}
	s := &Session{log: testLogger(), deps: d, out: make(chan []byte, writeQueueSize), quit: make(chan struct{}), Coach: coach}

	send := func(id int32) {
		t.Helper()
		p := protocol.NewWriter().I32(id).Bytes()
		if err := handleAddToTome(s, &protocol.C2SFrame{Payload: p}); err != nil {
			t.Fatalf("addToTome(%d): %v", id, err)
		}
	}
	inTome := func(id int32) bool {
		t.Helper()
		var n int64
		st.DB().Model(&domain.CoachTomeCard{}).Where("coach_id = ? AND template_id = ?", coach.ID, id).Count(&n)
		return n == 1
	}

	// Owned card → inscribed.
	send(42)
	if !inTome(42) {
		t.Fatal("owned card 42 was not recorded in the tome")
	}
	// Idempotent re-inscribe.
	send(42)
	var n int64
	st.DB().Model(&domain.CoachTomeCard{}).Where("coach_id = ? AND template_id = 42", coach.ID).Count(&n)
	if n != 1 {
		t.Fatalf("re-inscribe duplicated the tome row: %d rows", n)
	}
	// Negative id resolves by abs() like the client's Math.abs(jf) lookups:
	// grant a second card and inscribe it via -id.
	if err := st.DB().Create(&domain.CoachCard{CoachID: coach.ID, TemplateID: 7, Quantity: 1}).Error; err != nil {
		t.Fatalf("grant card 7: %v", err)
	}
	if err := st.DB().Where("coach_id = ?", coach.ID).Find(&coach.Inventory).Error; err != nil {
		t.Fatalf("reload inventory: %v", err)
	}
	send(-7)
	if !inTome(7) {
		t.Fatal("-7 did not resolve to template 7")
	}
	// Unowned template → refused, nothing recorded, no error (forged frame).
	send(999)
	if inTome(999) {
		t.Fatal("unowned card 999 was inscribed")
	}
	// Zero payload id → no-op.
	send(0)
	// The client expects no reply at all.
	select {
	case fr := <-s.out:
		t.Fatalf("unexpected S2C frame: %d bytes", len(fr))
	default:
	}
}
