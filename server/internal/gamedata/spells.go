package gamedata

// Spell is a decoded spell template (record type 220, class co_1). We decode the
// scalar combat fields plus the embedded effect list (used to resolve real
// damage/heal amounts).
//
// NOTE: Value is the spell's BUDGET value (what fighter budget sums via
// getValue()), NOT its damage — a spell's damage lives in its Effects' params.
type Spell struct {
	ID       int32
	BreedID  int32
	Value    int32
	ScriptID int32
	AP       int8
	RangeMin int8
	RangeMax int8
	// Cast-frequency limits (record fields 7-10). Zero = unlimited. Each maps to a
	// distinct bucket of the client's cast-history tracker `sH`, which is what
	// fixes their meanings — they are NOT interchangeable:
	//
	//	field 7  iS() -> sH.akU, keyed (spellId<<32|targetId)  = per-target cap
	//	field 8  iT() -> sH.akV, incremented/decremented       = max ACTIVE at once
	//	field 9  iU() -> sH.akT, reset each turn               = per-turn cap
	//	field 10 iV() -> sH.akS, stores (turn + value)         = COOLDOWN in turns
	CastMaxPerTarget uint8 // field 7: max casts on a single target, per turn
	// MaxActive caps how many instances of this spell may be live at once (the
	// client counts up on cast and down on expiry) — e.g. a summon or a glyph.
	MaxActive      uint8 // field 8
	CastMaxPerTurn uint8 // field 9: max casts per turn
	// Cooldown is the number of table turns before the spell may be recast;
	// 63 means once per fight. This is field 10, NOT field 8 — reading it from
	// field 8 gave every spell the wrong (usually zero) cooldown while treating
	// the max-active cap as a cooldown.
	Cooldown uint8 // field 10
	// CooldownUnlockDelay (field 11) schedules a deferred re-unlock in the client
	// (arm_0.lQ). Decoded for completeness; the server's cooldown check does not
	// need it.
	CooldownUnlockDelay uint8 // field 11
	// Targeting flags (DATA-FORMAT §4 fields 14-16). Labels verified against real
	// data (TestDumpSpellFlagsReal) before they gate casts.
	TestLoS      bool // field 14: cast requires line of sight
	OnlyLine     bool // field 15: cast only in a straight line (same row/col)
	NeedFreeCell bool // field 16: target cell must be empty
	// RangeNotBoostable (field 18) blocks the caster's Range characteristic from
	// extending RangeMax. The client's gate is
	// `if (!(maxRange <= 1 || boost >= 0 && eD())) maxRange += boost`, i.e. the
	// flag suppresses only a POSITIVE boost; a negative one still applies.
	RangeNotBoostable bool // field 18
	// Criterion is the field-20 cast-precondition string: a ';'-separated list of
	// case-insensitive named tokens (implicit AND), e.g.
	// "cantCastWhenCarrying;cantCastWhenCarried". Empty = no gate. See the game
	// package's criteria evaluator.
	Criterion string
	Effects   []Effect
	// EnforceTargetMasks (field 19, eF()) gates TargetMasks: the client only runs
	// the spell-level target check when it is set — just 3 of the 203 spells.
	EnforceTargetMasks bool
	// TargetMasks (field 22) are CAST-level target conditions, distinct from the
	// per-effect Effect.Targets we filter an area with. 202 of 203 spells carry
	// one. They use the client's fuller `aLc` layout, which extends the per-effect
	// bits with state-based conditions (bit 49 intransposable, 50 stabilised,
	// 51 cannot-be-carried, 56 rooted, 57 petrified).
	TargetMasks []int64
	// ParentID (field 23) links a spell variant to its parent. The client's cast
	// tracker `sH` redirects EVERY limit — cooldown, per-turn, per-target — to the
	// parent, so variants share one budget. 5 spells have one (471/472/473 -> 462,
	// 474/475 -> 452).
	ParentID int32
}

// LimitKeyID returns the id a spell's cast limits are tracked under: its parent
// when it has one, else itself. Mirrors `sH`, which starts every limit lookup with
// `if (fv.jd() != null) fv = fv.jd()`.
func (sp *Spell) LimitKeyID() int32 {
	if sp == nil {
		return 0
	}
	if sp.ParentID != 0 {
		return sp.ParentID
	}
	return sp.ID
}

// Spells holds all spell templates by id.
type Spells struct {
	byID map[int32]*Spell
}

// NewSpells builds a catalog from explicit templates (tests/tooling).
func NewSpells(templates ...*Spell) *Spells {
	s := &Spells{byID: make(map[int32]*Spell, len(templates))}
	for _, t := range templates {
		if t != nil {
			s.byID[t.ID] = t
		}
	}
	return s
}

