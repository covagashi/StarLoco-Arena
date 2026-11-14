package gamedata

import (
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"reflect"
	"testing"
	"testing/fstest"

	"github.com/StarLoco/arena-2.70/content"
)

// TestCardContentParity: the embedded content is exactly the retail tables
// with the S40 rules applied (cardrules.go), record by record. A redesign that
// changes cards on purpose goes in the rules, or retires this test set by set.
func TestCardContentParity(t *testing.T) {
	if _, err := os.Stat(filepath.Join(clientBdataDir, "data.bdat")); err != nil {
		t.Skip("no client data")
	}
	retail, err := LoadRetailCardContent(clientBdataDir)
	if err != nil {
		t.Fatal(err)
	}
	// The content is the retail tables plus the S40 rules, nothing else.
	ApplyCardRules(retail)
	own, err := LoadCardContent(content.Cards)
	if err != nil {
		t.Fatal(err)
	}
	if retail.Cards.Len() != own.Cards.Len() {
		t.Fatalf("coach cards: retail %d, content %d", retail.Cards.Len(), own.Cards.Len())
	}
	for id, want := range retail.Cards.All() {
		if got := own.Cards.Get(id); !reflect.DeepEqual(got, want) {
			t.Errorf("coach card %d differs:\n content %+v\n retail  %+v", id, got, want)
		}
	}
	if !reflect.DeepEqual(own.Sets.IDs(), retail.Sets.IDs()) {
		t.Fatalf("card sets: content %v, retail %v", own.Sets.IDs(), retail.Sets.IDs())
	}
	for _, id := range retail.Sets.IDs() {
		if got, want := own.Sets.Get(id), retail.Sets.Get(id); !reflect.DeepEqual(got, want) {
			t.Errorf("card set %d differs:\n content %+v\n retail  %+v", id, got, want)
		}
	}
	if !reflect.DeepEqual(own.Fighters.All(), retail.Fighters.All()) {
		t.Errorf("fighter cards differ (%d content, %d retail)", own.Fighters.Len(), retail.Fighters.Len())
	}
	if !reflect.DeepEqual(own.Events.IDs(), retail.Events.IDs()) {
		t.Fatalf("events: content %v, retail %v", own.Events.IDs(), retail.Events.IDs())
	}
	for _, id := range retail.Events.IDs() {
		if got, want := own.Events.Get(id), retail.Events.Get(id); !reflect.DeepEqual(got, want) {
			t.Errorf("event %d differs:\n content %+v\n retail  %+v", id, got, want)
		}
	}
}

// TestCardContentRoundTrip writes a tree and reads it back, so the format
// keeps its promises without the retail data: nil and empty lists, the price
// map, a card in two set files.
func TestCardContentRoundTrip(t *testing.T) {
	in := &CardContent{
		Cards: NewCards(
			&CoachCard{ID: 1, CardSet: 5, Value: 79, Price: map[uint8]int32{1: 10}, Effects: []CardSetEffect{{Action: 13, Params: []int32{12}}}},
			&CoachCard{ID: 2, CardSet: 0, Effects: []CardSetEffect{}},
		),
		Sets:     NewCardSets(&CardSet{ID: 5, Effects: []CardSetEffect{{Action: 5, Params: []int32{-1}, Threshold: 3}}}),
		Fighters: NewFighterCards(&FighterCard{ID: 9, APCost: 4, UseEffects: []Effect{{ActionID: 100, Params: []float32{0.5, 3}}}}),
		Events:   NewEvents(&Event{ID: 3, DescriptionFlag: true}),
	}
	dir := t.TempDir()
	if err := WriteCardContent(dir, in); err != nil {
		t.Fatal(err)
	}
	out, err := LoadCardContent(os.DirFS(dir))
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(out, in) {
		t.Fatalf("round trip differs:\n got  %+v\n want %+v", out, in)
	}

	// The same card in two set files is refused, not silently overwritten.
	fsys := fstest.MapFS{
		"coach/set_001.json": {Data: []byte(`[{"ID":7}]`)},
		"coach/set_002.json": {Data: []byte(`[{"ID":7}]`)},
		"sets.json":          {Data: []byte(`[]`)},
		"fighter.json":       {Data: []byte(`[]`)},
		"events.json":        {Data: []byte(`[]`)},
	}
	if _, err := LoadCardContent(fsys); err == nil {
		t.Fatal("a card in two set files loaded")
	}
	// A misspelt field is an error.
	fsys["coach/set_002.json"] = &fstest.MapFile{Data: []byte(`[{"ID":8,"Valeu":3}]`)}
	if _, err := LoadCardContent(fsys); err == nil {
		t.Fatal("a misspelt field loaded")
	}
}

