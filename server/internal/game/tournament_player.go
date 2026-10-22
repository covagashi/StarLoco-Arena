package game

import (
	"time"
	"unicode/utf8"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// Player-created tournaments (17010 aFu, S09 block C).
//
// tournamentCreationDialog asks for a name, a description, a day and an hour
// (and optional custom fight rules); `oz_1` case 20072 checks the coach holds
// card 807 "Création de Tournoi", sends 17010 and shows "tournamentCreated"
// without waiting for a reply. The message carries the definition the
// tournament is built on (`selectedTournamentDefinition`, 1 unless changed),
// so a player tournament is an ordinary edition row: the "no type-1000 id"
// gap this was once filed under does not exist.
//
//	[i32 _][i16 n]{i32 fightParam}                  custom rules (jk_1)
//	[i64 regStart][i64 regEnd][i64 eventEnd]        epoch millis (rd_1.uJ)
//	[u8 n]{i64 start, i64 end}                      the game periods, n even, <= 8
//	[u8 len][utf8 name][i16 len][utf8 description]
//	[u8 definition][i64 period (jx_0)][i32 repetition][u8 n]{i32 proLeague}
//
// Taken as: the definition, the name and description, and the game periods
// as the search periods. Left out, on purpose: the registration dates
// (registration here closes when the first period starts, as for every
// tournament), the custom rules (definition rules are not applied either), the
// repeat and the pro-league list (the admin half of the same message).

const (
	cardTournamentCreation int32 = 807
	// errBadCoachCardQuantity is 25000 code 66, "you do not have the required
	// cards": the one code missing from the fight-creation table `je_2`, and
	// this is the action it fits.
	errBadCoachCardQuantity uint8 = 66
	// playerTournamentMaxPeriods: the dialog has four date slots.
	playerTournamentMaxPeriods = 4
	// playerTournamentMaxAhead keeps a player tournament from squatting the
	// calendar for years: the dialog itself only offers this year and next.
	playerTournamentMaxAhead = 400 * 24 * time.Hour
	playerTournamentPosition = 1000 // after the official line-up
)

// playerTournament is the useful half of a 17010.
type playerTournament struct {
	defID       uint8
	name, desc  string
	periods     [][2]time.Time
	fightParams int
}

func decodePlayerTournament(payload []byte) (playerTournament, error) {
	var pt playerTournament
	r := protocol.NewReader(payload)
	if _, err := r.I32(); err != nil {
		return pt, err
	}
	n, err := r.U16()
	if err != nil {
		return pt, err
	}
	for i := 0; i < int(n); i++ {
		if _, err := r.I32(); err != nil {
			return pt, err
		}
	}
	pt.fightParams = int(n)
	for i := 0; i < 3; i++ { // registration start/end, event end
		if _, err := r.I64(); err != nil {
			return pt, err
		}
	}
	dates, err := r.U8()
	if err != nil {
		return pt, err
	}
	for i := 0; i+1 < int(dates); i += 2 {
		a, err := r.I64()
		if err != nil {
			return pt, err
		}
		b, err := r.I64()
		if err != nil {
			return pt, err
		}
		pt.periods = append(pt.periods, [2]time.Time{time.UnixMilli(a), time.UnixMilli(b)})
	}
	if dates%2 == 1 {
		if _, err := r.I64(); err != nil {
			return pt, err
		}
	}
	if pt.name, err = r.StringU8(); err != nil {
		return pt, err
	}
	dl, err := r.U16()
	if err != nil {
		return pt, err
	}
	raw, err := r.Bytes(int(dl))
	if err != nil {
		return pt, err
	}
	pt.desc = protocol.DecodeText(raw)
	if pt.defID, err = r.U8(); err != nil {
		return pt, err
	}
	return pt, nil // period, repetition and pro-leagues are not used
}

// toTournament validates a player tournament and turns it into a row. The
// reason is for the log; the player only ever sees the client's own
// "tournamentCreated", so a refusal is silent apart from the card being kept.
func (d *Deps) playerTournamentRow(pt playerTournament, creator *domain.Coach, now time.Time) (*domain.Tournament, string) {
	switch {
	case pt.name == "" || len(pt.name) > 127 || !utf8.ValidString(pt.name):
		return nil, "bad name"
	case len(pt.desc) > 1000:
		return nil, "description too long"
	case len(pt.periods) == 0 || len(pt.periods) > playerTournamentMaxPeriods:
		return nil, "bad period count"
	}
	if d.TournamentDefs != nil {
		def := d.TournamentDefs.Get(int16(pt.defID))
		switch {
		case def == nil:
			return nil, "unknown definition" // the client would NPE on it
		case def.RewardCard != 0 || def.InscriptionCard != 0:
			// A prize would be a card tap among friends, and an entry ticket
			// is the console's business.
			return nil, "definition with a prize or an entry card"
		}
	}
	first := pt.periods[0]
	length := first[1].Sub(first[0])
	if !first[0].After(now) || first[0].Sub(now) > playerTournamentMaxAhead {
		return nil, "start not in the next year"
	}
	if length < time.Minute || length > 24*time.Hour {
		return nil, "bad period length"
	}
	interval := time.Duration(0)
	for i := 1; i < len(pt.periods); i++ {
		gap := pt.periods[i][0].Sub(pt.periods[i-1][0])
		if gap < length {
			return nil, "overlapping periods"
		}
		if interval == 0 {
			interval = gap // the model has one interval; the first gap sets it
		}
	}
	return &domain.Tournament{
		DefID:                 uint16(pt.defID),
		Name:                  pt.name,
		Short:                 pt.name,
		Description:           pt.desc,
		Organizer:             creator.Name,
		Enabled:               true,
		RegistrationOpen:      true,
		Position:              playerTournamentPosition,
		SearchPeriodStart:     first[0],
		SearchPeriodMinutes:   int32(length / time.Minute),
		SearchPeriods:         int32(len(pt.periods)),
		PeriodIntervalMinutes: int32(interval / time.Minute),
		CreatorCoachID:        creator.ID,
	}, ""
}

// handleTournamentCreate handles 17010.
func handleTournamentCreate(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil || s.deps.Store == nil {
		return nil
	}
	pt, err := decodePlayerTournament(f.Payload)
	if err != nil {
		return err
	}
	row, why := s.deps.playerTournamentRow(pt, s.Coach, s.deps.tournamentNow())
	if row == nil {
		s.log.Info("player tournament refused", "coach", s.Coach.Name, "reason", why)
		return nil
	}
	// Row first, card second: a failed insert must not cost the card, and the
	// card take is the atomic step (two racing 17010s cannot both spend one).
	if err := s.deps.Store.Tournaments.Create(row); err != nil {
		s.log.Warn("player tournament: create", "coach", s.Coach.Name, "err", err)
		return nil
	}
	if !s.consumeCard(cardTournamentCreation) {
		_ = s.deps.Store.Tournaments.Delete(row.ID)
		s.log.Info("player tournament refused: no creation card", "coach", s.Coach.Name)
		return s.sendErrorNotice(errBadCoachCardQuantity)
	}
	s.refreshAndPushInventory()
	s.log.Info("player tournament created", "coach", s.Coach.Name, "tournament", row.WireID(),
		"name", row.Name, "def", row.DefID, "start", row.SearchPeriodStart,
		"periods", row.SearchPeriods, "rulesIgnored", pt.fightParams)
	return nil
}
