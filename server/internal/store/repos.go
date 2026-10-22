package store

import (
	"errors"
	"strings"
	"time"

	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"

	"github.com/StarLoco/arena-2.70/internal/domain"
)

// ErrNotFound is returned when a lookup finds no row.
var ErrNotFound = errors.New("store: not found")

// ErrNameTaken is returned when creating a coach with a duplicate name.
var ErrNameTaken = errors.New("store: name already taken")

// ErrInvalidName is returned when a coach name is empty or otherwise unusable.
var ErrInvalidName = errors.New("store: invalid name")

// ---------------------------------------------------------------------------
// Accounts
// ---------------------------------------------------------------------------

// AccountRepo persists login accounts.
type AccountRepo struct{ db *gorm.DB }

// FindByName loads an account (and its coach) by login name.
func (r *AccountRepo) FindByName(name string) (*domain.Account, error) {
	var acc domain.Account
	err := r.db.Preload("Coach").Where("name = ?", name).First(&acc).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &acc, nil
}

// FindByID loads an account (and its coach) by primary key. The web portal
// re-loads the account behind a session cookie on every request rather than
// trusting the cookie's contents, so this is on its hot path.
func (r *AccountRepo) FindByID(id uint) (*domain.Account, error) {
	var acc domain.Account
	err := r.db.Preload("Coach").First(&acc, id).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &acc, nil
}

// Count returns the number of accounts on the server. Used to detect a brand
// new install, where the first account registered becomes the owner.
func (r *AccountRepo) Count() (int64, error) {
	var n int64
	if err := r.db.Model(&domain.Account{}).Count(&n).Error; err != nil {
		return 0, err
	}
	return n, nil
}

// CreateAccount creates an account with a bcrypt-hashed password.
func (r *AccountRepo) CreateAccount(name, password string, admin bool) (*domain.Account, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}
	acc := &domain.Account{Name: name, PasswordHash: string(hash), IsAdmin: admin}
	if err := r.db.Create(acc).Error; err != nil {
		return nil, err
	}
	return acc, nil
}

// VerifyPassword reports whether password matches the account's stored hash.
func (r *AccountRepo) VerifyPassword(acc *domain.Account, password string) bool {
	return bcrypt.CompareHashAndPassword([]byte(acc.PasswordHash), []byte(password)) == nil
}

// SetPassword updates an account's password (bcrypt-hashed).
func (r *AccountRepo) SetPassword(id uint, password string) error {
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	return r.db.Model(&domain.Account{}).Where("id = ?", id).
		Update("password_hash", string(hash)).Error
}

// SetAdmin flips the admin flag.
func (r *AccountRepo) SetAdmin(id uint, admin bool) error {
	return r.db.Model(&domain.Account{}).Where("id = ?", id).
		Update("is_admin", admin).Error
}

// SetConnected flips the connected flag.
func (r *AccountRepo) SetConnected(id uint, connected bool) error {
	return r.db.Model(&domain.Account{}).Where("id = ?", id).
		Update("connected", connected).Error
}

// LinkCoach sets the account's CoachID.
func (r *AccountRepo) LinkCoach(accountID, coachID uint) error {
	return r.db.Model(&domain.Account{}).Where("id = ?", accountID).
		Update("coach_id", coachID).Error
}

// ---------------------------------------------------------------------------
// Coaches
// ---------------------------------------------------------------------------

// CoachRepo persists coaches and their associations.
type CoachRepo struct{ db *gorm.DB }

// Get loads a coach by id with inventory + social lists preloaded.
func (r *CoachRepo) Get(id uint) (*domain.Coach, error) {
	var c domain.Coach
	err := r.db.
		Preload("Inventory").
		Preload("Friends.Friend").
		Preload("Ignored.Ignored").
		Preload("Wallet").
		// Stats carries the coach's achievement criteria, which the 2052 descriptor
		// must echo back â€” it is the only channel by which criteria reach the
		// client, so without this preload every criterion is silently lost on
		// relog (both the ones the client reports via 22003 and the ones the
		// server sets on challenge victories).
		Preload("Stats").
		First(&c, id).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &c, nil
}

