package game

import (
	"path/filepath"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/store/storetest"
)

// The prize a tournament advertises lives in the CLIENT's own data - a type-1000
// aub record, field aHi(), bound to the GUI field "tournamentRewards" - and is
// never sent over the wire. So the client shows the prize whether or not the
// server pays it, and only the server can close that gap.
//
// Of the 22 shipped definitions only 11 (card 26) and 18 (card 544) name a
// prize. Both are free to enter, so both pass the web console's "no entry
// ticket" filter and can be picked by an operator.

// tournamentPrizeDeps builds a Deps with a real store, the real card table and
// the real type-1000 definitions, plus a persisted tournament row on defID and
// the coach that will win it.
func tournamentPrizeDeps(t *testing.T, defID uint16) (*Deps, uint, int64) {
	t.Helper()
	st, err := storetest.Open(t, filepath.Join(t.TempDir(), "tournprize.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })

	gd := openRealGameData(t)
	cards, err := gd.LoadCards()
	if err != nil {
		t.Fatalf("LoadCards: %v", err)
	}
	defs, err := gd.LoadTournaments()
	if err != nil {
		t.Fatalf("LoadTournaments: %v", err)
	}

	acc, _ := st.Accounts.CreateAccount("tournwin", "pw", false)
	coach, _ := st.Coaches.Create(acc.ID, "TournWinner", 0, 0, 0)

	tr := &domain.Tournament{
		DefID: defID, Name: "Prize Cup", Short: "PC", Enabled: true,
	}
	if err := st.Tournaments.Create(tr); err != nil {
		t.Fatalf("create tournament: %v", err)
	}

	d := &Deps{
		Store: st, Cards: cards, TournamentDefs: defs,
		Fights: NewFightManager(), World: NewRegistry(150), Log: testLogger(),
	}
	return d, coach.ID, tr.WireID()
}

// TestTournamentPrizeIsGranted: winning a tournament built on a definition that
// names a prize puts that exact card in the winner's inventory.
func TestTournamentPrizeIsGranted(t *testing.T) {
	// Definition 11 advertises card 26.
	d, coachID, tid := tournamentPrizeDeps(t, 11)
	const prizeCard = 26

	before := ownedQty(t, d, coachID, prizeCard)
	d.awardTournamentPrize(tid, coachID, nil)
	after := ownedQty(t, d, coachID, prizeCard)

	if after != before+1 {
		t.Errorf("card %d quantity %d -> %d, want +1: the client advertises this "+
			"prize, so the server must pay it", prizeCard, before, after)
	}
}

// TestTournamentPrizeIsTheDefinitionsCard guards against paying a fixed or
// wrong card: definition 18 pays 544, not 26.
func TestTournamentPrizeIsTheDefinitionsCard(t *testing.T) {
	d, coachID, tid := tournamentPrizeDeps(t, 18)

	before26 := ownedQty(t, d, coachID, 26)
	before544 := ownedQty(t, d, coachID, 544)
	d.awardTournamentPrize(tid, coachID, nil)

	if got := ownedQty(t, d, coachID, 544); got != before544+1 {
		t.Errorf("card 544 quantity %d -> %d, want +1", before544, got)
	}
	if got := ownedQty(t, d, coachID, 26); got != before26 {
		t.Errorf("card 26 quantity %d -> %d: definition 18 pays 544, so the "+
			"prize is being read from the wrong definition", before26, got)
	}
}

// TestTournamentWithNoPrizePaysNoCard: 20 of the 22 definitions advertise no
// prize card, so the common case must grant no card at all rather than
// defaulting to some card. It still pays the tokens (TestTournamentWinPaysTokens).
func TestTournamentWithNoPrizePaysNoCard(t *testing.T) {
	// Definition 1 has no reward card - it is also one of the three the server
	// actually offers today.
	d, coachID, tid := tournamentPrizeDeps(t, 1)

	c, err := d.Store.Coaches.Get(coachID)
	if err != nil {
		t.Fatalf("get coach: %v", err)
	}
	before := len(c.Inventory)
	d.awardTournamentPrize(tid, coachID, nil)
	c, err = d.Store.Coaches.Get(coachID)
	if err != nil {
		t.Fatalf("get coach: %v", err)
	}
	if len(c.Inventory) != before {
		t.Errorf("inventory grew from %d to %d rows for a tournament that "+
			"advertises no prize", before, len(c.Inventory))
	}

	// Again with no card catalogue. Deps.Cards is nil on a server started
	// without data files, and then the "advertises no prize" check is the ONLY
	// thing standing between a 0 reward and a grant of card 0 - the
	// unknown-card guard that would otherwise catch it needs the catalogue it
	// no longer has.
	d.Cards = nil
	d.awardTournamentPrize(tid, coachID, nil)
	c, err = d.Store.Coaches.Get(coachID)
	if err != nil {
		t.Fatalf("get coach: %v", err)
	}
	if len(c.Inventory) != before {
		t.Errorf("inventory grew from %d to %d rows with no card catalogue: "+
			"a zero reward card was granted", before, len(c.Inventory))
	}
}

// TestTournamentPrizeOnlyAtTheWinnerSlot: the prize is for winning the
// tournament, not for winning a round.
//
// Uses a FULL 16-entrant draw so the winner earns the root by playing every
// round rather than riding byes into it - the short-draw case is covered by
// TestShortDrawIsWonByBye below.
func TestTournamentPrizeOnlyAtTheWinnerSlot(t *testing.T) {
	d, coachID, tid := tournamentPrizeDeps(t, 11)
	const prizeCard = 26

	// 16 entrants, the winner first: seeding is by coach id, so coachID takes
	// slot 16 and its opponents are the next ids up.
	m := NewTournamentManager()
	entrants := make([]uint, 0, bracketEntrants)
	for i := 0; i < bracketEntrants; i++ {
		entrants = append(entrants, coachID+uint(i))
	}
	for _, c := range entrants {
		m.Register(c, tid)
	}
	d.Tournaments = m

	before := ownedQty(t, d, coachID, prizeCard)
	rounds := 0
	pay := func(winner, loser uint) {
		if slot := m.RecordMatchResult(tid, winner, loser); slot == bracketWinnerSlot {
			d.awardTournamentPrize(tid, winner, nil)
		}
	}

	// Walk the draw: each round, every occupied sibling pair plays and the LOWER
	// coach id wins, so coachID wins the whole thing.
	for {
		slots := m.BracketSlots(tid)
		played := false
		for slot := int32(bracketSlots) - 1; slot >= 2; slot-- {
			a, okA := slots[slot]
			b, okB := slots[slot^1]
			if !okA || !okB || slot&1 == 1 {
				continue
			}
			if _, done := m.BracketSlots(tid)[slot/2]; done {
				continue
			}
			if a < b {
				pay(a, b)
			} else {
				pay(b, a)
			}
			played = true
		}
		if !played {
			break
		}
		rounds++
		if rounds > 10 {
			t.Fatal("bracket did not settle")
		}
		// The prize must not land before the final.
		if _, decided := m.BracketSlots(tid)[bracketWinnerSlot]; !decided {
			if got := ownedQty(t, d, coachID, prizeCard); got != before {
				t.Fatalf("card %d paid after round %d, before the final: the "+
					"prize is for winning the tournament, not a round",
					prizeCard, rounds)
			}
		}
	}

	if got := m.BracketSlots(tid)[bracketWinnerSlot]; got != coachID {
		t.Fatalf("winner slot = coach %d, want %d", got, coachID)
	}
	if got := ownedQty(t, d, coachID, prizeCard); got != before+1 {
		t.Errorf("card %d quantity %d -> %d, want exactly +1 for the tournament "+
			"win", prizeCard, before, got)
	}
}

// TestShortDrawIsWonByBye: a 4-entrant tournament can be won (B-122).
//
// The client's bracket is a fixed 16-entrant tree, so three quarters of a short
// draw is empty. Beating the only other entrant left must carry the winner all
// the way to the root rather than stranding it against nobody.
func TestShortDrawIsWonByBye(t *testing.T) {
	m := tmWithEntrants(7, 1, 2, 3, 4)
	if got := m.RecordMatchResult(7, 1, 2); got != 8 {
		t.Fatalf("advanced to %d, want 8", got)
	}
	if got := m.RecordMatchResult(7, 3, 4); got != 9 {
		t.Fatalf("advanced to %d, want 9", got)
	}
	// Slots 8 and 9 decide slot 4, and the whole 5-subtree (leaves 20..23) was
	// never seeded, so the winner rides the byes from 4 to the root.
	if got := m.RecordMatchResult(7, 1, 3); got != bracketWinnerSlot {
		t.Errorf("final advanced to slot %d, want %d: with the top half of the "+
			"draw empty the winner must not be stranded", got, bracketWinnerSlot)
	}
	if got := m.BracketSlots(7)[bracketWinnerSlot]; got != 1 {
		t.Errorf("winner slot = coach %d, want 1", got)
	}
}

// TestByeIsNotGivenWhileAnOpponentIsStillComing is the rule that makes byes
// safe. "Unopposed" must mean nobody can EVER arrive in the sibling subtree, not
// merely that it is empty at this instant - otherwise the first coach to win its
// match is walked straight past an opponent who is still playing.
func TestByeIsNotGivenWhileAnOpponentIsStillComing(t *testing.T) {
	m := tmWithEntrants(7, 1, 2, 3, 4)
	// Coach 1 wins its first round and reaches slot 8. Slot 9 is empty right
	// now, but 3 and 4 are seeded beneath it and have not played yet.
	if got := m.RecordMatchResult(7, 1, 2); got != 8 {
		t.Fatalf("advanced to %d, want 8", got)
	}
	if got, ok := m.BracketSlots(7)[bracketWinnerSlot]; ok {
		t.Fatalf("coach %d was byed to the winner slot while coaches 3 and 4 "+
			"were still to play their semi-final", got)
	}
	if got := m.BracketSlots(7)[4]; got != 0 {
		t.Errorf("slot 4 = coach %d before the other semi-final was played", got)
	}
}

// tokenBalance is the coach's primary-currency (Card Master token) balance.
func tokenBalance(t *testing.T, d *Deps, coachID uint) int32 {
	t.Helper()
	c, err := d.Store.Coaches.Get(coachID)
	if err != nil {
		t.Fatalf("get coach: %v", err)
	}
	for _, w := range c.Wallet {
		if w.CurrencyType == primaryCurrency {
			return w.Amount
		}
	}
	return 0
}

// TestTournamentWinPaysTokens (S26): the help text says tournaments give
// tokens, so every win pays tournamentWinTokens, with or without a card, and
// only once per tournament.
func TestTournamentWinPaysTokens(t *testing.T) {
	for _, defID := range []uint16{1, 11} { // no card / card 26
		d, coachID, tid := tournamentPrizeDeps(t, defID)
		before := tokenBalance(t, d, coachID)
		for i := 0; i < 3; i++ { // the repeats are the 28611 spam case
			d.awardTournamentPrize(tid, coachID, nil)
		}
		if got := tokenBalance(t, d, coachID); got != before+tournamentWinTokens {
			t.Errorf("def %d: tokens %d -> %d, want +%d once", defID, before, got, tournamentWinTokens)
		}
	}
}
