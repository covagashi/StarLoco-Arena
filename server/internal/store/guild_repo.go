package store

import (
	"errors"
	"strings"
	"time"

	"gorm.io/gorm"

	"github.com/StarLoco/arena-2.70/internal/domain"
)

// Guild rank constants, taken from the client's own rules (`aia_0`):
// level 1 is the leader and level 10 the default rung, neither is deletable, and
// a guild may hold at most ten ranks.
const (
	// Clan islands are worlds 86-109 in the shipped map data - exactly 24 of
	// them, one per island, each with its own Zaap (see
	// docs/OVERWORLD-MAP.md "Clan island Zaaps"). They are a finite resource,
	// which is why the client has a "your clan is not ranked high enough to have
	// an island" error at all.
	GuildIslandFirst int16 = 86
	GuildIslandLast  int16 = 109

	GuildRankLeader  int16 = 1
	GuildRankDefault int16 = 10
	GuildMaxRanks          = 10

	// Rights bits (`aen_1`). Bit 0 is "leader", and because every accessor is
	// `(rights & 1) | (rights & bit)` it implies all the others.
	GuildRightLeader  int32 = 1
	GuildRightInvite  int32 = 2
	GuildRightRemove  int32 = 4
	GuildRightPromote int32 = 8
	GuildRightDemote  int32 = 16
)

// ErrGuildNameTaken is returned when a guild name is already in use or unusable.
// The caller maps it to the client's result code 11 ("not valid or already
// being used"), which is a single code for both cases - so the server does not
// need to distinguish them either.
var ErrGuildNameTaken = errors.New("store: guild name unavailable")

// ErrAlreadyInGuild is returned when a coach that is already a member tries to
// create or join another guild (client result code / string
// `guild.error.alreadyGuildMember`).
var ErrAlreadyInGuild = errors.New("store: coach already in a guild")

// ErrGuildRankLimit is returned when a guild already holds the ten ranks the
// client can display.
var ErrGuildRankLimit = errors.New("store: guild rank limit reached")

// ErrGuildRankProtected is returned for the leader (1) and default (10) rungs,
// which the client refuses to delete and which the guild cannot work without.
var ErrGuildRankProtected = errors.New("store: guild rank cannot be removed")

// ErrGuildDemonInvalid / ErrGuildAlreadyAffiliated guard demon affiliation.
var ErrGuildDemonInvalid = errors.New("store: no such demon")
var ErrGuildAlreadyAffiliated = errors.New("store: guild already serves a demon")

// GuildRepo is the guild persistence layer.
type GuildRepo struct{ db *gorm.DB }

// Create makes a guild owned by leaderCoachID, seeds the two mandatory ranks and
// puts the leader at rank 1, all in one transaction: a guild with no leader row
// would present an empty member list and no one able to manage it.
func (r *GuildRepo) Create(name string, leaderCoachID uint, leaderRankName, defaultRankName string) (*domain.Guild, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, ErrGuildNameTaken
	}
	var g domain.Guild
	err := r.db.Transaction(func(tx *gorm.DB) error {
		var n int64
		if err := tx.Model(&domain.GuildMember{}).
			Where("coach_id = ?", leaderCoachID).Count(&n).Error; err != nil {
			return err
		}
		if n > 0 {
			return ErrAlreadyInGuild
		}
		// SECURITY: case-INSENSITIVE, matching CoachRepo.Create. An exact match
		// made "Elite", "elite" and "ELITE" four distinct guilds, which is direct
		// impersonation - and the guild name is broadcast to every online session
		// on creation. LOWER() rather than COLLATE NOCASE, which is SQLite-only.
		if err := tx.Model(&domain.Guild{}).
			Where("LOWER(name) = LOWER(?)", name).Count(&n).Error; err != nil {
			return err
		}
		if n > 0 {
			return ErrGuildNameTaken
		}
		g = domain.Guild{Name: name, LeaderCoachID: leaderCoachID, CreatedAt: time.Now().UTC()}
		if err := tx.Create(&g).Error; err != nil {
			return err
		}
		ranks := []domain.GuildRank{
			{GuildID: g.ID, Level: GuildRankLeader, Rights: GuildRightLeader, Name: leaderRankName},
			{GuildID: g.ID, Level: GuildRankDefault, Rights: 0, Name: defaultRankName},
		}
		if err := tx.Create(&ranks).Error; err != nil {
			return err
		}
		return tx.Create(&domain.GuildMember{
			GuildID: g.ID, CoachID: leaderCoachID,
			RankLevel: GuildRankLeader, JoinedAt: time.Now().UTC(),
		}).Error
	})
	if err != nil {
		return nil, err
	}
	return &g, nil
}

