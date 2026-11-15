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

// LoadBundle loads the game's own data, embedded in the binary. Since S43 no
// table comes from loc (it is kept for the GM /TP world topology); a broken
// content tree is survivable: the affected tables stay nil and the server
// still starts.
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

	// The rest of the rules too (S43), embedded from server/content/rules:
	// nothing here reads data.bdat any more.
	if r, err := LoadRulesContent(content.Rules); err != nil {
		log.Warn("rules content not loaded", "err", err)
	} else {
		b.Spells, b.Summonings, b.StaticEffects = r.Spells, r.Summonings, r.StaticEffects
		b.Challenges, b.Achievements, b.Conditions = r.Challenges, r.Achievements, r.Conditions
		b.FusionLabs, b.MapBonuses, b.Tournaments = r.FusionLabs, r.MapBonuses, r.Tournaments
		b.SphereBoards, b.EquipmentPools = r.SphereBoards, r.EquipmentPools
		log.Debug("rules content loaded", "spells", b.Spells.Len(), "challenges", b.Challenges.Len(),
			"achievements", b.Achievements.Len(), "sphereBoards", b.SphereBoards.BoardCount())
	}
	return b
}
