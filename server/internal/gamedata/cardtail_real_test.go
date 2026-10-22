package gamedata

import (
	"math"
	"os"
	"path/filepath"
	"testing"
)

// TestCoachCardTailReal locks fields 19-26 — the tail that was unreachable until
// the `np_1` element layout was decoded (see parameters.go).
//
// The headline assertion is ZERO RESIDUAL: every one of the 907 records must be
// consumed exactly, with no bytes left over and no short read. A record format
// that ends precisely where the decoder stops, 907 times out of 907, is not a
// coincidence — it is the strongest evidence available that the layout is right.
func TestCoachCardTailReal(t *testing.T) {
	if _, err := os.Stat(filepath.Join(clientBdataDir, "data.bdat")); err != nil {
		t.Skip("no client data")
	}
	st, err := Open(clientBdataDir)
	if err != nil {
		t.Fatal(err)
	}

	var total, exact, withParams, inlineEffects, pets int
	slots := map[uint8]int{}
	for _, e := range st.EntriesOf(TypeCoachCard) {
		rec, err := st.ReadRecord(e.Position)
		if err != nil {
			continue
		}
		total++
		c := &cur{b: rec.Data}
		card, err := decodeCoachCardCursor(c)
		if err != nil || card == nil {
			t.Errorf("card at %d failed to decode: %v", e.Position, err)
			continue
		}
		if c.err {
			t.Errorf("card %d: short read", card.ID)
			continue
		}
		if resid := len(rec.Data) - c.pos; resid != 0 {
			t.Errorf("card %d: %d byte(s) left over — the tail layout is wrong", card.ID, resid)
			continue
		}
		exact++
		if len(card.Parameters) > 0 {
			withParams++
		}
		for _, p := range card.Parameters {
			if p.HasEffect() {
				inlineEffects++
			}
		}
		if card.PetModelID != 0 {
			pets++
		}
		if card.ColourSlot != 0 || card.ColourIndex != 0 {
			slots[card.ColourSlot]++
		}
	}

	if total != 907 {
		t.Errorf("read %d coach cards, want 907", total)
	}
	if exact != total {
		t.Errorf("only %d/%d records consumed exactly", exact, total)
	}
	if withParams != 282 {
		t.Errorf("%d cards carry np_1 parameters, want 282", withParams)
	}

	// No shipped parameter carries a trailing inline effect. That matters: such
	// an effect has no length prefix, so it cannot be skipped — decodeParameters
	// bails out rather than desynchronise. If this ever trips, that guard has
	// started firing on real data and needs a full inline Ht parser.
	if inlineEffects != 0 {
		t.Errorf("%d parameters carry an inline Ht effect; decodeParameters cannot skip those", inlineEffects)
	}

	// Cross-check against a completely independent source: the client ships
	// exactly seven pet descriptions (i18n content.24.71/75/80/88/92/99/103,
	// "Ce familier Augmente les drops dans tous les modes de jeu"), and exactly
	// seven cards carry a pet model id.
	if pets != 7 {
		t.Errorf("%d cards have a pet model id, want 7 (one per shipped pet)", pets)
	}

	// Colouring cards: slot 0 hair, 1 skin, 2 eyes (client setFighterColorIndex).
	for slot, want := range map[uint8]int{0: 10, 1: 10, 2: 3} {
		if slots[slot] != want {
			t.Errorf("colour slot %d has %d cards, want %d", slot, slots[slot], want)
		}
	}
}

// TestParameterLayoutSizing checks decodeParameters against the client's own
// size function, `np_1.nj()` = 13 + 4*len(params) + 2 (no effect). If the two
// ever disagree, one of them has a field the other does not.
func TestParameterLayoutSizing(t *testing.T) {
	// [count=1][type][id][parent][n=3][p0][p1][p2][effectVersion=0]
	w := []byte{1}
	put32 := func(v int32) { w = append(w, byte(v>>24), byte(v>>16), byte(v>>8), byte(v)) }
	put32(900)
	put32(42)
	put32(7)
	w = append(w, 3)
	put32(11)
	put32(22)
	put32(33)
	w = append(w, 0, 0) // effectVersion = 0

	c := &cur{b: w}
	got, ok := decodeParameters(c)
	if !ok {
		t.Fatal("decodeParameters reported failure on a well-formed element")
	}
	if len(got) != 1 {
		t.Fatalf("decoded %d parameters, want 1", len(got))
	}
	p := got[0]
	if p.Type != 900 || p.ID != 42 || p.ParentID != 7 {
		t.Errorf("header = type %d id %d parent %d, want 900/42/7", p.Type, p.ID, p.ParentID)
	}
	if len(p.Params) != 3 || p.Params[0] != 11 || p.Params[2] != 33 {
		t.Errorf("params = %v, want [11 22 33]", p.Params)
	}
	if p.HasEffect() {
		t.Error("element reported an effect it does not carry")
	}
	// The element must consume exactly nj() = 13 + 4*3 + 2 = 27 bytes, after the
	// leading count byte.
	if want := 1 + 13 + 4*3 + 2; c.pos != want {
		t.Errorf("consumed %d bytes, want %d (np_1.nj() + count byte)", c.pos, want)
	}
}

