package game

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"math/rand"
	"strconv"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// ghost.go is async PvP phase 3 (godot/ASYNC-PVP.md, sprints/S12): a coach
// saves a GHOST — a frozen snapshot of their titular line-up plus optional
// gambit rules per fighter — and other coaches fight it while its owner is
// offline. The server AI plays the ghost: its rules first, the archetype AI
// when none applies (runAITurn).
//
// Every fight against a ghost is recorded with its seed and arena
// (ghost_fights), and 60014 can play a recorded one again: the arena comes
// from the seed, not from the global rand, so the same seed, arena and inputs
// give the same fight (the decision-log hash proves it).
//
// Open to every coach since S13. Practice fights; the ghost ladder and the
// fillers are ghost_ladder.go (S14).

// ghostCoachID is the synthetic coach owning every ghost side in a fight, far
// above any real coach id like the other synthetic ones (isSyntheticCoach).
// Using the owner's real id instead would let the post-fight pass write XP,
// wounds and drops into the owner's real fighters.
const ghostCoachID uint = 1<<31 + 2

// ghostWireBase keeps ghost fighters' wire ids in their own range: real
// fighters use FighterWireIDBase + id*16, challenges + challengeID*1024.
const ghostWireBase = FighterWireIDBase + 1<<36

// maxGhostsPerCoach caps the saved ghosts per coach.
const maxGhostsPerCoach = 3

// 60011 actions and result codes.
const (
	ghostActionSave   uint8 = 1
	ghostActionFight  uint8 = 2
	ghostActionDelete uint8 = 3

	ghostOK         uint8 = 0
	ghostNotAllowed uint8 = 1 // not an admin (yet)
	ghostBadRoster  uint8 = 2 // no legal line-up / an unreadable snapshot
	ghostBadRules   uint8 = 3 // a rule set the gambit parser refused
	ghostNotFound   uint8 = 4 // no such ghost / recorded fight
	ghostBusy       uint8 = 5 // already in a fight
	ghostLimit      uint8 = 6 // maxGhostsPerCoach reached
	ghostBadName    uint8 = 7
)

// ghostFightInfo rides on a Fight started against a ghost, for recordGhostFight.
type ghostFightInfo struct {
	ghostID    uint
	challenger uint
	replayOf   uint
}

func registerGhostHandlers(r *Router, _ *Deps) {
	r.Register(protocol.OpGhostSave, handleGhostSave)
	r.Register(protocol.OpGhostListRequest, handleGhostList)
	r.Register(protocol.OpGhostFight, handleGhostFight)
	r.Register(protocol.OpGhostDelete, handleGhostDelete)
	r.Register(protocol.OpGhostLadderRequest, handleGhostLadder)
}

// handleGhostDelete (60015) deletes one of the caller's own ghosts. The fights
// recorded against it stay: they are history, and their ghost id dangles.
func handleGhostDelete(s *Session, frame *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	if !s.ghostAllowed() {
		return s.sendGhostResult(ghostActionDelete, ghostNotAllowed, 0)
	}
	gid, err := protocol.NewReader(frame.Payload).I64()
	if err != nil {
		return err
	}
	g, err := s.deps.Store.Ghosts.Get(uint(gid))
	if err != nil || g == nil || g.CoachID != s.Coach.ID {
		return s.sendGhostResult(ghostActionDelete, ghostNotFound, uint(gid))
	}
	if err := s.deps.Store.Ghosts.Delete(g.ID); err != nil {
		return err
	}
	return s.sendGhostResult(ghostActionDelete, ghostOK, g.ID)
}

func (s *Session) sendGhostResult(action, code uint8, id uint) error {
	w := protocol.NewWriter().U8(action).U8(code).I64(int64(id))
	frame, err := protocol.EncodeS2C(protocol.OpGhostResult, w.Bytes())
	if err != nil {
		return err
	}
	return s.Send(frame)
}

