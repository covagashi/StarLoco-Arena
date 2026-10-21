package game

import (
	"path/filepath"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store/storetest"
)

// The 2v2 handshake is the only way a fight can ever have two coaches on a side,
// so every rule it enforces is load-bearing: a duo that forms when it should not
// puts a coach into someone else's fight.
//
// 6024 carries [teamName][inviterId][invitedId] and 6026 echoes most of it back,
// which means almost every field is attacker-controlled. These tests exist to
// pin the re-derivation rather than the happy path.

func teamUpDeps(t *testing.T) *Deps {
	t.Helper()
	return &Deps{
		World:    NewRegistry(150),
		Fights:   NewFightManager(),
		Sessions: NewSessionRegistry(),
		TeamUps:  newTeamUps(),
		Log:      testLogger(),
	}
}

func teamUpSession(d *Deps, id uint, name string) *Session {
	s := &Session{
		log:   testLogger(),
		deps:  d,
		out:   make(chan []byte, writeQueueSize),
		quit:  make(chan struct{}),
		Coach: &domain.Coach{ID: id, Name: name},
	}
	d.Sessions.Swap(id, s) // keyed by account; ids double as accounts in tests
	return s
}

// drain returns the opcodes queued on a session's out channel.
func drain(t *testing.T, s *Session) []uint16 {
	t.Helper()
	var out []uint16
	for {
		select {
		case frame := <-s.out:
			if len(frame) >= 4 {
				out = append(out, uint16(frame[2])<<8|uint16(frame[3]))
			}
		default:
			return out
		}
	}
}

func teamUpRequest(name string, inviter, invited uint) *protocol.C2SFrame {
	w := protocol.NewWriter()
	w.StringU8(name)
	w.I64(int64(inviter))
	w.I64(int64(invited))
	return &protocol.C2SFrame{Opcode: protocol.OpTeamUpRequest, Arch: 2, Payload: w.Bytes()}
}

func teamUpAnswer(accept uint8, name string, inviter, invited uint) *protocol.C2SFrame {
	w := protocol.NewWriter()
	w.U8(accept)
	w.StringU8(name)
	w.I64(int64(inviter))
	w.I64(int64(invited))
	w.U16(0)
	return &protocol.C2SFrame{Opcode: protocol.OpTeamUpAnswer, Arch: 2, Payload: w.Bytes()}
}

func TestTeamUpFormsADuo(t *testing.T) {
	d := teamUpDeps(t)
	a := teamUpSession(d, 1, "Alpha")
	b := teamUpSession(d, 2, "Bravo")

	if err := handleTeamUpRequest(a, teamUpRequest("Les Deux", 1, 2)); err != nil {
		t.Fatalf("request: %v", err)
	}
	if got := drain(t, b); len(got) != 1 || got[0] != protocol.OpTeamUpInvitation {
		t.Fatalf("invited got %v, want one 6025 invitation", got)
	}
	if got := drain(t, a); len(got) != 0 {
		t.Fatalf("inviter got %v, want nothing until the answer", got)
	}

	if err := handleTeamUpAnswer(b, teamUpAnswer(1, "Les Deux", 1, 2)); err != nil {
		t.Fatalf("answer: %v", err)
	}
	// BOTH clients open the fighter picker on 6028.
	for _, c := range []struct {
		s    *Session
		name string
	}{{a, "inviter"}, {b, "invited"}} {
		got := drain(t, c.s)
		if len(got) != 1 || got[0] != protocol.OpTeamUpAccepted {
			t.Errorf("%s got %v, want one 6028 accepted", c.name, got)
		}
	}

	pair := d.TeamUps.PairOf(1)
	if pair == nil || pair.Name != "Les Deux" {
		t.Fatalf("no duo formed, got %+v", pair)
	}
	if d.TeamUps.Partner(1) != 2 || d.TeamUps.Partner(2) != 1 {
		t.Errorf("partners = %d/%d, want 2/1 - the duo must resolve from EITHER side",
			d.TeamUps.Partner(1), d.TeamUps.Partner(2))
	}
}

