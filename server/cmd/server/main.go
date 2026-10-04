// Command server runs the DofusArena 2.70 game server.
//
// Run it with no arguments and it does the right thing: on first start it
// writes a documented config.yaml next to itself, creates its database, serves
// a small web portal where players register their own accounts, and prints the
// two addresses that matter.
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log/slog"
	"net"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/StarLoco/arena-2.70/internal/config"
	"github.com/StarLoco/arena-2.70/internal/game"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/store"
	"github.com/StarLoco/arena-2.70/internal/update"
	"github.com/StarLoco/arena-2.70/internal/version"
	"github.com/StarLoco/arena-2.70/internal/web"
)

func main() {
	configPath := flag.String("config", "config.yaml", "path to the YAML config file")
	dataDir := flag.String("data", "", "path to the game data, or to your DofusArena folder (overrides the config)")
	showVersion := flag.Bool("version", false, "print the version and exit")
	flag.Parse()

	if *showVersion {
		fmt.Println(version.String())
		return
	}

	if err := run(*configPath, *dataDir); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

func run(configPath, dataOverride string) error {
	// First run: leave the operator a documented file to edit. Never fatal -
	// a read-only directory should not stop the server from working.
	createdConfig, cfgErr := config.EnsureFile(configPath)

	cfg, err := config.Load(configPath)
	if err != nil {
		return err
	}
	if dataOverride != "" {
		cfg.DataDir = dataOverride
	}

	log := slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{
		Level: parseLevel(cfg.LogLevel),
	}))
	if cfgErr != nil {
		log.Warn("could not write the default config file", "err", cfgErr)
	}

	st, err := store.OpenConfig(store.Config{
		Driver:       cfg.DB.Driver,
		DSN:          cfg.DB.DSN,
		MaxOpenConns: cfg.DB.MaxOpenConns,
		MaxIdleConns: cfg.DB.MaxIdleConns,
	})
	if err != nil {
		return fmt.Errorf("open database: %w", err)
	}
	defer func() { _ = st.Close() }()
	if err := st.ResetConnectedFlags(); err != nil {
		log.Warn("reset connected flags", "err", err)
	}

	deps, dataLoc := buildDeps(cfg, st, log)

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	// SECURITY: combat validation is data-driven, so a server with no spell data
	// silently loses ALL of it.
	//
	// Every targeting rule in castSpellByFighter lives inside `if sp != nil`:
	// range, line of sight, free-cell, only-line, target masks, cast criteria and
	// cooldowns. spellLegalForBreed also fails OPEN without data, by design, so a
	// data-less server additionally accepts any spell on any fighter. The result
	// is a fight with ownership, turn order and "is alive" as its only rules -
	// which is fine for a unit test and catastrophic for a public instance.
	//
	// data-dist ships in git and is auto-discovered, so this should never fire in
	// practice; it exists because "never fires in practice" is exactly the
	// assumption that stops being true quietly.
	if spellsLen(deps.Spells) == 0 {
		log.Error("SECURITY: no spell data loaded - combat runs with NO range, " +
			"line-of-sight, target-mask, criteria or cooldown validation, and any " +
			"fighter may cast any spell. Do not expose this instance.")
		fmt.Println()
		fmt.Println("  !! No spell data was found. Combat validation is DISABLED.")
		fmt.Println("     Point data_dir at a copy of the client data, or restore")
		fmt.Println("     server/data-dist/, before letting anyone connect.")
		fmt.Println()
	}

	// SECURITY: a portal served over HTTPS with secure_cookies=false hands the
	// session cookie to any plain-HTTP request the browser is tricked into making.
	// The default is false because a Secure cookie is simply not sent over
	// http://localhost, which would break local development - so the correct
	// value differs by deployment and only the operator knows which they are.
	// Saying so once at startup is the cheapest way to stop that being silent.
	if cfg.Web.Enabled && !cfg.Web.SecureCookies {
		log.Warn("web portal is enabled with secure_cookies=false - correct for " +
			"plain HTTP, but if you serve the portal over HTTPS set " +
			"web.secure_cookies: true so session cookies are never sent in clear")
	}

	srv := game.NewServer(cfg.Addr, deps)

	// Bind both ports BEFORE announcing anything, so a port clash is reported
	// as a plain problem with a fix, rather than after a banner claiming the
	// server is up.
	gameLn, err := srv.Listen(ctx)
	if err != nil {
		return portInUse(cfg.Addr, err)
	}
	defer func() { _ = gameLn.Close() }()

	var webLn net.Listener
	if cfg.Web.Enabled {
		var webErr error
		webLn, webErr = web.Listen(cfg.Web.Addr)
		if webErr != nil {
			log.Warn("web portal disabled: no port available", "err", webErr)
		} else if want := requestedPort(cfg.Web.Addr); want > 0 && want != web.Port(webLn) {
			log.Warn("web portal port was busy, using another one",
				"requested", want, "using", web.Port(webLn))
		}
	}

	srv.StartDebugInject(cfg.DebugAddr) // no-op unless debug_addr is set

	banner(cfg, gameLn, webLn, createdConfig, configPath, deps, dataLoc)

	if webLn != nil {
		// The portal runs inside this process on purpose: that is what lets it
		// report live player and fight counts, and it means the admin
		// profiler dumps this server's own runtime rather than proxying to a
		// second, unauthenticated debug port.
		portal, err := web.New(st, cfg.Web, cfg.Addr, web.Live{
			PlayersOnline:  func() int { return deps.World.Len() },
			ActiveFights:   func() int { return deps.Fights.Count() },
			TournamentDefs: deps.TournamentDefs,
			TournamentRegistrations: func(wireID int64) int {
				return deps.Tournaments.CountFor(wireID)
			},
		}, log)
		if err != nil {
			return fmt.Errorf("web portal: %w", err)
		}
		go func() {
			if err := portal.Serve(ctx, webLn); err != nil {
				log.Error("web portal stopped", "err", err)
			}
		}()

		// Optional plain-http listener carrying ONLY the bug-report endpoint.
		// The 2012 client's Java 1.6 cannot negotiate modern TLS, so an
		// https-only site can never receive its bug reports; see
		// web.BugReportHandler. Failing to bind is a warning, not fatal - the
		// game and the website matter more than the bug form.
		if addr := strings.TrimSpace(cfg.Web.BugReportAddr); addr != "" && cfg.Web.BugReportsEnabled {
			bugLn, err := net.Listen("tcp", addr)
			if err != nil {
				log.Warn("bug-report listener disabled: cannot bind",
					"addr", addr, "err", err)
			} else {
				log.Info("bug-report listener (plain http, bug endpoint only)", "addr", addr)
				go func() {
					defer func() { _ = bugLn.Close() }()
					if err := portal.ServeBugReports(ctx, bugLn); err != nil {
						log.Error("bug-report listener stopped", "err", err)
					}
				}()
			}
		}
	}

	if cfg.UpdateCheck.Enabled {
		go checkForUpdate(ctx, cfg, log)
	}

	if err := srv.Serve(ctx, gameLn); err != nil {
		return fmt.Errorf("game server stopped: %w", err)
	}
	fmt.Println("Server stopped.")
	return nil
}

