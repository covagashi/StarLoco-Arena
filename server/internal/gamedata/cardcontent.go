package gamedata

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"path"
	"path/filepath"
	"sort"
	"strings"
)

// cardcontent.go reads and writes the game's own card data (S40, path A): the
// same structs the data.bdat decoders produce, as JSON in server/content/cards/
// (embedded into the binary by package content). The ids are the retail ones,
// so the players' inventories need no migration.
//
//	coach/set_<id>.json  the coach cards of one card set, by id
//	sets.json            the card-set definitions (their threshold bonuses)
//	fighter.json         the fighter cards (weapons and gear)
//	events.json          the per-round event cards
//
// Each file is a JSON array with one record per line, so a redesign diffs card
// by card. The field names are the Go ones; nothing is omitted, so a nil list
// and an empty one survive the round trip and the parity test can compare the
// decoded structs exactly.

// CardContent is the card data of one content tree.
type CardContent struct {
	Cards    *Cards
	Sets     *CardSets
	Fighters *FighterCards
	Events   *Events
}

const (
	cardContentCoachDir = "coach"
	cardContentSets     = "sets.json"
	cardContentFighters = "fighter.json"
	cardContentEvents   = "events.json"
)

// LoadCardContent decodes a card content tree (content.Cards, or os.DirFS of a
// checkout). A missing or malformed file is an error: unlike the retail data,
// this is ours and must load whole.
func LoadCardContent(fsys fs.FS) (*CardContent, error) {
	var coach []*CoachCard
	files, err := fs.Glob(fsys, path.Join(cardContentCoachDir, "set_*.json"))
	if err != nil {
		return nil, err
	}
	if len(files) == 0 {
		return nil, fmt.Errorf("card content: no %s/set_*.json", cardContentCoachDir)
	}
	seen := map[int32]string{}
	for _, f := range files {
		var part []*CoachCard
		if err := readContentFile(fsys, f, &part); err != nil {
			return nil, err
		}
		for _, c := range part {
			if prev, dup := seen[c.ID]; dup {
				return nil, fmt.Errorf("card content: card %d is in %s and %s", c.ID, prev, f)
			}
			seen[c.ID] = f
		}
		coach = append(coach, part...)
	}
	var sets []*CardSet
	if err := readContentFile(fsys, cardContentSets, &sets); err != nil {
		return nil, err
	}
	var fighters []*FighterCard
	if err := readContentFile(fsys, cardContentFighters, &fighters); err != nil {
		return nil, err
	}
	var events []*Event
	if err := readContentFile(fsys, cardContentEvents, &events); err != nil {
		return nil, err
	}
	return &CardContent{
		Cards:    NewCards(coach...),
		Sets:     NewCardSets(sets...),
		Fighters: NewFighterCards(fighters...),
		Events:   NewEvents(events...),
	}, nil
}

func readContentFile(fsys fs.FS, name string, into any) error {
	b, err := fs.ReadFile(fsys, name)
	if err != nil {
		return fmt.Errorf("card content: %w", err)
	}
	dec := json.NewDecoder(bytes.NewReader(b))
	dec.DisallowUnknownFields() // a misspelt field must not vanish silently
	if err := dec.Decode(into); err != nil {
		return fmt.Errorf("card content: %s: %w", name, err)
	}
	return nil
}

// WriteCardContent writes c as a content tree under dir, replacing the coach
// set files that are there. It is how the retail tables were turned into ours
// (cmd/exportcards), and the inverse of LoadCardContent.
func WriteCardContent(dir string, c *CardContent) error {
	coachDir := filepath.Join(dir, cardContentCoachDir)
	if err := os.MkdirAll(coachDir, 0o755); err != nil {
		return err
	}
	old, _ := filepath.Glob(filepath.Join(coachDir, "set_*.json"))
	for _, f := range old {
		if err := os.Remove(f); err != nil {
			return err
		}
	}
	bySet := map[int32][]*CoachCard{}
	for _, card := range c.Cards.All() {
		bySet[card.CardSet] = append(bySet[card.CardSet], card)
	}
	for set, cards := range bySet {
		sort.Slice(cards, func(i, j int) bool { return cards[i].ID < cards[j].ID })
		name := filepath.Join(coachDir, fmt.Sprintf("set_%03d.json", set))
		if err := writeContentFile(name, cards); err != nil {
			return err
		}
	}
	var sets []*CardSet
	for _, id := range c.Sets.IDs() {
		sets = append(sets, c.Sets.Get(id))
	}
	if err := writeContentFile(filepath.Join(dir, cardContentSets), sets); err != nil {
		return err
	}
	var fighters []*FighterCard
	for _, fc := range c.Fighters.All() {
		fighters = append(fighters, fc)
	}
	sort.Slice(fighters, func(i, j int) bool { return fighters[i].ID < fighters[j].ID })
	if err := writeContentFile(filepath.Join(dir, cardContentFighters), fighters); err != nil {
		return err
	}
	var events []*Event
	for _, id := range c.Events.IDs() {
		events = append(events, c.Events.Get(id))
	}
	return writeContentFile(filepath.Join(dir, cardContentEvents), events)
}

// writeContentFile writes recs as a JSON array, one compact record per line.
func writeContentFile[T any](name string, recs []T) error {
	var sb strings.Builder
	sb.WriteString("[\n")
	for i, r := range recs {
		b, err := json.Marshal(r)
		if err != nil {
			return fmt.Errorf("%s: %w", name, err)
		}
		sb.Write(b)
		if i < len(recs)-1 {
			sb.WriteByte(',')
		}
		sb.WriteByte('\n')
	}
	sb.WriteString("]\n")
	return os.WriteFile(name, []byte(sb.String()), 0o644)
}

// LoadRetailCardContent decodes the same four tables from a data.bdat
// directory, as they come (before ApplyCardMasterPrices). It is the source of
// cmd/exportcards and the reference of the parity test.
func LoadRetailCardContent(bdatDir string) (*CardContent, error) {
	st, err := Open(bdatDir)
	if err != nil {
		return nil, err
	}
	c := &CardContent{}
	if c.Cards, err = st.LoadCards(); err != nil {
		return nil, err
	}
	if c.Sets, err = st.LoadCardSets(); err != nil {
		return nil, err
	}
	if c.Fighters, err = st.LoadFighterCards(); err != nil {
		return nil, err
	}
	if c.Events, err = st.LoadEvents(); err != nil {
		return nil, err
	}
	return c, nil
}
