package game

import (
	"errors"
	"strings"
	"sync"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store"
)

// Guild ("clan") handlers.
//
// The client drives this feature almost entirely by asking: opening the social
// window sends 519 then 517 unprompted, and accepting an invitation makes it send
// 519 again. So most of the work here is answering questions accurately; only
// create/invite/answer change state.

// minGuildNameLen mirrors the client's own creation dialog, which will not submit
// a shorter name. Enforced here too because the dialog is not the only way to
// reach 509.
const minGuildNameLen = 5

// Default rank names for a new guild. The client ships no default text for these
// - it renders whatever the server stores - so they are the server's choice, kept
// in the game's own language.
const (
	defaultLeaderRankName = "Chef"
	defaultMemberRankName = "Membre"
)

// pendingGuildInvite is one outstanding invitation. The client's answer (503)
// identifies it only by the inviter's and guild's NAMES, so that is the key.
type pendingGuildInvite struct {
	guildID     uint
	inviterName string
	guildName   string
	guildType   uint8
}

// guildInvites holds outstanding invitations per invited coach.
//
// In memory rather than persisted, deliberately: an invitation is a live
// conversation between two connected players, and one that outlived a restart
// would let a coach join a guild whose inviter has long since lost the right to
// invite - with no way for either side to see it was still pending.
type guildInvites struct {
	mu sync.Mutex
	by map[uint][]pendingGuildInvite // invited coach id -> invitations
}

func newGuildInvites() *guildInvites { return &guildInvites{by: map[uint][]pendingGuildInvite{}} }

func (g *guildInvites) add(target uint, inv pendingGuildInvite) {
	g.mu.Lock()
	defer g.mu.Unlock()
	for _, existing := range g.by[target] {
		if existing.guildID == inv.guildID {
			return // already pending for this guild; do not stack duplicates
		}
	}
	g.by[target] = append(g.by[target], inv)
}

// take removes and returns the invitation matching the names the client echoed.
func (g *guildInvites) take(target uint, inviterName, guildName string) (pendingGuildInvite, bool) {
	g.mu.Lock()
	defer g.mu.Unlock()
	list := g.by[target]
	for i, inv := range list {
		if strings.EqualFold(inv.inviterName, inviterName) && strings.EqualFold(inv.guildName, guildName) {
			g.by[target] = append(list[:i:i], list[i+1:]...)
			return inv, true
		}
	}
	return pendingGuildInvite{}, false
}

func (g *guildInvites) clear(target uint) {
	g.mu.Lock()
	defer g.mu.Unlock()
	delete(g.by, target)
}

func registerGuildHandlers(r *Router, d *Deps) {
	r.Register(protocol.OpGuildCreate, handleGuildCreate)
	r.Register(protocol.OpGuildInvite, handleGuildInvite)
	r.Register(protocol.OpGuildInviteAnswer, handleGuildInviteAnswer)
	r.Register(protocol.OpGuildGet, handleGuildGet)
	r.Register(protocol.OpGuildMembersGet, handleGuildMembers)
}

// handleGuildCreate (509, arch 3): [u8 type][u8 len][name].
func handleGuildCreate(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil || s.deps.Store == nil || s.deps.Store.Guilds == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	guildType, err := r.U8()
	if err != nil {
		return err
	}
	name, err := r.StringU8UTF8()
	if err != nil {
		return err
	}
	// SECURITY: the only check here used to be a MINIMUM length - no maximum, no
	// control-character filter, no markup strip - while the name is broadcast to
	// every online session via buildGuildCreatedFeed, which writes it raw. The
	// client has a dedicated refusal for this (GuildResultBadName ->
	// guild.error.invalidName, "Ce nom de clan n'est pas valide ou est deja
	// utilise"), so a bad name gets the right message with no invented prose.
	clean, ok := sanitizeDisplayName(name, maxGuildNameLen)
	if !ok || len([]rune(clean)) < minGuildNameLen {
		s.log.Warn("rejected guild name", "coach", s.Coach.ID, "len", len(name))
		return s.sendGuildResult(guildType, protocol.GuildResultBadName)
	}
	name = clean
	g, err := s.deps.Store.Guilds.Create(name, s.Coach.ID, defaultLeaderRankName, defaultMemberRankName)
	switch {
	case errors.Is(err, store.ErrGuildNameTaken):
		return s.sendGuildResult(guildType, protocol.GuildResultBadName)
	case errors.Is(err, store.ErrAlreadyInGuild):
		// The client blocks this in its own dialog, so reaching it means a
		// modified client or a race. Report it as a refusal rather than
		// creating a second guild.
		return s.sendGuildResult(guildType, protocol.GuildResultBadName)
	case err != nil:
		return err
	}
	s.log.Info("guild created", "guild", g.Name, "id", g.ID, "leader", s.Coach.Name)

	if err := s.sendGuildResult(guildType, protocol.GuildResultCreated); err != nil {
		return err
	}
	if err := s.pushGuildState(g.ID); err != nil {
		return err
	}
	// Every other session's coach registry now labels this coach with the new
	// clan - the 554 merge lands on the record it already holds.
	s.deps.broadcastGuildTag(s.Coach.ID)
	// The creation feed goes to everyone: it is a world announcement
	// ("infos.guildCreated"), not a clan-scoped line.
	if frame, err := buildGuildCreatedFeed(s.Coach.Name, g.Name); err == nil {
		s.deps.Sessions.Each(func(other *Session) { _ = other.Send(frame) })
	}
	return nil
}

