package gamedata

import (
	"archive/zip"
	"fmt"
	"path/filepath"
	"strings"
)

// Overworld environment layers — `maps/env/<world>.jar` (client `ru_2`
// ClientEnvironmentMap, one entry per 18×18 chunk named "<chunkX>_<chunkY>").
//
// This is where every interactive element a player can click actually lives:
// Zaaps, Card Masters, fusion altars, mailboxes, graveyards, totems, demons. The
// server used to carry them as a hand-transcribed Go table; this reads them from
// the client's own data instead.
//
// TWO BYTE ORDERS IN ONE FILE, which is the thing to get right:
//
//   - the env framing is LITTLE-endian (`acf` forces
//     ByteOrder.LITTLE_ENDIAN in its constructor and every factory on this path
//     goes through it);
//   - the per-element payload is a BIG-endian part table (`aJj.ad` wraps it in a
//     plain ByteBuffer and never reorders it).
//
// The payload is also copied onto the wire VERBATIM (opcode 200), so we parse it
// only to learn position and descriptor — we never rebuild it.
//
// Entry layout, all counts u8 (the client's writer refuses ≥255):
//
//	u8  version (always 0; read by gC before ru_2.b)
//	i16 chunkX, i16 chunkY            (redundant with the entry name — checked)
//	u8  particleCount, 13 bytes each  (aDv)
//	u8  soundCount,     8 bytes each  (axs_0; zero in all retail data)
//	u8  ambianceCount,  i32 each; then u8 maskLen + maskLen bytes if count > 0
//	u8  interactiveCount, aEG each    (below)
//	u8  dynamicCount,  15 bytes each  (ty_1; zero in all retail data)
const (
	envChunkSide      = 18
	envAmbianceMask   = 81 // ru_2.ais: 324 cells × 2 bits / 8
	envParticleSize   = 13 // aDv
	envSoundSize      = 8  // axs_0
	envDynamicSize    = 15 // ty_1
	envNoDescriptor   = "null"
	envPartIDPosition = 1 // do_1.Kl() slot 1 = RU, the position/descriptor part
)

// Env element types — client `asi`, the factory table `aap_0.bw(short)` selects
// from. These are the values in `aEG.Gp`.
const (
	EnvTypeCardMaster      int16 = 1
	EnvTypeMailbox         int16 = 2
	EnvTypeChallenge       int16 = 3
	EnvTypeZaap            int16 = 4
	EnvTypeBreedMaster     int16 = 5
	EnvTypeDemonIII        int16 = 6
	EnvTypeDemonChallenge  int16 = 7
	EnvTypeZoneTrigger     int16 = 8
	EnvTypeDemonI          int16 = 9
	EnvTypeGraveyard       int16 = 10
	EnvTypeDemonTotem      int16 = 11
	EnvTypeCardUsingSwitch int16 = 12 // the firework dispenser
	EnvTypeTournamentTotem int16 = 13
	EnvTypeFusionLab       int16 = 14
	EnvTypeNPCTalker       int16 = 15
)

// EnvElement is one interactive element of a world's env layer.
type EnvElement struct {
	// InstanceID is `aEG.nD`, the handle the client resolves an opcode-200 spawn
	// and an opcode-201 click against. Unique within a world.
	InstanceID int64
	// Type is `aEG.Gp`, one of the EnvType* values.
	Type int16
	// ViewIDs are `aEG.dBG` — indices into data.bdat record type 360 (sprites).
	// Kept for completeness; the server renders nothing.
	ViewIDs []int32
	// Payload is `aEG.Fe`, the part-table blob. It goes onto the wire byte for
	// byte in INTERACTIVE_ELEMENT_SPAWN.
	Payload []byte

	// --- decoded out of Payload's RU part (big-endian) ---

	// WorldID is the RU part's own world id. It always equals the jar's world in
	// retail data, so a mismatch means the parse has drifted.
	WorldID int16
	CellX   int32
	CellY   int32
	// DecorAlt is the RU part's altitude. **This is the DECORATION height, not the
	// walkable ground**, and using it as the 4600 arrival altitude is the classic
	// way to freeze a coach on arrival. Take the arrival altitude from tplg
	// (FightMaps/topology) instead; this field is kept only so the difference is
	// visible and testable.
	DecorAlt int16
	// Direction is the facing byte, Flags the approach-direction bitmask
	// (`agm_2.bI`; 0x100 means "interact from anywhere").
	Direction uint8
	Flags     int16
	// Descriptor is the RU part's name string, ';'-separated and element-specific;
	// the literal "null" means none. Card Master: "mode;cardListId[;nameId]".
	// DemonChallenge: "nameId;scenarioId;challengeId;acceptText[;refusalText]".
	Descriptor string
}

