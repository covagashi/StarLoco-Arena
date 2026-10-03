package game

import (
	"errors"
	"strings"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store"
)

func registerTeamHandlers(r *Router, d *Deps) {
	r.Register(protocol.OpTeamPresetSave, handleTeamPresetSave)
	r.Register(protocol.OpTeamPresetDelete, handleTeamPresetDelete)
	r.Register(protocol.OpFighterAssignTeam, handleFighterAssignTeam)
}

// handleFighterAssignTeam (6013 C2S: [i64 fighterId][i16 srcTeam][i16 dstTeam][i64 am]).
// The client's qp_1 packet (onFighterDropped / onFighterRemoved) sends this when a
// fighter is dragged between the pool and a team slot, or removed from a slot:
//   - dstTeam == -1  -> remove the fighter from srcTeam
//   - srcTeam == -1  -> the fighter came from the pool (nothing to unlink)
//   - otherwise      -> a move (unlink from srcTeam, link into dstTeam)
//
// am is the owning coach id (1v1) / teammate slot (2v2) and is not needed to
// persist 1v1 membership. Without this handler the packet was silently dropped, so
// team_fighters never persisted and a freshly built team reverted to the pool on
// reopen (the "fighters vanish" report).
func handleFighterAssignTeam(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	// SECURITY: no roster or loadout edits while queued / in a fight. The
	// matchmaker snapshots fighter IDS but the fight re-reads their STATS, so
	// editing while queued swaps a cheap legal roster for an expensive one
	// after pairing. Retail refused this with code 69.
	if s.rosterLocked() {
		return s.refuseRosterEdit("team assign")
	}
	r := protocol.NewReader(f.Payload)
	fid64, err := r.I64()
	if err != nil {
		return err
	}
	srcU, err := r.U16()
	if err != nil {
		return err
	}
	dstU, err := r.U16()
	if err != nil {
		return err
	}
	// am = the coach the client is filing the slot under (own id for 1v1, the
	// teammate's for a 2v2 preset). Unused for persistence — but echoed in the
	// 6014 ack, where the client puts it straight into the preset's
	// fighter->coach map.
	am64, err := r.I64()
	if err != nil {
		return err
	}
	fid := uint(fid64)
	src := int16(srcU)
	dst := int16(dstU)

	// IDOR guard: the coach must own the fighter being assigned.
	roster, err := s.deps.Store.Fighters.ListByCoach(s.Coach.ID)
	if err != nil {
		return err
	}
	var moved *domain.Fighter
	for i := range roster {
		if roster[i].ID == fid {
			moved = &roster[i]
			break
		}
	}
	if moved == nil {
		return nil // not this coach's fighter — ignore
	}

	// Unlink from the source team when the fighter is leaving it.
	if src > 0 && src != dst {
		if t, err := s.deps.Store.Teams.Get(uint(src)); err == nil && t.CoachID == s.Coach.ID {
			if err := s.deps.Store.Teams.RemoveMember(uint(src), fid); err != nil {
				return err
			}
		}
	}

	// Link into the destination team (dst <= 0 is a pure removal to the pool).
	// applied tracks whether the persisted state now matches the request; the
	// 6014 ack goes out only when it does — sending status 0 on a refused add
	// would file the fighter into the client's open preset anyway.
	applied := true
	if dst > 0 {
		applied = false
		if t, err := s.deps.Store.Teams.Get(uint(dst)); err == nil && t.CoachID == s.Coach.ID && canPlaceFighter(t, moved, roster) {
			if err := s.deps.Store.Teams.AddMember(uint(dst), fid); err != nil {
				return err
			}
			applied = true
		}
	}

	s.log.Info("fighter team assignment", "fighter", fid, "src", src, "dst", dst)

	// Ack first so the client performs its own bookkeeping (`dx_2` case 6014:
	// unlink from the src preset, file the fighter under `am` in the open
	// preset, fire the five notifications). aCG is the effective fighter id —
	// we never re-id, so it's fid on an assign and -1 on a removal, the value
	// `sw_1.j` refuses (skipping the re-add for a pure remove).
	if applied {
		aCG := int64(fid)
		if dst <= 0 {
			aCG = -1
		}
		if err := s.sendFighterAssignedTeam(int64(fid), srcU, dstU, am64, aCG); err != nil {
			return err
		}
	}

	// Refresh the client's roster (pool) and team list so slots/pool reconcile.
	if err := s.pushFighterList(); err != nil {
		return err
	}
	return s.pushTeamPresetList()
}

