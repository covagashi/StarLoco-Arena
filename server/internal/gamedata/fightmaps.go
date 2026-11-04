package gamedata

import "fmt"

// Fight arenas: the shape of each arena the server plays, the prototype's own
// (arenas.go, embedded). Until S43 they were decoded from the retail client's
// map files (maps/fight/<id>.jar .fmd + maps/tplg topology); the arenas'
// shape now comes from the owner's layouts and no .jar is read for them.

const voidAltitude int16 = -32768 // a cell with no floor at all

// MapCell is one arena cell.
type MapCell struct {
	Alt int16
	// Ground reports whether a fighter can stand here. False covers BOTH void and
	// solid scenery; Void distinguishes them.
	Ground bool
	Void   bool
}

// MapSpecial is a map-authored special cell (see game/specialcells.go).
type MapSpecial struct {
	X, Y     int32
	Z        int16
	Template int32
}

// MapPos is a cell coordinate with altitude.
type MapPos struct {
	X, Y int32
	Z    int16
}

// FightMap is one decoded arena.
type FightMap struct {
	ID            int32
	MinX, MinY    int32
	Width, Height int32
	cells         []MapCell // row-major over the bounding box; see At
	CoachCells    []MapPos
	Team0, Team1  []MapPos
	Specials      []MapSpecial
}

// At returns the cell at absolute (x,y). Out-of-bounds reads as void.
func (m *FightMap) At(x, y int32) MapCell {
	if x < m.MinX || y < m.MinY || x >= m.MinX+m.Width || y >= m.MinY+m.Height {
		return MapCell{Alt: voidAltitude, Void: true}
	}
	return m.cells[(y-m.MinY)*m.Width+(x-m.MinX)]
}

// FightMaps holds every arena, keyed by world id.
type FightMaps struct {
	byID map[int32]*FightMap
	// release are the ones new fights are drawn on: all of them, in id order.
	release []int32
}

// Get returns the arena for a world id, or nil.
func (f *FightMaps) Get(id int32) *FightMap { return f.byID[id] }

// IDs returns every arena id present.
func (f *FightMaps) IDs() []int32 {
	out := make([]int32, 0, len(f.byID))
	for id := range f.byID {
		out = append(out, id)
	}
	return out
}

// Len reports how many arenas were loaded.
func (f *FightMaps) Len() int { return len(f.byID) }

// LoadFightMaps returns the prototype's own arenas, embedded in the binary.
func LoadFightMaps() (*FightMaps, error) {
	own, err := loadOwnArenas()
	if err != nil {
		return nil, fmt.Errorf("own arenas: %w", err)
	}
	if len(own) == 0 {
		return nil, fmt.Errorf("no arenas embedded")
	}
	out := &FightMaps{byID: make(map[int32]*FightMap, len(own))}
	out.applyOwnArenas(own)
	return out, nil
}
