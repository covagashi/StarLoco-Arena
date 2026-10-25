package game

import (
	"log/slog"
	"sync"
	"time"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/store"
)

// Deps is the dependency container every handler closure captures.
type Deps struct {
	// fillerOnce seeds the filler ghosts on the first ghost request (S14).
	fillerOnce sync.Once
	// Rules are the server-invented numbers (XP, standing, social caps). Zero
	// value means "use DefaultRules" - see rules.go.
	Rules Rules
	// Limits bounds connections and login attempts. Zero value = no limits, so
	// tests and existing embedders are unaffected until they opt in.
	Limits Limits
	Store  *store.Store
	// arenas is built from FightMaps by NewServer (initArenas).
	arenas   arenaRegistry
	World    *Registry
	Cards    *gamedata.Cards    // nil if data files absent
	CardSets *gamedata.CardSets // card-set (panoplie) bonuses; nil if data files absent
	// FusionLabs is the type-1100 altar table (power / quality / slot count). The
	// 5490 request names no altar, so the fusion handler uses FusionLabs.Default().
	FusionLabs *gamedata.FusionLabs // nil if data files absent
	// MapBonuses is the type-1600 per-map table (eliteDropBonus + akw_0
	// actions: AI19 drop chance on arenas 86-109, AI1 XP% on 24-28).
	MapBonuses *gamedata.MapBonuses // nil if data files absent
	// DrawTable is the alb_1 card-draw table (built from Cards). nil means the
	// drop draw is inert — lazily built from Cards when unset (drops.go).
	DrawTable *gamedata.DrawTable // nil builds lazily from Cards
	// TournamentDefs is the type-1000/1001 tournament table. Read-only reference
	// data: the standing tournaments the server actually runs are built in
	// tournaments.go and validated against this.
	TournamentDefs *gamedata.Tournaments    // nil if data files absent
	Conditions     *gamedata.Conditions     // persistent fighter conditions/wounds (type 902); nil if data files absent
	Spells         *gamedata.Spells         // nil if data files absent
	SphereBoards   *gamedata.SphereBoards   // Kanodo boards/nodes (types 900/901); nil if data files absent
	EquipmentPools *gamedata.EquipmentPools // equipment a Kanodo node unlocks (type 251); nil if data files absent
	FighterCards   *gamedata.FighterCards   // nil if data files absent
	Summonings     *gamedata.Summonings     // summon-creature templates; nil if data files absent
	StaticEffects  *gamedata.StaticEffects  // trap/glyph (type-210) templates; nil if data files absent
	// ChallengeDefs is the type-400 challenge TABLE (PvE definitions behind the
	// overworld's DemonChallenge / BreedMaster elements); nil if data files
	// absent. Not to be confused with Challenges below, which is the live
	// coach-vs-coach direct-challenge manager.
	ChallengeDefs *gamedata.Challenges
	// FightMaps holds every arena decoded from data/maps; nil falls back to the
	// hand-decoded world 5 (see arena_registry.go).
	FightMaps *gamedata.FightMaps
	// MapsRoot is the maps directory (contents/maps). Only the GM teleport uses
	// it, to resolve a destination cell's real ground altitude on demand rather
	// than loading all ~113 world topologies at startup. Empty disables that.
	MapsRoot string
	// Events is the per-round event-card table (type 230). nil/empty leaves the
	// round-card mechanic inert (eventId 0, no effects) — see events.go.
	Events *gamedata.Events
	// Achievements is the type-800/801/802 "exploits" catalogue. nil leaves the
	// evaluator inert (no unlocks announced); the tab still opens and renders
	// progress, because the client computes percentages itself from the criteria.
	Achievements *gamedata.Achievements
	Exchanges    *ExchangeManager
	Matchmaker   *Matchmaker

	// GuildInvites holds outstanding clan invitations (in memory by design - see
	// handlers_guild.go).
	GuildInvites *guildInvites
	Challenges   *ChallengeManager
	Fights       *FightManager
	Sessions     *SessionRegistry
	// Tournaments tracks registrations, the bracket and the waiting searchers,
	// written through to the store.
	Tournaments *TournamentManager
	// TournamentClock is the scheduler's clock (tournament_schedule.go); nil
	// means time.Now. Tests set it to walk an edition through its periods.
	TournamentClock func() time.Time
	// SeasonClock is the season scheduler's clock (seasons.go); nil = now.
	SeasonClock func() time.Time
	// TeamUps holds pending 2v2 invitations and the duos they form.
	TeamUps *teamUps
	// WebBaseURL is the portal address announced to Godot clients that ask
	// (opcode 60000 -> 60001). Set from web.public_url, else derived from the
	// bound portal listener; empty when the portal is disabled.
	WebBaseURL string
	Log        *slog.Logger
}

