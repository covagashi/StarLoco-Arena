// Package domain holds the persistent data models (GORM) for the 2.70 server.
//
// Mirrors the proven 2006 server's schema: an Account owns at most one Coach
// (nullable FK CoachID is the existing-vs-new-coach discriminator); a Coach has
// cards, friends and ignores. Layouts on the wire differ for 2.70 but the
// persistence design is identical.
package domain

import (
	"sync"
	"time"
)

// Account is a login account.
type Account struct {
	ID           uint   `gorm:"primaryKey"`
	Name         string `gorm:"uniqueIndex;size:64;not null"`
	PasswordHash string `gorm:"size:120;not null"` // bcrypt
	Connected    bool   `gorm:"not null;default:false"`
	IsAdmin      bool   `gorm:"not null;default:false"`
	CoachID      *uint  // nullable FK — nil => no coach yet
	Coach        *Coach `gorm:"foreignKey:CoachID"`
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

// Coach is a player's in-world character.
type Coach struct {
	// Mu guards concurrent mutation of the in-memory coach fields (a coach can
	// be touched by both its session goroutine and a fight actor). Not persisted.
	Mu sync.Mutex `gorm:"-"`

	ID   uint   `gorm:"primaryKey"`
	Name string `gorm:"uniqueIndex;size:32;not null"`

	// Look
	Hair uint8 `gorm:"not null;default:0"`
	Skin uint8 `gorm:"not null;default:0"`
	Sex  uint8 `gorm:"not null;default:0"`
	// HairFx is the hair effect cosmetic the coach shows (S37, a
	// CoachCosmetic it owns; 0 = none).
	HairFx int32 `gorm:"not null;default:0"`

	// World position
	PosX int32 `gorm:"not null;default:1"`
	PosY int32 `gorm:"not null;default:1"`
	PosZ int16 `gorm:"not null;default:0"`

	// Standing is the coach's EVOLUTION experience ("Réputation" in the client,
	// aez_0.bMU, flag 0x400). It is a second, independent progression track from
	// Strength: Strength is the ELO-like ladder rating, Standing accumulates and
	// never drops. The client derives the evolution level from it with
	// StandingToLevel and pops its level-up dialog when that level changes.
	Standing int32 `gorm:"not null;default:0"`

	// Ladder / lifetime stats
	Strength          int32 `gorm:"not null;default:0"` // 1v1 rating; 0 = unranked
	StatFights        int32 `gorm:"not null;default:0"`
	StatWins          int32 `gorm:"not null;default:0"`
	StatLosses        int32 `gorm:"not null;default:0"`
	ConsecutiveWins   int32 `gorm:"not null;default:0"`
	ConsecutiveLosses int32 `gorm:"not null;default:0"`
	TimeInFightSecs   int64 `gorm:"not null;default:0"`
	TotalPlaySecs     int64 `gorm:"not null;default:0"`

	Inventory []CoachCard     `gorm:"foreignKey:CoachID;constraint:OnDelete:CASCADE"`
	Friends   []CoachFriend   `gorm:"foreignKey:OwnerID;constraint:OnDelete:CASCADE"`
	Ignored   []CoachIgnored  `gorm:"foreignKey:OwnerID;constraint:OnDelete:CASCADE"`
	Wallet    []CoachCurrency `gorm:"foreignKey:CoachID;constraint:OnDelete:CASCADE"`
	Stats     []CoachStat     `gorm:"foreignKey:CoachID;constraint:OnDelete:CASCADE"`

	CreatedAt time.Time
	UpdatedAt time.Time
}

// CoachStat is one keyed achievement/statistic counter for a coach. StatID is
// the client's statistic-enum ordinal (client `or_0`); the client reports
// progress via opcode 22003. Kept in a keyed table (rather than scalar Coach
// columns) because the id space is large and open-ended.
type CoachStat struct {
	ID      uint  `gorm:"primaryKey"`
	CoachID uint  `gorm:"uniqueIndex:idx_stat_pair;not null"`
	StatID  int16 `gorm:"uniqueIndex:idx_stat_pair;not null"`
	Value   int32 `gorm:"not null;default:0"`
}

// CoachCosmetic is one cosmetic the coach owns (S37: the hair effects, ids in
// game/cosmetics.go). Pure looks: nothing in a fight reads it. The S30 shop
// is meant to sell them; until then a GM grants them (/COSMETIC).
type CoachCosmetic struct {
	ID         uint  `gorm:"primaryKey"`
	CoachID    uint  `gorm:"uniqueIndex:idx_coach_cosmetic;not null"`
	CosmeticID int32 `gorm:"uniqueIndex:idx_coach_cosmetic;not null"`
}

// TableName pins the table name.
func (CoachCosmetic) TableName() string { return "coach_cosmetics" }

// CoachTomeCard is one card template the coach has EVER owned — the "grimoire"
// the client keeps in aez_0.dBd.
//
// This is deliberately not derived from the live inventory. The client's set is
// GROW-ONLY: every use of aQm() is either a read or a `.d(id, 1)` add, and
// nothing anywhere removes from it. So selling, mailing or fusing a card away
// must not cost the coach credit for having owned it, which is exactly what a
// "distinct templates currently held" query would do.
type CoachTomeCard struct {
	ID         uint  `gorm:"primaryKey"`
	CoachID    uint  `gorm:"uniqueIndex:idx_coach_tome;not null"`
	TemplateID int32 `gorm:"uniqueIndex:idx_coach_tome;not null"`
}

// TableName pins the table name.
func (CoachTomeCard) TableName() string { return "coach_tome_cards" }

// CoachAchievement records that an achievement has been UNLOCKED and announced.
//
// Completion itself is not stored: it is a pure function of the coach's criteria
// and tome, recomputed on demand exactly as the client does it. The only thing
// this table buys is that the unlock announcement (S2C 22000) fires once per
// coach instead of every time the criteria are re-evaluated.
type CoachAchievement struct {
	ID uint `gorm:"primaryKey"`
	// AchievementID is the type-800 record id (int16 on the wire).
	CoachID       uint  `gorm:"uniqueIndex:idx_coach_achievement;not null"`
	AchievementID int16 `gorm:"uniqueIndex:idx_coach_achievement;not null"`
	UnlockedAt    time.Time
}

// TableName pins the table name (gorm would otherwise pluralize to
// "coach_achievements" anyway, but the mapping is stated for the same reason as
// the others here).
func (CoachAchievement) TableName() string { return "coach_achievements" }

// CoachCard is one owned card stack. Pos==0 => in inventory; Pos>=1 => equipped
// in wire-slot Pos-1. TemplateID references a gamedata card template (not a FK).
//
// There is deliberately no per-instance flag here. 2.70 has none: the card
// object on the wire is a bare i32 reference id (eb_1.NT() == 4), and every rule
// about what may be traded, mailed, sold or destroyed reads the TEMPLATE's own
// booleans — Bound (tp()) and Undestructible (tq()) — which live in gamedata.
// A `Flag` column carrying "locked"/"cursed" bits used to exist here; nothing
// ever set the locked bit, the cursed bit was written to every card and meant
// nothing, and the client never saw either. See BUGS.md B-094.
type CoachCard struct {
	ID         uint  `gorm:"primaryKey"`
	CoachID    uint  `gorm:"index;not null"`
	TemplateID int32 `gorm:"not null"`
	Quantity   int16 `gorm:"not null;default:1"`
	Pos        int16 `gorm:"not null;default:0"`
}

// Mailbox limits enforced by the client and mirrored server-side.
const (
	// MailboxCapacity is how many mails a coach may hold before sending to them
	// fails ("votre boîte aux lettres est pleine (20 messages)").
	MailboxCapacity = 20
	// MailMaxAttachments is the per-mail attachment cap.
	MailMaxAttachments = 10
	// MailMaxTitle / MailMaxBody are the client's input limits.
	MailMaxTitle = 100
	MailMaxBody  = 800
)

// Mail is one in-game letter between coaches, optionally carrying card
// attachments. A mail stays in the row until BOTH sides have deleted it, so each
// side can delete independently (the client filters on its own flag).
type Mail struct {
	ID                uint   `gorm:"primaryKey"`
	SenderID          uint   `gorm:"index;not null"`
	SenderName        string `gorm:"not null"`
	ReceiverID        uint   `gorm:"index;not null"`
	ReceiverName      string `gorm:"not null"`
	Title             string `gorm:"not null"`
	Body              string `gorm:"not null"`
	SentAtMillis      int64  `gorm:"not null"` // unix millis; the wire carries millis
	Read              bool   `gorm:"not null;default:false"`
	DeletedBySender   bool   `gorm:"not null;default:false"`
	DeletedByReceiver bool   `gorm:"not null;default:false"`
	// Cards are the attachments still waiting to be collected.
	Cards []MailCard `gorm:"foreignKey:MailID;constraint:OnDelete:CASCADE"`
}

// MailCard is one card attached to a Mail. TemplateID references a gamedata card
// template (not a FK). Rows are deleted as the receiver collects them.
type MailCard struct {
	ID         uint  `gorm:"primaryKey"`
	MailID     uint  `gorm:"index;not null"`
	TemplateID int32 `gorm:"not null"`
}

// CoachFriend is a directed friend edge Owner -> Friend.
type CoachFriend struct {
	ID       uint   `gorm:"primaryKey"`
	OwnerID  uint   `gorm:"uniqueIndex:idx_friend_pair;not null"`
	FriendID uint   `gorm:"uniqueIndex:idx_friend_pair;not null"`
	Notify   bool   `gorm:"not null;default:true"`
	Friend   *Coach `gorm:"foreignKey:FriendID"`
}

// CoachCurrency is one balance slot of a coach's multi-currency "token" wallet.
// CurrencyType is the byte currency id used by the client (5403/4001 maps);
// type 1 is the primary shop token. Amount is the balance for that type.
type CoachCurrency struct {
	ID           uint  `gorm:"primaryKey"`
	CoachID      uint  `gorm:"uniqueIndex:idx_wallet_pair;not null"`
	CurrencyType uint8 `gorm:"uniqueIndex:idx_wallet_pair;not null"`
	Amount       int32 `gorm:"not null;default:0"`
}

// CoachIgnored is a directed ignore edge Owner -> Ignored.
type CoachIgnored struct {
	ID        uint   `gorm:"primaryKey"`
	OwnerID   uint   `gorm:"uniqueIndex:idx_ignore_pair;not null"`
	IgnoredID uint   `gorm:"uniqueIndex:idx_ignore_pair;not null"`
	Ignored   *Coach `gorm:"foreignKey:IgnoredID"`
}

// TableName overrides to match a stable snake_case naming.
func (Account) TableName() string       { return "accounts" }
func (*Coach) TableName() string        { return "coaches" }
func (CoachCard) TableName() string     { return "coach_cards" }
func (CoachFriend) TableName() string   { return "coach_friends" }
func (CoachIgnored) TableName() string  { return "coach_ignored" }
func (CoachCurrency) TableName() string { return "coach_currencies" }
func (CoachStat) TableName() string     { return "coach_stats" }

// --- Guilds ("clans" in the UI; the code says guild everywhere, the player-
// facing text says clan, and the two untranslated FR strings that still say
// "guilde" are a translation miss, not a second concept). ---

// Guild is a clan. DemonID is the Demon des Heures it is affiliated to (0 = none)
// and gates the clan island; the client appends it to the displayed name.
type Guild struct {
	ID      uint   `gorm:"primaryKey"`
	Name    string `gorm:"uniqueIndex;size:64;not null"`
	DemonID int16  `gorm:"not null;default:0"`
	// IslandWorld is the clan island allotted to this guild (world 86-109), or 0
	// when it holds none. There are only 24 islands in the shipped data, so this
	// is a scarce, persisted allocation rather than a function of the guild id.
	IslandWorld   int16 `gorm:"not null;default:0"`
	LeaderCoachID uint  `gorm:"not null;index"`
	CreatedAt     time.Time
}

func (Guild) TableName() string { return "guilds" }

// GuildRank is one rung of a guild's ladder. Level 1 is the leader and level 10
// the default rung; the client refuses to delete either and caps a guild at ten
// ranks (`aia_0`). Rights is the bitmask `aen_1` reads: bit0 leader/all,
// bit1 invite, bit2 remove, bit3 promote, bit4 demote - and bit0 grants
// everything, because every accessor is `(rights & 1) | (rights & bit)`.
type GuildRank struct {
	ID      uint   `gorm:"primaryKey"`
	GuildID uint   `gorm:"uniqueIndex:idx_guild_rank_level;not null"`
	Level   int16  `gorm:"uniqueIndex:idx_guild_rank_level;not null"`
	Rights  int32  `gorm:"not null;default:0"`
	Name    string `gorm:"size:64;not null"`
}

func (GuildRank) TableName() string { return "guild_ranks" }

// GuildMember links a coach to a guild at a rank level. A coach can be in at most
// one guild, which the unique index on CoachID enforces at the storage layer
// rather than only in the handler.
type GuildMember struct {
	ID        uint  `gorm:"primaryKey"`
	GuildID   uint  `gorm:"not null;index"`
	CoachID   uint  `gorm:"uniqueIndex;not null"`
	RankLevel int16 `gorm:"not null;default:10"`
	JoinedAt  time.Time
}

func (GuildMember) TableName() string { return "guild_members" }

// GuildDemonReputation is a clan's standing with one Demon des Heures. Earned by
// offering cards at the demon's totem (opcode 5470); the highest-standing clan
// for a demon holds that demon's island.
type GuildDemonReputation struct {
	ID      uint  `gorm:"primaryKey"`
	GuildID uint  `gorm:"uniqueIndex:idx_guild_demon;not null"`
	DemonID int16 `gorm:"uniqueIndex:idx_guild_demon;not null"`
	// Points is the quarterly reputation the demon ladder ranks on.
	Points int64 `gorm:"not null;default:0"`
}

func (GuildDemonReputation) TableName() string { return "guild_demon_reputations" }

// BugReport is one submission from the retail client's built-in bug dialog
// ("Rapport de bug", console command /bugreport). The client does NOT send it
// over the game protocol: it POSTs a multipart/form-data body to
// `<bugReportURL><lang>/bug-report` and expects a body whose first line is
// exactly "OK" (client aOG.a). Field names below are that form's, verbatim.
//
// The screenshot is deliberately NOT a column. It is a full-size JPEG, and:
//   - MySQL's default BLOB caps at 64 KB, which a screenshot exceeds, so an
//     in-table column would work on postgres/sqlite and silently truncate or
//     fail on mysql - the same dialect trap as B-125;
//   - it would land in every nightly pg_dump, so a few hundred reports would
//     bloat every backup by hundreds of MB.
//
// It is written to disk instead (web.bug_report_dir) and referenced by name.
type BugReport struct {
	ID        uint      `gorm:"primaryKey"`
	CreatedAt time.Time `gorm:"index"`

	// What the player typed. Type is the client's own i18n label, e.g.
	// "Affichage / Map / Son" - it is free text on the wire, not an enum.
	Title     string `gorm:"size:255;not null"`
	Type      string `gorm:"size:120"`
	Seen      string `gorm:"type:text"` // bug[seen_comportment]
	Awaited   string `gorm:"type:text"` // bug[awaited_comportment]
	Reproduce string `gorm:"type:text"` // bug[way_to_reproduce]

	// Who reported it. The names are what the CLIENT claimed; AccountID is
	// resolved server-side by looking the name up, and is 0 when it does not
	// match a real account (the endpoint is unauthenticated - see the handler).
	AccountID   uint   `gorm:"index"`
	AccountName string `gorm:"size:64;index"`
	CoachName   string `gorm:"size:64"`
	CoachRef    int64  // user[character][id]
	WorldX      int32
	WorldY      int32
	WorldName   string `gorm:"size:120"`
	Lang        string `gorm:"size:16"`

	// Client environment, for reproducing it.
	ClientVersion string `gorm:"size:120"`
	ScreenWidth   int32
	ScreenHeight  int32
	Fullscreen    bool
	// SystemInfo is the config[...] block (OS, VM, memory, GPU) flattened to
	// one "key=value" per line. The per-thread entries are dropped: the client
	// sends five fields for EVERY live thread, which is hundreds of useless
	// rows, and none of it survives triage.
	SystemInfo string `gorm:"type:text"`

	// Attachments. Text is truncated (tail-kept) to stay inside the smallest
	// TEXT the supported dialects share; ScreenshotFile is a name inside
	// web.bug_report_dir, empty when none was sent or it could not be stored.
	Log            string `gorm:"type:text"`
	Replay         string `gorm:"type:text"`
	ScreenshotFile string `gorm:"size:255"`

	// Triage.
	Resolved   bool   `gorm:"not null;default:false;index"`
	RemoteAddr string `gorm:"size:64"`
}

func (BugReport) TableName() string { return "bug_reports" }

// SetInventory / SetWallet / Inventories are the guarded accessors for the two
// slices that other goroutines write.
//
// SECURITY / CORRECTNESS: Coach.Mu existed but was taken only for the scalar
// snapshot in CoachRepo.Save. Meanwhile the fight actor, the exchange peer's
// goroutine and the shop all assigned sess.Coach.Inventory / .Wallet directly
// while the owning session read them - an unsynchronised slice-header write,
// which is undefined behaviour in Go, not merely a stale read.
//
// The economy itself was never at risk (every mutation goes through a
// transactional repo method that re-reads inside the transaction), so the
// exposure was torn reads and a wrong inventory on screen. That is still worth
// removing, and it is cheap.
func (c *Coach) SetInventory(inv []CoachCard) {
	if c == nil {
		return
	}
	c.Mu.Lock()
	c.Inventory = inv
	c.Mu.Unlock()
}

func (c *Coach) SetWallet(w []CoachCurrency) {
	if c == nil {
		return
	}
	c.Mu.Lock()
	c.Wallet = w
	c.Mu.Unlock()
}

// SnapshotInventory returns the inventory slice header under the lock. Callers
// must not mutate the returned slice's elements.
func (c *Coach) SnapshotInventory() []CoachCard {
	if c == nil {
		return nil
	}
	c.Mu.Lock()
	defer c.Mu.Unlock()
	return c.Inventory
}

// SnapshotWallet is SnapshotInventory's sibling for currencies.
func (c *Coach) SnapshotWallet() []CoachCurrency {
	if c == nil {
		return nil
	}
	c.Mu.Lock()
	defer c.Mu.Unlock()
	return c.Wallet
}