// ByID loads a guild.
func (r *GuildRepo) ByID(id uint) (*domain.Guild, error) {
	var g domain.Guild
	err := r.db.First(&g, id).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	return &g, err
}

// MembershipOf returns a coach's membership, or ErrNotFound when it has none.
func (r *GuildRepo) MembershipOf(coachID uint) (*domain.GuildMember, error) {
	var m domain.GuildMember
	err := r.db.Where("coach_id = ?", coachID).First(&m).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	return &m, err
}

// Ranks returns a guild's ranks ordered by level (1 first), which is the order
// the client's own rank list uses (`wu_0` sorts ascending).
func (r *GuildRepo) Ranks(guildID uint) ([]domain.GuildRank, error) {
	var out []domain.GuildRank
	err := r.db.Where("guild_id = ?", guildID).Order("level ASC").Find(&out).Error
	return out, err
}

// Rank returns one rank of a guild.
func (r *GuildRepo) Rank(guildID uint, level int16) (*domain.GuildRank, error) {
	var rk domain.GuildRank
	err := r.db.Where("guild_id = ? AND level = ?", guildID, level).First(&rk).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	return &rk, err
}

// MembershipsAll returns every guild_members row across all guilds — the
// source for the 554 clan-tag table the client caches for every known coach.
func (r *GuildRepo) MembershipsAll() ([]domain.GuildMember, error) {
	var out []domain.GuildMember
	err := r.db.Find(&out).Error
	return out, err
}

// Members returns a guild's memberships ordered by rank then id, mirroring the
// client's own member sort (`Wt` orders by rank).
func (r *GuildRepo) Members(guildID uint) ([]domain.GuildMember, error) {
	var out []domain.GuildMember
	err := r.db.Where("guild_id = ?", guildID).
		Order("rank_level ASC, id ASC").Find(&out).Error
	return out, err
}

// AddMember joins a coach at the default rank. Refuses a coach that already
// belongs somewhere, so a race between two invitations cannot produce a coach in
// two guilds - the unique index would reject it anyway, but this returns the
// error the handler can map to a client code.
func (r *GuildRepo) AddMember(guildID, coachID uint) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		var n int64
		if err := tx.Model(&domain.GuildMember{}).
			Where("coach_id = ?", coachID).Count(&n).Error; err != nil {
			return err
		}
		if n > 0 {
			return ErrAlreadyInGuild
		}
		// SECURITY/PERFORMANCE: bound the roster. refreshGuild rebuilds the full
		// member list once per online member, so every join and rank edit is O(N)
		// queries and O(N) frames - O(N^2) for the clan. Checked inside the same
		// transaction as the insert so two concurrent joins cannot both pass.
		var size int64
		if err := tx.Model(&domain.GuildMember{}).
			Where("guild_id = ?", guildID).Count(&size).Error; err != nil {
			return err
		}
		if size >= GuildMaxMembers {
			return ErrGuildFull
		}
		return tx.Create(&domain.GuildMember{
			GuildID: guildID, CoachID: coachID,
			RankLevel: GuildRankDefault, JoinedAt: time.Now().UTC(),
		}).Error
	})
}

// RemoveMember drops a coach from a guild. Returns whether a row went.
func (r *GuildRepo) RemoveMember(guildID, coachID uint) (bool, error) {
	res := r.db.Where("guild_id = ? AND coach_id = ?", guildID, coachID).
		Delete(&domain.GuildMember{})
	return res.RowsAffected > 0, res.Error
}

// CoachIDsIn returns every member coach id of a guild. Used by clan chat to find
// who to deliver to without loading whole rows.
func (r *GuildRepo) CoachIDsIn(guildID uint) ([]uint, error) {
	var out []uint
	err := r.db.Model(&domain.GuildMember{}).
		Where("guild_id = ?", guildID).Pluck("coach_id", &out).Error
	return out, err
}

// SetMemberRank moves a member to another rank level.
func (r *GuildRepo) SetMemberRank(guildID, coachID uint, level int16) error {
	return r.db.Model(&domain.GuildMember{}).
		Where("guild_id = ? AND coach_id = ?", guildID, coachID).
		Update("rank_level", level).Error
}

