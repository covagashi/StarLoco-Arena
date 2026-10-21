package game

import (
	"path/filepath"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store/storetest"
)

// A duo must never be paired against a lone coach: that side would field two
// coaches and two rosters, each with its own 6000-point budget, against one.
//
// This is the client's own distinction rather than a house rule - a preset's
// zK.cB() is 1 for an ordinary team and 2 for a duo, and the 2VS2 tab lists only
// the latter - so the queue carries it through as a separate mode tag.
func mmSession(m *Matchmaker, id uint, name string) *Session {
	return &Session{
		log: testLogger(), out: make(chan []byte, writeQueueSize),
		quit: make(chan struct{}), Coach: &domain.Coach{ID: id, Name: name},
	}
}

func TestDuoAndSoloQueuesDoNotMix(t *testing.T) {
	m := NewMatchmaker()
	solo := mmSession(m, 1, "Solo")
	duo := mmSession(m, 2, "Duo")

	if pm := m.Search(solo, modeClassicReady, 0, nil); pm != nil {
		t.Fatal("first searcher paired with nobody")
	}
	// A duo arriving must NOT take the waiting solo coach as its opponent.
	if pm := m.Search(duo, modeDuoReady, 0, nil); pm != nil {
		t.Fatalf("a 2v2 was paired against a lone coach (%s) - that side would field "+
			"two coaches against one", pm.a.session.Coach.Name)
	}
	// ... and a second duo must pair with the first.
	duo2 := mmSession(m, 3, "Duo2")
	pm := m.Search(duo2, modeDuoReady, 0, nil)
	if pm == nil {
		t.Fatal("two duos did not pair with each other")
	}
	got := map[uint]bool{pm.a.session.Coach.ID: true, pm.b.session.Coach.ID: true}
	if !got[2] || !got[3] {
		t.Errorf("paired %v, want the two duos (2 and 3)", got)
	}
	// The solo coach is still waiting, not consumed.
	solo2 := mmSession(m, 4, "Solo2")
	if pm := m.Search(solo2, modeClassicReady, 0, nil); pm == nil {
		t.Error("the waiting solo coach was consumed by the duo pairing")
	}
}

// TestDuoLaunchQueuesUnderTheDuoMode drives the real 23103 handler.
//
// The queue-level test above proves the matchmaker segregates by mode, but not
// that the handler actually PASSES the duo mode - a mutation making it queue a
// duo as modeClassicReady left it green. This one inspects the tag on the
// searcher the handler enqueued.
func TestDuoLaunchQueuesUnderTheDuoMode(t *testing.T) {
	st, err := storetest.Open(t, filepath.Join(t.TempDir(), "duoq.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })
	d := &Deps{
		Store: st, World: NewRegistry(150), Fights: NewFightManager(),
		Matchmaker: NewMatchmaker(), Sessions: NewSessionRegistry(),
		TeamUps: newTeamUps(), Log: testLogger(),
	}
	// domain.Coach carries a sync.Mutex, so it must not be copied by a range
	// variable (go vet catches it). Build each one in place.
	for _, name := range []struct {
		id   uint
		name string
	}{{1, "A"}, {2, "B"}} {
		c := &domain.Coach{ID: name.id, Name: name.name}
		if err := st.DB().Create(c).Error; err != nil {
			t.Fatalf("coach: %v", err)
		}
	}
	for _, f := range []domain.Fighter{
		{CoachID: 1, BreedID: 1, Name: "AF", State: domain.FighterStateTitular},
		{CoachID: 2, BreedID: 2, Name: "BF", State: domain.FighterStateTitular},
	} {
		if err := st.DB().Create(&f).Error; err != nil {
			t.Fatalf("fighter: %v", err)
		}
	}
	sessions := map[uint]*Session{}
	for _, id := range []uint{1, 2} {
		var c domain.Coach
		if err := st.DB().First(&c, id).Error; err != nil {
			t.Fatalf("load coach: %v", err)
		}
		s := &Session{
			log: testLogger(), deps: d, out: make(chan []byte, writeQueueSize),
			quit: make(chan struct{}), Coach: &c,
		}
		d.Sessions.Swap(id, s)
		sessions[id] = s
	}
	pair := &teamUpPair{Name: "Duo", InviterID: 1, InvitedID: 2}
	d.TeamUps.bind(pair)
	d.createDuoPresets(pair)

	// Both partners press Combattre; the pair queues once, on the second press.
	ready := func(self, ally uint) {
		w := protocol.NewWriter()
		w.I64(int64(ally)) // zK.afG() - the preset's ally
		w.U16(0)           // team id (unresolved preset is tolerated)
		f := &protocol.C2SFrame{Opcode: protocol.OpClassicReadyForFight, Arch: 2, Payload: w.Bytes()}
		if err := handleClassicReadyForFight(sessions[self], f); err != nil {
			t.Fatalf("ready(%d): %v", self, err)
		}
	}
	ready(1, 2)
	ready(2, 1)

	d.Matchmaker.mu.Lock()
	defer d.Matchmaker.mu.Unlock()
	if len(d.Matchmaker.queue) != 1 {
		t.Fatalf("queue has %d searchers, want exactly 1 (the duo queues once)",
			len(d.Matchmaker.queue))
	}
	if got := d.Matchmaker.queue[0].mode; got != modeDuoReady {
		t.Errorf("duo queued under mode %d, want modeDuoReady (%d) - it would be "+
			"paired against a lone coach", got, modeDuoReady)
	}
}

// TestDuoModeIsDistinct guards the constants themselves: if they ever collapse to
// the same value the segregation silently disappears.
func TestDuoModeIsDistinct(t *testing.T) {
	if modeDuoReady == modeClassicReady {
		t.Fatal("modeDuoReady == modeClassicReady - duos and solos share a queue")
	}
	if modeDuoReady == modeEvolutionSearch {
		t.Fatal("modeDuoReady collides with the evolution queue")
	}
}
