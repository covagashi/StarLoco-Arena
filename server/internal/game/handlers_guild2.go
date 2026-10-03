package game

import (
	"errors"

	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store"
)

// Guild membership and rank administration: leave/kick, destroy, promote/demote
// and rank CRUD.
//
// Every one of these is a privileged operation whose UI the client already
// hides from anyone without the right - so reaching the server without it means
// the check was bypassed, and each handler re-derives the caller's rank rather
// than trusting the request.

func registerGuildAdminHandlers(r *Router, d *Deps) {
	r.Register(protocol.OpGuildLeave, handleGuildLeave)
	r.Register(protocol.OpGuildDestroy, handleGuildDestroy)
	r.Register(protocol.OpGuildSetRank, handleGuildSetRank)
	r.Register(protocol.OpGuildRankAdd, handleGuildRankAdd)
	r.Register(protocol.OpGuildRankModify, handleGuildRankModify)
	r.Register(protocol.OpGuildRankDelete, handleGuildRankDelete)
	r.Register(protocol.OpGuildMemberStats, handleGuildMemberStats)
}

// guildActor resolves the caller's membership and rank in one step, since every
// handler below needs both.
func (s *Session) guildActor() (guildID uint, rankLevel int16, rights int32, ok bool) {
	if s.Coach == nil || s.deps.Store == nil || s.deps.Store.Guilds == nil {
		return 0, 0, 0, false
	}
	m, err := s.deps.Store.Guilds.MembershipOf(s.Coach.ID)
	if err != nil || m == nil {
		return 0, 0, 0, false
	}
	rk, err := s.deps.Store.Guilds.Rank(m.GuildID, m.RankLevel)
	if err != nil || rk == nil {
		return m.GuildID, m.RankLevel, 0, true
	}
	return m.GuildID, m.RankLevel, rk.Rights, true
}

