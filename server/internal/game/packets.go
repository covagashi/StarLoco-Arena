package game

import (
	"math"
	"time"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/handshake"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

func nowNanos() int64 { return time.Now().UnixNano() }

// buildCoachInformation builds CoachInformations (2052) from a persisted coach.
//
// guild may be nil (no clan), which reproduces byte-for-byte what this message
// carried before guilds existed.
func buildCoachInformation(c *domain.Coach, tome []int32, guild *handshake.GuildMembership) ([]byte, error) {
	return handshake.EncodeCoachInformations(handshake.Coach{
		ID:        int64(c.ID),
		Name:      c.Name,
		HairColor: c.Hair,
		SkinColor: c.Skin,
		Sex:       c.Sex,
		Standing:  c.Standing,
		Strength:  c.Strength,
		// Statistic 183 is that running total; no second copy is kept.
		TournamentPoints: coachStat(c, statTournamentPoints),
		Criteria:         coachCriteria(c),
		Tome:             tome,
		Guild:            guild,
	})
}

// coachCriteria converts a coach's persisted stats into the criteria the 2052
// descriptor carries. This is the ONLY path by which criteria reach the client,
// so a criterion missing here is invisible to it however faithfully it was
// stored.
//
// Filters:
//   - ids above handshake.MaxCriterionID are the server's own bookkeeping (e.g.
//     per-challenge completion flags), not client criteria — never send them;
//   - non-positive values are dropped (absent keys already read as 0 client-side);
//   - values are clamped into uint16, because the client reads each as a signed
//     i16 and a wrapped negative would silently FAIL every `>=` gate it feeds.
func coachCriteria(c *domain.Coach) []handshake.Criterion {
	out := make([]handshake.Criterion, 0, len(c.Stats))
	for _, st := range c.Stats {
		if st.StatID <= 0 || uint16(st.StatID) > handshake.MaxCriterionID {
			continue
		}
		if st.Value <= 0 {
			continue
		}
		v := st.Value
		if v > math.MaxInt16 {
			v = math.MaxInt16
		}
		out = append(out, handshake.Criterion{ID: uint16(st.StatID), Value: uint16(v)})
	}
	return out
}

// buildPlayerStatisticsReport builds PlayerStatisticsReport (2400).
//
// Payload: [u16 blobLen][blob], where blob = statistics field-map:
//
//	[i16 modelId=1][i64 reportId=1][i16 entryCount]
//	entryCount × { i16 fieldId, u8 typeCode, value }   (typeCode 1=i32, 2=i64, 3=f32)
//
// The field ids are those the client's PlayerStatisticsReport reads (verified
// vs the decompiled class):
//
//	1 = total play time  (dM, long)   2 = time in fight (dL, long)
//	3 = total fights     (dI, int)    4 = fights won    (dJ, int)
//	5 = fights lost      (dK, int)    7 = consec. wins  (dP, int)
//	8 = consec. losses   (dO, int)
//
// Field 6 is an internal model value (dN), NOT the ladder strength — strength
// is carried elsewhere (the coach "strenght" field), so we do not emit it here.
func playerStatisticsBlob(c *domain.Coach) ([]byte, error) {
	blob := protocol.NewWriter()
	blob.U16(1) // model id
	blob.I64(1) // report id
	blob.U16(7) // entry count

	longEntry := func(id uint16, v int64) { blob.U16(id).U8(2).I64(v) }
	intEntry := func(id uint16, v int32) { blob.U16(id).U8(1).I32(v) }

	longEntry(1, c.TotalPlaySecs)    // dM: total play time (s)
	longEntry(2, c.TimeInFightSecs)  // dL: time in fight (s)
	intEntry(3, c.StatFights)        // dI: total fights
	intEntry(4, c.StatWins)          // dJ: total wins
	intEntry(5, c.StatLosses)        // dK: total losses
	intEntry(7, c.ConsecutiveWins)   // dP: consecutive wins
	intEntry(8, c.ConsecutiveLosses) // dO: consecutive losses

	return blob.Bytes(), nil
}

// buildPlayerStatisticsReport wraps the blob in its own message (2053). The blob
// is split out so the guild member-stats popup (2601) can carry the same numbers
// without the two drifting apart.
func buildPlayerStatisticsReport(c *domain.Coach) ([]byte, error) {
	b, err := playerStatisticsBlob(c)
	if err != nil {
		return nil, err
	}
	payload := protocol.NewWriter().U16(uint16(len(b)))
	payload.Raw(b)
	return protocol.EncodeS2C(protocol.OpPlayerStatisticsReport, payload.Bytes())
}

// buildFriendList builds FriendList (3144).
//
// Payload: [u8 count] then per friend { i16 elemLen, blob }, blob = the client's
// `qm.b` layout:
//
//	[u8 len][name][u8 len][adM][u8 len][adN][i8 adO][i64 adP][i16 adQ][i8 adR][i16 adS]
//
// The last two fields are NOT what an earlier revision of this function assumed
// ("[i8 online][i64 lastSeen]"), and getting them wrong broke more than cosmetics.
// `om_0` case 3144 constructs each entry as:
//
//	new axa_0(qm.adM, qm.name, qm.adP != -1L, qm.adP, qm.adO)
//
// so **adP is the friend's COACH ID, and it doubles as the online flag: -1 means
// offline**. adO is the per-friend NOTIFY toggle (`axa_0.aJM()` gates the
// "X vient de se connecter" toast), not presence.
//
// Writing the online bool into adO and a constant 0 into adP therefore gave every
// friend the id 0 AND made them all read as online (0 != -1). The id matters
// because the client hands it straight back: the 2v2 teammate picker sends
// `axa_0.getId()` as the invited coach in 6024, so a whole feature refused with
// "Le coach a refuse la creation, ou est indisponible." until this was fixed.
//
// CRITICAL: the count MUST equal the number of blobs actually written. Rows
// with a nil joined coach (e.g. a friend whose account was deleted) are skipped,
// so we count the filtered set first — otherwise the client's fixed-count loop
// reads past the buffer (BufferUnderflowException) and the login chain aborts.
func buildFriendList(c *domain.Coach, world *Registry) ([]byte, error) {
	friends := make([]domain.CoachFriend, 0, len(c.Friends))
	for _, fr := range c.Friends {
		if fr.Friend != nil {
			friends = append(friends, fr)
		}
	}
	w := protocol.NewWriter().U8(uint8(len(friends)))
	for _, row := range friends {
		fr := row.Friend
		blob := protocol.NewWriter().
			StringU8(fr.Name).
			StringU8(""). // adM (character name; the client falls back to name)
			StringU8("")  // adN
		notify := uint8(0)
		if row.Notify {
			notify = 1
		}
		// Offline friends are sent as -1: that is the client's own presence test,
		// and it means an offline friend deliberately has no usable id.
		id := int64(-1)
		if world.IsOnline(fr.ID) {
			id = int64(fr.ID)
		}
		blob.U8(notify). // adO: notify-on-login toggle
					I64(id). // adP: coach id, or -1 when offline
					U16(0).  // adQ
					U8(0).   // adR
					U16(0)   // adS
		b := blob.Bytes()
		w.U16(uint16(len(b)))
		w.Raw(b)
	}
	return protocol.EncodeS2C(protocol.OpFriendList, w.Bytes())
}

// buildIgnoreList builds IgnoreList (3146): [i8 count] then { u8 nameLen, name }.
//
// CRITICAL: count MUST equal the number of names written (skip nil joins first),
// or the client reads past the buffer. See buildFriendList.
func buildIgnoreList(c *domain.Coach) ([]byte, error) {
	names := make([]string, 0, len(c.Ignored))
	for _, ig := range c.Ignored {
		if ig.Ignored != nil {
			names = append(names, ig.Ignored.Name)
		}
	}
	w := protocol.NewWriter().U8(uint8(len(names)))
	for _, name := range names {
		w.StringU8(name)
	}
	return protocol.EncodeS2C(protocol.OpIgnoreList, w.Bytes())
}

// buildActorSpawn builds ActorSpawn (4096): an uncompressed actor list.
//
// Payload (uncompressed form): [i32 wrapPrefix = bodyLen][body] where body =
// [i32 count] then per actor [i8 type=1 (coach)] + coach record.
//
// The 4096 body is normally zlib-wrapped: a positive i32 prefix = inflated
// length + zlib data; a NEGATIVE prefix = -rawLen + raw stored bytes. We use
// the negative (stored, uncompressed) form so no compression is needed.
func buildActorSpawn(views []CoachView) ([]byte, error) {
	body := protocol.NewWriter()
	body.I32(int32(len(views)))
	for _, v := range views {
		body.U8(1) // actorType 1 = Coach
		writeCoachActor(body, v)
	}
	b := body.Bytes()

	out := protocol.NewWriter()
	out.I32(int32(-len(b))) // negative => raw stored (uncompressed) bytes follow
	out.Raw(b)
	return protocol.EncodeS2C(protocol.OpActorSpawn, out.Bytes())
}

// writeCoachActor serializes a coach entry inside ActorSpawn (4096).
//
// The client reads a coach actor via aez_0.b(bb, flags) with flags = 3179
// (0x0C6B) — the exact value xe_2 passes for a type-1 (Coach) actor. The
// sub-readers run in aez_0's SOURCE order (NOT numeric flag order), so the wire
// layout for flags 3179 is exactly:
//
//	V (always):  i64 id, u8 nameLen + name
//	U (0x1):     i32 x, i32 y, i16 z, u8 orientation
//	T (always):  u8 hair, u8 skin, u8 sex, i16 lookUF
//	bMU (0x400): i32
//	dBg (0x40):  u8
//	W (0x20):    i16 guildLen (=0)
//	S (0x2):     i16 descriptorLen (=0)
//	X (0x8):     u8 strengthPairCount (=0)
//	Y (0x800):   i32 adminRight
//
// Emitting fewer bytes makes aez_0.b throw BufferUnderflowException, the actor
// is dropped ("pas assez de données ... Coach"), and other coaches never spawn.
func writeCoachActor(w *protocol.Writer, v CoachView) {
	// V (always): id + name
	w.I64(int64(v.ID))
	w.StringU8(v.Name)

	// U (0x1): position + orientation
	w.I32(v.PosX)
	w.I32(v.PosY)
	w.U16(uint16(v.PosZ)) // i16 z
	w.U8(0)               // orientation / direction

	// T (always): look — SKIN then HAIR then sex (client T reader order).
	w.U8(v.Skin)
	w.U8(v.Hair)
	w.U8(v.Sex)
	w.U16(0) // UF look short

	// bMU (0x400): standing — the coach's evolution experience, which the client
	// turns into the evolution level it renders (aet_0.nJ / StandingToLevel).
	w.I32(v.Standing)
	// dBg (0x40): the sit flag. no_2.g plays AnimAssis-Debut when an actor
	// spawns with this set, so a coach that sat down before you arrived is
	// already sitting when it appears in your view.
	w.U8(boolByte(v.Sitting))
	// W (0x20): guild blob (empty)
	w.U16(0)
	// S (0x2): descriptor/linkage blob (empty)
	w.U16(0)
	// X (0x8): strength-pair count = 0
	w.U8(0)
	// Y (0x800): adminRight
	w.I32(0)
}

// buildActorDespawn builds ActorDespawn (4098): [i32 count] then i64 ids.
func buildActorDespawn(ids []uint) ([]byte, error) {
	w := protocol.NewWriter().I32(int32(len(ids)))
	for _, id := range ids {
		w.I64(int64(id))
	}
	return protocol.EncodeS2C(protocol.OpActorDespawn, w.Bytes())
}

// coachStat is one of a coach's persisted statistics (0 when absent).
func coachStat(c *domain.Coach, id int16) int32 {
	for _, st := range c.Stats {
		if st.StatID == id {
			return st.Value
		}
	}
	return 0
}
