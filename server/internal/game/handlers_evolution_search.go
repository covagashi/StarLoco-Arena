package game

import (
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// registerEvolutionSearchHandlers wires the EVOLUTION tab's opponent search —
// the "Combattre" button of the evolution team panel. Until this existed the
// server never answered 23003 and the client waited on a silent screen, so an
// evolution fight could not be started from the retail client at all (B-098).
//
// The handshake itself is shared with the classic tab: see searchFamily.
func registerEvolutionSearchHandlers(r *Router, d *Deps) {
	r.Register(protocol.OpEvolutionSearchRequest, handleEvolutionSearch)
	r.Register(protocol.OpEvolutionSearchCancel, handleEvolutionSearchCancel)
}

// evolutionTeamPreset is the i16 the client sends in 23003/23001. It is NOT a
// database team id: `sw_1.bMm = 99` is a synthetic pseudo-preset for "the
// evolution team", a peer of graveyard (10000) and legend (9999), and the object
// carrying it (`xz_0`, bound to the Lua property "evolutionTeam") sets it in its
// own constructor. All four client call sites inline the literal; the tournament
// path (`en_2`) sends `xz_0.amc().tI()`, which is the same 99.
//
// So it must be mapped to the coach's TITULAR line-up rather than looked up in
// the teams table, where preset 99 would either miss or — worse — collide with
// some unrelated coach's real team. This is the one place the evolution family
// genuinely differs from its classic twin, whose i16 is a real team id.
const evolutionTeamPreset uint16 = 99

// evolutionTeamSlots is how many fighters the evolution panel fields (six slots,
// "Recruter" for the empty ones).
const evolutionTeamSlots = 6

// modeEvolutionSearch tags evolution searchers in the shared matchmaker queue so
// they only ever pair with each other — never with a 2301 quick-search or a
// 23103 classic ready-up. Same trick, and same reasoning, as modeClassicReady.
const modeEvolutionSearch int16 = 23003

// handleEvolutionSearch (23003 ajw_0: [i64 coachId][i16 preset=99]) enters the
// coach into the evolution opponent queue and pairs it with the next coach that
// does the same. The client has already pushed its own fight frame by the time it
// sends this, so CREATE_FIGHT is routable the moment we send it.
func handleEvolutionSearch(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	if _, err := r.I64(); err != nil { // team-owner coach id (trust the session)
		return err
	}
	preset, err := r.U16()
	if err != nil {
		return err
	}
	// Refuse anything that is not the evolution pseudo-preset rather than
	// guessing: the classic/tournament tabs have their own opcodes, and a real
	// team id arriving here would mean we misread the message.
	if preset != evolutionTeamPreset {
		s.log.Warn("evolution search: unexpected preset", "coach", s.Coach.Name, "preset", preset)
		return evolutionSearchFamily.sendError(s, searchErrCannotStart)
	}
	if s.deps.Fights.ByCoach(s.Coach.ID) != nil {
		return evolutionSearchFamily.sendError(s, searchErrCannotStart)
	}
	roster := s.deps.titularRoster(s.Coach.ID, evolutionTeamSlots)
	if len(roster) == 0 {
		return evolutionSearchFamily.sendError(s, searchErrBadTeam)
	}

	// Re-sending 23003 while already queued is possible (the end-of-fight path
	// in WE fires it unprompted), so drop any stale queue entry first rather
	// than letting the same coach sit in the queue twice.
	s.deps.Matchmaker.CancelSearch(s.Coach.ID)

	if err := evolutionSearchFamily.sendResult(s, preset, true); err != nil {
		return err
	}
	pm := s.deps.Matchmaker.Search(s, modeEvolutionSearch, 0, roster)
	if pm == nil {
		s.log.Info("evolution search: waiting for opponent",
			"coach", s.Coach.Name, "fighters", len(roster))
		return nil
	}
	// Paired. Like the classic ready-up, the evolution search has no accept
	// prompt — the fight starts at once — so the pending match is discarded
	// rather than left for a 23114 that will never come.
	s.deps.Matchmaker.Discard(pm)
	s.log.Info("evolution search: paired -> starting fight",
		"a", pm.a.session.Coach.Name, "b", pm.b.session.Coach.Name)
	announceFightStarting(evolutionSearchFamily, pm)
	return s.deps.startEvolutionFight(pm)
}

// handleEvolutionSearchCancel (23001 abn_0: [i64 coachId][i16 preset]) is the
// overlay's Cancel button (Lua dofusarena.evolutionSearchStatus:cancelSearch).
func handleEvolutionSearchCancel(s *Session, _ *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	if s.deps.Matchmaker.CancelSearch(s.Coach.ID) {
		s.log.Info("evolution search cancelled", "coach", s.Coach.Name)
	}
	return evolutionSearchFamily.sendCancelResult(s, true)
}

// startEvolutionFight builds the fight for a paired evolution search. It is
// startFight with the evolution flag set: ranked-style (not practice), no
// challenge, and it FEEDS PROGRESSION — XP, morale, fatigue, wounds and the
// per-fighter death roll all apply, which is the entire point of the mode.
func (d *Deps) startEvolutionFight(pm *pendingMatch) error {
	a := d.pickArena()
	teamA, err := d.buildFightTeam(a, pm.a, 0)
	if err != nil {
		return err
	}
	teamB, err := d.buildFightTeam(a, pm.b, 1)
	if err != nil {
		return err
	}
	return d.startFightWithTeams(a, teamA, teamB, false, 0, true)
}
