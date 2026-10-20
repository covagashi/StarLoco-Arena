package gamedata

import ()

// CardTypeEvolution is the client's aMK.dYy (24, "Evolution"): the consumable
// cards of the evolution mode. The retail graveyard only offers the sets whose
// cards are of this type (aij_0 "evolutionSets"), so it is the only type a
// resurrection may spend.
const CardTypeEvolution int32 = 24

// CoachCard is a decoded coach-card template (record type 100, class aPp).
// We decode the fields the server needs (id, set, value, and the token price
// map); the rest of the record is skipped.
type CoachCard struct {
	ID int32
	// Type is the card's kind (client enum aMK), NOT an icon reference: 2..13 are
	// the equipment slots, 20 is a Zaap card, etc. (DATA-FORMAT.md §6 mislabels
	// this field "iconRef".)
	Type int32
	// CardSet is the card's "panoplie" (set) id, named by content.25.<id>. It is
	// also what a Card Master's descriptor selects as its stock — see
	// game.cardMasterStock.
	CardSet int32
	Value   int32 // barter/recycle value (field r); NOT the shop price
	Rank    int32
	// Price is the shop cost: currencyType -> amount (field 5, the aim_1
	// "tokenValue" map). A card with an empty Price is not purchasable.
	Price map[uint8]int32
	// RequiredLevel (field 6, tr()) is the coach level needed to use the card; the
	// client greys it out below that.
	RequiredLevel int32
	// FireworkType (field 7, tl()) and FireworkColour (field 8, tk(), an RGB
	// triple when it has 3 entries) drive the firework particle effect.
	FireworkType   uint8
	FireworkColour []float32
	// IsUnique (field 9) is set but never read by the client either.
	IsUnique bool
	// ObtainableInDraw (field 10, to()) admits the card to the random booster
	// table; DropPercent (field 11, ts()) is its weight there.
	ObtainableInDraw bool
	DropPercent      int32
	// Bound (field 12, tp()) marks a card as linked to its owner: the client
	// refuses to stake it in an exchange ("error.exchange.linkedCard"). The server
	// must enforce it too — a client cannot be trusted to police trading.
	Bound bool
	// Undestructible (field 13, tq()) blocks destroy/sell/trade
	// ("coachInventory.undestructibleCard").
	Undestructible bool
	// HasUsableAction (field 14, tt()) marks the card as consumable/usable.
	HasUsableAction bool
	// ResurrectPercent is the % chance (1..100) this card gives to resurrect a
	// fighter it is dropped on (client effect action 13, AI.aHI, param[0]); 0 if
	// the card carries no resurrection effect. Read from the card's effect array
	// (aPp field 15). Used by the graveyard 22099 handler to gate + roll the
	// resurrection. Verified values: cards 305/316/317/318 = 100%, 51 = 12%,
	// 53 = 10%, 35 = 5%, 137 = 1%.
	ResurrectPercent int32
	// Effects is the card's full akw_0 effect array (field 15). The action ids
	// are the client's AI enum — the coach META layer, not in-fight combat.
	Effects []CardSetEffect

	// --- fields 19-26 (see parameters.go for why these were unreachable) ---

	// Parameters (19, tv()) are the card's `np_1` gameplay parameters. The client
	// gathers them across a team preset to build its fight profile
	// (acx_2: `jk_1.mf().mg().a(np_1Array)`).
	Parameters []Parameter
	// Unknown19/20 (20-21, tw()/tx()) are handed to the runtime card object and
	// never read again — dead in the client, kept so the record round-trips.
	Unknown19 int16
	Unknown20 int16
	// FusionPower (22, tz()) and FusionQuality (23, tA()) are the fusion
	// laboratory's "labPower" and "quality" fields (client ajt_1's Xulor field
	// names). They are also formatted into the description of pet-type cards.
	FusionPower   int16
	FusionQuality uint8
	// PetModelID (24, tB()) is the pet appearance id: `aez_0.aQv()` spawns one
	// visual instance per owned pet using it.
	PetModelID int32
	// ColourSlot (25, tD()) and ColourIndex (26, tE()) are a colouring card's
	// target and palette entry — client `setFighterColorIndex`, one of the few
	// unobfuscated method names in the jar: slot 0/1/2 maps to element ids
	// 16650/16651/16652 (hair / skin / eyes).
	ColourSlot  uint8
	ColourIndex int32
}