// ghostAllowed: any logged-in coach since S13 (S12 kept it to admins while the
// client had no panel).
func (s *Session) ghostAllowed() bool {
	return s.Coach != nil && s.deps.Store != nil && s.deps.Store.Ghosts != nil
}

// handleGhostSave (60010) snapshots the caller's titular line-up as a ghost.
func handleGhostSave(s *Session, frame *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	if !s.ghostAllowed() {
		return s.sendGhostResult(ghostActionSave, ghostNotAllowed, 0)
	}
	r := protocol.NewReader(frame.Payload)
	name, err := r.StringU8UTF8()
	if err != nil {
		return err
	}
	rules := map[uint][]byte{}
	if n, err := r.U8(); err == nil {
		for i := 0; i < int(n); i++ {
			fid, err := r.I64()
			if err != nil {
				return err
			}
			ln, err := r.U16()
			if err != nil {
				return err
			}
			b, err := r.Bytes(int(ln))
			if err != nil {
				return err
			}
			rules[uint(fid)] = b
		}
	}
	// S22: the line-up itself, after the rules — [u8 m]{[i64 fighterId]}, the
	// Elite team the player picked. Optional, so an older client still saves
	// (its ghost is the Elite titulars).
	var lineup []uint
	if m, err := r.U8(); err == nil {
		for i := 0; i < int(m); i++ {
			fid, err := r.I64()
			if err != nil {
				break
			}
			lineup = append(lineup, uint(fid))
		}
	}
	g, code := s.deps.saveGhostLineup(s.Coach.ID, name, rules, lineup)
	if code != ghostOK {
		return s.sendGhostResult(ghostActionSave, code, 0)
	}
	s.log.Info("ghost saved", "coach", s.Coach.Name, "ghost", g.ID, "name", g.Name)
	return s.sendGhostResult(ghostActionSave, ghostOK, g.ID)
}

// saveGhost validates and stores a ghost for coachID. rules maps one of the
// coach's fighter ids to that fighter's gambit rule set JSON; a fighter that is
// not in the snapshot (benched, over the cap) has its rules dropped — the
// client cannot know exactly which fighters titularRoster keeps.
func (d *Deps) saveGhost(coachID uint, name string, rules map[uint][]byte) (*domain.GhostTeam, uint8) {
	return d.saveGhostLineup(coachID, name, rules, nil)
}

// saveGhostLineup is saveGhost with the fighters to snapshot named (nil =
// the coach's Elite titulars).
func (d *Deps) saveGhostLineup(coachID uint, name string, rules map[uint][]byte, lineup []uint) (*domain.GhostTeam, uint8) {
	if len(name) == 0 || len(name) > 32 {
		return nil, ghostBadName
	}
	if d.Fights.ByCoach(coachID) != nil {
		return nil, ghostBusy
	}
	if n, err := d.Store.Ghosts.CountByCoach(coachID); err != nil || n >= maxGhostsPerCoach {
		return nil, ghostLimit
	}
	roster, sourceIDs, ok := d.ghostSnapshot(coachID, lineup)
	if !ok {
		return nil, ghostBadRoster
	}
	stored := map[string]json.RawMessage{}
	for fid, raw := range rules {
		if _, err := parseGambitRules(raw); err != nil {
			return nil, ghostBadRules
		}
		for idx, src := range sourceIDs {
			if src == fid {
				stored[strconv.Itoa(idx)] = json.RawMessage(raw)
			}
		}
	}
	rosterJSON, err := json.Marshal(roster)
	if err != nil {
		return nil, ghostBadRoster
	}
	rulesJSON, err := json.Marshal(stored)
	if err != nil {
		return nil, ghostBadRules
	}
	g := &domain.GhostTeam{CoachID: coachID, Name: name, Roster: string(rosterJSON),
		Rules: string(rulesJSON), EloGhost: 1000}
	if err := d.Store.Ghosts.Create(g); err != nil {
		d.Log.Warn("ghost save failed", "coach", coachID, "err", err)
		return nil, ghostBadRoster
	}
	return g, ghostOK
}

