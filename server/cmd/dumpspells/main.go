package main

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

func main() {
	dir := os.Args[1]
	out := os.Args[2]
	st, err := gamedata.Open(dir)
	if err != nil {
		panic(err)
	}
	sp, err := st.LoadSpells()
	if err != nil {
		panic(err)
	}
	type rec struct {
		ID    int32 `json:"id"`
		AP    int8  `json:"ap"`
		Min   int8  `json:"min"`
		Max   int8  `json:"max"`
		Value int32 `json:"value"`
		// Cast gates for the Godot range overlay — the client enforces the
		// same rules before it ever sends 8109 (see spellTargetValidFrom).
		LoS     bool    `json:"los"`            // TestLoS — needs line of sight
		Line    bool    `json:"line"`           // OnlyLine — same row/col only
		Free    bool    `json:"free"`           // NeedFreeCell — empty target cell
		NoBoost bool    `json:"noboost"`        // RangeNotBoostable
		Masks   []int64 `json:"mask,omitempty"` // cast-level TargetMasks (only when enforced)
		// Cast-frequency limits for the Godot spell-bar lock — the client
		// tracks its own sH history: parent key, effective cooldown (63 =
		// once per fight), per-turn and per-target caps (0 = unconstrained).
		LimitKey int32 `json:"lk,omitempty"`
		Cooldown uint8 `json:"cd,omitempty"`
		PerTurn  uint8 `json:"mpt,omitempty"`
		PerTarget uint8 `json:"mptt,omitempty"`
	}
	byBreed := map[int32][]rec{}
	for _, s := range sp.All() {
		if s.BreedID < 1 || s.BreedID > 12 {
			continue
		}
		r := rec{ID: s.ID, AP: s.AP, Min: s.RangeMin, Max: s.RangeMax,
			Value: s.Value, LoS: s.TestLoS, Line: s.OnlyLine,
			Free: s.NeedFreeCell, NoBoost: s.RangeNotBoostable}
		if s.EnforceTargetMasks {
			r.Masks = s.TargetMasks
		}
		r.LimitKey = s.LimitKeyID()
		if ec := s.EffectiveCooldown(); ec > 0 {
			r.Cooldown = ec
		}
		r.PerTurn = s.CastMaxPerTurn
		r.PerTarget = s.CastMaxPerTarget
		byBreed[s.BreedID] = append(byBreed[s.BreedID], r)
	}
	b, _ := json.Marshal(byBreed)
	if err := os.WriteFile(out, b, 0o644); err != nil {
		panic(err)
	}
	fmt.Println("wrote", out, "spells:", sp.Len())
}
