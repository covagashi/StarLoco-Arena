package game

import (
	"context"
	"time"
)

// DemoMaxIdle is how long a web demo account (S44) lives without a login.
// The browser holds its only key, so an account idle this long is almost
// surely one whose browser forgot it.
const DemoMaxIdle = 30 * 24 * time.Hour

const demoPurgeTick = time.Hour

// RunDemoPurge deletes the stale demo accounts every hour until ctx is
// done.
func (d *Deps) RunDemoPurge(ctx context.Context) {
	t := time.NewTicker(demoPurgeTick)
	defer t.Stop()
	d.PurgeDemoAccounts(time.Now())
	for {
		select {
		case <-ctx.Done():
			return
		case now := <-t.C:
			d.PurgeDemoAccounts(now)
		}
	}
}

// PurgeDemoAccounts deletes every offline demo account with no login in
// DemoMaxIdle before now, coach and all (AccountRepo.DeleteAccount).
func (d *Deps) PurgeDemoAccounts(now time.Time) int {
	if d.Store == nil || d.Store.Accounts == nil {
		return 0
	}
	ids, err := d.Store.Accounts.StaleDemoIDs(now.Add(-DemoMaxIdle))
	if err != nil {
		d.Log.Warn("demo purge: list", "err", err)
		return 0
	}
	n := 0
	for _, id := range ids {
		if err := d.Store.Accounts.DeleteAccount(id); err != nil {
			d.Log.Warn("demo purge: delete", "account", id, "err", err)
			continue
		}
		n++
	}
	if n > 0 {
		d.Log.Info("demo purge", "deleted", n)
	}
	return n
}
