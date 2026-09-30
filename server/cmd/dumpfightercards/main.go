// dumpfightercards dumps every fighter-equipment card's ACTIVE-ability data
// (the 8107 FIGHTER_CARD_USE attack) for the Godot client's fight spell bar:
// {"<id>": {"ap":N,"min":N,"max":N,"usable":bool}}. Display names resolve
// through the coach-card table (same id space) already in cards.json.
//
// Usage: go run ./cmd/dumpfightercards <data-dir> <out.json>
package main

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

type rec struct {
	AP     int32 `json:"ap"`
	Min    int32 `json:"min"`
	Max    int32 `json:"max"`
	Usable bool  `json:"usable"` // has a FIGHTER_CARD_USE effect list (server Usable())
	// Cast gates for the Godot range overlay — the same three mv_1
	// rejections the server validates in fightercard_use.go.
	LoS  bool `json:"los"`  // TestLoS — needs line of sight
	Line bool `json:"line"` // OnlyLine — same row/col only
	Free bool `json:"free"` // NeedFreeCell — empty target cell
	// Effect zones for the Godot AoE preview — deduped [shape, size…]
	// tuples from UseEffects (point/empty/all produce no tint).
	Zones [][]int32 `json:"zn,omitempty"`
}

func main() {
	dir, out := os.Args[1], os.Args[2]
	st, err := gamedata.Open(dir)
	if err != nil {
		panic(err)
	}
	fc, err := st.LoadFighterCards()
	if err != nil {
		panic(err)
	}
	res := map[string]rec{}
	for id, c := range fc.All() {
		r := rec{
			AP: c.APCost, Min: c.RangeMin, Max: c.RangeMax,
			Usable: c.Usable(),
			LoS:    c.TestLoS, Line: c.OnlyLine, Free: c.NeedFreeCell,
		}
		seen := map[string]bool{}
		for _, ef := range c.UseEffects {
			if ef.AreaShape <= 1 || ef.AreaShape == 32767 || len(ef.AreaSize) == 0 {
				continue
			}
			row := append([]int32{ef.AreaShape}, ef.AreaSize...)
			key := fmt.Sprint(row)
			if !seen[key] {
				seen[key] = true
				r.Zones = append(r.Zones, row)
			}
		}
		res[fmt.Sprint(id)] = r
	}
	b, _ := json.Marshal(res)
	if err := os.WriteFile(out, b, 0o644); err != nil {
		panic(err)
	}
	fmt.Println("wrote", out, "fighter cards:", fc.Len())
}
