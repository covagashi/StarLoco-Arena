package game

import (
	"path/filepath"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store"
)

// TestFighterAssignTeamPersists exercises the 6013 (qp_1) fighter-to-team
// assignment handler: dragging a fighter from the pool into a team slot must
// persist to team_fighters (and survive a reload), the 6-fighter / 2-per-breed
// caps must hold, removal (dst = -1) must unlink, and a foreign coach's fighter
// must be rejected (IDOR). Regression guard for the "fighters revert to the pool
// on reopen" bug (6013 was previously unhandled, so assignments were dropped).
func TestFighterAssignTeamPersists(t *testing.T) {
	st, err := store.Open(filepath.Join(t.TempDir(), "assign.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })

	acc, _ := st.Accounts.CreateAccount("assignA", "pw", false)
	coach, _ := st.Coaches.Create(acc.ID, "Coach", 0, 0, 0)

	// Roster: two breed-1 fighters + one breed-8 fighter.
	f1 := &domain.Fighter{CoachID: coach.ID, BreedID: 1, Name: "F1", Budget: 400}
	f2 := &domain.Fighter{CoachID: coach.ID, BreedID: 1, Name: "F2", Budget: 400}
	f3 := &domain.Fighter{CoachID: coach.ID, BreedID: 8, Name: "F3", Budget: 400}
	for _, f := range []*domain.Fighter{f1, f2, f3} {
		if err := st.Fighters.Create(f); err != nil {
			t.Fatalf("create fighter: %v", err)
		}
	}

	team := &domain.Team{CoachID: coach.ID, Name: "T", Type: -6, GameMode: 1}
	if err := st.Teams.Upsert(team); err != nil {
		t.Fatalf("upsert team: %v", err)
	}

	d := &Deps{Store: st, Log: testLogger()}
	s := &Session{
		log:   testLogger(),
		deps:  d,
		out:   make(chan []byte, writeQueueSize),
		quit:  make(chan struct{}),
		Coach: coach,
	}

	assign := func(fid uint, src, dst int16) {
		t.Helper()
		p := protocol.NewWriter().
			I64(int64(fid)).
			U16(uint16(src)).
			U16(uint16(dst)).
			I64(int64(coach.ID)).
			Bytes()
		if err := handleFighterAssignTeam(s, &protocol.C2SFrame{Payload: p}); err != nil {
			t.Fatalf("assign fighter %d: %v", fid, err)
		}
	}
	// frames6014 returns the payloads of every FighterAssignedTeam (6014) frame
	// the handler queued — the ack whose body echoes the request + aCG.
	frames6014 := func() [][]byte {
		t.Helper()
		var out [][]byte
		for {
			select {
			case fr := <-s.out:
				if len(fr) >= 4 && uint16(fr[2])<<8|uint16(fr[3]) == protocol.OpFighterAssignedTeam {
					out = append(out, fr[4:])
				}
			default:
				return out
			}
		}
	}
	members := func() []domain.TeamFighter {
		t.Helper()
		reloaded, err := st.Teams.Get(team.ID)
		if err != nil {
			t.Fatalf("reload team: %v", err)
		}
		return reloaded.Members
	}

	// 1) Assign f1 from the pool (src=-1) into the team → one persisted member,
	//    and a 6014 ack echoing the request with aCG = the fighter id itself.
	assign(f1.ID, -1, int16(team.ID))
	if m := members(); len(m) != 1 || m[0].FighterID != f1.ID {
		t.Fatalf("after assign f1: members=%+v", m)
	}
	acks := frames6014()
	if len(acks) != 1 {
		t.Fatalf("want exactly 1 ack 6014, got %d", len(acks))
	}
	ar := protocol.NewReader(acks[0])
	if st8, _ := ar.U8(); st8 != 0 {
		t.Fatalf("6014 status=%d, want 0", st8)
	}
	if got, _ := ar.I64(); uint(got) != f1.ID {
		t.Fatalf("6014 fid=%d, want %d", got, f1.ID)
	}
	if got, _ := ar.U16(); int16(got) != -1 {
		t.Fatalf("6014 src=%d, want -1", int16(got))
	}
	if got, _ := ar.U16(); uint(got) != team.ID {
		t.Fatalf("6014 dst=%d, want %d", got, team.ID)
	}
	if got, _ := ar.I64(); uint(got) != coach.ID {
		t.Fatalf("6014 am=%d, want coach %d", got, coach.ID)
	}
	if got, _ := ar.I64(); uint(got) != f1.ID {
		t.Fatalf("6014 aCG=%d, want %d (no re-id)", got, f1.ID)
	}

	// 2) f2 (same breed as f1) is still allowed — the cap is 2 per breed.
	assign(f2.ID, -1, int16(team.ID))
	// 3) f3 (different breed) is allowed.
	assign(f3.ID, -1, int16(team.ID))
	if m := members(); len(m) != 3 {
		t.Fatalf("want 3 members after f1..f3, got %d", len(m))
	}
	frames6014() // drain the two acks from steps 2-3

	// 4) A third breed-1 fighter must be rejected (max 2 of the same breed) —
	//    and must NOT produce a status-0 ack, which would file it into the
	//    client's open preset anyway.
	f4 := &domain.Fighter{CoachID: coach.ID, BreedID: 1, Name: "F4", Budget: 400}
	if err := st.Fighters.Create(f4); err != nil {
		t.Fatalf("create f4: %v", err)
	}
	assign(f4.ID, -1, int16(team.ID))
	if m := members(); len(m) != 3 {
		t.Fatalf("breed cap breached: %d members", len(m))
	}
	if acks := frames6014(); len(acks) != 0 {
		t.Fatalf("refused breed-cap assign emitted %d ack(s), want none", len(acks))
	}

	// 5) Removal (dst=-1) unlinks f1 from the team — the ack carries aCG=-1,
	//    the sentinel that keeps the client from re-adding it to the open preset.
	assign(f1.ID, int16(team.ID), -1)
	m := members()
	if len(m) != 2 {
		t.Fatalf("after removing f1: %d members", len(m))
	}
	for _, tf := range m {
		if tf.FighterID == f1.ID {
			t.Fatalf("f1 still present after removal")
		}
	}
	acks = frames6014()
	if len(acks) != 1 {
		t.Fatalf("want 1 removal ack, got %d", len(acks))
	}
	ar = protocol.NewReader(acks[0])
	_, _ = ar.U8()  // status
	_, _ = ar.I64() // fid
	_, _ = ar.U16() // src
	_, _ = ar.U16() // dst
	_, _ = ar.I64() // am
	if got, _ := ar.I64(); got != -1 {
		t.Fatalf("removal aCG=%d, want -1", got)
	}

	// 6) IDOR: another coach's fighter cannot be added to this team — and gets
	//    no ack either (early return before any mutation).
	acc2, _ := st.Accounts.CreateAccount("assignB", "pw", false)
	coach2, _ := st.Coaches.Create(acc2.ID, "Coach2", 0, 0, 0)
	fx := &domain.Fighter{CoachID: coach2.ID, BreedID: 8, Name: "FX", Budget: 400}
	if err := st.Fighters.Create(fx); err != nil {
		t.Fatalf("create fx: %v", err)
	}
	assign(fx.ID, -1, int16(team.ID))
	if m := members(); len(m) != 2 {
		t.Fatalf("IDOR: foreign fighter added, %d members", len(m))
	}
}
