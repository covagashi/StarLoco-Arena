package game

import (
	"errors"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store"
)

// Shop result codes carried by ShopResult(5403).
const (
	shopResultOK           uint8 = 0 // purchase succeeded, new balance follows
	shopResultInsufficient uint8 = 1 // not enough tokens
	shopResultError        uint8 = 2 // bad request / unknown card
)

func registerShopHandlers(r *Router, d *Deps) {
	r.Register(protocol.OpShopOpen, handleShopOpen)
	r.Register(protocol.OpShopBuy, handleShopBuy)
	r.Register(protocol.OpShopBarter, handleShopBarter)
}

// maxBarterCards bounds the given/wanted list sizes accepted from a 5400 request.
const maxBarterCards = 64

// handleShopBarter (5400 C2S) does a Card-Master card-for-card exchange: the
// coach trades in cards ("given") for a wanted card. Layout:
//
//	[i32 exchangeId][i16 N]{i32 wantedId}[i16 M]{i32 givenId, i16 qty}
//
// The client's own rule (aJd.canBuyCards) is Σ(given.value × qty) ≥ wanted.value
// (and wanted.value > 0); we enforce the same server-side, then consume the
// given cards and grant the wanted card. Replies ShopResult(5403) + pushes the
// updated inventory (5200).
// maxBarterQtyPerCard bounds how many copies of ONE card a single barter may
// offer. Well above any real inventory; see handleShopBarter for why it exists.
const maxBarterQtyPerCard uint16 = 1000

func handleShopBarter(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	if s.deps.Cards == nil {
		return s.sendShopResult(shopResultError)
	}
	r := protocol.NewReader(f.Payload)
	// The echoed catalogue id of the Card Master being bartered with.
	shopID, err := r.I32()
	if err != nil {
		return err
	}
	wantedIDs, err := readCardIDList(r)
	if err != nil {
		return err
	}
	givenIDs, givenQty, err := readCardQtyList(r)
	if err != nil {
		return err
	}
	if len(wantedIDs) != 1 { // the client always wants exactly one card
		return s.sendShopResult(shopResultError)
	}
	wanted := s.deps.Cards.Get(wantedIDs[0])
	if wanted == nil || wanted.Value <= 0 {
		return s.sendShopResult(shopResultError)
	}
	if !shopSells(s.deps.Cards, shopID, wantedIDs[0]) {
		// This Card Master does not stock the wanted card. (The GIVEN cards come
		// from the coach's own inventory, so they are not stock-checked.)
		return s.sendShopResult(shopResultError)
	}

	// Value check: Σ(given.value × qty) ≥ wanted.value.
	var givenValue int64
	inputs := make([]int32, 0, len(givenIDs))
	for i, id := range givenIDs {
		card := s.deps.Cards.Get(id)
		if card == nil {
			return s.sendShopResult(shopResultError)
		}
		// SECURITY: cap the per-entry quantity before expanding it.
		//
		// readCardQtyList caps the number of ENTRIES at 64 but never the quantity
		// within one, and each unit became a separate slice element: 64 x 65535 is
		// 4.19M int32, about 16.8 MB, from a ~400-byte frame - roughly 42,000x
		// amplification, repeatable. ConsumeAndGrant would then correctly refuse
		// for lack of ownership, so the damage was purely allocation.
		//
		// Nobody owns more than maxBarterQtyPerCard copies of one card, so this
		// cannot refuse a real barter; it only stops the request being used as an
		// allocator.
		qty := givenQty[i]
		if qty > maxBarterQtyPerCard {
			s.log.Warn("barter quantity clamped", "coach", s.Coach.ID,
				"card", id, "requested", qty)
			qty = maxBarterQtyPerCard
		}
		givenValue += int64(card.Value) * int64(qty)
		for j := uint16(0); j < qty; j++ {
			inputs = append(inputs, id)
		}
	}
	if len(inputs) == 0 || givenValue < int64(wanted.Value) {
		return s.sendShopResult(shopResultInsufficient)
	}
	// SECURITY: same unique rule as handleShopBuy - the client gates this exact
	// opcode (ku_2.java:98-100 guards 5400) and barter is the cheaper vector,
	// since any inputs whose summed value covers the target will do.
	if s.deps.cardIsUnique(wantedIDs[0]) && s.coachOwnsCard(wantedIDs[0]) {
		s.log.Warn("barter refused: unique card already owned",
			"coach", s.Coach.ID, "card", wantedIDs[0])
		return s.sendShopResult(shopResultError)
	}
	// SECURITY: an "undestructible" card may not be consumed. 65 shipped cards
	// carry the flag and the client blocks every destructive gesture on them
	// (ku_2.java:45 barter, arb_0.java:31 demon, add.java:24 fusion). Losing one
	// is irreversible player-data loss.
	for _, id := range inputs {
		if !s.deps.cardIsTradable(id) {
			s.log.Warn("barter refused: input card is bound or undestructible",
				"coach", s.Coach.ID, "card", id)
			return s.sendShopResult(shopResultError)
		}
	}

	err = s.deps.Store.Coaches.ConsumeAndGrant(s.Coach.ID, inputs, wantedIDs[0])
	if errors.Is(err, store.ErrCardNotOwned) {
		return s.sendShopResult(shopResultInsufficient) // doesn't own the given cards
	}
	if err != nil {
		return err
	}
	s.log.Info("card barter", "coach", s.Coach.Name, "wanted", wantedIDs[0], "gave", len(inputs))

	s.refreshAndPushInventory()
	// The wallet is unchanged by a barter; still send a success 5403 so the
	// client closes the dialog and refreshes.
	if fresh, err := s.deps.Store.Coaches.Get(s.Coach.ID); err == nil {
		s.Coach.SetWallet(fresh.Wallet)
	}
	return s.sendShopResult(shopResultOK)
}

