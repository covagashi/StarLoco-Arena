package domain

import "time"

// Seasons (S25, owner 2026-10-25): the ladders run in seasons. When one
// closes, the top of each ladder is paid in pesetas (a cosmetics-only
// currency, S28) and every rating takes a soft reset towards the start.

// Season is one ladder season. The open one has ClosedAt nil; there is at
// most one.
type Season struct {
	ID       uint      `gorm:"primaryKey"`
	Number   int32     `gorm:"uniqueIndex;not null"`
	StartsAt time.Time `gorm:"not null"`
	EndsAt   time.Time `gorm:"not null"`
	ClosedAt *time.Time
}

// TableName pins the table name.
func (Season) TableName() string { return "seasons" }

// The ladders a season closes.
const (
	LadderRanked uint8 = 1 // the 1v1 Ranking (Coach.Strength)
	LadderGhost  uint8 = 2 // the ghost ladder (GhostRating.Elo)
)

// SeasonResult is one coach's place on one ladder when a season closed, and
// what it paid. Seen turns true once the client has been told.
type SeasonResult struct {
	ID      uint  `gorm:"primaryKey"`
	Season  int32 `gorm:"uniqueIndex:idx_season_result;not null"`
	Ladder  uint8 `gorm:"uniqueIndex:idx_season_result;not null"`
	CoachID uint  `gorm:"uniqueIndex:idx_season_result;index;not null"`
	Rank    int32 `gorm:"not null"`
	Rating  int32 `gorm:"not null"`
	Pesetas int32 `gorm:"not null"`
	Seen    bool  `gorm:"not null;default:false"`
}

// TableName pins the table name.
func (SeasonResult) TableName() string { return "season_results" }

// CurrencyPesetas is the wallet slot of the pesetas. The retail client uses
// types 1, 2, 3 and 5; 10 is ours.
const CurrencyPesetas uint8 = 10

// SeasonPrizes is how many pesetas each place pays, by tier: the first place
// up to (and including) Last pays Pesetas.
var SeasonPrizes = []struct{ Last, Pesetas int32 }{
	{1, 500}, {3, 300}, {10, 150}, {50, 50},
}

// SeasonPrize is what a place pays (0 off the paid table).
func SeasonPrize(rank int32) int32 {
	if rank < 1 {
		return 0
	}
	for _, p := range SeasonPrizes {
		if rank <= p.Last {
			return p.Pesetas
		}
	}
	return 0
}

// SeasonPaidPlaces is how deep the paid table goes.
func SeasonPaidPlaces() int { return int(SeasonPrizes[len(SeasonPrizes)-1].Last) }

// SoftReset moves a rating halfway back to base: 1400 → 1200 around 1000.
func SoftReset(rating, base int32) int32 {
	return base + (rating-base)/2
}

// SeasonBounds is the season that starts at now: it ends on the first day of
// the next calendar month (UTC), or of the month after when fewer than 14
// days would be left, so a first season is never a stub.
func SeasonBounds(now time.Time) (time.Time, time.Time) {
	now = now.UTC()
	end := time.Date(now.Year(), now.Month()+1, 1, 0, 0, 0, 0, time.UTC)
	if end.Sub(now) < 14*24*time.Hour {
		end = end.AddDate(0, 1, 0)
	}
	return now, end
}