// handleGuildLeave (505): [i64 guildId][i64 memberId].
//
// One opcode for two operations, told apart by whether the member is the caller:
// quitting yields result 400 to yourself, being thrown out yields 402 to the
// victim. The client clears its membership on either.
func handleGuildLeave(s *Session, f *protocol.C2SFrame) error {
	guildID, myLevel, myRights, ok := s.guildActor()
	if !ok {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	if _, err := r.I64(); err != nil { // guild id, re-derived above
		return err
	}
	memberID, err := r.I64()
	if err != nil {
		return err
	}
	target := uint(memberID)
	// SECURITY: id 0 is not "self". Treating it as self meant RemoveMember deleted
	// nothing (so the request could be repeated without limit) while still fanning
	// out a forged "X was thrown out" feed with an empty name plus a 556 for player
	// 0 to every online clan member - at 2+ DB queries per member per packet, which
	// with SQLite's single connection serialises the whole persistence layer.
	if target == 0 {
		return nil
	}
	self := target == s.Coach.ID

	if !self {
		// Kicking needs the right AND a strictly lower-ranked victim: without
		// the rank test two officers could remove each other, and a member could
		// remove the leader.
		if !guildRightAllows(myRights, store.GuildRightRemove) {
			return nil
		}
		tm, err := s.deps.Store.Guilds.MembershipOf(target)
		if err != nil || tm == nil || tm.GuildID != guildID || tm.RankLevel <= myLevel {
			return nil
		}
	}
	// SECURITY: never leave a clan with no leader.
	//
	// A leader could remove ITSELF with no succession and no last-leader check.
	// guilds.leader_coach_id then pointed at a non-member and no rank-1 member
	// remained, so destroy, every rank edit and demon affiliation became
	// permanently unreachable - while the name stayed reserved
	// (case-insensitively unique). Self-inflicted, but unrecoverable, and usable
	// as a name-squatting primitive.
	//
	// The refusal is silent: the client has no status for it, and it can only be
	// reached by someone who IS the last leader, who can promote a successor or
	// destroy the clan instead.
	if orphan, err := s.deps.Store.Guilds.WouldOrphanGuild(guildID, target); err == nil && orphan {
		s.log.Info("guild leave refused: would leave the clan with no leader",
			"guild", guildID, "coach", target)
		return nil
	}

	if _, err := s.deps.Store.Guilds.RemoveMember(guildID, target); err != nil {
		return err
	}
	name := s.deps.coachName(target)
	s.log.Info("guild member left", "guild", guildID, "coach", name, "kicked", !self)

	code := int32(protocol.GuildResultLeft)
	if !self {
		code = protocol.GuildResultKicked
	}
	// Tell the departing member, whether that is the caller or someone else.
	if sess := s.deps.findSessionByCoach("", target); sess != nil {
		if frame, err := buildGuildResult(2, code); err == nil {
			_ = sess.Send(frame)
		}
		if frame, err := buildGuildMemberGone(int64(target)); err == nil {
			_ = sess.Send(frame)
		}
	}
	// And tell the clan, refreshing the roster everyone is looking at.
	feed, _ := buildGuildMemberFeed(name, true)
	for _, other := range s.deps.guildSessions(int64(guildID), target) {
		_ = other.Send(feed)
		_ = s.deps.sendGuildMembers(other, guildID)
	}
	// Every observer's coach registry clears the tag too (556 is the removal
	// counterpart of the 554 tag push). The departed already got its copy above;
	// everyone else - clan included - takes it from this broadcast.
	if gone, err := buildGuildMemberGone(int64(target)); err == nil {
		departed := s.deps.findSessionByCoach("", target)
		s.deps.Sessions.Each(func(other *Session) {
			if other != departed {
				_ = other.Send(gone)
			}
		})
	}
	return nil
}

// handleGuildDestroy (511): [i64 guildId]. Leader only.
func handleGuildDestroy(s *Session, f *protocol.C2SFrame) error {
	guildID, _, myRights, ok := s.guildActor()
	if !ok {
		return nil
	}
	if myRights&store.GuildRightLeader == 0 {
		return nil
	}
	if _, err := protocol.NewReader(f.Payload).I64(); err != nil {
		return err
	}
	// Collect the sessions BEFORE deleting: afterwards there is no membership
	// left to look them up by, and the members would never learn the clan is
	// gone until they relogged.
	targets := append(s.deps.guildSessions(int64(guildID), 0), s)
	members, err := s.deps.Store.Guilds.Delete(guildID)
	if err != nil {
		return err
	}
	s.log.Info("guild destroyed", "guild", guildID, "members", len(members), "by", s.Coach.Name)

	frame, err := buildGuildResult(2, protocol.GuildResultDestroyed)
	if err != nil {
		return err
	}
	seen := map[*Session]bool{}
	for _, sess := range targets {
		if sess == nil || seen[sess] {
			continue
		}
		seen[sess] = true
		_ = sess.Send(frame)
	}
	// Clear every ex-member's clan tag in every observer's registry — the 556
	// the leave path broadcasts, times one per member of the dissolved clan.
	for _, coachID := range members {
		if gone, err := buildGuildMemberGone(int64(coachID)); err == nil {
			s.deps.Sessions.Each(func(other *Session) { _ = other.Send(gone) })
		}
	}
	return nil
}

// handleGuildSetRank (515): [i64 guildId][i64 memberId][i16 newRankLevel].
//
// The client computes the new level itself for both promote and demote, so this
// validates the OUTCOME rather than re-deriving it: the target must be below the
// caller, the caller must hold the matching right, and the destination rank must
// exist and stay below the caller's own.
func handleGuildSetRank(s *Session, f *protocol.C2SFrame) error {
	guildID, myLevel, myRights, ok := s.guildActor()
	if !ok {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	if _, err := r.I64(); err != nil {
		return err
	}
	memberID, err := r.I64()
	if err != nil {
		return err
	}
	newLevel, err := r.U16()
	if err != nil {
		return err
	}
	target := uint(memberID)
	tm, err := s.deps.Store.Guilds.MembershipOf(target)
	if err != nil || tm == nil || tm.GuildID != guildID {
		return nil
	}
	if tm.RankLevel <= myLevel {
		return nil // cannot touch an equal or higher rank
	}
	want := int16(newLevel)
	if want <= myLevel {
		return nil // would place the target at or above the caller
	}
	if rk, err := s.deps.Store.Guilds.Rank(guildID, want); err != nil || rk == nil {
		return nil // no such rank in this guild
	}
	right := store.GuildRightPromote
	if want > tm.RankLevel {
		right = store.GuildRightDemote // a HIGHER level number is a lower rung
	}
	if !guildRightAllows(myRights, right) {
		return nil
	}
	if err := s.deps.Store.Guilds.SetMemberRank(guildID, target, want); err != nil {
		return err
	}
	return s.deps.refreshGuild(guildID)
}

// handleGuildRankAdd (553): [i64 guildId][i32 rights][u8 len][name].
func handleGuildRankAdd(s *Session, f *protocol.C2SFrame) error {
	guildID, _, myRights, ok := s.guildActor()
	if !ok || myRights&store.GuildRightLeader == 0 {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	if _, err := r.I64(); err != nil {
		return err
	}
	rights, err := r.I32()
	if err != nil {
		return err
	}
	name, err := r.StringU8UTF8()
	if err != nil {
		return err
	}
	// SECURITY: rank names had NO validation on either path - no trim, no
	// bounds, no content filter - and are pushed to every guild member in
	// buildGuildRecord. Anyone can found a guild and be its leader, so the
	// leader-rights gate is effectively self-service.
	rankName, ok := sanitizeDisplayName(name, maxGuildRankNameLen)
	if !ok {
		s.log.Warn("rejected guild rank name", "guild", guildID, "len", len(name))
		return nil
	}
	if err := s.deps.Store.Guilds.AddRank(guildID, rights, rankName); err != nil {
		if errors.Is(err, store.ErrGuildRankLimit) {
			return nil // the client shows its own "10 ranks max" message
		}
		return err
	}
	return s.deps.refreshGuild(guildID)
}

// handleGuildRankModify (555):
// [i64 guildId][i32 rights][i16 level][i16 level][u8 len][name].
// Both shorts carry the same level - `aia_0.modifyRank` sets each from the
// selected rank's own `aRe()`.
func handleGuildRankModify(s *Session, f *protocol.C2SFrame) error {
	guildID, _, myRights, ok := s.guildActor()
	if !ok || myRights&store.GuildRightLeader == 0 {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	if _, err := r.I64(); err != nil {
		return err
	}
	rights, err := r.I32()
	if err != nil {
		return err
	}
	level, err := r.U16()
	if err != nil {
		return err
	}
	if _, err := r.U16(); err != nil { // the duplicate level
		return err
	}
	name, err := r.StringU8UTF8()
	if err != nil {
		return err
	}
	rankName, ok := sanitizeDisplayName(name, maxGuildRankNameLen)
	if !ok {
		s.log.Warn("rejected guild rank name", "guild", guildID, "len", len(name))
		return nil
	}
	if err := s.deps.Store.Guilds.UpdateRank(guildID, int16(level), rights, rankName); err != nil {
		return err
	}
	return s.deps.refreshGuild(guildID)
}

// handleGuildRankDelete (557): [i64 guildId][i16 level].
func handleGuildRankDelete(s *Session, f *protocol.C2SFrame) error {
	guildID, _, myRights, ok := s.guildActor()
	if !ok || myRights&store.GuildRightLeader == 0 {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	if _, err := r.I64(); err != nil {
		return err
	}
	level, err := r.U16()
	if err != nil {
		return err
	}
	if err := s.deps.Store.Guilds.DeleteRank(guildID, int16(level)); err != nil {
		if errors.Is(err, store.ErrGuildRankProtected) {
			return nil
		}
		return err
	}
	return s.deps.refreshGuild(guildID)
}

// handleGuildMemberStats (2600): [i64 memberId] - clicking a member opens its
// stats popup, which the server answers with 2601.
func handleGuildMemberStats(s *Session, f *protocol.C2SFrame) error {
	guildID, _, _, ok := s.guildActor()
	if !ok {
		return nil
	}
	memberID, err := protocol.NewReader(f.Payload).I64()
	if err != nil {
		return err
	}
	target := uint(memberID)
	tm, err := s.deps.Store.Guilds.MembershipOf(target)
	if err != nil || tm == nil || tm.GuildID != guildID {
		return nil // only your own clan's members
	}
	c, err := s.deps.Store.Coaches.Get(target)
	if err != nil || c == nil {
		return nil
	}
	frame, err := buildGuildMemberReport(c)
	if err != nil {
		return err
	}
	return s.Send(frame)
}

// refreshGuild re-pushes the guild record and roster to every online member, so
// a rank change is visible to everyone looking at the tab rather than only to
// whoever made it.
func (d *Deps) refreshGuild(guildID uint) error {
	g, err := d.Store.Guilds.ByID(guildID)
	if err != nil || g == nil {
		return err
	}
	ranks, err := d.Store.Guilds.Ranks(guildID)
	if err != nil {
		return err
	}
	record, err := buildGuildRecord(g, ranks)
	if err != nil {
		return err
	}
	for _, sess := range d.guildSessions(int64(guildID), 0) {
		_ = sess.Send(record)
		_ = d.sendGuildMembers(sess, guildID)
	}
	return nil
}
