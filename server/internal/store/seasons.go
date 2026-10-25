package store

import (
	"errors"
	"time"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"gorm.io/gorm"
)

// SeasonRepo holds the ladder seasons and their results (S25).
type SeasonRepo struct{ db *gorm.DB }

// Open is the season in progress, or nil when there is none yet.
func (r *SeasonRepo) Open() (*domain.Season, error) {
	var s domain.Season
	err := r.db.Where("closed_at IS NULL").Order("number DESC").First(&s).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &s, nil
}

// LastNumber is the highest season number ever opened (0 = none).
func (r *SeasonRepo) LastNumber() (int32, error) {
	var s domain.Season
	err := r.db.Order("number DESC").First(&s).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return 0, nil
	}
	return s.Number, err
}

// Create opens a season.
func (r *SeasonRepo) Create(s *domain.Season) error {
	return r.db.Create(s).Error
}

// Standing is one place on a ladder at close time.
type Standing struct {
	CoachID uint
	Rating  int32
}

// RankedTop is the top n of the 1v1 Ranking, the LadderPage order.
func (r *SeasonRepo) RankedTop(n int) ([]Standing, error) {
	var cs []domain.Coach
	err := r.db.Select("id", "strength").Where("strength > 0").
		Order("strength DESC, name ASC").Limit(n).Find(&cs).Error
	out := make([]Standing, 0, len(cs))
	for _, c := range cs {
		out = append(out, Standing{CoachID: c.ID, Rating: c.Strength})
	}
	return out, err
}

// GhostTop is the top n of the ghost ladder, the GhostRepo.Ladder order.
func (r *SeasonRepo) GhostTop(n int) ([]Standing, error) {
	var gs []domain.GhostRating
	err := r.db.Where("fights > 0").Order("elo DESC").Order("fights ASC").
		Order("coach_id ASC").Limit(n).Find(&gs).Error
	out := make([]Standing, 0, len(gs))
	for _, g := range gs {
		out = append(out, Standing{CoachID: g.CoachID, Rating: g.Elo})
	}
	return out, err
}

// Close settles a season in one transaction: it records the results, pays
// their pesetas, soft-resets both ladders (Strength towards StrengthMin, the
// ghost Elo towards GhostEloStart) and marks the season closed. A season that
// is already closed is left alone (false).
func (r *SeasonRepo) Close(seasonID uint, results []domain.SeasonResult, now time.Time) (bool, error) {
	closed := false
	err := r.db.Transaction(func(tx *gorm.DB) error {
		res := tx.Model(&domain.Season{}).Where("id = ? AND closed_at IS NULL", seasonID).
			Update("closed_at", now.UTC())
		if res.Error != nil {
			return res.Error
		}
		if res.RowsAffected == 0 {
			return nil // already closed
		}
		closed = true
		for i := range results {
			if err := tx.Create(&results[i]).Error; err != nil {
				return err
			}
			if results[i].Pesetas > 0 {
				if err := creditTx(tx, results[i].CoachID, domain.CurrencyPesetas, results[i].Pesetas); err != nil {
					return err
				}
			}
		}
		var cs []domain.Coach
		if err := tx.Select("id", "strength").Where("strength > ?", domain.StrengthMin).Find(&cs).Error; err != nil {
			return err
		}
		for _, c := range cs {
			if err := tx.Model(&domain.Coach{}).Where("id = ?", c.ID).
				Update("strength", domain.SoftReset(c.Strength, domain.StrengthMin)).Error; err != nil {
				return err
			}
		}
		var gs []domain.GhostRating
		if err := tx.Where("elo <> ?", domain.GhostEloStart).Find(&gs).Error; err != nil {
			return err
		}
		for _, g := range gs {
			if err := tx.Model(&domain.GhostRating{}).Where("coach_id = ?", g.CoachID).
				Update("elo", domain.SoftReset(g.Elo, domain.GhostEloStart)).Error; err != nil {
				return err
			}
		}
		return nil
	})
	return closed, err
}

// creditTx is CoachRepo.CreditCurrency inside an open transaction.
func creditTx(tx *gorm.DB, coachID uint, ctype uint8, delta int32) error {
	var wallet domain.CoachCurrency
	err := tx.Where("coach_id = ? AND currency_type = ?", coachID, ctype).First(&wallet).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return tx.Create(&domain.CoachCurrency{CoachID: coachID, CurrencyType: ctype, Amount: delta}).Error
	}
	if err != nil {
		return err
	}
	return tx.Model(&domain.CoachCurrency{}).Where("id = ?", wallet.ID).
		Update("amount", addCurrencySaturating(wallet.Amount, delta)).Error
}

// TakeUnseen returns a coach's season results the client has not been told
// about yet, and marks them seen.
func (r *SeasonRepo) TakeUnseen(coachID uint) ([]domain.SeasonResult, error) {
	var out []domain.SeasonResult
	err := r.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Where("coach_id = ? AND seen = ?", coachID, false).
			Order("season ASC, ladder ASC").Find(&out).Error; err != nil {
			return err
		}
		if len(out) == 0 {
			return nil
		}
		return tx.Model(&domain.SeasonResult{}).Where("coach_id = ? AND seen = ?", coachID, false).
			Update("seen", true).Error
	})
	return out, err
}