// RegisterAll wires every feature handler group onto the router.
func RegisterAll(r *Router, d *Deps) {
	if d.TeamUps == nil {
		d.TeamUps = newTeamUps()
	}
	if d.GuildInvites == nil {
		// Constructed here so every caller - server, tests, harness - gets one
		// without having to know it exists.
		d.GuildInvites = newGuildInvites()
	}
	registerConnectionHandlers(r, d)
	registerLifecycleHandlers(r, d)
	registerMovementHandlers(r, d)
	registerChatHandlers(r, d)
	registerEmoteHandlers(r, d)
	registerGuildHandlers(r, d)
	registerGuildAdminHandlers(r, d)
	registerDemonAffiliationHandlers(r, d)
	registerSocialHandlers(r, d)
	registerInventoryHandlers(r, d)
	registerShopHandlers(r, d)
	registerFusionHandlers(r, d)
	registerExchangeHandlers(r, d)
	registerFighterHandlers(r, d)
	registerTeamHandlers(r, d)
	registerMatchmakingHandlers(r, d)
	registerLadderHandlers(r, d)
	registerFightHandlers(r, d)
	registerFightCreationHandlers(r, d)
	registerEvolutionSearchHandlers(r, d)
	registerReconnectHandlers(r, d)
	registerSpectateHandlers(r, d)
	registerChallengeHandlers(r, d)
	registerElementHandlers(r, d)
	registerZaapHandlers(r, d)
	registerMailHandlers(r, d)
	registerEvolutionHandlers(r, d)
	registerSphereHandlers(r, d)
	registerTotemHandlers(r, d)
	registerTeamUpHandlers(r, d)
	registerClientConfigHandlers(r, d)
	registerStoryHandlers(r, d)
	registerSeasonHandlers(r, d)
	registerGhostHandlers(r, d)
}

// UseGameData copies a loaded bundle into the container. cmd/server and the e2e
// harness both go through it, so a table wired here is wired in both.
func (d *Deps) UseGameData(b *gamedata.Bundle) {
	if b == nil {
		return
	}
	d.Cards = b.Cards
	d.Spells = b.Spells
	d.FighterCards = b.FighterCards
	d.Summonings = b.Summonings
	d.ChallengeDefs = b.Challenges
	d.FightMaps = b.FightMaps
	d.Events = b.Events
	d.Achievements = b.Achievements
	d.MapsRoot = b.Loc.MapsRoot
	d.CardSets = b.CardSets
	d.FusionLabs = b.FusionLabs
	d.MapBonuses = b.MapBonuses
	d.DrawTable = b.DrawTable
	d.TournamentDefs = b.Tournaments
	d.SphereBoards = b.SphereBoards
	d.EquipmentPools = b.EquipmentPools
	d.Conditions = b.Conditions
	d.StaticEffects = b.StaticEffects

	// Teach the fighter repo where a card may be equipped, so every fighter it
	// hands out already matches what the client's 5-slot inventory will accept.
	// The store cannot import game data itself, so the mapping is injected: a
	// card's record type IS its slot type (vi_1 — weapon 1 … dofus 5, at
	// positions 0-4).
	if d.Store != nil && b.FighterCards != nil {
		fc := b.FighterCards
		d.Store.Fighters.EquipSlotOf = func(templateID int32) (int16, bool) {
			c := fc.Get(templateID)
			if c == nil || c.Type < 1 || c.Type > 5 {
				return 0, false
			}
			return int16(c.Type) - 1, true
		}
	}
}
