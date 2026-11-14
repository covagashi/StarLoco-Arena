package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/StarLoco/arena-2.70/content"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// cardedit.go: the cards are the game's own data since S40, in the checkout's
// server/content/cards (proprietary, see its LICENSE), not in data.bdat. The
// studio reads them from there, whatever data directory is selected, and its
// card editor writes them back with gamedata.WriteCardContent, which keeps one
// card per line so a saved edit diffs as that card alone. Away from a checkout
// it shows the cards embedded in the binary, read-only.

// ensureCards loads the card content once (caller holds a.mu).
func (a *App) ensureCards() error {
	if a.cardContent != nil {
		return nil
	}
	var (
		cc  *gamedata.CardContent
		err error
	)
	if a.paths.ContentDir != "" {
		cc, err = gamedata.LoadCardContent(os.DirFS(a.paths.ContentDir))
	} else {
		cc, err = gamedata.LoadCardContent(content.Cards)
	}
	if err != nil {
		return err
	}
	a.cardContent = cc
	return nil
}

// detectContentDir finds server/content/cards from the working directory or
// the executable, the same way detectPaths finds the data store.
func detectContentDir() string {
	for _, root := range candidateRoots() {
		for _, rel := range []string{filepath.Join("server", "content", "cards"), filepath.Join("content", "cards")} {
			dir := filepath.Join(root, rel)
			if fileExists(filepath.Join(dir, "sets.json")) && isDir(filepath.Join(dir, "coach")) {
				return dir
			}
		}
	}
	return ""
}

// CoachCardEdit is what the editor can change on a coach card: its balance and
// economy fields. Effects and parameters stay as they are (the redesign of
// what a card does is S40 step 2).
type CoachCardEdit struct {
	ID               int32  `json:"id"`
	Value            int32  `json:"value"`
	Rank             int32  `json:"rank"`
	Price            string `json:"price"` // "currency:amount, ..."; empty = not purchasable
	RequiredLevel    int32  `json:"reqLevel"`
	ObtainableInDraw bool   `json:"inDraw"`
	DropPercent      int32  `json:"dropPercent"`
	Bound            bool   `json:"bound"`
	Undestructible   bool   `json:"undestructible"`
}

// maxRank is the highest rank in the data (0..10); the card template's
// rarity metal is derived from it.
const maxRank = 10

// UpdateCoachCard validates an edit, applies it and saves the content tree.
// Nothing changes, in memory or on disk, when it returns an error.
func (a *App) UpdateCoachCard(e CoachCardEdit) error {
	a.mu.Lock()
	defer a.mu.Unlock()
	if err := a.ensureCards(); err != nil {
		return err
	}
	if a.paths.ContentDir == "" {
		return fmt.Errorf("read-only: server/content/cards not found (run the studio from a checkout)")
	}
	c := a.cardContent.Cards.Get(e.ID)
	if c == nil {
		return fmt.Errorf("no coach card %d", e.ID)
	}
	price, err := parsePrice(e.Price)
	if err != nil {
		return err
	}
	switch {
	case e.Value < 0:
		return fmt.Errorf("value must be 0 or more")
	case e.Rank < 0 || e.Rank > maxRank:
		return fmt.Errorf("rank must be 0..%d", maxRank)
	case e.RequiredLevel < 0:
		return fmt.Errorf("required level must be 0 or more")
	case e.DropPercent < 0 || e.DropPercent > 100:
		return fmt.Errorf("drop percent must be 0..100")
	}
	next := *c
	next.Value, next.Rank, next.Price = e.Value, e.Rank, price
	next.RequiredLevel, next.ObtainableInDraw, next.DropPercent = e.RequiredLevel, e.ObtainableInDraw, e.DropPercent
	next.Bound, next.Undestructible = e.Bound, e.Undestructible
	prev := *c
	*c = next
	if err := gamedata.WriteCardContent(a.contentRoot(), a.cardContent); err != nil {
		*c = prev
		return err
	}
	return nil
}

// FighterCardEdit is what the editor can change on a fighter card: its value
// and its weapon attack's cost and range.
type FighterCardEdit struct {
	ID       int32 `json:"id"`
	Value    int32 `json:"value"`
	APCost   int32 `json:"apCost"`
	RangeMin int32 `json:"rangeMin"`
	RangeMax int32 `json:"rangeMax"`
}

// UpdateFighterCard validates an edit, applies it and saves the content tree.
func (a *App) UpdateFighterCard(e FighterCardEdit) error {
	a.mu.Lock()
	defer a.mu.Unlock()
	if err := a.ensureCards(); err != nil {
		return err
	}
	if a.paths.ContentDir == "" {
		return fmt.Errorf("read-only: server/content/cards not found (run the studio from a checkout)")
	}
	c := a.cardContent.Fighters.Get(e.ID)
	if c == nil {
		return fmt.Errorf("no fighter card %d", e.ID)
	}
	switch {
	case e.Value < 0:
		return fmt.Errorf("value must be 0 or more")
	case e.APCost < 0 || e.APCost > 12:
		return fmt.Errorf("AP cost must be 0..12")
	case e.RangeMin < 0 || e.RangeMax < e.RangeMin:
		return fmt.Errorf("range must be 0 <= min <= max")
	}
	prev := *c
	c.Value, c.APCost, c.RangeMin, c.RangeMax = e.Value, e.APCost, e.RangeMin, e.RangeMax
	if err := gamedata.WriteCardContent(a.contentRoot(), a.cardContent); err != nil {
		*c = prev
		return err
	}
	return nil
}

// contentRoot is the directory WriteCardContent writes into.
func (a *App) contentRoot() string { return a.paths.ContentDir }

// parsePrice is formatPrice's inverse: "1:10, 2:5" -> {1:10, 2:5}, "" -> nil.
func parsePrice(s string) (map[uint8]int32, error) {
	s = strings.TrimSpace(s)
	if s == "" {
		return nil, nil
	}
	out := map[uint8]int32{}
	for _, part := range strings.Split(s, ",") {
		cur, amt, ok := strings.Cut(strings.TrimSpace(part), ":")
		if !ok {
			return nil, fmt.Errorf("price %q: want currency:amount pairs, e.g. 1:10", part)
		}
		c, err := strconv.Atoi(strings.TrimSpace(cur))
		if err != nil || c < 1 || c > 255 {
			return nil, fmt.Errorf("price %q: currency must be 1..255", part)
		}
		n, err := strconv.Atoi(strings.TrimSpace(amt))
		if err != nil || n < 0 {
			return nil, fmt.Errorf("price %q: amount must be 0 or more", part)
		}
		if _, dup := out[uint8(c)]; dup {
			return nil, fmt.Errorf("price: currency %d twice", c)
		}
		out[uint8(c)] = int32(n)
	}
	return out, nil
}