// readCardIDList reads [i16 N]{i32 cardId}.
func readCardIDList(r *protocol.Reader) ([]int32, error) {
	n, err := r.U16()
	if err != nil {
		return nil, err
	}
	if n > maxBarterCards {
		return nil, nil
	}
	ids := make([]int32, 0, n)
	for i := 0; i < int(n); i++ {
		id, err := r.I32()
		if err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, nil
}

// readCardQtyList reads [i16 M]{i32 cardId, i16 qty}.
func readCardQtyList(r *protocol.Reader) (ids []int32, qtys []uint16, err error) {
	m, err := r.U16()
	if err != nil {
		return nil, nil, err
	}
	if m > maxBarterCards {
		return nil, nil, nil
	}
	for i := 0; i < int(m); i++ {
		id, err := r.I32()
		if err != nil {
			return nil, nil, err
		}
		qty, err := r.U16()
		if err != nil {
			return nil, nil, err
		}
		ids = append(ids, id)
		qtys = append(qtys, qty)
	}
	return ids, qtys, nil
}

// theCardMasterShopID is the fallback shop context id, used when a Card Master
// element carries no catalogue id of its own.
const theCardMasterShopID int32 = 1

// handleShopOpen handles opcode 5300. Despite the name this is NOT a shop
// request: 5300 is the client's DEBUG-CONSOLE opener (its only sender is the
// console command). Replying with a catalogue here made opening the console pop
// the Card Master, so we accept it and do nothing. The real in-world shop flow is
// element click -> 201 -> server pushes 5401 (see handleInteractiveElementAction).
func handleShopOpen(_ *Session, _ *protocol.C2SFrame) error {
	return nil
}

// cardMasterStockQty is the availability we advertise per card. The server does
// not track stock, so this is effectively "unlimited" (retail behaviour). It is
// NOT a price — prices come from the card templates client-side.
const cardMasterStockQty uint16 = 999

// cardMasterStock returns the card ids a Card Master sells. Each Card Master's
// descriptor carries a "cardListId", which is a card SET id ("panoplie", named by
// content.25.<id>) — the twelve main-island Card Masters map 1:1 onto the twelve
// lowest equipment sets, so each sells exactly one panoplie.
//
// Falls back to every priced card when the element carries no set (id 0) or the
// set is unknown/empty (e.g. game data not loaded), so the shop is still usable.
func cardMasterStock(cards *gamedata.Cards, cardListID int32) []int32 {
	if cards == nil {
		return nil
	}
	if cardListID != 0 {
		// NOTE: the stock deliberately stays the card set VERBATIM, including
		// cards with no chargeable price. A Card Master advertises its whole
		// "panoplie" (TestCardMasterStockIsItsCardSet pins this), and I have no
		// client evidence that retail filtered the displayed list - changing what
		// we advertise is a retail-parity question, not a security one.
		//
		// The security guard lives at the PURCHASE instead: cardIsPurchasable in
		// handleShopBuy. Stocked and purchasable are therefore not the same set,
		// and a client that asks to buy an unpriced card gets a refusal rather
		// than a free card.
		if ids := cards.CardsInSet(cardListID); len(ids) > 0 {
			return ids
		}
	}
	// No card set behind the list id: the mode-1 ("démone II") masters of worlds
	// 37 and 80 name lists 17-24, which are no set in the client data - their
	// retail stock lived on Ankama's server. The fallback is what this server
	// can actually sell: cards with a positive price. It used to be every card
	// with a price MAP, zeros included - 845 cards, most of them refused at
	// purchase, and ~15 s for the Godot panel to load their art (S08).
	priced := cards.Priced()
	out := priced[:0:0]
	for _, id := range priced {
		if cardIsPurchasable(cards.Get(id)) {
			out = append(out, id)
		}
	}
	return out
}

// buildShopCatalog builds ShopCatalog(5401): [i8 mode][i32 shopId] then per
// offered card [i32 cardTemplateId][i16 qty].
//
// mode 0 = the ordinary Card Master ("kardmaster") tab; 1 switches the UI to the
// "démone II" variant. Every Card Master on the six main islands carries flag 0 in
// its descriptor, so we always send 0.
//
// shopId is opaque to the client: it stores it and echoes it back on every
// purchase (5400 barter / 5450 token buy), so we stamp the clicking Card Master's
// own catalogue id — that is what lets a purchase be validated against the right
// stock. When no gamedata is loaded the catalog is empty (but still a valid,
// openable shop).
func buildShopCatalog(cards *gamedata.Cards, cardListID int32, mode uint8) ([]byte, error) {
	shopID := cardListID
	if shopID == 0 {
		shopID = theCardMasterShopID
	}
	w := protocol.NewWriter().U8(mode).I32(shopID)
	for _, id := range cardMasterStock(cards, cardListID) {
		w.I32(id).U16(cardMasterStockQty)
	}
	return protocol.EncodeS2C(protocol.OpShopCatalog, w.Bytes())
}

// shopSells reports whether the Card Master identified by the echoed shopId
// actually offers cardID. The client echoes the shopId we stamped into 5401 on
// every purchase, so this rejects buying a card the clicked Card Master doesn't
// stock (a forged or stale request).
func shopSells(cards *gamedata.Cards, shopID, cardID int32) bool {
	for _, id := range cardMasterStock(cards, shopID) {
		if id == cardID {
			return true
		}
	}
	return false
}

// handleShopBuy (5450 C2S: [i32 shopId][i16 N]{i32 cardId}) buys cards from the
// Card Master with tokens. It sums each card's token price (from gamedata),
// debits the wallet + grants the cards atomically, then pushes the updated
// inventory (5200) and the new balance (5403). One unit is bought per listed id.
func handleShopBuy(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	// shopId: the catalogue id we stamped into 5401, echoed back by the client. It
	// identifies WHICH Card Master's stock this purchase belongs to.
	shopID, err := r.I32()
	if err != nil {
		return err
	}
	n, err := r.U16()
	if err != nil {
		return err
	}
	if n == 0 || n > 64 {
		return s.sendShopResult(shopResultError)
	}

	// Resolve prices and aggregate per-card quantities + total cost.
	if s.deps.Cards == nil {
		return s.sendShopResult(shopResultError)
	}
	qtyByCard := make(map[int32]int16)
	cost := make(map[uint8]int32)
	for i := 0; i < int(n); i++ {
		cardID, err := r.I32()
		if err != nil {
			return err
		}
		card := s.deps.Cards.Get(cardID)
		if card == nil {
			return s.sendShopResult(shopResultError) // unknown card
		}
		if !shopSells(s.deps.Cards, shopID, cardID) {
			// This Card Master does not stock that card (forged/stale request).
			return s.sendShopResult(shopResultError)
		}
		// SECURITY: a unique card cannot be acquired twice. The client blocks this
		// before it will even build the packet (ku_2.java:98-100), so any request
		// that reaches here is forged. Beyond the economy, the retail client
		// REFUSES to accept a second copy in the 5200 push (ky_2 returns 2), so
		// granting one desyncs the player's inventory view from the database
		// permanently. Unique cards also carry high Value, which feeds clan-island
		// reputation and the fusion value ceiling.
		if s.deps.cardIsUnique(cardID) && s.coachOwnsCard(cardID) {
			s.log.Warn("purchase refused: unique card already owned",
				"coach", s.Coach.ID, "card", cardID)
			return s.sendShopResult(shopResultError)
		}
		// SECURITY: a card with no POSITIVE price is not purchasable.
		//
		// Cost was derived solely from the template's Price map, and BuyCards
		// skips any entry with amount <= 0, so a card whose Price map is empty or
		// all-zero was granted for nothing. That is not theoretical against
		// shipped data: of 907 cards, 62 are in a card set with NO price at all
		// and 702 more carry an all-zero price - so 764 templates were mintable in
		// batches of 64 per packet. shopID arrives unvalidated, so the attacker
		// picks whichever set contains the card it wants; no proximity to a Card
		// Master is checked or needed.
		//
		// Anything genuinely meant to be free must be granted by a reward path,
		// not by the shop.
		if !cardIsPurchasable(card) {
			s.log.Warn("rejected purchase of an unpriced card",
				"coach", s.Coach.ID, "card", cardID, "shop", shopID)
			return s.sendShopResult(shopResultError)
		}
		qtyByCard[cardID]++
		for ctype, amount := range card.Price {
			cost[ctype] += amount
		}
	}

	grants := make([]store.GrantCard, 0, len(qtyByCard))
	for id, qty := range qtyByCard {
		grants = append(grants, store.GrantCard{TemplateID: id, Quantity: qty})
	}

	err = s.deps.Store.Coaches.BuyCards(s.Coach.ID, cost, grants)
	if errors.Is(err, store.ErrInsufficientFunds) {
		return s.sendShopResult(shopResultInsufficient)
	}
	if err != nil {
		return err
	}
	s.log.Info("shop purchase", "coach", s.Coach.Name, "cards", int(n), "cost", cost)

	// Reload the coach so inventory + wallet reflect the purchase, then push.
	if fresh, err := s.deps.Store.Coaches.Get(s.Coach.ID); err == nil {
		s.Coach.SetInventory(fresh.Inventory)
		s.Coach.SetWallet(fresh.Wallet)
	}
	if err := s.pushInventory(s.Coach); err != nil {
		return err
	}
	return s.sendShopResult(shopResultOK)
}

// sendShopResult sends ShopResult(5403): [i8 result][i8 count]{i8 type, i32 amt}
// echoing the coach's current wallet (empty on non-success).
func (s *Session) sendShopResult(result uint8) error {
	w := protocol.NewWriter().U8(result)
	if result == shopResultOK {
		writeWallet(w, s.Coach.Wallet)
	} else {
		w.U8(0) // no balances on failure
	}
	frame, err := protocol.EncodeS2C(protocol.OpShopResult, w.Bytes())
	if err != nil {
		return err
	}
	return s.Send(frame)
}

// buildWalletUpdate builds WalletUpdate(4001): [i8 count]{i8 type, i32 amount},
// the full-wallet sync the client applies on login.
func buildWalletUpdate(wallet []domain.CoachCurrency) ([]byte, error) {
	w := protocol.NewWriter()
	writeWallet(w, wallet)
	return protocol.EncodeS2C(protocol.OpWalletUpdate, w.Bytes())
}

// writeWallet writes [i8 count] then {i8 currencyType, i32 amount} per slot.
func writeWallet(w *protocol.Writer, wallet []domain.CoachCurrency) {
	w.U8(uint8(len(wallet)))
	for _, c := range wallet {
		w.U8(c.CurrencyType).I32(c.Amount)
	}
}

// primaryCurrency is the Card-Master shop token type (byte 1 in real data).
const primaryCurrency uint8 = 1

// starterTokens seeds a brand-new coach so the shop is usable (mirrors
// grantStarterCards). Only credits when the coach has no wallet yet.
const starterTokens int32 = 1000

// fightWinReward is the token faucet: how many primary-currency tokens a coach
// earns for winning a fight.
const fightWinReward int32 = 50

// challengeTokenReward is what a challenge that names no reward card pays on
// its first clear (owner, 2026-10-25: "aunque no tengan recompensa, que den
// ese dinero"). Two ranked wins' worth; a repeat clear pays nothing.
const challengeTokenReward int32 = 100

// tournamentWinTokens is what winning a tournament pays, on top of the
// definition's reward card when it names one. The client's help text has
// always said tournaments give tokens; until S26 none did.
const tournamentWinTokens int32 = 500

// awardFightWin credits the win reward to a coach. Safe to call from the
// fight-actor goroutine (see creditTokens).
func (d *Deps) awardFightWin(coachID uint, sess *Session) {
	d.creditTokens(coachID, sess, fightWinReward, "fight win")
}

// creditTokens pays n primary-currency tokens to a coach and, if the coach is
// online, pushes the updated wallet (4001) so the shop balance reflects it
// live. Errors are logged, never propagated — a reward must not break fight
// teardown. Safe to call from the fight-actor goroutine (only touches the
// store + a Send).
func (d *Deps) creditTokens(coachID uint, sess *Session, n int32, why string) {
	if d.Store == nil || n <= 0 {
		return
	}
	if err := d.Store.Coaches.CreditCurrency(coachID, primaryCurrency, n); err != nil {
		d.Log.Warn("credit tokens", "coach", coachID, "why", why, "err", err)
		return
	}
	d.Log.Info("credited tokens", "coach", coachID, "why", why, "tokens", n)
	if sess == nil {
		return
	}
	// Reload the wallet and push a full 4001 sync.
	fresh, err := d.Store.Coaches.Get(coachID)
	if err != nil {
		return
	}
	if sess.Coach != nil {
		sess.Coach.SetWallet(fresh.Wallet)
	}
	if frame, err := buildWalletUpdate(fresh.Wallet); err == nil {
		_ = sess.Send(frame)
	}
}

// grantStarterWallet gives a new coach an initial token balance so it can shop.
func (s *Session) grantStarterWallet(coach *domain.Coach) {
	if len(coach.Wallet) > 0 {
		return
	}
	if err := s.deps.Store.Coaches.CreditCurrency(coach.ID, primaryCurrency, starterTokens); err != nil {
		s.log.Warn("grant starter wallet", "err", err)
		return
	}
	coach.Wallet = append(coach.Wallet, domain.CoachCurrency{
		CoachID: coach.ID, CurrencyType: primaryCurrency, Amount: starterTokens,
	})
	s.log.Info("granted starter wallet", "coach", coach.Name, "tokens", starterTokens)
}

// cardIsPurchasable reports whether a card template has a price a shop can
// actually charge: at least one currency with a strictly positive amount.
//
// See handleShopBuy for why this is a security guard rather than a tidiness one.
func cardIsPurchasable(card *gamedata.CoachCard) bool {
	if card == nil {
		return false
	}
	for _, amount := range card.Price {
		if amount > 0 {
			return true
		}
	}
	return false
}