// handleGuildInvite (501): [u8 type][u8 mode] then [u8 len][name] or [i64 id],
// then [i64 guildId].
func handleGuildInvite(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil || s.deps.Store == nil || s.deps.Store.Guilds == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	guildType, err := r.U8()
	if err != nil {
		return err
	}
	mode, err := r.U8()
	if err != nil {
		return err
	}
	var targetName string
	var targetID int64
	if mode == 0 {
		if targetName, err = r.StringU8UTF8(); err != nil {
			return err
		}
	} else {
		if targetID, err = r.I64(); err != nil {
			return err
		}
	}
	// The client sends the guild id it believes it is inviting into; it is
	// re-derived from the sender rather than trusted, exactly as clan chat does.
	if _, err := r.I64(); err != nil {
		return err
	}

	inviter, err := s.deps.Store.Guilds.MembershipOf(s.Coach.ID)
	if err != nil || inviter == nil {
		return s.sendGuildResult(guildType, protocol.GuildResultInviteRefused)
	}
	rank, err := s.deps.Store.Guilds.Rank(inviter.GuildID, inviter.RankLevel)
	if err != nil || rank == nil || !guildRightAllows(rank.Rights, store.GuildRightInvite) {
		return s.sendGuildResult(guildType, protocol.GuildResultInviteRefused)
	}
	g, err := s.deps.Store.Guilds.ByID(inviter.GuildID)
	if err != nil || g == nil {
		return s.sendGuildResult(guildType, protocol.GuildResultInviteRefused)
	}

	target := s.deps.findSessionByCoach(targetName, uint(targetID))
	if target == nil || target.Coach == nil {
		return s.sendGuildResult(guildType, protocol.GuildResultUserNotFound)
	}
	if _, err := s.deps.Store.Guilds.MembershipOf(target.Coach.ID); err == nil {
		// Already in a guild: the client greys the menu entry out, so this is
		// only reachable out-of-band.
		return s.sendGuildResult(guildType, protocol.GuildResultUserNotFound)
	}
	s.deps.GuildInvites.add(target.Coach.ID, pendingGuildInvite{
		guildID: g.ID, inviterName: s.Coach.Name, guildName: g.Name, guildType: guildType,
	})
	frame, err := buildGuildInvitation(guildType, s.Coach.Name, g.Name)
	if err != nil {
		return err
	}
	return target.Send(frame)
}

// handleGuildInviteAnswer (503):
// [u8 type][u8 accepted][u8 len][inviterName][u8 len][guildName].
func handleGuildInviteAnswer(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil || s.deps.Store == nil || s.deps.Store.Guilds == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	guildType, err := r.U8()
	if err != nil {
		return err
	}
	accepted, err := r.U8()
	if err != nil {
		return err
	}
	inviterName, err := r.StringU8UTF8()
	if err != nil {
		return err
	}
	guildName, err := r.StringU8UTF8()
	if err != nil {
		return err
	}

	inv, ok := s.deps.GuildInvites.take(s.Coach.ID, inviterName, guildName)
	if !ok {
		return nil // stale or forged answer: nothing to act on
	}
	if accepted == 0 {
		if inviter := s.deps.findSessionByCoach(inviterName, 0); inviter != nil {
			if frame, err := buildGuildResult(guildType, protocol.GuildResultInviteRefused); err == nil {
				_ = inviter.Send(frame)
			}
		}
		return nil
	}
	if err := s.deps.Store.Guilds.AddMember(inv.guildID, s.Coach.ID); err != nil {
		if errors.Is(err, store.ErrAlreadyInGuild) {
			return nil
		}
		return err
	}
	s.deps.GuildInvites.clear(s.Coach.ID) // any other pending offers are moot now
	s.log.Info("guild joined", "guild", inv.guildName, "coach", s.Coach.Name)

	if err := s.sendGuildResult(guildType, protocol.GuildResultJoined); err != nil {
		return err
	}
	if err := s.pushGuildState(inv.guildID); err != nil {
		return err
	}
	// The joiner's clan tag now shows under its name for every observer.
	s.deps.broadcastGuildTag(s.Coach.ID)
	// Tell the clan, and refresh the member list everyone is looking at.
	if frame, err := buildGuildMemberFeed(s.Coach.Name, false); err == nil {
		for _, other := range s.deps.guildSessions(int64(inv.guildID), s.Coach.ID) {
			_ = other.Send(frame)
			_ = s.deps.sendGuildMembers(other, inv.guildID)
		}
	}
	return nil
}

