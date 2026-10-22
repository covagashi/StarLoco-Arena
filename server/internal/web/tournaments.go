package web

import (
	"errors"
	"fmt"
	"sort"
	"strings"
	"time"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// Tournament editing is the one place in this console where a careless save can
// take every connected client down rather than merely annoying somebody.
//
// A tournament row carries a client definition id, and the client dereferences
// that definition unguarded: `LS.Yf().gG(defId)` returns null for an id it does
// not have and the list/detail/register code walks straight into it. The retail
// build ships 22 definitions (ids 1 and 4..24) and nothing else.
//
// That rule cannot be left to the operator to remember, so it is enforced here
// against the decoded type-1000 catalogue, and the form only ever offers
// definitions the client has. Definitions with an inscription card (13: card
// 16, 19: card 808) used to be filtered out because nothing took the card; the
// server now takes it at registration (S09), so they are offered, labelled.
// Nothing in the game GRANTS those cards, though: /GIVECARD does.

// tournamentNameMax is the wire limit, not a style choice: the calendar entry
// length-prefixes the name and short label with a SIGNED byte, so 128 bytes
// presents as a negative length and the client's decoder throws.
const tournamentNameMax = protocol.MaxStringU8

// tournamentDescMax is editorial. The wire prefix is 16 bits, so the real
// ceiling is far higher, but a description that long is unreadable in the
// client's panel.
const tournamentDescMax = 1000

// tournamentChoice is one selectable client definition, decorated with what the
// decoded catalogue knows about it so an admin can choose meaningfully instead
// of guessing at a number.
type tournamentChoice struct {
	DefID    uint16
	TeamType uint8
	Label    string // e.g. "4 — classic 1v1 (3 rules)"
	Rules    int
}

// teamTypeLabel names a definition's team type. The client branches on this in
// agz_1 against aql_0 to decide which tournament UI to open.
func teamTypeLabel(t uint8) string {
	switch t {
	case gamedata.TournamentTeamClassic:
		return "classic 1v1"
	case gamedata.TournamentTeamEvolution:
		return "evolution"
	case gamedata.TournamentTeamGraveyard:
		return "graveyard"
	case gamedata.TournamentTeamLegendary:
		return "legendary"
	}
	return "unknown"
}

// tournamentChoices lists the definitions an admin may pick: those that exist in
// the client's own data.
//
// With no catalogue loaded (a server running without game data) it returns nil,
// and the caller falls back to accepting the id as typed — refusing to let an
// operator edit tournaments at all because the data directory is missing would
// be worse than trusting them.
func (s *Server) tournamentChoices() []tournamentChoice {
	if s.tournamentDefs == nil || s.tournamentDefs.Len() == 0 {
		return nil
	}
	var out []tournamentChoice
	for id, d := range s.tournamentDefs.All() {
		if d == nil || id <= 0 {
			continue
		}
		out = append(out, tournamentChoice{
			DefID:    uint16(id),
			TeamType: d.TeamType,
			Rules:    len(d.Rules),
			Label: fmt.Sprintf("%d — %s%s%s", id, teamTypeLabel(d.TeamType),
				func() string {
					if n := len(d.Rules); n > 0 {
						return fmt.Sprintf(", %d rule(s)", n)
					}
					return ""
				}(),
				func() string {
					if d.InscriptionCard != 0 {
						return fmt.Sprintf(", entry costs card %d", d.InscriptionCard)
					}
					return ""
				}()),
		})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].DefID < out[j].DefID })
	return out
}

// validateTournament applies the sign-off rules to a row about to be saved.
func (s *Server) validateTournament(t *domain.Tournament) error {
	t.Name = strings.TrimSpace(t.Name)
	t.Short = strings.TrimSpace(t.Short)
	t.Description = strings.TrimSpace(t.Description)
	t.Organizer = strings.TrimSpace(t.Organizer)

	switch {
	case t.Name == "":
		return errors.New("Please give the tournament a name.")
	case len(t.Name) > tournamentNameMax:
		return fmt.Errorf("The name must be at most %d characters — the game client cannot display a longer one.", tournamentNameMax)
	case len(t.Short) > tournamentNameMax:
		return fmt.Errorf("The short label must be at most %d characters.", tournamentNameMax)
	case len(t.Description) > tournamentDescMax:
		return fmt.Errorf("The description must be at most %d characters.", tournamentDescMax)
	case len(t.Organizer) > tournamentNameMax:
		return fmt.Errorf("The organiser must be at most %d characters.", tournamentNameMax)
	}
	if err := validateTournamentSchedule(t); err != nil {
		return err
	}
	if t.Short == "" {
		t.Short = t.Name
	}
	if t.Organizer == "" {
		t.Organizer = "StarLoco"
	}

	choices := s.tournamentChoices()
	if len(choices) == 0 {
		// No catalogue to check against; the id has to be taken on trust.
		if t.DefID == 0 {
			return errors.New("Please choose a tournament type.")
		}
		return nil
	}
	for _, c := range choices {
		if c.DefID == t.DefID {
			return nil
		}
	}
	return fmt.Errorf("Tournament type %d is not one this game client knows about. "+
		"Pick one from the list — an unknown type crashes the client when a player opens the tournament window.", t.DefID)
}

// tournamentMaxPeriods is the most search periods an edition may have: six,
// like the date slots of retail's own admin scheduler, and more than the four
// rounds a 16-entrant draw needs.
const tournamentMaxPeriods = 6

// validateTournamentSchedule checks the schedule half of the form. No start
// means unscheduled, which leaves the rest irrelevant (and zeroes it).
func validateTournamentSchedule(t *domain.Tournament) error {
	if t.SearchPeriodStart.IsZero() {
		if t.RepeatDays != 0 {
			return errors.New("A repeating tournament needs a start time.")
		}
		t.SearchPeriodMinutes, t.SearchPeriods, t.PeriodIntervalMinutes = 0, 0, 0
		return nil
	}
	switch {
	case t.SearchPeriodMinutes < 1 || t.SearchPeriodMinutes > 24*60:
		return errors.New("A search period lasts between 1 minute and 24 hours.")
	case t.SearchPeriods < 1 || t.SearchPeriods > tournamentMaxPeriods:
		return fmt.Errorf("A tournament has between 1 and %d search periods.", tournamentMaxPeriods)
	case t.SearchPeriods > 1 && t.PeriodIntervalMinutes < t.SearchPeriodMinutes:
		return errors.New("The time between period starts must be at least one period long, or two periods would be open at once.")
	case t.RepeatDays < 0 || t.RepeatDays > 365:
		return errors.New("Repeat every 0 to 365 days (0 = do not repeat).")
	}
	if t.RepeatDays > 0 {
		span := t.LastPeriodEnd().Sub(t.SearchPeriodStart)
		if span >= time.Duration(t.RepeatDays)*24*time.Hour {
			return errors.New("The next edition would start before this one ends; repeat less often or shorten the schedule.")
		}
	}
	return nil
}