// ghostSnapshot freezes the coach's titular line-up the way a fight would
// field it: a legal roster, spells filtered for legality, sphere spells added.
// Every id is zeroed so nothing keyed by a fighter id can reach the real rows;
// the second result keeps the source ids, index by index, for the rules.
//
// S22 (no pay-to-win): ghosts fight in the Ranking, so they are ELITE
// fighters only — a Historia fighter would bring its spheres and conditions.
// `lineup` is the team the player picked; empty means the Elite titulars.
func (d *Deps) ghostSnapshot(coachID uint, lineup []uint) ([]domain.Fighter, []uint, bool) {
	var ids []int64
	if len(lineup) > 0 {
		for _, id := range lineup {
			ids = append(ids, int64(id))
		}
	} else {
		ids = d.titulars(coachID, maxTeamMembers, eliteFighter)
	}
	fighters, err := d.Store.Fighters.ListByCoach(coachID)
	if err != nil {
		return nil, nil, false
	}
	byID := map[uint]*domain.Fighter{}
	for i := range fighters {
		byID[fighters[i].ID] = &fighters[i]
	}
	var chosen []*domain.Fighter
	seen := map[uint]bool{}
	for _, id := range ids {
		fr := byID[uint(id)]
		if fr == nil || seen[fr.ID] || fr.IsEvolution() || len(chosen) >= maxTeamMembers {
			continue
		}
		seen[fr.ID] = true
		chosen = append(chosen, fr)
	}
	if len(chosen) == 0 || validateRoster(chosen, false) != rosterOK {
		return nil, nil, false
	}
	out := make([]domain.Fighter, 0, len(chosen))
	src := make([]uint, 0, len(chosen))
	for _, fr := range chosen {
		src = append(src, fr.ID)
		fr = fighterWithSphereSpells(fighterWithLegalSpells(d, fr), d.SphereBoards)
		snap := *fr
		snap.ID, snap.CoachID = 0, 0
		snap.Spells = append([]domain.FighterSpell(nil), fr.Spells...)
		for i := range snap.Spells {
			snap.Spells[i].ID, snap.Spells[i].FighterID = 0, 0
		}
		snap.Objects = append([]domain.FighterObject(nil), fr.Objects...)
		for i := range snap.Objects {
			snap.Objects[i].ID, snap.Objects[i].FighterID = 0, 0
		}
		snap.Conditions = append([]domain.FighterCondition(nil), fr.Conditions...)
		for i := range snap.Conditions {
			snap.Conditions[i].ID, snap.Conditions[i].FighterID = 0, 0
		}
		snap.Spheres = append([]domain.FighterSphere(nil), fr.Spheres...)
		for i := range snap.Spheres {
			snap.Spheres[i].ID, snap.Spheres[i].FighterID = 0, 0
		}
		out = append(out, snap)
	}
	return out, src, true
}

// handleGhostList (60012) answers 60013 with the newest ghosts.
func handleGhostList(s *Session, _ *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	if !s.ghostAllowed() {
		return s.sendGhostResult(ghostActionFight, ghostNotAllowed, 0)
	}
	s.deps.ensureFillerGhosts()
	list, err := s.deps.Store.Ghosts.List(50)
	if err != nil {
		return err
	}
	w := protocol.NewWriter().U16(uint16(len(list)))
	for _, g := range list {
		owner := "" // a filler: the client names it
		if g.CoachID != domain.GhostFillerCoach {
			owner = "?"
			if c, err := s.deps.Store.Coaches.Get(g.CoachID); err == nil && c != nil {
				owner = c.Name
			}
		}
		n := 0
		if full, err := s.deps.Store.Ghosts.Get(g.ID); err == nil {
			var roster []domain.Fighter
			if json.Unmarshal([]byte(full.Roster), &roster) == nil {
				n = len(roster)
			}
		}
		mine := uint8(0)
		if g.CoachID == s.Coach.ID {
			mine = 1
		}
		w.I64(int64(g.ID)).StringU8UTF8(g.Name).StringU8UTF8(owner).
			U8(uint8(n)).I32(g.EloGhost).U8(mine)
	}
	frame, err := protocol.EncodeS2C(protocol.OpGhostList, w.Bytes())
	if err != nil {
		return err
	}
	return s.Send(frame)
}

