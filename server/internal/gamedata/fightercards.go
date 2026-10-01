package gamedata

// RunningEffect action ids for the passive CharacBuff bonuses a fighter card can
// grant while equipped (RunningEffectConstants: HP_BOOST=11, AP_BOOST=13,
// MP_BOOST=17, INIT_BOOST=76). Each raises the matching characteristic's MAX on
// the fighter that equips the card — verified in the client's CharacBuff.execute
// (updateMaxValue) reached from the equipment-inventory ITEM_ADDED path.
const (
	actionHPBoost   = 11
	actionAPBoost   = 13
	actionMPBoost   = 17
	actionInitBoost = 76
)

// FighterStatBonus is the summed EQUIP-time characteristic boost a fighter card
// grants passively. The 2.70 client adds exactly these to a fighter's breed-base
// max HP/AP/MP/init when the card sits in its equipment inventory, so the server
// must add the same to keep its damage/death math and the client HP gauge in
// sync.
type FighterStatBonus struct {
	HP, AP, MP, Init, Range int32
}

// IsZero reports whether the card grants no passive stat bonus.
func (b FighterStatBonus) IsZero() bool {
	return b.HP == 0 && b.AP == 0 && b.MP == 0 && b.Init == 0 && b.Range == 0
}

// FighterCard is a decoded fighter-card template (record type 250, class uh_0) —
// a fighter's equipment, i.e. its weapon and gear. A card carries two disjoint
// effect lists, told apart by each effect's container type (the client splits
// them the same way in jb_2.a, trimming the space-padded field):
//
//   - FIGHTER_CARD_EQUIP — passive, applied while the card is equipped.
//   - FIGHTER_CARD_USE   — the ACTIVE ability, i.e. attacking with the weapon.
//     A card is "usable" in a fight iff it has at least one (client
//     jb_2.isUsable); 23 of the 75 shipped cards are.
type FighterCard struct {
	ID    int32
	Type  int16
	Value int32
	Bonus FighterStatBonus
	// EquipEffects are the card's passive FIGHTER_CARD_EQUIP effects, kept raw so
	// the combat layer can accumulate the elemental damage/resistance bonuses
	// (mh_2 21-55, 80-83) the flat Bonus summary does not cover.
	EquipEffects []Effect

	// --- use-time (active) data: the weapon attack, played via 8107 ---

	// ScriptID (uh_0 field 7, eA()) is the Lua script the client's card-use
	// action runs (abk_1 bGs it). The shipped weapon scripts 8000-8007 play
	// the per-family armed gesture AnimStatique03(-Debut)-<fam> — 219 fists,
	// 110 sword, 112 dagger, 117 bow, 108 wand, 114 hammer, 111 shovel.
	ScriptID int32
	// APCost is the AP the attack costs (client jb_2.Vo()).
	APCost int32
	// RangeMin/RangeMax bound the aimable distance (Manhattan), client
	// jb_2.AA()/Az(). NB the record stores MAX BEFORE MIN — three independent
	// signals agree: the client renders the range as "AA()-Az()" (which is only
	// ascending this way), a RangeMax of 0 is what makes a card self-target-only
	// (ve_0's "cast.targetCaster"), and reading them the other way round yields
	// min > max on every ranged weapon in the shipped data.
	RangeMin int32
	RangeMax int32
	// Targeting gates, each mapped to the client rejection it causes in mv_1:
	// OnlyLine -> aUl, TestLoS -> the ahc_2 ray-cast, NeedFreeCell -> aUk,
	// and the two "usable while …" flags -> aUm.
	OnlyLine          bool
	TestLoS           bool
	NeedFreeCell      bool
	UsableWhenDead    bool
	UsableWhenCarried bool
	// UseEffects are the FIGHTER_CARD_USE effects, including both the normal and
	// the IsCritical subsets (selected at resolve time).
	UseEffects []Effect
}

// Usable reports whether the card has an active ability that can be played in a
// fight (client jb_2.isUsable: the FIGHTER_CARD_USE list is non-empty).
func (c *FighterCard) Usable() bool { return c != nil && len(c.UseEffects) > 0 }

// FighterCards holds all fighter-card templates by id.
type FighterCards struct {
	byID map[int32]*FighterCard
}

// LoadFighterCards reads and decodes every fighter-card template (type 250).
func (s *Store) LoadFighterCards() (*FighterCards, error) {
	fc := &FighterCards{byID: make(map[int32]*FighterCard)}
	for _, e := range s.EntriesOf(TypeFighterCard) {
		rec, err := s.ReadRecord(e.Position)
		if err != nil {
			return nil, err
		}
		if card := decodeFighterCard(rec.Data); card != nil {
			fc.byID[card.ID] = card
		}
	}
	return fc, nil
}

