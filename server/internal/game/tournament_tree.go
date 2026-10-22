package game

import (
	"time"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// The tournament bracket (28649 request / 28650 reply).
//
// The client models the bracket as a 1-INDEXED BINARY HEAP and slices it into
// rounds by slot range (`ah_1.getFieldValue`):
//
//	slot 1      winner
//	slots 2-3   finale
//	slots 4-7   semiFinale
//	slots 8-15  quarterFinal
//	slots 16-31 firstRound
//
// so a full tree is 16 first-round entrants and 31 slots, and the winner of
// slots 2i / 2i+1 occupies slot i. Nothing about that is negotiable - the ranges
// are hard-coded in the client - which is why the bracket is built to fit it
// rather than the other way round.
//
// Names are UTF-8 here (`new String(byArray2, "UTF-8")`), NOT the windows-1252
// the rest of this protocol uses (B-068). Sending cp1252 would mangle any
// accented coach name in the bracket only.
const (
	// bracketWinnerSlot is the root: the tournament winner.
	bracketWinnerSlot = 1
	// bracketFirstRoundSlot is where the entrants go.
	bracketFirstRoundSlot = 16
	// bracketSlots is one past the last first-round slot.
	bracketSlots = 32
	// bracketEntrants is how many first-round names the client can render.
	bracketEntrants = bracketSlots - bracketFirstRoundSlot
)

// firstRoundRange returns the span of first-round slots sitting under slot.
//
// In a binary heap a slot's descendants are a contiguous run at every level, so
// scaling the slot down to the first round gives its leaves directly: slot 5
// covers 20..23, slot 1 covers the whole draw, and a first-round slot covers
// only itself.
func firstRoundRange(slot int32) (int32, int32) {
	lo, hi := slot, slot
	for lo < bracketFirstRoundSlot {
		lo *= 2
		hi = hi*2 + 1
	}
	return lo, hi
}

// applyByes walks unopposed coaches up the tree.
//
// A tournament rarely fills all 16 first-round places, and the client's bracket
// has no notion of a short draw - so without this a coach whose half of the tree
// was never seeded runs out of opponents and the winner slot is never filled
// (B-122).
//
// The test for "unopposed" is deliberately NOT "the sibling slot is empty right
// now", which would walk a coach past an opponent who simply has not finished
// its own match yet. It is "the sibling's entire subtree holds no entrant" -
// nobody can ever arrive there - which is decidable from the seeding alone and
// so gives the same answer no matter when it is asked.
//
// Slots are visited deepest-first so a bye can cascade: a coach alone in its
// quarter of the draw rides up several rounds in one pass.
func applyByes(out map[int32]uint, seeded map[int32]bool) {
	for slot := int32(bracketSlots) - 1; slot >= 2; slot-- {
		coachID, ok := out[slot]
		if !ok {
			continue
		}
		parent := slot / 2
		if _, taken := out[parent]; taken {
			continue // already decided by a real result
		}
		lo, hi := firstRoundRange(slot ^ 1)
		opposed := false
		for s := lo; s <= hi; s++ {
			if seeded[s] {
				opposed = true
				break
			}
		}
		if !opposed {
			out[parent] = coachID
		}
	}
}

// bracket is a sparse slot -> display name map.
type bracket map[int32]string

// buildBracket seeds entrants into the first round in the given order, with
// the upper slots empty: the shape of a draw before any fixture is decided.
// The live tree comes from TournamentManager.BracketSlots; this is the
// first-round-only helper the encoder tests use.
func buildBracket(names []string) bracket {
	b := make(bracket, len(names))
	for i, name := range names {
		if i >= bracketEntrants {
			break // the client has nowhere to draw a 17th entrant
		}
		b[int32(bracketFirstRoundSlot+i)] = name
	}
	return b
}

// encodeTournamentTree builds TOURNAMENT_TREE (28650, client IL):
//
//	[i32 page][i32 count]{[i32 slot][i32 nameLen][utf8 name]}[i32 unread]
//
// `page` is echoed from the request: the client stores it (`ah_1.eE`) and sends
// it back incremented or decremented when the player uses the tree's paging
// buttons (20069), so returning anything else would make those buttons jump.
func encodeTournamentTree(page int32, b bracket) ([]byte, error) {
	w := protocol.NewWriter().I32(page).I32(int32(len(b)))
	// Ascending slot order: the client keys them into a map, so the order does
	// not matter to it - but a stable one keeps the bytes diffable.
	for slot := int32(0); slot < bracketSlots; slot++ {
		name, ok := b[slot]
		if !ok {
			continue
		}
		raw := []byte(name) // UTF-8, deliberately not protocol.EncodeText
		w.I32(slot).I32(int32(len(raw))).Raw(raw)
	}
	w.I32(0) // read unconditionally by IL.a, never consulted by ajp_0
	return protocol.EncodeS2C(protocol.OpTournamentTree, w.Bytes())
}

// handleTournamentTreeRequest handles TOURNAMENT_TREE_REQ (28649, client alf_0):
// [i64 tournamentId][i32 page][i32 nameLen][utf8 highlightName].
//
// The name is the coach the client wants highlighted in the tree (it seeds it
// with its own name and lets the player type another). It is presentational and
// the server does not need it, but it is parsed rather than skipped so a short
// payload is rejected instead of silently yielding a garbage tournament id.
func handleTournamentTreeRequest(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	tid, page := int64(0), int32(0)
	if len(f.Payload) > 0 {
		r := protocol.NewReader(f.Payload)
		v, err := r.I64()
		if err != nil {
			return err
		}
		tid = v
		if p, err := r.I32(); err == nil {
			page = p
		}
	}

	// SECURITY: only an ENTRANT may read a bracket.
	//
	// tid came off the wire with no registration check, so any coach could read
	// any tournament's full entrant list - and each request costs one
	// Coaches.Get per occupied slot (up to 31 queries) for an arbitrary id, which
	// is why this is also the cheapest DB-amplification handler in the family.
	// The sibling opcode 28611 already checks; this one did not.
	//
	// The names are already public via the ladder, so the refusal is silent: an
	// empty bracket is what the client shows for a tournament it is not in.
	if tid != 0 && s.deps.Tournaments != nil &&
		!s.deps.Tournaments.IsRegistered(s.Coach.ID, tid) {
		s.log.Debug("bracket request refused: not an entrant",
			"coach", s.Coach.ID, "tournament", tid)
		frame, err := encodeTournamentTree(page, bracket{})
		if err != nil {
			return err
		}
		return s.Send(frame)
	}

	// The whole current bracket, not just the entrants: first-round seats PLUS
	// everyone who has won through above them.
	b := bracket{}
	if s.deps.Tournaments != nil {
		for slot, coachID := range s.deps.Tournaments.BracketSlots(tid) {
			b[slot] = s.deps.coachDisplayName(coachID)
		}
	}

	frame, err := encodeTournamentTree(page, b)
	if err != nil {
		return err
	}
	s.log.Debug("tournament tree", "coach", s.Coach.Name,
		"tournament", tid, "page", page, "occupied", len(b))
	return s.Send(frame)
}

// buildTournamentSearchPeriod builds TOURNAMENT_SEARCH_PERIOD (28630, dg_0):
// [i64 tid][i8 open].
func buildTournamentSearchPeriod(tid int64, open bool) ([]byte, error) {
	w := protocol.NewWriter().I64(tid)
	if open {
		w.U8(1)
	} else {
		w.U8(0)
	}
	return protocol.EncodeS2C(protocol.OpTournamentSearchPeriod, w.Bytes())
}

// announceTournamentSearchPeriods tells a coach which of its tournaments are
// currently accepting opponent searches.
//
// This is what makes the Tournois tab usable at all. The notification it creates
// (`td_0`) is the ONLY thing that selects a tournament: clicking it runs
// `agz_1`, which sets `vk_1.ad(tid)` and opens the team panel on the right tab.
// Until then `hu_2` refuses "Combattre" with "error.noTournamentSelected",
// however valid the team is - a gate no amount of server-side testing reveals,
// found by driving the real client.
//
// ORDERING IS LOAD-BEARING: this must follow the tournament LIST (28602), never
// precede it. `zN` builds the notification with
//
//	vg vg2 = vk_1.BZ().aQ(tid);   // the client's own tournament registry
//	new td_0(vg2.BC());           // its name
//
// and that registry is filled by 28602. Announced at world entry - before the
// client has ever asked for the list - the lookup returns null, `vg2.BC()`
// throws, the frame loop swallows it, and no notification appears. That is
// exactly what happened: the message went out, the log said so, and the Tournois
// panel stayed empty.
//
// Sent only for tournaments the coach is REGISTERED for: a notification for one
// it cannot enter would select a tournament whose search must then be refused.
// The client de-duplicates 28630 by tid, so re-requesting the list re-announces
// harmlessly.
//
// A scheduled edition is announced only while a search period is OPEN; ahead
// of one it gets the 28644 countdown instead. 28646 (the period opens now) is
// the scheduler's, sent once at the moment of opening (tournament_schedule.go).
// An unscheduled tournament keeps the old always-open alert.
func (s *Session) announceTournamentSearchPeriods() {
	if s.Coach == nil || s.deps == nil || s.deps.Tournaments == nil || s.deps.Store == nil {
		return
	}
	ts, err := s.deps.Store.Tournaments.ListEnabled()
	if err != nil {
		return
	}
	now := s.deps.tournamentNow()
	for i := range ts {
		t := &ts[i]
		tid := t.WireID()
		if !s.deps.Tournaments.IsRegistered(s.Coach.ID, tid) {
			continue
		}
		if t.Scheduled() && !t.SearchPeriodOpenAt(now) {
			s.announceUpcomingSearchPeriod(t, now)
			continue
		}
		frame, err := buildTournamentSearchPeriod(tid, true)
		if err != nil {
			continue
		}
		if err := s.Send(frame); err == nil {
			s.log.Debug("tournament search period announced",
				"coach", s.Coach.Name, "tournament", tid)
		}
	}
}

// announceUpcomingSearchPeriod sends 28644 when a search period is still
// ahead, so the entrant sees a countdown to it, once per period per session.
//
// Deliberately NOT sent once the window has opened or passed: `zN` computes the
// remaining minutes as 1 + (start - now)/60000, so a start in the past produces a
// negative countdown rather than nothing.
func (s *Session) announceUpcomingSearchPeriod(t *domain.Tournament, now time.Time) {
	start := t.NextPeriodStartAt(now)
	if start.IsZero() {
		return
	}
	if s.tournamentCountdowns[t.WireID()] == start.UnixMilli() {
		return
	}
	w := protocol.NewWriter().I64(t.WireID()).I64(start.UnixMilli())
	frame, err := protocol.EncodeS2C(protocol.OpTournamentSearchUpcoming, w.Bytes())
	if err != nil {
		return
	}
	if err := s.Send(frame); err == nil {
		if s.tournamentCountdowns == nil {
			s.tournamentCountdowns = map[int64]int64{}
		}
		s.tournamentCountdowns[t.WireID()] = start.UnixMilli()
		s.log.Debug("tournament search period upcoming",
			"coach", s.Coach.Name, "tournament", t.WireID(), "start", start)
	}
}

// coachDisplayName resolves a coach id to the name shown in the bracket.
func (d *Deps) coachDisplayName(coachID uint) string {
	if d.Store != nil {
		if c, err := d.Store.Coaches.Get(coachID); err == nil && c != nil && c.Name != "" {
			return c.Name
		}
	}
	return "?"
}
