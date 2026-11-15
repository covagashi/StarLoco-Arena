// dumpcards dumps every coach-card template into a JSON table for the Godot
// client's shop/inventory UI: {"<id>": {"type","set","value","price":{t:amt}}},
// plus the resurrection, fusion, firework and rarity (rank) fields the client uses.
// No names: since S41 the client names cards itself (godot/assets/i18n/
// content_<lang>.json). S41 also exports each card's effects ("fx": [[action, params...]]) and, beside it
// in cardsetfx.json, each set's ({"<set>": [[threshold, action, params...]]}),
// which the client turns into its own text.
//
// Usage: go run ./cmd/dumpcards <data-dir> <cards.json> [fusionlabs.json]
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"github.com/StarLoco/arena-2.70/content"
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
	Rank      int32           `json:"rank,omitempty"`     // the rarity frame (getRank)
	FusPower  int16           `json:"fusPower,omitempty"` // fusion lab target/input power
	FusQual   uint8           `json:"fusQuality,omitempty"`
	// Firework cards (type 25): the particle kind (tl()) and its RGB colour
	// (tk(), 0..255 per channel) — the Godot lobby draws the show from them.
	FwType   uint8     `json:"fwType,omitempty"`
	FwColour []float32 `json:"fwColour,omitempty"`
	Fx       [][]int32 `json:"fx,omitempty"` // S41: [action, params...] per effect
}

// fxRows flattens effects to [lead..., action, params...] rows.
func fxRows(effs []gamedata.CardSetEffect, lead func(gamedata.CardSetEffect) []int32) [][]int32 {
	var out [][]int32
	for _, e := range effs {
		row := append(lead(e), e.Action)
		out = append(out, append(row, e.Params...))
	}
	return out
}

func main() {
	dir, out := os.Args[1], os.Args[2]
	st, err := gamedata.Open(dir)
	if err != nil {
		panic(err)
	}
	cc, err := gamedata.LoadCardContent(content.Cards) // S40: our cards, not data.bdat
	if err != nil {
		panic(err)
	}
	cards := cc.Cards
	none := func(gamedata.CardSetEffect) []int32 { return nil }
	res := map[string]rec{}
	for id, c := range cards.All() {
		res[fmt.Sprint(id)] = rec{
			Fx:   fxRows(c.Effects, none),
			Type: c.Type, Set: c.CardSet, Value: c.Value,
			Price:     c.Price,
			Unique:    c.IsUnique,
			Tradable:  !c.Bound && !c.Undestructible,
			Resurrect: c.ResurrectPercent,
			ReqLevel:  c.RequiredLevel,
			Rank:      c.Rank,
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
	sets := map[string][][]int32{}
	for _, id := range cc.Sets.IDs() {
		if rows := fxRows(cc.Sets.Get(id).Effects, func(e gamedata.CardSetEffect) []int32 {
			return []int32{int32(e.Threshold)}
		}); len(rows) > 0 {
			sets[fmt.Sprint(id)] = rows
		}
	}
	sb, _ := json.Marshal(sets)
	setsOut := filepath.Join(filepath.Dir(out), "cardsetfx.json")
	if err := os.WriteFile(setsOut, sb, 0o644); err != nil {
		panic(err)
	}
	fmt.Println("wrote", setsOut, "sets:", len(sets))
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
