package gamedata

// StaticEffect is a decoded trap/glyph template (record type 210, class rf_2).
// A spell effect with action id 66 ("Pose un piège") carries a template id in
// its params[0]; the server instantiates a live ground-effect area from the
// matching StaticEffect, and replays this template's inner Effects on whichever
// fighter triggers the area (walks onto it, or starts a turn on it).
//
// Wire layout (big-endian, record version must be 1), verified against the
// client's rf_2 deserializer (DofusArena 2.70 decompiled core, rf_2.java a()):
//
//	i32 id, str type, str label,
//	i32 areaShape, i32 maxExec, i32 _unknown1, i32 appCondition, i32 _unknown2,
//	i32[] areaSize, i32[] appTriggers, i32[] unappTriggers, i32[] deactivationDelay,
//	effectList inner effects
//
// String = [i32 len][utf8]; every array = [i32 count][i32×count] (the Java BitSet
// trigger sets are serialized as plain id arrays, NOT bit-packed).
//
// Named from the client's loader (aeb_0 -> er_1 / yl_1 / ack_1, S19): field 6
// is ack_1.ahJ, which nothing in the client reads; field 8 is the trigger
// animation (aor.bG(er_1.eA())); field 12 is the re-trigger delay pair (yl_1.FH:
// either value > 0 arms it). Field 7 (yl_1.aDQ) and fields 6 and 12 are zero /
// empty in all 16 shipped templates, so the server applies none of them;
// TestStaticEffectsUnusedFieldsReal fails if a data change ever sets one.
type StaticEffect struct {
	ID             int32
	Type           string // "TRAP" (walk/turn-triggered) | "SPECIAL" (map bonus tile)
	Label          string // e.g. "trap", "mauvaisOeil" (often "")
	AreaShape      int32  // footprint shape (1 point, 2 circle, …)
	AreaSize       []int32
	MaxExec        int32   // firings before self-removal; >=63 or <0 = unlimited
	AppCondition   int32   // yl_1.d: 0 always / 1 once-everyone / 2 once-team / 3 once-target
	Field6         int32   // ack_1.ahJ, unread by the client
	Animation      int32   // the trigger's animation id (aor.bG), display only
	RetriggerDelay []int32 // yl_1.cjB: the re-trigger delay pair
	AppTriggers    []int32 // trigger event ids that FIRE the area (10001 walk-on, 10000 turn-start, …)
	UnappTriggers  []int32 // trigger event ids that UN-apply it (exit)
	Effects        []Effect
}

// Unlimited reports whether the area never self-removes from a firing count
// (mirrors yl_1.FF(): maxExec >= 63 || maxExec < 0).
func (t *StaticEffect) Unlimited() bool { return t.MaxExec >= 63 || t.MaxExec < 0 }

// StaticEffects holds every trap/glyph template by id.
type StaticEffects struct {
	byID map[int32]*StaticEffect
}

// LoadStaticEffects reads and decodes every trap/glyph template (type 210).
func (s *Store) LoadStaticEffects() (*StaticEffects, error) {
	out := &StaticEffects{byID: make(map[int32]*StaticEffect)}
	for _, e := range s.EntriesOf(TypeStaticEffect) {
		rec, err := s.ReadRecord(e.Position)
		if err != nil {
			return nil, err
		}
		if t := decodeStaticEffect(rec.Data); t != nil {
			out.byID[t.ID] = t
		}
	}
	return out, nil
}

// NewStaticEffects builds a catalog from explicit templates (tests/tooling).
func NewStaticEffects(templates ...*StaticEffect) *StaticEffects {
	out := &StaticEffects{byID: make(map[int32]*StaticEffect, len(templates))}
	for _, t := range templates {
		if t != nil {
			out.byID[t.ID] = t
		}
	}
	return out
}

// Get returns a template by id, or nil.
func (s *StaticEffects) Get(id int32) *StaticEffect { return s.byID[id] }

// Len reports how many templates were loaded.
func (s *StaticEffects) Len() int { return len(s.byID) }

// All returns every loaded trap/glyph template, keyed by id.
func (s *StaticEffects) All() map[int32]*StaticEffect { return s.byID }

// decodeStaticEffect parses one rf_2 record. Returns nil for a malformed/empty
// record (the defensive cursor degrades a truncated tail to zero values).
func decodeStaticEffect(data []byte) *StaticEffect {
	c := &cur{b: data}
	t := &StaticEffect{}
	t.ID = c.i32()                  // 1 id
	t.Type = c.str()                // 2 type "TRAP"/"SPECIAL"
	t.Label = c.str()               // 3 label
	t.AreaShape = c.i32()           // 4 areaShape
	t.MaxExec = c.i32()             // 5 maxExecutionCount
	t.Field6 = c.i32()              // 6 ack_1.ahJ
	t.AppCondition = c.i32()        // 7 applicationCondition
	t.Animation = c.i32()           // 8 trigger animation
	t.AreaSize = c.i32Array()       // 9 areaSize
	t.AppTriggers = c.i32Array()    // 10 applicationTriggers
	t.UnappTriggers = c.i32Array()  // 11 unapplicationTriggers
	t.RetriggerDelay = c.i32Array() // 12 re-trigger delay
	t.Effects = decodeEffectList(c) // 13 inner effects
	if !c.ok() || t.ID <= 0 {
		return nil
	}
	return t
}
