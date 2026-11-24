package store

import (
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
	"time"

	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"

	"github.com/StarLoco/arena-2.70/internal/domain"
)

// Saved accounts (S51, «Guardar mi progreso»): a web demo account becomes an
// ordinary one under the player's email, the browser keeps a key instead of
// the password, and a forgotten password is reset with an emailed code.

// ErrNotDemo is returned when claiming an account that is not a demo one.
var ErrNotDemo = errors.New("store: not a demo account")

// ErrResetWrong is returned for a reset code that does not match (the try
// is counted).
var ErrResetWrong = errors.New("store: wrong reset code")

// ErrResetExpired is returned when there is no usable reset code: none was
// asked for, it expired, or it ran out of tries.
var ErrResetExpired = errors.New("store: reset code expired")

const (
	// ResetCodeTTL is how long an emailed reset code stays valid.
	ResetCodeTTL = 15 * time.Minute
	// ResetMaxAttempts is how many wrong codes end a reset request.
	ResetMaxAttempts = 5
	// maxAccountKeys caps the browser keys of one account; a new one past it
	// replaces the least recently used.
	maxAccountKeys = 20
)

// NormalizeEmail is the form an email login is stored and looked up in:
// trimmed and lower-cased.
func NormalizeEmail(email string) string { return strings.ToLower(strings.TrimSpace(email)) }

func sha256Hex(s string) string {
	sum := sha256.Sum256([]byte(s))
	return hex.EncodeToString(sum[:])
}

// ClaimDemo turns a demo account into an ordinary one (S51): its login
// becomes the email, its password the one given, and the demo's random key
// stays valid as a browser key (account_keys) so the browser keeps logging
// in without ever storing the password. Refused with ErrNotDemo for an
// account that is not a demo one and ErrNameTaken when another account has
// the email. Nothing else changes: the coach, its fighters and cards stay.
func (r *AccountRepo) ClaimDemo(accountID uint, email, password string) error {
	email = NormalizeEmail(email)
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	return r.db.Transaction(func(tx *gorm.DB) error {
		var acc domain.Account
		if err := tx.First(&acc, accountID).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return ErrNotFound
			}
			return err
		}
		if !acc.IsDemo {
			return ErrNotDemo
		}
		var n int64
		if err := tx.Model(&domain.Account{}).
			Where("name = ? AND id <> ?", email, accountID).Count(&n).Error; err != nil {
			return err
		}
		if n > 0 {
			return ErrNameTaken
		}
		now := time.Now()
		key := &domain.AccountKey{AccountID: accountID, KeyHash: acc.PasswordHash,
			CreatedAt: now, LastUsedAt: now}
		if err := tx.Create(key).Error; err != nil {
			return err
		}
		return tx.Model(&domain.Account{}).Where("id = ?", accountID).Updates(map[string]any{
			"name":          email,
			"password_hash": string(hash),
			"is_demo":       false,
		}).Error
	})
}

// AddKey stores a new browser key for the account (its SHA-256). Past
// maxAccountKeys the least recently used ones are dropped.
func (r *AccountRepo) AddKey(accountID uint, key string) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		now := time.Now()
		if err := tx.Create(&domain.AccountKey{AccountID: accountID, KeyHash: sha256Hex(key),
			CreatedAt: now, LastUsedAt: now}).Error; err != nil {
			return err
		}
		var ids []uint
		if err := tx.Model(&domain.AccountKey{}).Where("account_id = ?", accountID).
			Order("last_used_at DESC, id DESC").Offset(maxAccountKeys).
			Limit(1000).Pluck("id", &ids).Error; err != nil {
			return err
		}
		if len(ids) > 0 {
			return tx.Where("id IN ?", ids).Delete(&domain.AccountKey{}).Error
		}
		return nil
	})
}