// portInUse turns a bind failure into something an operator can act on. "Port
// already in use" is the single most common startup problem, so it is worth
// spelling out the two ways to fix it.
func portInUse(addr string, err error) error {
	if errors.Is(err, syscall.EADDRINUSE) || strings.Contains(err.Error(), "address already in use") ||
		strings.Contains(strings.ToLower(err.Error()), "only one usage of each socket address") {
		return fmt.Errorf(
			"cannot start the game server on %s - another program is already using that port.\n"+
				"       Either stop it (a server you left running?), or change `addr` in your config file.",
			addr)
	}
	return fmt.Errorf("cannot listen on %s: %w", addr, err)
}

// banner is the whole of the server's normal startup output. Everything an
// operator needs, nothing they don't.
func banner(cfg config.Config, gameLn, webLn net.Listener, createdConfig bool, configPath string, deps *game.Deps, dataLoc gamedata.Location) {
	fmt.Println()
	fmt.Printf("  DofusArena 2.70 server %s\n", version.Short())
	fmt.Println()
	fmt.Printf("  Game server   %s\n", gameLn.Addr().String())
	if webLn != nil {
		fmt.Printf("  Web portal    %s\n", web.URL(webLn))
	} else if cfg.Web.Enabled {
		fmt.Println("  Web portal    unavailable (see the warning above)")
	} else {
		fmt.Println("  Web portal    disabled in config.yaml")
	}
	fmt.Println()

	if createdConfig {
		fmt.Printf("  Settings written to %s - edit it and restart to change anything.\n", configPath)
	}
	gameDataStatus(cfg, deps, dataLoc)
	if webLn != nil && cfg.Web.RegistrationEnabled {
		fmt.Println("  Players create their accounts on the web portal, then log in with the game client.")
	}
	fmt.Println("  Press Ctrl+C to stop.")
	fmt.Println()
}