// NewFighterCards builds a catalog from explicit templates (tests/tooling).
func NewFighterCards(templates ...*FighterCard) *FighterCards {
	fc := &FighterCards{byID: make(map[int32]*FighterCard, len(templates))}
	for _, t := range templates {
		if t != nil {
			fc.byID[t.ID] = t
		}
	}
	return fc
}

// Get returns a fighter-card template by id, or nil.
func (c *FighterCards) Get(id int32) *FighterCard { return c.byID[id] }

// Len reports how many templates were loaded.
func (c *FighterCards) Len() int { return len(c.byID) }

// All returns every loaded fighter-card template.
func (c *FighterCards) All() map[int32]*FighterCard { return c.byID }

// fighterCardHeaderLen is the fixed size of a uh_0 record's scalar header before
// the embedded effect list (fields 1-14, verified against uh_0.a):
//
//	i32 id, i16 type, i8 weaponAp, i32 value, i32 rangeMAX, i32 rangeMIN,
//	i32 (uh_0.eA), i32 iconSubType, 6×bool  = 4+2+1+4+4+4+4+4+6 = 33 bytes.
const fighterCardHeaderLen = 33

// decodeFighterCard parses a uh_0 record (DATA-FORMAT §5) and sums its EQUIP-time
// CharacBuff effects into Bonus. Returns nil on a malformed/empty record.
func decodeFighterCard(data []byte) *FighterCard {
	c := &cur{b: data}
	id := c.i32()       // 1  id
	typ := c.i16()      // 2  type
	ap := c.u8()        // 3  weaponActionPoints (jb_2.Vo)
	value := c.i32()    // 4  value
	rangeMax := c.i32() // 5  uh_0.Az -> jb_2.Az = range MAX (see the struct doc)
	rangeMin := c.i32() // 6  uh_0.AA -> jb_2.AA = range MIN
	scriptID := c.i32() // 7  uh_0.eA — use-time Lua script id
	c.i32()             // 8  icon sub-type (ve_0.Bo)
	// The six flags, now identified against the client's own targeting validator
	// (mv_1.a(gn_0, jb_2, ry), which rejects a use with a specific error per flag).
	onlyLine := c.u8() != 0     // 9  ex() -> Vp(): target must share the caster's row/col
	testLoS := c.u8() != 0      // 10 ew() -> iW(): needs line of sight
	needFreeCell := c.u8() != 0 // 11 ey() -> Vq(): target cell must be empty
	whenDead := c.u8() != 0     // 12 AB() -> Vr(): usable while dead/KO
	whenCarried := c.u8() != 0  // 13 AC() -> Vs(): usable while carried
	c.u8()                      // 14 AD(): description-generation toggle only
	if !c.ok() || id <= 0 {
		return nil
	}
	card := &FighterCard{
		ID: id, Type: typ, Value: value, ScriptID: scriptID,
		APCost: int32(ap), RangeMin: rangeMin, RangeMax: rangeMax,
		OnlyLine: onlyLine, TestLoS: testLoS, NeedFreeCell: needFreeCell,
		UsableWhenDead: whenDead, UsableWhenCarried: whenCarried,
	}
	effects := decodeEffectList(c) // 15 effects
	card.Bonus = sumEquipBonus(effects)
	for _, ef := range effects {
		switch ef.ContainerType {
		case containerFighterCardEquip:
			card.EquipEffects = append(card.EquipEffects, ef)
		case containerFighterCardUse:
			card.UseEffects = append(card.UseEffects, ef)
		}
	}
	return card
}

// Effect container types. The record stores these space-padded to a fixed width
// ("FIGHTER_CARD_USE  "); decodeEffectBlob trims them, exactly as the client does
// (jb_2.a calls .trim() before comparing).
const (
	containerFighterCardEquip = "FIGHTER_CARD_EQUIP"
	containerFighterCardUse   = "FIGHTER_CARD_USE"
)

// sumEquipBonus folds an effect list into the passive stat bonus, counting only
// FIGHTER_CARD_EQUIP (passive) CharacBuff effects — a FIGHTER_CARD_USE effect is
// an active ability and must NOT be pre-applied to the fighter's max.
func sumEquipBonus(effects []Effect) FighterStatBonus {
	var b FighterStatBonus
	for _, ef := range effects {
		if ef.ContainerType != containerFighterCardEquip || len(ef.Params) == 0 {
			continue
		}
		v := int32(ef.Params[0])
		switch ef.ActionID {
		case actionHPBoost:
			b.HP += v
		case actionAPBoost:
			b.AP += v
		case actionMPBoost:
			b.MP += v
		case actionInitBoost:
			b.Init += v
		case actionRangeGain:
			b.Range += v
		}
	}
	return b
}
