package game

import (
	"errors"
	"time"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/handshake"
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store"
)

// startWorldID is the world the client loads on entering the overworld
// (the i16 "world" field of ENTER_WORLD_INSTANCE / opcode 4600). The retail
// client streams gfx/tplg/env from contents/maps/{gfx,tplg,env}/<worldID>.jar
// and worlds.lib registers ids 5..113 (NO world 0).
//
// The island-map panel ("carte de l'île", i18n key showMap) is 100% CLIENT-LOCAL
// and keyed off THIS worldId (see docs/OVERWORLD-MAP.md, "Island map"): it renders
// the island NAME (i18n content.61.<id>) and PICTURE (GUI theme style
// containerMap<id> -> map<id>.dds) only for worlds that ship BOTH. That
// intersection is exactly 23..28 — Maknala, Sturbia, Venivici, du Passage,
// Fourmagnet, Magmara. World 85 (the Gostof island we used before) has NEITHER,
// so its island map rendered blank with "!content.61.85!".
//
// We spawn on world 25 (Venivici / "Île de Veniviki"): its chunk 0_0 topology is
// fully populated (~1.4 KB, solid land at the origin — unlike world 23 whose 0_0
// is 187 B of ocean), so the island map renders AND the coach spawns on walkable
// ground at a simple near-origin cell. (The map's "you are here" dot stays hidden
// on every world because 2.70's config.properties omits fullMapPath — a
// client-side limitation, not fixable server-side.)
//
// NOTE: the scripted intro cutscene ("Aïe ! Aïe aïe !" / "Hey ! Toi là bas !")
// is NOT a static world — it is Lua scenario 0/1/99 (scripts/scenario/*.lua)
// run on a dynamic instance, triggered by a scenario/zone-trigger message the
// server does not yet implement. See docs/OVERWORLD-MAP.md.
const startWorldID int16 = 25

// startCellX/startCellY place the coach on world 25's Zaap cell (40,-20) — the
// island's teleporter (see internal/game/zaap.go) — so the coach arrives right at
// the Zaap it can travel from. It is a walkable cell (the Zaap element sits on
// it). Both the render (ENTER_WORLD_INSTANCE) and the server-side coach position
// are set here so movement works from the spawn.
const (
	startCellX float32 = 40
	startCellY float32 = -20
)

func registerConnectionHandlers(r *Router, d *Deps) {
	r.Register(protocol.OpClientVersion, handleClientVersion)
	r.Register(protocol.OpPing, handlePing)
	r.Register(protocol.OpClientAuthentication, handleAuthentication)
	r.Register(protocol.OpCoachCreation, handleCoachCreation)
}

func handleClientVersion(s *Session, f *protocol.C2SFrame) error {
	cv, err := handshake.DecodeClientVersion(f.Payload)
	if err != nil {
		return err
	}
	s.log.Info("client version", "version", cv.Version, "build", cv.Build)
	if !cv.Accepted() {
		// Tell the client its version is wrong and let it self-disconnect (it shows
		// a modal and closes the socket on opcode 8), instead of silently letting an
		// unsupported build proceed to auth. Sent through the normal write queue.
		s.log.Warn("rejecting unsupported client version",
			"version", cv.Version, "expected", protocol.VersionMinor)
		frame, err := handshake.EncodeInvalidClientVersion(protocol.VersionMajor, protocol.VersionMinor)
		if err != nil {
			return err
		}
		return s.Send(frame)
	}
	return nil
}

// handlePing answers the client's keepalive. After auth the client sends TWO
// 107s roughly every 60s (one per "channel", flag 1 and 2) and credits its
// connection-health counter for each 108 it decodes back; if a round goes
// uncredited it logs "Too high ping detected: Server reply number is low". The
// debug line here makes that round-trip observable.
func handlePing(s *Session, f *protocol.C2SFrame) error {
	ping, err := handshake.DecodePing(f.Payload)
	if err != nil {
		s.log.Warn("ping decode failed", "arch", f.Arch, "len", len(f.Payload), "err", err)
		return err
	}
	now := nowNanos()
	reply, err := handshake.EncodePingReply(ping, now, now, now)
	if err != nil {
		return err
	}
	s.log.Debug("ping", "flag", ping.Flag, "key", ping.Key, "replyBytes", len(reply))
	return s.Send(reply)
}

