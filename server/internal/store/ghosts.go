package store

import (
	"errors"

	"gorm.io/gorm"

	"github.com/StarLoco/arena-2.70/internal/domain"
)

// GhostRepo stores ghost teams and the fights played against them (S12).
type GhostRepo struct{ db *gorm.DB }

// Create persists a new ghost team.
func (r *GhostRepo) Create(g *domain.GhostTeam) error {
	return r.db.Create(g).Error
}

// Get loads one ghost team by id.
func (r *GhostRepo) Get(id uint) (*domain.GhostTeam, error) {
	var g domain.GhostTeam
	err := r.db.First(&g, id).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &g, nil
}

// List returns up to limit ghost teams, newest first. The roster and rules
// columns are left out: a list shows names, not fighters.
func (r *GhostRepo) List(limit int) ([]domain.GhostTeam, error) {
	if limit <= 0 {
		limit = 50
	}
	var out []domain.GhostTeam
	err := r.db.Select("id", "coach_id", "name", "created_at", "elo_ghost").
		Order("id DESC").Limit(limit).Find(&out).Error
	return out, err
}

// CountByCoach is how many ghost teams a coach has saved.
func (r *GhostRepo) CountByCoach(coachID uint) (int64, error) {
	var n int64
	err := r.db.Model(&domain.GhostTeam{}).Where("coach_id = ?", coachID).Count(&n).Error
	return n, err
}

// CreateFight records a fight played against a ghost.
func (r *GhostRepo) CreateFight(f *domain.GhostFight) error {
	return r.db.Create(f).Error
}

// GetFight loads one recorded ghost fight.
func (r *GhostRepo) GetFight(id uint) (*domain.GhostFight, error) {
	var f domain.GhostFight
	err := r.db.First(&f, id).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &f, nil
}

// FightsByGhost returns the fights played against a ghost, newest first.
func (r *GhostRepo) FightsByGhost(ghostID uint) ([]domain.GhostFight, error) {
	var out []domain.GhostFight
	err := r.db.Where("ghost_id = ?", ghostID).Order("id DESC").Find(&out).Error
	return out, err
}
