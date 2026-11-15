package gamedata

import "sort"

// events.go holds the per-round EVENT CARDS (retail client class ama_1; ours
// in server/content/cards/events.json since S40).
//
// An event card is the card drawn at the start of every table turn (round). The
// mechanic is SERVER-authoritative: NEW_TABLE_TURN_BEGIN (8100) carries only an
// `int eventId`, which the client resolves via cw_1.eO().w(id) into a `tO`
// ("ClientEvent") purely to DISPLAY the card art/name/description — it applies
// nothing. The server draws the card and applies its effects.
//
// Wire layout (big-endian), matched field-for-field against ama_1.a():
//
//	i32 id, i16 (unused), u8 descriptionFlag, then the standard embedded
//	effect list ([i32 count] + count × {i32 innerId, i16 innerVer, i32 len, blob})
//
// Every shipped event effect carries areaShape=32767 ("all") and duration=[1,0]
// (one table turn), which is exactly the mechanic: the card affects the whole
// arena for the round it was drawn on.

// Event is one decoded per-round event card.
type Event struct {
	ID int32
	// Effects are applied to the whole arena for the round. Each carries its own
	// target-condition mask (Effect.Targets) — the breed-god cards restrict
	// themselves to a single breed that way, e.g. "Dieu Iop" only buffs Iops.
	Effects []Effect
	// DescriptionFlag is ama_1.eB(), passed straight to the client's description
	// formatter (asf_0.a). It carries no gameplay meaning; kept so a decoder test
	// can assert we consumed the byte rather than mis-aligning the effect list.
	DescriptionFlag bool
}

// Events holds all event definitions by id.
type Events struct {
	byID map[int32]*Event
	ids  []int32 // sorted, for a deterministic pre-shuffle deck order
}

// NewEvents builds a catalog from explicit definitions (tests/tooling).
func NewEvents(defs ...*Event) *Events {
	out := &Events{byID: make(map[int32]*Event, len(defs))}
	for _, d := range defs {
		if d != nil {
			out.byID[d.ID] = d
		}
	}
	out.reindex()
	return out
}

func (e *Events) reindex() {
	e.ids = make([]int32, 0, len(e.byID))
	for id := range e.byID {
		e.ids = append(e.ids, id)
	}
	sort.Slice(e.ids, func(i, j int) bool { return e.ids[i] < e.ids[j] })
}

// Get returns the card for id, or nil when the table has no such event.
func (e *Events) Get(id int32) *Event {
	if e == nil {
		return nil
	}
	return e.byID[id]
}

// IDs returns every event id, ascending.
func (e *Events) IDs() []int32 {
	if e == nil {
		return nil
	}
	return e.ids
}

// Len is the number of decoded event cards.
func (e *Events) Len() int {
	if e == nil {
		return 0
	}
	return len(e.byID)
}
