package game

import (
	"encoding/binary"
	"encoding/hex"
	"sort"

	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// Overworld interactive elements.
//
// Every island's Zaaps, Card Masters, Fusion altars, mailboxes and graveyards are
// baked into its env layer (contents/maps/env/<world>.jar) as "interactive
// elements", each with a unique env instanceId. The client CLEARS its live element
// manager on every ENTER_INSTANCE (4600), so the server must (re)push the world's
// elements with INTERACTIVE_ELEMENT_SPAWN (opcode 200) on each entry — see
// Session.sendEnterOverworld. Clicking one sends INTERACTIVE_ELEMENT_ACTION
// (opcode 201) carrying the instanceId; what happens next depends on the kind
// (see handleInteractiveElementAction).
//
// The payloads below are the exact part-table blobs extracted from the env jars
// (the outer env framing is little-endian, but the blob itself is opaque and is
// copied verbatim onto the wire). Cells and ground altitudes come from the
// matching tplg (topology) data. See docs/OVERWORLD-MAP.md.

// elementKind is what an interactive element does when clicked.
type elementKind uint8

const (
	// kindZaap (env type 4) opens the grimoire's Zaap-card page locally; picking a
	// destination card sends ZAAP_USE (4512). See zaap.go.
	kindZaap elementKind = iota
	// kindCardMaster (env type 1) opens NO UI by itself: it arms its handler and
	// waits for the server to push the catalogue (5401), which is what opens and
	// populates the shop.
	kindCardMaster
	// kindFusionLab (env type 14) opens the fusion altar entirely from client-local
	// lab definitions; only the fuse itself is networked (5490 -> 5491).
	kindFusionLab
	// kindMailbox (env type 2) opens the mailbox dialog locally. Its contents are
	// server-driven and NOT implemented yet, so it opens empty.
	kindMailbox
	// kindGraveyard (env type 10) opens the graveyard dialog locally; its roster is
	// server-driven (see handlers_evolution.go / the 6031 -> 6006+6030 reply).
	kindGraveyard
	// kindChallenge (env type 3) opens an accept/refuse bubble locally. Accepting
	// sends 26330 [i32 challengeId][i16 99] (see challengeAcceptBreed), which
	// starts a real PvE fight — see challenge_fights.go.
	kindChallenge
	// kindDemonChallenge (env type 7) behaves like kindChallenge, or runs a local
	// Lua scenario when its descriptor names one. Its descriptor is a ';'-separated
	// list `nameId;scenarioId;challengeId;promptTextId[;refusalTextId]`; field 2 is
	// the challenge id sent in 26330.
	kindDemonChallenge
	// kindFirework (env type 12, "cardUsingSwitch") opens the firework dialog
	// locally, filled from the coach's own card inventory. Launching one sends
	// 22095, which we echo back as 22094 so the effect is visible.
	kindFirework
	// kindNPC (env type 15, NPCTalker) opens a dialog tree entirely from client
	// data — the server owes nothing at all beyond spawning it.
	kindNPC
	// kindBreedMaster (env type 5) offers recruit / test-fight / cancel. Recruit is
	// local and already works through our fighter creation; the test fight is the
	// shared 26330 challenge path (refused politely).
	kindBreedMaster
	// kindDemonI / kindDemonIII (env types 9 and 6) are the named demon NPCs.
	kindDemonI
	kindDemonIII
	// kindDemonTotem (env type 11) sends 27510 asking for a demon's ladder page;
	// its dialog opens ONLY on our 27511 reply.
	kindDemonTotem
	// kindTournamentTotem (env type 13) sends 17002 (+28601); its dialog opens ONLY
	// on our 17003 reply.
	kindTournamentTotem
	// kindZoneTrigger (env type 8) fires on WALK-ON and runs a local Lua scenario.
	// It never even sends 201 — purely client-side.
	kindZoneTrigger
)

func (k elementKind) String() string {
	switch k {
	case kindZaap:
		return "zaap"
	case kindCardMaster:
		return "cardmaster"
	case kindFusionLab:
		return "fusionlab"
	case kindMailbox:
		return "mailbox"
	case kindGraveyard:
		return "graveyard"
	case kindChallenge:
		return "challenge"
	case kindDemonChallenge:
		return "demonchallenge"
	case kindFirework:
		return "firework"
	case kindNPC:
		return "npc"
	case kindBreedMaster:
		return "breedmaster"
	case kindDemonI:
		return "demon1"
	case kindDemonIII:
		return "demon3"
	case kindDemonTotem:
		return "demontotem"
	case kindTournamentTotem:
		return "tournamenttotem"
	case kindZoneTrigger:
		return "zonetrigger"
	}
	return "unknown"
}

// worldElement is one interactive element of a world.
type worldElement struct {
	kind       elementKind
	instanceID int64
	payload    []byte
	cellX      int32
	cellY      int32
	// alt is the element cell's walkable GROUND altitude (the tplg layer "wp").
	// It matters only where the cell is used as an ARRIVAL cell (Zaaps): the
	// ENTER_INSTANCE (4600) `alt` must equal it, because the client seeds its
	// overworld pathfinder with the coach's cell + altitude and requires a walkable
	// layer at EXACTLY that altitude — a mismatch leaves the coach unable to move.
	// NOTE the env sprite's RU z is decoration height, NOT the ground wp. Elements
	// that are never stood on (mailboxes, graveyards — often on non-walkable cells)
	// carry 0 here; it is unused for them.
	alt int16
	// arg is the element's descriptor argument: for a Card Master its catalogue id
	// ("cardListId", descriptor "flag;cardListId[;nameContentId]"), for a Fusion
	// altar its lab-definition id, for a Demon Totem its demon id. 0 when the kind
	// has no argument.
	arg int32
	// mode is a Card Master's descriptor flag (field 0): 0 = the ordinary
	// "kardmaster" shop, 1 = the "démone II" exchanger variant. It selects which
	// UI the client opens when our catalogue (5401) arrives.
	mode uint8
}

func mustElement(kind elementKind, instanceID int64, x, y int32, alt int16, arg int32, payloadHex string) worldElement {
	b, err := hex.DecodeString(payloadHex)
	if err != nil {
		panic("game: bad element payload hex: " + err.Error())
	}
	return worldElement{
		kind: kind, instanceID: instanceID, payload: b,
		cellX: x, cellY: y, alt: alt, arg: arg,
	}
}

// mustCardMaster builds a Card Master element, which additionally carries the
// descriptor's mode flag (0 = kardmaster shop, 1 = "démone II" exchanger).
func mustCardMaster(instanceID int64, x, y int32, alt int16, cardListID int32, mode uint8, payloadHex string) worldElement {
	e := mustElement(kindCardMaster, instanceID, x, y, alt, cardListID, payloadHex)
	e.mode = mode
	return e
}

// worldElements maps a worldId to every interactive element the server spawns
// there. The first Zaap listed for a world is its "primary" one (see primaryZaap):
// it is the default arrival for /WORLD and the login spawn.
//
// STALE UNTIL NOW: this list used to name Challenge (3), DemonChallenge (7),
// ZoneTrigger (8), BreedMaster (5), DemonTotem (11) and TournamentTotem (13) as
// "deliberately NOT spawned yet". All six ARE spawned — the table below places
// 2 Challenges, 11 DemonChallenges, 9 ZoneTriggers, 12 BreedMasters, 24
// DemonTotems and 2 TournamentTotems — and their flows exist (PvE challenges,
// breed-master test fights, the tournament calendar).
//
// CORRECTION: that "genuinely not spawned" list was itself stale. It named env
// type 12 (cardUsingSwitch → kindFirework) and type 15 (NPCTalker → kindNPC),
// but the table below places 5 Fireworks and 6 NPCs. **All 15 env types are
// spawned.** Both are safe to spawn because both are answered entirely
// client-side: the firework dialog is filled from the coach's own inventory (we
// only echo 22095 back as 22094), and NPCTalker runs a dialog tree from client
// data, so an undecoded record type 1500 costs the player nothing here.
// worldElements now lives in elements_data.go, GENERATED from the client's own
// maps/env layers by cmd/genelements. It used to be transcribed by hand here;
// see that command's doc comment for the two errors that cost us.

// elementAt returns a world's element by env instanceId.
func elementAt(world int16, instanceID int64) (worldElement, bool) {
	for _, e := range worldElements[world] {
		if e.instanceID == instanceID {
			return e, true
		}
	}
	return worldElement{}, false
}

// elementAnywhere finds an element by instanceId in any world. Instance ids are
// unique across the whole env data (elements_lobby_test pins it), so the id
// alone names the element. The Godot client has no walkable world: its lobby
// lists the services of every island and sends their 201 from wherever the
// coach is. The retail client only ever names elements of its own world.
func elementAnywhere(instanceID int64) (worldElement, bool) {
	for _, elems := range worldElements {
		for _, e := range elems {
			if e.instanceID == instanceID {
				return e, true
			}
		}
	}
	return worldElement{}, false
}

// zaapAt returns a specific Zaap on a world by env instanceId.
func zaapAt(world int16, instanceID int64) (worldElement, bool) {
	e, ok := elementAt(world, instanceID)
	if !ok || e.kind != kindZaap {
		return worldElement{}, false
	}
	return e, true
}

// primaryZaap returns a world's main (first-listed) Zaap.
func primaryZaap(world int16) (worldElement, bool) {
	for _, e := range worldElements[world] {
		if e.kind == kindZaap {
			return e, true
		}
	}
	return worldElement{}, false
}

// buildInteractiveElementSpawn builds INTERACTIVE_ELEMENT_SPAWN (opcode 200,
// client rz_2): [i16 count]{[i64 instanceId][i16 payloadLen][payload]}. Outer
// framing is big-endian (network order); each element payload is appended verbatim
// (it is an opaque part-table blob).
func buildInteractiveElementSpawn(elems ...worldElement) ([]byte, error) {
	w := protocol.NewWriter()
	w.U16(uint16(len(elems)))
	for _, e := range elems {
		p := elementPayloadAtGroundAltitude(e.payload, e.alt)
		w.I64(e.instanceID)
		w.U16(uint16(len(p)))
		w.Raw(p)
	}
	return protocol.EncodeS2C(protocol.OpInteractiveElementSpawn, w.Bytes())
}

// The payload is the client's env PART TABLE (client aJj.ad):
//
//	u8 partCount, partCount x { u8 partId, i32 offset }
//	part i data = [offset+1, nextOffset)   (or to the buffer end for the last)
//
// The element's position/mask/descriptor live in the RU part inside it. Its offset
// is therefore payload-dependent, NOT a fixed header size: every shipped payload
// has two parts and most put the RU part at byte 14, but one (world 23's card
// master, instance 5) puts it at 20. Assuming 14 silently writes into the middle
// of that element's data.
const (
	// elementRUZOffset is the z field's position WITHIN the RU part:
	// i16 world, i32 x, i32 y, then i16 z.
	elementRUZOffset = 2 + 4 + 4
	// elementRUMinLen is RU.f's own minimum (it refuses anything shorter), which
	// is how we tell the RU part from the small sibling part.
	elementRUMinLen = 23
)

// elementRUPart returns the bounds of the RU part inside an element payload.
func elementRUPart(payload []byte) (start, end int, ok bool) {
	if len(payload) < 1 {
		return 0, 0, false
	}
	n := int(payload[0])
	if n <= 0 || len(payload) < 1+n*5 {
		return 0, 0, false
	}
	offs := make([]int, n)
	p := 1
	for i := 0; i < n; i++ {
		p++ // part id
		offs[i] = int(int32(binary.BigEndian.Uint32(payload[p:])))
		p += 4
	}
	for i := 0; i < n; i++ {
		s := offs[i] + 1
		e := len(payload)
		if i < n-1 {
			e = offs[i+1]
		}
		if s < 0 || e > len(payload) || s > e {
			return 0, 0, false
		}
		if e-s >= elementRUMinLen && e-s > end-start {
			start, end, ok = s, e, true
		}
	}
	return start, end, ok
}

// elementPayloadAtGroundAltitude rewrites an element's z to its cell's walkable
// ground altitude.
//
// The blob is env AUTHORING data and its z is the sprite's decoration height, not
// the ground: world 25's Zaap carries 30 where its cell's ground is 8. The view is
// drawn at that z, so the element renders away from its cell and the client's
// cell-based pick (wp_2 -> bd(cellX, cellY)) can never reach it. Measured: with the
// authored z the Zaap is INVISIBLE and un-clickable; with the ground altitude it
// renders beside the coach and a right-click reaches the server as an element
// action.
//
// Nothing else is touched. An earlier version also cleared bit 256 of the approach
// mask, on the theory that it made every element inert via do_1.a(coach) — that
// method turns out to have NO CALLER, and an A/B on the live client confirmed the
// interaction works with the mask left exactly as shipped. Mutating authentic data
// for a dead code path is not worth it.
func elementPayloadAtGroundAltitude(payload []byte, groundAlt int16) []byte {
	start, _, ok := elementRUPart(payload)
	if !ok || start+elementRUZOffset+2 > len(payload) {
		return payload
	}
	out := make([]byte, len(payload))
	copy(out, payload)
	binary.BigEndian.PutUint16(out[start+elementRUZOffset:], uint16(groundAlt))
	return out
}

// sendWorldElements pushes the INTERACTIVE_ELEMENT_SPAWN for every element of
// worldID. Call it right after the ENTER_INSTANCE (4600) for that world — the
// client clears its element manager on each 4600, so they must be re-sent per
// entry (see sendEnterOverworld).
// Interactive elements are streamed, not sent in one go.
//
// The client cannot materialise an element just because we name it: opcode 200
// carries only [instanceId][payload], and do_1.a() resolves the element's TYPE
// through me_2.qR().eP(instanceId), a registry the CLIENT fills from its own env
// data. That registry is per-CHUNK and transient — OH.d(ru_2) registers a chunk's
// definitions as it streams in and OH.e(ru_2) unregisters them when it unloads —
// so an element whose chunk is not currently loaded is rejected outright:
//
//	Aucune définition trouvée pour l'instance d'élement interactif 103
//	Impossible de spawner l'élément interactif instanceId=103
//
// Sending every element of a world at entry therefore DROPPED most of them, for
// good, because nothing re-sent them. On the start island that silently cost the
// mailbox, the graveyard, the fusion lab and both card masters — 5 of its 6
// elements — leaving only the Zaap the coach spawns on. See BUGS.md B-108.
const (
	// envChunkSide is the env chunk size in cells (gamedata.envChunkSide).
	envChunkSide = 18
	// elementChunkRadius is how far, in chunks, the client keeps env chunks
	// loaded around the coach. MEASURED on the live client, not guessed: with the
	// coach parked at three different cells, every element at Chebyshev chunk
	// distance <= 2 resolved and every element at distance >= 3 failed, 14
	// observations with no exceptions. The boundary itself is observed (the
	// graveyard resolves at exactly 2, a card master fails at exactly 3).
	elementChunkRadius = 2
)

// chunkOf returns a cell's env chunk index. Floor division, so it is correct for
// negative coordinates too — several islands have elements at negative cells, and
// Go's truncating `/` would put them in the wrong chunk.
func chunkOf(v int32) int32 {
	if v < 0 {
		return -((-v + envChunkSide - 1) / envChunkSide)
	}
	return v / envChunkSide
}

// elementInRange reports whether the client will have this element's chunk loaded
// with the coach standing at (x, y).
func elementInRange(e worldElement, x, y int32) bool {
	dx := chunkOf(e.cellX) - chunkOf(x)
	dy := chunkOf(e.cellY) - chunkOf(y)
	if dx < 0 {
		dx = -dx
	}
	if dy < 0 {
		dy = -dy
	}
	return dx <= elementChunkRadius && dy <= elementChunkRadius
}

// refreshWorldElements brings the client's spawned elements in line with what it
// can actually resolve from where the coach now stands: it spawns the ones that
// have come into range and despawns the ones that have left.
//
// Called on world entry and after every move, so an element missed at the edge of
// the range is picked up simply by walking closer — the property that makes this
// robust even if the measured radius is slightly conservative.
func (s *Session) refreshWorldElements(worldID int16, x, y int32) {
	if s.spawnedElements == nil {
		s.spawnedElements = make(map[int64]bool)
	}
	var add []worldElement
	want := make(map[int64]bool)
	for _, e := range worldElements[worldID] {
		if !elementInRange(e, x, y) {
			continue
		}
		want[e.instanceID] = true
		if !s.spawnedElements[e.instanceID] {
			add = append(add, e)
		}
	}
	var drop []int64
	for id := range s.spawnedElements {
		if !want[id] {
			drop = append(drop, id)
		}
	}
	// Despawn first: an element leaving and another arriving in the same step are
	// independent, and freeing the old one first keeps the client's registry small.
	if len(drop) > 0 {
		sort.Slice(drop, func(i, j int) bool { return drop[i] < drop[j] })
		if frame, err := buildInteractiveElementDespawn(drop); err == nil {
			_ = s.Send(frame)
		}
		for _, id := range drop {
			delete(s.spawnedElements, id)
		}
	}
	if len(add) > 0 {
		if frame, err := buildInteractiveElementSpawn(add...); err == nil {
			_ = s.Send(frame)
		}
		for _, e := range add {
			s.spawnedElements[e.instanceID] = true
		}
	}
}

// resetSpawnedElements forgets what the client has, which it must do on a world
// change: the client drops its element registry with the old world, so every
// element of the new one has to be sent again even if the ids repeat.
func (s *Session) resetSpawnedElements() {
	s.spawnedElements = nil
}

// buildInteractiveElementDespawn builds INTERACTIVE_ELEMENT_DESPAWN (opcode 206,
// client acc_2): [i16 count]{[i64 instanceId]}.
func buildInteractiveElementDespawn(ids []int64) ([]byte, error) {
	w := protocol.NewWriter()
	w.U16(uint16(len(ids)))
	for _, id := range ids {
		w.I64(id)
	}
	return protocol.EncodeS2C(protocol.OpInteractiveElementDespawn, w.Bytes())
}
