package gamedata

import (
	"archive/zip"
	"encoding/binary"
	"fmt"
	"io"
	"path/filepath"
	"strings"
)

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
)

// Topology decoding, shared by arenas and the overworld.
//
// `maps/tplg/<world>.jar`, one entry per 18×18 chunk named "<chunkX>_<chunkY>",
// little-endian, with a common header of `u8 type` (client `afg.az(type & 0x0F)`)
// + `i16 chunkX` + `i16 chunkY` (both ×18 to give the origin) + `i16 wp` (the
// chunk's base altitude).
//
// The altitude a coach ARRIVES at must be the walkable ground of its cell — the
// client seeds its pathfinder with cell + altitude and requires a walkable layer
// at exactly that height, so being wrong here leaves the player frozen in place.
// That value is `akd_0.wp` of a layer with real floor (`cCJ != -1`) that is not a
// pass-through layer; it is emphatically NOT the element sprite's own z, which is
// decoration height.

// topoChunk is one decoded 18×18 topology chunk.
type topoChunk struct {
	originX, originY int32
	alt              [chunkSide * chunkSide]int16
	ground           [chunkSide * chunkSide]bool
	// walkable lists EVERY walkable altitude of a cell, not just the one chosen
	// for alt. Only the layered kind can produce more than one, and only the
	// overworld reader consumes it (see WorldTopology.HasWalkableLayerAt); it stays
	// nil otherwise.
	walkable map[int][]int16
}

// topoScope selects which chunk kinds a topology read accepts.
//
// This exists because the two consumers genuinely want different sets, and the
// difference is not cosmetic:
//
//   - topoArena keeps the historical arena set (types 2/3/5). The uniform and
//     nibble kinds are the filler chunks AROUND an arena; admitting them widens
//     the map's bounding box without adding a single playable cell, and the arena
//     bounds feed placement, movement clamping and sudden death. Changing that is
//     a fight-affecting decision on its own evidence, not a side effect of an
//     overworld feature.
//   - topoWorld accepts everything, because on the overworld the uniform and
//     nibble kinds ARE most of the ground (roughly 55-90% of a world's chunks) and
//     leaving them out reads void almost everywhere.
type topoScope int

const (
	topoArena topoScope = iota
	topoWorld
)

// decodeTopoTiles reads one chunk's per-cell data into c, having already consumed
// the common header. Reports false when the kind is not accepted for the scope (or
// carries no floor data), in which case the chunk should be skipped.
func decodeTopoTiles(r *leReader, typ uint8, wp int16, c *topoChunk, scope topoScope) bool {
	switch typ {
	case tileTypeUniform: // ajo_2: one ground byte, uniform over all 324 cells
		if scope != topoWorld {
			return false
		}
		ground := int8(r.u8()) != -1
		for i := 0; i < chunkSide*chunkSide; i++ {
			c.alt[i] = wp
			c.ground[i] = ground
		}

	case tileTypeNibble: // ajq_2: 8-entry altitude palette, 2-entry ground, 4-bit grid
		if scope != topoWorld {
			return false
		}
		var altPalette [8]int16
		for i := range altPalette {
			altPalette[i] = wp + int16(r.u16())
		}
		var groundPalette [2]int8
		for i := range groundPalette {
			groundPalette[i] = int8(r.u8())
		}
		// 324 cells at 4 bits = 162 bytes. EVEN cell index takes the HIGH nibble,
		// odd the low one (ajq_2:29).
		var grid [162]byte
		for i := range grid {
			grid[i] = r.u8()
		}
		for i := 0; i < chunkSide*chunkSide; i++ {
			var n byte
			if i&1 != 0 {
				n = grid[i>>1] & 0x0F
			} else {
				n = grid[i>>1] >> 4 & 0x0F
			}
			c.alt[i] = altPalette[n>>1]
			c.ground[i] = groundPalette[n&1] != -1
		}

	case tileTypeFlat: // ajg_2: one layer, palette-indexed
		var altPalette [16]int16
		for i := range altPalette {
			altPalette[i] = wp + int16(r.u16())
		}
		var groundPalette [4]int8
		for i := range groundPalette {
			groundPalette[i] = int8(r.u8())
		}
		for i := 0; i < chunkSide*chunkSide; i++ {
			b := r.u8()
			c.alt[i] = altPalette[b&0x0F]
			c.ground[i] = groundPalette[(b&0x30)>>4] != -1
		}

	case tileTypePacked: // aji_2: one packed i16 per cell
		for i := 0; i < chunkSide*chunkSide; i++ {
			raw := r.u16()
			// cCJ is read from the SIGN-EXTENDED short, so a negative value yields
			// -1 ("no floor"); the low 10 bits are the altitude.
			cc := int8(uint32(uint32(int32(int16(raw)))&0xFFFFF000) >> 12)
			altRaw := int32(raw) & 0x3FF
			alt := voidAltitude
			if altRaw != 0 {
				alt = wp - 512 + int16(altRaw)
			}
			c.alt[i] = alt
			c.ground[i] = cc != -1
		}

	case tileTypeLayered: // ajj_2: a sorted list of packed per-layer entries
		for i := 0; i < 64; i++ {
			r.u8() // dSi palette: render data only
		}
		n := int(int16(r.u16()))
		seen := make([]bool, chunkSide*chunkSide)
		for i := 0; i < n; i++ {
			v := r.u32()
			cx := int32(v & 0x1F)
			cy := int32((v >> 5) & 0x1F)
			if cx >= chunkSide || cy >= chunkSide {
				continue
			}
			idx := cy*chunkSide + cx
			altRaw := int32((v >> 10) & 0x3FF)
			alt := voidAltitude
			if altRaw != 0 {
				alt = wp - 512 + int16(altRaw)
			}
			ground := ((v >> 22) & 0xF) != 15 // 15 encodes -1: no floor
			if ground && scope == topoWorld {
				if c.walkable == nil {
					c.walkable = make(map[int][]int16)
				}
				c.walkable[int(idx)] = append(c.walkable[int(idx)], alt)
			}
			// A cell can carry several stacked layers (a bridge over a pit, a
			// platform above ground). The surface a fighter stands on is the
			// HIGHEST one with real floor — verified against every arena's .fmd,
			// whose start cells record the exact z the client expects. With no
			// floor layer at all, keep the first entry so the cell is still
			// classified (scenery vs void).
			switch {
			case !seen[idx]:
				seen[idx], c.alt[idx], c.ground[idx] = true, alt, ground
			case ground && (!c.ground[idx] || alt > c.alt[idx]):
				c.alt[idx], c.ground[idx] = alt, ground
			}
		}

	default:
		return false // other tile kinds carry no per-cell floor data
	}
	return true
}