// handleGuildGet (517): [i64 playerId] - "tell me about this player's guild".
func handleGuildGet(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil || s.deps.Store == nil || s.deps.Store.Guilds == nil {
		return nil
	}
	// SECURITY: answer for the SENDER's own guild whatever coach id it named.
	//
	// 519 was hardened for exactly this and 517 was not, so it reached the same
	// builder with an arbitrary id. Iterating small sequential coach ids harvested,
	// for every guild on the server, the full member list with each member's rank,
	// RIGHTS bitmask and live online/offline status - the data 519 refuses to give
	// out, plus a presence oracle that bypasses the friend-list model.
	//
	// The payload's coach id is read so the frame is consumed correctly, then
	// discarded.
	r := protocol.NewReader(f.Payload)
	if _, err := r.I64(); err != nil {
		return err
	}
	m, err := s.deps.Store.Guilds.MembershipOf(s.Coach.ID)
	if err != nil || m == nil {
		return nil // no guild: the client keeps showing "no clan"
	}
	return s.pushGuildState(m.GuildID)
}

// handleGuildMembers (519): [i64 guildId] - the member list for the guild tab.
func handleGuildMembers(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil || s.deps.Store == nil || s.deps.Store.Guilds == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	guildID, err := r.I64()
	if err != nil {
		return err
	}
	// Answer for the sender's OWN guild whatever it asked for: the id is
	// client-supplied, and a member list is the roster of real player names.
	m, err := s.deps.Store.Guilds.MembershipOf(s.Coach.ID)
	if err != nil || m == nil {
		return nil
	}
	if guildID != 0 && uint(guildID) != m.GuildID {
		s.log.Debug("guild member list asked for another guild",
			"coach", s.Coach.Name, "asked", guildID, "own", m.GuildID)
	}
	return s.deps.sendGuildMembers(s, m.GuildID)
}

// --- helpers ---

// guildRightAllows reports whether a rights bitmask grants a right. Bit 0
// (leader) grants everything, which is how the client reads it too: every
// accessor in `aen_1` is `(rights & 1) | (rights & bit)`.
func guildRightAllows(rights, want int32) bool {
	return rights&store.GuildRightLeader != 0 || rights&want != 0
}

func (s *Session) sendGuildResult(guildType uint8, code int32) error {
	frame, err := buildGuildResult(guildType, code)
	if err != nil {
		return err
	}
	return s.Send(frame)
}

// pushGuildState sends the guild record (510) and the recipient's own membership
// (552), then the member list (512). The client needs all three before its tab
// can render: the record carries the ranks, 552 is what sets `aPY()` mid-session
// (the 0x20 blob only covers login), and 512 is the roster.
func (s *Session) pushGuildState(guildID uint) error {
	g, err := s.deps.Store.Guilds.ByID(guildID)
	if err != nil || g == nil {
		return err
	}
	ranks, err := s.deps.Store.Guilds.Ranks(guildID)
	if err != nil {
		return err
	}
	if frame, err := buildGuildRecord(g, ranks); err == nil {
		if err := s.Send(frame); err != nil {
			return err
		}
	}
	if s.Coach != nil {
		if mb := s.deps.guildMembership(s.Coach.ID); mb != nil {
			part := protocol.NewWriter().
				I64(mb.GuildID).
				I32(mb.Rights).
				U16(uint16(mb.RankLevel)).
				StringU8UTF8(mb.RankName).
				U16(0).
				StringU8UTF8(mb.GuildName).
				U16(0).
				I32(0).
				I32(0).
				U16(uint16(mb.DemonID)).
				Bytes()
			if frame, err := buildGuildMemberList(protocol.OpGuildMembership, 2, [][]byte{part}); err == nil {
				if err := s.Send(frame); err != nil {
					return err
				}
			}
		}
	}
	return s.deps.sendGuildMembers(s, guildID)
}

