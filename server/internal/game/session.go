package game

import (
	"bufio"
	"errors"
	"io"
	"log/slog"
	"net"
	"runtime/debug"
	"sync"
	"time"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// Session is one client connection and its game state.
type Session struct {
	conn   net.Conn
	r      *bufio.Reader
	log    *slog.Logger
	router *Router
	deps   *Deps

	// guard/remoteIP support the connection + login-rate limits. guard is nil in
	// tests that build a Session directly, so every use must nil-check.
	guard    *connGuard
	remoteIP string
	// gmArena pins this session's practice fights to one arena (/ARENA, admin
	// only); 0 = the usual random pick. It exists so the live smokes play on a
	// known map instead of whichever of the 47 comes up (S08).
	gmArena uint16
	// tournamentCountdowns remembers which 28644 countdowns this client already
	// holds (tournament -> period start): `zN` adds one row per message with no
	// duplicate guard, so re-opening the calendar used to stack them.
	tournamentCountdowns map[int64]int64
	// opcodes throttles the handful of opcodes that are expensive to serve or
	// push something at another player. See opcode_gate.go.
	opcodes *opcodeGate

	out       chan []byte   // async write queue (bounded; decouples broadcasters from slow clients)
	quit      chan struct{} // closed when the session is shutting down
	closeOnce sync.Once

	Account *domain.Account
	Coach   *domain.Coach

	// currentWorld is the overworld the coach is currently loaded into (the i16
	// world id last sent in ENTER_INSTANCE / 4600). Tracked in-memory so the
	// instance-ready ack (4517) can re-spawn that world's interactive elements
	// (Zaaps). Set on login and on Zaap teleport.
	currentWorld int16
	// fusionLabID is the lab-definition id of the fusion altar the coach last
	// opened (its 201), 0 if none. 5490 names no altar; see fusionLab.
	fusionLabID int32

	// chat is this session's chat rate state (trade cooldown + anti-repeat),
	// mirroring the client's own gates so a modified client cannot skip them.
	// Touched only by this session's goroutine, so it needs no lock.
	chat chatGate
	// spawnedElements tracks which interactive elements this client currently
	// holds, so refreshWorldElements can send only the delta. Reset on world
	// change - see resetSpawnedElements.
	spawnedElements map[int64]bool

	// spectating is the fight this session is watching as a spectator (nil = none).
	// Touched ONLY by this session's own goroutine (set on spectate-join, cleared
	// on fight-end ack or disconnect), so it needs no lock; the fight actor owns
	// the reciprocal f.spectators slice.
	spectating *Fight
	// playSince is when this coach entered the world; the gap up to disconnect is
	// added to Coach.TotalPlaySecs. Zero once credited, so it counts once.
	// Touched only by this session's own goroutine.
	playSince time.Time
}

// writeQueueSize bounds a session's pending outbound frames. A client that
// can't drain this fast enough is treated as dead and kicked, so one slow
// client never stalls a broadcast to everyone else.
const writeQueueSize = 256

// kick force-closes the session (used when a newer login replaces it). Closing
// quit stops the writer + unblocks Send; closing the conn unblocks the reader.
func (s *Session) kick() {
	s.closeOnce.Do(func() {
		close(s.quit)
		_ = s.conn.Close()
	})
}

func newSession(conn net.Conn, router *Router, deps *Deps) *Session {
	return &Session{
		conn:    conn,
		r:       bufio.NewReader(conn),
		log:     deps.Log.With("remote", conn.RemoteAddr().String()),
		router:  router,
		deps:    deps,
		out:     make(chan []byte, writeQueueSize),
		opcodes: newOpcodeGate(),
		quit:    make(chan struct{}),
	}
}

// Send enqueues a fully-framed S2C message for async delivery. Non-blocking:
// if the client's queue is full (it isn't reading fast enough), the session is
// kicked rather than blocking the caller (a broadcaster or the fight actor).
// This backpressure guard is the key to broadcast fan-out at scale. The `quit`
// select arm prevents a send-on-closed panic after teardown.
func (s *Session) Send(frame []byte) error {
	select {
	case <-s.quit:
		return net.ErrClosed
	default:
	}
	select {
	case s.out <- frame:
		return nil
	case <-s.quit:
		return net.ErrClosed
	default:
		s.log.Warn("write queue full, kicking slow client")
		s.kick()
		return net.ErrClosed
	}
}

// writeLoop drains the outbound queue to the socket, coalescing bursts through a
// buffered writer (a broadcast of many small frames becomes few syscalls).
func (s *Session) writeLoop() {
	bw := bufio.NewWriterSize(s.conn, 8192)
	for {
		select {
		case frame := <-s.out:
			if _, err := bw.Write(frame); err != nil {
				s.kick()
				return
			}
			// Flush when momentarily drained (batches bursts, keeps latency low).
			if len(s.out) == 0 {
				if err := bw.Flush(); err != nil {
					s.kick()
					return
				}
			}
		case <-s.quit:
			return
		}
	}
}

// serve reads and dispatches frames until the connection closes.
func (s *Session) serve() {
	defer s.onClose()
	s.log.Info("client connected")

	// Dedicated writer goroutine (async, backpressure-safe).
	go s.writeLoop()

	for {
		// SECURITY: bound how long a socket may sit silent.
		//
		// Before authentication the window is short (handshake timeout) - that is
		// what evicts a connect-and-say-nothing flood, which was previously free
		// and unbounded. After authentication it is generous, because a player can
		// legitimately idle in the world; the retail client pings well inside it.
		//
		// The deadline is set on the CONN, not the bufio.Reader, so it applies to
		// the actual socket read that the reader performs when its buffer drains.
		s.applyReadDeadline()

		frame, err := protocol.ReadC2S(s.r)
		if err != nil {
			if errors.Is(err, io.EOF) {
				s.log.Info("client disconnected")
			} else {
				s.log.Warn("read error", "err", err)
			}
			return
		}
		if err := s.dispatchSafely(frame); err != nil {
			s.log.Warn("dispatch error", "opcode", frame.Opcode, "err", err)
			return
		}
	}
}

// creditPlayTime adds this session's time in the world to the coach's lifetime
// play counter, which the client's 2400 statistics panel and the web portal both
// show.
//
// It only touches the in-memory Coach; persisting is left to whoever saves it
// next. That matters for the replaced-session case below: the incoming session
// owns the coach and will save it on its own disconnect, carrying this session's
// time with it.
//
// Time is therefore lost if the server dies without a clean teardown. Crediting
// periodically would fix that, but at the cost of a timer per session for a
// cosmetic statistic — the trade is deliberate.
func (s *Session) creditPlayTime() {
	if s.Coach == nil || s.playSince.IsZero() {
		return
	}
	secs := int64(time.Since(s.playSince) / time.Second)
	s.playSince = time.Time{} // credit at most once
	if secs <= 0 {
		return
	}
	s.Coach.Mu.Lock()
	s.Coach.TotalPlaySecs += secs
	s.Coach.Mu.Unlock()
}

// onClose handles connection teardown: deregister from world, clear connected.
func (s *Session) onClose() {
	s.kick() // idempotent: ensures quit is closed + writer stops

	// Before anything else, and in particular before the replaced-session return
	// below: the time was really played whether or not this session still owns
	// the coach.
	s.creditPlayTime()

	// If a newer login already replaced this session (kick/reconnect), do NOT
	// tear down the shared account/coach state -- the new session owns it now.
	//
	// SECURITY: this early return used to skip EVERYTHING below, which leaked the
	// coach into every subsystem on every duplicate login. handleAuthentication
	// calls Sessions.Swap BEFORE old.kick(), so Remove always returns false here -
	// this path is deterministic, not a race. The leaks that mattered:
	//
	//   - Matchmaker: the queue kept a searcher holding a DEAD socket. Real
	//     players were paired with ghosts, sendMatchFound went nowhere, and the
	//     fight started blind. Repeatable at will, so the queue could be
	//     saturated with unreachable opponents.
	//   - Challenges / exchanges / 2v2: the counterparty was left waiting on
	//     someone who was gone, and an exchange kept the OTHER player marked busy
	//     so they could not trade with anyone else.
	//
	// releaseSubsystems is therefore run for replaced sessions too. What stays
	// skipped is deliberate: the world entry (the new session took it over), the
	// coach save (the new session owns the struct) and the fight teardown (the
	// new session should be able to reconnect into it).
	if s.Account != nil {
		if !s.deps.Sessions.Remove(s.Account.ID, s) {
			s.log.Info("stale session closed (replaced by newer login)")
			s.releaseSubsystems()
			return
		}
	}

	if s.Coach != nil {
		// Mid-fight disconnect: keep the fight alive (reconnect-ready) and start the
		// grace period rather than destroying it — the leaver's team auto-passes and
		// forfeits if it doesn't return; a practice fight is torn down. The fight
		// actor may persist stats for this coach concurrently; CoachRepo.Save + the
		// actor both take Coach.Mu, so the two saves are serialized (no struct race).
		if f := s.deps.Fights.ByCoach(s.Coach.ID); f != nil {
			s.deps.coachLeftFight(f, s.Coach.ID)
		}
		// Matchmaking, challenges, exchanges, 2v2 and spectating all release
		// through the SAME helper the replaced-session path uses, so the two
		// cannot drift apart again.
		s.releaseSubsystems()

		// Despawn the leaver from coaches that currently see it (AoI known set),
		// then remove it from the registry.
		viewers := s.deps.World.LeaveAoI(s.Coach.ID)
		// Only if the entry is still OURS: a newer login may already have taken
		// it over, and removing it then would make the live player vanish.
		s.deps.World.RemoveIfSession(s.Coach.ID, s)
		// Persist the coach's final position/stats so they survive reconnect.
		// Coach.Mu (taken inside Save) serializes this with any concurrent
		// fight-actor stat save.
		if err := s.deps.Store.Coaches.Save(s.Coach); err != nil {
			s.log.Warn("save coach on disconnect", "err", err)
		}
		if frame, err := buildActorDespawn([]uint{s.Coach.ID}); err == nil {
			for _, other := range viewers {
				_ = other.Send(frame)
			}
		}
		// Push offline notifications to friends/ignorers watching this coach.
		s.notifyPresence(s.Coach, false)
	}
	if s.Account != nil {
		_ = s.deps.Store.Accounts.SetConnected(s.Account.ID, false)
	}
}

// errPanicInHandler is returned when a handler panicked. It ends the offending
// session but leaves the server, and everyone else's fights, running.
var errPanicInHandler = errors.New("handler panicked")

// dispatchSafely runs a handler and converts a panic into an error.
//
// SECURITY: this is the blast-radius control for the whole server. Go terminates
// the entire process on an unrecovered panic in ANY goroutine, so before this
// existed a single malformed or hostile frame that reached a nil dereference took
// down every logged-in player and every fight in progress - not just the sender.
// Two such crashes were reachable from three packets (the matchmaker and
// challenge ghost-coach bugs; see searcherCoachID and sessionCoachID).
//
// Those root causes are fixed, but the class is not: this file cannot know what a
// future handler will dereference. The stack trace is logged with the opcode so a
// crash is still loud and diagnosable - the goal is containment, not silence.
//
// Note this deliberately does NOT keep the session alive. A handler that panicked
// left its coach in an unknown state, and continuing to serve it risks acting on
// corrupt data; the caller drops the connection on any error.
func (s *Session) dispatchSafely(f *protocol.C2SFrame) (err error) {
	// SECURITY: per-opcode budget, applied before the handler runs so an
	// over-budget packet costs nothing but the parse. Dropping silently is
	// deliberate: these opcodes have no "you are going too fast" reply, the
	// retail client never reaches the budget, and answering would itself be a
	// broadcast the attacker controls.
	if s.opcodes != nil && !s.opcodes.allow(f.Opcode) {
		s.log.Debug("opcode throttled", "opcode", f.Opcode, "coach", coachID(s))
		return nil
	}
	defer func() {
		if r := recover(); r != nil {
			s.log.Error("PANIC in handler - session dropped, server survives",
				"opcode", f.Opcode,
				"payload_len", len(f.Payload),
				"panic", r,
				"stack", string(debug.Stack()))
			err = errPanicInHandler
		}
	}()
	return s.router.Dispatch(s, f)
}

// releaseSubsystems drops this session from every matchmaking/social structure
// that holds a pointer to it, notifying counterparties. Safe to call twice.
//
// It exists because the same release has to happen on TWO paths that used to
// share no code: a normal disconnect, and a session displaced by a newer login.
// Only the first ran it, so every duplicate login leaked a ghost.
//
// It deliberately does NOT touch the world registry, the coach row or any fight:
// on the replaced-session path those belong to the new session.
func (s *Session) releaseSubsystems() {
	if s.deps == nil {
		return
	}
	if s.Coach == nil {
		// SECURITY: 27529 (destroy coach) nils Coach while the socket stays up,
		// so a coachless session can still hold queue and challenge entries. The
		// managers now purge nil-coach entries themselves (searcherCoachID,
		// sessionCoachID), which is what stops those from being crashes; there is
		// simply no id left here to release by.
		return
	}
	coachID := s.Coach.ID

	// NOTE: the in-progress FIGHT is deliberately not released here.
	//
	// The three callers want different things. A normal disconnect starts a
	// reconnect grace period (onClose does that itself, just above its call to
	// this helper). A session replaced by a newer login must keep its fight intact
	// so the new session can reconnect into it. Only handleDestroyCoach wants the
	// fight torn down, and it does that itself - putting it here instead would
	// double-release on disconnect and would void a fight the reconnecting player
	// is still entitled to.
	//
	// Spectating: detach from whatever fight was being watched.
	if f := s.spectating; f != nil {
		s.spectating = nil
		sess := s
		f.Post(func(f *Fight) { f.removeSpectator(sess) })
	}
	// Matchmaking (queue or pending); tell a matched opponent it fell through.
	if s.deps.Matchmaker != nil {
		if pm := s.deps.Matchmaker.Remove(coachID); pm != nil {
			if other := pm.other(coachID); other != nil {
				_ = sendMatchCancelled(other.session)
			}
		}
	}
	// Pending direct challenge.
	if s.deps.Challenges != nil {
		if c := s.deps.Challenges.Remove(coachID); c != nil {
			if other := c.other(coachID); other != nil {
				if frame, err := buildChallengeCancelled(c.id); err == nil {
					_ = other.Send(frame)
				}
			}
		}
	}
	// In-progress exchange: without this the OTHER party stays marked busy and
	// cannot trade with anyone until they reconnect.
	if s.deps.Exchanges != nil {
		if ex := s.deps.Exchanges.Get(coachID); ex != nil {
			other := ex.Other(coachID)
			if s.deps.Exchanges.Remove(ex) && other != nil {
				if end, err := buildExchangeEnd(ex.ID, protocol.ExchangeEndCancel); err == nil {
					_ = other.Send(end)
				}
			}
		}
	}
	// 2v2 pairing, notifying the partner. (A method on *Deps, so no nil check -
	// the guards above are for the manager FIELDS, which tests may leave unset.)
	s.deps.releaseTeamUpAndNotify(coachID)
}

// applyReadDeadline sets the socket read deadline appropriate to this session's
// stage: a short handshake window while unauthenticated, a long idle window once
// logged in. A zero limit disables the deadline entirely.
func (s *Session) applyReadDeadline() {
	if s.guard == nil {
		return
	}
	d := s.guard.limits.IdleTimeout
	if s.Account == nil {
		d = s.guard.limits.HandshakeTimeout
	}
	if d <= 0 {
		_ = s.conn.SetReadDeadline(time.Time{})
		return
	}
	_ = s.conn.SetReadDeadline(time.Now().Add(d))
}

// allowLoginAttempt reports whether this session may attempt an authentication
// right now. Each attempt costs a bcrypt hash on this goroutine, so an
// unthrottled 1025 was a CPU-exhaustion primitive against the whole server.
func (s *Session) allowLoginAttempt() bool {
	if s.guard == nil {
		return true
	}
	return s.guard.allowLogin(s.remoteIP)
}

// rosterLocked reports whether this coach may not currently edit its roster or
// fighter loadouts: while queued for a fight, holding a pending match, or already
// in one. See Matchmaker.IsBusyMatchmaking for why.
//
// It answers with the retail error code (69) the client already renders, so the
// player sees "Action impossible pendant une recherche de combat" rather than
// silence.
func (s *Session) rosterLocked() bool {
	if s.Coach == nil || s.deps == nil {
		return false
	}
	if s.deps.Matchmaker != nil && s.deps.Matchmaker.IsBusyMatchmaking(s.Coach.ID) {
		return true
	}
	if s.deps.Fights != nil && s.deps.Fights.ByCoach(s.Coach.ID) != nil {
		return true
	}
	return false
}

// refuseRosterEdit tells the client why an edit was rejected.
func (s *Session) refuseRosterEdit(what string) error {
	s.log.Info("roster edit refused: busy matchmaking or in a fight",
		"coach", s.Coach.ID, "what", what)
	return s.sendFightCreationError(protocol.FightErrMatchfinderOccuring)
}
