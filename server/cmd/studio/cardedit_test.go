package main

import (
	"io/fs"
	"os"
	"path/filepath"
	"testing"

	"github.com/StarLoco/arena-2.70/content"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// contentCopy writes the embedded card content to a temp dir and checks that
// writing reproduces the committed files byte for byte, so a save in the
// editor never rewrites cards it did not touch.
func contentCopy(t *testing.T) string {
	t.Helper()
	cc, err := gamedata.LoadCardContent(content.Cards)
	if err != nil {
		t.Fatal(err)
	}
	dir := t.TempDir()
	if err := gamedata.WriteCardContent(dir, cc); err != nil {
		t.Fatal(err)
	}
	err = fs.WalkDir(content.Cards, ".", func(p string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		want, _ := fs.ReadFile(content.Cards, p)
		got, err := os.ReadFile(filepath.Join(dir, p))
		if err != nil {
			return err
		}
		if string(got) != string(want) {
			t.Errorf("%s: a rewrite of the unchanged content differs", p)
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	return dir
}

func snapshot(t *testing.T, dir string) map[string]string {
	t.Helper()
	out := map[string]string{}
	_ = filepath.WalkDir(dir, func(p string, d fs.DirEntry, err error) error {
		if err == nil && !d.IsDir() {
			b, _ := os.ReadFile(p)
			rel, _ := filepath.Rel(dir, p)
			out[rel] = string(b)
		}
		return nil
	})
	return out
}

func TestUpdateCoachCardSavesOnlyItsSet(t *testing.T) {
	dir := contentCopy(t)
	a := &App{paths: Paths{ContentDir: dir}} // no data dir: the cards do not need one
	cards, err := a.GetCoachCards()
	if err != nil || len(cards) != 907 {
		t.Fatalf("GetCoachCards without a data dir: %d cards, %v", len(cards), err)
	}
	var card CoachCardDTO
	for _, c := range cards {
		if c.ID == 16 {
			card = c
		}
	}
	before := snapshot(t, dir)

	edit := CoachCardEdit{ID: 16, Value: card.Value + 1, Rank: 7, Price: "1:25, 3:2",
		RequiredLevel: 10, ObtainableInDraw: !card.ObtainableInDraw, DropPercent: 50, Bound: true}
	if err := a.UpdateCoachCard(edit); err != nil {
		t.Fatal(err)
	}
	after := snapshot(t, dir)
	for name := range before {
		changed := before[name] != after[name]
		if want := name == filepath.Join("coach", "set_005.json"); changed != want {
			t.Errorf("%s changed=%v, want %v", name, changed, want)
		}
	}
	// What is on disk is what the server will load.
	cc, err := gamedata.LoadCardContent(os.DirFS(dir))
	if err != nil {
		t.Fatal(err)
	}
	c := cc.Cards.Get(16)
	if c.Value != card.Value+1 || c.Rank != 7 || c.Price[1] != 25 || c.Price[3] != 2 || len(c.Price) != 2 ||
		c.RequiredLevel != 10 || c.ObtainableInDraw == card.ObtainableInDraw || c.DropPercent != 50 || !c.Bound {
		t.Fatalf("saved card %+v", c)
	}
	if len(c.Effects) == 0 {
		t.Fatal("the edit dropped the card's effects")
	}

	// A bad edit changes nothing, on disk or in what the studio shows.
	for _, bad := range []CoachCardEdit{
		{ID: 16, Rank: 11}, {ID: 16, Value: -1}, {ID: 16, Price: "1-10"}, {ID: 16, Price: "0:5"},
		{ID: 16, Price: "1:5, 1:6"}, {ID: 16, DropPercent: 101}, {ID: 999999},
	} {
		if err := a.UpdateCoachCard(bad); err == nil {
			t.Errorf("edit %+v accepted", bad)
		}
	}
	if snap := snapshot(t, dir); snap[filepath.Join("coach", "set_005.json")] != after[filepath.Join("coach", "set_005.json")] {
		t.Fatal("a rejected edit changed the file")
	}
	// An empty price makes the card not purchasable.
	edit.Price = ""
	if err := a.UpdateCoachCard(edit); err != nil {
		t.Fatal(err)
	}
	if cc, _ := gamedata.LoadCardContent(os.DirFS(dir)); cc.Cards.Get(16).Price != nil {
		t.Fatal("an empty price did not clear it")
	}
}

func TestUpdateFighterCard(t *testing.T) {
	dir := contentCopy(t)
	a := &App{paths: Paths{ContentDir: dir}}
	fcs, err := a.GetFighterCards()
	if err != nil || len(fcs) != 75 {
		t.Fatalf("GetFighterCards: %d, %v", len(fcs), err)
	}
	var usable FighterCardDTO
	for _, f := range fcs {
		if f.Usable {
			usable = f
			break
		}
	}
	if err := a.UpdateFighterCard(FighterCardEdit{ID: usable.ID, Value: 5, APCost: 3, RangeMin: 1, RangeMax: 4}); err != nil {
		t.Fatal(err)
	}
	cc, _ := gamedata.LoadCardContent(os.DirFS(dir))
	if f := cc.Fighters.Get(usable.ID); f.Value != 5 || f.APCost != 3 || f.RangeMin != 1 || f.RangeMax != 4 || !f.Usable() {
		t.Fatalf("saved fighter card %+v", f)
	}
	for _, bad := range []FighterCardEdit{{ID: usable.ID, RangeMin: 3, RangeMax: 2}, {ID: usable.ID, APCost: 13}, {ID: -1}} {
		if err := a.UpdateFighterCard(bad); err == nil {
			t.Errorf("edit %+v accepted", bad)
		}
	}
}

// Away from a checkout the studio shows the embedded cards and refuses edits.
func TestCardsReadOnlyWithoutCheckout(t *testing.T) {
	a := &App{}
	cards, err := a.GetCoachCards()
	if err != nil || len(cards) != 907 {
		t.Fatalf("embedded cards: %d, %v", len(cards), err)
	}
	if err := a.UpdateCoachCard(CoachCardEdit{ID: cards[0].ID}); err == nil {
		t.Fatal("an edit was accepted with no content dir")
	}
}

func TestDetectContentDirFromCheckout(t *testing.T) {
	// The tests run in server/cmd/studio, inside the checkout.
	dir := detectContentDir()
	if dir == "" || !fileExists(filepath.Join(dir, "sets.json")) {
		t.Fatalf("detectContentDir = %q", dir)
	}
}
