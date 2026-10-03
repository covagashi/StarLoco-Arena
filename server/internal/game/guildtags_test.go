package game

import (
	"path/filepath"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store"
)

// TestGuildTagsTablePushesEveryClannedCoach pins the 554 emission: the login
// push must carry one `ca_0` part-1 tag per clanned coach so `lh_1` can label
// every coach in `bd_1.Is()` - and each blob must carry the COACH id (the
// field `Ke()` reads back), not the guild id.
func TestGuildTagsTablePushesEveryClannedCoach(t *testing.T) {
	st, err := store.Open(filepath.Join(t.TempDir(), "tags.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })

	acc, _ := st.Accounts.CreateAccount("tagA", "pw", false)
	leader, _ := st.Coaches.Create(acc.ID, "Chef", 1, 0, 0)
	if _, err := st.Guilds.Create("TagClan", leader.ID, "Chef", "Membre"); err != nil {
		t.Fatalf("create guild: %v", err)
	}
	acc2, _ := st.Accounts.CreateAccount("tagB", "pw", false)
	joiner, _ := st.Coaches.Create(acc2.ID, "Membre", 1, 0, 0)
	if err := st.Guilds.AddMember(1, joiner.ID); err != nil {
		t.Fatalf("join: %v", err)
	}
	// A third coach stays clanless and must NOT appear in the table.
	acc3, _ := st.Accounts.CreateAccount("tagC", "pw", false)
	if _, err := st.Coaches.Create(acc3.ID, "Solo", 1, 0, 0); err != nil {
		t.Fatalf("coach C: %v", err)
	}

	d := &Deps{Store: st, Log: testLogger()}
	s := &Session{
		log:   testLogger(),
		deps:  d,
		out:   make(chan []byte, writeQueueSize),
		quit:  make(chan struct{}),
		Coach: leader,
	}
	if err := d.pushGuildTags(s); err != nil {
		t.Fatalf("pushGuildTags: %v", err)
	}

	var frame []byte
	select {
	case frame = <-s.out:
	default:
		t.Fatal("no 554 frame queued")
	}
	if len(frame) < 4 || uint16(frame[2])<<8|uint16(frame[3]) != protocol.OpGuildTags {
		t.Fatalf("opcode=%d, want %d", uint16(frame[2])<<8|uint16(frame[3]), protocol.OpGuildTags)
	}

	r := protocol.NewReader(frame[4:])
	n, err := r.I32()
	if err != nil || n != 2 {
		t.Fatalf("entry count=%d err=%v, want 2", n, err)
	}
	for i := int32(0); i < n; i++ {
		l, err := r.I32()
		if err != nil || l <= 0 {
			t.Fatalf("entry %d len=%d err=%v", i, l, err)
		}
		blob, err := r.Bytes(int(l))
		if err != nil {
			t.Fatalf("entry %d blob: %v", i, err)
		}
		// PartTable with a single part 1: [u8 1][u8 1][i32 absOff][u8 1][tag].
		if len(blob) < 7 || blob[0] != 1 || blob[1] != 1 || blob[6] != 1 {
			t.Fatalf("entry %d is not a part-1 table: %x", i, blob)
		}
		tag := protocol.NewReader(blob[7:])
		name, err := tag.StringU8()
		if err != nil || name != "TagClan" {
			t.Fatalf("entry %d name=%q err=%v", i, name, err)
		}
		pid, err := tag.I64()
		if err != nil {
			t.Fatalf("entry %d coach id: %v", i, err)
		}
		if uint(pid) != leader.ID && uint(pid) != joiner.ID {
			t.Fatalf("entry %d carries coach %d, want %d or %d", i, pid, leader.ID, joiner.ID)
		}
	}
}
