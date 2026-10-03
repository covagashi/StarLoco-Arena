package game

import (
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

func registerMatchmakingHandlers(r *Router, d *Deps) {
	r.Register(protocol.OpOpponentSearchRequest, handleOpponentSearch)
	r.Register(protocol.OpOpponentSearchCancel, handleOpponentSearchCancel)
	r.Register(protocol.OpMatchAccept, handleMatchAccept)
	r.Register(protocol.OpMatchAcceptAlt, handleMatchAcceptAlt)
}

// Cancel-result codes carried by OpponentSearchCancelResult (2306).
const (
	searchCancelOK      uint8 = 0 // a search/match was actually cancelled
	searchCancelNothing uint8 = 1 // nothing was queued (idempotent no-op)
)

// handleOpponentSearch (2301 C2S: [i16 mode][i16 subMode][i32 N][i64×N reversed])
// enqueues the coach; on a match, announces MatchFound(23110) to both.
func handleOpponentSearch(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	mode, err := r.U16()
	if err != nil {
		return err
	}
	subMode, err := r.U16()
	if err != nil {
		return err
	}
	teamIDs, err := readReversedIDs(r)
	if err != nil {
		return err
	}

	pm := s.deps.Matchmaker.Search(s, int16(mode), int16(subMode), teamIDs)
	if pm == nil {
		s.log.Info("queued for match", "coach", s.Coach.Name, "mode", mode)
		// Tell the client its search is live so the UI shows the searching state.
		return s.sendSearchInProgress()
	}

	// Matched: announce to both coaches.
	s.log.Info("match found", "a", pm.a.session.Coach.Name, "b", pm.b.session.Coach.Name)
	if err := sendMatchFound(pm.a.session, pm, pm.b); err != nil {
		return err
	}
	return sendMatchFound(pm.b.session, pm, pm.a)
}

// handleOpponentSearchCancel (2303 C2S, empty) cancels a pending search. If the
// coach was queued, it is removed. If it was in a not-yet-accepted match, that
// match is aborted and the opponent is notified. Either way we reply with a
// CancelResult(2306).
func handleOpponentSearchCancel(s *Session, _ *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	if s.deps.Matchmaker.CancelSearch(s.Coach.ID) {
		s.log.Info("search cancelled (was queued)", "coach", s.Coach.Name)
		return s.sendSearchCancelResult(searchCancelOK)
	}
	// Not queued — maybe sitting in a pending (unaccepted) match. Abort it and
	// let the opponent know their match fell through.
	if pm := s.deps.Matchmaker.Remove(s.Coach.ID); pm != nil {
		s.log.Info("search cancelled (pending match aborted)", "coach", s.Coach.Name)
		if other := pm.other(s.Coach.ID); other != nil {
			_ = sendMatchCancelled(other.session)
		}
		return s.sendSearchCancelResult(searchCancelOK)
	}
	// Nothing to cancel — reply idempotently so the client UI resets.
	return s.sendSearchCancelResult(searchCancelNothing)
}

// sendSearchInProgress sends OpponentSearchInProgress(2304): empty payload.
func (s *Session) sendSearchInProgress() error {
	frame, err := protocol.EncodeS2C(protocol.OpOpponentSearchInProgress, nil)
	if err != nil {
		return err
	}
	return s.Send(frame)
}

// sendSearchCancelResult sends OpponentSearchCancelResult(2306): [i8 result].
func (s *Session) sendSearchCancelResult(result uint8) error {
	w := protocol.NewWriter().U8(result)
	frame, err := protocol.EncodeS2C(protocol.OpOpponentSearchCancelResult, w.Bytes())
	if err != nil {
		return err
	}
	return s.Send(frame)
}

// sendMatchFound sends MatchFound(23110) to a coach describing its opponent:
// [i64 matchId][i32 nameLen][name][i32 labelLen][label][i64 oppId][i16 mode]
// [i16 fightType][i32 N][i64×N opponent team ids].
func sendMatchFound(to *Session, pm *pendingMatch, opp *searcher) error {
	oppCoach := opp.session.Coach
	w := protocol.NewWriter().I64(pm.id)
	writeStringI32(w, oppCoach.Name)
	writeStringI32(w, "") // secondary label (team name)
	w.I64(int64(oppCoach.ID)).
		U16(uint16(pm.a.mode)).   // mode
		U16(uint16(pm.a.subMode)) // fightType
	w.I32(int32(len(opp.teamIDs)))
	for _, id := range opp.teamIDs {
		w.I64(id)
	}
	frame, err := protocol.EncodeS2C(protocol.OpMatchFound, w.Bytes())
	if err != nil {
		return err
	}
	return to.Send(frame)
}

// handleMatchAccept (23114 C2S: [i64 matchId][i64 oppId][i16 mode][i16 fightType]
// [i32 N][i64×N reversed roster][i8 accept]).
func handleMatchAccept(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	if _, err := r.I64(); err != nil { // matchId
		return err
	}
	if _, err := r.I64(); err != nil { // oppId
		return err
	}
	if _, err := r.U16(); err != nil { // mode
		return err
	}
	if _, err := r.U16(); err != nil { // fightType
		return err
	}
	if _, err := readReversedIDs(r); err != nil { // roster
		return err
	}
	accept, err := r.U8()
	if err != nil {
		return err
	}
	return s.resolveMatchAccept(accept == 1)
}

// handleMatchAcceptAlt (2308 C2S: [i64 matchId][i16 mode][i32 N][i64×N reversed]
// [i8 accept]) — the bet-carrying accept variant.
func handleMatchAcceptAlt(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	if _, err := r.I64(); err != nil { // matchId
		return err
	}
	if _, err := r.U16(); err != nil { // mode
		return err
	}
	if _, err := readReversedIDs(r); err != nil { // roster
		return err
	}
	accept, err := r.U8()
	if err != nil {
		return err
	}
	return s.resolveMatchAccept(accept == 1)
}

// resolveMatchAccept records the coach's decision. When both accept, the fight is
// created and started (startFight → full CREATE_FIGHT/placement/action flow); a
// decline notifies the other side that the pending match fell through.
func (s *Session) resolveMatchAccept(accept bool) error {
	pm, both := s.deps.Matchmaker.Accept(s.Coach.ID, accept)
	if pm == nil {
		return nil
	}
	if !accept {
		s.log.Info("match declined", "coach", s.Coach.Name)
		// Notify the other side their match fell through.
		if other := pm.other(s.Coach.ID); other != nil {
			_ = sendMatchCancelled(other.session)
		}
		return nil
	}
	if both {
		s.log.Info("both accepted match -> starting fight",
			"a", pm.a.session.Coach.Name, "b", pm.b.session.Coach.Name)
		return s.deps.startFight(pm)
	}
	return nil
}

// sendMatchCancelled tells the still-waiting coach their match fell through:
// MatchResult(23112) [i8 0] closes the avn_0 confirmation dialog client-side and
// toasts "opponentSearchConfirmation.resultIsNo". (This used to emit 23116,
// which gz_1 never registers — the retail decoder dropped it silently.)
func sendMatchCancelled(to *Session) error {
	w := protocol.NewWriter().U8(0)
	frame, err := protocol.EncodeS2C(protocol.OpMatchResult, w.Bytes())
	if err != nil {
		return err
	}
	return to.Send(frame)
}

// readReversedIDs reads [i32 N] then N i64 ids (they were written reversed by
// the client; we keep wire order — callers that need original order can flip).
func readReversedIDs(r *protocol.Reader) ([]int64, error) {
	n, err := r.I32()
	if err != nil {
		return nil, err
	}
	if n < 0 || n > 64 {
		return nil, nil
	}
	ids := make([]int64, 0, n)
	for i := int32(0); i < n; i++ {
		id, err := r.I64()
		if err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, nil
}

// writeStringI32 writes [i32 len][bytes] in the wire charset (see StringU32).
func writeStringI32(w *protocol.Writer, s string) {
	w.StringU32(s)
}
