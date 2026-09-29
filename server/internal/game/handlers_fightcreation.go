package game

import (
	"errors"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// registerFightCreationHandlers wires the team-management panel's fight-launch
// buttons: "Tester" (26330, solo practice), "Combattre" (23103, ready-up + pair)
// and the in-fight "Prêt" confirm (26303). The fight engine itself already
// exists; these are the entry points from the panel.
func registerFightCreationHandlers(r *Router, d *Deps) {
	r.Register(protocol.OpTeamTest, handleTeamTest)
	r.Register(protocol.OpClassicReadyForFight, handleClassicReadyForFight)
	r.Register(protocol.OpClassicSearchCancel, handleClassicSearchCancel)
	r.Register(protocol.OpFightReadyConfirm, handleFightReadyConfirm)
}

// modeClassicReady tags "Combattre" searchers in the shared matchmaker queue so
// they only ever pair with each other (never with a 2301 quick-search, whose
// client mode values are small). The value is deliberately out of that range.
const modeClassicReady int16 = 23103

// modeDuoReady is the same queue tag for a 2v2 "Combattre".
//
// A duo must not be matched against a lone coach: the sides would be two coaches
// and two rosters against one, each with its own 6000-point budget. The client
// already treats them as different things - a preset's `zK.cB()` is 1 for an
// ordinary team and 2 for a duo, and the 2VS2 tab lists only the latter - so
// this is not a house rule, it is the client's own distinction carried into the
// queue. The matchmaker pairs only searchers with equal `mode`, so a distinct
// tag is the whole implementation.
const modeDuoReady int16 = 23104

// sparringCoachID is the synthetic id of the "Tester" practice opponent. It is
// far above any real DB coach id, so it never collides with a live coach.
const sparringCoachID uint = 1 << 31

// challengeAcceptBreed is the value the client puts in the SECOND field of 26330
// when the message is an overworld CHALLENGE launch rather than a "Tester"
// practice launch. It is not a teamId at all: the client sets `bM((short)99)`,
// breed 99 = COACH, and puts the challenge id in the first field.
//
// Both the DemonChallenge bubble's "accept" button (pn_0.a(ke)) and the
// BreedMaster's "test this breed" button (zs_1.a(ke)) send this exact shape, and
// both send it with **arch byte 2** rather than the usual 3.
const challengeAcceptBreed uint16 = 99

// handleTeamTest (26330 alv_1: [i32 a][i16 b]) serves two distinct launches,
// told apart by the second field:
//
//   - b != 99 — the team panel's "Tester": an unranked practice fight of the
//     caller's selected team (a = fight type, b = teamId) against a synthetic
//     sparring opponent. A single client can start a fight with no second coach.
//   - b == 99 — an overworld CHALLENGE launch (a = challenge id): the
//     DemonChallenge bubble's "accept" or a BreedMaster's "test this breed".
//     See challengeAcceptBreed and challenge_fights.go.
func handleTeamTest(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	first, err := r.I32() // practice: the fight-type constant (12). challenge: its id.
	if err != nil {
		return err
	}
	teamID, err := r.U16()
	if err != nil {
		return err
	}
	if teamID == challengeAcceptBreed {
		return s.startPvEChallenge(first)
	}
	if s.deps.Fights.ByCoach(s.Coach.ID) != nil {
		return nil // already in a fight
	}
	roster := s.deps.resolveTeamRoster(s.Coach.ID, uint(teamID))
	// A coach with a formed duo brings its ally into the sparring bout too. This
	// is the only 2v2-shaped fight reachable with two players rather than four,
	// which makes it the practical way to exercise a two-coach side.
	seats := 1
	if s.deps.TeamUps != nil && s.deps.TeamUps.Partner(s.Coach.ID) != 0 {
		seats = 2
	}
	fightArena := pickArenaSeating(seats)
	teamA, err := s.deps.buildFightTeamFor(s, 0, fightArena.team0, roster)
	if err != nil {
		return refuseFightError(err, s)
	}
	if s.deps.joinDuoPartner(teamA, s.Coach.ID, fightArena.startCells(0)) {
		s.log.Info("2v2 test fight", "coach", s.Coach.Name,
			"coaches", len(teamA.Members), "fighters", len(teamA.Fighters))
	}
	teamB := buildSparringTeam(1, fightArena.team1[0])
	s.log.Info("team test fight", "coach", s.Coach.Name, "team", teamID, "fighters", len(roster))
	return s.deps.startFightWithTeams(fightArena, teamA, teamB, true, 0, false)
}

// startPvEChallenge launches the scripted PvE fight for an overworld challenge
// (DemonChallenge / BreedMaster). The caller's CURRENT team fights a server-built
// opponent side; the fight is unranked but DOES award the challenge's reward
// cards on victory.
//
// NOT to be confused with Deps.startChallengeFight, which starts a DIRECT
// coach-vs-coach challenge (the 26300-family training invitation).
//
// An unknown challenge id is refused with 26310 rather than ignored: the client
// has already armed its fight handlers by the time it sends 26330, so silence
// would leave it waiting forever.
func (s *Session) startPvEChallenge(challengeID int32) error {
	if s.deps.ChallengeDefs.Get(challengeID) == nil {
		// Either the data table is absent (dev without data/) or the element
		// references a challenge this build does not ship.
		s.log.Warn("challenge fight refused: unknown challenge",
			"coach", s.Coach.Name, "challenge", challengeID,
			"known", s.deps.ChallengeDefs.Len())
		return s.sendFightCreationError(protocol.FightErrUnableToCreate)
	}
	if s.deps.Fights.ByCoach(s.Coach.ID) != nil {
		return nil // already in a fight
	}
	// A challenge launch carries NO teamId — the payload is just the challenge id
	// — so the server picks the roster. Use the coach's titular line-up, which is
	// exactly the "team you play with" the evolution panel manages. (Falling back
	// to resolveTeamRoster's preset lookup would ask for preset id 0, which never
	// exists, and silently hand the coach a single fighter against a whole demon
	// team.)
	fightArena := pickArena()
	roster := s.deps.titularRoster(s.Coach.ID, len(fightArena.team0))
	teamA, err := s.deps.buildFightTeamFor(s, 0, fightArena.team0, roster)
	if err != nil {
		return refuseFightError(err, s)
	}
	teamB := s.deps.buildChallengeTeam(1, fightArena.startCells(1), challengeID, len(teamA.Fighters))
	s.log.Info("challenge fight", "coach", s.Coach.Name, "challenge", challengeID,
		"opponents", len(teamB.Fighters), "opponent", teamB.Coach().Name)
	return s.deps.startFightWithTeams(fightArena, teamA, teamB, true, challengeID, false)
}

// sendFightCreationError sends FIGHT_CREATION_ERROR (26310 nx_1):
// [i64 fightId][i8 errorCode]. It pops the client's pending fight-setup states and
// shows a localized message, so a fight that cannot be started fails visibly
// instead of leaving the client waiting forever.
func (s *Session) sendFightCreationError(code uint8) error {
	w := protocol.NewWriter().I64(0).U8(code)
	frame, err := protocol.EncodeS2C(protocol.OpFightCreationError, w.Bytes())
	if err != nil {
		return err
	}
	return s.Send(frame)
}

// refuseFightError converts a roster refusal into the retail
// FIGHT_CREATION_ERROR (26310) on every session waiting for the fight and
// reports it answered. An illegal roster is a gameplay answer, not a session
// fault: the session loop drops the connection on any propagated error, so
// letting rosterError escape turned a declined launch into a disconnect (for
// every waiting coach, in the two-session paths). Non-roster errors pass
// through unchanged — real infrastructure failures still propagate.
func refuseFightError(err error, sessions ...*Session) error {
	var re rosterError
	if !errors.As(err, &re) {
		return err
	}
	for _, s := range sessions {
		if s != nil {
			_ = s.sendFightCreationError(re.Code())
		}
	}
	return nil
}

// handleClassicReadyForFight (23103 atj_0: [i64 coachId][i16 teamId]) is the
// "Combattre" ready-up: the coach declares its team ready and is paired with the
// next coach that does the same. When paired the fight starts immediately — there
// is no accept prompt — otherwise the coach waits in the queue.
//
// While waiting, the client shows the "Recherche en cours……" overlay, but ONLY
// once we accept the search with 23104. An earlier version of this comment said
// the client showed "waitingForOpponentCoach" by itself; that was wrong — that
// string belongs to the fight-INVITATION flow (`B`, `aqr_0`), not here. Without
// 23104 the player got no overlay, no feedback and, since the Cancel button lives
// inside that overlay, **no way to leave the queue**. Same defect as B-098 in the
// evolution twin, and the same fix.
//
// Unlike the evolution preset (a synthetic 99), the i16 here is a real team id —
// and may be -1 ("no preset selected", `hu_2:969-973`), which arrives as 65535
// and resolves to no roster. That is tolerated, not refused: buildFightTeamFor
// falls back to the coach's own fighters, which is the long-standing behaviour of
// this path and not something to tighten while fixing the overlay.
func handleClassicReadyForFight(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	// That i64 is NOT "the team owner, trust the session", which is what this
	// used to assume before discarding it. `hu_2.a(zK)` fills it from
	// `zK3.afG()` - the preset's stored ALLY - and only falls back to the local
	// coach when afG is -1. On a 2v2 preset (`zK.cB() == 2`, which is also what
	// makes the client show "waitingReplyForFight") it is the partner's coach id,
	// so throwing it away threw away the entire second half of the fight.
	//
	// It is still not trusted: it only selects between "this is a duo launch" and
	// "this is a solo launch", and the partner itself is re-derived from the duo
	// the server formed.
	claimedAlly, err := r.I64()
	if err != nil {
		return err
	}
	teamID, err := r.U16()
	if err != nil {
		return err
	}
	if s.deps.Fights.ByCoach(s.Coach.ID) != nil {
		return classicSearchFamily.sendError(s, searchErrCannotStart)
	}
	// A duo launch: both partners must press Combattre before the pair enters the
	// queue, which is exactly what the client's own "waitingReplyForFight" dialog
	// tells the first one to expect. Queueing on the first press would drag the
	// ally into a fight it never agreed to start.
	searchMode := modeClassicReady
	if partner := s.deps.duoLaunchPartner(s.Coach.ID, claimedAlly); partner != 0 {
		searchMode = modeDuoReady
		ready, both := s.deps.TeamUps.markLaunchReady(s.Coach.ID, partner)
		if err := classicSearchFamily.sendResult(s, teamID, true); err != nil {
			return err
		}
		if !both {
			s.log.Info("2v2 combattre: waiting for ally", "coach", s.Coach.Name, "ally", partner)
			return nil
		}
		s.log.Info("2v2 combattre: both ready", "coach", s.Coach.Name, "ally", partner, "ready", ready)
		// Fall through: the duo queues ONCE, under this coach. joinDuoPartner
		// merges the ally in when the fight is built.
	}
	roster := s.deps.resolveTeamRoster(s.Coach.ID, uint(teamID))

	// Clicking "Combattre" twice must not put the coach in the queue twice.
	s.deps.Matchmaker.CancelSearch(s.Coach.ID)

	if err := classicSearchFamily.sendResult(s, teamID, true); err != nil {
		return err
	}
	pm := s.deps.Matchmaker.Search(s, searchMode, 0, roster)
	if pm == nil {
		s.log.Info("combattre: waiting for opponent", "coach", s.Coach.Name, "team", teamID)
		return nil
	}
	// Paired: the ready-room bypasses the accept handshake, so drop the pending
	// match from the matchmaker and start the fight now.
	s.deps.Matchmaker.Discard(pm)
	s.log.Info("combattre: paired -> starting fight",
		"a", pm.a.session.Coach.Name, "b", pm.b.session.Coach.Name)
	announceFightStarting(classicSearchFamily, pm)
	return s.deps.startFight(pm)
}

// handleClassicSearchCancel (23101 bm_1: [i64 coachId][i16 teamId]) is the
// classic overlay's Cancel button (Lua dofusarena.classicSearchStatus:
// cancelSearch, which sends the coach id and preset it stashed in mh_1). The
// reply is what closes the overlay, so it goes out even if nothing was queued.
func handleClassicSearchCancel(s *Session, _ *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	if s.deps.Matchmaker.CancelSearch(s.Coach.ID) {
		s.log.Info("combattre: search cancelled", "coach", s.Coach.Name)
	}
	return classicSearchFamily.sendCancelResult(s, true)
}

// handleFightReadyConfirm (26303 bl_1: [i64 coachId][i16 teamId]) serves two
// contexts, distinguished by whether the coach is already in a fight:
//   - IN a fight (post-CREATE_FIGHT): the in-fight "Prêt" — treat as
//     ready-for-placement so a confirmed team advances out of presentation
//     immediately instead of waiting for the clock.
//   - NOT in a fight, but in an ACCEPTED direct challenge: the team-select panel's
//     "Combattre" — record this coach's chosen team; once BOTH challengers have
//     confirmed, the fight starts (see startChallengeFight).
func handleFightReadyConfirm(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	if s.deps.Fights.ByCoach(s.Coach.ID) != nil {
		return handleReadyForPlacement(s, nil) // already in a fight → in-fight ready
	}
	if s.deps.Challenges.Get(s.Coach.ID) == nil {
		return nil // no fight, no challenge → nothing to confirm
	}
	r := protocol.NewReader(f.Payload)
	if _, err := r.I64(); err != nil { // team-owner coach id (trust the session)
		return err
	}
	teamID, err := r.U16()
	if err != nil {
		return err
	}
	c, both := s.deps.Challenges.ConfirmTeam(s.Coach.ID, int16(teamID))
	if c == nil || !both {
		return nil // waiting for the other coach to confirm
	}
	s.log.Info("challenge teams confirmed -> starting fight",
		"a", c.challenger.Coach.Name, "b", c.target.Coach.Name)
	return s.deps.startChallengeFight(c)
}

// titularRoster returns up to max of a coach's TITULAR fighters (state 0) — the
// starting line-up, excluding benched, dead, interred and legendary-slot
// fighters. Used when the client asks for a fight without naming a team preset
// (overworld challenges). Order is the store's, so it is stable across runs.
// Returns nil when the coach has none, letting buildFightTeamFor fall back.
func (d *Deps) titularRoster(coachID uint, max int) []int64 {
	fighters, err := d.Store.Fighters.ListByCoach(coachID)
	if err != nil {
		return nil
	}
	ids := make([]int64, 0, max)
	perBreed := map[uint8]int{}
	for i := range fighters {
		if fighters[i].State != domain.FighterStateTitular {
			continue
		}
		if len(ids) >= max {
			break
		}
		// The SERVER picks this lineup, so pick a legal one: a titular list
		// holding a third fighter of one breed is a state the retail client
		// cannot reach (the roster UI enforces the cap), but a dev database
		// can. Returning it wholesale makes every challenge launch refuse at
		// validateRoster; leaving the extra fighters out lets the fight run.
		if perBreed[fighters[i].BreedID] >= maxSameBreedPerTeam {
			continue
		}
		perBreed[fighters[i].BreedID]++
		ids = append(ids, int64(fighters[i].ID))
	}
	if len(ids) == 0 {
		return nil
	}
	return ids
}

// resolveTeamRoster returns the fighter ids of a coach's saved team preset,
// IDOR-guarded (the preset must belong to coachID). Returns nil if the preset is
// unknown or owned by someone else; callers fall back to the coach's own roster.
func (d *Deps) resolveTeamRoster(coachID, teamID uint) []int64 {
	t, err := d.Store.Teams.Get(teamID)
	if err != nil || t.CoachID != coachID {
		return nil
	}
	ids := make([]int64, 0, len(t.Members))
	for _, m := range t.Members {
		ids = append(ids, int64(m.FighterID))
	}
	return ids
}

// buildSparringTeam creates the synthetic practice opponent for a "Tester"
// fight: one placeholder fighter and a coach that is never persisted and holds
// no session (so it is excluded from all world/session I/O and reward logic).
func buildSparringTeam(side uint8, anchor Pos) *FightTeam {
	coach := &domain.Coach{ID: sparringCoachID, Name: "Sparring"}
	fr := &domain.Fighter{Name: "Sparring", BreedID: 1}
	st := computeFighterStats(fr, nil) // synthetic opponent: breed base, no cards
	ff := &FightFighter{
		WireID:  FighterWireIDBase + int64(side)*8, // pseudo fighter id 0; never a real fighter
		CoachID: sparringCoachID,
		TeamID:  side,
		Fighter: fr,
		Pos:     anchor,
		MaxHP:   st.MaxHP, HP: st.MaxHP,
		MaxAP: st.MaxAP, AP: st.MaxAP,
		MaxMP: st.MaxMP, MP: st.MaxMP,
		Init: st.Init, Range: st.Range,
		CritRate: st.CritRate, FumbleRate: st.FumbleRate,
		Block: st.Block, Dodge: st.Dodge,
	}
	return &FightTeam{ID: side, Members: []*FightMember{{Coach: coach}}, Fighters: []*FightFighter{ff}}
}
