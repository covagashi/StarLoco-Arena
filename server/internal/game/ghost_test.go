package game

import (
	"encoding/json"
	"log/slog"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store"
	"github.com/StarLoco/arena-2.70/internal/store/storetest"
)

const passRules = `{"version":1,"rules":[{"if":{"kind":"always"},"do":{"kind":"pass"}}]}`

// ghostFixture: a coach with two titular fighters (one with a spell and a
// card), on a real store.
func ghostFixture(t *testing.T) (*Deps, *store.Store, *domain.Coach) {
	t.Helper()
	st, err := storetest.Open(t, t.TempDir()+"/ghost.db")
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })
	acc, _ := st.Accounts.CreateAccount("ghostowner", "pw", true)
	coach, _ := st.Coaches.Create(acc.ID, "GhostOwner", 0, 0, 0)
	for _, fr := range []*domain.Fighter{
		{CoachID: coach.ID, BreedID: 8, Name: "Iopette",
			Spells:  []domain.FighterSpell{{Slot: 0, SpellID: 1}},
			Objects: []domain.FighterObject{{TemplateID: 5}}},
		{CoachID: coach.ID, BreedID: 9, Name: "Craette"},
	} {
		if err := st.Fighters.Create(fr); err != nil {
			t.Fatalf("create fighter: %v", err)
		}
	}
	d := &Deps{Store: st, Log: slog.Default(), Fights: NewFightManager(), World: NewRegistry(50)}
	return d, st, coach
}

// TestGhostSnapshotIsFrozenAndDetached: the saved ghost carries the line-up
// with every id zeroed, so nothing after a fight can write to the owner's real
// fighters — and changing the team later does not change the ghost.
func TestGhostSnapshotIsFrozenAndDetached(t *testing.T) {
	d, st, coach := ghostFixture(t)
	g, code := d.saveGhost(coach.ID, "Mi fantasma", nil)
	if code != ghostOK {
		t.Fatalf("save code = %d", code)
	}
	var roster []domain.Fighter
	if err := json.Unmarshal([]byte(g.Roster), &roster); err != nil {
		t.Fatal(err)
	}
	if len(roster) != 2 {
		t.Fatalf("roster = %d fighters, want 2", len(roster))
	}
	for _, fr := range roster {
		if fr.ID != 0 || fr.CoachID != 0 {
			t.Errorf("%s keeps ids %d/%d", fr.Name, fr.ID, fr.CoachID)
		}
		for _, o := range fr.Objects {
			if o.ID != 0 || o.FighterID != 0 {
				t.Errorf("%s card keeps ids", fr.Name)
			}
		}
	}
	// the owner renames a fighter afterwards: the ghost does not follow
	live, _ := st.Fighters.ListByCoach(coach.ID)
	live[0].Name = "Otro"
	_ = st.Fighters.SaveProgress(&live[0])
	again, _ := st.Ghosts.Get(g.ID)
	if again.Roster != g.Roster {
		t.Error("the stored roster changed with the live team")
	}
}

// TestGhostTeamIsSyntheticWithRules: in a fight the ghost is the synthetic
// coach, its wire ids sit in their own range, and its rules are attached.
func TestGhostTeamIsSyntheticWithRules(t *testing.T) {
	d, st, coach := ghostFixture(t)
	live, _ := st.Fighters.ListByCoach(coach.ID)
	g, _ := d.saveGhost(coach.ID, "G", map[uint][]byte{live[1].ID: []byte(passRules)})
	team, err := d.buildGhostTeam(1, []Pos{{X: 1, Y: 1}, {X: 2, Y: 2}}, g)
	if err != nil {
		t.Fatal(err)
	}
	if !isSyntheticCoach(team.Members[0].Coach.ID) || team.Members[0].Session != nil {
		t.Error("the ghost side must be the session-less synthetic coach")
	}
	for i, ff := range team.Fighters {
		if ff.CoachID != ghostCoachID {
			t.Errorf("fighter %d coach = %d", i, ff.CoachID)
		}
		if ff.WireID < ghostWireBase {
			t.Errorf("fighter %d wire id %d below the ghost range", i, ff.WireID)
		}
		if ff.MaxHP <= 0 {
			t.Errorf("fighter %d has no HP", i)
		}
	}
	if team.Fighters[0].Gambits != nil || team.Fighters[1].Gambits == nil {
		t.Error("rules must land on the fighter they were written for only")
	}
	f := &Fight{Teams: [2]*FightTeam{{ID: 0}, team}}
	if !f.isAIControlled(team.Fighters[0]) {
		t.Error("the AI plays the ghost")
	}
}

