package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// TestShapeMatchesDecode checks that every arena's forma.json says what the
// server decodes from the .jar files: the same floor cells and the same start
// cells. With ARCHIVO_ARENAS set it also checks the archived copies
// (<dir>/arena-NN/forma.json, numbered by world order).
func TestShapeMatchesDecode(t *testing.T) {
	fm, err := gamedata.LoadFightMaps(filepath.Join("..", "..", "data-dist"))
	if err != nil {
		t.Skip("no data-dist maps:", err)
	}
	if fm.Len() != 47 {
		t.Fatalf("arenas = %d, want 47", fm.Len())
	}
	ids := fm.IDs()
	slices.Sort(ids)
	archive := os.Getenv("ARCHIVO_ARENAS")
	for n, id := range ids {
		m := fm.Get(id)
		var got shape
		b, _ := json.Marshal(Shape(m))
		if archive != "" {
			b, err = os.ReadFile(filepath.Join(archive, fmt.Sprintf("arena-%02d", n+1), "forma.json"))
			if err != nil {
				t.Fatal(err)
			}
		}
		if err := json.Unmarshal(b, &got); err != nil {
			t.Fatal(err)
		}
		if got.World != id {
			t.Fatalf("arena %d: world %d, want %d", n+1, got.World, id)
		}
		floor := 0
		for y := m.MinY; y < m.MinY+m.Height; y++ {
			for x := m.MinX; x < m.MinX+m.Width; x++ {
				if m.At(x, y).Ground {
					floor++
				}
			}
		}
		walk := 0
		for _, c := range got.Cells {
			if c.Floor {
				walk++
				if mc := m.At(c.X, c.Y); !mc.Ground || mc.Alt != c.Alt {
					t.Errorf("world %d: cell %d,%d differs", id, c.X, c.Y)
				}
			}
		}
		if walk != floor || got.Floor != floor {
			t.Errorf("world %d: floor %d/%d, want %d", id, walk, got.Floor, floor)
		}
		same := func(a []pos, b []gamedata.MapPos) bool {
			if len(a) != len(b) {
				return false
			}
			for i := range a {
				if a[i] != (pos{b[i].X, b[i].Y, b[i].Z}) {
					return false
				}
			}
			return true
		}
		if !same(got.Team0, m.Team0) || !same(got.Team1, m.Team1) || !same(got.Coach, m.CoachCells) {
			t.Errorf("world %d: start or coach cells differ", id)
		}
		if len(got.Specials) != len(m.Specials) {
			t.Errorf("world %d: specials %d, want %d", id, len(got.Specials), len(m.Specials))
		}
	}
}
