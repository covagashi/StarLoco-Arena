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

var errShort = shortErr("gamedata: record too short")

type shortErr string

func (e shortErr) Error() string { return string(e) }