// AddRank appends a rank. The client caps a guild at GuildMaxRanks and refuses
// to render more, so the cap is enforced here rather than trusting it.
// sanitizeRankRights keeps the leader bit on rank 1 and strips it from every
// other rank.
//
// SECURITY: rights arrive as a raw wire bitmask. UpdateRank only ever ADDED the
// leader bit to rank 1 and never removed it elsewhere, and AddRank stored the
// mask verbatim - so a leader could mint a low rank carrying GuildRightLeader.
// guildRightAllows treats that bit as "everything", handleGuildSetRank orders
// only by LEVEL and never by rights, and anyone can found a guild - so an officer
// with only the promote right could raise a member into a leader-rights rank, and
// that member could then destroy the guild.
func sanitizeRankRights(level int16, rights int32) int32 {
	if level == GuildRankLeader {
		return rights | GuildRightLeader
	}
	return rights &^ GuildRightLeader
}

func (r *GuildRepo) AddRank(guildID uint, rights int32, name string) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		var existing []domain.GuildRank
		if err := tx.Where("guild_id = ?", guildID).Order("level ASC").Find(&existing).Error; err != nil {
			return err
		}
		if len(existing) >= GuildMaxRanks {
			return ErrGuildRankLimit
		}
		// The client numbers a new rank by the current count, which lands it
		// between the leader (1) and the default rung (10).
		level := int16(len(existing))
		if level <= GuildRankLeader {
			level = GuildRankLeader + 1
		}
		for _, rk := range existing {
			if rk.Level == level {
				level++
			}
		}
		if level >= GuildRankDefault {
			return ErrGuildRankLimit
		}
		return tx.Create(&domain.GuildRank{
			GuildID: guildID, Level: level,
			Rights: sanitizeRankRights(level, rights), Name: name,
		}).Error
	})
}

// UpdateRank rewrites a rank's rights and name. The leader rank keeps its
// leader bit whatever is asked: a guild whose rank 1 lost it would have no one
// able to manage it and no way back.
func (r *GuildRepo) UpdateRank(guildID uint, level int16, rights int32, name string) error {
	rights = sanitizeRankRights(level, rights)
	return r.db.Model(&domain.GuildRank{}).
		Where("guild_id = ? AND level = ?", guildID, level).
		Updates(map[string]any{"rights": rights, "name": name}).Error
}

// DeleteRank removes a rank and moves anyone holding it down to the default
// rung. Levels 1 and 10 are refused, matching the client, which greys the button
// out for both.
func (r *GuildRepo) DeleteRank(guildID uint, level int16) error {
	if level == GuildRankLeader || level == GuildRankDefault {
		return ErrGuildRankProtected
	}
	return r.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Model(&domain.GuildMember{}).
			Where("guild_id = ? AND rank_level = ?", guildID, level).
			Update("rank_level", GuildRankDefault).Error; err != nil {
			return err
		}
		return tx.Where("guild_id = ? AND level = ?", guildID, level).
			Delete(&domain.GuildRank{}).Error
	})
}

// Delete destroys a guild with its ranks and memberships. Returns the coach ids
// that were members, so the caller can tell each of them.
func (r *GuildRepo) Delete(guildID uint) ([]uint, error) {
	var members []uint
	err := r.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Model(&domain.GuildMember{}).
			Where("guild_id = ?", guildID).Pluck("coach_id", &members).Error; err != nil {
			return err
		}
		if err := tx.Where("guild_id = ?", guildID).Delete(&domain.GuildMember{}).Error; err != nil {
			return err
		}
		if err := tx.Where("guild_id = ?", guildID).Delete(&domain.GuildRank{}).Error; err != nil {
			return err
		}
		return tx.Delete(&domain.Guild{}, guildID).Error
	})
	return members, err
}

// GuildLadderEntry is one row of the clan board.
type GuildLadderEntry struct {
	Name   string
	Leader string
	Score  int32
}

// Ladder returns clans ordered by score, strongest first.
//
// Score is the SUM of the members' 1v1 ratings. The client renders whatever
// number it is given (the column has no unit and no client-side maths), so this
// is the server's definition rather than a decoded one: it rewards both a strong
// roster and a large one, which is what a clan board is usually for. Recorded
// here because it is a design choice, not a protocol fact.
func (r *GuildRepo) Ladder(limit int) ([]GuildLadderEntry, error) {
	var out []GuildLadderEntry
	q := r.db.Table("guilds AS g").
		Select("g.name AS name, COALESCE(lc.name, '') AS leader, COALESCE(SUM(mc.strength), 0) AS score").
		Joins("LEFT JOIN coaches lc ON lc.id = g.leader_coach_id").
		Joins("LEFT JOIN guild_members m ON m.guild_id = g.id").
		Joins("LEFT JOIN coaches mc ON mc.id = m.coach_id").
		Group("g.id").
		Order("score DESC, g.name ASC")
	if limit > 0 {
		q = q.Limit(limit)
	}
	return out, q.Scan(&out).Error
}

