package domain

import "time"

// AccountKey is a browser's key to a saved account (S51, «Guardar mi
// progreso»). The browser never keeps the password: on itch.io every HTML5
// game shares one origin, so whatever one game stores another can read.
// Instead the browser keeps a random 128-bit key and logs in with email +
// key. KeyHash is the key's SHA-256 (hex) — the key is random, so a slow hash
// buys nothing — except for the key a demo account carried over when it was
// saved, whose bcrypt hash (the demo's old PasswordHash) is kept as it was.
type AccountKey struct {
	ID         uint   `gorm:"primaryKey"`
	AccountID  uint   `gorm:"not null;index"`
	KeyHash    string `gorm:"size:120;not null"`
	CreatedAt  time.Time
	LastUsedAt time.Time
}

// PasswordReset is the one pending "forgot my password" code of an account
// (S51): 6 digits, emailed, typed back in the game. A new request replaces
// the old one; it expires and allows a few wrong tries.
type PasswordReset struct {
	AccountID uint      `gorm:"primaryKey;autoIncrement:false"`
	CodeHash  string    `gorm:"size:64;not null"`
	ExpiresAt time.Time `gorm:"not null"`
	Attempts  int       `gorm:"not null;default:0"`
	CreatedAt time.Time
}
