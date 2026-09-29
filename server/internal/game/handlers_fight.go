package game

import (
	"sort"
	"time"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/handshake"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

func registerFightHandlers(r *Router, d *Deps) {
	r.Register(protocol.OpReadyForPlacement, handleReadyForPlacement)
	r.Register(protocol.OpMoveToPlacementReq, handleMoveToPlacement)
	r.Register(protocol.OpReadyForObservation, handleReadyForObservation)
	r.Register(protocol.OpReadyForAction, handleReadyForAction)
	r.Register(protocol.OpFighterEndTurnReq, handleFighterEndTurn)
	r.Register(protocol.OpFighterMoveInFightReq, handleFighterMoveInFight)
	r.Register(protocol.OpFighterDirChangeReq, handleFighterDirectionChange)
	r.Register(protocol.OpSpellCastRequest, handleSpellCast)
	r.Register(protocol.OpFighterCardUseRequest, handleFighterCardUse)
	r.Register(protocol.OpCloseCombatRequest, handleCloseCombat)
	r.Register(protocol.OpGiveUpFight, handleGiveUp)
	r.Register(protocol.OpEndFightDone, handleEndFightDone)
}

// startFight builds a Fight from a mutually-accepted match and drives the
// clients into the presentation phase.
func (d *Deps) startFight(pm *pendingMatch) error {
	// If either matched coach has a formed 2v2 duo, the fight needs an arena that
	// actually seats two coaches a side - 15 of the 47 shipped arenas define no
	// pedestals at all and a few define only some.
	seats := 1
	if d.TeamUps != nil {
		for _, sc := range []*searcher{pm.a, pm.b} {
			if sc != nil && sc.session != nil && sc.session.Coach != nil &&
				d.TeamUps.Partner(sc.session.Coach.ID) != 0 {
				seats = 2
			}
		}
	}
	a := pickArenaSeating(seats)
	teamA, err := d.buildFightTeam(a, pm.a, 0)
	if err != nil {
		return refuseFightError(err, pm.a.session, pm.b.session)
	}
	teamB, err := d.buildFightTeam(a, pm.b, 1)
	if err != nil {
		return refuseFightError(err, pm.a.session, pm.b.session)
	}
	// Each side pulls in its ally, if it has one. Done after both sides exist so
	// the partner's fighters land on the start cells its own side has left.
	for _, pair := range []struct {
		team *FightTeam
		sc   *searcher
	}{{teamA, pm.a}, {teamB, pm.b}} {
		if pair.sc == nil || pair.sc.session == nil || pair.sc.session.Coach == nil {
			continue
		}
		if d.joinDuoPartner(pair.team, pair.sc.session.Coach.ID, a.startCells(pair.team.ID)) {
			d.Log.Info("2v2 side formed", "side", pair.team.ID,
				"coaches", len(pair.team.Members), "fighters", len(pair.team.Fighters))
		}
	}
	return d.startFightWithTeams(a, teamA, teamB, false, 0, false)
}

// startFightWithTeams creates the Fight from two prepared teams and drives both
// clients into the presentation phase. It is opponent-agnostic: a team with a
// nil Session (e.g. the TESTER sparring partner) is excluded from world/session
// I/O and pre-marked ready in every phase gate, so a single real coach's ready
// still advances the fight. When practice is true the fight is unranked.
func (d *Deps) startFightWithTeams(a *arena, teamA, teamB *FightTeam, practice bool, challengeID int32, evolution bool) error {
	f := &Fight{
		arena:        a,
		Practice:     practice,
		ChallengeID:  challengeID,
		Rules:        d.rulesForChallenge(challengeID),
		Evolution:    evolution,
		Teams:        [2]*FightTeam{teamA, teamB},
		deps:         d,
		readyPresent: make(map[uint]bool),
		readyObserve: make(map[uint]bool),
		readyAction:  make(map[uint]bool),
	}
	// A session-less coach can never signal ready, so pre-mark it in every gate.
	// Per MEMBER rather than per side: a 2v2 side pairing a real coach with a
	// server-driven one must still wait for the real coach's ready.
	for _, m := range f.members() {
		if m.Session == nil && m.Coach != nil {
			f.readyPresent[m.Coach.ID] = true
			f.readyObserve[m.Coach.ID] = true
			f.readyAction[m.Coach.ID] = true
		}
	}
	f.Timeline = buildTimeline(f)
	f.startActor()
	d.Fights.Create(f)

	// Entering a fight removes each real coach from the overworld: despawn them
	// from anyone who currently sees them. Session-less (synthetic) teams are
	// not in the world, so skip them.
	for _, m := range f.members() {
		if m.Session == nil || m.Coach == nil {
			continue
		}
		viewers := d.World.SetInFight(m.Coach.ID, true)
		if len(viewers) > 0 {
			if frame, err := buildActorDespawn([]uint{m.Coach.ID}); err == nil {
				for _, sess := range viewers {
					_ = sess.Send(frame)
				}
			}
		}
	}

	// Drive the fight-start sequence on the fight goroutine so all state access
	// (phase, clock) is serialized there.
	f.Post(func(f *Fight) {
		// Stream the arena world FIRST (EnterInstance = the arena world id) so the
		// client loads its topology before CREATE_FIGHT. The x,y is the CAMERA
		// FOCUS — the battlefield centre — so the view isn't off to one side.
		enter, _ := handshake.EncodeEnterInstance(
			float32(f.Arena().centerX), float32(f.Arena().centerY), 0,
			int16(f.Arena().worldID), true)
		for _, s := range f.sessions() {
			_ = s.Send(enter)
		}
		// CREATE_FIGHT is built PER RECIPIENT: each coach's own equipped action
		// deck goes in the coach-card blob (the client copies that blob onto both
		// coaches, so it must carry the receiver's deck, not a shared one).
		for _, m := range f.members() {
			if m.Session == nil {
				continue
			}
			if createFrame, err := buildCreateFight(f, m.Coach, false); err == nil {
				_ = m.Session.Send(createFrame)
			}
		}
		// ACTOR_APPEAR (4102): insert coach + fighter avatars into the client's
		// iso render list + show them. The avatars are created HIDDEN during the
		// 8000 parse; only 4102 makes them appear (proven in the 2.04 server).
		if appear, err := buildActorAppearForFight(f); err == nil {
			f.broadcast(appear)
		}
		present, _ := buildEmpty(protocol.OpStartPresentation)
		f.broadcast(present)
		f.setPhase(PhasePresentation)
		f.armClock(presentationClock, (*Fight).advanceToPlacement)
	})
	d.Log.Info("fight started", "id", f.ID, "practice", practice,
		"arena", a.worldID, "evolution", evolution, "challenge", challengeID)
	return nil
}

// buildFightTeam creates a FightTeam from a searcher's roster, placing fighters
// on the arena's start cells for its side.
func (d *Deps) buildFightTeam(a *arena, sr *searcher, side uint8) (*FightTeam, error) {
	return d.buildFightTeamFor(sr.session, side, a.startCells(side), sr.teamIDs)
}

// buildFightTeamFor creates a FightTeam for a session from an explicit list of
// selected fighter ids, placing each fighter on one of the given arena start
// cells (which carry the cell's real x,y,z so the client accepts the position).
// If none of the ids resolve to an owned fighter, it falls back to the coach's
// first owned fighter, then to a synthesized placeholder, so a fight can always
// start (dev convenience).
func (d *Deps) buildFightTeamFor(sess *Session, side uint8, cells []Pos, rosterIDs []int64) (*FightTeam, error) {
	return d.buildFightTeamForMode(sess, side, cells, rosterIDs, false)
}

// buildFightTeamForMode is buildFightTeamFor with the evolution flag, which only
// affects the MINIMUM budget rule (code 78).
func (d *Deps) buildFightTeamForMode(sess *Session, side uint8, cells []Pos, rosterIDs []int64, evolution bool) (*FightTeam, error) {
	coach := sess.Coach
	team := &FightTeam{ID: side, Members: []*FightMember{{Coach: coach, Session: sess}}}

	fighters, _ := d.Store.Fighters.ListByCoach(coach.ID)
	byID := make(map[uint]*domain.Fighter)
	for i := range fighters {
		byID[fighters[i].ID] = &fighters[i]
	}

	var chosen []*domain.Fighter
	for _, id := range rosterIDs {
		if fr := byID[uint(id)]; fr != nil {
			chosen = append(chosen, fr)
		}
	}
	// Default to the coach's own first fighter when the request names none. This
	// is legitimate and load-bearing: the 2v2 partner path passes a nil roster
	// (handlers_teamup.go), and an empty preset means "use my default".
	//
	// What was REMOVED here is the step after it, which synthesized a
	// &domain.Fighter{Name: "Champion"} out of nothing when the coach owned no
	// fighters at all. That is the server inventing game state to paper over a
	// validation failure - a ranked loss could be recorded for a team the player
	// never fielded. A coach with no fighters now gets a refusal, which is what
	// the client itself does (error.teamManagement.teamEmpty).
	if len(chosen) == 0 && len(fighters) > 0 {
		chosen = append(chosen, &fighters[0])
	}
	if len(chosen) == 0 {
		// The coach owns NO fighters at all. A brand-new coach is in exactly this
		// state - completeLogin grants starter cards and a wallet but no fighters -
		// and the retail client refuses to start a fight here
		// (error.teamManagement.teamEmpty), so an honest client never arrives.
		//
		// The placeholder is kept rather than refusing, because refusing would
		// also refuse a legitimate new player whose client is merely out of step,
		// and the substitute is weak enough to be no advantage. It is logged so it
		// stops being invisible: previously the server synthesized a fighter with
		// no trace at all, and a ranked loss could be recorded for a team the
		// player never fielded.
		//
		// What IS refused is the attack shape - see validateRoster's rosterEmpty
		// case, reached when the request names fighters that resolve to nothing
		// while the coach does own some.
		d.Log.Warn("fight started with a synthesized fighter: coach owns none",
			"coach", coach.ID)
		chosen = append(chosen, &domain.Fighter{Name: "Champion", BreedID: 1})
	}

	// SECURITY: validate the roster HERE, at the single point every fight path
	// funnels through (startFight, startFightWithTeams, startPvEChallenge,
	// startChallengeFight, startEvolutionFight, joinDuoPartner).
	//
	// The rules were previously applied only where a roster is EDITED (6013,
	// 6021), which left opcode 2301 wide open: handleOpponentSearch takes a raw
	// client id list capped only at 64 and hands it straight through, so a queued
	// attacker could field 64 fighters against an honest player who simply pressed
	// "Combattre". Past i=16 the derived WireID (base + fighterID*16 + side*8 + i)
	// collides with another fighter's space and corrupts targeting, HP and turn
	// order. Enforcing at the choke point closes every entry at once, including
	// ones added later.
	if v := validateRoster(chosen, evolution); v != rosterOK {
		d.Log.Warn("fight refused: illegal roster", "coach", coach.ID,
			"reason", v.String(), "fighters", len(chosen))
		return nil, rosterError{violation: v}
	}

	for i, fr := range chosen {
		pos := Pos{} // (0,0,0) fallback if the arena has no start cells
		if len(cells) > 0 {
			pos = cells[i%len(cells)]
		}
		st := computeFighterStatsWithConditions(fr, d.FighterCards, d.Conditions, d.SphereBoards)
		// SECURITY: re-apply spell legality HERE, not just when a loadout is saved.
		//
		// filterLoadoutSpells guards the 6011 write path, which stops a forged
		// loadout being STORED - but it does nothing about one already in the
		// database. A loadout saved before that guard existed, or written by any
		// other means, would still be fielded: the door was closed and the room
		// never cleaned. Filtering at fight build makes the rule retroactive with
		// no migration, and costs one pass over at most six spells.
		//
		// Order matters: filter the fighter's OWN spells first, then let
		// fighterWithSphereSpells append the sphere unlocks, which are derived
		// server-side from bought nodes and are legitimate regardless of breed.
		fr = fighterWithLegalSpells(d, fr)

		// The fighter that FIGHTS knows its sphere spells as well as its own; both
		// the cast validator and the AI read this one list.
		fr = fighterWithSphereSpells(fr, d.SphereBoards)
		ff := &FightFighter{
			WireID:  FighterWireIDBase + int64(fr.ID)*16 + int64(side)*8 + int64(i),
			CoachID: coach.ID,
			TeamID:  side,
			Fighter: fr,
			Pos:     pos,
			MaxHP:   st.MaxHP, HP: st.MaxHP,
			MaxAP: st.MaxAP, AP: st.MaxAP,
			MaxMP: st.MaxMP, MP: st.MaxMP,
			Init: st.Init, Range: st.Range,
			CritRate: st.CritRate, FumbleRate: st.FumbleRate,
			Block: st.Block, Dodge: st.Dodge,
			Stats: st.Stats,
		}
		team.Fighters = append(team.Fighters, ff)
	}
	return team, nil
}

// buildTimeline orders all fighters into the turn order: descending initiative
// (breed base init), stable so ties keep the team-A-before-team-B insertion
// order. The client plays exactly this order (it does no re-sort of its own), so
// this is what decides who acts first each round.
func buildTimeline(f *Fight) []*FightFighter {
	var tl []*FightFighter
	for _, t := range f.Teams {
		if t != nil {
			tl = append(tl, t.Fighters...)
		}
	}
	sort.SliceStable(tl, func(i, j int) bool {
		return fighterInit(tl[i]) > fighterInit(tl[j])
	})
	return tl
}

// --- phase-gate handlers ---
//
// Each phase transition is funneled through an idempotent advanceToX method
// guarded by f.phase, so a manual "both ready" signal and a clock firing can
// never double-advance. The clock is armed on entering each phase.

func handleReadyForPlacement(s *Session, _ *protocol.C2SFrame) error {
	f := s.deps.Fights.ByCoach(coachID(s))
	if f == nil {
		return nil
	}
	cid := s.Coach.ID
	f.Post(func(f *Fight) {
		ack, _ := buildReadyAck(protocol.OpReadyForPlacementAck, cid)
		f.broadcast(ack)
		if f.markReady(f.readyPresent, cid) {
			f.advanceToPlacement()
		}
	})
	return nil
}

// advanceToPlacement moves presentation -> placement exactly once.
func (f *Fight) advanceToPlacement() {
	if !f.transition(PhasePresentation, PhasePlacement) {
		return
	}
	end, _ := buildEmpty(protocol.OpEndPresentation)
	f.broadcast(end)
	start, _ := buildEmpty(protocol.OpStartPlacement)
	f.broadcast(start)
	f.armClock(placementClock, (*Fight).advanceToObservation)
}

func handleMoveToPlacement(s *Session, frame *protocol.C2SFrame) error {
	f := s.deps.Fights.ByCoach(coachID(s))
	if f == nil {
		return nil
	}
	r := protocol.NewReader(frame.Payload)
	wireID, _ := r.I64()
	x, _ := r.I32()
	y, _ := r.I32()
	z, _ := r.U16()
	cid := s.Coach.ID
	f.Post(func(f *Fight) {
		// PHASE GATE. Without this, 8021 is a free teleport: sent during the
		// action phase it moved a fighter anywhere on the map, at no MP cost,
		// ignoring rooting, tackle, traps and line of sight. Read here rather
		// than before Post because the phase can advance while the message sits
		// in the fight's mailbox, and the actor is the authoritative point.
		if f.Phase() != PhasePlacement {
			f.logPlacement("refused: not the placement phase", wireID)
			return
		}
		ff := f.fighterByWireID(wireID)
		if ff == nil || ff.CoachID != cid {
			return // not your fighter
		}
		p := Pos{X: x, Y: y, Z: int16(z)}
		if !f.placementCellValid(ff, p) {
			f.logPlacement("refused: illegal placement cell", wireID)
			return
		}
		ff.Pos = p
		bc, _ := buildPlacementBroadcast(wireID, ff.Pos)
		f.broadcast(bc)
	})
	return nil
}

// placementCellValid reports whether `ff` may stand on `p` during placement.
//
// The client only ever offers a side its OWN start cells — the same set the
// server seeded the team from at fight creation — so a genuine placement always
// passes. Everything else was previously accepted: the enemy's starting area,
// scenery, void, off-map coordinates, and a cell already occupied by another
// fighter (which silently stacked two fighters on one cell and corrupted
// targeting, tackle and line of sight for the rest of the fight).
//
// Altitude is deliberately NOT validated, matching the movement path: (x,y) is
// the unit of placement and the client owns per-cell z.
func (f *Fight) placementCellValid(ff *FightFighter, p Pos) bool {
	if ff == nil {
		return false
	}
	if !f.Arena().walkable(p.X, p.Y) || f.cellDestroyed(p.X, p.Y) {
		return false
	}
	if f.cellHeldByOther(p, ff) {
		return false
	}
	for _, c := range f.Arena().startCells(ff.TeamID) {
		if c.X == p.X && c.Y == p.Y {
			return true
		}
	}
	return false
}

// logPlacement records a refused placement. Debug, not warn: a client that
// double-clicks during the phase change produces one legitimately.
func (f *Fight) logPlacement(why string, wireID int64) {
	if f.deps == nil || f.deps.Log == nil {
		return
	}
	f.deps.Log.Debug("placement "+why, "fight", f.ID, "wireID", wireID)
}

func handleReadyForObservation(s *Session, _ *protocol.C2SFrame) error {
	f := s.deps.Fights.ByCoach(coachID(s))
	if f == nil {
		return nil
	}
	cid := s.Coach.ID
	f.Post(func(f *Fight) {
		ack, _ := buildReadyAck(protocol.OpReadyForObservationAck, cid)
		f.broadcast(ack)
		if f.markReady(f.readyObserve, cid) {
			f.advanceToObservation()
		}
	})
	return nil
}

// advanceToObservation moves placement -> observation exactly once.
func (f *Fight) advanceToObservation() {
	if !f.transition(PhasePlacement, PhaseObservation) {
		return
	}
	end, _ := buildEmpty(protocol.OpEndPlacement)
	f.broadcast(end)
	start, _ := buildEmpty(protocol.OpStartObservation)
	f.broadcast(start)
	f.armClock(observationClock, (*Fight).advanceToAction)
}

func handleReadyForAction(s *Session, _ *protocol.C2SFrame) error {
	f := s.deps.Fights.ByCoach(coachID(s))
	if f == nil {
		return nil
	}
	cid := s.Coach.ID
	f.Post(func(f *Fight) {
		ack, _ := buildReadyAck(protocol.OpReadyForActionAck, cid)
		f.broadcast(ack)
		if f.markReady(f.readyAction, cid) {
			f.advanceToAction()
		}
	})
	return nil
}

// advanceToAction moves observation -> action exactly once and starts turn 1.
func (f *Fight) advanceToAction() {
	if !f.transition(PhaseObservation, PhaseAction) {
		return
	}
	end, _ := buildEmpty(protocol.OpEndObservation)
	f.broadcast(end)
	start, _ := buildEmpty(protocol.OpStartAction)
	f.broadcast(start)
	f.startFirstTurn()
}

// transition atomically moves the phase from `from` to `to`, returning false if
// the fight wasn't in `from` (already advanced/ended) so callers run once.
func (f *Fight) transition(from, to FightPhase) bool {
	return f.phase.CompareAndSwap(int32(from), int32(to))
}

// startFirstTurn opens the action phase with the first table turn + first
// fighter's turn, and arms the turn clock.
func (f *Fight) startFirstTurn() {
	f.tableTurn = 1
	f.beginTableTurn()
	if len(f.Timeline) > 0 {
		f.turnIndex = 0
		f.beginTurn(f.Timeline[0])
	}
	// Both effect passes run AFTER the first FIGHTER_TURN_BEGIN: a timed effect
	// sent while no fighter is current throws client-side and is dropped (see
	// applyTableTurnEffects). np_1 type 12 still lands before the round card, so
	// a fight-long buff is in place when round 1 resolves.
	f.applyFightStartEffects()
	f.applyTableTurnEffects()
}

// beginTurn refills the fighter, broadcasts its FIGHTER_TURN_BEGIN and arms the
// turn clock. Session-less (sparring/AI) fighters auto-pass on the short
// aiTurnClock so a practice fight never dead-waits on a dummy; a human fighter
// gets the full turnClock to act.
func (f *Fight) beginTurn(ff *FightFighter) {
	refillFighter(ff)
	// Mirror the client's own per-fighter timeline counter (alh_1.aAw), which it
	// bumps at exactly this point. Buff expiry is expressed against it.
	ff.turnsTaken++
	ff.CastHistory.onNewTurn() // reset this fighter's per-turn cast counters
	turn, _ := buildFighterTurnBegin(f.nextActionUID(), ff.WireID)
	f.broadcast(turn)
	// A turn-start glyph/special the fighter stands on fires now (before it acts).
	f.checkEffectAreasTurnStart(ff)
	// Map-authored special cells fire on the same trigger: only when a fighter
	// STARTS its turn on one (walking over it does nothing) — see specialcells.go.
	if f.applyTurnStartSpecialCell(ff) {
		return // a killer/trap cell ended this fighter's turn (and maybe the fight)
	}
	if f.Phase() != PhaseAction {
		return // a turn-start glyph ended the fight
	}
	if ff.HP <= 0 {
		f.endTurn(ff.WireID) // died at turn start: pass to the next fighter
		return
	}
	ai := f.isAIControlled(ff)
	clock := f.turnClockFor()
	if ai {
		clock = aiTurnClock
	}
	if f.deps != nil && f.deps.Log != nil {
		name := ""
		if ff.Fighter != nil {
			name = ff.Fighter.Name
		}
		f.deps.Log.Debug("turn begin", "wire", ff.WireID, "name", name,
			"ai", ai, "summon", ff.isSummon(), "clockMs", clock.Milliseconds(), "mp", ff.MP, "ap", ff.AP)
	}
	// A petrified fighter cannot act — pass its turn after a short beat (both a
	// human and an AI skip it). Otherwise an AI fighter (sparring opponent /
	// summon) is played by the built-in AI after a short beat, and a human gets
	// the full turn clock.
	// SECURITY: the three auto-pass branches below end the turn on a 1200ms timer
	// rather than immediately, so mark the turn as not-playable. Without this the
	// fighter keeps full raw AP/MP and a modified client can act for the whole
	// window - an effect meant to cost a turn costing nothing.
	f.turnAutoPassed = false

	switch {
	case ff.hasState(stateSkipTurn):
		// Skip-turn (56/111): pass this turn and consume one skip.
		ff.consumeSkipTurn()
		f.turnAutoPassed = true
		f.armClock(aiTurnClock, func(f *Fight) { f.forceEndTurn(ff.WireID) })
	case ff.hasState(statePetrified):
		f.turnAutoPassed = true
		f.armClock(aiTurnClock, func(f *Fight) { f.forceEndTurn(ff.WireID) })
	case f.teamAbsent(ff):
		f.turnAutoPassed = true
		// A disconnected coach's fighters auto-pass — they are NOT AI-played (the
		// coach may still reconnect); the grace timer will forfeit if it doesn't.
		f.armClock(aiTurnClock, func(f *Fight) { f.forceEndTurn(ff.WireID) })
	case ai:
		f.armClock(aiTurnClock, func(f *Fight) { f.runAITurn(ff) })
	default:
		f.armClock(f.turnClockFor(), func(f *Fight) { f.forceEndTurn(ff.WireID) })
	}
}

// refillFighter restores a fighter's AP/MP to its per-turn ceiling (breed base +
// equipped-card bonuses). Falls back to the breed base when the ceiling is unset
// (lightweight tests that build a FightFighter without computed maxima).
func refillFighter(ff *FightFighter) {
	ap, mp := ff.MaxAP, ff.MaxMP
	if ap <= 0 {
		ap = baseAP
	}
	if mp <= 0 {
		mp = baseMP
	}
	ff.AP, ff.MP = ap, mp
}

// Base action/movement points per turn (breed base: AP=6, MP=3), used as a
// fallback when a fighter has no computed maxima.
const (
	baseAP = 6
	baseMP = 3
)

func handleFighterEndTurn(s *Session, frame *protocol.C2SFrame) error {
	f := s.deps.Fights.ByCoach(coachID(s))
	if f == nil || f.Phase() != PhaseAction {
		return nil
	}
	wireID, _ := protocol.NewReader(frame.Payload).I64()
	cid := s.Coach.ID
	deps := s.deps
	f.Post(func(f *Fight) {
		// Only the coach who owns the current-turn fighter may end it.
		ff := f.fighterByWireID(wireID)
		if deps.Log != nil {
			deps.Log.Debug("client end-turn req (8105)", "wire", wireID,
				"haveFighter", ff != nil, "current", f.isCurrentTurn(wireID))
		}
		if ff == nil || ff.CoachID != cid || !f.isCurrentTurn(wireID) {
			return
		}
		f.endTurn(wireID)
	})
	return nil
}

// forceEndTurn is the clock-driven turn timeout: end the current fighter's turn
// even though the coach never signalled.
func (f *Fight) forceEndTurn(wireID int64) {
	if f.Phase() != PhaseAction || !f.isCurrentTurn(wireID) {
		return
	}
	if f.deps != nil && f.deps.Log != nil {
		f.deps.Log.Debug("force end-turn (clock timeout)", "wire", wireID)
	}
	f.endTurn(wireID)
}

// endTurn broadcasts FIGHTER_TURN_END for wireID, advances the timeline to the
// next living fighter, refills it, broadcasts its turn-begin and (re)arms the
// turn clock. Safe for both the manual handler and the clock.
func (f *Fight) endTurn(wireID int64) {
	if f.Phase() != PhaseAction {
		return
	}
	end, _ := protocol.EncodeS2C(protocol.OpFighterTurnEnd,
		protocol.NewWriter().I32(f.nextActionUID()).I32(-1).I64(wireID).Bytes())
	f.broadcast(end)

	// A special cell's bonus lasts only the turn it was granted on.
	f.revertSpecialCellBuffs(f.fighterByWireID(wireID))

	// Advance to the next LIVING fighter (wrapping into a new table turn).
	newTable := false
	var next *FightFighter
	for i := 0; i < len(f.Timeline); i++ {
		f.turnIndex++
		if f.turnIndex >= len(f.Timeline) {
			f.turnIndex = 0
			newTable = true
		}
		if f.Timeline[f.turnIndex].HP > 0 {
			next = f.Timeline[f.turnIndex]
			break
		}
	}
	if next == nil {
		return // no living fighter (fight should be ending)
	}

	newRound := false
	if newTable {
		f.tableTurn++
		// A new round elapsed: age every fighter's timed buffs (reverting those
		// that expired), status states, damage-transfer links and auras before the
		// next fighter refills.
		f.tickBuffs()
		f.tickStates()
		f.tickTransfers()
		f.tickEffectAreas()
		f.tickPoisons()
		f.beginTableTurn()
		newRound = true
		// Sudden death: once the fight reaches the configured turn the arena
		// collapses to a small central area (suddendeath.go). Fires once.
		f.maybeTriggerSuddenDeath()
		if f.Phase() != PhaseAction {
			return // the collapse ended the fight
		}
		// An alternative win condition (np_1 type 14) can end the fight with
		// both sides still standing. Checked AFTER the collapse, because the
		// shipped conditions all outlast the default sudden-death turn: the
		// last rounds of a "Défi du temps" are meant to be fought on a
		// shrinking arena, and a fighter the collapse just killed must not
		// still be credited with surviving the round.
		if f.deps != nil {
			f.deps.checkVictoryConditions(f)
			if f.Phase() != PhaseAction {
				return // a victory condition ended the fight
			}
		}
	}
	f.beginTurn(next)
	if newRound {
		// After FIGHTER_TURN_BEGIN, never before it.
		f.applyTableTurnEffects()
	}
}

func handleGiveUp(s *Session, _ *protocol.C2SFrame) error {
	f := s.deps.Fights.ByCoach(coachID(s))
	if f == nil {
		return nil
	}
	cid := s.Coach.ID
	deps := s.deps
	f.Post(func(f *Fight) { deps.forfeitCoach(f, cid) })
	return nil
}

// forfeitCoach makes coachID lose the fight: every fighter on its team (including
// summons) dies, then the victory is resolved for the opponent (checkFightEnd
// sends END_FIGHT + stats + reward). Shared by the give-up button, the reconnect
// grace timeout and a returning coach. MUST run on the fight actor.
func (d *Deps) forfeitCoach(f *Fight, coachID uint) {
	if f.Phase() == PhaseEnded {
		return
	}
	t := f.teamOfCoach(coachID)
	if t == nil {
		return
	}
	for _, ff := range t.Fighters {
		if ff.HP > 0 {
			ff.HP = 0
			dies, _ := buildFighterDies(f.nextActionUID(), ff.WireID)
			f.broadcast(dies)
		}
	}
	d.checkFightEnd(f)
}

// coachLeftFight handles a coach dropping its connection mid-fight. A practice
// fight (synthetic opponent) is torn down — there is no one to award a win. In a
// real fight the leaver's team is flagged ABSENT and detached, but the fight is
// KEPT ALIVE so the coach can reconnect (the 2.70 client supports resume): the
// absent team's turns auto-pass and a grace timer forfeits it if it never returns.
// If BOTH real teams are absent the fight is torn down.
func (d *Deps) coachLeftFight(f *Fight, coachID uint) {
	if f == nil {
		return
	}
	f.Post(func(f *Fight) { d.coachLeftFightOnActor(f, coachID) })
}

// coachLeftFightOnActor is the fight-actor half of coachLeftFight (also called
// directly by tests). See coachLeftFight.
func (d *Deps) coachLeftFightOnActor(f *Fight, coachID uint) {
	if f.Phase() == PhaseEnded {
		return
	}
	// Practice ("Tester") fights have no real opponent to win — just tear down.
	if f.Practice {
		d.endFight(f)
		return
	}
	m := f.memberOfCoach(coachID)
	if m == nil {
		return
	}
	// Mark the ONE coach absent, not its whole side: in a 2v2 its ally is still
	// playing, and only this coach's own fighters should auto-pass.
	m.Session = nil
	m.Absent = true
	d.Log.Info("coach left fight (grace period)", "id", f.ID, "coach", coachID)

	// Both sides gone → nobody to play or win.
	if f.allTeamsAbsent() {
		d.endFight(f)
		return
	}
	// If it's the absent coach's turn right now, pass it immediately so the
	// opponent isn't left waiting out the departed coach's full turn clock.
	if f.Phase() == PhaseAction {
		if cur := f.currentFighter(); cur != nil && cur.CoachID == coachID {
			f.endTurn(cur.WireID)
		}
	}
	// Arm the reconnect grace: forfeit the absent coach if it hasn't returned.
	f.armGrace(disconnectGraceClock, func(f *Fight) {
		d.Log.Info("reconnect grace expired -> forfeit", "id", f.ID, "coach", coachID)
		d.forfeitCoach(f, coachID)
	})
}

// markReady records a coach as ready and returns true once both coaches are.
// Called inside the actor (no lock).
func (f *Fight) markReady(m map[uint]bool, coachID uint) bool {
	m[coachID] = true
	return len(m) >= 2
}

// endFight tears a fight down with NO winner declared — used for a practice fight
// or when BOTH coaches have left: it stops the clocks, returns any still-connected
// coach to the overworld and stops the actor. A single mid-fight disconnect goes
// through coachLeftFight (grace period + forfeit) instead, which DOES declare the
// opponent the winner. Safe to call from any goroutine: the teardown runs on the
// fight actor. CAS on the phase makes it run exactly once.
// creditFightTime adds a fight's wall-clock duration to every participating
// coach's lifetime "time in fight" counter — the dL entry in the client's 2400
// statistics panel, and a row on the web portal's account page.
//
// A fight can finish three different ways (a declared winner, a forfeit after
// someone disconnects, or a teardown with no winner at all), so this is called
// from each of them and made idempotent with a CAS rather than trusted to a
// single chokepoint that a future path might bypass.
//
// Practice fights count. They are excluded from wins, losses and ladder
// movement because those are competitive records; time spent is not a
// competitive record, and a player who spent an hour sparring did play for an
// hour.
func (d *Deps) creditFightTime(f *Fight) {
	if f == nil || f.startedAt.IsZero() || !f.timeCredited.CompareAndSwap(false, true) {
		return
	}
	secs := int64(time.Since(f.startedAt) / time.Second)
	if secs <= 0 {
		return
	}
	for _, m := range f.members() {
		if m.Coach == nil {
			continue
		}
		m.Coach.Mu.Lock()
		m.Coach.TimeInFightSecs += secs
		m.Coach.Mu.Unlock()
		if d.Store != nil {
			_ = d.Store.Coaches.Save(m.Coach)
		}
	}
}

func (d *Deps) endFight(f *Fight) {
	d.creditFightTime(f)
	if !f.phase.CompareAndSwap(int32(PhasePresentation), int32(PhaseEnded)) &&
		!f.phase.CompareAndSwap(int32(PhasePlacement), int32(PhaseEnded)) &&
		!f.phase.CompareAndSwap(int32(PhaseObservation), int32(PhaseEnded)) &&
		!f.phase.CompareAndSwap(int32(PhaseAction), int32(PhaseEnded)) {
		return // already ended
	}
	d.Fights.Remove(f)
	// Run the teardown on the actor (so clock access is race-free), then stop it.
	posted := f.Post(func(f *Fight) {
		f.stopClock()
		f.stopGrace()
		for _, m := range f.members() {
			if m.Coach == nil {
				continue
			}
			d.World.SetInFight(m.Coach.ID, false)
			if m.Session != nil {
				enter, _ := handshake.EncodeEnterInstance(
					float32(m.Coach.PosX), float32(m.Coach.PosY), m.Coach.PosZ, 0, false)
				_ = m.Session.Send(enter)
			}
		}
		f.stopActor()
	})
	if !posted {
		// Actor already stopped: do the world cleanup directly.
		for _, mem := range f.members() {
			if mem.Coach != nil {
				d.World.SetInFight(mem.Coach.ID, false)
			}
		}
	}
	d.Log.Info("fight ended (teardown)", "id", f.ID)
}

// coachID returns the session's coach id (0 if none).
func coachID(s *Session) uint {
	if s.Coach != nil {
		return s.Coach.ID
	}
	return 0
}

// rosterError carries a roster violation so callers can answer with the retail
// error code the client already knows how to render, instead of a generic
// "unable to create fight".
type rosterError struct{ violation rosterViolation }

func (e rosterError) Error() string { return "illegal roster: " + e.violation.String() }

// Code returns the wire error code for this violation.
func (e rosterError) Code() uint8 { return e.violation.code() }