// handleGhostFight (60014) starts a practice fight of the caller's titular
// line-up against a ghost — or plays a recorded one again, same seed and arena.
func handleGhostFight(s *Session, frame *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	if !s.ghostAllowed() {
		return s.sendGhostResult(ghostActionFight, ghostNotAllowed, 0)
	}
	r := protocol.NewReader(frame.Payload)
	gid, err := r.I64()
	if err != nil {
		return err
	}
	replayOf, _ := r.I64()
	if s.deps.Fights.ByCoach(s.Coach.ID) != nil {
		return s.sendGhostResult(ghostActionFight, ghostBusy, uint(gid))
	}
	if gid == 0 && replayOf == 0 {
		// "Rival automático" (S14): the ghost nearest our rating
		s.deps.ensureFillerGhosts()
		me, err := s.deps.Store.Ghosts.Rating(s.Coach.ID)
		if err != nil {
			return err
		}
		pick := s.deps.pickGhostFor(s.Coach.ID, me.Elo)
		if pick == nil {
			return s.sendGhostResult(ghostActionFight, ghostNotFound, 0)
		}
		gid = int64(pick.ID)
	}
	g, err := s.deps.Store.Ghosts.Get(uint(gid))
	if err != nil || g == nil {
		return s.sendGhostResult(ghostActionFight, ghostNotFound, uint(gid))
	}
	seed := newFightSeed()
	var fightArena *arena
	if replayOf > 0 {
		rec, err := s.deps.Store.Ghosts.GetFight(uint(replayOf))
		if err != nil || rec == nil || rec.GhostID != g.ID {
			return s.sendGhostResult(ghostActionFight, ghostNotFound, uint(gid))
		}
		seed = rec.Seed
		fightArena = s.deps.arenaByID(rec.ArenaID)
	} else {
		fightArena = s.deps.arenaFromSeed(seed)
	}
	roster := s.deps.titularRoster(s.Coach.ID, len(fightArena.team0))
	teamA, err := s.deps.buildFightTeamFor(s, 0, fightArena.team0, roster)
	if err != nil {
		return refuseFightError(err, s)
	}
	teamB, err := s.deps.buildGhostTeam(1, fightArena.startCells(1), g)
	if err != nil {
		s.log.Warn("ghost fight refused: unreadable ghost", "ghost", g.ID, "err", err)
		return s.sendGhostResult(ghostActionFight, ghostBadRoster, g.ID)
	}
	info := &ghostFightInfo{ghostID: g.ID, challenger: s.Coach.ID, replayOf: uint(replayOf)}
	s.log.Info("ghost fight", "coach", s.Coach.Name, "ghost", g.ID, "seed", seed,
		"arena", fightArena.worldID, "replay_of", replayOf)
	if err := s.deps.startFightWithTeamsSeeded(fightArena, teamA, teamB, true, 0, false,
		func(f *Fight) {
			f.seed = seed
			f.ghost = info
		}); err != nil {
		return err
	}
	return s.sendGhostResult(ghostActionFight, ghostOK, g.ID)
}

// arenaFromSeed picks the arena from the fight seed, with its own generator so
// the fight's dice (f.rng, same seed) are not shifted. pickArenaSeating's global
// rand is what made a fight impossible to replay (BACKLOG §4).
func (d *Deps) arenaFromSeed(seed int64) *arena {
	if d == nil {
		return &practiceArena
	}
	r := &d.arenas
	r.mu.RLock()
	defer r.mu.RUnlock()
	if len(r.ids) == 0 {
		return &practiceArena
	}
	rng := rand.New(rand.NewSource(seed ^ 0x5eed_a2e4a))
	return r.cache[r.ids[rng.Intn(len(r.ids))]]
}

