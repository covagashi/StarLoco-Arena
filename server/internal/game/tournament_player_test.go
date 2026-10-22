package game

import (
	"testing"
	"time"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store"
)

// Block C of S09: player-created tournaments (17010) and the entry cards.

// createFrame builds a 17010 exactly as `aFu.encode` lays it out.
func createFrame(name, desc string, def uint8, periods ...[2]time.Time) *protocol.C2SFrame {
	w := protocol.NewWriter().I32(0)
	w.U16(1).I32(42) // one custom fight rule (not applied)
	now := time.Now().UnixMilli()
	w.I64(now).I64(now).I64(now) // registration start/end, event end
	w.U8(uint8(2 * len(periods)))
	for _, p := range periods {
		w.I64(p[0].UnixMilli()).I64(p[1].UnixMilli())
	}
	w.StringU8(name)
	w.U16(uint16(len(desc))).Raw([]byte(desc))
	w.U8(def)
	w.I64(0).I32(0) // no period, no repetition
	w.U8(0)         // no pro leagues
	return &protocol.C2SFrame{Opcode: protocol.OpTournamentCreate, Arch: 3, Payload: w.Bytes()}
}

// playerRig is a scheduler rig plus a creator coach holding n creation cards.
func playerRig(t *testing.T, cards int16) (*schedRig, *Session) {
	t.Helper()
	r := newSchedRig(t, 1, 0, nil)
	cardsTable, err := openRealGameData(t).LoadCards()
	if err != nil {
		t.Fatal(err)
	}
	r.d.Cards = cardsTable
	acc, _ := r.st.Accounts.CreateAccount("maker", "pw", false)
	co, _ := r.st.Coaches.Create(acc.ID, "Maker", 0, 0, 0)
	if cards > 0 {
		if err := r.st.Coaches.GrantCards(co.ID, []store.GrantCard{{TemplateID: 807, Quantity: cards}}); err != nil {
			t.Fatal(err)
		}
	}
	s := tmSession(r.d, co.ID, "Maker")
	return r, s
}

func playerTournaments(t *testing.T, r *schedRig, creator uint) []domain.Tournament {
	t.Helper()
	all, _ := r.st.Tournaments.List()
	var out []domain.Tournament
	for _, tr := range all {
		if tr.CreatorCoachID == creator {
			out = append(out, tr)
		}
	}
	return out
}

func TestPlayerTournamentIsCreatedAndCostsTheCard(t *testing.T) {
	r, s := playerRig(t, 2)
	start := r.now.Add(48 * time.Hour).Truncate(time.Minute)
	if err := handleTournamentCreate(s, createFrame("Coupe des amis", "Entre nous", 1,
		[2]time.Time{start, start.Add(2 * time.Hour)})); err != nil {
		t.Fatal(err)
	}
	got := playerTournaments(t, r, s.Coach.ID)
	if len(got) != 1 {
		t.Fatalf("%d player tournaments, want 1", len(got))
	}
	tr := got[0]
	if tr.DefID != 1 || tr.Name != "Coupe des amis" || tr.Description != "Entre nous" ||
		tr.Organizer != "Maker" || !tr.SearchPeriodStart.Equal(start) ||
		tr.SearchPeriodMinutes != 120 || tr.SearchPeriods != 1 || tr.RepeatDays != 0 || tr.Official() {
		t.Errorf("row = %+v", tr)
	}
	if n := int16(ownedQty(t, r.d, s.Coach.ID, 807)); n != 1 {
		t.Errorf("807 left: %d, want 1 (one spent)", n)
	}
	// It is listed to everyone, like any tournament.
	live, _ := r.st.Tournaments.ListEnabled()
	found := false
	for _, l := range live {
		found = found || l.ID == tr.ID
	}
	if !found {
		t.Error("the player tournament is not offered to players")
	}
}

func TestPlayerTournamentWithoutTheCard(t *testing.T) {
	r, s := playerRig(t, 0)
	start := r.now.Add(48 * time.Hour)
	_ = handleTournamentCreate(s, createFrame("Sans carte", "", 1, [2]time.Time{start, start.Add(time.Hour)}))
	if got := playerTournaments(t, r, s.Coach.ID); len(got) != 0 {
		t.Fatalf("created without the card: %+v", got)
	}
	p := drainPayload(t, s, protocol.OpErrorNotice)
	if len(p) != 1 || p[0] != errBadCoachCardQuantity {
		t.Errorf("25000 payload %x, want code 66 (badCoachCardQuantity)", p)
	}
}

