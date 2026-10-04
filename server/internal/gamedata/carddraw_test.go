package gamedata

import (
	"math/rand"
	"testing"
)

// TestValueBucketMatchesKaCurve pins the bK bucket curve ported from ka_1.java.
func TestValueBucketMatchesKaCurve(t *testing.T) {
	cases := []struct {
		v    int32
		want int
	}{
		{0, 0}, {-5, 0}, {5, 1}, {17, 1}, {99, 9}, {105, 10}, {199, 10},
		{200, 11}, {3399, 18}, {3600, 19}, {3999, 19},
		{4000, 20}, {4820, 20}, {28999, 28}, {29000, 29}, {42000, 42},
		{49999, 49}, {50000, 50}, {999999, 50},
	}
	for _, c := range cases {
		if got := valueBucket(c.v); got != c.want {
			t.Errorf("valueBucket(%d) = %d, want %d", c.v, got, c.want)
		}
	}
}

// TestDrawTableBucketing covers the alb_1 registrations: only ObtainableInDraw
// cards enter buckets, keyed by bK(value).
func TestDrawTableBucketing(t *testing.T) {
	cards := NewCards(
		&CoachCard{ID: 1, Value: 50, ObtainableInDraw: true, DropPercent: 100},  // bucket 5
		&CoachCard{ID: 2, Value: 360, ObtainableInDraw: true, DropPercent: 100}, // bucket 11
		&CoachCard{ID: 3, Value: 5000, ObtainableInDraw: false},                 // not in draw
	)
	dt := NewDrawTable(cards, rand.New(rand.NewSource(1)))
	if got := dt.PoolLen(); got != 2 {
		t.Fatalf("PoolLen = %d, want 2", got)
	}
	if dt.Get(3) == nil {
		t.Fatal("card 3 must still be registered (alb_1.pj) even outside the draw")
	}
}

// TestDrawWalksBucketsDown: pk(n) steps to the first non-empty bucket below n —
// the empty-bucket walk-down that makes high draws degrade gracefully.
func TestDrawWalksBucketsDown(t *testing.T) {
	cards := NewCards(
		&CoachCard{ID: 7, Value: 50, ObtainableInDraw: true, DropPercent: 100},
	)
	dt := NewDrawTable(cards, rand.New(rand.NewSource(1)))
	got := dt.Draw(40, 0) // bucket 40 empty -> walks all the way down to 5
	if got == nil || got.ID != 7 {
		t.Fatalf("Draw(40) = %v, want card 7 from the walked-down bucket", got)
	}
}

// TestDrawRareCardsNeedBonus: the acceptance roll `nextInt(100) - n3 <= pct`
// makes a pct=0 card a ~1% keep at bonus 0 (roll == 0) and an equal citizen at
// bonus 100 — the map/pet drop-chance bonus is what turns the rare pool from
// lottery-odds into a real source. Same bucket for both cards so the pick
// itself is fair.
func TestDrawRareCardsNeedBonus(t *testing.T) {
	cards := NewCards(
		&CoachCard{ID: 1, Value: 50, ObtainableInDraw: true, DropPercent: 0},   // rare
		&CoachCard{ID: 2, Value: 55, ObtainableInDraw: true, DropPercent: 100}, // common
	)
	dt := NewDrawTable(cards, rand.New(rand.NewSource(2)))
	var rare0 int
	for i := 0; i < 400; i++ {
		c := dt.Draw(5, 0)
		if c == nil {
			t.Fatal("Draw returned nil from a non-empty pool")
		}
		if c.ID == 1 {
			rare0++
		}
	}
	// ~1% keep chance -> ~4 rare in 400; anything like parity would be a bug.
	if rare0 > 30 {
		t.Fatalf("bonus 0 returned %d/400 rare cards, want a trickle", rare0)
	}
	// At bonus 100 every pick keeps -> the rare card lands at its bucket share.
	var rare100 int
	for i := 0; i < 400; i++ {
		if c := dt.Draw(5, 100); c != nil && c.ID == 1 {
			rare100++
		}
	}
	if rare100 == 0 {
		t.Fatal("bonus 100 never unlocked the pct=0 card in 400 draws")
	}
}

// TestDrawEmptyPool reports nil rather than hanging or crashing.
func TestDrawEmptyPool(t *testing.T) {
	dt := NewDrawTable(NewCards(&CoachCard{ID: 1, Value: 10}), rand.New(rand.NewSource(1)))
	if got := dt.Draw(10, 0); got != nil {
		t.Fatalf("empty pool Draw = %v, want nil", got)
	}
}
