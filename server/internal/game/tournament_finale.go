package game

import (
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// Finale announcements (28620 Yq): the standing "Finale du tournoi X - A VS B"
// entry in the client's alert list (`iz_1.Vg()`), added when the last fixture of
// a tournament starts and withdrawn when it ends.
//
// Unlike the search-period pushes this is not driven by the scheduler: the
// final is simply the fixture whose parent slot is the root, which the bracket
// already knows.

const (
	finaleStatusAdd    uint8 = 1
	finaleStatusRemove uint8 = 2
)

// buildTournamentFinaleAdd encodes the ADD form.
//
// Both arrays are written in REVERSE, and that is not a style choice: `Yq.a`
// reads them backwards (`for (n = len-1; 0 <= n; --n)`), so the first element on
// the wire is stored at the highest index. `zN` renders `names[0] VS names[1]`,
// so writing them in natural order would swap the two finalists - a mistake that
// produces a perfectly valid frame and a wrong announcement.
func buildTournamentFinaleAdd(tid int64, coachIDs []int64, names []string, tournamentName string) ([]byte, error) {
	w := protocol.NewWriter().U8(finaleStatusAdd).I64(tid)

	w.I32(int32(len(coachIDs)))
	for i := len(coachIDs) - 1; i >= 0; i-- {
		w.I64(coachIDs[i])
	}

	w.I32(int32(len(names)))
	for i := len(names) - 1; i >= 0; i-- {
		w.StringU32(names[i])
	}

	w.StringU32(tournamentName)
	return protocol.EncodeS2C(protocol.OpTournamentFinale, w.Bytes())
}

// buildTournamentFinaleRemove encodes the REMOVE form, which carries only the id.
func buildTournamentFinaleRemove(tid int64) ([]byte, error) {
	w := protocol.NewWriter().U8(finaleStatusRemove).I64(tid)
	return protocol.EncodeS2C(protocol.OpTournamentFinale, w.Bytes())
}

// isFinalFixture reports whether a fixture between these two coaches decides the
// tournament: their slots are siblings whose parent is the root.
func (d *Deps) isFinalFixture(tid int64, a, b uint) bool {
	if d.Tournaments == nil {
		return false
	}
	slots := d.Tournaments.BracketSlots(tid)
	sa, okA := topSlotOf(slots, a)
	sb, okB := topSlotOf(slots, b)
	if !okA || !okB || sa == sb || sa/2 != sb/2 {
		return false
	}
	return d.Tournaments.FixtureDecidesTournament(tid, sa/2)
}

// announceFinale tells every online coach that a tournament's final is under way.
//
// It is broadcast rather than sent to the two finalists: the point of the entry
// is that everyone else can see the final is happening. The finalists are in a
// fight and will not be reading their alert list anyway.
func (d *Deps) announceFinale(tid int64, a, b *Session) {
	if d.World == nil || a.Coach == nil || b.Coach == nil {
		return
	}
	name := d.tournamentDisplayName(tid)
	frame, err := buildTournamentFinaleAdd(tid,
		[]int64{int64(a.Coach.ID), int64(b.Coach.ID)},
		[]string{a.Coach.Name, b.Coach.Name},
		name)
	if err != nil {
		d.Log.Warn("build finale announcement", "tournament", tid, "err", err)
		return
	}
	for _, s := range d.World.allSessions() {
		_ = s.Send(frame)
	}
	d.Log.Info("tournament finale announced", "tournament", tid,
		"a", a.Coach.Name, "b", b.Coach.Name)
}

// withdrawFinale removes the announcement once the final is decided.
func (d *Deps) withdrawFinale(tid int64) {
	if d.World == nil {
		return
	}
	frame, err := buildTournamentFinaleRemove(tid)
	if err != nil {
		d.Log.Warn("build finale withdrawal", "tournament", tid, "err", err)
		return
	}
	for _, s := range d.World.allSessions() {
		_ = s.Send(frame)
	}
}

// settleTournamentPeriod settles a search period that has just closed:
// whoever was searching takes the fixture, whoever was not is declared forfeit.
//
// Called by the scheduler when the period ends (closeSearchPeriod). It used to
// run lazily from the tournament-list request, so a period that closed while
// nobody looked was never settled. The outcome depends only on who was
// searching, and SettleClosedPeriod is idempotent.
func (d *Deps) settleTournamentPeriod(tid int64) {
	if d.Tournaments == nil {
		return
	}
	results := d.Tournaments.SettleClosedPeriod(tid, func(coachID uint) bool {
		return d.sessionForCoach(coachID) != nil
	})
	for _, r := range results {
		d.Log.Info("tournament fixture settled by forfeit", "tournament", tid,
			"winner", r.Winner, "loser", r.Loser, "slot", r.Slot)
		if sess := d.sessionForCoach(r.Winner); sess != nil {
			_ = sess.sendTournamentSearchEnded(tid, false)
		}
		if sess := d.sessionForCoach(r.Loser); sess != nil {
			_ = sess.sendTournamentSearchEnded(tid, true)
		}
		if r.Slot == bracketWinnerSlot {
			d.withdrawFinale(tid)
			d.awardTournamentPrize(tid, r.Winner, d.sessionForCoach(r.Winner))
		}
	}
}

// tournamentDisplayName is the tournament's own name, falling back to an empty
// string rather than an invented one - the client prints it verbatim into
// "Finale du tournoi [#1]".
func (d *Deps) tournamentDisplayName(tid int64) string {
	if d.Store == nil {
		return ""
	}
	t, err := d.Store.Tournaments.GetByWireID(tid)
	if err != nil || t == nil {
		return ""
	}
	return t.Name
}