// GetByName loads a coach by (case-insensitive) name.
func (r *CoachRepo) GetByName(name string) (*domain.Coach, error) {
	var c domain.Coach
	// LOWER() on both sides rather than COLLATE NOCASE: the latter is
	// SQLite-only, and on postgres it fails outright with
	// `collation "nocase" for encoding "UTF8" does not exist`.
	err := r.db.Where("LOWER(name) = LOWER(?)", name).First(&c).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &c, nil
}

// Create makes a coach and links it to the account in one transaction.
func (r *CoachRepo) Create(accountID uint, name string, hair, skin, sex uint8) (*domain.Coach, error) {
	name = strings.TrimSpace(name)
	// SECURITY (defence in depth): the game handler validates the name against
	// the client's own rule before calling this, but a blank name must never be
	// storable regardless of caller. An empty coach name was previously accepted
	// here - NOT NULL is satisfied by "" and the uniqueness count is 0 - and
	// sendGuildMembers already had to skip blank names downstream, which is the
	// symptom of exactly that leaking through.
	if name == "" {
		return nil, ErrInvalidName
	}
	coach := &domain.Coach{Name: name, Hair: hair, Skin: skin, Sex: sex, PosX: 1, PosY: 1}
	err := r.db.Transaction(func(tx *gorm.DB) error {
		// Uniqueness (case-insensitive) check. LOWER() rather than
		// COLLATE NOCASE, which is SQLite-only - see GetByName above.
		var count int64
		if err := tx.Model(&domain.Coach{}).
			Where("LOWER(name) = LOWER(?)", name).Count(&count).Error; err != nil {
			return err
		}
		if count > 0 {
			return ErrNameTaken
		}
		if err := tx.Create(coach).Error; err != nil {
			return err
		}
		return tx.Model(&domain.Account{}).Where("id = ?", accountID).
			Update("coach_id", coach.ID).Error
	})
	if err != nil {
		return nil, err
	}
	return coach, nil
}

// WatchersAsFriend returns the ids of coaches who have targetID in their friend
// list with notifications enabled â€” i.e. the coaches to notify when targetID
// comes online or goes offline.
func (r *CoachRepo) WatchersAsFriend(targetID uint) ([]uint, error) {
	var ids []uint
	// Deliberately NOT filtered on `notify`. That flag is a TOAST preference, not
	// a subscription: the client applies the 3148 notification unconditionally -
	//
	//	axa_03.ai(true); axa_03.c(dh_02.no());   // presence + the friend's ID
	//	if (axa_03.aJM()) { ...show the message... }
	//
	// - and only consults its own notify flag (which we send in the friend list)
	// before showing "X vient de se connecter". Filtering here instead meant a
	// friend with notify off never learned the other came online AND never
	// received its id, because the friend list only carries an id for coaches
	// who were already online when it was built (see B-120). The visible symptom
	// was that a 2v2 invitation failed depending on who logged in first.
	err := r.db.Model(&domain.CoachFriend{}).
		Where("friend_id = ?", targetID).
		Pluck("owner_id", &ids).Error
	return ids, err
}

// WatchersAsIgnore returns the ids of coaches who have targetID on their ignore
// list â€” the coaches to notify when targetID comes online or goes offline.
func (r *CoachRepo) WatchersAsIgnore(targetID uint) ([]uint, error) {
	var ids []uint
	err := r.db.Model(&domain.CoachIgnored{}).
		Where("ignored_id = ?", targetID).
		Pluck("owner_id", &ids).Error
	return ids, err
}

// ErrInsufficientFunds is returned by BuyCards when the coach can't afford the
// total price.
var ErrInsufficientFunds = errors.New("store: insufficient funds")

// GrantCard is one card to add to inventory as part of a purchase.
type GrantCard struct {
	TemplateID int32
	Quantity   int16
}

