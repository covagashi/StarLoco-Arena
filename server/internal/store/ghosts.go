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

// Delete removes one ghost team.
func (r *GhostRepo) Delete(id uint) error {
	return r.db.Delete(&domain.GhostTeam{}, id).Error
}

// List returns up to limit ghost teams, newest first. The roster and rules
// columns are left out: a list shows names, not fighters.
func (r *GhostRepo) List(limit int) ([]domain.GhostTeam, error) {
	if limit <= 0 {
		limit = 50
	}
	var out []domain.GhostTeam
	err := r.db.Select("id", "coach_id", "name", "created_at", "elo_ghost", "battles", "wins").
		Order("id DESC").Limit(limit).Find(&out).Error
	return out, err
}

// Candidates is every ghost a challenger may be matched against, light
// columns only, by id: what matchmaking sorts by rating.
func (r *GhostRepo) Candidates() ([]domain.GhostTeam, error) {
	var out []domain.GhostTeam
	err := r.db.Select("id", "coach_id", "name", "elo_ghost").Order("id").Find(&out).Error
	return out, err
}

// CountFillers counts the server-made filler ghosts.
func (r *GhostRepo) CountFillers() (int64, error) {
	return r.CountByCoach(domain.GhostFillerCoach)
}

// SaveRecord writes a ghost's rating and its battles/wins.
func (r *GhostRepo) SaveRecord(id uint, elo, battles, wins int32) error {
	return r.db.Model(&domain.GhostTeam{}).Where("id = ?", id).Updates(map[string]any{
		"elo_ghost": elo, "battles": battles, "wins": wins}).Error
}

// Rating is a coach's ghost-ladder rating; one that never fought starts at
// GhostEloStart with no record.
func (r *GhostRepo) Rating(coachID uint) (domain.GhostRating, error) {
	var g domain.GhostRating
	err := r.db.Where("coach_id = ?", coachID).First(&g).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return domain.GhostRating{CoachID: coachID, Elo: domain.GhostEloStart}, nil
	}
	return g, err
}

// SaveRating stores a coach's ghost-ladder rating (insert or update).
func (r *GhostRepo) SaveRating(g domain.GhostRating) error {
	res := r.db.Model(&domain.GhostRating{}).Where("coach_id = ?", g.CoachID).
		Updates(map[string]any{"elo": g.Elo, "fights": g.Fights, "wins": g.Wins})
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected > 0 {
		return nil
	}
	return r.db.Create(&g).Error
}

// Ladder is the top `limit` coaches by ghost rating, best first (ties by
// fewer fights, then coach id: a stable order).
func (r *GhostRepo) Ladder(limit int) ([]domain.GhostRating, error) {
	if limit <= 0 {
		limit = 50
	}
	var out []domain.GhostRating
	err := r.db.Where("fights > 0").Order("elo DESC").Order("fights ASC").Order("coach_id ASC").
		Limit(limit).Find(&out).Error
	return out, err
}

// RankOf is a coach's place on the ladder (1 = first), 0 if it is not on it.
func (r *GhostRepo) RankOf(coachID uint) (int64, error) {
	me, err := r.Rating(coachID)
	if err != nil || me.Fights == 0 {
		return 0, err
	}
	var above int64
	err = r.db.Model(&domain.GhostRating{}).Where("fights > 0 AND elo > ?", me.Elo).Count(&above).Error
	return above + 1, err
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

// FightsByCoach returns the fights a coach played against ghosts, newest first.
func (r *GhostRepo) FightsByCoach(coachID uint) ([]domain.GhostFight, error) {
	var out []domain.GhostFight
	err := r.db.Where("coach_id = ?", coachID).Order("id DESC").Find(&out).Error
	return out, err
}

// LatestByCoach is the ghost a coach saved last (nil when it has none): the
// team an offline tournament fields for it (S29).
func (r *GhostRepo) LatestByCoach(coachID uint) (*domain.GhostTeam, error) {
	var g domain.GhostTeam
	err := r.db.Where("coach_id = ?", coachID).Order("id DESC").First(&g).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &g, nil
}
