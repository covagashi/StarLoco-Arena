package domain

// CardPick (S40, owner 2026-11-14) is a coach's progress towards its next
// "pick one card of three" reward: every few wins (Ranking and ghost ladder)
// the server offers three coach cards and the coach keeps one. It is a source
// on top of the shop and the drops; the fighter cards stay free for everyone.
type CardPick struct {
	CoachID uint  `gorm:"primaryKey"`
	Wins    int32 `gorm:"not null;default:0"` // wins towards the next offer
	Picks   int32 `gorm:"not null;default:0"` // offers taken so far
	// Offer is the pending offer, card template ids joined by commas ("" =
	// none). It waits until the coach picks, across sessions.
	Offer string `gorm:"not null;default:''"`
}

// TableName pins the table name.
func (CardPick) TableName() string { return "card_picks" }

// PickEvery is how many wins an offer costs: 3 for the first ten, then 5.
func PickEvery(picks int32) int32 {
	if picks < 10 {
		return 3
	}
	return 5
}