func TestTeamUpRefusalTellsTheInviter(t *testing.T) {
	d := teamUpDeps(t)
	a := teamUpSession(d, 1, "Alpha")
	b := teamUpSession(d, 2, "Bravo")

	_ = handleTeamUpRequest(a, teamUpRequest("Nope", 1, 2))
	drain(t, a)
	drain(t, b)

	if err := handleTeamUpAnswer(b, teamUpAnswer(0, "Nope", 1, 2)); err != nil {
		t.Fatalf("answer: %v", err)
	}
	if got := drain(t, a); len(got) != 1 || got[0] != protocol.OpTeamUpRefused {
		t.Fatalf("inviter got %v, want 6027 refused - otherwise its dialog hangs forever", got)
	}
	if d.TeamUps.PairOf(1) != nil || d.TeamUps.PairOf(2) != nil {
		t.Error("a refused invitation still formed a duo")
	}
}

func TestTeamUpRejectsTheImpossible(t *testing.T) {
	tests := []struct {
		name  string
		setup func(d *Deps, a, b *Session)
		// inviterID is what the ATTACKER puts in the packet's inviter field.
		inviterID uint
		invitedID uint
	}{
		{
			name:      "self-invitation",
			setup:     func(*Deps, *Session, *Session) {},
			inviterID: 1, invitedID: 1,
		},
		{
			name:      "invited coach is offline",
			setup:     func(*Deps, *Session, *Session) {},
			inviterID: 1, invitedID: 99,
		},
		{
			name: "invited coach ignores the inviter",
			setup: func(_ *Deps, _, b *Session) {
				b.Coach.Ignored = []domain.CoachIgnored{{IgnoredID: 1}}
			},
			inviterID: 1, invitedID: 2,
		},
		{
			name: "inviter is already in a fight",
			setup: func(d *Deps, a, _ *Session) {
				f := &Fight{Teams: [2]*FightTeam{
					{ID: 0, Members: []*FightMember{{Coach: a.Coach}}}, nil,
				}}
				d.Fights.Create(f)
			},
			inviterID: 1, invitedID: 2,
		},
		{
			name: "invited coach is already in a duo",
			setup: func(d *Deps, _, b *Session) {
				d.TeamUps.bind(&teamUpPair{Name: "Taken", InviterID: 7, InvitedID: b.Coach.ID})
			},
			inviterID: 1, invitedID: 2,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			d := teamUpDeps(t)
			a := teamUpSession(d, 1, "Alpha")
			b := teamUpSession(d, 2, "Bravo")
			tc.setup(d, a, b)
			drain(t, a)
			drain(t, b)

			if err := handleTeamUpRequest(a, teamUpRequest("X", tc.inviterID, tc.invitedID)); err != nil {
				t.Fatalf("request: %v", err)
			}
			if got := drain(t, b); len(got) != 0 {
				t.Errorf("invited coach received %v, want no invitation", got)
			}
			if got := drain(t, a); len(got) != 1 || got[0] != protocol.OpTeamUpRefused {
				t.Errorf("inviter got %v, want 6027 refused", got)
			}
			if d.TeamUps.PairOf(1) != nil {
				t.Error("a duo formed despite the request being refused")
			}
		})
	}
}

