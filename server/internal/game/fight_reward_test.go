package game

import (
	"path/filepath"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/store/storetest"
)

// TestFightWinAwardsTokens: when a fight ends, the winning coach is credited the
// token faucet reward, persisted to the store.
func TestFightWinAwardsTokens(t *testing.T) {
	st, err := storetest.Open(t, filepath.Join(t.TempDir(), "reward.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })

	// Persist two coaches so the fight teams reference real DB rows.
	accA, _ := st.Accounts.CreateAccount("winA", "pw", false)
	winner, _ := st.Coaches.Create(accA.ID, "Winner", 0, 0, 0)
	accB, _ := st.Accounts.CreateAccount("loseB", "pw", false)
	loser, _ := st.Coaches.Create(accB.ID, "Loser", 0, 0, 0)

	f := buildTestFight()
	// Rebind the synthetic teams to the persisted coach ids (team 0 wins).
	f.Teams[0].Coach().ID = winner.ID
	f.Teams[1].Coach().ID = loser.ID
	f.setPhase(PhaseAction)

	d := &Deps{Store: st, Fights: NewFightManager(), World: NewRegistry(150), Log: testLogger()}
	d.Fights.Create(f)

	// Kill team B (side 1) so team A wins.
	for _, ff := range f.allFighters() {
		if ff.TeamID == 1 {
			ff.HP = 0
		}
	}
	d.checkFightEnd(f)

	// Winner's wallet should hold exactly the win reward; loser gets nothing.
	wc, _ := st.Coaches.Get(winner.ID)
	var winBal int32
	for _, w := range wc.Wallet {
		if w.CurrencyType == primaryCurrency {
			winBal = w.Amount
		}
	}
	if winBal != fightWinReward {
		t.Errorf("winner balance = %d, want %d", winBal, fightWinReward)
	}

	lc, _ := st.Coaches.Get(loser.ID)
	if len(lc.Wallet) != 0 {
		t.Errorf("loser should have no tokens, got %+v", lc.Wallet)
	}
}