// NamesByCoachName maps coach names to their clan's name, for the guild-tag
// column the ladder boards carry. Keyed by NAME because that is all a ladder row
// holds; one query for the whole page rather than one per row.
func (r *GuildRepo) NamesByCoachName(names []string) (map[string]string, error) {
	out := make(map[string]string, len(names))
	if len(names) == 0 {
		return out, nil
	}
	var rows []struct {
		Coach string
		Guild string
	}
	err := r.db.Table("guild_members AS m").
		Select("c.name AS coach, g.name AS guild").
		Joins("JOIN guilds g ON g.id = m.guild_id").
		Joins("JOIN coaches c ON c.id = m.coach_id").
		Where("c.name IN ?", names).
		Scan(&rows).Error
	if err != nil {
		return out, err
	}
	for _, row := range rows {
		out[row.Coach] = row.Guild
	}
	return out, nil
}

// DemonCount is the number of Demons des Heures: 24 totems ship in the world
// data, carrying demon ids 1..24 - and the shipped map data has exactly 24 clan
// islands. That 1:1 is the whole attribution rule.
const DemonCount int16 = 24

// IslandWorldForDemon maps a demon to the island its champion clan holds.
//
// The pairing (demon N -> world 85+N) is the server's, not the client's: nothing
// in the data names which island belongs to which demon, and the client is never
// told - it only ever receives a destination. What IS from the client is the rule
// itself: "Seul le clan le plus puissant au service de chaque Demon recoit une
// ile de clan" - one island per demon, held by its strongest servant.
func IslandWorldForDemon(demonID int16) (int16, bool) {
	if demonID < 1 || demonID > DemonCount {
		return 0, false
	}
	w := GuildIslandFirst + demonID - 1
	if w > GuildIslandLast {
		return 0, false
	}
	return w, true
}

// AddDemonReputation credits a clan's standing with a demon and returns the new
// total.
func (r *GuildRepo) AddDemonReputation(guildID uint, demonID int16, points int64) (int64, error) {
	var total int64
	err := r.db.Transaction(func(tx *gorm.DB) error {
		var rep domain.GuildDemonReputation
		err := tx.Where("guild_id = ? AND demon_id = ?", guildID, demonID).First(&rep).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			rep = domain.GuildDemonReputation{GuildID: guildID, DemonID: demonID, Points: points}
			total = points
			return tx.Create(&rep).Error
		}
		if err != nil {
			return err
		}
		rep.Points += points
		total = rep.Points
		return tx.Save(&rep).Error
	})
	return total, err
}

// DemonReputationRow is one line of a demon's clan ladder.
type DemonReputationRow struct {
	GuildID uint
	Name    string
	Points  int64
}

// GuildActiveMinMembers is how many members a clan needs to count as "active".
//
// The client states the threshold but never enforces it: opening the CLAN tab
// with fewer members pops guild.notEnoughGuildMembersToBeActive - "Votre clan ne
// comporte pas assez de membres pour etre actif. Recrutez encore [#1]
// personne{[>1]?s:} !" - computed as `5 - memberCount` in uk_1.java:52. That is
// the whole of its involvement: a warning label, gating nothing.
//
// So what "actif" DOES is the server's to decide, and the only reading that gives
// the warning any meaning is that an inactive clan does not compete. Otherwise a
// single coach could found a clan, feed a demon a handful of cards and hold an
// island against the entire server, which is not "le clan le plus puissant au
// service de chaque Demon" in any sense.
const GuildActiveMinMembers = 5

// activeClans is the subquery restricting a ladder to clans that actually field
// enough members to be active. Written once here because the demon ladder and
// the island allocation MUST agree: if an inactive clan could rank first while
// the island went to the clan below it, the ladder would be showing a leader who
// does not hold the prize.
func (r *GuildRepo) activeClans() *gorm.DB {
	return r.db.Table("guild_members").
		Select("guild_id").
		Group("guild_id").
		Having("COUNT(*) >= ?", GuildActiveMinMembers)
}

