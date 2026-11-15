package gamedata

// Summoning is a decoded summon-creature template (record type 300, class jz_2).
// It is the stat sheet the client builds a summoned fighter from (keyed by the
// summon effect's template id) and that the server mirrors so its HP/turn/AI math
// matches.
//
// Wire layout (big-endian), matched field-for-field against jz_2's deserializer:
//
//	i32 id, i32 maxHP, i32 maxAP, i32 maxMP,
//	i8 spellCount, i32×spellCount spellIds, i32 look,
//	6×bool state flags, i32 block%, i32 dodge%, i8 radius,
//	blob list (i8 count + {i32 len, bytes}), i32 particleId
//
// The six flags are not decoration: the client's adT/ta_0 give the spawned
// creature the matching FIGHTER PROPERTY at birth, which is how a wall or a doll
// is immovable. 22 of the 53 shipped summons are Rooted, 21 CannotBeCarried,
// 18 Stabilised and 15 Intransposable.
type Summoning struct {
	ID       int32
	HP       int32
	AP       int32
	MP       int32
	SpellIDs []int32
	Look     int32

	// Innate properties, each mapping to the same client property a spell effect
	// would apply (see game/states.go):
	//   CannotBeCarried  -> avx_0.deA (blocks Carry 58)
	//   Intransposable   -> avx_0.deB (blocks swap 64)
	//   Stabilised       -> avx_0.dev (blocks Push 37 / Pull 38)
	//   Rooted           -> avx_0.dex (MP reads as 0: cannot walk)
	CannotBeCarried bool // field 7  op()
	Intransposable  bool // field 8  oq()
	Stabilised      bool // field 9  or()
	Rooted          bool // field 10 os()
	// DeadFlag (field 11, ov() -> avx_0.deD) is set by the client but never
	// tested anywhere in it; decoded for completeness only.
	DeadFlag bool
	// NoPositionalBonus (field 12, oy() -> avx_0.deF) disables the back/side
	// damage bonus against this creature. 2.70 dropped directional damage, so it
	// is inert here — decoded to keep the field order honest.
	NoPositionalBonus bool

	Block int32 // field 13 ot() -> Lr.brd, tackle/block %
	Dodge int32 // field 14 ou() -> Lr.bre, dodge %
	// Radius (field 15, ox()) is the creature's footprint used by the client for
	// distance and area maths. Only one shipped summon has a non-zero radius.
	Radius     int32
	ParticleID int32 // field 17 oz()
}

// PrimarySpellID returns the creature's first spell id (0 = a spell-less
// blocker), which drives the summon AI's behaviour.
func (s *Summoning) PrimarySpellID() int32 {
	if len(s.SpellIDs) > 0 {
		return s.SpellIDs[0]
	}
	return 0
}

// Summonings holds all summon templates by id.
type Summonings struct {
	byID map[int32]*Summoning
}

// NewSummonings builds a catalog from explicit templates (tests/tooling).
func NewSummonings(templates ...*Summoning) *Summonings {
	out := &Summonings{byID: make(map[int32]*Summoning, len(templates))}
	for _, t := range templates {
		if t != nil {
			out.byID[t.ID] = t
		}
	}
	return out
}

// Get returns a summon template by id, or nil.
func (s *Summonings) Get(id int32) *Summoning { return s.byID[id] }

// Len reports how many templates were loaded.
func (s *Summonings) Len() int { return len(s.byID) }

// All returns every loaded summon template, keyed by id.
func (s *Summonings) All() map[int32]*Summoning { return s.byID }
