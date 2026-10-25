package game

import (
	"encoding/binary"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// TestWorldElementsWellFormed guards the hand-transcribed env data in
// elements.go: every element must carry a payload, and env instanceIds are
// globally unique (the client keys its element manager by instanceId, so a
// duplicate would silently drop one element).
func TestWorldElementsWellFormed(t *testing.T) {
	seen := make(map[int64]int16)
	for world, elems := range worldElements {
		if len(elems) == 0 {
			t.Errorf("world %d: no elements", world)
		}
		for _, e := range elems {
			if len(e.payload) == 0 {
				t.Errorf("world %d element %d (%s): empty payload", world, e.instanceID, e.kind)
			}
			if prev, dup := seen[e.instanceID]; dup {
				t.Errorf("instanceId %d used by both world %d and world %d", e.instanceID, prev, world)
			}
			seen[e.instanceID] = world
			switch e.kind {
			case kindCardMaster, kindFusionLab:
				// These carry a descriptor argument (catalogue id / lab id) the
				// server needs; 0 would mean it was lost in transcription.
				if e.arg == 0 {
					t.Errorf("world %d element %d (%s): missing descriptor arg",
						world, e.instanceID, e.kind)
				}
			}
		}
	}
}

// TestEveryIslandHasCoreServices asserts each of the six main islands ships the
// services the island-map POI legend advertises and that we now spawn.
func TestEveryIslandHasCoreServices(t *testing.T) {
	for _, world := range []int16{23, 24, 25, 26, 27, 28} {
		kinds := make(map[elementKind]int)
		for _, e := range worldElements[world] {
			kinds[e.kind]++
		}
		for _, want := range []elementKind{kindZaap, kindCardMaster, kindFusionLab, kindMailbox, kindGraveyard} {
			if kinds[want] == 0 {
				t.Errorf("world %d: no %s spawned", world, want)
			}
		}
	}
}

// TestZaapCardDestinationsResolve asserts every routed Zaap card points at an
// element that actually exists AND is a Zaap — a typo would otherwise only show up
// as a dead card in-game.
func TestZaapCardDestinationsResolve(t *testing.T) {
	for card, dest := range zaapCardDest {
		z, ok := zaapAt(dest.world, dest.instanceID)
		if !ok {
			t.Errorf("card %d -> world %d zaap %d: no such Zaap", card, dest.world, dest.instanceID)
			continue
		}
		if z.kind != kindZaap {
			t.Errorf("card %d -> element %d is %s, not a zaap", card, dest.instanceID, z.kind)
		}
	}
}

// TestStarterZaapCardsAreRouted asserts we never grant a card that would do
// nothing when double-clicked.
func TestStarterZaapCardsAreRouted(t *testing.T) {
	for _, card := range starterZaapCards {
		if _, ok := zaapCardDest[card]; !ok {
			t.Errorf("starter card %d has no destination", card)
		}
	}
}

// TestZaapDestinationsCanBeLeft asserts nobody can be stranded: every world a Zaap
// CARD routes to, and indeed every world we spawn elements on at all, has a Zaap of
// its own to leave by. (It also means /WORLD lands on a known-walkable cell, since
// gmWorld defaults to the destination's primary Zaap.)
func TestZaapDestinationsCanBeLeft(t *testing.T) {
	for card, dest := range zaapCardDest {
		if _, ok := primaryZaap(dest.world); !ok {
			t.Errorf("card %d sends a coach to world %d, which has no Zaap to leave by",
				card, dest.world)
		}
	}
	for world := range worldElements {
		if _, ok := primaryZaap(world); !ok {
			t.Errorf("world %d has elements but no Zaap: a coach there would be stranded", world)
		}
	}
}

// TestBuildInteractiveElementSpawnEncodes checks the opcode-200 wire layout:
// [i16 count]{[i64 instanceId][i16 payloadLen][payload]}, with the payload copied
// verbatim.
func TestBuildInteractiveElementSpawnEncodes(t *testing.T) {
	a := mustElement(kindZaap, 37, 40, -20, 8, 0, "AABB")
	b := mustElement(kindCardMaster, 9, 94, 6, 2, 13, "CCDDEE")

	frame, err := buildInteractiveElementSpawn(a, b)
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	// Strip the S2C header: [u16 totalLen][u16 opcode].
	if got := binary.BigEndian.Uint16(frame[0:2]); int(got) != len(frame) {
		t.Errorf("totalLen = %d, want %d", got, len(frame))
	}
	if got := binary.BigEndian.Uint16(frame[2:4]); got != protocol.OpInteractiveElementSpawn {
		t.Errorf("opcode = %d, want %d", got, protocol.OpInteractiveElementSpawn)
	}
	p := frame[4:]

	if got := binary.BigEndian.Uint16(p[0:2]); got != 2 {
		t.Fatalf("count = %d, want 2", got)
	}
	if got := binary.BigEndian.Uint64(p[2:10]); got != 37 {
		t.Errorf("first instanceId = %d, want 37", got)
	}
	if got := binary.BigEndian.Uint16(p[10:12]); got != 2 {
		t.Errorf("first payloadLen = %d, want 2", got)
	}
	if got := p[12:14]; got[0] != 0xAA || got[1] != 0xBB {
		t.Errorf("first payload = % X, want AA BB", got)
	}
	if got := binary.BigEndian.Uint64(p[14:22]); got != 9 {
		t.Errorf("second instanceId = %d, want 9", got)
	}
	if got := binary.BigEndian.Uint16(p[22:24]); got != 3 {
		t.Errorf("second payloadLen = %d, want 3", got)
	}
}

// TestBuildShopCatalogStampsShopID asserts the clicking Card Master's catalogue id
// is stamped as the shopId (the client echoes it back on every purchase), that
// unpriced cards are excluded, and that a missing id falls back.
func TestBuildShopCatalogStampsShopID(t *testing.T) {
	cards := gamedata.NewCards(
		&gamedata.CoachCard{ID: 10, Price: map[uint8]int32{0: 5}},
		&gamedata.CoachCard{ID: 20}, // unpriced -> not sold
	)

	frame, err := buildShopCatalog(cards, 13, 0)
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	p := frame[4:] // strip [u16 len][u16 opcode]
	if p[0] != 0 {
		t.Errorf("mode = %d, want 0 (kardmaster tab)", p[0])
	}
	if got := int32(binary.BigEndian.Uint32(p[1:5])); got != 13 {
		t.Errorf("shopId = %d, want 13 (the element's cardListId)", got)
	}
	if len(p) != 5+6 {
		t.Fatalf("payload = %d bytes, want 11 (header + one 6-byte entry)", len(p))
	}
	if got := int32(binary.BigEndian.Uint32(p[5:9])); got != 10 {
		t.Errorf("card id = %d, want 10", got)
	}
	if got := binary.BigEndian.Uint16(p[9:11]); got != cardMasterStockQty {
		t.Errorf("qty = %d, want %d", got, cardMasterStockQty)
	}

	// shopId 0 (element without a catalogue id) falls back to the default.
	frame, err = buildShopCatalog(cards, 0, 0)
	if err != nil {
		t.Fatalf("build fallback: %v", err)
	}
	if got := int32(binary.BigEndian.Uint32(frame[5:9])); got != theCardMasterShopID {
		t.Errorf("fallback shopId = %d, want %d", got, theCardMasterShopID)
	}

	// The "démone II" exchangers (world 37/80) carry mode 1, which switches the
	// client to the other shop UI.
	frame, err = buildShopCatalog(cards, 17, 1)
	if err != nil {
		t.Fatalf("build demone II: %v", err)
	}
	if frame[4] != 1 {
		t.Errorf("mode = %d, want 1 (démone II variant)", frame[4])
	}
}

// TestCardMasterStockIsItsCardSet: a Card Master sells exactly its own "panoplie"
// (the card set its descriptor names), not the whole shop.
func TestCardMasterStockIsItsCardSet(t *testing.T) {
	cards := gamedata.NewCards(
		&gamedata.CoachCard{ID: 16, CardSet: 5, Price: map[uint8]int32{0: 1}},
		&gamedata.CoachCard{ID: 17, CardSet: 5},                                 // in-set, unpriced: still stocked
		&gamedata.CoachCard{ID: 105, CardSet: 6, Price: map[uint8]int32{0: 1}},  // other set
		&gamedata.CoachCard{ID: 51, CardSet: 7, Price: map[uint8]int32{1: 0}},   // all-zero price
		&gamedata.CoachCard{ID: 300, CardSet: 36, Price: map[uint8]int32{1: 9}}, // priced, no Card Master set
	)

	got := cardMasterStock(cards, 5)
	if len(got) != 2 || got[0] != 16 || got[1] != 17 {
		t.Errorf("stock(set 5) = %v, want [16 17]", got)
	}
	if got := cardMasterStock(cards, 6); len(got) != 1 || got[0] != 105 {
		t.Errorf("stock(set 6) = %v, want [105]", got)
	}

	// Purchase validation follows the same stock.
	if !shopSells(cards, 5, 16) {
		t.Error("shop 5 should sell card 16")
	}
	if shopSells(cards, 5, 105) {
		t.Error("shop 5 must NOT sell card 105 (it belongs to set 6)")
	}

	// Unknown/empty set falls back to every PURCHASABLE card so the shop stays
	// usable; an all-zero price map (card 51) is not one, and since S28 the
	// Card Master sets' cards (16, 105) stay with their own Card Masters.
	got = cardMasterStock(cards, 999)
	if len(got) != 1 || got[0] != 300 {
		t.Errorf("stock(unknown set) = %v, want the priced non-set card [300]", got)
	}
}