// TestBundleCardsWithoutRetailData: with no data.bdat at all the server still
// has every card (S43 deletes data-dist), Card Master prices and the drop
// table included.
func TestBundleCardsWithoutRetailData(t *testing.T) {
	b := LoadBundle(Location{}, slog.New(slog.NewTextHandler(io.Discard, nil)))
	if b.Spells != nil {
		t.Fatal("spells loaded without data.bdat; the test is not isolated")
	}
	if b.Cards.Len() != 907 || b.CardSets.Len() != 138 || b.FighterCards.Len() != 75 || b.Events.Len() != 51 {
		t.Fatalf("cards %d, sets %d, fighter cards %d, events %d",
			b.Cards.Len(), b.CardSets.Len(), b.FighterCards.Len(), b.Events.Len())
	}
	if b.DrawTable == nil {
		t.Fatal("no drop table")
	}
	var derived int
	for _, c := range b.Cards.All() {
		if c.Price[1] >= 10 && c.CardSet >= 5 && c.CardSet <= 16 {
			derived++
		}
	}
	if derived == 0 {
		t.Fatal("no Card Master set card has a token price: ApplyCardMasterPrices did not run")
	}
}

// TestCardContentObeysRules keeps every later edit (the studio, a redesign)
// inside the S40 caps.
func TestCardContentObeysRules(t *testing.T) {
	cc, err := LoadCardContent(content.Cards)
	if err != nil {
		t.Fatal(err)
	}
	for _, v := range CardRuleViolations(cc) {
		t.Error(v)
	}
}

func TestApplyCardRules(t *testing.T) {
	cc := &CardContent{
		Cards: NewCards(
			&CoachCard{ID: 1, Rank: 10, Effects: []CardSetEffect{{Action: 1, Params: []int32{50}}, {Action: 7, Params: []int32{-12}}, {Action: 5, Params: []int32{7}}}},
			&CoachCard{ID: 2, HasUsableAction: true, ResurrectPercent: 100, Effects: []CardSetEffect{{Action: 13, Params: []int32{100}}, {Action: 9, Params: []int32{40}}}},
			&CoachCard{ID: 3, HasUsableAction: true, ResurrectPercent: 1, Effects: []CardSetEffect{{Action: 13, Params: []int32{1}}}},
		),
		Sets:     NewCardSets(&CardSet{ID: 5, Effects: []CardSetEffect{{Action: 2, Params: []int32{50}}, {Action: 13, Params: []int32{20}}, {Action: 1, Params: []int32{-4}}}}),
		Fighters: NewFighterCards(&FighterCard{ID: 28, Value: 200}, &FighterCard{ID: 9, Value: 300}),
		Events:   NewEvents(),
	}
	if len(CardRuleViolations(cc)) == 0 {
		t.Fatal("the raw fixture reports no violation")
	}
	ApplyCardRules(cc)
	c1 := cc.Cards.Get(1)
	if c1.Effects[0].Params[0] != 10 || c1.Effects[1].Params[0] != -5 || c1.Effects[2].Params[0] != 7 {
		t.Fatalf("passive caps: %+v (XP 50 -> 10, death -12 -> -5, a wound malus +7 stays)", c1.Effects)
	}
	if c2 := cc.Cards.Get(2); c2.ResurrectPercent != 25 || c2.Effects[0].Params[0] != 25 || c2.Effects[1].Params[0] != 40 {
		t.Fatalf("consumable: %+v (resurrection to 25, the potion's morale kept)", c2)
	}
	if c3 := cc.Cards.Get(3); c3.ResurrectPercent != 25 {
		t.Fatalf("a 1 %% resurrection card: %d, want 25", c3.ResurrectPercent)
	}
	if s := cc.Sets.Get(5).Effects; s[0].Params[0] != 8 || s[1].Params[0] != 10 || s[2].Params[0] != -4 {
		t.Fatalf("set caps: %+v", s)
	}
	if cc.Fighters.Get(28).Value != 150 || cc.Fighters.Get(9).Value != 300 {
		t.Fatal("fighter-card values")
	}
	if v := CardRuleViolations(cc); len(v) != 0 {
		t.Fatalf("after the rules: %v", v)
	}
	// Idempotent.
	before := *cc.Cards.Get(1)
	ApplyCardRules(cc)
	if cc.Cards.Get(1).Effects[0].Params[0] != before.Effects[0].Params[0] {
		t.Fatal("not idempotent")
	}
}