// canPlaceFighter reports whether fighter may be added to team t under the client's
// team-building rules: no duplicate, at most 6 fighters, and at most 2 of the same
// breed. roster is the coach's fighters (for breed lookup of existing members).
// maxTeamMembers and maxSameBreedPerTeam are the retail client's roster rules.
// They were previously inline literals reachable from only one of the two paths
// that build a roster; named here so both use the same numbers.
const (
	maxTeamMembers      = 6
	maxSameBreedPerTeam = 2
)

func canPlaceFighter(t *domain.Team, fighter *domain.Fighter, roster []domain.Fighter) bool {
	if len(t.Members) >= maxTeamMembers {
		return false
	}
	breedByID := make(map[uint]uint8, len(roster))
	for i := range roster {
		breedByID[roster[i].ID] = roster[i].BreedID
	}
	sameBreed := 0
	for _, m := range t.Members {
		if m.FighterID == fighter.ID {
			return false // already on the team
		}
		if breedByID[m.FighterID] == fighter.BreedID {
			sameBreed++
		}
	}
	return sameBreed < maxSameBreedPerTeam
}

// handleTeamPresetSave (6021 C2S: [sw_1 blob][u8 pad]) persists a team preset
// (members scoped to the coach's own fighters) and re-sends the team list.
func handleTeamPresetSave(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	// SECURITY: no roster or loadout edits while queued / in a fight. The
	// matchmaker snapshots fighter IDS but the fight re-reads their STATS, so
	// editing while queued swaps a cheap legal roster for an expensive one
	// after pairing. Retail refused this with code 69.
	if s.rosterLocked() {
		return s.refuseRosterEdit("preset save")
	}
	tp, err := decodeTeamPreset(f.Payload)
	if err != nil {
		return err
	}

	// An empty or unusable preset name is REFUSED rather than silently renamed.
	//
	// The refusal is silent (re-push the authoritative list) because the wire has
	// no status for it: the client checks this LOCALLY - acx_2 shows
	// error.teamManagement.teamNameEmpty itself when its form fails validation and
	// never sends - so 6022 only ever carried "name already exists" (25). Sending
	// 25 here would display "Ce nom d'equipe est deja utilise" for an EMPTY name,
	// which is a wrong message rather than a missing one. Only a modified client
	// can reach this at all.
	presetName, ok := validateTeamName(tp.Name)
	if !ok {
		s.log.Warn("rejected team preset name", "coach", s.Coach.ID, "len", len(tp.Name))
		return s.pushTeamPresetList()
	}

	team := &domain.Team{
		CoachID:  s.Coach.ID,
		Name:     presetName,
		Type:     tp.Type,
		GameMode: tp.GameMode,
		App1:     tp.App[0], App2: tp.App[1], App3: tp.App[2], App4: tp.App[3],
	}
	if tp.TeamID > 0 {
		team.ID = uint(tp.TeamID)
	}
	// Only include fighters the coach actually owns (IDOR guard), and enforce the
	// SAME roster rules the drag-and-drop path enforces.
	//
	// SECURITY: ownership was checked here but nothing else was. 6021 accepted a
	// u8 fighter count, so a hostile client could send the same owned fighter id
	// 255 times and field 255 copies of one fighter against an opponent's 6. Two
	// further consequences made it worse than an unfair roster: WireID is derived
	// as base + fighterID*16 + side*8 + i, so past i=16 the ids collide with
	// another fighter's WireID space and corrupt targeting/HP/turn order, and
	// placement does cells[i%len(cells)], stacking dozens of fighters on one cell.
	//
	// canPlaceFighter (6 members, no duplicate fighter, max 2 per breed) existed
	// and was only ever reached from 6013. The rules are the client's; this path
	// simply never applied them.
	team.Members = s.presetMembers(tp.FighterIDs)
	// Retail refuses a duplicate preset name: the client carries a dedicated
	// status (25) and the string "error.teamManagement.teamNameExist" for it.
	// Without this the save silently succeeded and left the coach with two
	// presets sharing a name, which the team panel then lists twice identically.
	if s.teamNameTaken(team.Name, team.ID) {
		s.log.Info("team preset save refused: duplicate name",
			"coach", s.Coach.ID, "name", team.Name)
		return s.sendTeamPresetSaveError(teamSaveNameExists)
	}
	if err := s.deps.Store.Teams.Upsert(team); err != nil {
		// A team id that is not this coach's (the 6021 IDOR) is a refusal, not a
		// protocol fault: drop the write and re-push the authoritative list so the
		// client's view is corrected. Returning the error here would disconnect,
		// which is the wrong answer for the benign race where a preset was deleted
		// in another session between load and save.
		//
		// There is no S2C status for this. The retail client validates rosters
		// locally (hu_2 shows error.teamManagement.fightersCountExploded itself and
		// never sends), so no "invalid preset" code was ever needed on the wire -
		// the same reason chat flood has no S2C frame. Inventing one would mean
		// authoring player-facing prose the client cannot render.
		if errors.Is(err, store.ErrNotFound) {
			s.log.Warn("team preset save refused: not this coach's team",
				"coach", s.Coach.ID, "team", team.ID)
			return s.pushTeamPresetList()
		}
		return err
	}
	s.log.Info("team preset saved", "name", team.Name, "members", len(team.Members))

	return s.pushTeamPresetList()
}