// VerifyKey reports whether key is one of the account's browser keys, and
// marks it used.
func (r *AccountRepo) VerifyKey(accountID uint, key string) bool {
	if key == "" {
		return false
	}
	var keys []domain.AccountKey
	if err := r.db.Where("account_id = ?", accountID).Find(&keys).Error; err != nil {
		return false
	}
	want := sha256Hex(key)
	for _, k := range keys {
		ok := false
		if strings.HasPrefix(k.KeyHash, "$2") { // a claimed demo's bcrypt key
			ok = bcrypt.CompareHashAndPassword([]byte(k.KeyHash), []byte(key)) == nil
		} else {
			ok = subtle.ConstantTimeCompare([]byte(k.KeyHash), []byte(want)) == 1
		}
		if ok {
			_ = r.db.Model(&domain.AccountKey{}).Where("id = ?", k.ID).
				Update("last_used_at", time.Now()).Error
			return true
		}
	}
	return false
}

// CountKeys is how many browser keys the account has.
func (r *AccountRepo) CountKeys(accountID uint) (int64, error) {
	var n int64
	err := r.db.Model(&domain.AccountKey{}).Where("account_id = ?", accountID).Count(&n).Error
	return n, err
}

// ClearKeys forgets every browser key of the account.
func (r *AccountRepo) ClearKeys(accountID uint) error {
	return r.db.Where("account_id = ?", accountID).Delete(&domain.AccountKey{}).Error
}

func resetHash(accountID uint, code string) string {
	return sha256Hex(fmt.Sprintf("%d:%s", accountID, code))
}

// CreateResetCode stores the account's reset code (its hash), valid for
// ResetCodeTTL from now; it replaces any earlier one.
func (r *AccountRepo) CreateResetCode(accountID uint, code string, now time.Time) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Where("account_id = ?", accountID).Delete(&domain.PasswordReset{}).Error; err != nil {
			return err
		}
		return tx.Create(&domain.PasswordReset{AccountID: accountID, CodeHash: resetHash(accountID, code),
			ExpiresAt: now.Add(ResetCodeTTL), CreatedAt: now}).Error
	})
}

// ResetRequestedAt is when the account's pending reset code was made (ok
// false when there is none).
func (r *AccountRepo) ResetRequestedAt(accountID uint) (time.Time, bool, error) {
	var pr domain.PasswordReset
	err := r.db.Where("account_id = ?", accountID).First(&pr).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return time.Time{}, false, nil
	}
	if err != nil {
		return time.Time{}, false, err
	}
	return pr.CreatedAt, true, nil
}

// VerifyResetCode checks the account's reset code at now. A wrong code
// counts a try (ErrResetWrong); no code, an expired one or one out of tries
// is ErrResetExpired. A right one is used up.
func (r *AccountRepo) VerifyResetCode(accountID uint, code string, now time.Time) error {
	var pr domain.PasswordReset
	err := r.db.Where("account_id = ?", accountID).First(&pr).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return ErrResetExpired
	}
	if err != nil {
		return err
	}
	if now.After(pr.ExpiresAt) || pr.Attempts >= ResetMaxAttempts {
		_ = r.db.Where("account_id = ?", accountID).Delete(&domain.PasswordReset{}).Error
		return ErrResetExpired
	}
	if subtle.ConstantTimeCompare([]byte(pr.CodeHash), []byte(resetHash(accountID, code))) != 1 {
		if err := r.db.Model(&domain.PasswordReset{}).Where("account_id = ?", accountID).
			UpdateColumn("attempts", gorm.Expr("attempts + 1")).Error; err != nil {
			return err
		}
		return ErrResetWrong
	}
	return r.db.Where("account_id = ?", accountID).Delete(&domain.PasswordReset{}).Error
}

// ResetPassword checks the reset code (VerifyResetCode) and, if right, sets
// the new password and forgets every browser key, so a lost or stolen
// browser no longer opens the account.
func (r *AccountRepo) ResetPassword(accountID uint, code, password string, now time.Time) error {
	if err := r.VerifyResetCode(accountID, code, now); err != nil {
		return err
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	return r.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Model(&domain.Account{}).Where("id = ?", accountID).
			Update("password_hash", string(hash)).Error; err != nil {
			return err
		}
		return tx.Where("account_id = ?", accountID).Delete(&domain.AccountKey{}).Error
	})
}
