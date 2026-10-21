package e2e

import (
	"io"
	"log/slog"
	"sort"
	"sync"
	"testing"
	"time"

	"github.com/StarLoco/arena-2.70/internal/game"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/testclient"
)

// The rest of this package runs on a nil (or a hand-built) catalogue, so the
// data layer itself had no e2e. These tests start the server with the committed
// data-dist loaded through the same gamedata.LoadBundle + Deps.UseGameData that
// cmd/server uses (S08).

var (
	realDataOnce sync.Once
	realData     *gamedata.Bundle
)

// realBundle loads data-dist once per package: it is read-only after loading,
// and every parallel test can share it.
func realBundle(t *testing.T) *gamedata.Bundle {
	t.Helper()
	realDataOnce.Do(func() {
		realData = gamedata.LoadBundle(gamedata.Discover("../../data-dist"),
			slog.New(slog.NewTextHandler(io.Discard, nil)))
	})
	if realData.Cards == nil || realData.Spells == nil || realData.FightMaps == nil {
		t.Skip("data-dist not loadable from test/e2e; real-data e2e skipped")
	}
	return realData
}

// testServerWithData is testServerWithDeps on top of the real game data.
func testServerWithData(t *testing.T, customize func(*game.Deps)) string {
	t.Helper()
	b := realBundle(t)
	_, addr := testServerWithDeps(t, func(d *game.Deps) {
		d.UseGameData(b)
		if customize != nil {
			customize(d)
		}
	})
	return addr
}

// TestRealDataShopRefusesUnpricedCard is B-151 over the socket: a card the
// shipped data leaves unpriced is refused by 5450, while a priced card from the
// same Card Master is sold, so the refusal is the guard and not the harness.
func TestRealDataShopRefusesUnpricedCard(t *testing.T) {
	t.Parallel()
	b := realBundle(t)

	// Pick a set that stocks both kinds, from the data rather than hardcoded ids.
	var shop, unpriced, priced int32
	bySet := map[int32][2]int32{}
	all := b.Cards.All()
	ids := make([]int32, 0, len(all))
	for id := range all {
		ids = append(ids, id)
	}
	sort.Slice(ids, func(i, j int) bool { return ids[i] < ids[j] })
	for _, id := range ids {
		c := all[id]
		if c.CardSet == 0 || c.IsUnique {
			continue
		}
		pair := bySet[c.CardSet]
		positive, tokensOnly := false, true
		for ctype, amt := range c.Price {
			if amt > 0 {
				positive = true
				// the starter wallet holds only currency 1, 1000 tokens
				tokensOnly = tokensOnly && ctype == 1 && amt <= 1000
			}
		}
		switch {
		case !positive && pair[0] == 0:
			pair[0] = c.ID
		case positive && tokensOnly && pair[1] == 0:
			pair[1] = c.ID
		}
		bySet[c.CardSet] = pair
		if pair[0] != 0 && pair[1] != 0 {
			shop, unpriced, priced = c.CardSet, pair[0], pair[1]
			break
		}
	}
	if shop == 0 {
		t.Fatal("no card set in data-dist stocks both an unpriced and a cheap card")
	}

	addr := testServerWithData(t, nil)
	a, _ := dialLogin(t, addr, "real_shop", "RealShop")
	reachWorld(t, a)
	a.DrainReceived(200 * time.Millisecond)

	buy := func(card int32) uint8 {
		t.Helper()
		req := testclient.NewW().I32(shop).U16(1).I32(card).Bytes()
		_ = a.Send(2, testclient.OpShopBuy, req)
		f, _, err := a.WaitFor(testclient.OpShopResult, testclient.DefaultTimeout)
		if err != nil {
			t.Fatalf("no ShopResult(5403) for card %d: %v", card, err)
		}
		return testclient.NewR(f.Payload).U8()
	}
	if res := buy(unpriced); res != 2 {
		t.Errorf("unpriced card %d (set %d): result %d, want 2 (refused)", unpriced, shop, res)
	}
	if res := buy(priced); res != 0 {
		t.Errorf("priced card %d (set %d): result %d, want 0 (sold)", priced, shop, res)
	}
}

// TestRealDataFightReachesFirstTurn starts a ranked fight on the real arenas,
// spells and event cards and drives it to the first turn.
func TestRealDataFightReachesFirstTurn(t *testing.T) {
	t.Parallel()
	if raceEnabled {
		t.Skip("timing-sensitive full-fight E2E; see TestCombatSpellDamage")
	}
	addr := testServerWithData(t, nil)
	a, b := startFightForCombat(t, addr)
	if _, _, err := a.WaitFor(testclient.OpFighterTurnBegin, testclient.DefaultTimeout); err != nil {
		t.Fatalf("A: no FIGHTER_TURN_BEGIN with real data: %v", err)
	}
	b.DrainReceived(100 * time.Millisecond)
}
