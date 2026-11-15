package gamedata

// equipmentpools.go decodes EQUIPMENT POOLS (record type 251, client class
// `alf_2`), the sets of equipment a Sphere Board node unlocks for a fighter.
//
// The record is as small as it looks: an id and a list of equipment-card ids.
// `ne_0` loads them, resolves each id through the equipment-card registry and
// files the result under the pool id (`aca_0.a(map, poolId)`).
//
// What makes them worth having server-side is the ENTITLEMENT question. An
// evolution fighter's equipment picker is built exclusively from the pools its
// bought nodes unlocked: `ee_2.getFieldValue` walks `aRF`, pulls each pool and
// keeps the cards matching the slot being filled. A classic ("Elite") fighter
// uses a different path entirely (`aca_0.b(type)`, every card of that type), so
// the restriction belongs to evolution fighters alone.
//
// The client therefore cannot OFFER a card the fighter has not unlocked - which
// is precisely why the server has to check it. The one place a card can arrive
// unearned is a crafted 6011.

// EquipmentPool is one decoded pool.
type EquipmentPool struct {
	ID int32
	// CardIDs are the equipment cards this pool unlocks. Order is the record's.
	CardIDs []int32
	// leftover is how many bytes of the record went unread; 0 on every shipped row
	// is what proves the layout.
	leftover int
}

// Leftover reports unconsumed bytes; 0 means the record was fully accounted for.
func (p *EquipmentPool) Leftover() int { return p.leftover }

// EquipmentPools is the decoded catalogue.
type EquipmentPools struct {
	byID   map[int32]*EquipmentPool
	ids    []int32
	byCard map[int32][]int32 // cardID -> pool ids that grant it
}

// NewEquipmentPools builds a catalogue from explicit definitions (tests/tooling).
func NewEquipmentPools(pools ...*EquipmentPool) *EquipmentPools {
	out := &EquipmentPools{byID: make(map[int32]*EquipmentPool, len(pools))}
	for _, p := range pools {
		if p != nil {
			out.byID[p.ID] = p
		}
	}
	out.reindex()
	return out
}

func (c *EquipmentPools) reindex() {
	c.ids = make([]int32, 0, len(c.byID))
	c.byCard = make(map[int32][]int32)
	for id, p := range c.byID {
		c.ids = append(c.ids, id)
		for _, card := range p.CardIDs {
			c.byCard[card] = append(c.byCard[card], id)
		}
	}
	sortInt32Slice(c.ids)
	for card := range c.byCard {
		sortInt32Slice(c.byCard[card])
	}
}

// Get returns a pool by id.
func (c *EquipmentPools) Get(id int32) *EquipmentPool {
	if c == nil {
		return nil
	}
	return c.byID[id]
}

// IDs returns every pool id, ascending.
func (c *EquipmentPools) IDs() []int32 {
	if c == nil {
		return nil
	}
	return c.ids
}

// Len reports how many pools were decoded.
func (c *EquipmentPools) Len() int {
	if c == nil {
		return 0
	}
	return len(c.byID)
}

// Grants reports whether any of the given pools contains a card. This is the
// entitlement question, asked the way the caller has it: a fighter holds a set of
// unlocked pool ids and wants to equip one card.
func (c *EquipmentPools) Grants(poolIDs []int32, cardID int32) bool {
	if c == nil {
		return false
	}
	for _, id := range poolIDs {
		p := c.byID[id]
		if p == nil {
			continue
		}
		for _, card := range p.CardIDs {
			if card == cardID {
				return true
			}
		}
	}
	return false
}

// CardsOf returns every card the given pools unlock, deduplicated and ascending.
func (c *EquipmentPools) CardsOf(poolIDs []int32) []int32 {
	if c == nil {
		return nil
	}
	seen := map[int32]bool{}
	var out []int32
	for _, id := range poolIDs {
		p := c.byID[id]
		if p == nil {
			continue
		}
		for _, card := range p.CardIDs {
			if !seen[card] {
				seen[card] = true
				out = append(out, card)
			}
		}
	}
	sortInt32Slice(out)
	return out
}