// BuyCards debits the given per-currency cost from a coach's wallet and grants
// the cards to its inventory, atomically. Returns ErrInsufficientFunds (without
// mutating anything) if any currency balance is too low. cost maps
// currencyType -> total amount to debit.
func (r *CoachRepo) BuyCards(coachID uint, cost map[uint8]int32, grants []GrantCard) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		// Verify + debit each currency.
		for ctype, amount := range cost {
			if amount <= 0 {
				continue
			}
			var wallet domain.CoachCurrency
			err := tx.Where("coach_id = ? AND currency_type = ?", coachID, ctype).
				First(&wallet).Error
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return ErrInsufficientFunds
			}
			if err != nil {
				return err
			}
			if wallet.Amount < amount {
				return ErrInsufficientFunds
			}
			wallet.Amount -= amount
			if err := tx.Model(&domain.CoachCurrency{}).
				Where("id = ?", wallet.ID).
				Update("amount", wallet.Amount).Error; err != nil {
				return err
			}
		}
		// Grant cards: stack onto an existing unequipped (Pos==0) row if present.
		for _, g := range grants {
			if g.Quantity <= 0 {
				continue
			}
			var existing domain.CoachCard
			err := tx.Where("coach_id = ? AND template_id = ? AND pos = 0",
				coachID, g.TemplateID).First(&existing).Error
			switch {
			case errors.Is(err, gorm.ErrRecordNotFound):
				card := domain.CoachCard{
					CoachID: coachID, TemplateID: g.TemplateID,
					Quantity: g.Quantity,
				}
				if err := tx.Create(&card).Error; err != nil {
					return err
				}
			case err != nil:
				return err
			default:
				if err := tx.Model(&domain.CoachCard{}).Where("id = ?", existing.ID).
					Update("quantity", existing.Quantity+g.Quantity).Error; err != nil {
					return err
				}
			}
		}
		return nil
	})
}

// GrantCards adds cards to a coach's inventory for free, atomically, stacking
// onto an existing unequipped row like a purchase does. Used for rewards
// (challenge victories) where there is nothing to debit.
func (r *CoachRepo) GrantCards(coachID uint, grants []GrantCard) error {
	return r.BuyCards(coachID, nil, grants)
}

// ErrCardNotOwned is returned by ConsumeAndGrant when the coach doesn't own an
// input card being consumed.
var ErrCardNotOwned = errors.New("store: card not owned")

// ConsumeAndGrant removes one unit of each input template from a coach's
// unequipped (Pos==0) inventory and, if grantTemplate != 0, grants one unit of
// it â€” atomically. Returns ErrCardNotOwned (rolling back) if any input isn't
// owned in sufficient quantity. Used by the Fusion Lab. inputs may contain
// duplicates (each occurrence consumes one unit).
func (r *CoachRepo) ConsumeAndGrant(coachID uint, inputs []int32, grantTemplate int32) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		// Tally how many of each template we must consume.
		need := make(map[int32]int)
		for _, id := range inputs {
			need[id]++
		}
		for tmpl, qty := range need {
			var card domain.CoachCard
			err := tx.Where("coach_id = ? AND template_id = ? AND pos = 0", coachID, tmpl).
				First(&card).Error
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return ErrCardNotOwned
			}
			if err != nil {
				return err
			}
			if int(card.Quantity) < qty {
				return ErrCardNotOwned
			}
			if int(card.Quantity) == qty {
				if err := tx.Delete(&domain.CoachCard{}, card.ID).Error; err != nil {
					return err
				}
			} else {
				if err := tx.Model(&domain.CoachCard{}).Where("id = ?", card.ID).
					Update("quantity", int(card.Quantity)-qty).Error; err != nil {
					return err
				}
			}
		}
		if grantTemplate == 0 {
			return nil
		}
		// Grant the output: stack onto an existing unequipped row if present.
		var existing domain.CoachCard
		err := tx.Where("coach_id = ? AND template_id = ? AND pos = 0", coachID, grantTemplate).
			First(&existing).Error
		switch {
		case errors.Is(err, gorm.ErrRecordNotFound):
			return tx.Create(&domain.CoachCard{
				CoachID: coachID, TemplateID: grantTemplate,
				Quantity: 1,
			}).Error
		case err != nil:
			return err
		default:
			return tx.Model(&domain.CoachCard{}).Where("id = ?", existing.ID).
				Update("quantity", existing.Quantity+1).Error
		}
	})
}

