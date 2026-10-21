package store

import (
	"path/filepath"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
)

// newTestStore opens an empty store for one test: SQLite in a temp dir by
// default, or the server's other dialects when ARENA_STORE_TEST_DRIVER and
// ARENA_STORE_TEST_DSN name one (see dialect_test.go).
func newTestStore(t *testing.T) *Store {
	t.Helper()
	if s := openDialectTestStore(t); s != nil {
		return s
	}
	path := filepath.Join(t.TempDir(), "test.db")
	s, err := Open(path)
	if err != nil {
		t.Fatalf("Open: %v", err)
	}
	t.Cleanup(func() { _ = s.Close() })
	return s
}

func TestAccountLifecycle(t *testing.T) {
	s := newTestStore(t)

	acc, err := s.Accounts.CreateAccount("Tester", "secret", false)
	if err != nil {
		t.Fatalf("CreateAccount: %v", err)
	}
	if acc.CoachID != nil {
		t.Error("new account should have no coach")
	}

	got, err := s.Accounts.FindByName("Tester")
	if err != nil {
		t.Fatalf("FindByName: %v", err)
	}
	if !s.Accounts.VerifyPassword(got, "secret") {
		t.Error("password should verify")
	}
	if s.Accounts.VerifyPassword(got, "wrong") {
		t.Error("wrong password should not verify")
	}
}

func TestCoachCreationAndReload(t *testing.T) {
	s := newTestStore(t)
	acc, _ := s.Accounts.CreateAccount("Player", "pw", false)

	coach, err := s.Coaches.Create(acc.ID, "Hero", 1, 2, 0)
	if err != nil {
		t.Fatalf("Create coach: %v", err)
	}

	// Account should now link the coach (existing-coach discriminator).
	reloaded, err := s.Accounts.FindByName("Player")
	if err != nil {
		t.Fatalf("FindByName: %v", err)
	}
	if reloaded.CoachID == nil || *reloaded.CoachID != coach.ID {
		t.Fatalf("account.CoachID = %v, want %d", reloaded.CoachID, coach.ID)
	}

	// Duplicate name is rejected.
	if _, err := s.Coaches.Create(acc.ID, "hero", 0, 0, 0); err != ErrNameTaken {
		t.Errorf("duplicate name err = %v, want ErrNameTaken", err)
	}

	// Reloading the coach preserves look.
	got, err := s.Coaches.Get(coach.ID)
	if err != nil {
		t.Fatalf("Get coach: %v", err)
	}
	if got.Hair != 1 || got.Skin != 2 {
		t.Errorf("look = (%d,%d), want (1,2)", got.Hair, got.Skin)
	}

	// Save mutable fields (position/stats) and confirm they persist.
	got.PosX, got.PosY, got.PosZ = 42, 43, 7
	got.Strength = 1500
	// Standing is the EVOLUTION experience, a different axis from Strength (the
	// ladder rating). It was updated in memory by the post-fight META and then
	// dropped by Save's field map, so every point earned died on relog.
	got.Standing = 9000
	if err := s.Coaches.Save(got); err != nil {
		t.Fatalf("Save: %v", err)
	}
	again, _ := s.Coaches.Get(coach.ID)
	if again.PosX != 42 || again.PosY != 43 || again.PosZ != 7 || again.Strength != 1500 {
		t.Errorf("saved fields = (%d,%d,%d,str=%d), want (42,43,7,str=1500)",
			again.PosX, again.PosY, again.PosZ, again.Strength)
	}
	if again.Standing != 9000 {
		t.Errorf("standing = %d after reload, want 9000 (evolution level resets without it)", again.Standing)
	}
}