// gameDataStatus reports what game data was found and, when something is
// missing, exactly how to fix it.
//
// The data is the retail client's copyrighted content, so it cannot ship with
// the server; the next best thing is to find the operator's own copy for them
// and, failing that, to make the fix a single obvious step instead of a
// folder-merging puzzle.
func gameDataStatus(cfg config.Config, deps *game.Deps, loc gamedata.Location) {
	haveCards := deps.Cards != nil
	haveArenas := deps.FightMaps != nil && deps.FightMaps.Len() > 0

	if haveCards && haveArenas {
		fmt.Printf("  Game data     %d cards, %d spells, %d arenas\n",
			cardsLen(deps.Cards), spellsLen(deps.Spells), arenaCount(deps))
		if loc.Root != "" {
			fmt.Printf("                from %s\n", loc.Root)
		}
		return
	}

	fmt.Println()
	switch {
	case !haveCards && !haveArenas:
		fmt.Println("  No game data found, so fights are unavailable.")
	case haveCards && !haveArenas:
		// Almost always means the operator pointed at contents/bdata, which
		// holds the records but not the arenas. Say so, rather than making
		// them guess which half is missing.
		fmt.Println("  Found the cards and spells, but no arenas, so fights are unavailable.")
		fmt.Println("  The arenas sit next to the records, not inside them - point one")
		fmt.Println("  folder higher up.")
	default:
		fmt.Println("  Found the arenas, but no cards or spells, so fights are unavailable.")
	}

	fmt.Println()
	fmt.Println("  The game data belongs to Ankama and cannot be shipped with this")
	fmt.Println("  server, so point it at your own DofusArena installation:")
	fmt.Println()
	fmt.Println("      arena-server --data \"<your DofusArena folder>\"")
	fmt.Println()
	fmt.Println("  or set data_dir in your config file to the same path. Use the folder")
	fmt.Println("  that holds DofusArena.exe - its game and game/contents folders work")
	fmt.Println("  too.")

	searched := gamedata.SearchedPaths(cfg.DataDir)
	if len(searched) > 0 {
		fmt.Println()
		fmt.Println("  Looked in:")
		for i, p := range searched {
			if i >= 6 { // enough to be useful without burying the banner
				fmt.Printf("      ... and %d more\n", len(searched)-i)
				break
			}
			fmt.Printf("      %s\n", p)
		}
	}
	fmt.Println()
}

// checkForUpdate tells the operator when a newer release exists. Every failure
// is deliberately quiet: an offline server must not be nagged, and a GitHub
// outage is not the operator's problem.
func checkForUpdate(ctx context.Context, cfg config.Config, log *slog.Logger) {
	timeout := time.Duration(cfg.UpdateCheck.TimeoutSeconds) * time.Second
	if timeout <= 0 {
		timeout = update.DefaultTimeout
	}
	res, err := update.Check(ctx, timeout)
	switch {
	case errors.Is(err, update.ErrDevBuild), errors.Is(err, update.ErrNoRelease):
		return // nothing meaningful to compare against
	case err != nil:
		log.Debug("update check failed", "err", err)
		return
	case !res.Available:
		return
	}

	fmt.Println()
	fmt.Printf("  A new version is available: %s (you have %s)\n", res.Latest, res.Current)
	if res.Major {
		fmt.Println("  This is a major update - read the release notes before upgrading.")
	}
	fmt.Printf("  Download: %s\n", res.URL)
	fmt.Println("  (Turn this check off with update_check.enabled: false in config.yaml)")
	fmt.Println()
}

// requestedPort reports the port an operator explicitly asked for, or 0 when
// they left it on automatic.
func requestedPort(addr string) int {
	_, port, err := net.SplitHostPort(addr)
	if err != nil {
		return 0
	}
	n, err := net.LookupPort("tcp", port)
	if err != nil {
		return 0
	}
	return n
}

