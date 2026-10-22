package store

import (
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"gorm.io/gorm"
)

func TestUpsertStat(t *testing.T) {
	s := newTestStore(t)
	acc, _ := s.Accounts.CreateAccount("Stats", "pw", false)
	coach, _ := s.Coaches.Create(acc.ID, "Achiever", 0, 0, 0)

	// Insert.
	if err := s.Coaches.UpsertStat(coach.ID, 229, 1); err != nil {
		t.Fatalf("UpsertStat insert: %v", err)
	}
	var stat domain.CoachStat
	if err := s.DB().Where("coach_id = ? AND stat_id = ?", coach.ID, 229).
		First(&stat).Error; err != nil {
		t.Fatalf("load stat: %v", err)
	}
	if stat.Value != 1 {
		t.Errorf("value after insert = %d, want 1", stat.Value)
	}

	// Update overwrites (no duplicate row).
	if err := s.Coaches.UpsertStat(coach.ID, 229, 5); err != nil {
		t.Fatalf("UpsertStat update: %v", err)
	}
	var count int64
	s.DB().Model(&domain.CoachStat{}).
		Where("coach_id = ? AND stat_id = ?", coach.ID, 229).Count(&count)
	if count != 1 {
		t.Errorf("row count = %d, want 1 (upsert must not duplicate)", count)
	}
	s.DB().Where("coach_id = ? AND stat_id = ?", coach.ID, 229).First(&stat)
	if stat.Value != 5 {
		t.Errorf("value after update = %d, want 5", stat.Value)
	}
}

func TestDeleteCoach(t *testing.T) {
	s := newTestStore(t)
	// Separate accounts: an account owns at most one coach, so creating a
	// second coach on the same account would just relink it.
	acc, _ := s.Accounts.CreateAccount("Owner", "pw", false)
	otherAcc, _ := s.Accounts.CreateAccount("Neighbor", "pw", false)
	victim, _ := s.Coaches.Create(acc.ID, "Victim", 1, 2, 0)
	other, _ := s.Coaches.Create(otherAcc.ID, "Bystander", 0, 0, 0)

	// Seed every kind of associated data.
	s.DB().Create(&domain.CoachCard{CoachID: victim.ID, TemplateID: 700, Quantity: 3})
	s.DB().Create(&domain.CoachCurrency{CoachID: victim.ID, CurrencyType: 1, Amount: 500})
	if err := s.Coaches.UpsertStat(victim.ID, 229, 1); err != nil {
		t.Fatalf("seed stat: %v", err)
	}

	fighter := &domain.Fighter{
		CoachID: victim.ID, BreedID: 5, Name: "Champ",
		Spells:  []domain.FighterSpell{{Slot: 0, SpellID: 1}},
		Objects: []domain.FighterObject{{Slot: 0, TemplateID: 10}},
	}
	if err := s.Fighters.Create(fighter); err != nil {
		t.Fatalf("seed fighter: %v", err)
	}
	team := &domain.Team{
		CoachID: victim.ID, Name: "A",
		Members: []domain.TeamFighter{{FighterID: fighter.ID}},
	}
	if err := s.DB().Create(team).Error; err != nil {
		t.Fatalf("seed team: %v", err)
	}

	// Reciprocal social edges: victim<->other in both directions.
	s.DB().Create(&domain.CoachFriend{OwnerID: victim.ID, FriendID: other.ID})
	s.DB().Create(&domain.CoachFriend{OwnerID: other.ID, FriendID: victim.ID})   // reverse
	s.DB().Create(&domain.CoachIgnored{OwnerID: other.ID, IgnoredID: victim.ID}) // reverse

	// Act.
	if err := s.Coaches.DeleteCoach(victim.ID); err != nil {
		t.Fatalf("DeleteCoach: %v", err)
	}

	// The account is unlinked (returns to coach-creation flow).
	reloaded, _ := s.Accounts.FindByName("Owner")
	if reloaded.CoachID != nil {
		t.Errorf("account.CoachID = %v, want nil after delete", reloaded.CoachID)
	}

	// The coach row is gone.
	if _, err := s.Coaches.Get(victim.ID); err != ErrNotFound {
		t.Errorf("Get(victim) err = %v, want ErrNotFound", err)
	}

	// Every associated table has no rows for the victim.
	assertNone := func(name string, model any, where string, args ...any) {
		var n int64
		s.DB().Model(model).Where(where, args...).Count(&n)
		if n != 0 {
			t.Errorf("%s: %d rows remain, want 0", name, n)
		}
	}
	assertNone("coach_cards", &domain.CoachCard{}, "coach_id = ?", victim.ID)
	assertNone("coach_currencies", &domain.CoachCurrency{}, "coach_id = ?", victim.ID)
	assertNone("coach_stats", &domain.CoachStat{}, "coach_id = ?", victim.ID)
	assertNone("fighters", &domain.Fighter{}, "coach_id = ?", victim.ID)
	assertNone("fighter_spells", &domain.FighterSpell{}, "fighter_id = ?", fighter.ID)
	assertNone("fighter_objects", &domain.FighterObject{}, "fighter_id = ?", fighter.ID)
	assertNone("teams", &domain.Team{}, "coach_id = ?", victim.ID)
	assertNone("team_fighters", &domain.TeamFighter{}, "team_id = ?", team.ID)
	assertNone("coach_friends (any edge)", &domain.CoachFriend{},
		"owner_id = ? OR friend_id = ?", victim.ID, victim.ID)
	assertNone("coach_ignored (any edge)", &domain.CoachIgnored{},
		"owner_id = ? OR ignored_id = ?", victim.ID, victim.ID)

	// The bystander coach survives untouched.
	if _, err := s.Coaches.Get(other.ID); err != nil {
		t.Errorf("bystander should survive: %v", err)
	}
}

