package gamedata

import (
	"fmt"
	"io/fs"
	"slices"
)

// Breed is one fighter class's base combat stats (S46): what a fighter has
// before its cards. The values started as the 2.70 client's breed table (see
// internal/game/breed.go for how each column was pinned); since S46 they are
// ours, in server/content/rules/breeds.json, and the balance pass edits them
// there. Names are ours too (S41, OwnText breed.<id>).
type Breed struct {
	ID         uint8
	HP, AP, MP int32
	// Init orders the turn timeline and decides which team chooses to open.
	Init int32
	// CCElement is the close-combat (punch) element: 1 fire, 2 earth, 3 water,
	// 4 air (game's elem* constants).
	CCElement int
	// Block holds an adjacent enemy in place, Dodge slips away (tackle.go), in %.
	Block, Dodge int32
}

// Breeds is the class table, by id.
type Breeds struct {
	byID map[uint8]*Breed
}

// NewBreeds indexes the given classes by id.
func NewBreeds(bs ...*Breed) *Breeds {
	m := make(map[uint8]*Breed, len(bs))
	for _, b := range bs {
		m[b.ID] = b
	}
	return &Breeds{byID: m}
}

// Get returns a class, or nil.
func (b *Breeds) Get(id uint8) *Breed {
	if b == nil {
		return nil
	}
	return b.byID[id]
}

// All returns every class, by id.
func (b *Breeds) All() []*Breed {
	out := make([]*Breed, 0, len(b.byID))
	for _, x := range b.byID {
		out = append(out, x)
	}
	slices.SortFunc(out, func(x, y *Breed) int { return int(x.ID) - int(y.ID) })
	return out
}

// LoadBreeds decodes just the class table of a rules content tree: the
// fight code reads it at start-up without the rest of the rules.
func LoadBreeds(fsys fs.FS) (*Breeds, error) {
	var bs []*Breed
	if err := readContentFile(fsys, rulesBreeds, &bs); err != nil {
		return nil, err
	}
	if len(bs) == 0 {
		return nil, fmt.Errorf("rules content: %s is empty", rulesBreeds)
	}
	return NewBreeds(bs...), nil
}
