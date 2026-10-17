package e2e

import (
	"testing"
	"time"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/game"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/testclient"
)

// shopCatalog is a tiny gamedata catalog for shop tests: a cheap card and an
// expensive one, both priced in currency type 1.
func shopCatalog() *gamedata.Cards {
	return gamedata.NewCards(
		&gamedata.CoachCard{ID: 700, Value: 100, Price: map[uint8]int32{1: 50}},
		&gamedata.CoachCard{ID: 800, Value: 9000, Price: map[uint8]int32{1: 5000}},
	)
}

// parseWallet reads a wallet body [i8 count]{i8 type, i32 amount} and returns
// type-1 balance.
func walletType1(payload []byte) int32 {
	r := testclient.NewR(payload)
	n := int(r.U8())
	var bal int32
	for i := 0; i < n; i++ {
		ctype := r.U8()
		amt := r.I32()
		if ctype == 1 {
			bal = amt
		}
	}
	return bal
}

// TestWalletSyncOnLogin: a coach receives a WalletUpdate(4001) at login showing
// its starter token balance.
func TestWalletSyncOnLogin(t *testing.T) {
	t.Parallel()
	addr := testServer(t)
	a, _ := dialLogin(t, addr, "wallet_a", "WalletA")

	f, _, err := a.WaitFor(testclient.OpWalletUpdate, testclient.DefaultTimeout)
	if err != nil {
		t.Fatalf("no WalletUpdate(4001): %v", err)
	}
	if bal := walletType1(f.Payload); bal <= 0 {
		t.Errorf("starter balance = %d, want > 0", bal)
	}
}

// barterCatalog: wanted card 9700 (value 100) and trade-in 9703 (value 60) use
// high ids so grantStarterCards (which grants the 10 LOWEST ids) never hands
// them out — keeping the test's inventory rows unambiguous. Ten low-id filler
// cards fill the starter set.
func barterCatalog() *gamedata.Cards {
	cards := []*gamedata.CoachCard{
		{ID: 9700, Value: 100, Price: map[uint8]int32{1: 50}},
		{ID: 9703, Value: 60},
	}
	for i := int32(1); i <= 10; i++ {
		cards = append(cards, &gamedata.CoachCard{ID: i, Value: 1})
	}
	return gamedata.NewCards(cards...)
}

// barterReq builds a 5400 payload: [i32 exId][i16 N]{i32 wantedId}[i16 M]{i32 givenId, i16 qty}.
func barterReq(wanted int32, given map[int32]uint16) []byte {
	w := testclient.NewW().I32(0).U16(1).I32(wanted)
	w.U16(uint16(len(given)))
	for id, qty := range given {
		w.I32(id).U16(qty)
	}
	return w.Bytes()
}

// TestShopBarterSuccess: trading in cards whose total value >= the wanted card's
// value grants the wanted card and consumes the given cards.
func TestShopBarterSuccess(t *testing.T) {
	t.Parallel()
	st, addr := testServerWithDeps(t, func(d *game.Deps) { d.Cards = barterCatalog() })
	a, aID := dialLogin(t, addr, "bar_a", "BarA")
	reachWorld(t, a)
	a.DrainReceived(200 * time.Millisecond)

	// Own 2× card 9703 (value 60 each = 120 >= wanted 100).
	if err := st.DB().Create(&domain.CoachCard{CoachID: uint(aID), TemplateID: 9703, Quantity: 2}).Error; err != nil {
		t.Fatalf("seed 9703: %v", err)
	}
	before700 := ownedQty(t, st, uint(aID), 9700)

	_ = a.Send(3, testclient.OpShopBarter, barterReq(9700, map[int32]uint16{9703: 2}))
	f, _, err := a.WaitFor(testclient.OpShopResult, testclient.DefaultTimeout)
	if err != nil {
		t.Fatalf("no ShopResult(5403): %v", err)
	}
	if res := testclient.NewR(f.Payload).U8(); res != 0 {
		t.Fatalf("barter result = %d, want 0 (ok)", res)
	}

	time.Sleep(150 * time.Millisecond)
	if q := ownedQty(t, st, uint(aID), 9703); q != 0 {
		t.Errorf("given card 9703 = %d, want 0 (consumed both)", q)
	}
	if q := ownedQty(t, st, uint(aID), 9700); q != before700+1 {
		t.Errorf("wanted card 9700 = %d, want %d (granted 1)", q, before700+1)
	}
}