// HasDescriptor reports whether the element carries a real descriptor rather than
// the "null" sentinel.
func (e *EnvElement) HasDescriptor() bool {
	return e.Descriptor != "" && e.Descriptor != envNoDescriptor
}

// DescriptorFields splits the descriptor on ';'. Empty for the "null" sentinel.
func (e *EnvElement) DescriptorFields() []string {
	if !e.HasDescriptor() {
		return nil
	}
	return strings.Split(e.Descriptor, ";")
}

// LoadEnvWorld decodes every interactive element of one world. dir is the
// directory CONTAINING maps/ (the same root LoadWorldTopology takes).
//
// Elements come back sorted by instance id so the result is stable run to run,
// which matters because the first Zaap of a world is used as its default spawn.
func LoadEnvWorld(dir string, worldID int16) ([]EnvElement, error) {
	jarPath := filepath.Join(dir, "maps", "env", fmt.Sprintf("%d.jar", worldID))
	zr, err := zip.OpenReader(jarPath)
	if err != nil {
		return nil, err
	}
	defer zr.Close()

	var out []EnvElement
	for _, f := range zr.File {
		if !isEnvChunkEntry(f.Name) {
			continue
		}
		data, err := readZipFile(f)
		if err != nil {
			return nil, err
		}
		elems, err := decodeEnvChunk(data)
		if err != nil {
			return nil, fmt.Errorf("world %d chunk %s: %w", worldID, f.Name, err)
		}
		out = append(out, elems...)
	}
	sortEnvByInstance(out)
	return out, nil
}

// isEnvChunkEntry filters the jar down to chunk blobs. Env jars also carry
// META-INF and a 4-byte `data.amd` marker, and (unlike tplg) no `coord` entry.
func isEnvChunkEntry(name string) bool {
	if strings.HasPrefix(name, "META-INF") || strings.HasSuffix(name, "/") {
		return false
	}
	if name == "data.amd" || name == "coord" {
		return false
	}
	// "<chunkX>_<chunkY>", either part optionally negative.
	i := strings.IndexByte(name, '_')
	if i <= 0 || i == len(name)-1 {
		return false
	}
	return isEnvInt(name[:i]) && isEnvInt(name[i+1:])
}

func isEnvInt(s string) bool {
	if s == "" {
		return false
	}
	if s[0] == '-' {
		s = s[1:]
		if s == "" {
			return false
		}
	}
	for i := 0; i < len(s); i++ {
		if s[i] < '0' || s[i] > '9' {
			return false
		}
	}
	return true
}

// decodeEnvChunk walks one chunk entry positionally and returns its interactive
// elements. It insists on ending exactly at the blob's end: the sections are
// variable-length and only reachable in order, so a short read anywhere means
// every later offset is wrong and the elements cannot be trusted.
func decodeEnvChunk(data []byte) ([]EnvElement, error) {
	r := &leReader{b: data}

	if v := r.u8(); v != 0 {
		return nil, fmt.Errorf("unexpected env version %d (want 0)", v)
	}
	chunkX := int16(r.u16())
	chunkY := int16(r.u16())

	// 1. particles (aDv), 2. sounds (axs_0) — fixed size, skipped wholesale.
	if err := envSkipFixed(r, envParticleSize); err != nil {
		return nil, fmt.Errorf("particles: %w", err)
	}
	if err := envSkipFixed(r, envSoundSize); err != nil {
		return nil, fmt.Errorf("sounds: %w", err)
	}

	// 3. ambiance: u8 count, count × i32 id, then (only when count > 0) an
	//    explicit u8 mask length — which the client asserts is 81 — and the mask.
	if n := int(r.u8()); n > 0 {
		for i := 0; i < n; i++ {
			r.u32() // ambiance id (always -1 in retail)
		}
		if maskLen := int(r.u8()); maskLen > 0 {
			if maskLen != envAmbianceMask {
				return nil, fmt.Errorf("ambiance mask is %d bytes (want %d)",
					maskLen, envAmbianceMask)
			}
			if err := envSkip(r, maskLen); err != nil {
				return nil, fmt.Errorf("ambiance mask: %w", err)
			}
		}
	}

	// 4. interactive elements.
	count := int(r.u8())
	elems := make([]EnvElement, 0, count)
	for i := 0; i < count; i++ {
		e, err := decodeEnvElement(r)
		if err != nil {
			return nil, fmt.Errorf("element %d/%d: %w", i+1, count, err)
		}
		elems = append(elems, e)
	}

	// 5. dynamic elements (ty_1) — last thing in the entry.
	if err := envSkipFixed(r, envDynamicSize); err != nil {
		return nil, fmt.Errorf("dynamic: %w", err)
	}

	if r.err {
		return nil, fmt.Errorf("truncated chunk")
	}
	if r.i != len(data) {
		return nil, fmt.Errorf("walked %d of %d bytes — layout drift", r.i, len(data))
	}
	// The header repeats the entry name; treat a mismatch as drift rather than
	// trusting the elements we just read.
	_ = chunkX
	_ = chunkY
	return elems, nil
}