// TestTeamUpAnswerCannotBeForged: 6026 names its inviter, so a coach could claim
// an invitation that was never sent to it - or that came from someone else.
func TestTeamUpAnswerCannotBeForged(t *testing.T) {
	d := teamUpDeps(t)
	a := teamUpSession(d, 1, "Alpha")
	b := teamUpSession(d, 2, "Bravo")
	c := teamUpSession(d, 3, "Charlie")

	// Alpha invites Bravo. Charlie was never invited.
	_ = handleTeamUpRequest(a, teamUpRequest("Duo", 1, 2))
	drain(t, a)
	drain(t, b)
	drain(t, c)

	if err := handleTeamUpAnswer(c, teamUpAnswer(1, "Duo", 1, 3)); err != nil {
		t.Fatalf("answer: %v", err)
	}
	if d.TeamUps.PairOf(3) != nil {
		t.Fatal("an uninvited coach accepted its way into a duo")
	}
	if got := drain(t, a); len(got) != 0 {
		t.Errorf("inviter was told %v about a forged answer", got)
	}
	// Bravo's real invitation must survive the forgery attempt.
	if err := handleTeamUpAnswer(b, teamUpAnswer(1, "Duo", 1, 2)); err != nil {
		t.Fatalf("real answer: %v", err)
	}
	if d.TeamUps.PairOf(2) == nil {
		t.Error("the genuine invitation was consumed by the forged one")
	}
}

// TestTeamUpAnswerMustNameTheRealInviter: 6026 echoes an inviter id back, and it
// is attacker-controlled. A coach holding a genuine invitation from Alpha must
// not be able to answer it naming Charlie - that would bind Charlie, who sent
// nothing, into a duo it never agreed to and cannot see.
//
// Added after a mutation run: removing the inviter match from takePending left
// every other test passing, which meant the check was unproven.
func TestTeamUpAnswerMustNameTheRealInviter(t *testing.T) {
	d := teamUpDeps(t)
	a := teamUpSession(d, 1, "Alpha")
	b := teamUpSession(d, 2, "Bravo")
	c := teamUpSession(d, 3, "Charlie")

	_ = handleTeamUpRequest(a, teamUpRequest("Duo", 1, 2))
	drain(t, a)
	drain(t, b)
	drain(t, c)

	// Bravo answers its real invitation but names Charlie as the inviter.
	if err := handleTeamUpAnswer(b, teamUpAnswer(1, "Duo", 3, 2)); err != nil {
		t.Fatalf("answer: %v", err)
	}
	if p := d.TeamUps.PairOf(3); p != nil {
		t.Fatalf("Charlie was bound into a duo it never opened: %+v", p)
	}
	if d.TeamUps.PairOf(2) != nil {
		t.Fatal("a duo formed from an answer naming the wrong inviter")
	}
	if got := drain(t, c); len(got) != 0 {
		t.Errorf("Charlie was sent %v about a duo it never opened", got)
	}
	// Alpha's genuine invitation must still be answerable.
	if err := handleTeamUpAnswer(b, teamUpAnswer(1, "Duo", 1, 2)); err != nil {
		t.Fatalf("real answer: %v", err)
	}
	if d.TeamUps.PairOf(2) == nil {
		t.Error("the genuine invitation was consumed by the mis-addressed answer")
	}
}

// TestTeamUpAnswerRevalidatesOnAccept: the invitation dialog is modal and can sit
// open indefinitely, so the world may have moved on before the answer arrives.
func TestTeamUpAnswerRevalidatesOnAccept(t *testing.T) {
	d := teamUpDeps(t)
	a := teamUpSession(d, 1, "Alpha")
	b := teamUpSession(d, 2, "Bravo")

	_ = handleTeamUpRequest(a, teamUpRequest("Late", 1, 2))
	drain(t, a)
	drain(t, b)

	// While the dialog sat open, the inviter started a fight.
	d.Fights.Create(&Fight{Teams: [2]*FightTeam{
		{ID: 0, Members: []*FightMember{{Coach: a.Coach}}}, nil,
	}})

	if err := handleTeamUpAnswer(b, teamUpAnswer(1, "Late", 1, 2)); err != nil {
		t.Fatalf("answer: %v", err)
	}
	if d.TeamUps.PairOf(2) != nil {
		t.Fatal("a duo formed with a coach that is already fighting")
	}
	if got := drain(t, b); len(got) != 1 || got[0] != protocol.OpTeamUpRefused {
		t.Errorf("accepter got %v, want 6027 so its picker does not open alone", got)
	}
}

