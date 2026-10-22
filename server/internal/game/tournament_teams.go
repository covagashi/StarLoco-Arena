package game

import (
	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// Which team a tournament fixture is played with.
//
// A tournament's definition (type 1000, `aub.aHh()`) names a team kind, and the
// client routes the entrant to the matching place when it clicks the alert row
// (`agz_1`): the evolution tab, the graveyard dialog (`en_2`), the Légendes tab,
// or the Tournois tab restricted to the definition's presets. Each sends 28611
// with its own preset:
//
//	classic   (1) a real team preset id         hu_2 23101
//	evolution (2) 99, the evolution team         hu_2 23101 via xz_0.tI()
//	graveyard (3) 10000                          en_2 23101
//	legendary (4) 9999, the legend line-up       hu_2 23201
const (
	legendTeamPreset    uint16 = 9999
	graveyardTeamPreset uint16 = 10000
)

// tournamentTeamType is the team kind of a tournament's definition, or
// TournamentTeamUnknown when it cannot be told (no store, no catalogue).
func (d *Deps) tournamentTeamType(tid int64) uint8 {
	if d.Store == nil || d.Store.Tournaments == nil || d.TournamentDefs == nil {
		return gamedata.TournamentTeamUnknown
	}
	t, err := d.Store.Tournaments.GetByWireID(tid)
	if err != nil || t == nil {
		return gamedata.TournamentTeamUnknown
	}
	def := d.TournamentDefs.Get(int16(t.DefID))
	if def == nil {
		return gamedata.TournamentTeamUnknown
	}
	return def.TeamType
}

// tournamentPresetAllowed reports whether a 28611 preset fits the tournament's
// team kind. An unknown kind accepts anything, as before this check existed.
func (d *Deps) tournamentPresetAllowed(tid int64, preset uint16) bool {
	switch d.tournamentTeamType(tid) {
	case gamedata.TournamentTeamClassic:
		return preset != evolutionTeamPreset && preset != legendTeamPreset &&
			preset != graveyardTeamPreset
	case gamedata.TournamentTeamEvolution:
		return preset == evolutionTeamPreset
	case gamedata.TournamentTeamGraveyard:
		return preset == graveyardTeamPreset
	case gamedata.TournamentTeamLegendary:
		return preset == legendTeamPreset
	}
	return true
}

// tournamentRoster is the line-up a coach fields in a fixture.
//
// Classic plays the named preset (IDOR-guarded by resolveTeamRoster), falling
// back to the titular line-up as the tournament path always has. Evolution
// and graveyard play the titular line-up: that is what 99 means everywhere
// else (handlers_evolution_search.go), and the graveyard dialog only lists
// who of that team has died. Legendary plays the legendary titulars.
func (d *Deps) tournamentRoster(coachID uint, tid int64, preset uint16, seats int) []int64 {
	if d.Store == nil {
		return nil // the fight builder falls back on its own
	}
	switch preset {
	case legendTeamPreset:
		return d.fightersInState(coachID, domain.FighterStateLegendary, seats)
	case evolutionTeamPreset, graveyardTeamPreset:
		return d.titularRoster(coachID, seats)
	}
	if r := d.resolveTeamRoster(coachID, uint(preset)); len(r) > 0 {
		return r
	}
	return d.titularRoster(coachID, seats)
}

// fightersInState lists up to max of a coach's fighters in one state.
func (d *Deps) fightersInState(coachID uint, state uint8, max int) []int64 {
	if max > maxTeamMembers {
		max = maxTeamMembers
	}
	fighters, err := d.Store.Fighters.ListByCoach(coachID)
	if err != nil {
		return nil
	}
	var ids []int64
	for i := range fighters {
		if fighters[i].State == state && len(ids) < max {
			ids = append(ids, int64(fighters[i].ID))
		}
	}
	return ids
}
