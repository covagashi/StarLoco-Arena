package game

import (
	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/store"
)

// What an edition leaves behind when it finishes (S09): tournament points,
// the tournament statistics the achievements count, and who is offered the
// carry-over to the next edition (28618).

// Client or_0 statistics for tournaments. Every one is a "maximal" counter of
// a running total, so they are added to, never maxed against a single result:
// the achievements (182-206) ask for 5 up to 20 000 points and 5 up to 1 000
// tournaments, which only cumulative values can reach.
const (
	statTournamentPoints  int16 = 183 // "Points maximaux atteint en tournoi"
	statOfficialWins      int16 = 187 // "Nombre maximal de tournois officiels gagnés"
	statTournamentDuels   int16 = 188 // "Nombre maximal de duels gagnés en tournoi"
	statTournamentEntries int16 = 189 // "Nombre maximal d'inscriptions atteint en tournoi"
	statTournamentWins    int16 = 190 // "Nombre maximal de tournois gagnés" (official or not)
)

// tournamentPointsByWins is what an entrant earns by fixtures actually won:
// 1 for taking part, then 3, 6 and 10 for reaching the quarter-final, semi and
// final of a full draw. Winning the tournament is worth 20, so the top points
// achievement (20 000) sits where the top wins one does (1 000 tournaments).
var tournamentPointsByWins = [...]int32{1, 3, 6, 10}

const tournamentWinnerPoints int32 = 20

// tournamentPoints is the points for one entry. A winner that never played
// (carried to the root by byes alone) is scored by its wins like anyone else:
// signing up alone to an empty tournament must not be worth a win's points.
func tournamentPoints(fixturesWon int, winner bool) int32 {
	if winner && fixturesWon > 0 {
		return tournamentWinnerPoints
	}
	if fixturesWon >= len(tournamentPointsByWins) {
		fixturesWon = len(tournamentPointsByWins) - 1
	}
	return tournamentPointsByWins[fixturesWon]
}

// settleTournamentResults scores a finishing edition. Called by
// finishTournament while the bracket is still in memory.
func (d *Deps) settleTournamentResults(t *domain.Tournament, winner uint) {
	tid := t.WireID()
	slots := d.Tournaments.BracketSlots(tid)
	var results []store.TournamentResult
	for _, coachID := range d.Tournaments.EntrantsFor(tid) {
		won := d.Tournaments.FixturesWon(tid, coachID)
		res := store.TournamentResult{CoachID: coachID}
		// Only official tournaments score: a player tournament among friends
		// would otherwise be a points tap for the board.
		if t.Official() {
			res.Points = tournamentPoints(won, coachID == winner)
		}
		// Still in contention when the edition ran out of periods: its seat's
		// fixture was never decided. Only worth flagging when a next edition
		// will exist to carry into.
		if winner == 0 && t.RepeatDays > 0 {
			if top, ok := topSlotOf(slots, coachID); ok && top > bracketWinnerSlot {
				if _, decided := slots[top/2]; !decided {
					res.Unfinished = true
				}
			}
		}
		results = append(results, res)

		b := statBatch{d: d, coach: coachID}
		b.add(statTournamentPoints, res.Points)
		if coachID == winner && won > 0 {
			if t.Official() {
				b.add(statOfficialWins, 1)
			}
			b.add(statTournamentWins, 1)
		}
		if s := d.sessionForCoach(coachID); s != nil && b.moved {
			s.evaluateAchievements()
		}
	}
	if err := d.Store.Tournaments.SetResults(tid, results); err != nil {
		d.Log.Warn("tournament results", "tournament", tid, "err", err)
	}
}

// noteTournamentDuel counts a played fixture won (statistic 188).
func (d *Deps) noteTournamentDuel(f *Fight, winner uint) {
	if d.Store == nil || winner == 0 {
		return
	}
	b := statBatch{d: d, coach: winner}
	b.add(statTournamentDuels, 1)
	if s := winnerSession(f, winner); s != nil && b.moved {
		s.evaluateAchievements()
	}
}

// noteTournamentEntry counts a new registration (statistic 189).
func (s *Session) noteTournamentEntry() {
	if s.deps.Store == nil || s.Coach == nil {
		return
	}
	b := statBatch{d: s.deps, coach: s.Coach.ID}
	b.add(statTournamentEntries, 1)
	if b.moved {
		s.evaluateAchievements()
	}
}
