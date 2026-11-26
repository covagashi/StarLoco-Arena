package game

import (
	"strings"
	"sync"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// 2v2 team formation.
//
// This is the PRODUCTION path, and it is not the one item 33's opcodes describe.
// The team panel's "Creer une equipe 2VS2" (hu_2 case 16636) opens
// team2vs2NameDialog, the teammate is chosen from the coach's own FRIEND LIST
// (case 16635, built from mc_1.qM().qN()), and the named pair goes out as 6024.
// The 26313 "XvsXInvitation" request is a different thing entirely: its only
// builder is a binding in the client's `Test` Lua library, with no UI.
//
// The handshake:
//
//	6024 C2S  inviter -> server   [u8 teamName][i64 inviterId][i64 invitedId]
//	6025 S2C  server  -> invited  [u8 teamName][u8 inviterName][i64 inviterId][i64 invitedId]
//	6026 C2S  invited -> server   [i8 accept][u8 teamName][i64 inviterId][i64 invitedId][i16 reason]
//	6027 S2C  server  -> inviter  (empty) "Le coach a refuse la creation, ou est indisponible."
//	6028 S2C  server  -> both     (empty) both clients open the fighter picker
//
// The client auto-refuses on the invited side when it is already in a team or
// the inviter is on its ignore list (ug_1 case 6025 / lg_0 case 6025), sending
// 6026 with accept=0 and reason=2. The server enforces the same rules anyway:
// the client's checks protect the client's UX, not the server's state, and 6024
// is a bare pair of ids that anyone can craft.

// teamUpPair is a formed 2v2 duo, held until it is spent on a fight.
type teamUpPair struct {
	Name      string
	InviterID uint
	InvitedID uint
	// ready tracks which members have pressed Combattre. Guarded by teamUps.mu.
	ready map[uint]bool
}

// pendingTeamUp is an invitation awaiting the invited coach's answer.
type pendingTeamUp struct {
	Name      string
	InviterID uint
}

// teamUps holds pending 2v2 invitations and the duos that came out of them.
//
// Deliberately in memory rather than in the store: a duo is a lobby-lived
// arrangement (both clients sit on the fighter picker with it), and neither the
// client nor the protocol offers any way to resume one across a reconnect - the
// invitation dialog is modal and dies with the session.
type teamUps struct {
	mu      sync.Mutex
	pending map[uint]pendingTeamUp // invited coach id -> invitation
	pairs   map[uint]*teamUpPair   // EACH member's coach id -> the shared duo
}

func newTeamUps() *teamUps {
	return &teamUps{
		pending: map[uint]pendingTeamUp{},
		pairs:   map[uint]*teamUpPair{},
	}
}

func (t *teamUps) invite(invited uint, p pendingTeamUp) {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.pending[invited] = p // one pending invitation per coach; a newer one wins
}

// takePending removes and returns the invitation held for invited, if the
// inviter matches. Matching on the inviter is what stops a crafted 6026 from
// consuming an invitation that came from somebody else.
func (t *teamUps) takePending(invited, inviter uint) (pendingTeamUp, bool) {
	t.mu.Lock()
	defer t.mu.Unlock()
	p, ok := t.pending[invited]
	if !ok || p.InviterID != inviter {
		return pendingTeamUp{}, false
	}
	delete(t.pending, invited)
	return p, true
}

func (t *teamUps) bind(p *teamUpPair) {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.pairs[p.InviterID] = p
	t.pairs[p.InvitedID] = p
}

// PairOf returns the duo coachID belongs to, or nil.
func (t *teamUps) PairOf(coachID uint) *teamUpPair {
	t.mu.Lock()
	defer t.mu.Unlock()
	return t.pairs[coachID]
}

// release drops the duo both members share.
func (t *teamUps) release(coachID uint) {
	t.mu.Lock()
	defer t.mu.Unlock()
	p := t.pairs[coachID]
	if p == nil {
		return
	}
	delete(t.pairs, p.InviterID)
	delete(t.pairs, p.InvitedID)
}

// Partner returns the other member of coachID's duo (0 if it has none).
func (t *teamUps) Partner(coachID uint) uint {
	p := t.PairOf(coachID)
	if p == nil {
		return 0
	}
	if p.InviterID == coachID {
		return p.InvitedID
	}
	return p.InviterID
}

func registerTeamUpHandlers(r *Router, d *Deps) {
	r.Register(protocol.OpTeamUpRequest, handleTeamUpRequest)
	r.Register(protocol.OpTeamUpAnswer, handleTeamUpAnswer)
}

// teamUpName trims a client-supplied team name to something safe to echo.
//
// The name goes straight back out in 6025, which the invited client renders
// into a dialog, and the chat renderer parses markup without escaping it (see
// B-104) - so the same stripping applies here.
func teamUpName(s string) string {
	s = strings.ReplaceAll(s, "<", "")
	s = strings.ReplaceAll(s, ">", "")
	s = strings.TrimSpace(s)
	if len(s) > 32 {
		s = s[:32]
	}
	if s == "" {
		s = "2vs2"
	}
	return s
}

// handleTeamUpRequest handles 6024 (ir_0): the inviter names a duo and picks a
// teammate from its friend list.
func handleTeamUpRequest(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	name, err := r.StringU8()
	if err != nil {
		return nil
	}
	if _, err = r.I64(); err != nil { // the inviter id the client sends
		return nil
	}
	invitedID64, err := r.I64()
	if err != nil {
		return nil
	}
	// The inviter is the SENDER, never the id in the packet: trusting that field
	// would let anyone open invitations in another coach's name.
	inviter := s.Coach
	invited := uint(invitedID64)

	if why := s.deps.teamUpRefusal(inviter.ID, invited); why != "" {
		// Log it. A silent refusal is indistinguishable from a packet that never
		// arrived, which cost two live debugging sessions: the client shows only
		// "Le coach a refuse la creation, ou est indisponible." for every cause.
		s.log.Info("2v2 invitation refused", "from", inviter.Name,
			"invitedRaw", invitedID64, "invited", invited, "why", why)
		return s.sendEmpty(protocol.OpTeamUpRefused)
	}
	target := s.deps.sessionForCoach(invited)
	if target == nil || target.Coach == nil {
		s.log.Info("2v2 invitation refused", "from", inviter.Name,
			"invitedRaw", invitedID64, "invited", invited, "why", "target vanished")
		return s.sendEmpty(protocol.OpTeamUpRefused)
	}

	name = teamUpName(name)
	s.deps.TeamUps.invite(invited, pendingTeamUp{Name: name, InviterID: inviter.ID})

	w := protocol.NewWriter()
	w.StringU8(name)
	w.StringU8(inviter.Name)
	w.I64(int64(inviter.ID))
	w.I64(int64(invited))
	frame, err := protocol.EncodeS2C(protocol.OpTeamUpInvitation, w.Bytes())
	if err != nil {
		return err
	}
	s.log.Info("2v2 invitation", "from", inviter.Name, "to", target.Coach.Name, "team", name)
	return target.Send(frame)
}

// teamUpAllowed reports whether a duo may form.
func (d *Deps) teamUpAllowed(inviter, invited uint) bool {
	return d.teamUpRefusal(inviter, invited) == ""
}

// teamUpRefusal re-derives every rule the client applies before offering the
// invitation, plus the ones it cannot know about, and NAMES the one that fails.
//
// It returns a reason rather than a bool because the client renders one message
// for all of them ("Le coach a refuse la creation, ou est indisponible."), so
// the server log is the only place the real cause can ever be seen.
func (d *Deps) teamUpRefusal(inviter, invited uint) string {
	if invited == 0 {
		// Usually the friend-list id: an entry for a friend that was offline when
		// the list was built carries -1, which arrives here as a huge uint.
		return "invited id is zero"
	}
	if invited == inviter {
		return "self-invitation" // "Impossible de faire un combat avec soi-meme !"
	}
	// Neither side may already be committed: to a fight, or to another duo.
	if d.Fights != nil {
		if d.Fights.ByCoach(inviter) != nil {
			return "inviter is already fighting"
		}
		if d.Fights.ByCoach(invited) != nil {
			return "invited coach is already fighting"
		}
	}
	if d.TeamUps.PairOf(inviter) != nil {
		return "inviter is already in a duo"
	}
	if d.TeamUps.PairOf(invited) != nil {
		return "invited coach is already in a duo"
	}
	// The invited coach must be online, and must not have ignored the inviter -
	// the same rule the client applies locally (ug_1 checks its ignore map before
	// even showing the dialog), enforced here because a crafted 6024 never asks.
	target := d.sessionForCoach(invited)
	if target == nil || target.Coach == nil {
		return "invited coach is not online (or the id does not exist)"
	}
	if ignoresCoach(target.Coach, inviter) {
		return "invited coach ignores the inviter"
	}
	return ""
}

// handleTeamUpAnswer handles 6026 (abB): accept or refuse an invitation.
func handleTeamUpAnswer(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	accept, err := r.U8()
	if err != nil {
		return nil
	}
	name, err := r.StringU8()
	if err != nil {
		return nil
	}
	inviterID64, err := r.I64()
	if err != nil {
		return nil
	}
	// The remaining [i64 invitedId][i16 reason] are echoed back by the client and
	// carry nothing the server does not already know.

	inviter := uint(inviterID64)
	pending, ok := s.deps.TeamUps.takePending(s.Coach.ID, inviter)
	if !ok {
		// "Pas d'invitation trouvee" - answer nothing rather than inventing a duo.
		return nil
	}
	inviterSess := s.deps.sessionForCoach(inviter)

	if accept == 0 {
		s.log.Info("2v2 invitation refused", "by", s.Coach.Name, "inviter", inviter)
		if inviterSess != nil {
			return inviterSess.sendEmpty(protocol.OpTeamUpRefused)
		}
		return nil
	}
	// Re-check on ACCEPT as well: the invitation may have been sitting in a
	// dialog while the inviter started a fight or formed another duo.
	if inviterSess == nil || !s.deps.teamUpAllowed(inviter, s.Coach.ID) {
		if inviterSess != nil {
			_ = inviterSess.sendEmpty(protocol.OpTeamUpRefused)
		}
		return s.sendEmpty(protocol.OpTeamUpRefused)
	}

	if name == "" {
		name = pending.Name
	}
	pair := &teamUpPair{Name: teamUpName(name), InviterID: inviter, InvitedID: s.Coach.ID}
	s.deps.TeamUps.bind(pair)
	s.log.Info("2v2 team formed", "team", pair.Name, "inviter", inviter, "invited", s.Coach.ID)

	// Give BOTH coaches a real 2v2 team preset naming the other as its ally.
	// Without one the 2VS2 tab has nothing to show and its "Combattre" has
	// nothing to launch: the duo would exist server-side and be invisible.
	s.deps.createDuoPresets(pair)

	// Both clients open the fighter picker on 6028.
	if err := inviterSess.sendEmpty(protocol.OpTeamUpAccepted); err != nil {
		return err
	}
	if err := s.sendEmpty(protocol.OpTeamUpAccepted); err != nil {
		return err
	}
	// Push the refreshed preset lists so the new team appears in both panels.
	_ = inviterSess.pushTeamPresetList()
	return s.pushTeamPresetList()
}

// createDuoPresets gives each member of a duo a GameMode-2 team preset whose
// coach list names its partner.
//
// One preset per coach, not one shared row: each side owns its own fighters and
// its own slot in its own panel, and the client reads the preset out of the list
// it was sent. Existing presets for the same pair are reused so pressing accept
// twice does not litter the panel.
func (d *Deps) createDuoPresets(p *teamUpPair) {
	if d.Store == nil || p == nil {
		return
	}
	for _, side := range [2][2]uint{{p.InviterID, p.InvitedID}, {p.InvitedID, p.InviterID}} {
		owner, ally := side[0], side[1]
		existing, err := d.Store.Teams.ListByCoach(owner)
		if err != nil {
			continue
		}
		var found *domain.Team
		for i := range existing {
			if existing[i].AllyCoachID == ally && existing[i].GameMode == gameMode2v2 {
				found = &existing[i]
				break
			}
		}
		team := &domain.Team{
			CoachID: owner, Name: p.Name,
			Type: duoTeamType, GameMode: gameMode2v2, AllyCoachID: ally,
		}
		if found != nil {
			team.ID = found.ID
		}
		// The team must field at least one fighter FROM EACH coach: sw_1.afH()
		// walks the preset's coach list and requires every one of them to control
		// a fighter in it. Seed one titular fighter per side; the players re-pick
		// from there in the panel.
		team.Members = duoStartingMembers(d, owner, ally)
		if err := d.Store.Teams.Upsert(team); err != nil {
			d.Log.Warn("2v2 preset save failed", "coach", owner, "err", err)
		}
	}
}

// duoStartingMembers picks one titular fighter from each coach so a fresh duo
// preset is immediately valid.
//
// A 2v2 preset that lists only its owner's fighters can never be launched:
// sw_1.afH() requires EVERY coach in the preset's coach list to control at least
// one fighter in it, and the client decides ownership from the second i64 of
// each fighter entry - which encodeTeamPreset now fills with the real owner.
// Benched fighters are skipped: the panel will not field them.
func duoStartingMembers(d *Deps, owner, ally uint) []domain.TeamFighter {
	var out []domain.TeamFighter
	for _, coach := range []uint{owner, ally} {
		fighters, err := d.Store.Fighters.ListByCoach(coach)
		if err != nil {
			continue
		}
		for i := range fighters {
			if fighters[i].State != domain.FighterStateTitular {
				continue
			}
			out = append(out, domain.TeamFighter{FighterID: fighters[i].ID})
			break
		}
	}
	return out
}

// gameMode2v2 is the client's zK.cB() value for a two-coach team. It is what
// makes the client show "waitingReplyForFight" when the team is launched.
const gameMode2v2 int16 = 2

// duoTeamType is the preset TYPE a duo carries: the same -6 the client stamps on
// every team a player creates by hand (hu_2 case 16632).
//
// A 2v2 preset is not a different KIND of team. `zK.cG(coachId)` appends to the
// preset's coach list, and a hand-made team calls it once with its own owner -
// so an ordinary team is [self] (size 1) and a duo is [ally, self] (size 2).
// That size is the entire difference: `sw_1.afL()` is `bMK.size() == 2`, and the
// 2VS2 tab lists exactly the presets where it holds.
//
// Type 0 - what these presets used to carry - is not a type the client stamps on
// anything. It is excluded from the 1v1 bucket (which wants -6) and skips the
// appearance bytes that only -5/-6/-7 carry, so the row had no icon to draw.
const duoTeamType int16 = -6

// duoLaunchPartner returns the partner id when a 23103 "Combattre" is a DUO
// launch, or 0 when it is an ordinary solo one.
//
// The client's id is only a hint: it is accepted solely when the server's own
// duo registry agrees that these two are partners. A crafted 23103 naming a
// stranger therefore launches a normal solo fight rather than dragging that
// stranger in.
func (d *Deps) duoLaunchPartner(self uint, claimed int64) uint {
	if claimed <= 0 || uint(claimed) == self {
		return 0 // afG == -1 (no ally) or the client's own fallback to self
	}
	partner := d.partnerOf(self)
	if partner == 0 || partner != uint(claimed) {
		return 0
	}
	return partner
}

// partnerOf resolves a coach's 2v2 ally: the live invitation registry first, then
// the persisted preset.
//
// The registry only exists to run the invitation handshake and dies with the
// process. The PRESET is the durable record - it is what the client lists in its
// 2VS2 tab and what it names when launching - so a duo formed yesterday, or one
// that outlived a restart, must still be launchable today. Falling back to it
// also means the pair does not have to be re-invited after every server bounce.
func (d *Deps) partnerOf(self uint) uint {
	if d.TeamUps != nil {
		if p := d.TeamUps.Partner(self); p != 0 {
			return p
		}
	}
	if d.Store == nil {
		return 0
	}
	teams, err := d.Store.Teams.ListByCoach(self)
	if err != nil {
		return 0
	}
	for i := range teams {
		if teams[i].GameMode == gameMode2v2 && teams[i].AllyCoachID != 0 {
			return teams[i].AllyCoachID
		}
	}
	return 0
}

// markLaunchReady records that a duo member pressed Combattre, returning how
// many of the pair are ready and whether that is both.
func (t *teamUps) markLaunchReady(self, partner uint) (int, bool) {
	t.mu.Lock()
	defer t.mu.Unlock()
	p := t.pairs[self]
	if p == nil {
		// The duo came from a persisted preset rather than a live invitation
		// (a restart, or a pair formed in an earlier session). Adopt it so the
		// two-presses-to-launch gate still works.
		p = &teamUpPair{InviterID: self, InvitedID: partner}
		t.pairs[self] = p
		t.pairs[partner] = p
	}
	if p.ready == nil {
		p.ready = map[uint]bool{}
	}
	p.ready[self] = true
	n := len(p.ready)
	return n, p.ready[self] && p.ready[partner]
}

// joinDuoPartner adds the coach's 2v2 partner to a side that has already been
// built for the coach itself, so one fight carries both allies.
//
// The partner's fighters are placed on the start cells the first coach did not
// use. A side has 8 start cells on most arenas (34 of 47), so two six-fighter
// rosters cannot both fit whole - the partner takes what is left, which is the
// same clamp the single-coach path already applies.
//
// Returns true if a partner was actually added. It is deliberately quiet when
// there is no duo, no online partner, or no room: a 2v2 that cannot be seated
// degrades to the 1v1 that was already valid rather than failing the fight.
func (d *Deps) joinDuoPartner(team *FightTeam, ownerID uint, cells []Pos) bool {
	if team == nil || d.TeamUps == nil {
		return false
	}
	partnerID := d.partnerOf(ownerID)
	if partnerID == 0 {
		return false
	}
	ps := d.sessionForCoach(partnerID)
	if ps == nil || ps.Coach == nil {
		return false
	}
	// SECURITY: never drag a partner who is already busy.
	//
	// partnerOf falls back to the PERSISTED 2v2 preset, so a duo formed once (or
	// restored across a restart) let the owner pull the partner into a fight at
	// will by pressing "Tester". Worse, FightManager.Create overwrites
	// byCoach[partner] unconditionally - so if the partner was already fighting,
	// their inputs started routing to the new fight and they received a
	// CREATE_FIGHT on top of a live one. Repeatable = denial of play against one
	// named player.
	//
	// The 23103 path was deliberately gated for exactly this ("queueing on the
	// first press would drag the ally into a fight it never agreed to start");
	// 26330 did what that comment forbids.
	if d.Fights != nil && d.Fights.ByCoach(partnerID) != nil {
		return false
	}
	if d.Matchmaker != nil && d.Matchmaker.IsBusyMatchmaking(partnerID) {
		return false
	}
	free := len(cells) - len(team.Fighters)
	if free <= 0 {
		return false
	}
	spare := cells[len(team.Fighters):]
	partner, err := d.buildFightTeamFor(ps, team.ID, spare, nil)
	if err != nil || partner == nil || len(partner.Members) == 0 {
		return false
	}
	team.Members = append(team.Members, partner.Members...)
	team.Fighters = append(team.Fighters, partner.Fighters...)
	return true
}

// sendEmpty sends a payload-less S2C frame.
func (s *Session) sendEmpty(opcode uint16) error {
	frame, err := protocol.EncodeS2C(opcode, nil)
	if err != nil {
		return err
	}
	return s.Send(frame)
}

// releaseTeamUpAndNotify breaks a 2v2 pairing when one member leaves, and TELLS
// the other half (6029).
//
// Every other pairing in the session teardown already notifies its counterparty -
// matchmaking, direct challenges, exchanges - but the team-up did not, so a
// partner dropping during team formation left the other player sitting in the
// fighter picker waiting for someone who was already gone.
//
// 6029 carries one byte and `dx_2` shows "error.teamManagement.coachDisconnected"
// whatever its value: the opcode is the message.
func (d *Deps) releaseTeamUpAndNotify(coachID uint) {
	if d.TeamUps == nil {
		return
	}
	partner := d.TeamUps.Partner(coachID)
	if partner == 0 {
		return
	}
	d.TeamUps.release(coachID)
	other := d.sessionForCoach(partner)
	if other == nil {
		// Nobody left to tell; the pairing is broken either way. Logged because
		// "no partner online" and "never ran" are indistinguishable otherwise, and
		// that ambiguity cost a live debugging session.
		if d.Log != nil {
			d.Log.Debug("2v2 partner gone, nobody to notify", "leaver", coachID, "partner", partner)
		}
		return
	}
	if d.Log != nil {
		d.Log.Info("2v2 partner gone", "leaver", coachID, "notified", partner)
	}
	frame, err := protocol.EncodeS2C(protocol.OpTeamUpCoachGone,
		protocol.NewWriter().U8(0).Bytes())
	if err != nil {
		return
	}
	_ = other.Send(frame)
}
