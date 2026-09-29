package game

import (
	"time"

	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store"
)

// Demon totems and tournament totems.
//
// Both elements open NO UI when clicked: the click only fires a request, and the
// dialog is opened purely by the server's reply. Without an answer the totem is a
// completely inert click Ã¢â‚¬â€ it looks broken, though it cannot hang the client.
//
// The demon ladder is answered with a well-formed EMPTY window (no guild/clan
// reputation is modelled). The tournament totem now serves real data: see
// tournaments.go for the calendar (17003) / list (28602) builders and the standing
// tournament catalogue. Registration (4607 -> 28608) and the bracket request
// (28649 -> empty 28650) are handled below; the live-match layer stays deferred.
//
// Every decoder here reads its trailing fields unconditionally and has no length
// guards, so the byte counts must be exact Ã¢â‚¬â€ a short buffer is silently dropped
// inside the client's frame decoder and the dialog never opens.

func registerTotemHandlers(r *Router, d *Deps) {
	r.Register(protocol.OpDemonLadderRequest, handleDemonLadderRequest)
	r.Register(protocol.OpTournamentCalReq, handleTournamentCalendarRequest)
	r.Register(protocol.OpTournamentListReq, handleTournamentListRequest)
	r.Register(protocol.OpTournamentRegister, handleTournamentRegister)
	r.Register(protocol.OpTournamentTreeReq, handleTournamentTreeRequest)
	r.Register(protocol.OpTournamentSearchRequest, handleTournamentSearchRequest)
	r.Register(protocol.OpTournamentSearchCancel, handleTournamentSearchCancel)
}

// handleDemonLadderRequest handles DEMON_LADDER_REQUEST (27510):
// [i16 demonId][i16 flag][i32 startRank] Ã¢â‚¬â€ the per-demon drill-down, sent both by
// a DemonTotem click and by selecting a row in the ranking window's DÃƒÂ©mon tab.
// Replies with an empty ranking for that demon (no guild reputation modelled).
func handleDemonLadderRequest(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	demonID, err := r.U16()
	if err != nil {
		return err
	}
	frame, err := buildDemonLadder(demonID, s.deps.demonLadderRows(int16(demonID)), s.deps.viewerDemon(s.Coach.ID))
	if err != nil {
		return err
	}
	s.log.Debug("demon ladder", "coach", s.Coach.Name, "demon", demonID)
	return s.Send(frame)
}

// buildDemonLadder builds DEMON_LADDER (27511 anc_0) Ã¢â‚¬â€ guilds ranked by
// reputation on one demon:
//
//	[i16 demonId][i16 statusFlag][i32 startRank][i32 count]
//	count Ãƒâ€” { [i32 nameLen][guildName][i64 quarterly][i64 quarterlyCumul][i64 monthly] }
//	[i64 demonAffiliation]   <- PER-MESSAGE, not per-row
//
// The trailing i64 is read unconditionally, so it must be present even with zero
// rows Ã¢â‚¬â€ omitting it throws inside the client's decoder and the dialog never
// opens. statusFlag MUST be 1 for the client (awj) to (re)fill its rows. Guild
// reputation is not modelled, so this is always an empty (count 0) window.
func buildDemonLadder(demonID uint16, rows []store.DemonReputationRow, viewerDemon int16) ([]byte, error) {
	const statusPopulate uint16 = 1
	w := protocol.NewWriter().
		U16(demonID).
		U16(statusPopulate).
		I32(0). // startRank
		I32(int32(len(rows)))
	for _, e := range rows {
		writeLadderString(w, e.Name)
		w.I64(e.Points) // quarterly reputation
		w.I64(0)        // differential quarterly (not tracked)
		w.I64(e.Points) // monthly reputation
	}
	// Trailing per-message field: the VIEWER's own clan affiliation, which is
	// what the window uses to decide whether to offer the affiliate control.
	w.I64(int64(viewerDemon))
	return protocol.EncodeS2C(protocol.OpDemonLadder, w.Bytes())
}

