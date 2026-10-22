package store

import (
	"errors"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"github.com/StarLoco/arena-2.70/internal/domain"
)

// TournamentRepo persists the standing tournaments the server offers. They were
// a compiled-in table until the web console needed to edit them.
type TournamentRepo struct{ db *gorm.DB }

// List returns every tournament, in the order players see them.
func (r *TournamentRepo) List() ([]domain.Tournament, error) {
	var out []domain.Tournament
	err := r.db.Order("position ASC, id ASC").Find(&out).Error
	return out, err
}

// ListEnabled returns only the tournaments currently offered to players:
// enabled, and not a finished edition.
func (r *TournamentRepo) ListEnabled() ([]domain.Tournament, error) {
	var out []domain.Tournament
	err := r.db.Where("enabled = ? AND finished_at IS NULL", true).
		Order("position ASC, id ASC").Find(&out).Error
	return out, err
}

// MarkFinished ends an edition, once. It reports whether THIS call did it: the
// WHERE on finished_at makes two racing finishers (a tick and a fight end)
// agree on a single one, so the follow-up (next edition, prize) runs once.
func (r *TournamentRepo) MarkFinished(id uint, winner uint, at time.Time) (bool, error) {
	res := r.db.Model(&domain.Tournament{}).
		Where("id = ? AND finished_at IS NULL", id).
		Updates(map[string]any{"finished_at": at, "winner_coach_id": winner})
	return res.RowsAffected > 0, res.Error
}

// NextEdition returns the edition repeated from `id`, if one exists.
func (r *TournamentRepo) NextEdition(id uint) (*domain.Tournament, error) {
	var t domain.Tournament
	err := r.db.Where("previous_id = ?", id).Order("id ASC").First(&t).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &t, nil
}

// Get loads one tournament by row id.
func (r *TournamentRepo) Get(id uint) (*domain.Tournament, error) {
	var t domain.Tournament
	err := r.db.First(&t, id).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &t, nil
}

// GetByWireID loads the tournament a client is referring to.
func (r *TournamentRepo) GetByWireID(wireID int64) (*domain.Tournament, error) {
	id := wireID - domain.TournamentWireBase
	if id <= 0 {
		return nil, ErrNotFound
	}
	return r.Get(uint(id))
}

// Create inserts a tournament.
func (r *TournamentRepo) Create(t *domain.Tournament) error {
	return r.db.Create(t).Error
}

// Update saves an edited tournament. It writes the editable columns explicitly
// so a zero value (an emptied description, a disabled flag) is persisted —
// GORM's Updates with a struct skips zero values and would silently ignore
// exactly the changes an admin is most likely to make.
func (r *TournamentRepo) Update(t *domain.Tournament) error {
	return r.db.Model(&domain.Tournament{}).Where("id = ?", t.ID).
		Updates(map[string]any{
			"def_id":            t.DefID,
			"name":              t.Name,
			"short":             t.Short,
			"description":       t.Description,
			"organizer":         t.Organizer,
			"enabled":           t.Enabled,
			"registration_open": t.RegistrationOpen,
			"position":          t.Position,
			// The schedule is editable too; it used to be left out, so a
			// tournament could only be given one by editing the database.
			"search_period_start":     t.SearchPeriodStart,
			"search_period_minutes":   t.SearchPeriodMinutes,
			"search_periods":          t.SearchPeriods,
			"period_interval_minutes": t.PeriodIntervalMinutes,
			"repeat_days":             t.RepeatDays,
		}).Error
}

// Delete removes a tournament.
func (r *TournamentRepo) Delete(id uint) error {
	res := r.db.Delete(&domain.Tournament{}, id)
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return ErrNotFound
	}
	// Registrations are keyed by WIRE id and have no FK, so they would otherwise
	// outlive the tournament as orphans — and, because the wire id is derived
	// from the row id, be inherited by whatever row reused that id later.
	tid := domain.TournamentWireBase + int64(id)
	if err := r.DeleteRegistrationsFor(tid); err != nil {
		return err
	}
	// The bracket is keyed the same way and would be inherited the same way.
	return r.db.Where("tournament_wire_id = ?", tid).
		Delete(&domain.TournamentSlot{}).Error
}

// --- registrations ---
//
// Keyed by the tournament's WIRE id: that is what the client sends in 4607 and
// what the manager caches, and it is stable across restarts because it is derived
// from the row id.

// ListRegistrations returns every stored registration, for loading the in-memory
// cache at startup.
func (r *TournamentRepo) ListRegistrations() ([]domain.TournamentRegistration, error) {
	var out []domain.TournamentRegistration
	err := r.db.Find(&out).Error
	return out, err
}

// AddRegistration records one coach's entry, idempotently: the (coach, tid) pair
// carries a unique index, and a duplicate insert is not an error here because the
// caller has usually already decided the registration is new.
func (r *TournamentRepo) AddRegistration(coachID uint, tid int64) error {
	reg := domain.TournamentRegistration{CoachID: coachID, TournamentWireID: tid}
	return r.db.Where("coach_id = ? AND tournament_wire_id = ?", coachID, tid).
		FirstOrCreate(&reg).Error
}

// RemoveRegistration withdraws one coach from one tournament.
func (r *TournamentRepo) RemoveRegistration(coachID uint, tid int64) error {
	return r.db.Where("coach_id = ? AND tournament_wire_id = ?", coachID, tid).
		Delete(&domain.TournamentRegistration{}).Error
}

