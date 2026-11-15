package gamedata

// Challenge definitions (retail client class GE; ours in
// server/content/rules/challenges.json since S43).
//
// A "challenge" is a scripted fight against a server-built opponent, referenced
// by id from two kinds of overworld element:
//
//   - DemonChallenge (env type 7) — field 2 of its ';'-separated descriptor.
//   - BreedMaster (env type 5) — field 4 of its descriptor ("test this breed").
//
// Challenge is a decoded challenge definition.
//
// The fields follow the retail record (big-endian), matched field-for-field
// against the client's GE deserializer (GE.a) when it was decoded:
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
	// The rest of the block the client keeps in its afz_0 (q_0 -> ahy_1.a):
	// ShowsResult is GE.QA, LinkedAchievement GE.QB (afz_0's
	// "achievementLinkedCompleted": the challenge dialog shows whether the
	// coach has that achievement), XP and XPLimit GE.QC / GE.QD (the dialog's
	// "xp" / "xpLimit"). Field15 is GE.QF, which the loader drops.
	ShowsResult       bool
	LinkedAchievement int16
	XP                int32
	XPLimit           int32
	Field15           int32
}

// Challenges holds all challenge definitions by id.
type Challenges struct {
	byID map[int32]*Challenge
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
