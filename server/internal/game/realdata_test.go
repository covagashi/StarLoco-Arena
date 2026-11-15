package game

import (
	"testing"

	"github.com/StarLoco/arena-2.70/content"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// realGameData is the game's own data for a real-data test: since S43 the
// tables come from server/content (embedded), so these tests run on every
// build instead of skipping without the retail client's files.
type realGameData struct {
	c *gamedata.CardContent
	r *gamedata.RulesContent
}

// openRealGameData loads the embedded content; a broken tree fails the test.
func openRealGameData(t testing.TB) *realGameData {
	t.Helper()
	c, err := gamedata.LoadCardContent(content.Cards)
	if err != nil {
		t.Fatal(err)
	}
	r, err := gamedata.LoadRulesContent(content.Rules)
	if err != nil {
		t.Fatal(err)
	}
	return &realGameData{c: c, r: r}
}

func (d *realGameData) LoadCards() (*gamedata.Cards, error)               { return d.c.Cards, nil }
func (d *realGameData) LoadCardSets() (*gamedata.CardSets, error)         { return d.c.Sets, nil }
func (d *realGameData) LoadFighterCards() (*gamedata.FighterCards, error) { return d.c.Fighters, nil }
func (d *realGameData) LoadEvents() (*gamedata.Events, error)             { return d.c.Events, nil }
func (d *realGameData) LoadSpells() (*gamedata.Spells, error)             { return d.r.Spells, nil }
func (d *realGameData) LoadSummonings() (*gamedata.Summonings, error)     { return d.r.Summonings, nil }
func (d *realGameData) LoadStaticEffects() (*gamedata.StaticEffects, error) {
	return d.r.StaticEffects, nil
}
func (d *realGameData) LoadChallenges() (*gamedata.Challenges, error) { return d.r.Challenges, nil }
func (d *realGameData) LoadAchievements() (*gamedata.Achievements, error) {
	return d.r.Achievements, nil
}
func (d *realGameData) LoadConditions() (*gamedata.Conditions, error)   { return d.r.Conditions, nil }
func (d *realGameData) LoadFusionLabs() (*gamedata.FusionLabs, error)   { return d.r.FusionLabs, nil }
func (d *realGameData) LoadMapBonuses() (*gamedata.MapBonuses, error)   { return d.r.MapBonuses, nil }
func (d *realGameData) LoadTournaments() (*gamedata.Tournaments, error) { return d.r.Tournaments, nil }
func (d *realGameData) LoadSphereBoards() (*gamedata.SphereBoards, error) {
	return d.r.SphereBoards, nil
}
func (d *realGameData) LoadEquipmentPools() (*gamedata.EquipmentPools, error) {
	return d.r.EquipmentPools, nil
}
