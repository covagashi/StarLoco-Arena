package store

import (
	"fmt"
	"time"

	"github.com/glebarez/sqlite"

	"gorm.io/gorm"

	"github.com/StarLoco/arena-2.70/internal/domain"
)

// Versioned schema migrations.
//
// The server supports three dialects (sqlite, postgres, mysql), which is what
// decides the shape of this file. Hand-frozen `CREATE TABLE` SQL would have to
// exist three times and drift three ways, so the baseline is expressed through
// GORM's own migrator instead: portable by construction, and identical to what
// every existing database was built with.
//
// What this adds over the bare `AutoMigrate` call it replaces:
//
//   - a `schema_migrations` table recording which steps have run, so a database
//     has a KNOWN version instead of "whatever the models happened to say";
//   - ordered, one-shot steps, each in its own transaction, so a step that fails
//     leaves no half-applied schema and is retried on the next start;
//   - somewhere to put the things AutoMigrate cannot express - dropping or
//     renaming a column, backfilling a row - which is the reason this item
//     existed at all.
//
// AutoMigrate remains the BASELINE step (version 1) rather than being deleted.
// It is additive-only and idempotent, so re-running it against a database built
// by the old code adopts that database unchanged, which is what makes this
// upgrade safe for every operator who already has an `arena.db`. The honest cost
// of that choice: step 1 is defined against the LIVE models, so a purely additive
// model change still lands without a numbered migration. The moment a change is
// destructive - or must be ordered against a data fix - it needs its own entry
// here, and from then on the version number is what tells you where a database
// stands.

// schemaMigration is the bookkeeping row. Deliberately store-private: nothing
// outside migration control should read or write it.
type schemaMigration struct {
	Version   int `gorm:"primaryKey"`
	Name      string
	AppliedAt time.Time
}

func (schemaMigration) TableName() string { return "schema_migrations" }

// migration is one ordered, one-shot schema step.
type migration struct {
	Version int
	Name    string
	Up      func(tx *gorm.DB) error
}

// baselineModels is the model set the initial schema is built from. Keep it in
// sync with the domain package when ADDING a model; when changing an existing
// one destructively, add a numbered migration below instead.
func baselineModels() []any {
	return []any{
		&domain.Account{},
		&domain.Coach{},
		&domain.CoachCard{},
		&domain.CoachFriend{},
		&domain.CoachIgnored{},
		&domain.CoachCurrency{},
		&domain.CoachStat{},
		&domain.CoachAchievement{},
		&domain.CoachTomeCard{},
		&domain.Fighter{},
		&domain.FighterSpell{},
		&domain.FighterObject{},
		&domain.FighterCondition{},
		&domain.FighterSphere{},
		&domain.Team{},
		&domain.TeamFighter{},
		&domain.Mail{},
		&domain.MailCard{},
		&domain.Tournament{},
		&domain.TournamentRegistration{},
		&domain.BugReport{},
		&domain.GhostTeam{},
		&domain.GhostFight{},
	}
}

