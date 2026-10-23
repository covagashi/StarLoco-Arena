package domain

import "time"

// GhostTeam is a saved snapshot of a coach's line-up that other coaches fight
// while its owner is offline (async PvP phase 3, godot/ASYNC-PVP.md). It is a
// RECORDING: the fighters are frozen as they were when it was saved, so the
// owner changing their team later does not change the ghost.
type GhostTeam struct {
	ID        uint      `gorm:"primaryKey"`
	CoachID   uint      `gorm:"index;not null"`
	Name      string    `gorm:"size:32;not null"`
	CreatedAt time.Time `gorm:"index"`
	// Roster is the JSON of the frozen []Fighter, ids zeroed (see
	// game/ghost.go): spells already filtered for legality, sphere spells
	// included, cards and conditions as they were.
	Roster string `gorm:"type:text;not null"`
	// Rules is the JSON of the per-fighter gambit rule sets, by roster index
	// ({"0": {...}, "2": {...}}); "" or "{}" = archetype AI for everyone.
	Rules string `gorm:"type:text"`
	// EloGhost is the ghost-ladder rating (S14); 1000 until then.
	EloGhost int32 `gorm:"not null;default:1000"`
}

// TableName pins the table name.
func (GhostTeam) TableName() string { return "ghost_teams" }

// GhostFight is one fight against a ghost: what it takes to play it again
// exactly (seed + arena) and what came out of it, to check that it did.
type GhostFight struct {
	ID        uint      `gorm:"primaryKey"`
	GhostID   uint      `gorm:"index;not null"`
	CoachID   uint      `gorm:"index;not null"` // the challenger
	CreatedAt time.Time `gorm:"index"`
	Seed      int64     `gorm:"not null"`
	ArenaID   uint16    `gorm:"not null"`
	// WinnerTeam is 0 (the challenger) or 1 (the ghost). No column default:
	// GORM writes a zero field as the default, so `default:-1` stored every
	// challenger win as -1.
	WinnerTeam int8  `gorm:"not null"`
	Rounds     int32 `gorm:"not null;default:0"`
	// DecisionHash is the SHA-256 (hex) of the fight's decision log: two runs
	// of the same seed, arena and inputs must produce the same one.
	DecisionHash string `gorm:"size:64"`
	// ReplayOf is the GhostFight this one re-ran (0 = a fresh fight).
	ReplayOf uint `gorm:"not null;default:0"`
}

// TableName pins the table name.
func (GhostFight) TableName() string { return "ghost_fights" }