// EffectParam returns the first parameter of this card's effect with the given
// AI action id, and whether the card carries one at all. Several effects with
// the same action are summed, matching how the client aggregates them.
func (c *CoachCard) EffectParam(action int32) (int32, bool) {
	if c == nil {
		return 0, false
	}
	var total int32
	var found bool
	for _, ef := range c.Effects {
		if ef.Action == action && len(ef.Params) > 0 {
			total += ef.Params[0]
			found = true
		}
	}
	return total, found
}

// resurrectAction is the client AI effect action id (enum AI.aHI) whose param[0]
// is the resurrection success percentage.
const resurrectAction int32 = 13

// Cards holds all coach-card templates by id.
type Cards struct {
	byID map[int32]*CoachCard
}

// LoadCards reads and decodes every coach-card template from the store.
func (s *Store) LoadCards() (*Cards, error) {
	cards := &Cards{byID: make(map[int32]*CoachCard)}
	for _, e := range s.EntriesOf(TypeCoachCard) {
		rec, err := s.ReadRecord(e.Position)
		if err != nil {
			return nil, err
		}
		card, err := decodeCoachCard(rec.Data)
		if err != nil {
			// Skip malformed records rather than failing the whole load.
			continue
		}
		cards.byID[card.ID] = card
	}
	return cards, nil
}

// NewCards builds a Cards catalog from an explicit set of templates. Intended
// for tests and tooling that need a deterministic catalog without the client
// data files.
func NewCards(templates ...*CoachCard) *Cards {
	c := &Cards{byID: make(map[int32]*CoachCard, len(templates))}
	for _, t := range templates {
		if t != nil {
			c.byID[t.ID] = t
		}
	}
	return c
}

// Get returns a card template by id, or nil.
func (c *Cards) Get(id int32) *CoachCard { return c.byID[id] }

// All returns every loaded card template.
func (c *Cards) All() map[int32]*CoachCard { return c.byID }

// Priced returns the ids of every card that has a non-empty token price, in
// ascending id order (deterministic). These are the cards the shop can sell.
func (c *Cards) Priced() []int32 {
	ids := make([]int32, 0, len(c.byID))
	for id, card := range c.byID {
		if len(card.Price) > 0 {
			ids = append(ids, id)
		}
	}
	sortInt32Asc(ids)
	return ids
}

// CardsInSet returns the ids of every card belonging to cardSet, ascending.
// A cardSet of 0 (ungrouped) returns nothing — those cards can't be fused.
func (c *Cards) CardsInSet(cardSet int32) []int32 {
	if cardSet == 0 {
		return nil
	}
	ids := make([]int32, 0, 8)
	for id, card := range c.byID {
		if card.CardSet == cardSet {
			ids = append(ids, id)
		}
	}
	sortInt32Asc(ids)
	return ids
}

// sortInt32Asc sorts a slice of int32 ascending (insertion sort; small deps).
func sortInt32Asc(a []int32) {
	for i := 1; i < len(a); i++ {
		for j := i; j > 0 && a[j-1] > a[j]; j-- {
			a[j-1], a[j] = a[j], a[j-1]
		}
	}
}

// Len reports how many templates were loaded.
func (c *Cards) Len() int { return len(c.byID) }

// decodeCoachCard reads the leading fields of an aPp record (big-endian):
//
//	i32 id, i32 type, i32 cardSet, i32 value, then the token-price map
//	[i8 count]{i8 currencyType, i32 amount} (field 5, the shop "tokenValue"),
//	... (remaining fields skipped).
//
// decodeCoachCard parses an aPp record in full, matching the client's aPp
// deserializer field for field.
//
// The record is read to the END, including the 19-26 tail (the `np_1[]`
// parameters, fusion power/quality, pet model, colour slot/palette). That tail
// used to be unreachable because the `np_1` element layout was unknown; it was
// decoded in B-071/B-073. Nothing in this record references a spell — the last
// field, `tE()`, is the colour PALETTE index (the client builds the style class
// as `"fighterColor" + tE()`), not a link to anything castable.
func decodeCoachCard(data []byte) (*CoachCard, error) {
	return decodeCoachCardCursor(&cur{b: data})
}