// handleTeamPresetDelete (6023 C2S: aad_1.encode = [i64 teamId][i16 Gm][i16 fA]).
// The team id is an i64 -- reading it as a u16 (the old bug) only saw the top 2
// zero bytes, so real ids decoded as 0 and the delete silently no-op'd.
func handleTeamPresetDelete(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	id, err := r.I64()
	if err != nil {
		return err
	}
	// r.U16() (Gm) and r.U16() (fA) follow but are unused.
	teamID := uint(id)
	if teamID != 0 {
		if _, err := s.deps.Store.Teams.Delete(teamID, s.Coach.ID); err != nil {
			return err
		}
		s.log.Info("team preset deleted", "id", teamID)
		// Tell the client to drop it. Re-sending the list is NOT enough: 6030
		// merges by preset id and only purges duo presets, so a deleted normal
		// preset would linger on screen until the player relogged.
		if err := s.sendTeamPresetDeleted(uint16(teamID)); err != nil {
			return err
		}
	}
	return s.pushTeamPresetList()
}

// ownedFighterSet returns the set of fighter ids owned by the coach.
func (s *Session) ownedFighterSet() map[uint]bool {
	set := make(map[uint]bool)
	fighters, err := s.deps.Store.Fighters.ListByCoach(s.Coach.ID)
	if err != nil {
		return set
	}
	for _, f := range fighters {
		set[f.ID] = true
	}
	return set
}

// pushTeamPresetList sends TeamPresetList(6030):
// [u8 presetCount]{sw_1 blob} then [u8 coachCount]{...}.
func (s *Session) pushTeamPresetList() error {
	if s.Coach == nil || s.deps == nil || s.deps.Store == nil {
		return nil // no persistence wired (unit harness); nothing to list
	}
	teams, err := s.deps.Store.Teams.ListByCoach(s.Coach.ID)
	if err != nil {
		return err
	}
	fighters, _ := s.deps.Store.Fighters.ListByCoach(s.Coach.ID)
	// Fighter -> owning coach. The second i64 of each preset fighter entry is the
	// OWNER (see encodeTeamPreset), and a 2v2 preset lists the ally's fighters
	// too, so their owner has to be resolved rather than assumed.
	ownerOf := make(map[uint]uint, len(fighters))
	for i := range fighters {
		ownerOf[fighters[i].ID] = fighters[i].CoachID
	}
	for i := range teams {
		if teams[i].AllyCoachID == 0 {
			continue
		}
		allies, err := s.deps.Store.Fighters.ListByCoach(teams[i].AllyCoachID)
		if err != nil {
			continue
		}
		for j := range allies {
			ownerOf[allies[j].ID] = allies[j].CoachID
		}
	}

	// Lead the team list with an EMPTY type=-4 team. The client's Evolution
	// first-open handler (ce_1 case 6030) does an unchecked arrayList.get(0), so
	// the list must be non-empty; but the -4 team must NOT list any fighters —
	// the client's fighter-pool filter (U/Z) hides any fighter that belongs to
	// any team in the 6030, so a populated -4 team makes the Elite roster render
	// empty. The coach's fighters reach the client via 6006 (type=1) only.
	_ = fighters // fighters flow via 6006, not the team list
	w := protocol.NewWriter().U8(uint8(len(teams) + 1))
	w.Raw(benchTeamPreset())
	for i := range teams {
		w.Raw(encodeTeamPreset(&teams[i], ownerOf))
	}
	w.U8(0) // coach section (empty)

	frame, err := protocol.EncodeS2C(protocol.OpTeamPresetList, w.Bytes())
	if err != nil {
		return err
	}
	return s.Send(frame)
}

