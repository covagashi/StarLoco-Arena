package gamedata

import (
	"log/slog"

	"github.com/StarLoco/arena-2.70/content"
)

// Bundle is every table the game server reads at startup. LoadBundle is the one
// place that loads them, shared by cmd/server and the e2e harness, so the tests
// that drive the real socket also exercise the real data path (S08).
type Bundle struct {
	Loc            Location
	FightMaps      *FightMaps
	Cards          *Cards
	Spells         *Spells
	FighterCards   *FighterCards
	Summonings     *Summonings
	StaticEffects  *StaticEffects
	Challenges     *Challenges
	Events         *Events
	Achievements   *Achievements
	CardSets       *CardSets
	FusionLabs     *FusionLabs
	MapBonuses     *MapBonuses
	DrawTable      *DrawTable
	Tournaments    *Tournaments
	SphereBoards   *SphereBoards
	EquipmentPools *EquipmentPools
	Conditions     *Conditions
}

// LoadBundle loads whatever loc points at. Missing or unreadable data is
// survivable: the affected tables stay nil and the server still starts.
func LoadBundle(loc Location, log *slog.Logger) *Bundle {
	b := &Bundle{Loc: loc}

	// The fight arenas are the prototype's own, embedded in the binary, so
	// they load whatever loc points at.
	if fm, err := LoadFightMaps(); err != nil {
		log.Warn("fight arenas not loaded; falling back to the built-in arena", "err", err)
	} else {
		b.FightMaps = fm
		log.Debug("fight arenas loaded", "arenas", fm.Len())
	}

	// The cards are the game's own too (S40), embedded from server/content:
	// they load whatever loc points at, and never from data.bdat.
	if cc, err := LoadCardContent(content.Cards); err != nil {
		log.Warn("card content not loaded", "err", err)
	} else {
		b.Cards, b.CardSets, b.FighterCards, b.Events = cc.Cards, cc.Sets, cc.Fighters, cc.Events
		ApplyCardMasterPrices(b.Cards) // S28: the Card Master sets cost tokens
		// The drop table derives only from the card set.
		b.DrawTable = NewDrawTable(b.Cards, nil)
		log.Debug("card content loaded", "cards", b.Cards.Len(), "sets", b.CardSets.Len(),
			"fighterCards", b.FighterCards.Len(), "events", b.Events.Len())
	}

	st, err := Open(loc.BdatDir)
	if err != nil {
		log.Debug("game data not loaded", "dir", loc.BdatDir, "err", err)
		return b
	}
	warn := func(what string, err error) {
		if err != nil {
			log.Warn(what+" load failed", "err", err)
		}
	}
	b.Spells, err = st.LoadSpells()
	warn("spell", err)
	b.Summonings, err = st.LoadSummonings()
	warn("summoning", err)
	b.StaticEffects, err = st.LoadStaticEffects()
	warn("static-effect", err)
	b.Challenges, err = st.LoadChallenges()
	warn("challenge", err)
	b.Achievements, err = st.LoadAchievements()
	warn("achievement", err)
	b.Conditions, err = st.LoadConditions()
	warn("fighter-condition", err)
	b.FusionLabs, err = st.LoadFusionLabs()
	warn("fusion-lab", err)
	b.MapBonuses, err = st.LoadMapBonuses()
	warn("map-bonus", err)
	b.Tournaments, err = st.LoadTournaments()
	warn("tournament-definition", err)
	b.SphereBoards, err = st.LoadSphereBoards()
	warn("sphere-board", err)
	b.EquipmentPools, err = st.LoadEquipmentPools()
	warn("equipment-pool", err)
	return b
}
