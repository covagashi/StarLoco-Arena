package gamedata

import (
	"archive/zip"
	"encoding/binary"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// Fight-arena map data, read from the client's own shipped files:
//
//	data/maps/fight/<id>.jar!/<id>.fmd   start cells, coach pedestals, special cells
//	data/maps/tplg/<id>.jar!/<cx>_<cy>   per-cell altitude + ground (blocking) data
//
// Both are LITTLE-endian (the client's acf reader fixes that byte order).
//
// Only some worlds are arenas: a world is one when its fight jar carries a non-empty
// .fmd. The rest are overworld-only topologies that happen to share the numbering.
//
// The .fmd layout is ArenaFightMapDefinition.b (client Om.b):
//
//	6 × i32                  coach pedestal slots (packed positions)
//	i16                      (team0Count << 8) | team1Count, read unsigned
//	team0Count × i32         team-0 start cells
//	team1Count × i32         team-1 start cells
//	u8                       special-cell count
//	N × {i32 pos, i32 tmpl}  special cells
//
// A packed position is x = (v>>>20 & 0xFFF) - 2047, y = (v>>>8 & 0xFFF) - 2047,
// z = (v & 0xFF) - 127.
//
// A topology tile is a 7-byte header — [u8 type][i16 chunkX][i16 chunkY][i16 wp] —
// followed, for the type we care about (2, the per-cell tile), by a 16-entry
// altitude palette (each stored as wp+value), a 4-entry ground palette, and 18×18
// cell bytes. Per cell: altitude = altPalette[b & 0x0F] and ground =
// groundPalette[(b & 0x30) >> 4]; a ground of -1 means the cell has NO walkable
// floor. That covers both true void (the altitude is the sentinel) and solid scenery
// like ice spikes or trees (a real altitude you cannot stand on).

const (
	chunkSide = 18
	// The two topology tile kinds that carry per-cell floor data. Type 2 (ajg_2)
	// stores one palette-indexed layer per cell; type 5 (ajj_2) stores a sorted
	// list of packed entries, several layers deep. The remaining kinds (0/1/3/6)
	// are placeholders or render-only and contribute no floor.
	// Tile chunk kinds — client `afg.az(type & 0x0F)`.
	//
	// 0 and 1 were long unhandled here: type 0 is exactly 8 bytes and was dropped
	// by a "no per-cell data" size guard, and type 1 fell through to default. Both
	// assumptions were wrong — 0 carries a UNIFORM altitude+ground for all 324
	// cells and 1 a 4-bit palette grid. Together they are the majority of the
	// overworld (roughly 55-90% of a world's chunks), so overworld altitude
	// lookups read void without them.
	tileTypeUniform = 0 // ajo_2
	tileTypeNibble  = 1 // ajq_2
	tileTypeFlat    = 2 // ajg_2
	tileTypePacked  = 3 // aji_2
	tileTypeLayered = 5 // ajj_2
	// voidAltitude is the palette entry the client uses for "no floor at all".
	// It is Short.MIN_VALUE after the wp offset wraps.
	voidAltitude int16 = -32768
)

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

// FightMaps holds every decoded arena, keyed by world id.
type FightMaps struct {
	byID map[int32]*FightMap
	// skipped are worlds that define fight start points but ship no usable
	// topology, so they cannot host a fight.
	skipped []int32
	// unreachable counts special cells dropped because the topology gives their
	// cell no floor — a content quirk in the retail data, not a decode failure.
	unreachable int
	// release are the prototype's own arenas (arenas.go), the ones new fights
	// are drawn on.
	release []int32
}

// Skipped returns the arena ids that were dropped for lack of topology.
func (f *FightMaps) Skipped() []int32 { return f.skipped }

// UnreachableSpecials reports how many map-authored special cells were dropped for
// sitting on a cell with no floor (they could never be stood on, so they could
// never fire).
func (f *FightMaps) UnreachableSpecials() int { return f.unreachable }

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

// LoadFightMaps decodes every arena under <dir>/maps. A world is included only if
// its fight jar holds a non-empty .fmd; worlds whose topology is present but which
// define no fight start points are overworld maps and are skipped.
//
// The prototype's own arenas (arenas.go, embedded) then replace the retail
// data of their worlds.
func LoadFightMaps(dir string) (*FightMaps, error) {
	own, err := loadOwnArenas()
	if err != nil {
		return nil, fmt.Errorf("own arenas: %w", err)
	}
	out, err := loadRetailFightMaps(dir)
	if err != nil {
		return nil, err
	}
	out.applyOwnArenas(own)
	return out, nil
}

// loadRetailFightMaps is LoadFightMaps without the own arenas: the retail
// .jar data alone.
func loadRetailFightMaps(dir string) (*FightMaps, error) {
	fightDir := filepath.Join(dir, "maps", "fight")
	entries, err := os.ReadDir(fightDir)
	if err != nil {
		return nil, fmt.Errorf("read fight maps: %w", err)
	}
	out := &FightMaps{byID: make(map[int32]*FightMap)}
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".jar") {
			continue
		}
		id64, err := strconv.ParseInt(strings.TrimSuffix(e.Name(), ".jar"), 10, 32)
		if err != nil {
			continue
		}
		id := int32(id64)
		fmd, err := readZipEntrySuffix(filepath.Join(fightDir, e.Name()), ".fmd")
		if err != nil || len(fmd) == 0 {
			continue // not an arena
		}
		m := &FightMap{ID: id}
		if err := m.decodeFMD(fmd); err != nil {
			return nil, fmt.Errorf("map %d: %w", id, err)
		}
		// A few worlds ship a start-point definition but no per-cell topology (an
		// unfinished or retired arena). Skip those rather than failing the whole
		// set — they are unusable as fight maps, but the other arenas are fine.
		if err := m.loadTopology(filepath.Join(dir, "maps", "tplg", fmt.Sprintf("%d.jar", id))); err != nil {
			out.skipped = append(out.skipped, id)
			continue
		}
		out.unreachable += m.dropUnreachableSpecials()
		out.byID[id] = m
	}
	if len(out.byID) == 0 {
		return nil, fmt.Errorf("no arenas found under %s", fightDir)
	}
	return out, nil
}

