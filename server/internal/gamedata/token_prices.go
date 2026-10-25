package gamedata

// token_prices.go — the S28 card economy (owner, 2026-10-25).
//
// Retail sold the good cards for real money, which is why the twelve Card
// Master sets carry no token price at all: they could only be bartered. Here
// nothing that wins fights is paid for, so those cards get a token price
// derived from their barter value. Tokens are earned by playing (fights,
// challenges, tournaments); pesetas buy cosmetics only and never cards.
//
// The Godot client derives the same price (godot/src/gamedata/cards.gd);
// TestTokenPriceMatchesClient keeps the constants equal.

// CardMasterSetFirst..CardMasterSetLast are the card sets the lobby's twelve
// Card Masters sell, one each.
const (
	CardMasterSetFirst int32 = 5
	CardMasterSetLast  int32 = 16
)

// TokenPriceDivisor and TokenPriceMin turn a barter value into a token price:
// max(TokenPriceMin, value / TokenPriceDivisor). The sets' values run 35 to
// 49000, so a card costs 10 to 490 tokens: one to ten ranked wins.
const (
	TokenPriceDivisor int32 = 100
	TokenPriceMin     int32 = 10
)

// TokenCurrency is the Card Master token type in a Price map (byte 1).
const TokenCurrency uint8 = 1

// IsCardMasterSet reports whether a set is one of the twelve Card Masters'.
func IsCardMasterSet(set int32) bool {
	return set >= CardMasterSetFirst && set <= CardMasterSetLast
}

// DerivedTokenPrice is the token price a Card Master set card gets.
func DerivedTokenPrice(value int32) int32 {
	if p := value / TokenPriceDivisor; p > TokenPriceMin {
		return p
	}
	return TokenPriceMin
}

// ApplyCardMasterPrices gives every card of a Card Master set that has no
// positive price its derived token price. A card the data already prices
// keeps its price. Runs on the server's runtime catalogue only (LoadBundle);
// dumpcards and the studio keep the raw data.
func ApplyCardMasterPrices(c *Cards) {
	if c == nil {
		return
	}
	for _, card := range c.byID {
		if card == nil || !IsCardMasterSet(card.CardSet) || card.Value <= 0 {
			continue
		}
		priced := false
		for _, amount := range card.Price {
			if amount > 0 {
				priced = true
			}
		}
		if priced {
			continue
		}
		card.Price = map[uint8]int32{TokenCurrency: DerivedTokenPrice(card.Value)}
	}
}