// TestDuoPresetsCarryTheAlly is what makes a formed duo visible and launchable.
//
// The 2VS2 tab lists team PRESETS, and "Combattre" (23103) sends back
// zK.afG() - the first entry of the preset's trailing coach list. So a duo with
// no preset is invisible in the panel, and a preset with an empty coach list
// launches as a solo fight. Both must hold, for BOTH members.
func TestDuoPresetsCarryTheAlly(t *testing.T) {
	st, err := storetest.Open(t, filepath.Join(t.TempDir(), "duo.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })
	d := &Deps{Store: st, TeamUps: newTeamUps(), Log: testLogger()}

	pair := &teamUpPair{Name: "LesDeux", InviterID: 1, InvitedID: 2}
	d.createDuoPresets(pair)

	for _, c := range []struct{ owner, ally uint }{{1, 2}, {2, 1}} {
		teams, err := st.Teams.ListByCoach(c.owner)
		if err != nil {
			t.Fatalf("list teams for %d: %v", c.owner, err)
		}
		var duo *domain.Team
		for i := range teams {
			if teams[i].GameMode == gameMode2v2 {
				duo = &teams[i]
			}
		}
		if duo == nil {
			t.Fatalf("coach %d has no 2v2 preset - its 2VS2 tab would be empty", c.owner)
		}
		if duo.AllyCoachID != c.ally {
			t.Errorf("coach %d preset ally = %d, want %d", c.owner, duo.AllyCoachID, c.ally)
		}
		if duo.Name != "LesDeux" {
			t.Errorf("coach %d preset name = %q, want the duo's name", c.owner, duo.Name)
		}
		// The type must be one the client actually stamps on teams (-6, as
		// hu_2 case 16632 does). Type 0 belongs to no bucket and carries no
		// appearance bytes, so the row has nothing to draw.
		if duo.Type != duoTeamType {
			t.Errorf("coach %d preset type = %d, want %d - a type the client renders",
				c.owner, duo.Type, duoTeamType)
		}
		if !specialTeamType(duo.Type) {
			t.Errorf("coach %d preset type %d skips the appearance bytes", c.owner, duo.Type)
		}
		// The blob's coach list must hold BOTH coaches, ally first.
		//
		// Count: the 2VS2 tab lists presets where sw_1.afL() is true, and afL()
		// is `bMK.size() == 2`. A one-entry list makes the team invisible - which
		// is exactly what happened live before this was checked.
		// Order: afG() returns bMK.get(0) and that is the id 23103 sends back as
		// the ally, so the partner must be first.
		blob := encodeTeamPreset(duo, nil)
		want := append([]byte{2}, append(i64Bytes(int64(c.ally)), i64Bytes(int64(c.owner))...)...)
		if !frameContains(blob, want) {
			t.Errorf("coach %d preset coach list is not [2][ally=%d][self=%d] - the "+
				"2VS2 tab would not list it (afL needs exactly 2) or Combattre would "+
				"name the wrong ally", c.owner, c.ally, c.owner)
		}
	}

	// Accepting twice must not litter the panel with duplicates.
	d.createDuoPresets(pair)
	teams, _ := st.Teams.ListByCoach(1)
	n := 0
	for i := range teams {
		if teams[i].GameMode == gameMode2v2 {
			n++
		}
	}
	if n != 1 {
		t.Errorf("coach 1 has %d 2v2 presets after two accepts, want 1", n)
	}
}

// TestDuoPresetSatisfiesAfH reproduces the client's own launch gate.
//
// sw_1.afH(): when the preset has more than one coach, EVERY coach in its coach
// list must control at least one fighter in the team - and cF(coachId) decides
// that from the SECOND i64 of each fighter entry (`bMJ.du(id) == coachId || ==
// -1`). It reads the preset alone and never consults the client's roster, so
// this is fully checkable here.
//
// Getting either half wrong makes the client refuse with "Un des coachs ne
// controle aucun combattant", which is exactly what it did while that i64
// carried the fighter's BUDGET.
func TestDuoPresetSatisfiesAfH(t *testing.T) {
	st, err := storetest.Open(t, filepath.Join(t.TempDir(), "afh.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })
	d := &Deps{Store: st, TeamUps: newTeamUps(), Log: testLogger()}

	// One titular fighter each, plus a benched one that must NOT be chosen.
	//
	// The benched fighter is created FIRST so it also has the lowest id: listed
	// in id order it is what a "just take the first" implementation would pick.
	// With the titular one first the bench check was unfalsifiable - a mutation
	// removing it passed.
	for _, f := range []domain.Fighter{
		{CoachID: 1, BreedID: 1, Name: "A2", State: domain.FighterStateBench},
		{CoachID: 1, BreedID: 1, Name: "A1", State: domain.FighterStateTitular},
		{CoachID: 2, BreedID: 2, Name: "B1", State: domain.FighterStateTitular},
	} {
		if err := st.DB().Create(&f).Error; err != nil {
			t.Fatalf("create fighter: %v", err)
		}
	}

	d.createDuoPresets(&teamUpPair{Name: "Duo", InviterID: 1, InvitedID: 2})

	teams, _ := st.Teams.ListByCoach(1)
	var duo *domain.Team
	for i := range teams {
		if teams[i].GameMode == gameMode2v2 {
			duo = &teams[i]
		}
	}
	if duo == nil {
		t.Fatal("no duo preset")
	}
	ownerOf := map[uint]uint{}
	for _, coach := range []uint{1, 2} {
		fs, _ := st.Fighters.ListByCoach(coach)
		for i := range fs {
			ownerOf[fs[i].ID] = fs[i].CoachID
		}
	}
	tp, err := decodeTeamPreset(encodeTeamPreset(duo, ownerOf))
	if err != nil {
		t.Fatalf("decode: %v", err)
	}

	// afH(), transcribed.
	if len(tp.CoachIDs) <= 1 {
		t.Fatalf("coach list = %v, want two entries or afH never runs", tp.CoachIDs)
	}
	for _, coach := range tp.CoachIDs {
		controlled := 0
		for i := range tp.FighterIDs {
			if tp.FighterOwners[i] == coach || tp.FighterOwners[i] == -1 {
				controlled++
			}
		}
		if controlled == 0 {
			t.Errorf("coach %d controls no fighter in the preset (owners=%v) - the client "+
				"refuses this team with \"Un des coachs ne controle aucun combattant\"",
				coach, tp.FighterOwners)
		}
	}
	// The benched fighter must not have been picked.
	for i := range tp.FighterIDs {
		var f domain.Fighter
		if err := st.DB().First(&f, tp.FighterIDs[i]).Error; err == nil {
			if f.State != domain.FighterStateTitular {
				t.Errorf("preset fields benched fighter %q", f.Name)
			}
		}
	}
}

func i64Bytes(v int64) []byte {
	b := make([]byte, 8)
	for i := 7; i >= 0; i-- {
		b[i] = byte(v)
		v >>= 8
	}
	return b
}

// TestTeamUpNameIsSanitised: the name is echoed into a dialog the client renders
// as markup, which escapes nothing (B-104).
func TestTeamUpNameIsSanitised(t *testing.T) {
	tests := []struct{ in, want string }{
		{"<b>bold</b>", "bbold/b"},
		{"   ", "2vs2"},
		{"", "2vs2"},
		{"0123456789012345678901234567890123456789", "01234567890123456789012345678901"},
	}
	for _, tc := range tests {
		if got := teamUpName(tc.in); got != tc.want {
			t.Errorf("teamUpName(%q) = %q, want %q", tc.in, got, tc.want)
		}
	}
}
