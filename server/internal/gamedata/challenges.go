package gamedata

// TypeChallengeDef is the data.bdat record type holding challenge definitions
// (client class GE, loaded by q_0 into contentLoader.challenge / ahy_1.axg()).
//
// A "challenge" is a scripted fight against a server-built opponent, referenced
// by id from two kinds of overworld element:
//
//   - DemonChallenge (env type 7) — field 2 of its ';'-separated descriptor.
//   - BreedMaster (env type 5) — field 4 of its descriptor ("test this breed").
//
// Both launch it by sending C2S 26330 [i32 challengeId][i16 99].
const TypeChallengeDef = 400

// Challenge is a decoded challenge definition.
//
// Wire layout (big-endian), matched field-for-field against the client's GE
// deserializer (GE.a) and verified by checking each decoded record's size
// against its byte length (39 records, ids 3..46):
//
//	i32 id, i32×6 fields, u8 rewardCount, i32×rewardCount rewardCardIds,
//	u8 bool(QA), i16(QB), i32(QC), i32(QD), i32(QE), i32(QF),
//	u8 bonusCount, np_1×bonusCount, i32(QG), i32(QH)
//
// The whole record is now read: the bonus list is an `np_1[]` (see
// parameters.go), which was the last unknown here.
//
// IMPORTANT — the client carries NO opponent roster for a challenge. Its own
// loader (ahy_1.a) keeps just the display name (content.30.<id>), description
// (content.31.<id>) and reward metadata, and discards the rest. The fight's
// opponents therefore arrive purely through the normal fight messages, which
// means the SERVER owns team composition and nothing in the client can
// contradict it.
type Challenge struct {
	ID int32
	// Fields are the six i32 that follow the id (GE getters Qt/Qu/Qv/Qw/Qy/Qz).
	// Fields[1] (Qu) IS verified: the NPC-dialog "Lancer un défi" reply action
	// (client th_0) sends it as the i16 second field of 26330 — i.e. the
	// challenge launch carries [challengeId][Fields[1]], not the breedmaster's
	// literal 99. The remaining fields' semantics are NOT verified — observed
	// shapes, for whoever decodes them next:
	//
	//	breed-master challenges 17..28: [45, 33..44, 36, 0, 5, 0]  (field0 constant,
	//	                                 field1 twelve consecutive values)
	//	minute demons 32..36:           [47..51, 62|64, 38..42, 0, 5|1|6, 0]
	//	challenge 45 (world 23):        [60, 0, 76, 542, 1, 0]
	//
	// field5 is 0 in every record.
	Fields [6]int32
	// Bonuses is the trailing `np_1[]` gameplay-parameter list (field 16).
	Bonuses []Parameter
	// Unknown1/Unknown2 are the two trailing i32 (GE getters QG/QH). Decoded so
	// the record round-trips; their meaning is not established.
	Unknown1 int32
	Unknown2 int32
	// RewardCards are CoachCard template ids (verified: every value resolves in
	// the type-100 card table, e.g. challenge 32 -> 187,189,194). Not all
	// challenges award cards — 17..28 and several demons have none.
	RewardCards []int32
	// TimeChallenge is GE.QE() (field bbI). The client's end-of-fight builder
	// (WE, case 8300) gates its "time challenge" reward/XP panel on QE() > 0.
	//
	// Verified against the real table: it is non-zero ONLY for the contiguous
	// block of challenges 37..44, and 0 for every challenge any overworld element
	// actually references — every breed master (17..28), every minute demon
	// (32/34/35/36) and world 23's Barnaby demon (45). So despite the "Nth minute"
	// names, no reachable challenge is a timed one, and there is nothing here for
	// the server to enforce. 37..44 are not spawned by any element, and even if
	// they were, the panel is client-owned (the client loads type-400 itself), so
	// the server's only obligation is the one it already meets: tag the fight
	// kind 5 with the challenge id so the client can find this record. See
	// docs/OVERWORLD-MAP.md.
	TimeChallenge int32
}

// Challenges holds all challenge definitions by id.
type Challenges struct {
	byID map[int32]*Challenge
}

// LoadChallenges reads and decodes every challenge definition (type 400).
func (s *Store) LoadChallenges() (*Challenges, error) {
	out := &Challenges{byID: make(map[int32]*Challenge)}
	for _, e := range s.EntriesOf(TypeChallengeDef) {
		rec, err := s.ReadRecord(e.Position)
		if err != nil {
			return nil, err
		}
		if ch := decodeChallenge(rec.Data); ch != nil {
			out.byID[ch.ID] = ch
		}
	}
	return out, nil
}

// NewChallenges builds a catalog from explicit definitions (tests/tooling).
func NewChallenges(defs ...*Challenge) *Challenges {
	out := &Challenges{byID: make(map[int32]*Challenge, len(defs))}
	for _, d := range defs {
		if d != nil {
			out.byID[d.ID] = d
		}
	}
	return out
}

// Get returns the definition for id, or nil if the table has no such challenge.
func (c *Challenges) Get(id int32) *Challenge {
	if c == nil {
		return nil
	}
	return c.byID[id]
}

// Len is the number of decoded challenges.
func (c *Challenges) Len() int {
	if c == nil {
		return 0
	}
	return len(c.byID)
}

// All exposes the whole table (read-only use).
func (c *Challenges) All() map[int32]*Challenge {
	if c == nil {
		return nil
	}
	return c.byID
}

func decodeChallenge(data []byte) *Challenge {
	return decodeChallengeCursor(&cur{b: data})
}

// decodeChallengeCursor is decodeChallenge over a caller-owned cursor so a test
// can assert the record is consumed exactly (zero bytes left over).
func decodeChallengeCursor(c *cur) *Challenge {
	id := c.i32()
	ch := &Challenge{ID: id}
	for i := range ch.Fields {
		ch.Fields[i] = c.i32()
	}
	n := int(c.u8())
	for i := 0; i < n; i++ {
		if v := c.i32(); c.ok() {
			ch.RewardCards = append(ch.RewardCards, v)
		}
	}
	if !c.ok() || id <= 0 {
		return nil
	}
	// Tail, best-effort: read through to QE (the client's time-panel gate). A
	// record that somehow ends early leaves TimeChallenge at its zero value —
	// which is exactly "no time challenge" — rather than dropping the whole
	// definition, so the core decode above stays authoritative.
	c.u8()        // QA bool
	c.i16()       // QB
	c.i32()       // QC
	c.i32()       // QD
	qe := c.i32() // QE — GE.bbI
	if c.ok() {
		ch.TimeChallenge = qe
	}
	c.i32() // QF

	// The tail used to stop here because the np_1 element layout was unknown.
	// It is decodable now (see parameters.go), so the record is read to its end.
	bonuses, ok := decodeParameters(c)
	if !ok {
		return ch // an inline effect we cannot skip; keep what we have
	}
	ch.Bonuses = bonuses
	ch.Unknown1 = c.i32() // QG
	ch.Unknown2 = c.i32() // QH
	return ch
}
