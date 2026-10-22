package game

import (
	"context"
	"time"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// The tournament scheduler: what makes a scheduled edition run on its own.
//
// An edition (domain.Tournament) takes entrants until its first search period
// starts. Each period then opens (28646 to the online entrants), lets the
// entrants of each fixture find each other (28611), and closes: whoever was
// searching takes an undecided fixture by forfeit (28648), the alert row goes
// (28630 open=0) and anybody still waiting is released (28610). The edition
// finishes as soon as the bracket has a winner, or when its last period closes
// with none; a repeating one then opens its next edition as a new row.
//
// This replaces the lazy settlement that ran when someone asked for the
// tournament list: a period that closed while nobody looked was never settled,
// and nothing could ever end a tournament.

// tournamentTick is how often the scheduler looks. Period boundaries are
// minutes apart, so a few seconds of lag is invisible.
const tournamentTick = 5 * time.Second

// tournamentNow is the scheduler's clock.
func (d *Deps) tournamentNow() time.Time {
	if d.TournamentClock != nil {
		return d.TournamentClock()
	}
	return time.Now()
}

// RunTournamentScheduler ticks until ctx is done.
func (d *Deps) RunTournamentScheduler(ctx context.Context) {
	t := time.NewTicker(tournamentTick)
	defer t.Stop()
	d.TickTournaments()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			d.TickTournaments()
		}
	}
}

// TickTournaments advances every scheduled, unfinished, enabled edition to
// where the clock says it should be. Safe to call at any time: every step is
// idempotent or guarded by the marks.
func (d *Deps) TickTournaments() {
	if d.Store == nil || d.Store.Tournaments == nil || d.Tournaments == nil {
		return
	}
	ts, err := d.Store.Tournaments.ListEnabled()
	if err != nil {
		d.Log.Warn("tournament scheduler: list", "err", err)
		return
	}
	now := d.tournamentNow()
	for i := range ts {
		if ts[i].Scheduled() {
			d.tickTournament(&ts[i], now)
		}
	}
}

func (d *Deps) tickTournament(t *domain.Tournament, now time.Time) {
	tid := t.WireID()
	closed := t.ClosedPeriodsAt(now)
	mk := d.Tournaments.periodMarks(tid, closed)

	// Close first: a tick can cross the end of one period and the start of
	// the next, and the next must not open with the previous one's searchers.
	if closed > mk.settled {
		mk.settled = closed
		if mk.opened < closed {
			mk.opened = closed // a period that closed unseen is not announced
		}
		d.Tournaments.setPeriodMarks(tid, mk)
		d.closeSearchPeriod(t)
	}
	if i := t.OpenPeriodAt(now); i >= 0 && mk.opened <= i {
		mk.opened = i + 1
		d.Tournaments.setPeriodMarks(tid, mk)
		_, end := t.Period(i)
		d.openSearchPeriod(t, end.Sub(now))
	}

	if now.Before(t.SearchPeriodStart) {
		return // still taking entrants: the draw is not fixed yet
	}
	winner := d.Tournaments.BracketSlots(tid)[bracketWinnerSlot]
	if winner == 0 && !now.Before(t.LastPeriodEnd()) && d.tournamentFightInProgress(tid) {
		// The last period has closed with a fixture still being played: its
		// result can still decide the tournament, so wait for it.
		return
	}
	if winner != 0 || !now.Before(t.LastPeriodEnd()) {
		d.finishTournament(t, winner, now)
	}
}

// tournamentFightInProgress reports whether any entrant is playing one of
// this tournament's fixtures right now.
func (d *Deps) tournamentFightInProgress(tid int64) bool {
	if d.Fights == nil {
		return false
	}
	for _, coachID := range d.Tournaments.EntrantsFor(tid) {
		if f := d.Fights.ByCoach(coachID); f != nil && f.TournamentID == tid {
			return true
		}
	}
	return false
}

