package game

import (
	"io"
	"log/slog"
	"path/filepath"
	"testing"
	"time"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/store/storetest"
)

func TestIsDemoLogin(t *testing.T) {
	for login, want := range map[string]bool{
		"demo-abcdefghij0123456789":  true,
		"demo-abcdefghij012345678":   false, // 19
		"demo-abcdefghij01234567890": false, // 21
		"demo-ABCDEFGHIJ0123456789":  false,
		"demo-abcdefghij012345678_":  false,
		"xemo-abcdefghij0123456789":  false,
		"test":                       false,
	} {
		if got := IsDemoLogin(login); got != want {
			t.Errorf("IsDemoLogin(%q) = %v, want %v", login, got, want)
		}
	}
}

func TestDemoPerIPHour(t *testing.T) {
	now := time.Now()
	g := newConnGuard(Limits{DemoPerIPHour: 2})
	g.now = func() time.Time { return now }
	if !g.allowDemo("1.2.3.4") || !g.allowDemo("1.2.3.4") {
		t.Fatal("the first two demo accounts must be allowed")
	}
	if g.allowDemo("1.2.3.4") {
		t.Error("a third demo account inside the hour was allowed")
	}
	if !g.allowDemo("5.6.7.8") {
		t.Error("another address was blocked by the first one's demo accounts")
	}
	now = now.Add(61 * time.Minute)
	if !g.allowDemo("1.2.3.4") {
		t.Error("the cap did not reset after an hour")
	}
	g.sweepLoginHits()
	if _, ok := g.demoHit["5.6.7.8"]; ok {
		t.Error("an address idle for an hour kept its demo entry")
	}
}

// The purge deletes demo accounts idle past DemoMaxIdle, and nothing else:
// not a recent demo account, not an old ordinary one.
func TestPurgeDemoAccounts(t *testing.T) {
	st, err := storetest.Open(t, filepath.Join(t.TempDir(), "demo.db"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = st.Close() })
	d := &Deps{Store: st, Log: slog.New(slog.NewTextHandler(io.Discard, nil))}
	now := time.Now()
	old := now.Add(-DemoMaxIdle - time.Hour)
	stale, _ := st.Accounts.CreateDemoAccount("demo-aaaaaaaaaaaaaaaaaaa1", "pw")
	fresh, _ := st.Accounts.CreateDemoAccount("demo-aaaaaaaaaaaaaaaaaaa2", "pw")
	plain, _ := st.Accounts.CreateAccount("plain", "pw", false)
	for _, id := range []uint{stale.ID, plain.ID} {
		if err := st.DB().Model(&domain.Account{}).Where("id = ?", id).
			UpdateColumn("updated_at", old).Error; err != nil {
			t.Fatal(err)
		}
	}
	if n := d.PurgeDemoAccounts(now); n != 1 {
		t.Errorf("purged %d accounts, want 1", n)
	}
	if _, err := st.Accounts.FindByID(stale.ID); err == nil {
		t.Error("the idle demo account survived")
	}
	for _, id := range []uint{fresh.ID, plain.ID} {
		if _, err := st.Accounts.FindByID(id); err != nil {
			t.Errorf("account %d was purged: %v", id, err)
		}
	}
}

// Demo coaches play the ladders but take no place at a season's close, so
// they earn no pesetas (S44).
func TestDemoCoachesTakeNoSeasonPlace(t *testing.T) {
	st, err := storetest.Open(t, filepath.Join(t.TempDir(), "demoseason.db"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = st.Close() })
	plain, _ := st.Accounts.CreateAccount("plain", "pw", false)
	demo, _ := st.Accounts.CreateDemoAccount("demo-aaaaaaaaaaaaaaaaaaa1", "pw")
	var ids []uint
	for i, acc := range []*domain.Account{plain, demo} {
		c, err := st.Coaches.Create(acc.ID, []string{"Plain", "Visitor"}[i], 0, 0, 0)
		if err != nil {
			t.Fatal(err)
		}
		c.Strength = int32(1100 + 300*i) // the demo coach leads
		if err := st.Coaches.Save(c); err != nil {
			t.Fatal(err)
		}
		if err := st.Ghosts.SaveRating(domain.GhostRating{CoachID: c.ID, Elo: int32(1000 + 300*i), Fights: 3}); err != nil {
			t.Fatal(err)
		}
		ids = append(ids, c.ID)
	}
	ranked, err := st.Seasons.RankedTop(10)
	if err != nil || len(ranked) != 1 || ranked[0].CoachID != ids[0] {
		t.Errorf("ranked top = %+v (%v), want only the ordinary coach %d", ranked, err, ids[0])
	}
	ghosts, err := st.Seasons.GhostTop(10)
	if err != nil || len(ghosts) != 1 || ghosts[0].CoachID != ids[0] {
		t.Errorf("ghost top = %+v (%v), want only the ordinary coach %d", ghosts, err, ids[0])
	}
}
