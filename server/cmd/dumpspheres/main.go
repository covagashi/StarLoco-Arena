// dumpspheres exports the Kanodo (sphere board) catalogue — record types 900
// (boards) and 901 (nodes) — as JSON for the Godot client's board pane.
// Usage: dumpspheres <data_dir> <out.json>
package main

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// first-effect action ids the client's ayr_0.aKZ() maps to Malus
// (mh_2: buQ/buS/buU/buW/bvj/bvl/bvn/bvp/bvP/bvR/bwr).
var malusActions = map[int32]bool{
	30: true, 32: true, 34: true, 36: true, 49: true, 51: true,
	53: true, 55: true, 81: true, 83: true, 123: true,
}

// summon-mastery action ids (mh_2 bwK..bwO + bwN = 142..146).
func summonAction(id int32) bool { return id >= 142 && id <= 146 }

func kind(s *gamedata.Sphere) string {
	if s.SpellID != 0 {
		return "spell"
	}
	if len(s.Effects) > 0 {
		a := s.Effects[0].ActionID
		if malusActions[a] {
			return "malus"
		}
		if summonAction(a) {
			return "summon"
		}
		return "bonus"
	}
	if len(s.BarrierCards) > 0 {
		return "barrier"
	}
	if s.TeleportX != 0 {
		return "teleport"
	}
	if s.EquipmentPoolID != 0 {
		return "item"
	}
	if s.DeadEnd {
		return "deadend"
	}
	return "empty"
}

func main() {
	st, err := gamedata.Open(os.Args[1])
	if err != nil {
		panic(err)
	}
	sb, err := st.LoadSphereBoards()
	if err != nil {
		panic(err)
	}
	type board struct {
		Breed  int    `json:"breed"`
		Season int32  `json:"season"`
		Root   [2]int `json:"root"`
	}
	type node struct {
		ID      int32   `json:"id"`
		Board   int32   `json:"board"`
		X       int     `json:"x"`
		Y       int     `json:"y"`
		XP      int32   `json:"xp"`
		Kind    string  `json:"kind"`
		Spell   int32   `json:"spell,omitempty"`
		Pool    int32   `json:"pool,omitempty"`
		Barrier []int32 `json:"barrier,omitempty"`
		Tx      int     `json:"tx,omitempty"`
		Ty      int     `json:"ty,omitempty"`
		Fx      []int32 `json:"fx,omitempty"` // first effect: [action, param0, param1]
	}
	out := struct {
		Boards map[int32]board `json:"boards"`
		Nodes  map[int32]node  `json:"nodes"`
	}{map[int32]board{}, map[int32]node{}}
	for _, bid := range sb.BoardIDs() {
		b := sb.Board(bid)
		out.Boards[bid] = board{int(b.Breed), b.Season,
			[2]int{int(b.RootX), int(b.RootY)}}
		for _, s := range sb.SpheresOf(bid) {
			n := node{ID: s.ID, Board: bid, X: int(s.X), Y: int(s.Y), XP: s.XPCost,
				Kind: kind(s), Spell: s.SpellID, Pool: s.EquipmentPoolID,
				Barrier: s.BarrierCards, Tx: int(s.TeleportX),
				Ty: int(s.TeleportY)}
			if len(s.Effects) > 0 {
				e := s.Effects[0]
				n.Fx = []int32{e.ActionID}
				for _, p := range e.Params {
					n.Fx = append(n.Fx, int32(p))
				}
			}
			out.Nodes[s.ID] = n
		}
	}
	b, _ := json.Marshal(out)
	if err := os.WriteFile(os.Args[2], b, 0o644); err != nil {
		panic(err)
	}
	fmt.Println("wrote", os.Args[2], "boards:", len(out.Boards),
		"nodes:", len(out.Nodes))
}