func TestWalletBuyAndCredit(t *testing.T) {
	s := newTestStore(t)
	acc, _ := s.Accounts.CreateAccount("Shopper", "pw", false)
	coach, _ := s.Coaches.Create(acc.ID, "Buyer", 0, 0, 0)

	// Credit 100 of currency type 1.
	if err := s.Coaches.CreditCurrency(coach.ID, 1, 100); err != nil {
		t.Fatalf("CreditCurrency: %v", err)
	}
	// Credit again (upsert adds).
	if err := s.Coaches.CreditCurrency(coach.ID, 1, 50); err != nil {
		t.Fatalf("CreditCurrency 2: %v", err)
	}

	// Buy two cards costing 30 (type 1) total; grant 1 of template 700, 1 of 701.
	cost := map[uint8]int32{1: 30}
	grants := []GrantCard{{TemplateID: 700, Quantity: 1}, {TemplateID: 701, Quantity: 1}}
	if err := s.Coaches.BuyCards(coach.ID, cost, grants); err != nil {
		t.Fatalf("BuyCards: %v", err)
	}

	got, _ := s.Coaches.Get(coach.ID)
	// Balance = 150 - 30 = 120.
	var bal int32
	for _, w := range got.Wallet {
		if w.CurrencyType == 1 {
			bal = w.Amount
		}
	}
	if bal != 120 {
		t.Errorf("balance = %d, want 120", bal)
	}
	if len(got.Inventory) != 2 {
		t.Errorf("inventory = %d cards, want 2", len(got.Inventory))
	}

	// Buying the same template again stacks quantity, not a new row.
	if err := s.Coaches.BuyCards(coach.ID, map[uint8]int32{1: 10},
		[]GrantCard{{TemplateID: 700, Quantity: 2}}); err != nil {
		t.Fatalf("BuyCards stack: %v", err)
	}
	got2, _ := s.Coaches.Get(coach.ID)
	if len(got2.Inventory) != 2 {
		t.Errorf("inventory after stacking = %d, want 2 rows", len(got2.Inventory))
	}
	var qty700 int16
	for _, c := range got2.Inventory {
		if c.TemplateID == 700 {
			qty700 = c.Quantity
		}
	}
	if qty700 != 3 {
		t.Errorf("template 700 qty = %d, want 3", qty700)
	}

	// Insufficient funds: cost exceeds balance -> ErrInsufficientFunds, no change.
	before, _ := s.Coaches.Get(coach.ID)
	if err := s.Coaches.BuyCards(coach.ID, map[uint8]int32{1: 999999},
		[]GrantCard{{TemplateID: 800, Quantity: 1}}); err != ErrInsufficientFunds {
		t.Fatalf("over-budget buy err = %v, want ErrInsufficientFunds", err)
	}
	after, _ := s.Coaches.Get(coach.ID)
	if len(after.Inventory) != len(before.Inventory) {
		t.Error("inventory changed after a rejected (insufficient-funds) buy")
	}
}

func TestLadderRankingQueries(t *testing.T) {
	s := newTestStore(t)
	acc, _ := s.Accounts.CreateAccount("Ladder", "pw", false)

	// Create coaches with varying strengths (0 = unranked).
	mk := func(name string, strength, wins, losses int32) *domain.Coach {
		c, err := s.Coaches.Create(acc.ID, name, 0, 0, 0)
		if err != nil {
			t.Fatalf("create %s: %v", name, err)
		}
		c.Strength, c.StatWins, c.StatLosses = strength, wins, losses
		if err := s.Coaches.Save(c); err != nil {
			t.Fatalf("save %s: %v", name, err)
		}
		return c
	}
	top := mk("Top", 3000, 30, 5)
	mid := mk("Mid", 2000, 20, 10)
	low := mk("Low", 1000, 10, 20)
	unranked := mk("Unranked", 0, 0, 0)

	// Count = only the 3 ranked coaches.
	if n, _ := s.Coaches.LadderCount(); n != 3 {
		t.Errorf("LadderCount = %d, want 3 (unranked excluded)", n)
	}

	// Page ordered by strength desc.
	page, err := s.Coaches.LadderPage(0, 10)
	if err != nil {
		t.Fatalf("LadderPage: %v", err)
	}
	if len(page) != 3 {
		t.Fatalf("page len = %d, want 3", len(page))
	}
	if page[0].Name != "Top" || page[1].Name != "Mid" || page[2].Name != "Low" {
		t.Errorf("order = %s,%s,%s, want Top,Mid,Low", page[0].Name, page[1].Name, page[2].Name)
	}
	if page[0].StatWins != 30 || page[0].Strength != 3000 {
		t.Errorf("top row = str %d wins %d, want 3000/30", page[0].Strength, page[0].StatWins)
	}

	// Offset paging.
	if p, _ := s.Coaches.LadderPage(1, 10); len(p) != 2 || p[0].Name != "Mid" {
		t.Errorf("offset page wrong: %+v", p)
	}

	// Ranks.
	if rk, _ := s.Coaches.LadderRank(top.ID); rk != 1 {
		t.Errorf("Top rank = %d, want 1", rk)
	}
	if rk, _ := s.Coaches.LadderRank(mid.ID); rk != 2 {
		t.Errorf("Mid rank = %d, want 2", rk)
	}
	if rk, _ := s.Coaches.LadderRank(low.ID); rk != 3 {
		t.Errorf("Low rank = %d, want 3", rk)
	}
	if rk, _ := s.Coaches.LadderRank(unranked.ID); rk != 0 {
		t.Errorf("Unranked rank = %d, want 0", rk)
	}
}