// pushGuildTags sends the clan-tag part-table (554, kf_1 with ca_0 part 1 =
// `ut_2`): one entry per clanned coach, so the client's `bd_1.Is()` registry
// can label every coach it knows — the same role the 0x20 blob plays for the
// coach itself, and the reason a coach's clan tag appears under its name
// without a per-observer lookup.
func (d *Deps) pushGuildTags(to *Session) error {
	if d == nil || d.Store == nil || d.Store.Guilds == nil {
		return nil
	}
	members, err := d.Store.Guilds.MembershipsAll()
	if err != nil {
		return err
	}
	payloads := make([][]byte, 0, len(members))
	for _, m := range members {
		g, err := d.Store.Guilds.ByID(m.GuildID)
		if err != nil || g == nil {
			continue
		}
		payloads = append(payloads, guildTagPart(g.Name, int64(m.CoachID), g.DemonID))
	}
	frame, err := buildGuildMemberList(protocol.OpGuildTags, 1, payloads)
	if err != nil {
		return err
	}
	return to.Send(frame)
}

// broadcastGuildTag pushes one coach's clan tag (554, single-entry table) to
// every connected session after a membership change, so the tag under its name
// updates live rather than on each observer's next login. `lh_1` merges the
// entry onto the coach record it already holds, so no clear is needed here —
// removals go through 556 (`a(null)` on the coach), which the leave/destroy
// paths already send.
func (d *Deps) broadcastGuildTag(coachID uint) {
	if d == nil || d.Store == nil || d.Store.Guilds == nil || d.Sessions == nil {
		return
	}
	m, err := d.Store.Guilds.MembershipOf(coachID)
	if err != nil || m == nil {
		return // not in a guild: nothing to tag (a removal is 556's job)
	}
	g, err := d.Store.Guilds.ByID(m.GuildID)
	if err != nil || g == nil {
		return
	}
	frame, err := buildGuildMemberList(protocol.OpGuildTags, 1,
		[][]byte{guildTagPart(g.Name, int64(coachID), g.DemonID)})
	if err != nil {
		return
	}
	d.Sessions.Each(func(other *Session) { _ = other.Send(frame) })
}

// sendGuildMembers pushes 512 for a guild to one session.
func (d *Deps) sendGuildMembers(to *Session, guildID uint) error {
	members, err := d.Store.Guilds.Members(guildID)
	if err != nil {
		return err
	}
	ranks, err := d.Store.Guilds.Ranks(guildID)
	if err != nil {
		return err
	}
	rankByLevel := make(map[int16]domain.GuildRank, len(ranks))
	for _, rk := range ranks {
		rankByLevel[rk.Level] = rk
	}
	online := make(map[uint]bool)
	d.Sessions.Each(func(sess *Session) {
		if sess.Coach != nil {
			online[sess.Coach.ID] = true
		}
	})
	payloads := make([][]byte, 0, len(members))
	for _, m := range members {
		name := d.coachName(m.CoachID)
		if name == "" {
			continue // a deleted coach must not appear as a blank row
		}
		rk := rankByLevel[m.RankLevel]
		payloads = append(payloads, guildMemberPart(
			int64(m.CoachID), rk.Rights, m.RankLevel, rk.Name, name, online[m.CoachID]))
	}
	frame, err := buildGuildMemberList(protocol.OpGuildMembers, 0, payloads)
	if err != nil {
		return err
	}
	return to.Send(frame)
}

// coachName resolves a coach id to its name, preferring an online session (no
// query) and falling back to storage so offline members still appear.
func (d *Deps) coachName(coachID uint) string {
	var name string
	d.Sessions.Each(func(sess *Session) {
		if sess.Coach != nil && sess.Coach.ID == coachID {
			name = sess.Coach.Name
		}
	})
	if name != "" {
		return name
	}
	if d.Store == nil || d.Store.Coaches == nil {
		return ""
	}
	c, err := d.Store.Coaches.Get(coachID)
	if err != nil || c == nil {
		return ""
	}
	return c.Name
}

// findSessionByCoach finds an online session by coach name (case-insensitive) or
// by coach id. Guild invitations address a player one way or the other depending
// on whether they were typed or right-clicked.
func (d *Deps) findSessionByCoach(name string, coachID uint) *Session {
	var found *Session
	d.Sessions.Each(func(sess *Session) {
		if sess.Coach == nil || found != nil {
			return
		}
		if coachID != 0 && sess.Coach.ID == coachID {
			found = sess
			return
		}
		if name != "" && strings.EqualFold(sess.Coach.Name, name) {
			found = sess
		}
	})
	return found
}