// dropUnreachableSpecials removes special cells whose topology cell has no floor.
// The retail data contains a couple of these (map 42), and a fighter can never
// start a turn on one, so keeping them would only be misleading. Returns how many
// were dropped.
func (m *FightMap) dropUnreachableSpecials() int {
	kept := m.Specials[:0]
	dropped := 0
	for _, s := range m.Specials {
		if m.At(s.X, s.Y).Ground {
			kept = append(kept, s)
			continue
		}
		dropped++
	}
	m.Specials = kept
	return dropped
}

// unpackPos decodes a packed .fmd position.
func unpackPos(v uint32) MapPos {
	return MapPos{
		X: int32((v>>20)&0xFFF) - 2047,
		Y: int32((v>>8)&0xFFF) - 2047,
		Z: int16(int32(v&0xFF) - 127),
	}
}

func (m *FightMap) decodeFMD(b []byte) error {
	r := &leReader{b: b}
	for i := 0; i < 6; i++ {
		m.CoachCells = append(m.CoachCells, unpackPos(r.u32()))
	}
	counts := r.u16()
	n0, n1 := int(counts>>8), int(counts&0xFF)
	for i := 0; i < n0; i++ {
		m.Team0 = append(m.Team0, unpackPos(r.u32()))
	}
	for i := 0; i < n1; i++ {
		m.Team1 = append(m.Team1, unpackPos(r.u32()))
	}
	for i, n := 0, int(r.u8()); i < n; i++ {
		pos := unpackPos(r.u32())
		tmpl := int32(r.u32())
		m.Specials = append(m.Specials, MapSpecial{X: pos.X, Y: pos.Y, Z: pos.Z, Template: tmpl})
	}
	if r.err {
		return fmt.Errorf("truncated .fmd")
	}
	return nil
}

