package gamedata

import (
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"testing"
)

func TestDerivedTokenPrice(t *testing.T) {
	for _, tc := range []struct{ value, want int32 }{
		{35, 10}, {999, 10}, {1000, 10}, {1099, 10}, {1100, 11}, {7400, 74}, {49000, 490},
	} {
		if got := DerivedTokenPrice(tc.value); got != tc.want {
			t.Errorf("DerivedTokenPrice(%d) = %d, want %d", tc.value, got, tc.want)
		}
	}
}

// TestApplyCardMasterPrices: only an unpriced, valued card of a Card Master
// set gets a price; a card the data prices keeps it.
func TestApplyCardMasterPrices(t *testing.T) {
	c := NewCards(
		&CoachCard{ID: 1, CardSet: 5, Value: 7400, Price: map[uint8]int32{1: 0}},
		&CoachCard{ID: 2, CardSet: 16, Value: 300},
		&CoachCard{ID: 3, CardSet: 5, Value: 7400, Price: map[uint8]int32{1: 25}},
		&CoachCard{ID: 4, CardSet: 20, Value: 7400, Price: map[uint8]int32{1: 0}},
		&CoachCard{ID: 5, CardSet: 5, Price: map[uint8]int32{1: 0}}, // no value
	)
	ApplyCardMasterPrices(c)
	want := map[int32]int32{1: 74, 2: 10, 3: 25, 4: 0, 5: 0}
	for id, w := range want {
		if got := c.Get(id).Price[TokenCurrency]; got != w {
			t.Errorf("card %d: token price %d, want %d", id, got, w)
		}
	}
}

// TestTokenPriceMatchesClient: the Godot client derives the same price
// (godot/src/gamedata/cards.gd).
func TestTokenPriceMatchesClient(t *testing.T) {
	src, err := os.ReadFile(filepath.Join("..", "..", "..", "godot", "src", "gamedata", "cards.gd"))
	if err != nil {
		t.Skip("no Godot client in this checkout")
	}
	want := map[string]int32{
		"CARD_MASTER_SET_FIRST": CardMasterSetFirst, "CARD_MASTER_SET_LAST": CardMasterSetLast,
		"TOKEN_PRICE_DIVISOR": TokenPriceDivisor, "TOKEN_PRICE_MIN": TokenPriceMin,
	}
	for name, w := range want {
		m := regexp.MustCompile(`const ` + name + ` := ([0-9]+)`).FindSubmatch(src)
		if m == nil {
			t.Errorf("cards.gd has no %s", name)
			continue
		}
		if v, _ := strconv.Atoi(string(m[1])); int32(v) != w {
			t.Errorf("%s: client %d, server %d", name, v, w)
		}
	}
}