// migrations is the ordered list. NEVER renumber or edit a shipped entry: a
// database that already recorded a version will not run it again, so changing it
// only makes new installs diverge from old ones. Append instead.
var migrations = []migration{
	{
		Version: 1,
		Name:    "baseline",
		Up: func(tx *gorm.DB) error {
			return tx.AutoMigrate(baselineModels()...)
		},
	},
	{
		// Guilds ("clans"). Additive, so AutoMigrate could have carried it - but
		// it gets its own version anyway: this is the first schema change since
		// the mechanism landed, and a numbered step is what lets a later data
		// migration say "after guilds existed" without guessing.
		Version: 2,
		Name:    "guilds",
		Up: func(tx *gorm.DB) error {
			return tx.AutoMigrate(
				&domain.Guild{},
				&domain.GuildRank{},
				&domain.GuildMember{},
			)
		},
	},
	{
		// Clan islands. Additive again, but numbered for the same reason: it is
		// the version a later "assign islands to existing clans" data step would
		// have to run after.
		Version: 3,
		Name:    "guild_islands",
		Up: func(tx *gorm.DB) error {
			return tx.AutoMigrate(&domain.Guild{})
		},
	},
	{
		// Demon reputation. A clan's island is derived from this rather than
		// stored, so the island column added in 3 is now unused - left in place
		// rather than dropped, because dropping a column is the one thing
		// AutoMigrate cannot do and it costs nothing to keep.
		Version: 4,
		Name:    "guild_demon_reputation",
		Up: func(tx *gorm.DB) error {
			return tx.AutoMigrate(&domain.GuildDemonReputation{})
		},
	},
	{
		// Sphere Board (Kanodo) progress: the fighter's cursor columns and the
		// nodes it has bought. The board GRAPH is client-side data (gamedata
		// types 900/901) - only the progress is ours to keep.
		Version: 5,
		Name:    "fighter_sphere_progress",
		Up: func(tx *gorm.DB) error {
			return tx.AutoMigrate(&domain.Fighter{}, &domain.FighterSphere{})
		},
	},
	{
		// 2v2: a team preset remembers the ally it fights alongside. The id rides
		// the sw_1 blob's trailing coach list, which the client reads back as
		// zK.afG() and sends in 23103 "Combattre".
		//
		// Additive, so the baseline AutoMigrate would carry it on a FRESH
		// database - but an existing one is already recorded at its current
		// version and never re-runs step 1, so without a numbered step here the
		// column simply never appears. That is not hypothetical: it was found by
		// the live server logging "table teams has no column named ally_coach_id"
		// while every test passed against freshly-created databases.
		Version: 6,
		Name:    "team_preset_ally",
		Up: func(tx *gorm.DB) error {
			return tx.AutoMigrate(&domain.Team{})
		},
	},
	{
		// Tournament bracket results. Registrations were already persisted while
		// the bracket they feed was not, so a restart reset every tournament to
		// its first round - which looked like the results had been thrown away,
		// because they had.
		Version: 7,
		Name:    "tournament_bracket_slots",
		Up: func(tx *gorm.DB) error {
			return tx.AutoMigrate(&domain.TournamentSlot{})
		},
	},
	{
		// Additive columns still need their own step: the baseline AutoMigrate
		// only covers a FRESH database, so an existing one is already recorded at
		// its version and never sees them. Tests pass, production breaks with
		// "table tournaments has no column named search_period_start".
		Version: 8,
		Name:    "tournament_search_period",
		Up: func(tx *gorm.DB) error {
			return tx.AutoMigrate(&domain.Tournament{})
		},
	},
	{
		// Bug reports from the retail client's own dialog. Additive, but a
		// numbered step for the usual reason: an existing database is already
		// recorded at its version and never re-runs the baseline, so without
		// this the table simply would not exist in production.
		Version: 9,
		Name:    "bug_reports",
		Up: func(tx *gorm.DB) error {
			return tx.AutoMigrate(&domain.BugReport{})
		},
	},
	{
		// Tournament editions (S09): several search periods, repeat, and the
		// finished state the scheduler sets. Additive columns, numbered step for
		// the same reason as 8.
		Version: 10,
		Name:    "tournament_editions",
		Up: func(tx *gorm.DB) error {
			return tx.AutoMigrate(&domain.Tournament{})
		},
	},
	{
		// Tournament points and the carry-over flags on each entry (S09).
		Version: 11,
		Name:    "tournament_results",
		Up: func(tx *gorm.DB) error {
			return tx.AutoMigrate(&domain.TournamentRegistration{})
		},
	},
	{
		// Player-created tournaments (17010, S09): who created the row.
		Version: 12,
		Name:    "tournament_creator",
		Up: func(tx *gorm.DB) error {
			return tx.AutoMigrate(&domain.Tournament{})
		},
	},
	{
		// Async PvP ghost teams (S12): the frozen line-up and its rules.
		Version: 13,
		Name:    "ghost_teams",
		Up: func(tx *gorm.DB) error {
			return tx.AutoMigrate(&domain.GhostTeam{})
		},
	},
	{
		// The fights played against them, with the seed and arena that replay
		// each one (S12).
		Version: 14,
		Name:    "ghost_fights",
		Up: func(tx *gorm.DB) error {
			return tx.AutoMigrate(&domain.GhostFight{})
		},
	},
}

// runMigrations applies every step the database has not recorded yet, in order.
//
// Each step runs inside a transaction together with the row that records it, so
// the two cannot disagree: a step either applied and is marked, or did neither.
// (SQLite and both server dialects allow DDL in a transaction; a dialect that
// did not would still be correct here, just not atomic.)
func runMigrations(db *gorm.DB) error {
	if err := db.AutoMigrate(&schemaMigration{}); err != nil {
		return fmt.Errorf("store: migrations table: %w", err)
	}
	var applied []schemaMigration
	if err := db.Find(&applied).Error; err != nil {
		return fmt.Errorf("store: read migrations: %w", err)
	}
	done := make(map[int]bool, len(applied))
	for _, a := range applied {
		done[a.Version] = true
	}
	for _, m := range migrations {
		if done[m.Version] {
			continue
		}
		if err := db.Transaction(func(tx *gorm.DB) error {
			if err := m.Up(tx); err != nil {
				return err
			}
			return tx.Create(&schemaMigration{
				Version:   m.Version,
				Name:      m.Name,
				AppliedAt: time.Now().UTC(),
			}).Error
		}); err != nil {
			return fmt.Errorf("store: migration %d (%s): %w", m.Version, m.Name, err)
		}
	}
	return nil
}

// SchemaVersion reports the highest applied migration version (0 = none).
// Exposed so the admin panel and a future `--version` flag can show it.
func (s *Store) SchemaVersion() (int, error) {
	var m schemaMigration
	err := s.db.Order("version DESC").First(&m).Error
	if err == gorm.ErrRecordNotFound {
		return 0, nil
	}
	if err != nil {
		return 0, err
	}
	return m.Version, nil
}

// sqliteDialector is the sqlite dialector used by Open. Exposed inside the
// package so a test can build a database exactly the way the pre-migration
// server did.
func sqliteDialector(path string) gorm.Dialector { return sqlite.Open(path) }