// TestGhostSaveRefusals: name, broken rules, the per-coach cap and a coach
// with no fighters are refused; a rule for a fighter outside the snapshot is
// dropped, not an error.
func TestGhostSaveRefusals(t *testing.T) {
	d, st, coach := ghostFixture(t)
	if _, c := d.saveGhost(coach.ID, "", nil); c != ghostBadName {
		t.Errorf("empty name: %d", c)
	}
	live, _ := st.Fighters.ListByCoach(coach.ID)
	if _, c := d.saveGhost(coach.ID, "G", map[uint][]byte{live[0].ID: []byte(`{"version":1,`)}); c != ghostBadRules {
		t.Errorf("broken rules: %d", c)
	}
	g, c := d.saveGhost(coach.ID, "G", map[uint][]byte{999999: []byte(passRules)})
	if c != ghostOK || g.Rules != "{}" {
		t.Errorf("rule for a fighter not in the snapshot: code %d rules %q", c, g.Rules)
	}
	for i := 1; i < maxGhostsPerCoach; i++ {
		if _, c := d.saveGhost(coach.ID, "G", nil); c != ghostOK {
			t.Fatalf("save %d: %d", i, c)
		}
	}
	if _, c := d.saveGhost(coach.ID, "G", nil); c != ghostLimit {
		t.Errorf("over the cap: %d", c)
	}
	acc, _ := st.Accounts.CreateAccount("empty", "pw", false)
	empty, _ := st.Coaches.Create(acc.ID, "Empty", 0, 0, 0)
	if _, c := d.saveGhost(empty.ID, "G", nil); c != ghostBadRoster {
		t.Errorf("no fighters: %d", c)
	}
}

// TestArenaFromSeedIsStable: the arena of a ghost fight comes from its seed,
// so a replay lands on the same map; the global rand plays no part.
func TestArenaFromSeedIsStable(t *testing.T) {
	d := &Deps{}
	d.arenas.cache = map[uint16]*arena{}
	for _, id := range []uint16{5, 9, 12, 40, 58} {
		d.arenas.cache[id] = &arena{worldID: id}
		d.arenas.ids = append(d.arenas.ids, id)
	}
	seen := map[uint16]bool{}
	for seed := int64(1); seed < 60; seed++ {
		a, b := d.arenaFromSeed(seed), d.arenaFromSeed(seed)
		if a != b {
			t.Fatalf("seed %d: %d then %d", seed, a.worldID, b.worldID)
		}
		seen[a.worldID] = true
	}
	if len(seen) < 3 {
		t.Errorf("only %d arenas over 59 seeds: the seed barely matters", len(seen))
	}
}

// TestDecisionHash: same log, same hash; one detail differs, the hash differs.
func TestDecisionHash(t *testing.T) {
	a := []fightDecision{{Round: 1, Turn: 0, WireID: 7, Kind: decisionCast, Detail: "spell=1"}}
	b := []fightDecision{{Round: 1, Turn: 0, WireID: 7, Kind: decisionCast, Detail: "spell=2"}}
	if decisionHash(a) != decisionHash(a) || decisionHash(a) == decisionHash(b) {
		t.Error("the hash must follow the log exactly")
	}
}

// TestGhostDeleteOnlyOwn: 60015 deletes the caller's own ghost and refuses
// anyone else's; ghosts are open to non-admins since S13.
func TestGhostDeleteOnlyOwn(t *testing.T) {
	d, st, coach := ghostFixture(t)
	g, _ := d.saveGhost(coach.ID, "G", nil)
	acc, _ := st.Accounts.CreateAccount("other", "pw", false)
	other, _ := st.Coaches.Create(acc.ID, "Other", 0, 0, 0)
	stranger := &Session{Coach: other, Account: acc, deps: d, log: slog.Default(), out: make(chan []byte, 8), quit: make(chan struct{})}
	if !stranger.ghostAllowed() {
		t.Fatal("a non-admin coach may use ghosts")
	}
	frame := func(id uint) *protocol.C2SFrame {
		return &protocol.C2SFrame{Payload: protocol.NewWriter().I64(int64(id)).Bytes()}
	}
	_ = handleGhostDelete(stranger, frame(g.ID))
	if still, _ := st.Ghosts.Get(g.ID); still == nil {
		t.Fatal("a stranger deleted someone else's ghost")
	}
	owner := &Session{Coach: coach, deps: d, log: slog.Default(), out: make(chan []byte, 8), quit: make(chan struct{})}
	_ = handleGhostDelete(owner, frame(g.ID))
	if gone, _ := st.Ghosts.Get(g.ID); gone != nil {
		t.Error("the owner's delete did not remove the ghost")
	}
}
