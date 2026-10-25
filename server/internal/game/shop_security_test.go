package game

import (
	"path/filepath"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store/storetest"
)

// TestUnpricedCardsAreNotPurchasable is the SECURITY regression for free card
// minting through the Card Master (5450).
//
// Cost was derived only from the template's Price map, and BuyCards skips any
// entry with amount <= 0 - so an empty or all-zero price meant a free card.
// Measured against shipped data, not assumed: of 907 cards, 62 sit in a card set
// with NO price and 702 more carry an all-zero price, so 764 templates were
// mintable in batches of 64 per packet. shopID arrives unvalidated, so the
// attacker picks whichever set holds the card it wants and never goes near a
// Card Master.
//
// That these are genuinely not-for-sale rather than free was confirmed by reading
// the data: card 51 has price map[1:0] and value 36200, card 449 price map[1:0]
// and value 17234. A zero entry means "no price in this currency", not "free" -
// those cards come from drops, rewards and fusion.
func TestUnpricedCardsAreNotPurchasable(t *testing.T) {
	cases := []struct {
		name string
		card *gamedata.CoachCard
		want bool
	}{
		{"nil card", nil, false},
		{"no price map at all", &gamedata.CoachCard{ID: 1, CardSet: 5}, false},
		{"empty price map", &gamedata.CoachCard{ID: 2, CardSet: 5, Price: map[uint8]int32{}}, false},
		{"all-zero price (the 702-card case)", &gamedata.CoachCard{ID: 3, CardSet: 5, Price: map[uint8]int32{1: 0}}, false},
		{"negative price", &gamedata.CoachCard{ID: 4, CardSet: 5, Price: map[uint8]int32{1: -50}}, false},
		{"mixed zero and negative", &gamedata.CoachCard{ID: 5, Price: map[uint8]int32{1: 0, 2: -1}}, false},
		{"one positive currency", &gamedata.CoachCard{ID: 6, Price: map[uint8]int32{1: 100}}, true},
		{"positive alongside zero", &gamedata.CoachCard{ID: 7, Price: map[uint8]int32{1: 0, 2: 40}}, true},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := cardIsPurchasable(tc.card); got != tc.want {
				t.Errorf("cardIsPurchasable = %v, want %v", got, tc.want)
			}
		})
	}
}

// TestStockedIsNotTheSameAsPurchasable records the deliberate asymmetry, so
// nobody "fixes" one side into agreement with the other by accident.
//
// A Card Master advertises its whole panoplie including unpriced cards
// (TestCardMasterStockIsItsCardSet pins that, and it predates this work). I did
// briefly filter the catalogue too and it broke that invariant - reverted,
// because what retail DISPLAYED is a parity question I have no client evidence
// for, while what the server HANDS OVER is not.
func TestStockedIsNotTheSameAsPurchasable(t *testing.T) {
	free := &gamedata.CoachCard{ID: 17, CardSet: 5}
	cards := gamedata.NewCards(
		&gamedata.CoachCard{ID: 16, CardSet: 5, Price: map[uint8]int32{0: 1}},
		free,
	)

	if !shopSells(cards, 5, free.ID) {
		t.Error("the unpriced card should still be STOCKED by its card master")
	}
	if cardIsPurchasable(free) {
		t.Error("...but it must not be PURCHASABLE")
	}
}

