package game

import (
	"encoding/binary"
	"math/rand/v2"
	"testing"

	"github.com/StarLoco/arena-2.70/content"
	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

func pickSession(t *testing.T) (*Session, *Deps) {
	t.Helper()
	s, d := cosmeticSession(t)
	cc, err := gamedata.LoadCardContent(content.Cards)
	if err != nil {
		t.Fatal(err)
	}
	d.Cards = cc.Cards
	d.pickRng = rand.New(rand.NewPCG(1, 2))
	s.out = make(chan []byte, 32)
	return s, d
}

// readPicks drains the frames up to the last 60045: (wins, every, offer).
func readPicks(t *testing.T, s *Session) (int, int, []int32) {
	t.Helper()
	var last []byte
	for len(s.out) > 0 {
		frame := <-s.out
		if len(frame) >= 4 && binary.BigEndian.Uint16(frame[2:4]) == protocol.OpCardPicks {
			last = frame
		}
	}
	if last == nil {
		t.Fatal("no 60045 sent")
	}
	r := protocol.NewReader(payloadOf(t, last, protocol.OpCardPicks))
	wins, _ := r.U8()
	every, _ := r.U8()
	n, _ := r.U8()
	var offer []int32
	for i := 0; i < int(n); i++ {
		id, _ := r.I32()
		offer = append(offer, id)
	}
	return int(wins), int(every), offer
}

func choose(s *Session, id int32) error {
	return handleCardPickChoose(s, &protocol.C2SFrame{Payload: protocol.NewWriter().I32(id).Bytes()})
}

// An offer: three distinct pickable cards, unowned first, over as many rarity
// tiers as the catalogue allows; never a colour card (season rewards).
func TestDrawPickOffer(t *testing.T) {
	cc, err := gamedata.LoadCardContent(content.Cards)
	if err != nil {
		t.Fatal(err)
	}
	rng := rand.New(rand.NewPCG(7, 7))
	for i := 0; i < 200; i++ {
		offer := drawPickOffer(cc.Cards, nil, rng)
		if len(offer) != pickOfferSize {
			t.Fatalf("offer %v", offer)
		}
		tiers := map[int]bool{}
		seen := map[int32]bool{}
		for _, id := range offer {
			c := cc.Cards.Get(id)
			if c == nil || !pickableTypes[c.Type] || c.Type == 29 || c.Value <= 0 || seen[id] {
				t.Fatalf("offer %v holds %+v", offer, c)
			}
			seen[id] = true
			tiers[pickTier(c.Rank)] = true
		}
		if len(tiers) != pickOfferSize {
			t.Fatalf("offer %v covers %d tiers, want %d", offer, len(tiers), pickOfferSize)
		}
	}
	// Owning almost everything: the unowned card still comes first.
	owned := map[int32]bool{}
	var keep int32
	for id, c := range cc.Cards.All() {
		if pickableTypes[c.Type] && c.Value > 0 {
			if keep == 0 {
				keep = id
				continue
			}
			owned[id] = true
		}
	}
	found := false
	for _, id := range drawPickOffer(cc.Cards, owned, rng) {
		found = found || id == keep
	}
	if !found {
		t.Fatalf("the one unowned card %d was not offered", keep)
	}
}

// Three wins make an offer; wins bank one more offer while it waits; picking
// grants the card, and the banked wins pay the next offer at once.
func TestCardPickProgress(t *testing.T) {
	s, d := pickSession(t)
	id := s.Coach.ID
	d.cardPickWin(id)
	d.cardPickWin(id)
	if err := s.sendCardPicks(); err != nil {
		t.Fatal(err)
	}
	if wins, every, offer := readPicks(t, s); wins != 2 || every != 3 || len(offer) != 0 {
		t.Fatalf("after 2 wins: %d/%d %v", wins, every, offer)
	}
	for i := 0; i < 8; i++ { // 1 makes the offer, 3 bank, 4 are dropped
		d.cardPickWin(id)
	}
	_ = s.sendCardPicks()
	wins, _, offer := readPicks(t, s)
	if wins != 3 || len(offer) != 3 {
		t.Fatalf("offer pending: wins %d offer %v (want 3 banked, 3 cards)", wins, offer)
	}

	// A card not in the offer is refused.
	if err := choose(s, 999999); err != nil {
		t.Fatal(err)
	}
	if p, _ := d.Store.CardPicks.Get(id); p.Picks != 0 {
		t.Fatal("a card outside the offer was taken")
	}
	readPicks(t, s)

	pick := offer[1]
	if err := choose(s, pick); err != nil {
		t.Fatal(err)
	}
	fresh, _ := d.Store.Coaches.Get(id)
	got := false
	for _, c := range fresh.Inventory {
		got = got || c.TemplateID == pick && c.Quantity > 0
	}
	if !got {
		t.Fatalf("card %d not in the inventory", pick)
	}
	wins, _, next := readPicks(t, s)
	if wins != 0 || len(next) != 3 {
		t.Fatalf("after picking with 3 banked wins: wins %d, next offer %v", wins, next)
	}
	if p, _ := d.Store.CardPicks.Get(id); p.Picks != 1 {
		t.Fatalf("picks = %d", p.Picks)
	}
}

func TestPickEverySlowsDown(t *testing.T) {
	if domain.PickEvery(0) != 3 || domain.PickEvery(9) != 3 || domain.PickEvery(10) != 5 {
		t.Fatal("every 3 wins for the first ten picks, then 5")
	}
}

// 60001 carries the picks and the league; a bronze coach sees 4000.
func TestLeagueWithClientConfig(t *testing.T) {
	s, _ := pickSession(t)
	if err := s.sendLeague(); err != nil {
		t.Fatal(err)
	}
	r := protocol.NewReader(payloadOf(t, <-s.out, protocol.OpLeague))
	tier, _ := r.U8()
	budget, _ := r.I32()
	gtier, _ := r.U8()
	gbudget, _ := r.I32()
	if tier != 0 || budget != 4000 || gtier != 0 || gbudget != 4000 {
		t.Fatalf("league %d/%d ghost %d/%d", tier, budget, gtier, gbudget)
	}
	s.Coach.Strength = 1650
	_ = s.sendLeague()
	r = protocol.NewReader(payloadOf(t, <-s.out, protocol.OpLeague))
	tier, _ = r.U8()
	budget, _ = r.I32()
	if tier != 3 || budget != 5500 {
		t.Fatalf("platinum: %d/%d", tier, budget)
	}
}
