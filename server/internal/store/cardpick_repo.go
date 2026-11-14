package store

import (
	"errors"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"gorm.io/gorm"
)

// CardPickRepo holds each coach's "pick one of three" progress (S40).
type CardPickRepo struct{ db *gorm.DB }

// Get is a coach's progress; a coach with none starts at zero.
func (r *CardPickRepo) Get(coachID uint) (domain.CardPick, error) {
	var p domain.CardPick
	err := r.db.Where("coach_id = ?", coachID).First(&p).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return domain.CardPick{CoachID: coachID}, nil
	}
	return p, err
}

// Save stores a coach's progress (insert or update).
func (r *CardPickRepo) Save(p domain.CardPick) error {
	res := r.db.Model(&domain.CardPick{}).Where("coach_id = ?", p.CoachID).
		Updates(map[string]any{"wins": p.Wins, "picks": p.Picks, "offer": p.Offer})
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected > 0 {
		return nil
	}
	return r.db.Create(&p).Error
}