// openSearchPeriod tells the online entrants that a period starts now.
func (d *Deps) openSearchPeriod(t *domain.Tournament, left time.Duration) {
	tid := t.WireID()
	frame, err := protocol.EncodeS2C(protocol.OpTournamentSearchOpening,
		protocol.NewWriter().I64(tid).I64(left.Milliseconds()).Bytes())
	if err != nil {
		return
	}
	n := 0
	for _, coachID := range d.Tournaments.EntrantsFor(tid) {
		if s := d.sessionForCoach(coachID); s != nil {
			_ = s.Send(frame)
			n++
		}
	}
	d.Log.Info("tournament search period opened", "tournament", tid,
		"name", t.Name, "online", n, "left", left.Round(time.Second))
}

// closeSearchPeriod settles a period that has just ended.
func (d *Deps) closeSearchPeriod(t *domain.Tournament) {
	tid := t.WireID()
	d.settleTournamentPeriod(tid)

	// Whoever is still waiting had nobody to meet. The period is over, so take
	// their waiting dialog down: 28610 is the client's own "no longer ready".
	cancel, _ := protocol.EncodeS2C(protocol.OpTournamentSearchCancelResult,
		protocol.NewWriter().U8(1).Bytes())
	for _, coachID := range d.Tournaments.ClearReady(tid) {
		if s := d.sessionForCoach(coachID); s != nil && cancel != nil {
			_ = s.Send(cancel)
		}
	}
	d.withdrawSearchAlert(tid)
	d.Log.Info("tournament search period closed", "tournament", tid, "name", t.Name)
}

// withdrawSearchAlert removes the tournament's alert row (28630 open=0) from
// every online entrant. Removing a row that is not there is a no-op in `zN`.
func (d *Deps) withdrawSearchAlert(tid int64) {
	frame, err := buildTournamentSearchPeriod(tid, false)
	if err != nil {
		return
	}
	for _, coachID := range d.Tournaments.EntrantsFor(tid) {
		if s := d.sessionForCoach(coachID); s != nil {
			_ = s.Send(frame)
		}
	}
}

// finishTournament ends an edition: once, whoever calls it.
func (d *Deps) finishTournament(t *domain.Tournament, winner uint, now time.Time) {
	tid := t.WireID()
	won, err := d.Store.Tournaments.MarkFinished(t.ID, winner, now)
	if err != nil {
		d.Log.Warn("tournament finish", "tournament", tid, "err", err)
		return
	}
	if !won {
		return // someone else finished it
	}
	d.settleTournamentResults(t, winner)
	if winner != 0 {
		// Usually paid already, by the final or the forfeit that decided it;
		// the claim is single-shot, so this only covers a winner carried to the
		// root by byes alone.
		d.awardTournamentPrize(tid, winner, d.sessionForCoach(winner))
	}
	d.withdrawFinale(tid)
	d.withdrawSearchAlert(tid)
	d.Tournaments.Forget(tid)
	d.Log.Info("tournament finished", "tournament", tid, "name", t.Name, "winner", winner)

	if t.RepeatDays > 0 {
		d.openNextEdition(t, now)
	}
}

// openNextEdition creates the edition that follows a repeating one: same
// tournament, schedule moved on by whole RepeatDays steps until it starts in
// the future. A new row, so a new wire id, an empty draw and no registrations.
func (d *Deps) openNextEdition(t *domain.Tournament, now time.Time) {
	if next, err := d.Store.Tournaments.NextEdition(t.ID); err == nil && next != nil {
		return // already opened (a retried finish)
	}
	step := time.Duration(t.RepeatDays) * 24 * time.Hour
	start := t.SearchPeriodStart.Add(step)
	for !start.After(now) {
		start = start.Add(step)
	}
	next := *t
	next.ID = 0
	next.SearchPeriodStart = start
	next.FinishedAt = nil
	next.WinnerCoachID = 0
	next.PreviousID = t.ID
	next.RegistrationOpen = true
	next.CreatedAt, next.UpdatedAt = time.Time{}, time.Time{}
	if err := d.Store.Tournaments.Create(&next); err != nil {
		d.Log.Warn("tournament next edition", "tournament", t.WireID(), "err", err)
		return
	}
	d.Log.Info("tournament next edition opened", "from", t.WireID(),
		"to", next.WireID(), "start", start)
}
