// dumpcards dumps every coach-card template into a JSON table for the Godot
// client's shop/inventory UI: {"<id>": {"type","set","value","price":{t:amt}}}.
// Card display names come from i18n content.23 (merged by card_names.py).
//
// Usage: go run ./cmd/dumpcards <data-dir> <out.json>
package main

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

type rec struct {
	Type      int32           `json:"type"`
	Set       int32           `json:"set"`
	Value     int32           `json:"value"`
	Price     map[uint8]int32 `json:"price"`
	Unique    bool            `json:"unique,omitempty"`
	Tradable  bool            `json:"tradable"`            // !Bound && !Undestructible
	Resurrect int32           `json:"resurrect,omitempty"` // % chance (action 13)
}

func main() {
	dir, out := os.Args[1], os.Args[2]
	st, err := gamedata.Open(dir)
	if err != nil {
		panic(err)
	}
	cards, err := st.LoadCards()
	if err != nil {
		panic(err)
	}
	res := map[string]rec{}
	for id, c := range cards.All() {
		res[fmt.Sprint(id)] = rec{
			Type: c.Type, Set: c.CardSet, Value: c.Value,
			Price:     c.Price,
			Unique:    c.IsUnique,
			Tradable:  !c.Bound && !c.Undestructible,
			Resurrect: c.ResurrectPercent,
		}
	}
	b, _ := json.Marshal(res)
	if err := os.WriteFile(out, b, 0o644); err != nil {
		panic(err)
	}
	fmt.Println("wrote", out, "cards:", cards.Len())
}