// decodeCoachCardCursor is decodeCoachCard over a caller-owned cursor, so a test
// can inspect how many bytes of the record were consumed. A record that decodes
// with ZERO bytes left over is the strongest evidence a layout is right.
func decodeCoachCardCursor(c *cur) (*CoachCard, error) {
	card := &CoachCard{}
	card.ID = c.i32()      // 1 id
	card.Type = c.i32()    // 2 type (client enum aMK)
	card.CardSet = c.i32() // 3 card set / panoplie
	card.Value = c.i32()   // 4 barter value
	// 5 token-price map (aim_1): [i8 count] then count × (i8 key, i32 amount).
	if n := int(c.u8()); n > 0 && n <= 64 {
		card.Price = make(map[uint8]int32, n)
		for i := 0; i < n && c.ok(); i++ {
			key := c.u8()
			card.Price[key] = c.i32()
		}
	}
	card.RequiredLevel = c.i32() // 6  tr()
	card.FireworkType = c.u8()   // 7  tl()
	// 8 tk(): float params, i32-counted (NOT i8 — getting this wrong misaligns
	// everything after it).
	if n := int(c.i32()); n > 0 && n <= 64 {
		card.FireworkColour = make([]float32, 0, n)
		for i := 0; i < n && c.ok(); i++ {
			card.FireworkColour = append(card.FireworkColour, c.f32())
		}
	}
	card.IsUnique = c.u8() != 0         // 9
	card.ObtainableInDraw = c.u8() != 0 // 10 to()
	card.DropPercent = c.i32()          // 11 ts()
	card.Bound = c.u8() != 0            // 12 tp()
	card.Undestructible = c.u8() != 0   // 13 tq()
	card.HasUsableAction = c.u8() != 0  // 14 tt()
	// 15 tu(): the akw_0 effect array — the SAME structure card sets and fighter
	// conditions carry, so it is decoded with the shared decodeAkw. Keeping the
	// whole list (rather than sniffing one action out of it, as this used to)
	// is what makes every consumable card usable: healing (AI 5/11), morale
	// (AI 9), fatigue (AI 16) and "apply a condition" (AI 15) all live here.
	if n := int(c.u8()); n >= 0 && n <= 64 {
		for k := 0; k < n && c.ok(); k++ {
			ef := decodeAkw(c)
			card.Effects = append(card.Effects, ef)
			if ef.Action == resurrectAction && card.ResurrectPercent == 0 && len(ef.Params) > 0 {
				card.ResurrectPercent = ef.Params[0]
			}
		}
	}
	c.u8()              // 16 aZd() — dead in the client too
	c.i32()             // 17 aZe() — dead in the client too
	card.Rank = c.i32() // 18 getRank(): drives the client's rarity frame colour

	// 19-26: the tail that used to be unreachable because the `np_1` element
	// layout was unknown (see parameters.go). Field order from aPp's own
	// deserializer `a(ByteBuffer,int,short)`.
	params, ok := decodeParameters(c) // 19 tv(): gameplay parameters
	card.Parameters = params
	if !ok {
		// A parameter carried an inline effect we cannot skip; everything after
		// it would be garbage. Keep what we have rather than invent values.
		return card, nil
	}
	card.Unknown19 = c.i16()    // 20 tw(): passed to the runtime card, never read
	card.Unknown20 = c.i16()    // 21 tx(): idem
	card.FusionPower = c.i16()  // 22 tz(): the fusion lab's "labPower" field
	card.FusionQuality = c.u8() // 23 tA(): the fusion lab's "quality" field
	card.PetModelID = c.i32()   // 24 tB(): pet appearance, spawned by aez_0.aQv()
	card.ColourSlot = c.u8()    // 25 tD(): 0 hair / 1 skin / 2 eyes
	card.ColourIndex = c.i32()  // 26 tE(): palette index within that slot

	if card.ID <= 0 {
		return nil, errShort
	}
	// A truncated tail leaves the trailing fields zeroed rather than dropping an
	// otherwise-usable card — the leading id/type/set/value are what most callers
	// need.
	return card, nil
}

var errShort = shortErr("gamedata: record too short")

type shortErr string

func (e shortErr) Error() string { return string(e) }
