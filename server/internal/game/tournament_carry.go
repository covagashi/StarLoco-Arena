package game

import (
	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// The carry-over (28618 / 28617, S09).
//
// When a repeating edition runs out of search periods without a winner, the
// entrants still in contention could not finish it through no fault of the
// draw. Retail asks each of them "carry your place to the next tournament of
// the same type?" (`ajp_0` -> `gs_2`, answer 16 = yes). The rule behind the
// question is not in the client; ours is: yes registers the coach in the next
// edition and seeds it ahead of new entrants, so it keeps a place in the
// 16-seat draw however many sign up.

// carryTarget returns the edition a finished one carries into, if it is still
// taking entrants.
func (d *Deps) carryTarget(fromTID int64) *domain.Tournament {
	from, err := d.Store.Tournaments.GetByWireID(fromTID)
	if err != nil || from == nil {
		return nil
	}
	next, err := d.Store.Tournaments.NextEdition(from.ID)
	if err != nil || next == nil || !next.Enabled ||
		!next.RegistrationOpenAt(d.tournamentNow()) {
		return nil
	}
	return next
}

// offerTournamentCarry asks the coach about each unfinished edition it has
// not been asked about yet. Sent after the 28602 list, which fills the
// registry the question is looked up in. Asked once: a "no" sends nothing, so
// asking again would be asking until the player gives in.
func (s *Session) offerTournamentCarry() {
	if s.Coach == nil || s.deps.Store == nil || s.deps.Tournaments == nil {
		return
	}
	pending, err := s.deps.Store.Tournaments.PendingCarryOffers(s.Coach.ID)
	if err != nil {
		return
	}
	for _, reg := range pending {
		next := s.deps.carryTarget(reg.TournamentWireID)
		if next == nil || s.deps.Tournaments.IsRegistered(s.Coach.ID, next.WireID()) {
			continue // nothing to carry into (yet), or already in it
		}
		frame, err := protocol.EncodeS2C(protocol.OpTournamentUnfinished,
			protocol.NewWriter().I64(next.WireID()).Bytes())
		if err != nil {
			continue
		}
		if err := s.Send(frame); err != nil {
			return
		}
		_ = s.deps.Store.Tournaments.MarkCarryOffered(s.Coach.ID, reg.TournamentWireID)
		s.log.Info("tournament carry-over offered", "coach", s.Coach.Name,
			"from", reg.TournamentWireID, "to", next.WireID())
	}
}

// handleTournamentCarryStanding (28617 afg_2: [i64 tid]) is the YES. The id is
// the next edition's; it is honoured only for a coach that was offered the
// carry-over from that edition's predecessor.
func handleTournamentCarryStanding(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil || s.deps.Store == nil || s.deps.Tournaments == nil {
		return nil
	}
	tid, err := protocol.NewReader(f.Payload).I64()
	if err != nil {
		return err
	}
	next, err := s.deps.Store.Tournaments.GetByWireID(tid)
	if err != nil || next == nil || next.PreviousID == 0 {
		return nil
	}
	fromTID := domain.TournamentWireBase + int64(next.PreviousID)
	offered, err := s.deps.Store.Tournaments.OfferedCarry(s.Coach.ID, fromTID)
	if err != nil || !offered {
		s.log.Info("tournament carry-over refused: not offered",
			"coach", s.Coach.Name, "tournament", tid)
		return nil
	}
	if target := s.deps.carryTarget(fromTID); target == nil || target.ID != next.ID {
		s.log.Info("tournament carry-over refused: registration closed",
			"coach", s.Coach.Name, "tournament", tid)
		return nil
	}
	if !s.deps.Tournaments.IsRegistered(s.Coach.ID, tid) {
		s.noteTournamentEntry()
	}
	s.deps.Tournaments.RegisterCarried(s.Coach.ID, tid)
	s.log.Info("tournament carry-over accepted", "coach", s.Coach.Name,
		"from", fromTID, "to", tid)

	// No reply exists for 28617; refresh the list so the row shows the entry.
	ts, err := s.deps.Store.Tournaments.ListEnabled()
	if err != nil {
		return nil
	}
	frame, err := buildTournamentList(s.Coach.ID, s.deps.Tournaments, ts)
	if err != nil {
		return nil
	}
	return s.Send(frame)
}