// buildGhostTeam fields a ghost: its frozen fighters with their stats computed
// as for a live team, its rules attached, owned by the synthetic ghost coach.
func (d *Deps) buildGhostTeam(side uint8, cells []Pos, g *domain.GhostTeam) (*FightTeam, error) {
	var roster []domain.Fighter
	if err := json.Unmarshal([]byte(g.Roster), &roster); err != nil {
		return nil, err
	}
	if len(roster) == 0 {
		return nil, fmt.Errorf("ghost %d: empty roster", g.ID)
	}
	rules := map[string]json.RawMessage{}
	if g.Rules != "" {
		if err := json.Unmarshal([]byte(g.Rules), &rules); err != nil {
			return nil, err
		}
	}
	coach := &domain.Coach{ID: ghostCoachID, Name: g.Name}
	team := &FightTeam{ID: side, Members: []*FightMember{{Coach: coach}}}
	for i := range roster {
		fr := &roster[i]
		pos := Pos{}
		if len(cells) > 0 {
			pos = cells[i%len(cells)]
		}
		st := computeFighterStatsWithConditions(fr, d.FighterCards, d.Conditions, d.SphereBoards)
		ff := &FightFighter{
			WireID:  ghostWireBase + int64(g.ID)*16 + int64(side)*8 + int64(i),
			CoachID: ghostCoachID,
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
		if raw, ok := rules[strconv.Itoa(i)]; ok {
			if err := ff.setGambitRulesJSON(raw); err != nil {
				// stored rules were validated on save; a vocabulary change since
				// is logged and the fighter plays the archetype AI
				d.Log.Warn("ghost rules refused", "ghost", g.ID, "fighter", i, "err", err)
			}
		}
		team.Fighters = append(team.Fighters, ff)
	}
	return team, nil
}

// decisionHash is the SHA-256 of the fight's decision log, row by row.
func decisionHash(log []fightDecision) string {
	h := sha256.New()
	for _, d := range log {
		fmt.Fprintf(h, "%d|%d|%d|%s|%t|%v|%s\n", d.Round, d.Turn, d.WireID, d.Name,
			d.AI, d.Kind, d.Detail)
	}
	return hex.EncodeToString(h.Sum(nil))
}

// recordGhostFight writes the ghost_fights row for a fight against a ghost.
// Runs on the fight actor from checkFightEnd; failures are logged only.
func (d *Deps) recordGhostFight(f *Fight, winnerTeam int8) {
	if f == nil || f.ghost == nil || d.Store == nil || d.Store.Ghosts == nil {
		return
	}
	rec := &domain.GhostFight{
		GhostID:      f.ghost.ghostID,
		CoachID:      f.ghost.challenger,
		Seed:         f.seed,
		ArenaID:      f.Arena().worldID,
		WinnerTeam:   winnerTeam,
		Rounds:       f.tableTurn,
		DecisionHash: decisionHash(f.decisionLog()),
		ReplayOf:     f.ghost.replayOf,
	}
	if err := d.Store.Ghosts.CreateFight(rec); err != nil {
		d.Log.Warn("ghost fight not recorded", "ghost", rec.GhostID, "err", err)
		return
	}
	d.Log.Info("ghost fight recorded", "id", rec.ID, "ghost", rec.GhostID,
		"seed", rec.Seed, "arena", rec.ArenaID, "winner", rec.WinnerTeam,
		"rounds", rec.Rounds, "hash", rec.DecisionHash[:12])
	if rec.ReplayOf == 0 {
		d.rateGhostFight(rec.GhostID, rec.CoachID, rec.WinnerTeam)
	}
}