// TestShopBuyRefusesUnpricedCardOnTheWire drives opcode 5450 itself (B-151's
// recorded gap): the guard has to hold in the handler, not only in the helper.
// A priced card from the same set is bought normally, so a refusal cannot be
// an unrelated failure of the harness.
func TestShopBuyRefusesUnpricedCardOnTheWire(t *testing.T) {
	st, err := storetest.Open(t, filepath.Join(t.TempDir(), "shop.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })
	acc, _ := st.Accounts.CreateAccount("shopA", "pw", false)
	coach, _ := st.Coaches.Create(acc.ID, "Buyer", 0, 0, 0)
	if err := st.Coaches.CreditCurrency(coach.ID, 1, 500); err != nil {
		t.Fatalf("credit: %v", err)
	}

	cards := gamedata.NewCards(
		&gamedata.CoachCard{ID: 16, CardSet: 5, Price: map[uint8]int32{1: 100}},
		&gamedata.CoachCard{ID: 17, CardSet: 5, Price: map[uint8]int32{1: 0}},
	)
	d := &Deps{Store: st, Cards: cards, Log: testLogger()}
	s := &Session{log: testLogger(), deps: d, out: make(chan []byte, writeQueueSize),
		quit: make(chan struct{}), Coach: coach}

	buy := func(cardID int32) {
		t.Helper()
		p := protocol.NewWriter().I32(5).U16(1).I32(cardID).Bytes()
		if err := handleShopBuy(s, &protocol.C2SFrame{Payload: p}); err != nil {
			t.Fatalf("handler: %v", err)
		}
	}
	wallet := func() int32 {
		t.Helper()
		var w domain.CoachCurrency
		if err := st.DB().Where("coach_id = ? AND currency_type = ?", coach.ID, 1).
			First(&w).Error; err != nil {
			t.Fatalf("wallet: %v", err)
		}
		return w.Amount
	}

	buy(17)
	if n := cardCount(t, st, coach.ID, 17); n != 0 {
		t.Errorf("unpriced card granted through 5450: %d copies", n)
	}
	if got := wallet(); got != 500 {
		t.Errorf("wallet = %d after a refused buy, want 500", got)
	}

	buy(16)
	if n := cardCount(t, st, coach.ID, 16); n != 1 {
		t.Errorf("priced card: %d copies, want 1", n)
	}
	if got := wallet(); got != 400 {
		t.Errorf("wallet = %d, want 400", got)
	}
}

// TestCardMasterSetCardBuysWithTokens (S28): a Card Master set card that the
// data leaves unpriced costs value/100 tokens once the runtime prices are
// applied, through 5450 itself; the Token Bazaar's fallback stock does not
// take it over.
func TestCardMasterSetCardBuysWithTokens(t *testing.T) {
	st, err := storetest.Open(t, filepath.Join(t.TempDir(), "shop28.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })
	acc, _ := st.Accounts.CreateAccount("shop28", "pw", false)
	coach, _ := st.Coaches.Create(acc.ID, "Buyer28", 0, 0, 0)
	if err := st.Coaches.CreditCurrency(coach.ID, 1, 500); err != nil {
		t.Fatalf("credit: %v", err)
	}
	cards := gamedata.NewCards(
		&gamedata.CoachCard{ID: 40, CardSet: 5, Value: 7400, Price: map[uint8]int32{1: 0}},
		&gamedata.CoachCard{ID: 41, CardSet: 36, Value: 500, Price: map[uint8]int32{1: 80}},
	)
	gamedata.ApplyCardMasterPrices(cards)
	d := &Deps{Store: st, Cards: cards, Log: testLogger()}
	s := &Session{log: testLogger(), deps: d, out: make(chan []byte, writeQueueSize),
		quit: make(chan struct{}), Coach: coach}

	p := protocol.NewWriter().I32(5).U16(1).I32(40).Bytes()
	if err := handleShopBuy(s, &protocol.C2SFrame{Payload: p}); err != nil {
		t.Fatalf("handler: %v", err)
	}
	if n := cardCount(t, st, coach.ID, 40); n != 1 {
		t.Errorf("set card: %d copies, want 1", n)
	}
	var w domain.CoachCurrency
	if err := st.DB().Where("coach_id = ? AND currency_type = ?", coach.ID, 1).First(&w).Error; err != nil {
		t.Fatalf("wallet: %v", err)
	}
	if w.Amount != 500-74 {
		t.Errorf("wallet = %d, want %d", w.Amount, 500-74)
	}
	bazaar := cardMasterStock(cards, 17)
	if len(bazaar) != 1 || bazaar[0] != 41 {
		t.Errorf("Token Bazaar stock = %v, want only the card the data prices [41]", bazaar)
	}
}