// handleAuthentication verifies credentials (auto-creating an account on first
// login for convenience), then either prompts for coach creation (no coach) or
// runs the full login into the world (existing coach).
func handleAuthentication(s *Session, f *protocol.C2SFrame) error {
	auth, err := handshake.DecodeClientAuthentication(f.Payload)
	if err != nil {
		return err
	}
	s.log.Info("auth attempt", "login", auth.Login)

	// SECURITY: throttle before touching bcrypt.
	//
	// Both branches below cost a bcrypt hash - CreateAccount generates one,
	// VerifyPassword compares one - at ~50-100 ms each, synchronously on this
	// goroutine. Unthrottled, a few dozen sockets spamming 1025 saturated every
	// core, which was the cheapest full-server DoS left. It also means password
	// guessing had no limit at all.
	//
	// The client's own AuthInvalidLogin is used for the refusal: it is the exact
	// case the client already renders, and it does not tell an attacker whether
	// the login exists.
	if !s.allowLoginAttempt() {
		s.log.Warn("login rate limit hit", "ip", s.remoteIP, "login", auth.Login)
		result, _ := handshake.EncodeAuthResult(protocol.AuthInvalidLogin)
		_ = s.Send(result)
		return nil
	}

	// SECURITY: one authentication per socket.
	//
	// This had no already-authenticated guard, so a single socket could loop 1025
	// forever. Each pass added a Sessions registry key WITHOUT removing the
	// previous one (onClose removes only the last account), and overwrote s.Coach
	// without removing the previous coach from the world registry - so both
	// registries leaked an entry per attempt, permanently. Registry.byID is
	// iterated under a global mutex on every movement packet, so poisoning it also
	// slowed every player down.
	if s.Account != nil {
		s.log.Warn("repeat authentication refused", "account", s.Account.ID)
		result, _ := handshake.EncodeAuthResult(protocol.AuthInvalidLogin)
		_ = s.Send(result)
		return nil
	}

	acc, err := s.deps.Store.Accounts.FindByName(auth.Login)
	if errors.Is(err, store.ErrNotFound) {
		// Auto-register on first login (dev convenience). The very first
		// account on a fresh server becomes the administrator, so a brand new
		// install always has someone who can run GM commands and open the web
		// portal's admin console; everybody after that is an ordinary player.
		//
		// This used to grant admin to *every* auto-created account, and the
		// branch below used to promote every existing account on login. That
		// made is_admin meaningless as a privilege check — which was harmless
		// while it only gated chat commands, but the web portal now hangs
		// account deletion and impersonation off the same flag.
		// SECURITY: auto-registration is now opt-out. On the GAME socket it lets
		// anyone mint unlimited accounts, each costing a bcrypt hash and a row,
		// and it is not covered by web.registration_enabled. It defaults ON to
		// preserve local workflows; a public instance should turn it off and use
		// the portal or cmd/seedaccount.
		if s.guard != nil && !s.guard.limits.AutoRegisterAllowed() {
			s.log.Warn("auto-registration disabled; refusing unknown login", "login", auth.Login)
			result, _ := handshake.EncodeAuthResult(protocol.AuthInvalidLogin)
			_ = s.Send(result)
			return nil
		}
		// SECURITY: "first account becomes admin" is a race an attacker can win on
		// a fresh public instance - whoever connects first is administrator, and
		// handlers_gm.go gates every GM verb on exactly that flag. Also opt-out.
		first := false
		if s.guard == nil || s.guard.limits.FirstAccountAdminAllowed() {
			if n, cErr := s.deps.Store.Accounts.Count(); cErr != nil {
				s.log.Error("account count failed", "err", cErr)
			} else {
				first = n == 0
			}
		}
		acc, err = s.deps.Store.Accounts.CreateAccount(auth.Login, auth.Password, first)
		if err != nil {
			return err
		}
		s.log.Info("account auto-created", "login", auth.Login, "admin", first)
	} else if err != nil {
		return err
	} else if !s.deps.Store.Accounts.VerifyPassword(acc, auth.Password) {
		result, _ := handshake.EncodeAuthResult(protocol.AuthInvalidLogin)
		_ = s.Send(result)
		return nil
	}

	// Kick any existing live session for this account (reconnect / dup login),
	// last-writer-wins. This avoids locking a player out when they reconnect
	// after a network drop before the old socket timed out.
	if old := s.deps.Sessions.Swap(acc.ID, s); old != nil {
		s.log.Info("kicking previous session", "login", acc.Name)
		old.kick()
	}

	s.Account = acc
	_ = s.deps.Store.Accounts.SetConnected(acc.ID, true)

	result, err := handshake.EncodeAuthResult(protocol.AuthOK)
	if err != nil {
		return err
	}
	if err := s.Send(result); err != nil {
		return err
	}

	if acc.CoachID == nil {
		// No coach yet -> prompt creation.
		req, err := handshake.EncodeCoachCreationRequest()
		if err != nil {
			return err
		}
		s.log.Info("no coach, prompting creation", "login", auth.Login)
		return s.Send(req)
	}

	coach, err := s.deps.Store.Coaches.Get(*acc.CoachID)
	if err != nil {
		return err
	}
	return s.completeLogin(coach)
}

