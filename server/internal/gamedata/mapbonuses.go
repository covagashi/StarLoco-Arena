package gamedata

// mapbonuses.go decodes record type 1600, the per-map metadata records
// (client `mw_0`, registered by `gc_1` into `afh_1`). One record per map.
//
// The client reads exactly two fields per map for its map-info tooltip
// (`nl_0.java`): `cn(mapId)` → the "eliteDropBonus" line, and `co(mapId)` →
// the "evolutionMapBonus" line rendered from an akw_0 action array. The wire
// layout comes from `mw_0.a(ByteBuffer,int,short)` version 1:
//
//	[i16 mapId][u8 eliteDropBonus][u8 nActions][nActions x akw_0]
//
// WHAT THE ACTIONS CARRY (this corpus, 29 records):
//
//	arenas 86-109 : one AI19 ("Modification des chances de drop") param 1-25 —
//	                the map's base drop-chance bonus, i.e. `alb_1.cl`'s `n3`.
//	maps   24-28  : one AI1 ("Bonus ou malus d'XP en %") param 5-25 —
//	                the evolution-mode XP bonus those maps advertise.
//
// The eliteDropBonus byte is the map's Elite-mode drop bonus (the i18n label
// is literally "Bonus Elite"); 2.70 renders it as a bare number, so its exact
// semantics (extra draw rolls vs. added chance) is the one unproven piece —
// we treat it as extra draw rolls on non-practice wins, the reading that
// matches both its name and the bare-count formatting.
type MapBonus struct {
	// MapID is the world/map id this record describes (`bud`).
	MapID int16
	// EliteDropBonus is the byte shown as "Bonus Elite : N" (`bue`) — extra
	// card draws granted on non-practice wins on this map.
	EliteDropBonus uint8
	// Actions is the akw_0 array (`UD`): AI1 (XP %) or AI19 (drop chance %).
	Actions []CardSetEffect
}

// TypeMapBonus is the data.bdat record type holding per-map bonus metadata
// (client enum `atr_0.cVm` = 1600).
const TypeMapBonus = 1600

// The two AI action ids this corpus's map records carry (the full enum is
// AI.java; the game package keeps its own copy for the post-fight pass).
const (
	AIXPPercent  int32 = 1  // "Bonus ou malus d'XP en %"
	AIDropChance int32 = 19 // "Modification des chances de drop"
)

// MapBonuses is the decoded type-1600 table, keyed by map id.
type MapBonuses struct {
	byMap map[int16]*MapBonus
}

// NewMapBonuses builds a table from explicit records (tests).
func NewMapBonuses(recs ...*MapBonus) *MapBonuses {
	t := &MapBonuses{byMap: make(map[int16]*MapBonus, len(recs))}
	for _, r := range recs {
		if r != nil {
			t.byMap[r.MapID] = r
		}
	}
	return t
}

// Get returns the bonus record for a map id, or nil when the map grants none.
func (t *MapBonuses) Get(mapID int16) *MapBonus {
	if t == nil {
		return nil
	}
	return t.byMap[mapID]
}

// Len reports how many records decoded.
func (t *MapBonuses) Len() int {
	if t == nil {
		return 0
	}
	return len(t.byMap)
}

// DropChanceBonus sums the map's AI19 drop-chance parameters (0 when the map
// has none) — the `n3` argument of the `alb_1.cl` draw.
func (t *MapBonuses) DropChanceBonus(mapID int16) int32 {
	m := t.Get(mapID)
	if m == nil {
		return 0
	}
	var total int32
	for _, a := range m.Actions {
		if a.Action == AIDropChance && len(a.Params) > 0 {
			total += a.Params[0]
		}
	}
	return total
}

// XPBonusPercent sums the map's AI1 XP-percent parameters (0 when none) — the
// evolution-mode XP bonus those maps advertise.
func (t *MapBonuses) XPBonusPercent(mapID int16) int32 {
	m := t.Get(mapID)
	if m == nil {
		return 0
	}
	var total int32
	for _, a := range m.Actions {
		if a.Action == AIXPPercent && len(a.Params) > 0 {
			total += a.Params[0]
		}
	}
	return total
}

// LoadMapBonuses decodes every type-1600 record.
func (s *Store) LoadMapBonuses() (*MapBonuses, error) {
	out := &MapBonuses{byMap: make(map[int16]*MapBonus)}
	for _, e := range s.EntriesOf(TypeMapBonus) {
		rec, err := s.ReadRecord(e.Position)
		if err != nil {
			return nil, err
		}
		if m := decodeMapBonus(rec.Data); m != nil {
			out.byMap[m.MapID] = m
		}
	}
	return out, nil
}

// decodeMapBonus reads one `mw_0` record, or nil if it is short.
func decodeMapBonus(data []byte) *MapBonus {
	c := &cur{b: data}
	m := &MapBonus{}
	m.MapID = c.i16()
	m.EliteDropBonus = c.u8()
	n := int(c.u8())
	if n < 0 || n > 32 {
		return nil
	}
	for i := 0; i < n && c.ok(); i++ {
		m.Actions = append(m.Actions, decodeAkw(c))
	}
	if !c.ok() {
		return nil
	}
	return m
}
