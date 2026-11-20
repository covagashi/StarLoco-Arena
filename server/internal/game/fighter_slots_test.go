package game

import (
	"log/slog"
	"path/filepath"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store/storetest"
)

// TestFighterSlots (S50, owner): 8 fighters of series, Historia and Élite
// together; each earned slot allows one more, up to 10.
func TestFighterSlots(t *testing.T) {
	st, err := storetest.Open(t, filepath.Join(t.TempDir(), "slots.db"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = st.Close() })
	acc, _ := st.Accounts.CreateAccount("slots", "pw", false)
	coach, _ := st.Coaches.Create(acc.ID, "Slots", 0, 0, 0)
	d := &Deps{Store: st, Log: slog.Default(), World: NewRegistry(50)}
	s := &Session{Coach: coach, deps: d, log: slog.Default(),
		out: make(chan []byte, 256), quit: make(chan struct{})}
	create := func() int {
		blob := encodeFighterBlob(&domain.Fighter{BreedID: 8, Name: "Slot"}, nil)
		w := protocol.NewWriter()
		w.U8(0)
		w.U16(0)
		w.U16(uint16(len(blob)))
		w.Raw(blob)
		if err := handleFighterCreate(s, &protocol.C2SFrame{Payload: w.Bytes()}); err != nil {
			t.Fatal(err)
		}
		fs, _ := st.Fighters.ListByCoach(coach.ID)
		return len(fs)
	}
	for i := 0; i < 9; i++ {
		create()
	}
	if n := create(); n != baseFighterSlots {
		t.Fatalf("%d fighters after ten creations, want %d (the series slots)", n, baseFighterSlots)
	}
	for i := 0; i < maxExtraFighterSlots+1; i++ {
		_, _ = d.grantFighterSlot(coach)
	}
	if got := fighterSlots(coach); got != baseFighterSlots+maxExtraFighterSlots {
		t.Errorf("slots = %d after three grants, want %d (capped)", got, baseFighterSlots+maxExtraFighterSlots)
	}
	for i := 0; i < 3; i++ {
		create()
	}
	if n := create(); n != baseFighterSlots+maxExtraFighterSlots {
		t.Errorf("%d fighters with every slot earned, want %d", n, baseFighterSlots+maxExtraFighterSlots)
	}
	reloaded, _ := st.Coaches.Get(coach.ID)
	if reloaded == nil || reloaded.ExtraFighterSlots != maxExtraFighterSlots {
		t.Errorf("stored extra slots = %v, want %d", reloaded, maxExtraFighterSlots)
	}
}
