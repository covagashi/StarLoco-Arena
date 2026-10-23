// Package store is the persistence layer. It is ORM-backed (GORM) so the
// database is a configuration choice: SQLite for dev, PostgreSQL or MySQL for
// production, selected by driver + DSN without touching game logic.
package store

import (
	"fmt"
	"strings"
	"time"

	"github.com/glebarez/sqlite"
	"gorm.io/driver/mysql"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"

	"github.com/StarLoco/arena-2.70/internal/domain"
)

// Config selects and tunes the database backend.
type Config struct {
	Driver       string // sqlite | postgres | mysql
	DSN          string // driver-specific; for sqlite a file path
	MaxOpenConns int
	MaxIdleConns int
}

// Store wraps the GORM DB handle and repositories.
type Store struct {
	db       *gorm.DB
	Accounts *AccountRepo
	Coaches  *CoachRepo
	Fighters *FighterRepo
	Teams    *TeamRepo
	Mail     *MailRepo
	// Tournaments are the standing events the web console edits.
	Tournaments *TournamentRepo
	Guilds      *GuildRepo
	// BugReports are submissions from the retail client's own bug dialog.
	BugReports *BugReportRepo
	// Ghosts are the async-PvP ghost teams and the fights against them (S12).
	Ghosts *GhostRepo
}

// Open connects to a SQLite database at path (dev convenience / tests) and
// migrates the schema. Equivalent to OpenConfig with the sqlite driver.
func Open(path string) (*Store, error) {
	return OpenConfig(Config{Driver: "sqlite", DSN: path, MaxOpenConns: 1, MaxIdleConns: 1})
}

// dialector returns the GORM dialector for the configured driver.
func dialector(c Config) (gorm.Dialector, bool, error) {
	switch strings.ToLower(c.Driver) {
	case "sqlite", "":
		return sqlite.Open(c.DSN), true, nil
	case "postgres", "postgresql":
		return postgres.Open(c.DSN), false, nil
	case "mysql", "mariadb":
		return mysql.Open(c.DSN), false, nil
	default:
		return nil, false, fmt.Errorf("store: unknown driver %q", c.Driver)
	}
}

// OpenConfig connects using the configured driver, tunes the pool, applies
// migrations and returns a ready Store.
func OpenConfig(c Config) (*Store, error) {
	dial, isSQLite, err := dialector(c)
	if err != nil {
		return nil, err
	}
	gdb, err := gorm.Open(dial, &gorm.Config{
		Logger:                 logger.Default.LogMode(logger.Silent),
		PrepareStmt:            true, // cache prepared statements (throughput)
		SkipDefaultTransaction: true, // we manage txns explicitly where needed
	})
	if err != nil {
		return nil, fmt.Errorf("store: open (%s): %w", c.Driver, err)
	}

	// Any failure from here on must hand the connection back, not abandon it: a
	// leaked handle keeps the file open, which on Windows also keeps it LOCKED -
	// so a server that failed to start once could not be restarted cleanly, and a
	// test could not delete its own temp database.
	failed := func(err error) (*Store, error) {
		if sqlDB, derr := gdb.DB(); derr == nil {
			_ = sqlDB.Close()
		}
		return nil, err
	}

	if isSQLite {
		// Pragmas: WAL for concurrent reads, busy timeout to avoid SQLITE_BUSY.
		for _, pragma := range []string{
			"PRAGMA journal_mode=WAL",
			"PRAGMA busy_timeout=5000",
			"PRAGMA foreign_keys=ON",
		} {
			if err := gdb.Exec(pragma).Error; err != nil {
				return failed(fmt.Errorf("store: %s: %w", pragma, err))
			}
		}
	}

	// Connection pool tuning (server DBs benefit from concurrent connections;
	// sqlite is single-writer so we keep it at 1).
	if sqlDB, err := gdb.DB(); err == nil {
		if c.MaxOpenConns > 0 {
			sqlDB.SetMaxOpenConns(c.MaxOpenConns)
		}
		if c.MaxIdleConns > 0 {
			sqlDB.SetMaxIdleConns(c.MaxIdleConns)
		}
		sqlDB.SetConnMaxLifetime(time.Hour)
	}

	// Versioned migrations (see migrations.go). Replaces the bare AutoMigrate
	// call that used to live here: the schema now has a recorded version, so a
	// destructive change or a data backfill has somewhere to go.
	if err := runMigrations(gdb); err != nil {
		return failed(err)
	}

	s := &Store{db: gdb}
	s.Accounts = &AccountRepo{db: gdb}
	s.Coaches = &CoachRepo{db: gdb}
	s.Fighters = &FighterRepo{db: gdb}
	s.Teams = &TeamRepo{db: gdb}
	s.Mail = &MailRepo{db: gdb}
	s.Tournaments = &TournamentRepo{db: gdb}
	s.Guilds = &GuildRepo{db: gdb}
	s.BugReports = &BugReportRepo{db: gdb}
	s.Ghosts = &GhostRepo{db: gdb}

	// A fresh database starts with the line-up that used to be compiled in, so
	// a new install behaves as before and an admin has something to edit.
	if _, err := s.Tournaments.SeedDefaults(); err != nil {
		return nil, fmt.Errorf("store: seed tournaments: %w", err)
	}
	return s, nil
}

// DB exposes the underlying handle for advanced/transaction use.
func (s *Store) DB() *gorm.DB { return s.db }

// Close releases the underlying database connection.
func (s *Store) Close() error {
	sqlDB, err := s.db.DB()
	if err != nil {
		return err
	}
	return sqlDB.Close()
}

// ResetConnectedFlags clears stale connected=true rows on startup (crash
// recovery), so a previous unclean shutdown doesn't lock accounts out.
func (s *Store) ResetConnectedFlags() error {
	return s.db.Model(&domain.Account{}).
		Where("connected = ?", true).
		Update("connected", false).Error
}