// TestShopBarterInsufficientValue: trading in cards worth less than the wanted
// card is rejected (result 1) and nothing is consumed.
func TestShopBarterInsufficientValue(t *testing.T) {
	t.Parallel()
	st, addr := testServerWithDeps(t, func(d *game.Deps) { d.Cards = barterCatalog() })
	a, aID := dialLogin(t, addr, "bar_b", "BarB")
	reachWorld(t, a)
	a.DrainReceived(200 * time.Millisecond)

	st.DB().Create(&domain.CoachCard{CoachID: uint(aID), TemplateID: 9703, Quantity: 1})
	before9703 := ownedQty(t, st, uint(aID), 9703)

	// 1× 9703 (value 60) < wanted 9700 (value 100) -> reject.
	_ = a.Send(3, testclient.OpShopBarter, barterReq(9700, map[int32]uint16{9703: 1}))
	f, _, err := a.WaitFor(testclient.OpShopResult, testclient.DefaultTimeout)
	if err != nil {
		t.Fatalf("no ShopResult(5403): %v", err)
	}
	if res := testclient.NewR(f.Payload).U8(); res != 1 {
		t.Fatalf("barter result = %d, want 1 (insufficient)", res)
	}
	time.Sleep(120 * time.Millisecond)
	if q := ownedQty(t, st, uint(aID), 9703); q != before9703 {
		t.Errorf("card 9703 changed on rejected barter: %d -> %d", before9703, q)
	}
}

// cardMasterVenivici is the env instanceId of a Card Master on world 25 (the
// login spawn island), and the catalogue id its descriptor carries. Clicking it is
// the only in-world way to open the shop.
const (
	cardMasterVenivici           int64 = 9
	cardMasterVeniviciCardListID int32 = 13
)

// TestShopOpenCatalog: clicking a Card Master (201) returns a ShopCatalog(5401)
// listing the priced cards, stamped with that Card Master's own catalogue id.
//
// NOTE opcode 5300 is the client's DEBUG-CONSOLE opener, not a shop request — the
// server deliberately does not answer it with a catalogue.
func TestShopOpenCatalog(t *testing.T) {
	t.Parallel()
	_, addr := testServerWithDeps(t, func(d *game.Deps) { d.Cards = shopCatalog() })
	a, _ := dialLogin(t, addr, "cat_a", "CatA")
	reachWorld(t, a)
	a.DrainReceived(200 * time.Millisecond)

	click := testclient.NewW().I64(cardMasterVenivici).U16(0).Bytes()
	_ = a.Send(3, testclient.OpInteractiveElementAction, click)
	f, _, err := a.WaitFor(testclient.OpShopCatalog, testclient.DefaultTimeout)
	if err != nil {
		t.Fatalf("no ShopCatalog(5401) after clicking Card Master: %v", err)
	}
	// Layout: [i8 mode][i32 shopId]{[i32 cardId][i16 qty]}.
	r := testclient.NewR(f.Payload)
	if flag := r.U8(); flag != 0 {
		t.Errorf("catalog mode = %d, want 0", flag)
	}
	if shop := r.I32(); shop != cardMasterVeniviciCardListID {
		t.Errorf("catalog shopId = %d, want %d (the element's cardListId)",
			shop, cardMasterVeniviciCardListID)
	}
	// Collect offered card ids (both catalog cards are priced).
	offered := map[int32]bool{}
	for r.Remaining() >= 6 {
		id := r.I32()
		_ = r.U16() // qty
		offered[id] = true
	}
	if !offered[700] || !offered[800] {
		t.Errorf("catalog = %v, want cards 700 and 800", offered)
	}
}

