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
	// DropsSinceRare counts the post-fight drops since the last rare one
	// (silver or gold, rank 6+): at DropPityAfter, the next is rare.
	DropsSinceRare int32 `gorm:"not null;default:0"`
}

const (
	// DropPityAfter: after this many drops without a rare card, the next one
	// is rare (owner: one every 10 at worst).
	DropPityAfter int32 = 10
	// DropRareRank is the lowest rank that counts as rare (silver, tier 2).
	DropRareRank int32 = 6
	// DropKeepCopies is how many copies of a dropped card a coach keeps (for
	// fusion and barter); further copies become tokens (DuplicateTokens).
	DropKeepCopies = 2
)

// CardTier is the rarity tier the client shows for a card rank (cards.gd
// tier_of, S38b): 0 black (rank 0-2), 1 copper (3-5), 2 silver (6-8), 3 gold
// (9-10).
func CardTier(rank int32) int {
	switch {
	case rank <= 2:
		return 0
	case rank <= 5:
		return 1
	case rank <= 8:
		return 2
	}
	return 3
}

// duplicateTokens is what a duplicate drop pays by tier: a gold one is worth
// a Ranking win.
var duplicateTokens = [4]int32{5, 10, 25, 50}

// DuplicateTokens is what a duplicate drop of that rank pays.
func DuplicateTokens(rank int32) int32 { return duplicateTokens[CardTier(rank)] }

// TableName pins the table name.
func (CardPick) TableName() string { return "card_picks" }

// PickEvery is how many wins an offer costs: 3 for the first ten, then 5.
func PickEvery(picks int32) int32 {
	if picks < 10 {
		return 3
	}
	return 5
}
