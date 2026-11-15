package gamedata

import (
	"testing"

	"github.com/StarLoco/arena-2.70/content"
)

// contentStore stands in for the retail store the real-data tests
// used to open: since S43 the same tables come from server/content, so these
// tests run everywhere instead of skipping without the client's files.
type contentStore struct {
	c *CardContent
	r *RulesContent
}

// openContent loads the embedded content; its error is always nil (a broken
// tree fails the test), kept so the tests read as they did with Open.
func openContent(t testing.TB) (*contentStore, error) {
	t.Helper()
	c, err := LoadCardContent(content.Cards)
	if err != nil {
		t.Fatal(err)
	}
	r, err := LoadRulesContent(content.Rules)
	if err != nil {
		t.Fatal(err)
	}
	return &contentStore{c: c, r: r}, nil
}

func (s *contentStore) LoadCards() (*Cards, error)               { return s.c.Cards, nil }
func (s *contentStore) LoadCardSets() (*CardSets, error)         { return s.c.Sets, nil }
func (s *contentStore) LoadFighterCards() (*FighterCards, error) { return s.c.Fighters, nil }
func (s *contentStore) LoadEvents() (*Events, error)             { return s.c.Events, nil }
func (s *contentStore) LoadSpells() (*Spells, error)             { return s.r.Spells, nil }
func (s *contentStore) LoadSummonings() (*Summonings, error)     { return s.r.Summonings, nil }
func (s *contentStore) LoadStaticEffects() (*StaticEffects, error) {
	return s.r.StaticEffects, nil
}
func (s *contentStore) LoadChallenges() (*Challenges, error)     { return s.r.Challenges, nil }
func (s *contentStore) LoadAchievements() (*Achievements, error) { return s.r.Achievements, nil }
func (s *contentStore) LoadConditions() (*Conditions, error)     { return s.r.Conditions, nil }
func (s *contentStore) LoadFusionLabs() (*FusionLabs, error)     { return s.r.FusionLabs, nil }
func (s *contentStore) LoadMapBonuses() (*MapBonuses, error)     { return s.r.MapBonuses, nil }
func (s *contentStore) LoadTournaments() (*Tournaments, error)   { return s.r.Tournaments, nil }
func (s *contentStore) LoadSphereBoards() (*SphereBoards, error) { return s.r.SphereBoards, nil }
func (s *contentStore) LoadEquipmentPools() (*EquipmentPools, error) {
	return s.r.EquipmentPools, nil
}