// CreditCurrency adds (or sets, if creating) an amount to a coach's currency
// balance, upserting the wallet slot. Used by faucets (grants/rewards).
func (r *CoachRepo) CreditCurrency(coachID uint, ctype uint8, delta int32) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		var wallet domain.CoachCurrency
		err := tx.Where("coach_id = ? AND currency_type = ?", coachID, ctype).
			First(&wallet).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return tx.Create(&domain.CoachCurrency{
				CoachID: coachID, CurrencyType: ctype, Amount: delta,
			}).Error
		}
		if err != nil {
			return err
		}
		// SECURITY: saturate rather than wrap. Amount is int32 and the increment
		// was unchecked, so a sufficiently large balance would overflow to
		// NEGATIVE - and BuyCards' affordability test (wallet.Amount < amount)
		// would then refuse every purchase, or worse, a negative delta path could
		// wrap the other way. Not practically reachable today (the only faucets are
		// a 50-token win reward and the 1000-token starter grant, so ~43M wins),
		// which is exactly why it should be bounded now rather than after someone
		// adds a bigger faucet.
		return tx.Model(&domain.CoachCurrency{}).Where("id = ?", wallet.ID).
			Update("amount", addCurrencySaturating(wallet.Amount, delta)).Error
	})
}

// UpsertStat sets a coach's keyed achievement/statistic counter (opcode 22003).
// Inserts the (coach_id, stat_id) row if absent, otherwise overwrites its value.
func (r *CoachRepo) UpsertStat(coachID uint, statID int16, value int32) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		var stat domain.CoachStat
		err := tx.Where("coach_id = ? AND stat_id = ?", coachID, statID).
			First(&stat).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return tx.Create(&domain.CoachStat{
				CoachID: coachID, StatID: statID, Value: value,
			}).Error
		}
		if err != nil {
			return err
		}
		return tx.Model(&domain.CoachStat{}).Where("id = ?", stat.ID).
			Update("value", value).Error
	})
}

// StatValueMax is the largest counter the client can hold: the 2052 criteria
// blob carries each value as a u16 the client reads back as a short.
const StatValueMax int32 = 32767

// MaxStat raises a coach's counter to value if that is higher than what it
// holds (a "best ever" statistic) and reports whether it moved. Values are
// clamped to StatValueMax.
func (r *CoachRepo) MaxStat(coachID uint, statID int16, value int32) (bool, error) {
	return r.bumpStat(coachID, statID, func(cur int32) int32 {
		if value > cur {
			return value
		}
		return cur
	})
}

// AddStat adds delta to a coach's counter (a running total) and reports
// whether it moved. The result is clamped to [0, StatValueMax].
func (r *CoachRepo) AddStat(coachID uint, statID int16, delta int32) (bool, error) {
	return r.bumpStat(coachID, statID, func(cur int32) int32 { return cur + delta })
}

// StatValue reads one counter (0 when absent or unreadable).
func (r *CoachRepo) StatValue(coachID uint, statID int16) int32 {
	var stat domain.CoachStat
	if err := r.db.Where("coach_id = ? AND stat_id = ?", coachID, statID).
		First(&stat).Error; err != nil {
		return 0
	}
	return stat.Value
}

// bumpStat applies next to the stored value (0 when absent) in one
// transaction, so two fights ending at once cannot lose an increment.
func (r *CoachRepo) bumpStat(coachID uint, statID int16, next func(int32) int32) (bool, error) {
	moved := false
	err := r.db.Transaction(func(tx *gorm.DB) error {
		var stat domain.CoachStat
		err := tx.Where("coach_id = ? AND stat_id = ?", coachID, statID).
			First(&stat).Error
		absent := errors.Is(err, gorm.ErrRecordNotFound)
		if err != nil && !absent {
			return err
		}
		v := next(stat.Value)
		if v > StatValueMax {
			v = StatValueMax
		}
		if v < 0 {
			v = 0
		}
		if v == stat.Value {
			return nil
		}
		moved = true
		if absent {
			return tx.Create(&domain.CoachStat{CoachID: coachID, StatID: statID, Value: v}).Error
		}
		return tx.Model(&domain.CoachStat{}).Where("id = ?", stat.ID).Update("value", v).Error
	})
	return moved, err
}