// handleTournamentCalendarRequest handles TOURNAMENT_CALENDAR_REQUEST (17002,
// empty) and replies with the standing tournaments as calendar events. This is one
// of the two requests the tournament window fires on open (the other is the list,
// below); together they populate the totem's calendar and its "Tournois du jour"
// panel.
func handleTournamentCalendarRequest(s *Session, _ *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	ts, err := s.deps.Store.Tournaments.ListEnabled()
	if err != nil {
		return err
	}
	frame, err := buildTournamentCalendar(ts)
	if err != nil {
		return err
	}
	s.log.Debug("tournament calendar", "coach", s.Coach.Name, "events", len(ts))
	return s.Send(frame)
}

// handleTournamentListRequest handles TOURNAMENT_LIST_REQUEST (28601, empty), sent
// alongside the calendar request, and replies with the registerable tournaments.
// The rows carry this coach's registration status so a re-opened window is correct.
func handleTournamentListRequest(s *Session, _ *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	ts, err := s.deps.Store.Tournaments.ListEnabled()
	if err != nil {
		return err
	}
	frame, err := buildTournamentList(s.Coach.ID, s.deps.Tournaments, ts)
	if err != nil {
		return err
	}
	s.log.Debug("tournament list", "coach", s.Coach.Name, "count", len(ts))
	if err := s.Send(frame); err != nil {
		return err
	}
	// Settle any window that has closed since anyone last looked. Done lazily
	// here rather than on a ticker: a tournament only has to be up to date when
	// somebody opens it, and the settlement is idempotent.
	now := time.Now()
	for i := range ts {
		s.deps.settleTournamentPeriod(ts[i].WireID(), now)
	}

	// AFTER the list: the search-period notification names its tournament by
	// looking it up in the registry this message just filled.
	s.announceTournamentSearchPeriods()
	return nil
}

// handleTournamentRegister handles TOURNAMENT_REGISTER (4607 aik_0):
// [i64 tournamentId][i64 coachId][i16 teamPreset][i32 cardId]. It is sent by the
// register button; the definitions we offer need no card, so cardId is 0 and
// teamPreset is -1. The server trusts the session identity and ignores the
// client-supplied coach id. Reply is 28608 dy_0: [i64 tournamentId][i8 errorCode]
// where 0 = accepted (2 = full, any other = refused).
func handleTournamentRegister(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	tid, err := r.I64()
	if err != nil {
		return err
	}

	const (
		regAccepted uint8 = 0
		regRefused  uint8 = 1
	)
	code := regAccepted
	switch t, lookupErr := s.deps.Store.Tournaments.GetByWireID(tid); {
	case lookupErr != nil || !t.Enabled:
		code = regRefused // unknown, or an admin has taken it offline
	case !t.RegistrationOpen:
		code = regRefused // listed, but closed to new entrants
	default:
		if s.deps.Tournaments != nil {
			s.deps.Tournaments.Register(s.Coach.ID, tid)
		}
	}

	w := protocol.NewWriter().I64(tid).U8(code)
	frame, err := protocol.EncodeS2C(protocol.OpTournamentRegisterReply, w.Bytes())
	if err != nil {
		return err
	}
	s.log.Debug("tournament register", "coach", s.Coach.Name, "tid", tid, "code", code)
	return s.Send(frame)
}