// WorldTopology is one overworld world's walkable surface.
//
// It answers two different questions, and the distinction matters:
//
//   - GroundAlt gives the HIGHEST walkable layer of a cell, which is what you want
//     when you have to pick a height yourself.
//   - HasWalkableLayerAt asks whether a SPECIFIC height is walkable, which is what
//     you want to validate an authored arrival altitude. A cell can carry several
//     stacked floors (a platform over ground), and the client is happy with any of
//     them — so "highest" is not a safe way to check an authored value, and a
//     mistyped altitude that happens to hit a lower floor produces no error at all,
//     just a coach standing in the wrong place.
type WorldTopology struct {
	WorldID int16
	cells   map[int64]MapCell
	// extraAlts holds the additional walkable altitudes of cells that have more
	// than one. Only multi-layer cells appear here, which keeps this small — a
	// slice per cell across every cell of every world would cost tens of MB.
	extraAlts map[int64][]int16
}

// GroundAlt returns the walkable ground altitude at (x,y) and whether the cell has
// real floor. A cell with no floor reports false, and callers must not use its
// altitude as an arrival height.
func (t *WorldTopology) GroundAlt(x, y int32) (int16, bool) {
	if t == nil {
		return 0, false
	}
	c, ok := t.cells[topoKey(x, y)]
	if !ok || !c.Ground {
		return 0, false
	}
	return c.Alt, true
}

// HasWalkableLayerAt reports whether the cell has a walkable floor at EXACTLY this
// altitude. This is the check an authored arrival altitude has to pass: the client
// seeds its pathfinder with cell + altitude and needs a layer at precisely that
// height, so anything else leaves the coach unable to move.
func (t *WorldTopology) HasWalkableLayerAt(x, y int32, alt int16) bool {
	if t == nil {
		return false
	}
	k := topoKey(x, y)
	c, ok := t.cells[k]
	if !ok || !c.Ground {
		return false
	}
	if c.Alt == alt {
		return true
	}
	for _, a := range t.extraAlts[k] {
		if a == alt {
			return true
		}
	}
	return false
}

// LowestWalkableAlt returns the LOWEST walkable altitude of a cell.
func (t *WorldTopology) LowestWalkableAlt(x, y int32) (int16, bool) {
	if t == nil {
		return 0, false
	}
	k := topoKey(x, y)
	c, ok := t.cells[k]
	if !ok || !c.Ground {
		return 0, false
	}
	lo := c.Alt
	for _, a := range t.extraAlts[k] {
		if a < lo {
			lo = a
		}
	}
	return lo, true
}

// Cells reports how many cells were decoded, for logging and for tests that want
// to notice a world going silently empty.
func (t *WorldTopology) Cells() int {
	if t == nil {
		return 0
	}
	return len(t.cells)
}

func topoKey(x, y int32) int64 { return int64(x)<<32 | int64(uint32(y)) }

// LoadWorldTopology decodes one world's topology jar for overworld use, accepting
// every chunk kind. dir is the directory CONTAINING maps/.
func LoadWorldTopology(dir string, worldID int16) (*WorldTopology, error) {
	jarPath := filepath.Join(dir, "maps", "tplg", fmt.Sprintf("%d.jar", worldID))
	zr, err := zip.OpenReader(jarPath)
	if err != nil {
		return nil, err
	}
	defer zr.Close()

	t := &WorldTopology{
		WorldID:   worldID,
		cells:     make(map[int64]MapCell),
		extraAlts: make(map[int64][]int16),
	}
	for _, f := range zr.File {
		if strings.HasPrefix(f.Name, "META-INF") || f.Name == "coord" || f.FileInfo().IsDir() {
			continue
		}
		if f.UncompressedSize64 < 8 {
			continue
		}
		data, err := readZipFile(f)
		if err != nil {
			return nil, err
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
		if !decodeTopoTiles(r, typ, wp, &c, topoWorld) {
			continue
		}
		if r.err {
			return nil, fmt.Errorf("world %d: truncated chunk %s", worldID, f.Name)
		}
		for i := 0; i < chunkSide*chunkSide; i++ {
			x := c.originX + int32(i%chunkSide)
			y := c.originY + int32(i/chunkSide)
			cell := MapCell{Alt: c.alt[i], Ground: c.ground[i]}
			cell.Void = !cell.Ground && cell.Alt == voidAltitude
			k := topoKey(x, y)
			t.cells[k] = cell
			if len(c.walkable[i]) > 1 {
				t.extraAlts[k] = append([]int16(nil), c.walkable[i]...)
			}
		}
	}
	if len(t.cells) == 0 {
		return nil, fmt.Errorf("world %d: no topology chunks", worldID)
	}
	return t, nil
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
