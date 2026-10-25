package gamedata

import "log/slog"

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

	// Fight arenas come from the client's own map files rather than the bdat
	// store, so they load independently: a server without them still runs,
	// falling back to the built-in world 5.
	if loc.MapsRoot != "" {
		fm, err := LoadFightMaps(loc.MapsRoot)
		if err != nil {
			log.Debug("fight maps not loaded; falling back to the built-in arena",
				"dir", loc.MapsRoot, "err", err)
		} else {
			b.FightMaps = fm
			log.Debug("fight maps loaded", "arenas", fm.Len(),
				"skipped", fm.Skipped(), "unreachableSpecials", fm.UnreachableSpecials())
		}
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
	b.Cards, err = st.LoadCards()
	warn("card", err)
	ApplyCardMasterPrices(b.Cards) // S28: the Card Master sets cost tokens
	b.Spells, err = st.LoadSpells()
	warn("spell", err)
	b.FighterCards, err = st.LoadFighterCards()
	warn("fighter-card", err)
	b.Summonings, err = st.LoadSummonings()
	warn("summoning", err)
	b.StaticEffects, err = st.LoadStaticEffects()
	warn("static-effect", err)
	b.Challenges, err = st.LoadChallenges()
	warn("challenge", err)
	b.Events, err = st.LoadEvents()
	warn("event-card", err)
	b.CardSets, err = st.LoadCardSets()
	warn("card-set", err)
	b.Achievements, err = st.LoadAchievements()
	warn("achievement", err)
	b.Conditions, err = st.LoadConditions()
	warn("fighter-condition", err)
	b.FusionLabs, err = st.LoadFusionLabs()
	warn("fusion-lab", err)
	b.MapBonuses, err = st.LoadMapBonuses()
	warn("map-bonus", err)
	// The drop table derives only from the card set, so it can build
	// straight from what LoadCards just produced.
	b.DrawTable = NewDrawTable(b.Cards, nil)
	b.Tournaments, err = st.LoadTournaments()
	warn("tournament-definition", err)
	b.SphereBoards, err = st.LoadSphereBoards()
	warn("sphere-board", err)
	b.EquipmentPools, err = st.LoadEquipmentPools()
	warn("equipment-pool", err)
	return b
}