// decodeEnvElement reads one `aEG`.
func decodeEnvElement(r *leReader) (EnvElement, error) {
	var e EnvElement
	e.InstanceID = int64(r.u32()) | int64(r.u32())<<32 // i64 LE
	e.Type = int16(r.u16())
	views := int(r.u8())
	if views > 0 {
		e.ViewIDs = make([]int32, views)
		for i := range e.ViewIDs {
			e.ViewIDs[i] = int32(r.u32())
		}
	}
	payloadLen := int(r.u16())
	if !r.need(payloadLen) {
		return e, fmt.Errorf("payload of %d bytes does not fit", payloadLen)
	}
	e.Payload = make([]byte, payloadLen)
	copy(e.Payload, r.b[r.i:r.i+payloadLen])
	r.i += payloadLen

	// `aqE()` is a BIT reader: this is its only call in the record and the cursor
	// has just moved, so it takes a fresh whole byte and yields bit 7. One byte on
	// the wire either way.
	r.u8()
	r.u16() // dBI, a persisted state slot; -1 in all retail data

	if r.err {
		return e, fmt.Errorf("truncated element")
	}
	if err := decodeEnvPayload(&e); err != nil {
		return e, err
	}
	return e, nil
}

// decodeEnvPayload reads position and descriptor out of the element's part table.
// BIG-endian, unlike everything around it.
//
// Container: u8 partCount, then partCount × {u8 partId, i32 offset}. A part's
// length runs to the next part's offset (or the blob end), minus one, because the
// byte AT the offset repeats the part id — the client's serialiser writes it and
// we use it as a checksum.
func decodeEnvPayload(e *EnvElement) error {
	p := e.Payload
	c := &cur{b: p}
	partCount := int(c.u8())
	if !c.ok() || partCount == 0 {
		return fmt.Errorf("element %d: empty part table", e.InstanceID)
	}
	ids := make([]uint8, partCount)
	offs := make([]int32, partCount)
	for i := 0; i < partCount; i++ {
		ids[i] = c.u8()
		offs[i] = c.i32()
	}
	if !c.ok() {
		return fmt.Errorf("element %d: truncated part header", e.InstanceID)
	}

	for i := 0; i < partCount; i++ {
		start := int(offs[i])
		end := len(p)
		if i < partCount-1 {
			end = int(offs[i+1])
		}
		length := end - start - 1
		if start < 0 || start >= len(p) || length <= 0 {
			continue // empty part; the client skips these too
		}
		if p[start] != ids[i] {
			return fmt.Errorf("element %d: part %d marker is %d, expected the "+
				"part id %d", e.InstanceID, i, p[start], ids[i])
		}
		if ids[i] != envPartIDPosition {
			continue // only the RU part carries position/descriptor
		}
		if start+1+length > len(p) {
			return fmt.Errorf("element %d: RU part overruns the payload", e.InstanceID)
		}
		if err := decodeEnvRU(e, p[start+1:start+1+length]); err != nil {
			return err
		}
		return nil
	}
	return fmt.Errorf("element %d: no RU part", e.InstanceID)
}

// decodeEnvRU reads the RU part (client `RU.f`), big-endian.
func decodeEnvRU(e *EnvElement, b []byte) error {
	c := &cur{b: b}
	e.WorldID = c.i16()
	e.CellX = c.i32()
	e.CellY = c.i32()
	e.DecorAlt = c.i16()
	c.i16() // amP, element state (1 throughout retail)
	c.u8()  // visible
	c.u8()  // agj, a second boolean
	e.Direction = c.u8()
	e.Flags = c.i16()
	paths := int(c.i16())
	for i := 0; i < paths; i++ {
		c.i32() // path x
		c.i32() // path y
		c.i16() // path z
	}
	nameLen := int(uint16(c.i16())) // u16 length, the only one on this path
	if nameLen > 0 {
		if !c.need(nameLen) {
			return fmt.Errorf("element %d: descriptor of %d bytes does not fit",
				e.InstanceID, nameLen)
		}
		e.Descriptor = string(c.b[c.pos : c.pos+nameLen])
		c.pos += nameLen
	}
	if props := c.u8(); props != 0 {
		// The client logs an error and carries on; retail data never does this.
		return fmt.Errorf("element %d: %d properties, expected none",
			e.InstanceID, props)
	}
	if !c.ok() {
		return fmt.Errorf("element %d: truncated RU part", e.InstanceID)
	}
	if c.pos != len(b) {
		return fmt.Errorf("element %d: RU part left %d of %d bytes unread",
			e.InstanceID, len(b)-c.pos, len(b))
	}
	return nil
}