// TestShopOpenCatalogFromAnotherWorld: the Godot lobby has no walkable world and
// sends a Card Master's 201 from wherever the coach is. Maknala's Card Master
// (world 23, instance 5, cardListId 5) must answer while the coach stands on
// the Venivici login island.
func TestShopOpenCatalogFromAnotherWorld(t *testing.T) {
	t.Parallel()
	_, addr := testServerWithDeps(t, func(d *game.Deps) { d.Cards = shopCatalog() })
	a, _ := dialLogin(t, addr, "cat_far", "CatFar")
	reachWorld(t, a)
	a.DrainReceived(200 * time.Millisecond)

	click := testclient.NewW().I64(5).U16(0).Bytes()
	_ = a.Send(3, testclient.OpInteractiveElementAction, click)
	f, _, err := a.WaitFor(testclient.OpShopCatalog, testclient.DefaultTimeout)
	if err != nil {
		t.Fatalf("no ShopCatalog(5401) for another world's Card Master: %v", err)
	}
	r := testclient.NewR(f.Payload)
	_ = r.U8()
	if shop := r.I32(); shop != 5 {
		t.Errorf("catalog shopId = %d, want 5 (Maknala's cardListId)", shop)
	}
}

// TestShopBuyCard: buying a card debits tokens, grants the card, and replies
// ShopResult(5403, result 0) with the new balance.
func TestShopBuyCard(t *testing.T) {
	t.Parallel()
	st, addr := testServerWithDeps(t, func(d *game.Deps) { d.Cards = shopCatalog() })
	a, aID := dialLogin(t, addr, "shop_a", "ShopA")
	reachWorld(t, a)
	a.DrainReceived(200 * time.Millisecond)

	// Buy card 700 (costs 50 of currency 1): [i32 shopId][i16 N]{i32 cardId}.
	req := testclient.NewW().I32(0).U16(1).I32(700).Bytes()
	_ = a.Send(2, testclient.OpShopBuy, req)

	f, _, err := a.WaitFor(testclient.OpShopResult, testclient.DefaultTimeout)
	if err != nil {
		t.Fatalf("no ShopResult(5403): %v", err)
	}
	r := testclient.NewR(f.Payload)
	if res := r.U8(); res != 0 {
		t.Fatalf("shop result = %d, want 0 (ok)", res)
	}
	// Remaining wallet body: balance = 1000 - 50 = 950.
	if bal := walletType1(f.Payload[1:]); bal != 950 {
		t.Errorf("balance after buy = %d, want 950", bal)
	}

	// The balance debit above is the authoritative proof of purchase; also
	// confirm the card is present (it may stack onto a starter grant).
	time.Sleep(150 * time.Millisecond)
	c, err := st.Coaches.Get(uint(aID))
	if err != nil {
		t.Fatalf("get coach: %v", err)
	}
	var qty700 int16
	for _, card := range c.Inventory {
		if card.TemplateID == 700 {
			qty700 += card.Quantity
		}
	}
	if qty700 < 1 {
		t.Error("bought card 700 not in inventory")
	}
}

// TestShopInsufficientFunds: buying beyond the wallet balance is rejected with
// ShopResult(5403, result 1) and no card is granted.
func TestShopInsufficientFunds(t *testing.T) {
	t.Parallel()
	st, addr := testServerWithDeps(t, func(d *game.Deps) { d.Cards = shopCatalog() })
	a, aID := dialLogin(t, addr, "shop_b", "ShopB")
	reachWorld(t, a)
	a.DrainReceived(200 * time.Millisecond)

	// Card 800 costs 5000; starter balance is 1000 -> reject.
	req := testclient.NewW().I32(0).U16(1).I32(800).Bytes()
	_ = a.Send(2, testclient.OpShopBuy, req)

	f, _, err := a.WaitFor(testclient.OpShopResult, testclient.DefaultTimeout)
	if err != nil {
		t.Fatalf("no ShopResult(5403): %v", err)
	}
	if res := testclient.NewR(f.Payload).U8(); res != 1 {
		t.Fatalf("shop result = %d, want 1 (insufficient)", res)
	}

	// The wallet must be unchanged (no tokens debited on a rejected buy).
	// (Note: with an injected catalog the coach may already own catalog cards
	// as starter grants, so we assert on the balance, not card presence.)
	time.Sleep(150 * time.Millisecond)
	c, _ := st.Coaches.Get(uint(aID))
	var bal int32
	for _, w := range c.Wallet {
		if w.CurrencyType == 1 {
			bal = w.Amount
		}
	}
	if bal != 1000 {
		t.Errorf("balance = %d after rejected buy, want 1000 (unchanged)", bal)
	}
}