// handleCoachCreation persists a newly created coach then runs the full login.
func handleCoachCreation(s *Session, f *protocol.C2SFrame) error {
	if s.Account == nil {
		return errors.New("coach creation before auth")
	}
	req, err := handshake.DecodeCoachCreation(f.Payload)
	if err != nil {
		return err
	}
	s.log.Info("coach creation", "name", req.Name)

	// SECURITY: validate server-side. The retail client checks this in
	// aBC.validateCoachCreationForm, but a modified client simply does not, and
	// the store applied only TrimSpace - so an empty, markup-bearing or
	// invisible-character name was accepted. The client's own error string for
	// this case, error.coachCreation.invalidName, reads "Nom de coach invalide ou
	// deja utilise", so code 11 correctly covers an invalid name as well as a
	// taken one; no invented server prose is needed.
	name, ok := validateCoachName(req.Name)
	if !ok {
		s.log.Warn("rejected coach name", "account", s.Account.ID, "len", len(req.Name))
		res, _ := handshake.EncodeCoachCreationResult(coachNameTaken)
		return s.Send(res)
	}

	// SECURITY: one coach per account. handleCoachCreation checked only that the
	// account was authenticated, so a hostile client could replay 2049 forever -
	// each call created another coach row, re-pointed the account at it, and ran
	// completeLogin, which grants starter cards + wallet to each fresh coach.
	// Unbounded storage growth and bulk name-squatting from a single account.
	// NOTE: check s.Coach FIRST. CoachRepo.Create writes accounts.coach_id in the
	// database but does not update the in-memory Account, so testing only
	// s.Account.CoachID silently never fires - the replay guard looked correct and
	// did nothing until an end-to-end test caught it.
	if s.Coach != nil || (s.Account.CoachID != nil && *s.Account.CoachID != 0) {
		s.log.Warn("coach creation refused: account already has a coach",
			"account", s.Account.ID)
		res, _ := handshake.EncodeCoachCreationResult(coachNameTaken)
		return s.Send(res)
	}

	coach, err := s.deps.Store.Coaches.Create(s.Account.ID, name, req.HairColor, req.SkinColor, req.Sex)
	if errors.Is(err, store.ErrNameTaken) {
		res, _ := handshake.EncodeCoachCreationResult(coachNameTaken)
		return s.Send(res)
	}
	if err != nil {
		return err
	}

	// Keep the in-memory Account in step with the row CoachRepo.Create just
	// updated, so the replay guard above sees it even if s.Coach were reset.
	if s.Account != nil {
		id := coach.ID
		s.Account.CoachID = &id
	}

	res, err := handshake.EncodeCoachCreationResult(protocol.AuthOK)
	if err != nil {
		return err
	}
	if err := s.Send(res); err != nil {
		return err
	}
	return s.completeLogin(coach)
}

// coach-creation result codes (client: 0=ok, 10/11/12/13=errors).
const coachNameTaken uint8 = 11

