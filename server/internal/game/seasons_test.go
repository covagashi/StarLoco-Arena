package game

import (
	"path/filepath"
	"testing"
	"time"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store/storetest"
)

func pesetas(t *testing.T, d *Deps, coachID uint) int32 {
	t.Helper()
	c, err := d.Store.Coaches.Get(coachID)
	if err != nil {
		t.Fatalf("get coach: %v", err)
	}
	for _, w := range c.Wallet {
		if w.CurrencyType == domain.CurrencyPesetas {
			return w.Amount
		}
	}
	return 0
}

// TestSeasonClosePaysResetsAndOpensTheNext (S25): the first tick opens
// season 1; once its end passes, the next tick pays the top of both ladders
// in pesetas, soft-resets every rating (also the in-memory Strength of an
// online coach), opens season 2 and tells the online coach; a further tick
// pays nothing twice.
func TestSeasonClosePaysResetsAndOpensTheNext(t *testing.T) {
	st, err := storetest.Open(t, filepath.Join(t.TempDir(), "season.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })
	mk := func(name string, strength int32) *domain.Coach {
		acc, _ := st.Accounts.CreateAccount(name, "pw", false)
		c, _ := st.Coaches.Create(acc.ID, name, 0, 0, 0)
		c.Strength = strength
		if err := st.Coaches.Save(c); err != nil {
			t.Fatalf("save: %v", err)
		}
		return c
	}
	a, b, c, g := mk("Ana", 1400), mk("Beto", 1100), mk("Cira", 0), mk("Gus", 0)
	for _, r := range []domain.GhostRating{{CoachID: a.ID, Elo: 1200, Fights: 3}, {CoachID: g.ID, Elo: 900, Fights: 2}} {
		if err := st.Ghosts.SaveRating(r); err != nil {
			t.Fatalf("rating: %v", err)
		}
	}

	now := time.Date(2026, 10, 25, 12, 0, 0, 0, time.UTC)
	d := &Deps{Store: st, World: NewRegistry(150), Log: testLogger(), SeasonClock: func() time.Time { return now }}
	online := &Session{log: testLogger(), deps: d, out: make(chan []byte, writeQueueSize),
		quit: make(chan struct{}), Coach: a}
	d.World.Add(&Online{Coach: a, Session: online})

	d.TickSeasons()
	s1, _ := st.Seasons.Open()
	if s1 == nil || s1.Number != 1 || !s1.EndsAt.Equal(time.Date(2026, 12, 1, 0, 0, 0, 0, time.UTC)) {
		t.Fatalf("first tick opened %+v, want season 1 to 2026-12-01", s1)
	}
	d.TickSeasons()
	if p := pesetas(t, d, a.ID); p != 0 {
		t.Fatalf("paid %d pesetas before the season ended", p)
	}

	now = s1.EndsAt.Add(time.Minute)
	d.TickSeasons()
	want := map[uint]int32{a.ID: 500 + 500, b.ID: 300, c.ID: 0, g.ID: 300}
	for id, w := range want {
		if p := pesetas(t, d, id); p != w {
			t.Errorf("coach %d: %d pesetas, want %d", id, p, w)
		}
	}
	for id, w := range map[uint]int32{a.ID: 1200, b.ID: 1050, c.ID: 0} {
		got, _ := st.Coaches.Get(id)
		if got.Strength != w {
			t.Errorf("coach %d: Strength %d after the reset, want %d", id, got.Strength, w)
		}
	}
	if a.Strength != 1200 {
		t.Errorf("online coach's in-memory Strength %d, want 1200 (else its next save undoes the reset)", a.Strength)
	}
	for id, w := range map[uint]int32{a.ID: 1100, g.ID: 950} {
		r, _ := st.Ghosts.Rating(id)
		if r.Elo != w {
			t.Errorf("coach %d: ghost Elo %d, want %d", id, r.Elo, w)
		}
	}
	s2, _ := st.Seasons.Open()
	if s2 == nil || s2.Number != 2 {
		t.Fatalf("after the close the open season is %+v, want 2", s2)
	}
	// The online coach was told at once: season 2, and both of its results.
	p := drainPayload(t, online, protocol.OpSeason)
	if p == nil {
		t.Fatal("no 60031 to the online coach at the close")
	}
	r := protocol.NewReader(p)
	num, _ := r.U16()
	_, _ = r.I64()
	n, _ := r.U8()
	if num != 2 || n != 2 {
		t.Errorf("60031: season %d with %d results, want season 2 with 2", num, n)
	}
	if left, _ := st.Seasons.TakeUnseen(a.ID); len(left) != 0 {
		t.Errorf("results still unseen after the 60031: %+v", left)
	}
	if left, _ := st.Seasons.TakeUnseen(b.ID); len(left) != 1 || left[0].Rank != 2 || left[0].Pesetas != 300 {
		t.Errorf("Beto's unseen results %+v, want one: Ranking 2nd, 300", left)
	}

	d.TickSeasons() // same clock: nothing more to pay
	if pa := pesetas(t, d, a.ID); pa != 1000 {
		t.Errorf("a repeat tick paid again: %d", pa)
	}
}