// DeleteRegistrationsFor drops every registration for one tournament.
func (r *TournamentRepo) DeleteRegistrationsFor(tid int64) error {
	return r.db.Where("tournament_wire_id = ?", tid).
		Delete(&domain.TournamentRegistration{}).Error
}

// Count returns how many tournaments exist.
func (r *TournamentRepo) Count() (int64, error) {
	var n int64
	err := r.db.Model(&domain.Tournament{}).Count(&n).Error
	return n, err
}

// DefaultTournaments is the line-up a fresh server starts with. It is the table
// that used to be compiled into the game package, kept so a new install behaves
// exactly as before and an operator has something to edit rather than a blank
// page.
//
// The def ids are real no-card client definitions: 1 and 4 are classic 1v1
// (team type 1), 17 is the graveyard type (3), which is why the third is named
// for it.
func DefaultTournaments() []domain.Tournament {
	return []domain.Tournament{
		{
			DefID: 1, Position: 1,
			Name:        "Tournoi 1v1 Classique",
			Short:       "Classique",
			Description: "Affrontez les meilleurs coachs dans un tournoi 1 contre 1.",
			Organizer:   "StarLoco",
			Enabled:     true, RegistrationOpen: true,
		},
		{
			DefID: 4, Position: 2,
			Name:        "Tournoi des Champions",
			Short:       "Champions",
			Description: "Un tournoi d'elite reserve aux coachs les plus aguerris.",
			Organizer:   "StarLoco",
			Enabled:     true, RegistrationOpen: true,
		},
		{
			DefID: 17, Position: 3,
			Name:        "Tournoi du Cimetiere",
			Short:       "Cimetiere",
			Description: "Un tournoi hante ou seuls les plus braves osent s'inscrire.",
			Organizer:   "StarLoco",
			Enabled:     true, RegistrationOpen: true,
		},
	}
}

// SeedDefaults inserts DefaultTournaments when the table is empty, and reports
// how many it added.
//
// It seeds only an EMPTY table on purpose: an operator who deletes a tournament
// means it, and having it reappear on the next restart would be maddening.
func (r *TournamentRepo) SeedDefaults() (int, error) {
	n, err := r.Count()
	if err != nil || n > 0 {
		return 0, err
	}
	defaults := DefaultTournaments()
	for i := range defaults {
		if err := r.Create(&defaults[i]); err != nil {
			return i, err
		}
	}
	return len(defaults), nil
}

// ListSlots returns every stored bracket slot (all tournaments), for priming the
// in-memory bracket at boot.
func (r *TournamentRepo) ListSlots() ([]domain.TournamentSlot, error) {
	var out []domain.TournamentSlot
	err := r.db.Find(&out).Error
	return out, err
}

// SetSlot records the occupant of a bracket slot, replacing any previous one.
//
// Upsert rather than insert: a slot is decided once, but a fixture can be
// replayed (a disconnect, a GM ending a fight), and the later result is the one
// that stands.
func (r *TournamentRepo) SetSlot(tid int64, slot int32, coachID uint) error {
	return r.db.Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "tournament_wire_id"}, {Name: "slot"}},
		DoUpdates: clause.AssignmentColumns([]string{"coach_id"}),
	}).Create(&domain.TournamentSlot{
		TournamentWireID: tid, Slot: slot, CoachID: coachID,
	}).Error
}

// ClaimTournamentPrize atomically records that a coach has been paid a
// tournament's reward, and reports whether THIS call was the one that claimed it.
// A second call returns false, so the reward can only ever be granted once.
//
// SECURITY: awardTournamentPrize had no already-paid record at all, and the path
// that reaches it (28611, the tournament search) re-derives "unopposed in this
// tournament" from persisted bracket state - so it stays true once you hold the
// root slot and each packet paid another copy of the reward card.
//
// This is a pay-once LEDGER, not an eligibility check: if no registration row
// exists it inserts one rather than refusing. That distinction matters. Requiring
// a registration would have added a second rule about WHO may be paid, and
// unregistration happens elsewhere in the lifecycle - so a legitimate winner
// could have been silently denied their prize. Eligibility is the caller's
// business; this function only guarantees "at most once".
//
// Both paths are race-safe: the UPDATE carries prize_awarded = false in its WHERE
// clause so exactly one of two concurrent claims can match, and the INSERT is
// protected by the unique (coach_id, tournament_wire_id) index, whose violation
// is treated as "someone else claimed it".
func (r *TournamentRepo) ClaimTournamentPrize(coachID uint, tid int64) (bool, error) {
	res := r.db.Model(&domain.TournamentRegistration{}).
		Where("coach_id = ? AND tournament_wire_id = ? AND prize_awarded = ?",
			coachID, tid, false).
		Update("prize_awarded", true)
	if res.Error != nil {
		return false, res.Error
	}
	if res.RowsAffected > 0 {
		return true, nil
	}

	// No unpaid row matched: either it is already paid, or there is no row.
	var existing int64
	if err := r.db.Model(&domain.TournamentRegistration{}).
		Where("coach_id = ? AND tournament_wire_id = ?", coachID, tid).
		Count(&existing).Error; err != nil {
		return false, err
	}
	if existing > 0 {
		return false, nil // already paid
	}

	reg := &domain.TournamentRegistration{
		CoachID:          coachID,
		TournamentWireID: tid,
		PrizeAwarded:     true,
	}
	if err := r.db.Create(reg).Error; err != nil {
		// Unique-index violation means a concurrent claim won; anything else is a
		// real error, but either way this call did not claim.
		return false, nil
	}
	return true, nil
}