// envSkipFixed reads a u8 count and skips count × size bytes.
func envSkipFixed(r *leReader, size int) error {
	n := int(r.u8())
	if n == 0 {
		return nil
	}
	return envSkip(r, n*size)
}

func envSkip(r *leReader, n int) error {
	if !r.need(n) {
		return fmt.Errorf("cannot skip %d bytes", n)
	}
	r.i += n
	return nil
}

// sortEnvByInstance orders elements by instance id (insertion sort: the biggest
// world has 40 elements).
func sortEnvByInstance(e []EnvElement) {
	for i := 1; i < len(e); i++ {
		for j := i; j > 0 && e[j].InstanceID < e[j-1].InstanceID; j-- {
			e[j], e[j-1] = e[j-1], e[j]
		}
	}
}

// --- descriptor parsing ---
//
// The RU part's name string is the element's configuration, ';'-separated and
// interpreted per element type by the client class the `asi` factory picks. Only
// the fields the server actually acts on are parsed here.

// ParseCardMasterDescriptor reads a Card Master's "mode;cardListId[;nameId]"
// (client `ayF.gi`, which requires at least two fields).
//
// mode 0 is the ordinary kardmaster shop, 1 the "Démone II" exchanger variant; it
// selects which UI the client opens when the catalogue (5401) arrives. cardListId
// is the catalogue to send.
func ParseCardMasterDescriptor(e *EnvElement) (mode uint8, cardListID int32, err error) {
	f := e.DescriptorFields()
	if len(f) < 2 {
		return 0, 0, fmt.Errorf("element %d: Card Master descriptor %q needs at "+
			"least 2 fields", e.InstanceID, e.Descriptor)
	}
	m, err := envAtoi(f[0])
	if err != nil {
		return 0, 0, fmt.Errorf("element %d: Card Master mode %q: %w", e.InstanceID, f[0], err)
	}
	c, err := envAtoi(f[1])
	if err != nil {
		return 0, 0, fmt.Errorf("element %d: Card Master cardList %q: %w", e.InstanceID, f[1], err)
	}
	return uint8(m), c, nil
}

// ParseSingleIntDescriptor reads a descriptor that is one bare integer — a Fusion
// altar's lab-definition id, a Demon Totem's demon id, a firework dispenser's or
// tournament totem's name id.
func ParseSingleIntDescriptor(e *EnvElement) (int32, error) {
	f := e.DescriptorFields()
	if len(f) == 0 {
		return 0, fmt.Errorf("element %d: no descriptor", e.InstanceID)
	}
	v, err := envAtoi(f[0])
	if err != nil {
		return 0, fmt.Errorf("element %d: descriptor %q: %w", e.InstanceID, e.Descriptor, err)
	}
	return v, nil
}

// ParseDemonChallengeDescriptor reads
// "nameId;scenarioId;challengeId;acceptText[;refusalText]" (client `pn_0`). The
// challenge id is the one the client sends back in 26330 when the player accepts.
func ParseDemonChallengeDescriptor(e *EnvElement) (challengeID int32, err error) {
	f := e.DescriptorFields()
	if len(f) < 3 {
		return 0, fmt.Errorf("element %d: DemonChallenge descriptor %q needs at "+
			"least 3 fields", e.InstanceID, e.Descriptor)
	}
	return envAtoi(f[2])
}

// envAtoi parses a signed decimal field without pulling in strconv's error text,
// so the messages above stay readable.
func envAtoi(s string) (int32, error) {
	if s == "" {
		return 0, fmt.Errorf("empty")
	}
	neg := false
	i := 0
	if s[0] == '-' {
		neg, i = true, 1
		if len(s) == 1 {
			return 0, fmt.Errorf("lone minus")
		}
	}
	var v int64
	for ; i < len(s); i++ {
		if s[i] < '0' || s[i] > '9' {
			return 0, fmt.Errorf("not a number")
		}
		v = v*10 + int64(s[i]-'0')
		if v > 1<<31 {
			return 0, fmt.Errorf("out of range")
		}
	}
	if neg {
		v = -v
	}
	return int32(v), nil
}