// TestDeleteCoachMissing ensures deleting a non-existent coach is a harmless
// no-op (the transaction commits without error).
func TestDeleteCoachMissing(t *testing.T) {
	s := newTestStore(t)
	if err := s.Coaches.DeleteCoach(999999); err != nil && err != gorm.ErrRecordNotFound {
		t.Fatalf("DeleteCoach(missing) err = %v, want nil", err)
	}
}

func TestMaxAndAddStat(t *testing.T) {
	s := newTestStore(t)
	acc, _ := s.Accounts.CreateAccount("Counts", "pw", false)
	coach, _ := s.Coaches.Create(acc.ID, "Counter", 0, 0, 0)
	get := func(id int16) int32 {
		var st domain.CoachStat
		if err := s.DB().Where("coach_id = ? AND stat_id = ?", coach.ID, id).First(&st).Error; err != nil {
			return -1
		}
		return st.Value
	}
	if moved, err := s.Coaches.MaxStat(coach.ID, 59, 40); err != nil || !moved || get(59) != 40 {
		t.Fatalf("MaxStat insert: moved=%v err=%v value=%d", moved, err, get(59))
	}
	if moved, _ := s.Coaches.MaxStat(coach.ID, 59, 30); moved || get(59) != 40 {
		t.Errorf("MaxStat lower: moved=%v value=%d, want unchanged 40", moved, get(59))
	}
	if moved, _ := s.Coaches.MaxStat(coach.ID, 59, 99999); !moved || get(59) != StatValueMax {
		t.Errorf("MaxStat clamp: moved=%v value=%d, want %d", moved, get(59), StatValueMax)
	}
	if moved, _ := s.Coaches.AddStat(coach.ID, 156, 0); moved || get(156) != -1 {
		t.Errorf("AddStat 0 on an absent row wrote one: moved=%v value=%d", moved, get(156))
	}
	_, _ = s.Coaches.AddStat(coach.ID, 156, 3)
	_, _ = s.Coaches.AddStat(coach.ID, 156, 4)
	if get(156) != 7 {
		t.Errorf("AddStat total = %d, want 7", get(156))
	}
	var count int64
	s.DB().Model(&domain.CoachStat{}).Where("coach_id = ? AND stat_id = ?", coach.ID, 156).Count(&count)
	if count != 1 {
		t.Errorf("rows = %d, want 1", count)
	}
}
