package handshake

import "testing"

// TestDecodeCoachCreationColorOrder verifies the wire order is
// [name][SKIN][HAIR][sex] -- the first color byte is skin, the second hair.
// A regression here silently swaps every created coach's colors.
func TestDecodeCoachCreationColorOrder(t *testing.T) {
	// payload: nameLen=3 "Bob", skin=0x11, hair=0x22, sex=0x01
	payload := []byte{3, 'B', 'o', 'b', 0x11, 0x22, 0x01}
	c, err := DecodeCoachCreation(payload)
	if err != nil {
		t.Fatalf("decode: %v", err)
	}
	if c.Name != "Bob" {
		t.Errorf("name = %q, want Bob", c.Name)
	}
	if c.SkinColor != 0x11 {
		t.Errorf("skin = %#x, want 0x11 (first color byte)", c.SkinColor)
	}
	if c.HairColor != 0x22 {
		t.Errorf("hair = %#x, want 0x22 (second color byte)", c.HairColor)
	}
	if c.Sex != 0x01 {
		t.Errorf("sex = %#x, want 0x01", c.Sex)
	}
}

// TestCoachInformationsLookOrder verifies the 2052 T-block emits SKIN then HAIR
// then sex, matching the client's look decoder.
func TestCoachInformationsLookOrder(t *testing.T) {
	frame, err := EncodeCoachInformations(Coach{ID: 1, Name: "X", SkinColor: 0x11, HairColor: 0x22, Sex: 1})
	if err != nil {
		t.Fatalf("encode: %v", err)
	}
	// frame = [u16 len][u16 op][payload]; payload = i64 id(8) + u8 nameLen(1) +
	// "X"(1) + skin + hair + sex ...
	p := frame[4:]
	// after id(8) + len(1) + name(1) = offset 10 is skin, 11 hair, 12 sex.
	if p[10] != 0x11 {
		t.Errorf("skin byte = %#x, want 0x11 (skin first)", p[10])
	}
	if p[11] != 0x22 {
		t.Errorf("hair byte = %#x, want 0x22 (hair second)", p[11])
	}
}

// TestCoachInformationsCarriesStanding: the 2052 descriptor must carry the
// coach's real evolution experience. It was hardcoded to 0, so the client — which
// derives the evolution LEVEL from this field (aet_0.nJ) — pinned every coach at
// level 1 however much it had earned.
//
// The field sits after the look block and the 0x100 tournament blob:
//
//	i64 id(8) + u8 nameLen(1) + name(1) + skin(1) + hair(1) + sex(1) + u16 look(2)
//	+ i32 tournamentPoints(4) + u16 ladderBlobLen(2) = offset 21, then i32 standing.
func TestCoachInformationsCarriesStanding(t *testing.T) {
	const want int32 = 0x0A0B0C0D
	frame, err := EncodeCoachInformations(Coach{ID: 1, Name: "X", Standing: want})
	if err != nil {
		t.Fatalf("encode: %v", err)
	}
	p := frame[4:]
	const off = 8 + 1 + 1 + 1 + 1 + 1 + 2 + 4 + 2
	if len(p) < off+4 {
		t.Fatalf("payload too short (%d bytes) to hold the standing field", len(p))
	}
	got := int32(uint32(p[off])<<24 | uint32(p[off+1])<<16 | uint32(p[off+2])<<8 | uint32(p[off+3]))
	if got != want {
		t.Errorf("standing on the wire = %#x, want %#x", got, want)
	}
}

// B-186: the 0x8 blob carries the 1v1 force as ladder type 1, the one place
// the client's lobby reads it from (aez_0.X → bi((byte)1)). It sits right
// before the trailing i32 adminRight.
func TestCoachInformationsCarriesLadderStrength(t *testing.T) {
	tail := func(c Coach) []byte {
		frame, err := EncodeCoachInformations(c)
		if err != nil {
			t.Fatalf("encode: %v", err)
		}
		p := frame[4:]
		return p[len(p)-4-4 : len(p)-4] // the 4 bytes before adminRight
	}
	ranked := tail(Coach{ID: 1, Name: "X", Strength: 1500})
	if want := []byte{1, ladderType1v1, 0x05, 0xDC}; string(ranked) != string(want) {
		t.Errorf("ranked 0x8 blob = %x, want %x", ranked, want)
	}
	frame, _ := EncodeCoachInformations(Coach{ID: 1, Name: "X"})
	p := frame[4:]
	if p[len(p)-5] != 0 {
		t.Errorf("an unranked coach sent %d ladder entries, want 0", p[len(p)-5])
	}
}

// TestCoachInformationsCarriesTournamentPoints: anV, the first field of the
// 0x100 blob, right after the look (offset 15). It was a hard 0 until S09.
func TestCoachInformationsCarriesTournamentPoints(t *testing.T) {
	const want int32 = 1234
	frame, err := EncodeCoachInformations(Coach{ID: 1, Name: "X", TournamentPoints: want})
	if err != nil {
		t.Fatalf("encode: %v", err)
	}
	p := frame[4:]
	const off = 8 + 1 + 1 + 1 + 1 + 1 + 2
	got := int32(uint32(p[off])<<24 | uint32(p[off+1])<<16 | uint32(p[off+2])<<8 | uint32(p[off+3]))
	if got != want {
		t.Errorf("tournament points on the wire = %d, want %d", got, want)
	}
}