// completeLogin runs the shared post-auth sequence: attach coach, send
// info + social lists + stats, register online, enter world, spawn fan-out.
func (s *Session) completeLogin(coach *domain.Coach) error {
	s.Coach = coach
	s.currentWorld = startWorldID
	s.playSince = time.Now() // lifetime play counter; banked in onClose
	s.grantStarterCards(coach)
	s.grantZaapCards(coach)
	s.grantStarterWallet(coach)

	// Align the coach's in-memory position with the rendered spawn cell so the
	// ENTER_WORLD_INSTANCE render, the World registry (enterWorld), and
	// movement validation all agree — otherwise the client renders at the start
	// cell while the server tracks the coach elsewhere and moves desync.
	//
	// Spawn on the start world's primary Zaap: it is a known-walkable cell, its
	// ground altitude is known (the 4600 `alt` must equal it or the client's
	// pathfinder can't move the coach — see zaapElement.alt), and the coach starts
	// on a teleporter it can travel from.
	spawnX, spawnY, spawnZ := float32(startCellX), float32(startCellY), coach.PosZ
	if z, ok := primaryZaap(startWorldID); ok {
		spawnX, spawnY, spawnZ = float32(z.cellX), float32(z.cellY), z.alt
	}
	coach.PosX, coach.PosY, coach.PosZ = int32(spawnX), int32(spawnY), spawnZ

	// Fold whatever the coach holds into the tome BEFORE the descriptor is built,
	// so the client's grimoire matches the server's on this very login rather
	// than one login behind. Grow-only, so this never takes a card away.
	tome, err := s.deps.Store.Coaches.SyncTome(coach.ID, ownedTemplates(coach))
	if err != nil {
		s.log.Warn("sync tome", "coach", coach.Name, "err", err)
	}
	tomeIDs := make([]int32, 0, len(tome))
	for id := range tome {
		tomeIDs = append(tomeIDs, id)
	}

	sends := [](func() ([]byte, error)){
		func() ([]byte, error) { return buildCoachInformation(coach, tomeIDs, s.deps.guildMembership(coach.ID)) },
		func() ([]byte, error) { return buildFriendList(coach, s.deps.World) },
		func() ([]byte, error) { return buildIgnoreList(coach) },
		func() ([]byte, error) { return buildPlayerStatisticsReport(coach) },
	}
	for _, build := range sends {
		frame, err := build()
		if err != nil {
			return err
		}
		if err := s.Send(frame); err != nil {
			return err
		}
	}
	if err := s.sendEnterOverworld(spawnX, spawnY, spawnZ, startWorldID); err != nil {
		return err
	}

	// Push the clan-tag part-table (554) so every coach the client already
	// knows gets its clan label without a per-observer lookup — the login-time
	// snapshot `broadcastGuildTag` keeps live afterwards.
	if err := s.deps.pushGuildTags(s); err != nil {
		return err
	}

	// Push the coach's card inventory (separate from the 2052 blob).
	if err := s.pushInventory(coach); err != nil {
		return err
	}
	// Push the coach's token wallet (4001 full sync) so the shop UI shows a
	// balance.
	if wallet, err := buildWalletUpdate(coach.Wallet); err == nil {
		if err := s.Send(wallet); err != nil {
			return err
		}
	}
	// Push the coach's fighter roster.
	if err := s.pushFighterList(); err != nil {
		return err
	}
	// Push the coach's saved team presets.
	if err := s.pushTeamPresetList(); err != nil {
		return err
	}
	// Push the lifetime statistics report (2401). Failure is logged, not
	// returned: a stats panel is not worth refusing a login over.
	if err := s.sendPlayerStatistics(); err != nil {
		s.log.Warn("push statistics", "coach", coach.Name, "err", err)
	}

	return s.enterWorld(coach)
}

// enterWorld registers the coach online and exchanges ACTOR_SPAWN lists so all
// overworld coaches see each other.
func (s *Session) enterWorld(coach *domain.Coach) error {
	online := &Online{Coach: coach, Session: s}
	if !s.deps.World.Add(online) {
		// Already present: this is the same coach logging in again, and the
		// previous session's socket is dead or about to be. Take the entry over
		// instead of refusing, otherwise THIS session is invisible for its whole
		// life while every world-scoped delivery goes to the old socket.
		if s.deps.World.TakeOver(online) {
			s.log.Info("world entry taken over by newer session", "coach_id", coach.ID)
		} else {
			s.log.Warn("coach already online and take-over failed", "coach_id", coach.ID)
			return nil
		}
	}

	// AoI seed: spawn in-range coaches to the joiner, and the joiner to them,
	// establishing the bilateral known sets. O(neighbors), not O(N).
	spawnToJoiner, joinerView, spawnJoinerTo := s.deps.World.EnterAoI(coach.ID)
	if len(spawnToJoiner) > 0 {
		if frame, err := buildActorSpawn(spawnToJoiner); err == nil {
			_ = s.Send(frame)
		}
	}
	if len(spawnJoinerTo) > 0 {
		if frame, err := buildActorSpawn([]CoachView{joinerView}); err == nil {
			for _, sess := range spawnJoinerTo {
				_ = sess.Send(frame)
			}
		}
	}
	// Push online notifications to friends/ignorers who are watching this coach.
	s.notifyPresence(coach, true)

	// If this coach dropped out of a fight that is still open (within its reconnect
	// grace), offer to RESUME it: push the reconnect QUESTION (26333) while the
	// coach is in the lobby. The client answers with 26334 (see
	// handleReconnectFightAnswer) — accept replays the fight, decline forfeits. The
	// grace timer keeps running, so a coach who never answers still forfeits.
	if f := s.deps.Fights.ByCoach(coach.ID); f != nil {
		cid := coach.ID
		sess := s
		f.Post(func(f *Fight) {
			if m := f.memberOfCoach(cid); m != nil && m.Absent {
				if frame, err := buildReconnectFightQuestion(); err == nil {
					_ = sess.Send(frame)
				}
			}
		})
	}

	// Evaluate on entry as well as on each criteria change. This is what
	// self-heals a coach whose criteria were earned before the evaluator existed,
	// or through a path that does not (yet) call it — and it costs one read when
	// there is nothing new.
	s.evaluateAchievements()

	s.log.Info("entered world", "coach", coach.Name, "id", coach.ID)
	return nil
}