// sendFighterAssignedTeam acks a 6013 assign/remove (6014 aoi):
// [i8 status][i64 fighterId][i16 srcTeam][i16 dstTeam][i64 am][i64 aCG] — the
// status==0 body is the request echoed plus the effective fighter id aCG.
// `dx_2` unlinks the fighter from preset srcTeam (`at(aCE).l(K)`), re-keys it
// when K != aCG, then files aCG under coach am in the OPEN preset; aCG = -1 is
// the pure-removal sentinel (`sw_1.j` refuses -1, so nothing is re-added).
func (s *Session) sendFighterAssignedTeam(fid int64, src, dst uint16, am, aCG int64) error {
	w := protocol.NewWriter().U8(0).I64(fid).U16(src).U16(dst).I64(am).I64(aCG)
	frame, err := protocol.EncodeS2C(protocol.OpFighterAssignedTeam, w.Bytes())
	if err != nil {
		return err
	}
	return s.Send(frame)
}

// sendTeamPresetDeleted acknowledges a deleted preset (6022 agH):
// [i8 status][i16 teamId], the id present only on success - agH reads it inside
// `if (aV == 0)`, so a failure frame must stop after the status byte.
func (s *Session) sendTeamPresetDeleted(teamID uint16) error {
	w := protocol.NewWriter().U8(0).U16(teamID)
	frame, err := protocol.EncodeS2C(protocol.OpTeamPresetDeleted, w.Bytes())
	if err != nil {
		return err
	}
	return s.Send(frame)
}

// teamSaveNameExists is the client's status for a name already in use; `dx_2`
// case 6020 maps it to "error.teamManagement.teamNameExist".
const teamSaveNameExists uint8 = 25

// teamNameTaken reports whether this coach already has a DIFFERENT preset with
// that name. Renaming a preset to its own current name is not a clash.
func (s *Session) teamNameTaken(name string, selfID uint) bool {
	if name == "" {
		return false
	}
	teams, err := s.deps.Store.Teams.ListByCoach(s.Coach.ID)
	if err != nil {
		return false // a lookup failure must not block a save
	}
	for i := range teams {
		if teams[i].ID != selfID && strings.EqualFold(teams[i].Name, name) {
			return true
		}
	}
	return false
}

// sendTeamPresetSaveError replies to 6021 with a failure. The frame is ONE byte:
// `aic_0` reads the preset only inside `if (aV == 0)`, so appending anything else
// would leave unread bytes on a message the client considers complete.
func (s *Session) sendTeamPresetSaveError(status uint8) error {
	frame, err := protocol.EncodeS2C(protocol.OpTeamPresetSaved,
		protocol.NewWriter().U8(status).Bytes())
	if err != nil {
		return err
	}
	return s.Send(frame)
}

// presetMembers turns a client-supplied fighter-id list into a legal roster:
// owned only, de-duplicated, capped at maxTeamMembers, and at most
// maxSameBreedPerTeam of any one breed. Order is preserved so the player's
// intended slot order survives.
//
// This mirrors canPlaceFighter, which guards the drag-and-drop path (6013). The
// rules are the retail client's own; see handleTeamPresetSave for why applying
// them here matters.
func (s *Session) presetMembers(fighterIDs []int64) []domain.TeamFighter {
	owned := s.ownedFighterSet()

	// Breed lookup for the per-breed cap.
	breedByID := map[uint]uint8{}
	if roster, err := s.deps.Store.Fighters.ListByCoach(s.Coach.ID); err == nil {
		for i := range roster {
			breedByID[roster[i].ID] = roster[i].BreedID
		}
	}

	members := make([]domain.TeamFighter, 0, maxTeamMembers)
	seen := map[uint]bool{}
	perBreed := map[uint8]int{}
	for _, fid := range fighterIDs {
		id := uint(fid)
		switch {
		case !owned[id]:
			continue // not this coach's fighter
		case seen[id]:
			continue // the duplication vector
		case len(members) >= maxTeamMembers:
			continue // roster full
		}
		breed := breedByID[id]
		if perBreed[breed] >= maxSameBreedPerTeam {
			continue
		}
		seen[id] = true
		perBreed[breed]++
		members = append(members, domain.TeamFighter{FighterID: id})
	}
	return members
}
