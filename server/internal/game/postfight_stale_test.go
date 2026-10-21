package game

import (
	"log/slog"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/store/storetest"
)

// TestPostFightDoesNotClobberConcurrentXP covers the ROOT CAUSE behind the free
// talent tree.
//
// fr is the fighter SNAPSHOT taken when the fight was built, and SaveProgress
// writes absolute values - so anything that changed the stored row while the
// fight ran was silently reverted at fight end. That is how a mid-fight sphere
// purchase got its XP refunded while the fighter_spheres rows survived.
func TestPostFightDoesNotClobberConcurrentXP(t *testing.T) {
	st, err := storetest.Open(t, t.TempDir()+"/stale.db")
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })

	acc, _ := st.Accounts.CreateAccount("stale", "pw", false)
	coach, _ := st.Coaches.Create(acc.ID, "Stale", 0, 0, 0)

	fr := &domain.Fighter{CoachID: coach.ID, BreedID: 1, Name: "Snap", XP: 1000}
	if err := st.Fighters.Create(fr); err != nil {
		t.Fatalf("seed: %v", err)
	}

	// The fight holds this snapshot (XP 1000).
	snapshot := *fr

	// Meanwhile something spends 400 XP in the DATABASE - a sphere purchase.
	if err := st.DB().Model(&domain.Fighter{}).Where("id = ?", fr.ID).
		Update("xp", 600).Error; err != nil {
		t.Fatalf("simulate spend: %v", err)
	}

	// Fight ends: re-read the accumulating fields, then bank the fight's reward.
	// Call the PRODUCTION helper. My first version of this test inlined the
	// re-read, which meant it was testing its own code: a mutation removing the
	// real one survived untouched.
	d := &Deps{Store: st, Log: slog.Default()}
	d.refreshAccumulatingFields(&snapshot)
	rep := &postFightReport{xpFinal: 100}
	rep.bank(&snapshot, 12345)
	if err := st.Fighters.SaveProgress(&snapshot); err != nil {
		t.Fatalf("save: %v", err)
	}

	after, err := st.Fighters.Get(fr.ID)
	if err != nil {
		t.Fatalf("reload: %v", err)
	}
	// 600 (post-purchase) + 100 (fight reward) = 700. The bug wrote 1100, refunding
	// the 400 that was spent.
	if after.XP != 700 {
		t.Errorf("XP = %d, want 700 (600 after the spend, +100 from the fight). "+
			"1100 means the pre-spend snapshot was written back and the purchase "+
			"was refunded", after.XP)
	}
}
