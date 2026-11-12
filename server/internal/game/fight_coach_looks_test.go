package game

import (
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// S35c: 60040 lists every coach of the fight with the cards it wears (5201's
// 0-based slots), skipping its unequipped stacks, then its hair effect (S37);
// a synthetic side has none.
func TestFightCoachLooksListsWornCards(t *testing.T) {
	a := &domain.Coach{ID: 7, HairFx: CosmeticHairStorm, Inventory: []domain.CoachCard{
		{TemplateID: 114, Pos: 1}, // hat
		{TemplateID: 200, Pos: 0}, // in the bag
		{TemplateID: 1, Pos: 9},   // cape
	}}
	f := &Fight{Teams: [2]*FightTeam{
		{ID: 0, Members: []*FightMember{{Coach: a}}},
		{ID: 1, Members: []*FightMember{{Coach: nil}}},
	}}
	frame, err := buildFightCoachLooks(f)
	if err != nil {
		t.Fatal(err)
	}
	r := protocol.NewReader(payloadOf(t, frame, protocol.OpFightCoachLooks))
	n, _ := r.U8()
	if n != 2 {
		t.Fatalf("coaches = %d, want 2", n)
	}
	id, _ := r.I64()
	m, _ := r.U8()
	if id != 7 || m != 2 {
		t.Fatalf("first coach = %d with %d cards, want 7 with 2", id, m)
	}
	want := [][2]int32{{0, 114}, {8, 1}}
	for _, w := range want {
		slot, _ := r.U8()
		card, _ := r.I32()
		if int32(slot) != w[0] || card != w[1] {
			t.Errorf("worn = slot %d card %d, want slot %d card %d", slot, card, w[0], w[1])
		}
	}
	if fx, _ := r.I32(); fx != CosmeticHairStorm {
		t.Errorf("hair effect = %d, want %d", fx, CosmeticHairStorm)
	}
	id, _ = r.I64()
	m, _ = r.U8()
	fx, _ := r.I32()
	if id != 0 || m != 0 || fx != 0 {
		t.Errorf("synthetic side = %d with %d cards, fx %d, want all 0", id, m, fx)
	}
	if r.Remaining() != 0 {
		t.Errorf("%d bytes left over", r.Remaining())
	}
}

// Only a session that asked 60000 (the Godot client) is sent 60040: the
// retail client doesn't know the opcode.
func TestFightCoachLooksOnlyToGodot(t *testing.T) {
	f := &Fight{Teams: [2]*FightTeam{{Members: []*FightMember{{Coach: &domain.Coach{ID: 1}}}}}}
	retail := &Session{out: make(chan []byte, 4), quit: make(chan struct{})}
	sendFightCoachLooks(f, retail)
	if len(retail.out) != 0 {
		t.Fatal("a retail session was sent 60040")
	}
	godot := &Session{out: make(chan []byte, 4), quit: make(chan struct{}), deps: &Deps{}}
	_ = handleClientConfigRequest(godot, nil)
	<-godot.out // the 60001 reply
	sendFightCoachLooks(f, godot)
	if len(godot.out) != 1 {
		t.Fatalf("a Godot session got %d frames, want 60040", len(godot.out))
	}
}