func TestPlayerTournamentRefusals(t *testing.T) {
	r, s := playerRig(t, 5)
	soon := r.now.Add(48 * time.Hour)
	for name, f := range map[string]*protocol.C2SFrame{
		"prize definition":    createFrame("A", "", 11, [2]time.Time{soon, soon.Add(time.Hour)}),
		"ticketed definition": createFrame("B", "", 19, [2]time.Time{soon, soon.Add(time.Hour)}),
		"unknown definition":  createFrame("C", "", 2, [2]time.Time{soon, soon.Add(time.Hour)}),
		"in the past":         createFrame("D", "", 1, [2]time.Time{r.now.Add(-time.Hour), r.now}),
		"too far ahead":       createFrame("E", "", 1, [2]time.Time{r.now.Add(500 * 24 * time.Hour), r.now.Add(500*24*time.Hour + time.Hour)}),
		"overlapping":         createFrame("F", "", 1, [2]time.Time{soon, soon.Add(2 * time.Hour)}, [2]time.Time{soon.Add(time.Hour), soon.Add(3 * time.Hour)}),
		"no period":           createFrame("G", "", 1),
	} {
		_ = handleTournamentCreate(s, f)
		if got := playerTournaments(t, r, s.Coach.ID); len(got) != 0 {
			t.Errorf("%s: created %+v", name, got)
			for _, tr := range got {
				_ = r.st.Tournaments.Delete(tr.ID)
			}
		}
	}
	if n := int16(ownedQty(t, r.d, s.Coach.ID, 807)); n != 5 {
		t.Errorf("807 left: %d, want 5: a refused tournament must not cost the card", n)
	}
}

// TestPlayerTournamentScoresNothing: no points and no official win, so it
// cannot farm the board; it still counts as a tournament won (190).
func TestPlayerTournamentScoresNothing(t *testing.T) {
	r := newSchedRig(t, 1, 2, func(tr *domain.Tournament) { tr.CreatorCoachID = 999; tr.SearchPeriods = 1 })
	tid := r.tr.WireID()
	a := r.online(t, 0)
	r.at(time.Minute)
	r.d.TickTournaments()
	_ = handleTournamentSearchRequest(a, readyFrame(tid, r.coaches[0], 0))
	r.at(31 * time.Minute)
	r.d.TickTournaments()
	if got := r.reload(t); got.WinnerCoachID != r.coaches[0] {
		t.Fatalf("winner %d, want A", got.WinnerCoachID)
	}
	if p := r.stat(r.coaches[0], statTournamentPoints); p != 0 {
		t.Errorf("statistic 183 = %d from a player tournament, want 0", p)
	}
	if w := r.stat(r.coaches[0], statOfficialWins); w != 0 {
		t.Errorf("statistic 187 = %d from a player tournament, want 0", w)
	}
	if w := r.stat(r.coaches[0], statTournamentWins); w != 1 {
		t.Errorf("statistic 190 = %d, want 1", w)
	}
}

// TestEntryCardIsTakenAtRegistration: definition 19 costs card 808.
func TestEntryCardIsTakenAtRegistration(t *testing.T) {
	r := newSchedRig(t, 19, 0, nil)
	cardsTable, _ := openRealGameData(t).LoadCards()
	r.d.Cards = cardsTable
	acc, _ := r.st.Accounts.CreateAccount("vip", "pw", false)
	co, _ := r.st.Coaches.Create(acc.ID, "Vip", 0, 0, 0)
	s := tmSession(r.d, co.ID, "Vip")
	register := func(card int32) uint8 {
		w := protocol.NewWriter().I64(r.tr.WireID()).I64(int64(co.ID)).U16(0xFFFF).I32(card)
		_ = handleTournamentRegister(s, &protocol.C2SFrame{Opcode: protocol.OpTournamentRegister, Payload: w.Bytes()})
		p := drainPayload(t, s, protocol.OpTournamentRegisterReply)
		return p[8]
	}
	if code := register(808); code == 0 {
		t.Fatal("registered without owning the ticket")
	}
	_ = r.st.Coaches.GrantCards(co.ID, []store.GrantCard{{TemplateID: 808, Quantity: 2}})
	if code := register(0); code == 0 {
		t.Fatal("registered without offering the ticket")
	}
	if code := register(-808); code != 0 { // the client may send the id negated
		t.Fatalf("refused with the ticket: code %d", code)
	}
	if code := register(808); code != 0 {
		t.Fatalf("re-registering refused: code %d", code)
	}
	if n := int16(ownedQty(t, r.d, co.ID, 808)); n != 1 {
		t.Errorf("808 left: %d, want 1: one ticket, taken once", n)
	}
}

// TestGMGiveCard: the only source of 807 and 808.
func TestGMGiveCard(t *testing.T) {
	r, s := playerRig(t, 0)
	s.Account = &domain.Account{ID: 1, Name: "Admin", IsAdmin: true}
	_ = handleGMCommand(s, "/GIVECARD Maker 807 3")
	if n := int16(ownedQty(t, r.d, s.Coach.ID, 807)); n != 3 {
		t.Errorf("807 after /GIVECARD: %d, want 3", n)
	}
	_ = handleGMCommand(s, "/GIVECARD Maker 999999")
	_ = handleGMCommand(s, "/GIVECARD Nobody 807")
	if n := int16(ownedQty(t, r.d, s.Coach.ID, 807)); n != 3 {
		t.Errorf("807 after bad grants: %d, want 3", n)
	}
}
