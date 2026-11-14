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

// TestCardContentParity is S40's step-1 gate: the embedded content tree holds
// exactly what the retail tables decode to, record by record. It holds until
// the redesign starts changing cards on purpose; from then on, retire it set by
// set (or pin the sets still untouched).
func TestCardContentParity(t *testing.T) {
	if _, err := os.Stat(filepath.Join(clientBdataDir, "data.bdat")); err != nil {
		t.Skip("no client data")
	}
	retail, err := LoadRetailCardContent(clientBdataDir)
	if err != nil {
		t.Fatal(err)
	}
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
