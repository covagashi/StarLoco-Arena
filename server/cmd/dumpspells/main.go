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
	}
	byBreed := map[int32][]rec{}
	for _, s := range sp.All() {
		if s.BreedID < 1 || s.BreedID > 12 {
			continue
		}
		byBreed[s.BreedID] = append(byBreed[s.BreedID], rec{s.ID, s.AP, s.RangeMin, s.RangeMax, s.Value})
	}
	b, _ := json.Marshal(byBreed)
	if err := os.WriteFile(out, b, 0o644); err != nil {
		panic(err)
	}
	fmt.Println("wrote", out, "spells:", sp.Len())
}