// --- Tournament opponent search (28609/28610/28611/28612/28614/28616) ---
//
// The third member of the "ready up and look for an opponent" pattern: the
// client's ds_2 frame is the same shape as vu_1 (classic) and wp_0 (evolution),
// and 28611 is sent by the Tournois tab's "Combattre" AND by LÃƒÂ©gendes (which
// passes the legend pseudo-preset 9999). Both sender sites pop the team panel
// themselves (`hu_2` ... `apN.aDK().b(this)`) after pushing the fight frame, so
// an unanswered 28611 is the SEVERE variant of the B-098/B-099 defect: the panel
// closes, no overlay appears, and there is nothing left to click.
//
// WHY THIS REFUSES INSTEAD OF QUEUEING. For the other two families, accepting the
// search is truthful Ã¢â‚¬â€ two coaches really can pair and fight. A tournament match
// is not a free pairing: it is a specific bracket fixture between two registered
// entrants, and this server has no bracket/match layer (28649 is answered with an
// empty tree). Pairing arbitrary searchers would invent semantics and produce
// fights that advance nothing, i.e. it would silently pretend tournaments work.
// So the honest answer is the client's own "impossible to start the search",
// which shows a message and leaves no overlay behind.
//
// When the bracket layer lands, this becomes: verify the coach is an entrant of
// `tid`, accept with 28612, pair by fixture, then 28614 (which carries the
// tournament id and prunes the overworld actors for it) followed by CREATE_FIGHT.
func handleTournamentSearchRequest(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	tid, err := r.I64()
	if err != nil {
		return err
	}
	if _, err := r.I64(); err != nil { // coach id (trust the session)
		return err
	}
	preset, err := r.U16()
	if err != nil {
		return err
	}
	// Only an ENTRANT may ready up. Without this a coach could join any
	// tournament's fixture list by sending a tid it never registered for, and the
	// match would advance a bracket it is not in.
	if s.deps.Tournaments == nil || !s.deps.Tournaments.IsRegistered(s.Coach.ID, tid) {
		s.log.Info("tournament search refused: not an entrant",
			"coach", s.Coach.Name, "tournament", tid)
		return s.sendTournamentSearchError(searchErrCannotStart, 0)
	}
	// SECURITY: and only inside the scheduled search window.
	//
	// Only registration was checked, so ReadyUp could be called at ANY time -
	// including long after the window closed and while the opponent was offline.
	// The attacker then triggers settlement itself with 28601, and
	// SettleClosedPeriod awards the fixture by forfeit to whichever side is
	// "ready and present". Cascading to the root also pays the prize card. The
	// prize is single-claim guarded, so the damage is bracket takeover rather than
	// card duplication - but the bracket IS the tournament.
	//
	// A tournament with no schedule (zero SearchPeriodEnd) is UNSCHEDULED, not
	// permanently closed, so it is deliberately left alone.
	if !s.tournamentSearchOpen(tid) {
		s.log.Info("tournament search refused: outside the search window",
			"coach", s.Coach.Name, "tournament", tid)
		return s.sendTournamentSearchError(searchErrCannotStart, 0)
	}

	// Accept first: 28612 is what opens the client's waiting dialog. Without it
	// the team panel has already closed itself and the player is left with no
	// overlay and nothing to click - the B-098/B-099 defect.
	if err := s.sendTournamentSearchResult(tid, preset, true); err != nil {
		return err
	}

	// A coach the byes have already carried to the root has won the tournament and
	// has nobody left to play. Queueing it would leave the waiting overlay up for
	// the rest of the session, since only an opponent - who cannot exist - would
	// take it down. 28648 is exactly the client's word for this: "the other player
	// was not searching while you were, so you are declared winner by forfeit".
	//
	// Gated on registration being CLOSED, and that gate is the whole subtlety.
	// Byes are derived from the current entrant list, so while registration is
	// still open "nobody can ever arrive in the sibling subtree" is only true
	// until the next person registers. Without this a lone early entrant would be
	// handed the tournament, and its prize, the instant it pressed Combattre.
	// Retail ties forfeits to a search PERIOD closing for the same reason.
	if s.unopposedInTournament(tid) {
		s.log.Info("tournament search: unopposed, winner by forfeit",
			"coach", s.Coach.Name, "tournament", tid)
		s.deps.Tournaments.CancelReady(s.Coach.ID)
		s.deps.awardTournamentPrize(tid, s.Coach.ID, s)
		return s.sendTournamentSearchEnded(tid, false)
	}

	opponent, paired := s.deps.Tournaments.ReadyUp(tid, s.Coach.ID)
	if !paired {
		s.log.Info("tournament search: waiting for an opponent",
			"coach", s.Coach.Name, "tournament", tid)
		return nil
	}
	other := s.deps.sessionForCoach(opponent)
	if other == nil {
		// The waiting entrant vanished between readying and pairing; put this one
		// back rather than dropping it silently.
		s.deps.Tournaments.ReadyUp(tid, s.Coach.ID)
		s.log.Info("tournament search: opponent went offline, still waiting",
			"coach", s.Coach.Name, "tournament", tid)
		return nil
	}
	s.log.Info("tournament match paired", "tournament", tid,
		"a", other.Coach.Name, "b", s.Coach.Name)
	return s.deps.startTournamentMatch(tid, other, s, preset)
}