func TestConsumeAndGrant(t *testing.T) {
	s := newTestStore(t)
	acc, _ := s.Accounts.CreateAccount("Fuser", "pw", false)
	coach, _ := s.Coaches.Create(acc.ID, "Alchemist", 0, 0, 0)

	// Seed: 2× card 10, 1× card 11.
	s.DB().Create(&domain.CoachCard{CoachID: coach.ID, TemplateID: 10, Quantity: 2})
	s.DB().Create(&domain.CoachCard{CoachID: coach.ID, TemplateID: 11, Quantity: 1})

	// Consume one 10 and one 11, grant a 99.
	if err := s.Coaches.ConsumeAndGrant(coach.ID, []int32{10, 11}, 99); err != nil {
		t.Fatalf("ConsumeAndGrant: %v", err)
	}
	got, _ := s.Coaches.Get(coach.ID)
	qty := map[int32]int16{}
	for _, c := range got.Inventory {
		qty[c.TemplateID] += c.Quantity
	}
	if qty[10] != 1 { // 2 -> 1
		t.Errorf("card 10 qty = %d, want 1", qty[10])
	}
	if _, has := qty[11]; has { // 1 -> 0, row deleted
		t.Errorf("card 11 should be gone, qty = %d", qty[11])
	}
	if qty[99] != 1 { // granted
		t.Errorf("card 99 qty = %d, want 1", qty[99])
	}

	// Consuming a card the coach doesn't own rolls back with ErrCardNotOwned.
	before, _ := s.Coaches.Get(coach.ID)
	if err := s.Coaches.ConsumeAndGrant(coach.ID, []int32{10, 12345}, 88); err != ErrCardNotOwned {
		t.Fatalf("consume unowned err = %v, want ErrCardNotOwned", err)
	}
	after, _ := s.Coaches.Get(coach.ID)
	if len(after.Inventory) != len(before.Inventory) {
		t.Error("inventory changed after a rejected consume")
	}
	// Card 10 must still be 1 (not decremented by the rolled-back call).
	var q10 int16
	for _, c := range after.Inventory {
		if c.TemplateID == 10 {
			q10 = c.Quantity
		}
	}
	if q10 != 1 {
		t.Errorf("card 10 qty after rollback = %d, want 1", q10)
	}
}

func TestFighterSaveLoadout(t *testing.T) {
	s := newTestStore(t)
	acc, _ := s.Accounts.CreateAccount("Loadout", "pw", false)
	coach, _ := s.Coaches.Create(acc.ID, "Owner", 0, 0, 0)

	f := &domain.Fighter{
		CoachID: coach.ID, BreedID: 5, Name: "Champ",
		Spells:  []domain.FighterSpell{{Slot: 0, SpellID: 1}},
		Objects: []domain.FighterObject{{Slot: 0, TemplateID: 10}},
	}
	if err := s.Fighters.Create(f); err != nil {
		t.Fatalf("Create fighter: %v", err)
	}

	// Replace the loadout entirely with new cards + slotted spells.
	cards := []domain.FighterObject{{TemplateID: 101, Slot: 0}, {TemplateID: 102, Slot: 1}}
	spells := []domain.FighterSpell{{Slot: 0, SpellID: 555}, {Slot: 2, SpellID: 557}}
	if err := s.Fighters.SaveLoadout(f.ID, coach.ID, cards, spells, 900); err != nil {
		t.Fatalf("SaveLoadout: %v", err)
	}

	got, err := s.Fighters.Get(f.ID)
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	if len(got.Objects) != 2 || len(got.Spells) != 2 {
		t.Fatalf("loadout not replaced: %d cards, %d spells", len(got.Objects), len(got.Spells))
	}
	if got.Budget != 900 {
		t.Errorf("budget = %d, want 900", got.Budget)
	}
	slots := map[int16]int32{}
	for _, sp := range got.Spells {
		slots[sp.Slot] = sp.SpellID
	}
	if slots[0] != 555 || slots[2] != 557 {
		t.Errorf("spell slots = %+v, want {0:555,2:557}", slots)
	}

	// IDOR guard: a non-owner coach id cannot modify the loadout.
	other, _ := s.Coaches.Create(acc.ID, "Intruder", 0, 0, 0)
	if err := s.Fighters.SaveLoadout(f.ID, other.ID, nil, nil, 0); err != ErrNotFound {
		t.Errorf("SaveLoadout by non-owner err = %v, want ErrNotFound", err)
	}
	// Loadout must be untouched after the rejected save.
	after, _ := s.Fighters.Get(f.ID)
	if len(after.Objects) != 2 || len(after.Spells) != 2 {
		t.Errorf("loadout changed after rejected save: %d cards, %d spells",
			len(after.Objects), len(after.Spells))
	}
}