// SyncTome folds the given card templates into the coach's tome and returns the
// resulting full set.
//
// Grow-only by construction: it only ever inserts. Calling it with the coach's
// current inventory is therefore enough to keep the tome correct without hooking
// every single grant site (shop, fight winnings, challenge rewards, mail, fusion)
// â€” a card that passes through the inventory at any point it is observed gets
// recorded, and one that leaves is never withdrawn.
func (r *CoachRepo) SyncTome(coachID uint, templateIDs []int32) (map[int32]bool, error) {
	have := make(map[int32]bool)
	err := r.db.Transaction(func(tx *gorm.DB) error {
		var rows []domain.CoachTomeCard
		if err := tx.Where("coach_id = ?", coachID).Find(&rows).Error; err != nil {
			return err
		}
		for _, row := range rows {
			have[row.TemplateID] = true
		}
		for _, id := range templateIDs {
			if id == 0 || have[id] {
				continue
			}
			if err := tx.Create(&domain.CoachTomeCard{
				CoachID: coachID, TemplateID: id,
			}).Error; err != nil {
				return err
			}
			have[id] = true
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return have, nil
}

// TomeCards returns the card templates this coach has ever owned, ascending.
func (r *CoachRepo) TomeCards(coachID uint) ([]int32, error) {
	var rows []domain.CoachTomeCard
	if err := r.db.Where("coach_id = ?", coachID).
		Order("template_id asc").Find(&rows).Error; err != nil {
		return nil, err
	}
	out := make([]int32, 0, len(rows))
	for _, row := range rows {
		out = append(out, row.TemplateID)
	}
	return out, nil
}

// UnlockedAchievements returns the ids this coach has already been told about.
func (r *CoachRepo) UnlockedAchievements(coachID uint) (map[int16]bool, error) {
	var rows []domain.CoachAchievement
	if err := r.db.Where("coach_id = ?", coachID).Find(&rows).Error; err != nil {
		return nil, err
	}
	out := make(map[int16]bool, len(rows))
	for _, row := range rows {
		out[row.AchievementID] = true
	}
	return out, nil
}

// RecordAchievements marks achievements as unlocked-and-announced, returning the
// subset that was NOT already recorded.
//
// The insert and the "was it new" answer are one transaction on purpose: two
// sessions for the same coach (or a re-entrant evaluation) would otherwise both
// see the id as new and announce it twice.
func (r *CoachRepo) RecordAchievements(coachID uint, ids []int16) ([]int16, error) {
	var fresh []int16
	err := r.db.Transaction(func(tx *gorm.DB) error {
		fresh = fresh[:0]
		for _, id := range ids {
			var existing domain.CoachAchievement
			err := tx.Where("coach_id = ? AND achievement_id = ?", coachID, id).
				First(&existing).Error
			if err == nil {
				continue // already announced
			}
			if !errors.Is(err, gorm.ErrRecordNotFound) {
				return err
			}
			if err := tx.Create(&domain.CoachAchievement{
				CoachID: coachID, AchievementID: id, UnlockedAt: time.Now(),
			}).Error; err != nil {
				return err
			}
			fresh = append(fresh, id)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return fresh, nil
}

// DeleteCoach permanently removes a coach and every piece of data associated
// with it, in a single transaction. Handles opcode 27529 ("DÃ©truire le coach").
//
// Deleted/cleared:
//   - the owning account's coach link (set to NULL, so the account returns to
//     the coach-creation flow on next login);
//   - the coach's fighters (+ their spells/objects) and team presets (+ members);
//   - the coach row, which cascades cards, wallet, stats and its own outgoing
//     friend/ignore edges;
//   - reverse social edges where this coach is the target of someone else's
//     friend or ignore list.
//
// Child deletes are issued explicitly rather than relying on DB-level ON DELETE
// CASCADE, which SQLite only enforces when PRAGMA foreign_keys is ON.
func (r *CoachRepo) DeleteCoach(coachID uint) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		// Unlink the account first so a concurrent login can't resurrect the
		// coach mid-delete.
		if err := tx.Model(&domain.Account{}).
			Where("coach_id = ?", coachID).
			Update("coach_id", gorm.Expr("NULL")).Error; err != nil {
			return err
		}

		// Fighters: delete children (spells, objects) then the fighters.
		var fighterIDs []uint
		if err := tx.Model(&domain.Fighter{}).
			Where("coach_id = ?", coachID).
			Pluck("id", &fighterIDs).Error; err != nil {
			return err
		}
		if len(fighterIDs) > 0 {
			if err := tx.Where("fighter_id IN ?", fighterIDs).
				Delete(&domain.FighterSpell{}).Error; err != nil {
				return err
			}
			if err := tx.Where("fighter_id IN ?", fighterIDs).
				Delete(&domain.FighterObject{}).Error; err != nil {
				return err
			}
			// Persistent wounds/conditions are fighters' third child table.
			// Like the two above, the schema already cascades this at the DB
			// level; it is deleted explicitly for the same belt-and-braces
			// reason, so the three siblings stay consistent and none of them
			// depends on the SQLite foreign-key pragma being on.
			if err := tx.Where("fighter_id IN ?", fighterIDs).
				Delete(&domain.FighterCondition{}).Error; err != nil {
				return err
			}
			if err := tx.Where("id IN ?", fighterIDs).
				Delete(&domain.Fighter{}).Error; err != nil {
				return err
			}
		}

		// Teams: delete members then the teams.
		var teamIDs []uint
		if err := tx.Model(&domain.Team{}).
			Where("coach_id = ?", coachID).
			Pluck("id", &teamIDs).Error; err != nil {
			return err
		}
		if len(teamIDs) > 0 {
			if err := tx.Where("team_id IN ?", teamIDs).
				Delete(&domain.TeamFighter{}).Error; err != nil {
				return err
			}
			if err := tx.Where("id IN ?", teamIDs).
				Delete(&domain.Team{}).Error; err != nil {
				return err
			}
		}

		// Coach-owned rows (also covered by the coach cascade, but deleted
		// explicitly for SQLite where the cascade may be off).
		if err := tx.Where("coach_id = ?", coachID).
			Delete(&domain.CoachCard{}).Error; err != nil {
			return err
		}
		if err := tx.Where("coach_id = ?", coachID).
			Delete(&domain.CoachCurrency{}).Error; err != nil {
			return err
		}
		if err := tx.Where("coach_id = ?", coachID).
			Delete(&domain.CoachStat{}).Error; err != nil {
			return err
		}
		if err := tx.Where("coach_id = ?", coachID).
			Delete(&domain.CoachAchievement{}).Error; err != nil {
			return err
		}
		if err := tx.Where("coach_id = ?", coachID).
			Delete(&domain.CoachTomeCard{}).Error; err != nil {
			return err
		}

		// Social edges in BOTH directions (owner-side and target-side).
		if err := tx.Where("owner_id = ? OR friend_id = ?", coachID, coachID).
			Delete(&domain.CoachFriend{}).Error; err != nil {
			return err
		}
		if err := tx.Where("owner_id = ? OR ignored_id = ?", coachID, coachID).
			Delete(&domain.CoachIgnored{}).Error; err != nil {
			return err
		}

		// Finally the coach itself.
		return tx.Delete(&domain.Coach{}, coachID).Error
	})
}

// LadderEntry is one row of the 1v1 leaderboard, ordered by strength desc.
type LadderEntry struct {
	Name              string
	Strength          int32
	StatWins          int32
	StatLosses        int32
	ConsecutiveWins   int32
	ConsecutiveLosses int32
}

// LadderCount returns how many coaches are ranked (strength > 0). Only ranked
// coaches appear on the 1v1 ladder.
func (r *CoachRepo) LadderCount() (int, error) {
	var n int64
	err := r.db.Model(&domain.Coach{}).Where("strength > 0").Count(&n).Error
	return int(n), err
}

// LadderPage returns a window of the 1v1 ladder ordered by strength desc (ties
// broken by name), starting at offset (0-based) with up to limit rows.
func (r *CoachRepo) LadderPage(offset, limit int) ([]LadderEntry, error) {
	if limit <= 0 {
		return nil, nil
	}
	var coaches []domain.Coach
	err := r.db.
		Where("strength > 0").
		Order("strength DESC, name ASC").
		Offset(offset).Limit(limit).
		Find(&coaches).Error
	if err != nil {
		return nil, err
	}
	out := make([]LadderEntry, 0, len(coaches))
	for i := range coaches {
		c := &coaches[i]
		out = append(out, LadderEntry{
			Name: c.Name, Strength: c.Strength,
			StatWins: c.StatWins, StatLosses: c.StatLosses,
			ConsecutiveWins: c.ConsecutiveWins, ConsecutiveLosses: c.ConsecutiveLosses,
		})
	}
	return out, nil
}

// LadderRank returns the 1-based rank of a coach on the 1v1 ladder, or 0 if the
// coach is unranked (strength == 0). Rank = 1 + (# coaches with a strictly
// higher strength, or equal strength but an earlier name).
func (r *CoachRepo) LadderRank(coachID uint) (int, error) {
	var c domain.Coach
	if err := r.db.Select("id", "name", "strength").First(&c, coachID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return 0, ErrNotFound
		}
		return 0, err
	}
	if c.Strength <= 0 {
		return 0, nil // unranked
	}
	var ahead int64
	err := r.db.Model(&domain.Coach{}).
		Where("strength > 0").
		Where("strength > ? OR (strength = ? AND name < ?)", c.Strength, c.Strength, c.Name).
		Count(&ahead).Error
	if err != nil {
		return 0, err
	}
	return int(ahead) + 1, nil
}

// Save persists mutable coach fields (position, stats) by primary key.
//
// A coach struct can be touched by both its session goroutine and a fight actor
// goroutine. Callers that mutate coach fields concurrently must hold
// domain.Coach.Mu; Save takes it to snapshot the fields into a plain map, so the
// DB write and any concurrent mutation are serialized.
func (r *CoachRepo) Save(c *domain.Coach) error {
	c.Mu.Lock()
	fields := map[string]any{
		"pos_x":    c.PosX,
		"pos_y":    c.PosY,
		"pos_z":    c.PosZ,
		"strength": c.Strength,
		// Standing is the coach's EVOLUTION experience, and it is NOT the same
		// thing as Strength: post-fight META adds to it (postfight_apply.go) and
		// the client derives the coach's evolution LEVEL from it. Omitting it
		// here meant every point earned was thrown away on relog â€” the column
		// existed and was updated in memory, it was simply never written.
		"standing":           c.Standing,
		"stat_fights":        c.StatFights,
		"stat_wins":          c.StatWins,
		"stat_losses":        c.StatLosses,
		"consecutive_wins":   c.ConsecutiveWins,
		"consecutive_losses": c.ConsecutiveLosses,
		"time_in_fight_secs": c.TimeInFightSecs,
		"total_play_secs":    c.TotalPlaySecs,
	}
	c.Mu.Unlock() // snapshot done; DB write no longer touches the struct
	return r.db.Model(&domain.Coach{}).Where("id = ?", c.ID).Updates(fields).Error
}

// addCurrencySaturating adds delta to amount, clamping at the int32 bounds
// instead of wrapping. See CreditCurrency for why.
func addCurrencySaturating(amount, delta int32) int32 {
	const maxI32, minI32 = int32(1<<31 - 1), int32(-1 << 31)
	if delta > 0 && amount > maxI32-delta {
		return maxI32
	}
	if delta < 0 && amount < minI32-delta {
		return minI32
	}
	return amount + delta
}