// buildDeps loads the static game data and assembles the server dependencies.
// Missing or unreadable data is survivable: the server starts, and only real
// fights are unavailable.
func buildDeps(cfg config.Config, st *store.Store, log *slog.Logger) (*game.Deps, gamedata.Location) {
	var (
		cards         *gamedata.Cards
		spells        *gamedata.Spells
		fighterCards  *gamedata.FighterCards
		summonings    *gamedata.Summonings
		staticEffects *gamedata.StaticEffects
		challengeDefs *gamedata.Challenges
		events        *gamedata.Events
		achievements  *gamedata.Achievements
		cardSets      *gamedata.CardSets
		fusionLabs    *gamedata.FusionLabs
		mapBonuses    *gamedata.MapBonuses
		drawTable     *gamedata.DrawTable
		tournDefs     *gamedata.Tournaments
		sphereBoards  *gamedata.SphereBoards
		equipPools    *gamedata.EquipmentPools
		conditions    *gamedata.Conditions
	)

	// The client keeps the record store and the arenas in two different
	// directories, so locate them independently rather than demanding a
	// hand-merged folder.
	loc := gamedata.Discover(cfg.DataDir)

	// Fight arenas come from the client's own map files rather than the bdat
	// store, so they load independently: a server without them still runs,
	// falling back to the built-in world 5.
	var fightMaps *gamedata.FightMaps
	if loc.MapsRoot != "" {
		fm, err := gamedata.LoadFightMaps(loc.MapsRoot)
		if err != nil {
			log.Debug("fight maps not loaded; falling back to the built-in arena",
				"dir", loc.MapsRoot, "err", err)
		} else {
			fightMaps = fm
			log.Debug("fight maps loaded", "arenas", fm.Len(),
				"skipped", fm.Skipped(), "unreachableSpecials", fm.UnreachableSpecials())
		}
	}

	if gdStore, err := gamedata.Open(loc.BdatDir); err != nil {
		log.Debug("game data not loaded", "dir", loc.BdatDir, "err", err)
	} else {
		if cards, err = gdStore.LoadCards(); err != nil {
			log.Warn("card load failed", "err", err)
		}
		if spells, err = gdStore.LoadSpells(); err != nil {
			log.Warn("spell load failed", "err", err)
		}
		if fighterCards, err = gdStore.LoadFighterCards(); err != nil {
			log.Warn("fighter-card load failed", "err", err)
		}
		if summonings, err = gdStore.LoadSummonings(); err != nil {
			log.Warn("summoning load failed", "err", err)
		}
		if staticEffects, err = gdStore.LoadStaticEffects(); err != nil {
			log.Warn("static-effect load failed", "err", err)
		}
		if challengeDefs, err = gdStore.LoadChallenges(); err != nil {
			log.Warn("challenge load failed", "err", err)
		}
		if events, err = gdStore.LoadEvents(); err != nil {
			log.Warn("event-card load failed", "err", err)
		}
		if cardSets, err = gdStore.LoadCardSets(); err != nil {
			log.Warn("card-set load failed", "err", err)
		}
		if achievements, err = gdStore.LoadAchievements(); err != nil {
			log.Warn("achievement load failed", "err", err)
		}
		if conditions, err = gdStore.LoadConditions(); err != nil {
			log.Warn("fighter-condition load failed", "err", err)
		}
		if fusionLabs, err = gdStore.LoadFusionLabs(); err != nil {
			log.Warn("fusion-lab load failed", "err", err)
		}
		if mapBonuses, err = gdStore.LoadMapBonuses(); err != nil {
			log.Warn("map-bonus load failed", "err", err)
		}
		// The drop table derives only from the card set, so it can build
		// straight from what LoadCards just produced.
		drawTable = gamedata.NewDrawTable(cards, nil)
		if tournDefs, err = gdStore.LoadTournaments(); err != nil {
			log.Warn("tournament-definition load failed", "err", err)
		}
		if sphereBoards, err = gdStore.LoadSphereBoards(); err != nil {
			log.Warn("sphere-board load failed", "err", err)
		}
		if equipPools, err = gdStore.LoadEquipmentPools(); err != nil {
			log.Warn("equipment-pool load failed", "err", err)
		}
		log.Debug("game data loaded", "cards", cardsLen(cards), "spells", spellsLen(spells),
			"fighterCards", fighterCardsLen(fighterCards), "summonings", summoningsLen(summonings),
			"staticEffects", staticEffectsLen(staticEffects), "challenges", challengeDefs.Len(),
			"eventCards", events.Len(), "cardSets", cardSets.Len(), "achievements", achievements.Len(),
			"conditions", conditions.Len(), "fusionLabs", fusionLabs.Len(), "tournamentDefs", tournDefs.Len(),
			"sphereBoards", sphereBoards.BoardCount(), "spheres", sphereBoards.Len(),
			"equipmentPools", equipPools.Len())
	}

	// Fair pairing: coaches are matched within a strength band that widens the
	// longer they wait (0 disables it). See WorldConfig.MatchBand.
	mm := game.NewMatchmaker()
	mm.SetRatingBand(int32(cfg.World.MatchBand), int32(cfg.World.MatchBandGrowth))

	// Tournament registrations are persisted, so restore them before serving:
	// they used to live only in memory and vanish on every restart (B-101).
	var tm *game.TournamentManager
	if st != nil {
		var err error
		if tm, err = game.NewTournamentManagerWithStore(st.Tournaments); err != nil {
			log.Warn("tournament registrations failed to load", "err", err)
		} else if n := tm.Loaded(); n > 0 {
			log.Info("tournament registrations restored", "count", n)
		}
	} else {
		tm = game.NewTournamentManager()
	}

	// Teach the fighter repo where a card may be equipped, so every fighter it
	// hands out already matches what the client's 5-slot inventory will accept.
	// The store cannot import game data itself, so the mapping is injected: a
	// card's record type IS its slot type (vi_1 — weapon 1 … dofus 5, at
	// positions 0-4).
	if st != nil && fighterCards != nil {
		st.Fighters.EquipSlotOf = func(templateID int32) (int16, bool) {
			c := fighterCards.Get(templateID)
			if c == nil || c.Type < 1 || c.Type > 5 {
				return 0, false
			}
			return int16(c.Type) - 1, true
		}
	}

	return &game.Deps{
		Store:          st,
		World:          game.NewRegistry(cfg.World.AoIRadius),
		Rules:          rulesFromConfig(cfg),
		Limits:         limitsFromConfig(cfg),
		Cards:          cards,
		Exchanges:      game.NewExchangeManager(),
		Spells:         spells,
		FighterCards:   fighterCards,
		Summonings:     summonings,
		ChallengeDefs:  challengeDefs,
		FightMaps:      fightMaps,
		Events:         events,
		Achievements:   achievements,
		MapsRoot:       loc.MapsRoot,
		CardSets:       cardSets,
		FusionLabs:     fusionLabs,
		MapBonuses:     mapBonuses,
		DrawTable:      drawTable,
		TournamentDefs: tournDefs,
		SphereBoards:   sphereBoards,
		EquipmentPools: equipPools,
		Conditions:     conditions,
		StaticEffects:  staticEffects,
		Matchmaker:     mm,
		Challenges:     game.NewChallengeManager(),
		Fights:         game.NewFightManager(),
		Sessions:       game.NewSessionRegistry(),
		Tournaments:    tm,
		Log:            log,
	}, loc
}