// buildHt assembles a complete, well-formed Ht effect blob — every field through
// to the two trailing flags. Used to prove decodeEffectCursor consumes an inline
// effect EXACTLY, which is what makes an np_1 carrying one skippable at all.
func buildHt(effectID, actionID int32, params []float32) []byte {
	var b []byte
	put32 := func(v int32) { b = append(b, byte(v>>24), byte(v>>16), byte(v>>8), byte(v)) }
	putArr := func(n int32) { put32(n) } // empty array = just a zero count
	put32(effectID)
	put32(actionID)
	put32(0) // parentId
	put32(4) // parentType length
	b = append(b, "SPEL"...)
	put32(1)                     // areaShape
	b = append(b, 0, 0)          // areaOrdering (i16)
	b = append(b, 0, 0, 0, 0, 1) // 5 bools; the last is isCritical
	put32(int32(len(params)))
	for _, f := range params {
		bits := math.Float32bits(f)
		b = append(b, byte(bits>>24), byte(bits>>16), byte(bits>>8), byte(bits))
	}
	for i := 0; i < 6; i++ { // triggersBefore/After/end/vestigial/areaSize/duration
		putArr(0)
	}
	putArr(0)           // targets (i64 array)
	b = append(b, 0, 1) // the two trailing flags
	return b
}

// TestParameterInlineEffect pins the case that used to stop the decoder dead:
// an np_1 whose trailing Ht is INLINE and carries no length prefix. The only way
// past it is to parse it exactly, so this asserts both the decode AND the cursor
// position — a byte out either way desynchronises the enclosing record.
func TestParameterInlineEffect(t *testing.T) {
	ht := buildHt(555, 42, []float32{7, 8})

	w := []byte{1}
	put32 := func(v int32) { w = append(w, byte(v>>24), byte(v>>16), byte(v>>8), byte(v)) }
	put32(12)           // type 12: "cast an effect on all fighters at fight creation"
	put32(1)            // id
	put32(0)            // parentId
	w = append(w, 0)    // no params
	w = append(w, 0, 1) // effectVersion = 1 -> an inline Ht follows
	put32(555)          // effect id
	w = append(w, ht...)
	w = append(w, 0xAB) // sentinel: must survive untouched

	c := &cur{b: w}
	got, ok := decodeParameters(c)
	if !ok {
		t.Fatal("decodeParameters failed on a well-formed inline effect")
	}
	if len(got) != 1 {
		t.Fatalf("decoded %d parameters, want 1", len(got))
	}
	p := got[0]
	if !p.HasEffect() || p.Effect == nil {
		t.Fatal("the inline effect was not captured")
	}
	if p.Effect.EffectID != 555 || p.Effect.ActionID != 42 {
		t.Errorf("effect = id %d action %d, want 555/42", p.Effect.EffectID, p.Effect.ActionID)
	}
	if len(p.Effect.Params) != 2 || p.Effect.Params[0] != 7 || p.Effect.Params[1] != 8 {
		t.Errorf("effect params = %v, want [7 8]", p.Effect.Params)
	}
	// THE ASSERTION THAT MATTERS: the cursor must sit exactly on the sentinel.
	if c.pos != len(w)-1 {
		t.Fatalf("consumed %d bytes, want %d — an inline effect must be consumed exactly",
			c.pos, len(w)-1)
	}
	if tail := c.u8(); tail != 0xAB {
		t.Errorf("sentinel = %#x, want 0xAB — the enclosing record is desynced", tail)
	}
}

// TestParameterTruncatedInlineEffect: a malformed/short inline effect must fail
// the decode rather than return junk, since we cannot know where it ended.
func TestParameterTruncatedInlineEffect(t *testing.T) {
	w := []byte{1}
	put32 := func(v int32) { w = append(w, byte(v>>24), byte(v>>16), byte(v>>8), byte(v)) }
	put32(12)
	put32(1)
	put32(0)
	w = append(w, 0)
	w = append(w, 0, 1)
	put32(555)
	w = append(w, 0xDE, 0xAD) // nowhere near a complete Ht

	c := &cur{b: w}
	if _, ok := decodeParameters(c); ok {
		t.Error("a truncated inline effect was accepted; it must fail the decode")
	}
}