// startTournamentMatch tells both entrants the fixture is starting and builds the
// fight.
//
// 28614 goes out FIRST: it is what closes the waiting dialog
// ("Lancement du combat") and re-arms the client's fight frame. Sending it after
// CREATE_FIGHT would leave the overlay on top of the arena.
func (d *Deps) startTournamentMatch(tid int64, a, b *Session, preset uint16) error {
	// Decided BEFORE the fight starts: once it ends the winner has moved up and
	// the pair no longer looks like a final.
	final := d.isFinalFixture(tid, a.Coach.ID, b.Coach.ID)

	frame, err := protocol.EncodeS2C(protocol.OpTournamentFightStarting,
		protocol.NewWriter().I64(tid).Bytes())
	if err != nil {
		return err
	}
	_ = a.Send(frame)
	_ = b.Send(frame)

	arena := pickArena()
	// SECURITY: each coach fields ITS OWN roster.
	//
	// The `preset` off the wire used to be applied to BOTH sides. resolveTeamRoster
	// is IDOR-guarded and returns nil for a preset the coach does not own, and a
	// nil roster falls back to a SINGLE fighter - so whoever sent 28611 named one
	// of its own preset ids, got its full six, and handed the opponent a
	// one-fighter team. The winner then advances the bracket and collects the
	// prize card, and it moves the ranked ladder too.
	//
	// Every other path already resolves per-coach (handlers_challenge.go uses each
	// side's confirmed preset; the queues carry each searcher's own teamIDs); the
	// tournament path was the only one sharing one wire value. Falling back to the
	// titular line-up rather than fighters[0] also fixes the fidelity half: the
	// honest client sends pseudo-presets 99/9999, so every fixture was silently
	// one-fighter-versus-one-fighter.
	rosterA := d.resolveTeamRoster(a.Coach.ID, uint(preset))
	if len(rosterA) == 0 {
		rosterA = d.titularRoster(a.Coach.ID, len(arena.startCells(0)))
	}
	rosterB := d.titularRoster(b.Coach.ID, len(arena.startCells(1)))

	teamA, err := d.buildFightTeamFor(a, 0, arena.startCells(0), rosterA)
	if err != nil {
		return refuseFightError(err, a, b)
	}
	teamB, err := d.buildFightTeamFor(b, 1, arena.startCells(1), rosterB)
	if err != nil {
		return refuseFightError(err, a, b)
	}
	// Ranked: a tournament match is competitive, so it feeds stats and the ladder
	// exactly like a Combattre pairing.
	if err := d.startFightWithTeams(arena, teamA, teamB, false, 0, false); err != nil {
		return err
	}
	// Tag the fixture so its result can be advanced up the bracket. Done after
	// creation rather than by threading a tournament id through
	// startFightWithTeams, which has seven callers with nothing to do with
	// tournaments. The fight is registered synchronously, so this lookup is safe.
	if f := d.Fights.ByCoach(a.Coach.ID); f != nil {
		f.TournamentID = tid
	}
	if final {
		d.announceFinale(tid, a, b)
	}
	return nil
}

// sendTournamentSearchResult sends TOURNAMENT_SEARCH_RESULT (28612 DR):
// [i64 tid][i16 preset][i8 accepted].
func (s *Session) sendTournamentSearchResult(tid int64, preset uint16, accepted bool) error {
	w := protocol.NewWriter().I64(tid).U16(preset)
	if accepted {
		w.U8(1)
	} else {
		w.U8(0)
	}
	frame, err := protocol.EncodeS2C(protocol.OpTournamentSearchResult, w.Bytes())
	if err != nil {
		return err
	}
	return s.Send(frame)
}

// unopposedInTournament reports whether this coach has already won `tid` without
// playing: the byes carried it to the root AND no further entrant can arrive to
// change that, because registration is closed.
//
// Both halves are required. The bracket alone is not enough while registration is
// open, since byes are re-derived from the entrant list on every read and a later
// registration can put a real opponent in the empty half.
func (s *Session) unopposedInTournament(tid int64) bool {
	if s.deps.Tournaments == nil || s.deps.Store == nil {
		return false
	}
	t, err := s.deps.Store.Tournaments.GetByWireID(tid)
	if err != nil || t == nil || t.RegistrationOpen {
		return false
	}
	return s.deps.Tournaments.BracketSlots(tid)[bracketWinnerSlot] == s.Coach.ID
}