// DemonLadder returns the ACTIVE clans serving a demon, strongest first. Ties
// break on guild id so the order is stable - the top slot decides who holds an
// island, and an island that changed hands on every query would be worse than
// none.
func (r *GuildRepo) DemonLadder(demonID int16, limit int) ([]DemonReputationRow, error) {
	var out []DemonReputationRow
	q := r.db.Table("guild_demon_reputations AS rep").
		Select("rep.guild_id AS guild_id, g.name AS name, rep.points AS points").
		Joins("JOIN guilds g ON g.id = rep.guild_id").
		Where("rep.demon_id = ? AND g.demon_id = ?", demonID, demonID).
		Where("rep.guild_id IN (?)", r.activeClans()).
		Order("rep.points DESC, rep.guild_id ASC")
	if limit > 0 {
		q = q.Limit(limit)
	}
	return out, q.Scan(&out).Error
}

// IslandOf resolves the island a clan currently holds, if any.
//
// Derived, never stored: a clan holds its demon's island only while it is that
// demon's top-ranked ACTIVE servant. Storing the allocation would let a clan keep
// an island after being overtaken, which is precisely the thing the mechanic is
// about.
//
// The activity requirement rides in through DemonLadder, so a clan that drops
// below GuildActiveMinMembers loses its island the moment the member leaves,
// without anything having to notice the departure.
func (r *GuildRepo) IslandOf(guildID uint) (int16, bool, error) {
	g, err := r.ByID(guildID)
	if err != nil || g == nil || g.DemonID == 0 {
		return 0, false, err
	}
	world, ok := IslandWorldForDemon(g.DemonID)
	if !ok {
		return 0, false, nil
	}
	rows, err := r.DemonLadder(g.DemonID, 1)
	if err != nil || len(rows) == 0 || rows[0].GuildID != guildID {
		return 0, false, err
	}
	return world, true, nil
}

// SetDemon affiliates a clan to a demon. Refused once it already serves one:
// the client only offers the button when `demonId == 0` (pq_1.java:56), and
// switching allegiance would take an island from its holder for free.
func (r *GuildRepo) SetDemon(guildID uint, demonID int16) error {
	if demonID < 1 || demonID > DemonCount {
		return ErrGuildDemonInvalid
	}
	return r.db.Transaction(func(tx *gorm.DB) error {
		var g domain.Guild
		if err := tx.First(&g, guildID).Error; err != nil {
			return err
		}
		if g.DemonID != 0 {
			return ErrGuildAlreadyAffiliated
		}
		return tx.Model(&domain.Guild{}).Where("id = ?", guildID).
			Update("demon_id", demonID).Error
	})
}

// GuildMaxMembers caps a clan's roster.
//
// SECURITY/PERFORMANCE: there was no cap at all, and refreshGuild re-queries and
// rebuilds the full member list once per online member - so a single rank edit or
// join costs O(N) queries and O(N) frames, i.e. O(N^2) work for the clan. The
// number is generous (retail clans are far smaller) and exists to bound that
// fan-out, not to police play.
const GuildMaxMembers = 120

// ErrGuildFull is returned when a clan has reached GuildMaxMembers.
var ErrGuildFull = errors.New("store: guild is full")

// ErrGuildLastLeader is returned when removing a member would leave the clan with
// no one holding leader rights.
var ErrGuildLastLeader = errors.New("store: guild would have no leader")

// CountMembers returns how many coaches are in a guild.
func (r *GuildRepo) CountMembers(guildID uint) (int64, error) {
	var n int64
	err := r.db.Model(&domain.GuildMember{}).Where("guild_id = ?", guildID).Count(&n).Error
	return n, err
}

// WouldOrphanGuild reports whether removing coachID would leave the guild with no
// member at the leader rank.
//
// SECURITY: handleGuildLeave let a leader remove ITSELF with no succession and no
// last-leader check. guilds.leader_coach_id then pointed at a non-member and no
// rank-1 member remained, so destroy, every rank edit and demon affiliation
// became permanently unreachable for that clan - while its name stayed reserved
// (case-insensitively unique). Self-inflicted, but unrecoverable, and usable as a
// name-squatting primitive.
func (r *GuildRepo) WouldOrphanGuild(guildID, coachID uint) (bool, error) {
	var leaders []domain.GuildMember
	if err := r.db.Where("guild_id = ? AND rank_level = ?", guildID, GuildRankLeader).
		Find(&leaders).Error; err != nil {
		return false, err
	}
	if len(leaders) == 0 {
		return false, nil // already leaderless; removing one more changes nothing
	}
	for _, m := range leaders {
		if m.CoachID != coachID {
			return false, nil // another leader remains
		}
	}
	return true, nil
}