func parseLevel(s string) slog.Level {
	switch strings.ToLower(s) {
	case "debug":
		return slog.LevelDebug
	case "warn":
		return slog.LevelWarn
	case "error":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}

func arenaCount(deps *game.Deps) int {
	if deps.FightMaps == nil {
		return 0
	}
	return deps.FightMaps.Len()
}

func cardsLen(c *gamedata.Cards) int {
	if c == nil {
		return 0
	}
	return c.Len()
}

func spellsLen(s *gamedata.Spells) int {
	if s == nil {
		return 0
	}
	return s.Len()
}

func fighterCardsLen(c *gamedata.FighterCards) int {
	if c == nil {
		return 0
	}
	return c.Len()
}

func summoningsLen(s *gamedata.Summonings) int {
	if s == nil {
		return 0
	}
	return s.Len()
}

func staticEffectsLen(s *gamedata.StaticEffects) int {
	if s == nil {
		return 0
	}
	return s.Len()
}

// rulesFromConfig maps the invented-number config onto game.Rules, treating 0 as
// "use the built-in default" for each field independently. That way an operator
// can override one number without having to restate the others.
func rulesFromConfig(cfg config.Config) game.Rules {
	r := game.DefaultRules()
	if cfg.Rules.BaseXPPerFight != 0 {
		r.BaseXPPerFight = cfg.Rules.BaseXPPerFight
	}
	if cfg.Rules.StandingWin != 0 {
		r.StandingWin = cfg.Rules.StandingWin
	}
	if cfg.Rules.StandingLoss != 0 {
		r.StandingLoss = cfg.Rules.StandingLoss
	}
	if cfg.Rules.MaxSocialListEntries != 0 {
		r.MaxSocialListEntries = cfg.Rules.MaxSocialListEntries
	}
	return r
}

// limitsFromConfig turns the operator's limits block into the game package's
// Limits. Every knob is 0-means-default / negative-means-disabled, resolved by
// the config accessors so the policy lives in one place.
func limitsFromConfig(cfg config.Config) game.Limits {
	l := cfg.Limits
	return game.Limits{
		MaxConns:                 l.MaxConns(),
		MaxConnsPerIP:            l.MaxConnsPerIP(),
		HandshakeTimeout:         time.Duration(l.HandshakeTimeout()) * time.Second,
		IdleTimeout:              time.Duration(l.IdleTimeout()) * time.Second,
		LoginRatePerMin:          l.LoginRatePerMinute(),
		DisableAutoRegister:      !l.AutoRegisterEnabled(),
		DisableFirstAccountAdmin: !l.FirstAccountAdmin(),
	}
}