// Get returns a spell by id, or nil.
func (s *Spells) Get(id int32) *Spell { return s.byID[id] }

// Len reports how many spells were loaded.
func (s *Spells) Len() int { return len(s.byID) }

// All returns every loaded spell template, keyed by id.
func (s *Spells) All() map[int32]*Spell { return s.byID }

// AnyEffectIDWithParamCountOtherThan returns the id of some effect whose
// parameter count differs from n, plus whether one was found. Results are stable
// across calls (the lowest such id wins), so the same value is sent every time.
//
// This exists for the sudden-death MapDestruction script (see game/suddendeath.go):
// the client resolves part-0's genericEffectId to obtain the script's parameters,
// and no shipped effect carries that script's action, so the server sends a real,
// resolvable effect whose parameter count is deliberately NOT the one the script
// expects. The client then logs a parameter-count mismatch and falls back to its
// own defaults — a deterministic, documented path. An unresolvable id instead
// leaves the client's parameter holder null and crashes its init.
func (s *Spells) AnyEffectIDWithParamCountOtherThan(n int) (int32, bool) {
	best := int32(0)
	found := false
	for _, sp := range s.byID {
		for _, ef := range sp.Effects {
			if len(ef.Params) == n || ef.EffectID <= 0 {
				continue
			}
			if !found || ef.EffectID < best {
				best, found = ef.EffectID, true
			}
		}
	}
	return best, found
}

// Damage returns the spell's direct flat HP damage (the sum of its flat HP-loss
// effect params) and the element of the last such effect. ok is false for a
// utility spell (shields, buffs, heals) that removes no HP — those correctly
// deal 0 damage. This reads the REAL per-effect magnitude, unlike the spell's
// budget Value.
func (sp *Spell) Damage() (amount int32, elem Element, ok bool) {
	for _, ef := range sp.Effects {
		e, isDmg := isFlatDamage(ef.ActionID)
		if !isDmg || len(ef.Params) == 0 {
			continue
		}
		amount += int32(ef.Params[0])
		elem = e
		ok = true
	}
	return
}

// PrimaryDamage returns the spell's total flat HP damage plus the running-effect
// ActionID and generic EffectID of the PRIMARY (first) flat-damage effect. The
// ActionID is the mh_2 running-effect id (1-5 direct / 130-134 "par sort") the
// client must receive to render the damage number + "perd X PV" chat line; the
// EffectID is the generic-effect id the client's part-0 blob carries. ok is
// false for a utility spell that removes no HP (it deals 0 and shows nothing).
// (Multi-element damage spells are summed under the primary effect's id for now;
// per-effect broadcasting is a later refinement.)
func (sp *Spell) PrimaryDamage() (amount, actionID, effectID int32, ok bool) {
	for _, ef := range sp.Effects {
		_, isDmg := isFlatDamage(ef.ActionID)
		if !isDmg || len(ef.Params) == 0 {
			continue
		}
		amount += int32(ef.Params[0])
		if !ok {
			actionID = ef.ActionID
			effectID = ef.EffectID
			ok = true
		}
	}
	return
}

// IsHeal reports whether the spell has a heal (Soin) effect.
func (sp *Spell) IsHeal() bool {
	for _, ef := range sp.Effects {
		if ef.ActionID == actionHeal {
			return true
		}
	}
	return false
}

// EffectiveCooldown is the number of turns before this spell may be recast.
//
// SECURITY: the client has TWO recast brakes and the server only modelled one.
// Field 10 (Cooldown, iV()) is the plain cooldown; field 11
// (CooldownUnlockDelay, et()) arms a deferred per-fighter LOCK that
// mv_1.java:454-468 refuses to cast through. For a spell where et() > 0 but
// Cooldown == 0 the lock is the client's ONLY brake, and the server had none.
//
// Measured against shipped data rather than assumed: 25 spells carry et() > 0,
// and exactly two rely on it alone - 408 (breed 12) and 476 (breed 14). 476 has
// no other limit whatsoever (Cooldown 0, CastMaxPerTurn 0, CastMaxPerTarget 0) at
// 2 AP and range 1-2, so with 6 AP it was castable three times in a turn where
// retail allows one.
//
// Taking the max is the faithful reading: both mechanisms express "not again for
// N turns", and where both are set the tighter one already governs on the client.
func (s *Spell) EffectiveCooldown() uint8 {
	if s == nil {
		return 0
	}
	if s.CooldownUnlockDelay > s.Cooldown {
		return s.CooldownUnlockDelay
	}
	return s.Cooldown
}