// loadTopology reads every per-cell chunk of the world's topology jar and builds the
// arena's bounding box from them.
func (m *FightMap) loadTopology(jarPath string) error {
	zr, err := zip.OpenReader(jarPath)
	if err != nil {
		return err
	}
	defer zr.Close()

	var chunks []topoChunk
	minX, minY := int32(1<<30), int32(1<<30)
	maxX, maxY := int32(-(1 << 30)), int32(-(1 << 30))

	for _, f := range zr.File {
		if strings.HasPrefix(f.Name, "META-INF") || f.Name == "coord" || f.FileInfo().IsDir() {
			continue
		}
		if f.UncompressedSize64 < 8 {
			continue // shorter than the common header + a uniform tile's one byte
		}
		data, err := readZipFile(f)
		if err != nil {
			return err
		}
		r := &leReader{b: data}
		typ := r.u8() & 0x0F
		originX := int32(int16(r.u16())) * chunkSide
		originY := int32(int16(r.u16())) * chunkSide
		wp := int16(r.u16())
		if r.err {
			continue
		}
		var c topoChunk
		c.originX, c.originY = originX, originY
		for i := range c.alt {
			c.alt[i] = voidAltitude
		}

		if !decodeTopoTiles(r, typ, wp, &c, topoArena) {
			continue
		}
		if r.err {
			return fmt.Errorf("truncated chunk %s", f.Name)
		}
		chunks = append(chunks, c)
		if originX < minX {
			minX = originX
		}
		if originY < minY {
			minY = originY
		}
		if originX+chunkSide-1 > maxX {
			maxX = originX + chunkSide - 1
		}
		if originY+chunkSide-1 > maxY {
			maxY = originY + chunkSide - 1
		}
	}
	if len(chunks) == 0 {
		return fmt.Errorf("no per-cell topology chunks")
	}

	m.MinX, m.MinY = minX, minY
	m.Width, m.Height = maxX-minX+1, maxY-minY+1
	m.cells = make([]MapCell, m.Width*m.Height)
	for i := range m.cells {
		m.cells[i] = MapCell{Alt: voidAltitude, Void: true}
	}
	for _, c := range chunks {
		for i := 0; i < chunkSide*chunkSide; i++ {
			x := c.originX + int32(i%chunkSide)
			y := c.originY + int32(i/chunkSide)
			cell := MapCell{Alt: c.alt[i], Ground: c.ground[i]}
			// No ground AND the sentinel altitude means the cell simply is not
			// part of the map; no ground with a real altitude is solid scenery.
			cell.Void = !cell.Ground && cell.Alt == voidAltitude
			m.cells[(y-m.MinY)*m.Width+(x-m.MinX)] = cell
		}
	}
	return nil
}

// --- helpers ------------------------------------------------------------------

func readZipFile(f *zip.File) ([]byte, error) {
	rc, err := f.Open()
	if err != nil {
		return nil, err
	}
	defer rc.Close()
	return io.ReadAll(rc)
}

func readZipEntrySuffix(jarPath, suffix string) ([]byte, error) {
	zr, err := zip.OpenReader(jarPath)
	if err != nil {
		return nil, err
	}
	defer zr.Close()
	for _, f := range zr.File {
		if strings.HasSuffix(f.Name, suffix) && !f.FileInfo().IsDir() {
			return readZipFile(f)
		}
	}
	return nil, nil
}

// leReader is a little-endian cursor that latches an error instead of panicking.
type leReader struct {
	b   []byte
	i   int
	err bool
}

func (r *leReader) need(n int) bool {
	if r.i+n > len(r.b) {
		r.err = true
		return false
	}
	return true
}

func (r *leReader) u8() uint8 {
	if !r.need(1) {
		return 0
	}
	v := r.b[r.i]
	r.i++
	return v
}

func (r *leReader) u16() uint16 {
	if !r.need(2) {
		return 0
	}
	v := binary.LittleEndian.Uint16(r.b[r.i:])
	r.i += 2
	return v
}

func (r *leReader) u32() uint32 {
	if !r.need(4) {
		return 0
	}
	v := binary.LittleEndian.Uint32(r.b[r.i:])
	r.i += 4
	return v
}
