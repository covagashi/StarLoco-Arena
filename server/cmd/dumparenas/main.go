// dumparenas writes each fight arena's shape — cells, altitude, floor or
// blocking, team start cells, coach pedestals and special cells — as one
// forma.json per arena, so the M7 arena archive (S42) can be read without the
// client's .jar files. It runs once, while server/data-dist/maps still exists,
// and goes away in S43 when the server reads its own arena format.
// Usage: dumparenas <data_dir> <out_dir> [world ...]
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strconv"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

type cell struct {
	X     int32 `json:"x"`
	Y     int32 `json:"y"`
	Alt   int16 `json:"alt"`
	Floor bool  `json:"floor"` // a fighter can stand here; false = solid scenery
}

type pos struct {
	X int32 `json:"x"`
	Y int32 `json:"y"`
	Z int16 `json:"z"`
}

type special struct {
	pos
	Template int32 `json:"template"`
}

type shape struct {
	World    int32     `json:"world"`
	MinX     int32     `json:"min_x"`
	MinY     int32     `json:"min_y"`
	Width    int32     `json:"width"`
	Height   int32     `json:"height"`
	Floor    int       `json:"floor_cells"`
	Cells    []cell    `json:"cells"` // every non-void cell, row-major
	Team0    []pos     `json:"team0"`
	Team1    []pos     `json:"team1"`
	Coach    []pos     `json:"coach"`
	Specials []special `json:"specials"`
}

func toPos(ps []gamedata.MapPos) []pos {
	out := make([]pos, 0, len(ps))
	for _, p := range ps {
		out = append(out, pos{p.X, p.Y, p.Z})
	}
	return out
}

// Shape flattens one decoded arena; void cells are left out.
func Shape(m *gamedata.FightMap) shape {
	s := shape{World: m.ID, MinX: m.MinX, MinY: m.MinY, Width: m.Width, Height: m.Height,
		Cells: []cell{}, Specials: []special{},
		Team0: toPos(m.Team0), Team1: toPos(m.Team1), Coach: toPos(m.CoachCells)}
	for y := m.MinY; y < m.MinY+m.Height; y++ {
		for x := m.MinX; x < m.MinX+m.Width; x++ {
			c := m.At(x, y)
			if c.Void {
				continue
			}
			s.Cells = append(s.Cells, cell{x, y, c.Alt, c.Ground})
			if c.Ground {
				s.Floor++
			}
		}
	}
	for _, sp := range m.Specials {
		s.Specials = append(s.Specials, special{pos{sp.X, sp.Y, sp.Z}, sp.Template})
	}
	return s
}

func main() {
	if len(os.Args) < 3 {
		fmt.Fprintln(os.Stderr, "usage: dumparenas <data_dir> <out_dir> [world ...]")
		os.Exit(2)
	}
	fm, err := gamedata.LoadFightMaps(os.Args[1])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	ids := fm.IDs()
	if len(os.Args) > 3 {
		ids = ids[:0]
		for _, a := range os.Args[3:] {
			n, err := strconv.Atoi(a)
			if err != nil || fm.Get(int32(n)) == nil {
				fmt.Fprintf(os.Stderr, "no arena %q\n", a)
				os.Exit(1)
			}
			ids = append(ids, int32(n))
		}
	}
	slices.Sort(ids)
	for _, id := range ids {
		b, err := json.Marshal(Shape(fm.Get(id)))
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		out := filepath.Join(os.Args[2], fmt.Sprintf("%d.json", id))
		if err := os.WriteFile(out, b, 0o644); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
	}
	fmt.Printf("%d arenas -> %s (skipped for no topology: %v)\n", len(ids), os.Args[2], fm.Skipped())
}
