package game

import (
	"path/filepath"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store/storetest"
)

func cosmeticSession(t *testing.T) (*Session, *Deps) {
	t.Helper()
	st, err := storetest.Open(t, filepath.Join(t.TempDir(), "cosm.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })
	acc, _ := st.Accounts.CreateAccount("cz", "pw", false)
	c, _ := st.Coaches.Create(acc.ID, "Cosmo", 0, 0, 0)
	d := &Deps{Store: st, Fights: NewFightManager(), World: NewRegistry(150), Log: testLogger()}
	s := &Session{Coach: c, deps: d, log: testLogger(), out: make(chan []byte, 8), quit: make(chan struct{})}
	s.godot.Store(true)
	return s, d
}

// readCosmetics drains one 60043 and returns (shown, owned).
func readCosmetics(t *testing.T, s *Session) (int32, []int32) {
	t.Helper()
	if len(s.out) == 0 {
		t.Fatal("no 60043 sent")
	}
	r := protocol.NewReader(payloadOf(t, <-s.out, protocol.OpCosmetics))
	fx, _ := r.I32()
	n, _ := r.U8()
	var owned []int32
	for i := 0; i < int(n); i++ {
		id, _ := r.I32()
		owned = append(owned, id)
	}
	return fx, owned
}

func equip(s *Session, id int32) error {
	return handleCosmeticEquip(s, &protocol.C2SFrame{Payload: protocol.NewWriter().I32(id).Bytes()})
}

// A coach can only show a hair effect it owns; the choice is stored, and 0
// takes it off.
func TestCosmeticHairFxEquip(t *testing.T) {
	s, d := cosmeticSession(t)
	if err := equip(s, CosmeticHairFire); err != nil {
		t.Fatal(err)
	}
	if fx, owned := readCosmetics(t, s); fx != 0 || len(owned) != 0 {
		t.Fatalf("unowned effect: shown %d owned %v, want 0 / none", fx, owned)
	}
	_ = d.Store.Coaches.GrantCosmetic(s.Coach.ID, CosmeticHairFire)
	_ = d.Store.Coaches.GrantCosmetic(s.Coach.ID, CosmeticHairFire) // twice is fine
	_ = d.Store.Coaches.GrantCosmetic(s.Coach.ID, CosmeticHairGold)
	if err := equip(s, CosmeticHairFire); err != nil {
		t.Fatal(err)
	}
	fx, owned := readCosmetics(t, s)
	if fx != CosmeticHairFire || len(owned) != 2 || owned[0] != CosmeticHairFire || owned[1] != CosmeticHairGold {
		t.Fatalf("shown %d owned %v, want 1 / [1 4]", fx, owned)
	}
	again, _ := d.Store.Coaches.GetByName("Cosmo")
	if again.HairFx != CosmeticHairFire {
		t.Fatalf("stored hair effect = %d, want %d", again.HairFx, CosmeticHairFire)
	}
	_ = equip(s, CosmeticHairStorm) // not owned: stays on fire
	if fx, _ := readCosmetics(t, s); fx != CosmeticHairFire {
		t.Fatalf("unowned switch changed it to %d", fx)
	}
	_ = equip(s, 0)
	if fx, _ := readCosmetics(t, s); fx != 0 {
		t.Fatalf("0 left %d on", fx)
	}
}

// The cosmetics ride along with 60001, and only to the Godot client.
func TestCosmeticsWithClientConfig(t *testing.T) {
	s, d := cosmeticSession(t)
	_ = d.Store.Coaches.GrantCosmetic(s.Coach.ID, CosmeticHairFrost)
	s.godot.Store(false)
	if err := handleClientConfigRequest(s, nil); err != nil {
		t.Fatal(err)
	}
	<-s.out // 60001
	if _, owned := readCosmetics(t, s); len(owned) != 1 || owned[0] != CosmeticHairFrost {
		t.Fatalf("owned = %v, want [2]", owned)
	}
	retail := &Session{Coach: &domain.Coach{ID: s.Coach.ID}, deps: d, out: make(chan []byte, 2)}
	_ = retail.sendCosmetics(nil)
	if len(retail.out) != 0 {
		t.Fatal("a retail session was sent 60043")
	}
}

// /COSMETIC grants a known cosmetic and refuses anything else.
func TestGMCosmetic(t *testing.T) {
	s, d := cosmeticSession(t)
	s.Coach.Name = "Cosmo"
	_ = s.gmCosmetic([]string{"Cosmo", "9"})
	if got, _ := d.Store.Coaches.Cosmetics(s.Coach.ID); len(got) != 0 {
		t.Fatalf("unknown id granted: %v", got)
	}
	_ = s.gmCosmetic([]string{"Cosmo", "3"})
	if got, _ := d.Store.Coaches.Cosmetics(s.Coach.ID); len(got) != 1 || got[0] != CosmeticHairStorm {
		t.Fatalf("cosmetics = %v, want [3]", got)
	}
}