// sendTournamentSearchEnded closes the recipient's opponent-search period for a
// fixture (28648 df_1) and says how it was settled.
//
// forfeit=false is the client's "tournamentWinner": *"the other player was not
// searching for an opponent while you were, so you are declared winner by
// forfeit"*. It also dismisses `tournamentsSearchStatusDialog`, which is the
// only server-side way to take that overlay down.
func (s *Session) sendTournamentSearchEnded(tid int64, forfeit bool) error {
	w := protocol.NewWriter().I64(tid)
	if forfeit {
		w.U8(1)
	} else {
		w.U8(0)
	}
	frame, err := protocol.EncodeS2C(protocol.OpTournamentSearchEnded, w.Bytes())
	if err != nil {
		return err
	}
	return s.Send(frame)
}

// handleTournamentSearchCancel (28609 bt_0) answers the tournament overlay's
// Cancel. Nothing can currently be queued, but the reply is what closes that
// overlay and unregisters ds_2, so it is sent unconditionally Ã¢â‚¬â€ the same reason
// the classic and evolution cancels do.
func handleTournamentSearchCancel(s *Session, _ *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	if s.deps.Tournaments != nil && s.deps.Tournaments.CancelReady(s.Coach.ID) {
		s.log.Info("tournament search cancelled", "coach", s.Coach.Name)
	}
	s.deps.Matchmaker.CancelSearch(s.Coach.ID)
	w := protocol.NewWriter().U8(boolU8(true))
	frame, err := protocol.EncodeS2C(protocol.OpTournamentSearchCancelResult, w.Bytes())
	if err != nil {
		return err
	}
	return s.Send(frame)
}

// sendTournamentSearchError sends OpTournamentSearchError (28616 kw_1):
// [i8 code][i8 subCode]. Note the SECOND byte, which the other two families do
// not have: when code == 2 the client ignores the usual message table and calls
// zN.M(subCode) instead, i.e. subCode selects a generic error string. For every
// other code it is read but unused, so it goes out as 0.
func (s *Session) sendTournamentSearchError(code, subCode uint8) error {
	w := protocol.NewWriter().U8(code).U8(subCode)
	frame, err := protocol.EncodeS2C(protocol.OpTournamentSearchError, w.Bytes())
	if err != nil {
		return err
	}
	return s.Send(frame)
}

// demonLadderRows returns the clans serving a demon, strongest first. Empty when
// guilds are unavailable, which is exactly what this message carried before.
func (d *Deps) demonLadderRows(demonID int16) []store.DemonReputationRow {
	if d == nil || d.Store == nil || d.Store.Guilds == nil {
		return nil
	}
	rows, err := d.Store.Guilds.DemonLadder(demonID, ladderPageSize)
	if err != nil {
		return nil
	}
	return rows
}

// viewerDemon is the demon the viewer's own clan serves (0 = none/no clan). The
// window reads it to decide whether the affiliate control applies.
func (d *Deps) viewerDemon(coachID uint) int16 {
	if d == nil || d.Store == nil || d.Store.Guilds == nil {
		return 0
	}
	m, err := d.Store.Guilds.MembershipOf(coachID)
	if err != nil || m == nil {
		return 0
	}
	g, err := d.Store.Guilds.ByID(m.GuildID)
	if err != nil || g == nil {
		return 0
	}
	return g.DemonID
}

// tournamentSearchOpen reports whether a tournament's opponent-search window is
// currently open. An unscheduled tournament (zero SearchPeriodEnd) is treated as
// open: it has no window to be outside of.
func (s *Session) tournamentSearchOpen(tid int64) bool {
	if s.deps.Store == nil || s.deps.Store.Tournaments == nil {
		return true
	}
	t, err := s.deps.Store.Tournaments.GetByWireID(tid)
	if err != nil || t == nil {
		return true // unknown here; IsRegistered above is the real entrant gate
	}
	end := t.SearchPeriodEnd()
	if end.IsZero() {
		return true // unscheduled
	}
	now := time.Now()
	return !now.Before(t.SearchPeriodStart) && !now.After(end)
}
