// dumpcards dumps every coach-card template into a JSON table for the Godot
// client's shop/inventory UI: {"<id>": {"type","set","value","price":{t:amt}}},
// plus the resurrection, fusion and firework fields the client uses.
// Card display names come from i18n content.23 (merged by card_names.py).
//
// Usage: go run ./cmd/dumpcards <data-dir> <cards.json> [fusionlabs.json]
package main

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

type labRec struct {
	Power   int16 `json:"power"`
	Quality uint8 `json:"quality"`
	Slots   uint8 `json:"slots"`
}

type rec struct {
	Type      int32           `json:"type"`
	Set       int32           `json:"set"`
	Value     int32           `json:"value"`
	Price     map[uint8]int32 `json:"price"`
	Unique    bool            `json:"unique,omitempty"`
	Tradable  bool            `json:"tradable"`            // !Bound && !Undestructible
	Resurrect int32           `json:"resurrect,omitempty"` // % chance (action 13)
	ReqLevel  int32           `json:"reqLevel,omitempty"`
	FusPower  int16           `json:"fusPower,omitempty"` // fusion lab target/input power
	FusQual   uint8           `json:"fusQuality,omitempty"`
	// Firework cards (type 25): the particle kind (tl()) and its RGB colour
	// (tk(), 0..255 per channel) — the Godot lobby draws the show from them.
	FwType   uint8     `json:"fwType,omitempty"`
	FwColour []float32 `json:"fwColour,omitempty"`
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
			ReqLevel:  c.RequiredLevel,
			FusPower:  c.FusionPower,
			FusQual:   c.FusionQuality,
			FwType:    c.FireworkType,
			FwColour:  c.FireworkColour,
		}
	}
	b, _ := json.Marshal(res)
	if err := os.WriteFile(out, b, 0o644); err != nil {
		panic(err)
	}
	fmt.Println("wrote", out, "cards:", cards.Len())
	if len(os.Args) > 3 {
		labs, err := st.LoadFusionLabs()
		if err != nil {
			panic(err)
		}
		lres := map[string]labRec{}
		for _, l := range labs.All() {
			lres[fmt.Sprint(l.ID)] = labRec{
				Power: l.Power, Quality: l.Quality, Slots: l.Slots}
		}
		lb, _ := json.Marshal(lres)
		if err := os.WriteFile(os.Args[3], lb, 0o644); err != nil {
			panic(err)
		}
		fmt.Println("wrote", os.Args[3], "labs:", len(lres))
	}
}
