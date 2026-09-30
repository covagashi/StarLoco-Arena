package main

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// dumpeffects emits godot/assets/gamedata/effects.json:
//
//	{"<effectId>": {"a": actionId, "d": turns, "i": 0|1, "p": [params]}}
//
// for every type-200 effect embedded in spells and fighter cards that has a
// non-instant DurationTurns() OR is infinite. The Godot client uses it to
// attach + count down buff chips on live 8120 casts (duration is data-side,
// never on the wire) and to resolve dispel targets (params[0] = the effectId
// a remove-effect strips — see removeEffectByID).
func main() {
	dir := os.Args[1]
	out := os.Args[2]
	st, err := gamedata.Open(dir)
	if err != nil {
		panic(err)
	}
	type rec struct {
		Action   int32     `json:"a"`
		Turns    int32     `json:"d"`
		Infinite bool      `json:"i"`
		Params   []float32 `json:"p,omitempty"`
	}
	effects := map[int32]rec{}
	add := func(e gamedata.Effect) {
		turns, inf := e.DurationTurns()
		if !inf && turns <= 0 {
			return
		}
		effects[e.EffectID] = rec{Action: e.ActionID, Turns: turns,
			Infinite: inf, Params: e.Params}
	}
	sp, err := st.LoadSpells()
	if err != nil {
		panic(err)
	}
	for _, s := range sp.All() {
		for _, e := range s.Effects {
			add(e)
		}
	}
	fc, err := st.LoadFighterCards()
	if err != nil {
		panic(err)
	}
	for _, c := range fc.All() {
		for _, e := range c.EquipEffects {
			add(e)
		}
		for _, e := range c.UseEffects {
			add(e)
		}
	}
	b, _ := json.Marshal(effects)
	if err := os.WriteFile(out, b, 0o644); err != nil {
		panic(err)
	}
	fmt.Println("wrote", out, "timed/infinite effects:", len(effects))
}
