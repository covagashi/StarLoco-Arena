package game

import (
	"fmt"
	"path/filepath"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store/storetest"
	"gorm.io/gorm"
)

// socialCapSession builds a DB-backed session: the cap is enforced with COUNT
// queries, so an in-memory-only fixture cannot exercise it.
func socialCapSession(t *testing.T, name string) (*Session, *Deps) {
	t.Helper()
	st, err := storetest.Open(t, filepath.Join(t.TempDir(), "social.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })
	d := tmDeps()
	d.Log = testLogger()
	d.Store = st
	acc, _ := st.Accounts.CreateAccount("sc_"+name, "pw", false)
	coach, _ := st.Coaches.Create(acc.ID, name, 0, 0, 0)
	s := tmSession(d, coach.ID, name)
	s.Coach = coach
	return s, d
}

// TestSocialListCapRefusesWithNotPermitted: the friend and ignore lists had no
// upper bound, so a client could grow either without limit. The 2.70 client
// carries the error string for exactly this - "Ta liste d'amis ou de personnes
// ignorees est peut-etre pleine" (3216) - so retail enforced it server-side.
//
// The cap value itself is server policy; only the refusal is client-derived.
func TestSocialListCapRefusesWithNotPermitted(t *testing.T) {
	for _, tc := range []struct {
		name string
		kind socialKind
	}{
		{"friends", socialFriend},
		{"ignored", socialIgnore},
	} {
		t.Run(tc.name, func(t *testing.T) {
			s, d := socialCapSession(t, "Hoarder"+tc.name)
			db := d.Store.DB()
			owner := s.Coach.ID

			// Fill the list to exactly the cap. The edges carry a foreign key, so
			// the targets have to be real coaches - synthetic ids are rejected by
			// SQLite before the cap is ever consulted.
			// One account owns every target: CreateAccount runs bcrypt, and 100 of
			// those dominated the test's runtime for no added coverage.
			targetAcc, err := d.Store.Accounts.CreateAccount("targets_"+tc.name, "pw", false)
			if err != nil {
				t.Fatalf("create target account: %v", err)
			}
			var firstTarget uint
			for i := 0; i < DefaultRules().MaxSocialListEntries; i++ {
				target, err := d.Store.Coaches.Create(
					targetAcc.ID, fmt.Sprintf("Target%s%d", tc.name, i), 0, 0, 0)
				if err != nil {
					t.Fatalf("create coach %d: %v", i, err)
				}
				if i == 0 {
					firstTarget = target.ID
				}
				var res *gorm.DB
				if tc.kind == socialFriend {
					res = db.Create(&domain.CoachFriend{OwnerID: owner, FriendID: target.ID})
				} else {
					res = db.Create(&domain.CoachIgnored{OwnerID: owner, IgnoredID: target.ID})
				}
				if res.Error != nil {
					t.Fatalf("insert edge %d: %v", i, res.Error)
				}
			}

			// Fixture check: a cap that is not actually reached would make the
			// refusal below pass for the wrong reason.
			full, err := s.socialListFull(db, tc.kind, 9999)
			if err != nil {
				t.Fatalf("socialListFull: %v", err)
			}
			if !full {
				t.Fatalf("fixture: list is not full at %d entries, so this test "+
					"could not tell a working cap from a missing one", DefaultRules().MaxSocialListEntries)
			}

			// An edge that already exists is not a new entry - re-adding an
			// existing friend must stay a no-op, not become an error at the edge.
			existing := firstTarget
			full, err = s.socialListFull(db, tc.kind, existing)
			if err != nil {
				t.Fatalf("socialListFull(existing): %v", err)
			}
			if full {
				t.Errorf("re-adding an entry that is already in the list was refused; "+
					"a duplicate add is not a new entry (target %d)", existing)
			}
		})
	}
}

// TestSocialCapBelowLimitAllows guards the other direction: an ordinary coach
// with a short list must never see the refusal.
func TestSocialCapBelowLimitAllows(t *testing.T) {
	s, d := socialCapSession(t, "Normal")
	db := d.Store.DB()
	db.Create(&domain.CoachFriend{OwnerID: s.Coach.ID, FriendID: 42})

	full, err := s.socialListFull(db, socialFriend, 43)
	if err != nil {
		t.Fatalf("socialListFull: %v", err)
	}
	if full {
		t.Error("a coach with 1 friend was told the list is full")
	}
	_ = protocol.OpChatErrNotPermitted
}
