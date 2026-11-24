package store

import (
	"errors"
	"strings"
	"time"

	"gorm.io/gorm"

	"github.com/StarLoco/arena-2.70/internal/domain"
)

// This file holds the account queries the web portal's admin console needs and
// the game server never did: searching and paging the account list, counting
// who is connected, and deleting an account outright.

// ErrAccountConnected refuses a delete while the account is logged in. Pulling
// the row out from under a live session would leave the game server holding a
// coach whose account no longer exists.
var ErrAccountConnected = errors.New("store: account is connected")

// AccountSummary is one row of the admin console's account table. It is a flat
// projection rather than a domain.Account because the console shows the coach's
// name and rating alongside the account, and because domain.Coach embeds a
// mutex that must not be copied.
type AccountSummary struct {
	ID        uint
	Name      string
	IsAdmin   bool
	Connected bool
	CoachName string
	Strength  int32
	CreatedAt time.Time
}

// ListAccounts returns one page of accounts plus the total number of matches.
//
// query matches either the account name or the coach's name, case-insensitively
// and as a substring, so an admin can find a player from whichever of the two
// names they were given. An empty query lists everything.
func (r *AccountRepo) ListAccounts(query string, offset, limit int) ([]AccountSummary, int64, error) {
	if limit <= 0 {
		limit = 25
	}
	if offset < 0 {
		offset = 0
	}

	// LEFT JOIN: an account with no coach yet must still be listed, otherwise
	// a freshly registered player would be invisible to the console.
	base := r.db.Model(&domain.Account{}).
		Joins("LEFT JOIN coaches ON coaches.id = accounts.coach_id")

	if q := strings.TrimSpace(query); q != "" {
		// LOWER() on both sides rather than COLLATE NOCASE: the latter is
		// SQLite-only and this has to work on postgres and mysql too.
		like := "%" + strings.ToLower(q) + "%"
		base = base.Where("LOWER(accounts.name) LIKE ? OR LOWER(COALESCE(coaches.name, '')) LIKE ?", like, like)
	}

	var total int64
	if err := base.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	var rows []AccountSummary
	err := base.
		Select("accounts.id AS id, accounts.name AS name, accounts.is_admin AS is_admin, " +
			"accounts.connected AS connected, accounts.created_at AS created_at, " +
			"COALESCE(coaches.name, '') AS coach_name, COALESCE(coaches.strength, 0) AS strength").
		Order("accounts.id ASC").
		Offset(offset).
		Limit(limit).
		Scan(&rows).Error
	if err != nil {
		return nil, 0, err
	}
	return rows, total, nil
}

// CountConnected returns how many accounts are currently flagged connected.
//
// This counts the *persisted* flag rather than live sessions, so it stays
// correct for the admin table's per-row badge, which is rendered from the same
// column. Startup calls ResetConnectedFlags, so a crash cannot leave it stuck.
func (r *AccountRepo) CountConnected() (int64, error) {
	var n int64
	if err := r.db.Model(&domain.Account{}).Where("connected = ?", true).Count(&n).Error; err != nil {
		return 0, err
	}
	return n, nil
}

// DeleteAccount removes an account and everything hanging off it.
//
// It refuses to touch a connected account (ErrAccountConnected): the game
// server holds that coach in memory and would happily keep saving it back.
// The connected check and the delete run in one transaction so an account that
// logs in halfway through cannot slip past the check.
//
// Mail the coach *received* is deleted with them; mail they *sent* is left
// alone, because it belongs to whoever received it — and Mail stores
// SenderName as a plain string, so those messages still render correctly after
// the sender is gone.
func (r *AccountRepo) DeleteAccount(id uint) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		var acc domain.Account
		if err := tx.First(&acc, id).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return ErrNotFound
			}
			return err
		}
		if acc.Connected {
			return ErrAccountConnected
		}

		if acc.CoachID != nil {
			coachID := *acc.CoachID

			// Received mail and its attachments.
			var mailIDs []uint
			if err := tx.Model(&domain.Mail{}).
				Where("receiver_id = ?", coachID).
				Pluck("id", &mailIDs).Error; err != nil {
				return err
			}
			if len(mailIDs) > 0 {
				if err := tx.Where("mail_id IN ?", mailIDs).
					Delete(&domain.MailCard{}).Error; err != nil {
					return err
				}
				if err := tx.Where("id IN ?", mailIDs).
					Delete(&domain.Mail{}).Error; err != nil {
					return err
				}
			}

			// Everything else cascades through the coach. Reuse the same
			// transaction so the whole delete is atomic.
			if err := (&CoachRepo{db: tx}).DeleteCoach(coachID); err != nil {
				return err
			}
		}

		// Browser keys and a pending reset code (S51).
		if err := tx.Where("account_id = ?", id).Delete(&domain.AccountKey{}).Error; err != nil {
			return err
		}
		if err := tx.Where("account_id = ?", id).Delete(&domain.PasswordReset{}).Error; err != nil {
			return err
		}
		return tx.Delete(&domain.Account{}, id).Error
	})
}
