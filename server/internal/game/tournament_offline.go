package game

import (
	"bytes"
	"compress/gzip"
	"encoding/binary"
	"encoding/json"
	"time"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// Offline tournaments (S29, owner 2026-10-25: "torneos sin conexión: que juegue
// la IA"). A classic tournament no longer needs its entrants online: each one
// fields its most recent ghost (a frozen Elite team with its rules, S12/S13),
// and when registration closes the server plays the whole bracket AI against
// AI, round by round, recording every fixture. The entrants watch them later
// as replays (60032-60035), and finishTournament pays the winner as before.
//
// The fights run synchronously on the scheduler's goroutine — no actor, no
// clocks, no FightManager entry — the way determinism_test.go plays one, so
// a fixture takes milliseconds and no real coach id is ever inside a fight
// (every player-facing handler looks fights up by coach id). Both sides are
// synthetic coaches; checkFightEnd sees f.offline and only records the winner.
//
// Evolution and graveyard tournaments stay live: they field the Historia
// line-up, whose fighters tire, get hurt and die.

// offlineCoachID is side B's synthetic coach in an offline fixture (side A
// reuses ghostCoachID); recorderCoachID owns the recording spectator.
const (
	offlineCoachID  uint = 1<<31 + 3
	recorderCoachID uint = 1<<31 + 4
)

// offlineRoundCap ends a fixture that is still going after this many rounds:
// the side with more of its total HP left wins. Sudden death starts at round
// 15 (suddendeath.go) but cannot force a kill.
const offlineRoundCap = 40

// Recording timing: the client plays frames at their recorded time (capped
// at 1.5 s per gap), so the virtual clock sets the pace of the replay.
const (
	offlineFrameMS   = 350
	offlineOpeningMS = 2500
)

// regNeedsGhost is the 28608 code for "a classic tournament needs a ghost".
const regNeedsGhost uint8 = 3

type offlineFight struct {
	winner int8 // -1 until decided
	rec    *fightRecorder
}

// hasGhost reports whether the coach has a ghost an offline tournament can
// field.
func (s *Session) hasGhost() bool {
	if s.Coach == nil || s.deps.Store == nil {
		return false
	}
	g, err := s.deps.Store.Ghosts.LatestByCoach(s.Coach.ID)
	return err == nil && g != nil
}

// tournamentOffline reports whether a tournament is played by the server.
func (d *Deps) tournamentOffline(t *domain.Tournament) bool {
	if !d.OfflineTournaments || d.TournamentDefs == nil || t == nil {
		return false
	}
	def := d.TournamentDefs.Get(int16(t.DefID))
	return def != nil && def.TeamType == gamedata.TournamentTeamClassic
}

// playOfflineTournament plays every pending fixture, round after round, until
// the bracket has a winner or nothing is left to play. Idempotent: only
// fixtures whose parent slot is empty are played.
func (d *Deps) playOfflineTournament(t *domain.Tournament) {
	tid := t.WireID()
	for round := 0; round < 8; round++ {
		fixtures := d.Tournaments.PendingFixtures(tid)
		if len(fixtures) == 0 {
			return
		}
		for _, fx := range fixtures {
			d.playOfflineFixture(t, fx)
		}
	}
}

func (d *Deps) playOfflineFixture(t *domain.Tournament, fx Fixture) {
	tid := t.WireID()
	ga, _ := d.Store.Ghosts.LatestByCoach(fx.A)
	gb, _ := d.Store.Ghosts.LatestByCoach(fx.B)
	var winner, loser uint
	var m *domain.TournamentMatch
	switch {
	case ga == nil && gb == nil:
		// Nobody to field on either side (both deleted their ghosts): the
		// lower seed goes through, so the bracket can still finish.
		winner, loser = fx.A, fx.B
	case ga == nil:
		winner, loser = fx.B, fx.A
	case gb == nil:
		winner, loser = fx.A, fx.B
	default:
		var err error
		m, err = d.runOfflineMatch(ga, gb, d.coachName(fx.A), d.coachName(fx.B))
		if err != nil || m == nil {
			d.Log.Warn("offline fixture", "tournament", tid, "slot", fx.Slot, "err", err)
			winner, loser = fx.A, fx.B
			m = nil
		} else if m.WinnerCoachID == 0 {
			winner, loser = fx.A, fx.B
		} else {
			winner, loser = fx.B, fx.A
		}
	}
	landed := d.Tournaments.RecordMatchResult(tid, winner, loser)
	if landed == 0 {
		d.Log.Warn("offline fixture did not fit the bracket", "tournament", tid, "slot", fx.Slot)
		return
	}
	if m != nil {
		m.TournamentWireID, m.Slot = tid, fx.Slot/2
		m.WinnerCoachID, m.LoserCoachID = winner, loser
		m.WinnerName, m.LoserName = d.coachName(winner), d.coachName(loser)
		if err := d.Store.Tournaments.SaveMatch(m); err != nil {
			d.Log.Warn("offline fixture: save", "tournament", tid, "err", err)
		}
	}
	d.Log.Info("offline fixture played", "tournament", tid, "slot", fx.Slot/2,
		"winner", winner, "loser", loser, "recorded", m != nil)
	if landed == bracketWinnerSlot {
		d.awardTournamentPrize(tid, winner, d.sessionForCoach(winner))
	}
}

// runOfflineMatch plays ghost a (side 0) against ghost b (side 1) to the end
// and returns the match: WinnerCoachID is 0 when side 0 won, 1 when side 1
// did (the caller maps it to the real coaches), with the recording.
func (d *Deps) runOfflineMatch(a, b *domain.GhostTeam, nameA, nameB string) (*domain.TournamentMatch, error) {
	seed := newFightSeed()
	ar := d.arenaFromSeed(seed)
	teamA, err := d.buildGhostTeam(0, ar.startCells(0), a)
	if err != nil {
		return nil, err
	}
	teamB, err := d.buildGhostTeam(1, ar.startCells(1), b)
	if err != nil {
		return nil, err
	}
	// Side B gets its own synthetic coach (both ghost teams would otherwise
	// share ghostCoachID), and both carry their owners' names for the replay.
	teamB.Members[0].Coach = &domain.Coach{ID: offlineCoachID, Name: nameB}
	for _, ff := range teamB.Fighters {
		ff.CoachID = offlineCoachID
		ff.WireID += 1 << 20 // the same ghost on both sides must not share wire ids
	}
	if nameA != "" {
		teamA.Members[0].Coach.Name = nameA
	}
	f := &Fight{
		arena:        ar,
		Practice:     true,
		Teams:        [2]*FightTeam{teamA, teamB},
		deps:         d,
		readyPresent: map[uint]bool{}, readyObserve: map[uint]bool{}, readyAction: map[uint]bool{},
		offline: &offlineFight{winner: -1},
	}
	f.SetSeed(seed)
	f.Timeline = buildTimeline(f)
	rec := newFightRecorder(d)
	f.offline.rec = rec
	f.spectators = append(f.spectators, rec.sess)

	// The opening a joining spectator would see, then the phase cues.
	if create, err := buildCreateFight(f, nil, true); err == nil {
		rec.add(create)
	}
	if appear, err := buildActorAppearForFight(f); err == nil {
		rec.add(appear)
	}
	if present, err := buildEmpty(protocol.OpStartPresentation); err == nil {
		rec.add(present)
	}
	rec.clock += offlineOpeningMS
	f.setPhase(PhasePresentation)
	f.advanceToPlacement()
	f.advanceToObservation()
	f.advanceToAction() // starts turn 1
	rec.drain()

	for f.Phase() == PhaseAction && f.tableTurn <= offlineRoundCap {
		cur := f.currentFighter()
		if cur == nil {
			break
		}
		f.runAITurn(cur)
		rec.drain()
	}
	if f.Phase() == PhaseAction {
		w := offlineHPLeader(f)
		f.decidedWinner = &w
		d.checkFightEnd(f)
		rec.drain()
	}
	f.stopClock()
	if f.offline.winner < 0 {
		return nil, nil
	}
	replay, err := rec.encode(map[string]any{
		"version":     1,
		"recorded_at": time.Now().Unix(),
		"coach_id":    0,
		"coach_name":  "",
		"spectating":  true,
		"world":       ar.worldID,
		"fight_type":  1,
		"fight_id":    0,
		"left":        []string{nameA},
		"right":       []string{nameB},
		"result":      "none",
		"complete":    true,
		"tournament":  true,
	})
	if err != nil {
		return nil, err
	}
	return &domain.TournamentMatch{
		WinnerCoachID: uint(f.offline.winner), // 0 or 1, the side
		Seed:          seed, Rounds: f.tableTurn, Replay: replay,
	}, nil
}

// offlineHPLeader is the side with the larger share of its HP left.
func offlineHPLeader(f *Fight) uint8 {
	var hp, max [2]int64
	for _, ff := range f.allFighters() {
		if ff.TeamID > 1 {
			continue
		}
		if ff.HP > 0 {
			hp[ff.TeamID] += int64(ff.HP)
		}
		max[ff.TeamID] += int64(ff.MaxHP)
	}
	// hp0/max0 >= hp1/max1, cross-multiplied; a tie goes to side 0
	if hp[0]*max[1] >= hp[1]*max[0] {
		return 0
	}
	return 1
}

// endOffline is checkFightEnd for an offline fixture: the result frame for
// the recording, the winner, and the end of the fight.
func (f *Fight) endOffline(winnerTeam uint8) {
	var winners, losers []endFightCoach
	for _, t := range f.Teams {
		for _, mem := range t.Members {
			if mem.Coach == nil {
				continue
			}
			e := endFightCoach{ID: mem.Coach.ID}
			if t.ID == winnerTeam {
				winners = append(winners, e)
			} else {
				losers = append(losers, e)
			}
		}
	}
	if end, err := buildEndFightFull(f.nextActionUID(), winners, losers, nil, 0, 0, 0, nil); err == nil {
		f.broadcastSpectators(end)
	}
	f.offline.winner = int8(winnerTeam)
	f.setPhase(PhaseEnded)
}

// fightRecorder is a spectator that writes down what it is sent, with a
// virtual clock, in the client's replay layout.
type fightRecorder struct {
	sess   *Session
	clock  uint32
	frames [][]byte // [u32 t][u16 op][u32 len][payload]
}

func newFightRecorder(d *Deps) *fightRecorder {
	return &fightRecorder{sess: &Session{
		log: d.Log, deps: d, out: make(chan []byte, writeQueueSize),
		quit:  make(chan struct{}),
		Coach: &domain.Coach{ID: recorderCoachID, Name: "replay"},
	}}
}

// add records one server frame ([u16 len][u16 op][payload]).
func (r *fightRecorder) add(frame []byte) {
	if len(frame) < 4 {
		return
	}
	op := binary.BigEndian.Uint16(frame[2:4])
	payload := frame[4:]
	var b bytes.Buffer
	_ = binary.Write(&b, binary.BigEndian, r.clock)
	_ = binary.Write(&b, binary.BigEndian, op)
	_ = binary.Write(&b, binary.BigEndian, uint32(len(payload)))
	b.Write(payload)
	r.frames = append(r.frames, b.Bytes())
	r.clock += offlineFrameMS
}

// drain records everything the spectator session has been sent.
func (r *fightRecorder) drain() {
	for {
		select {
		case frame := <-r.sess.out:
			r.add(frame)
		default:
			return
		}
	}
}

// encode is the gzipped replay: "SLRP" [u8 version][u32 header len][header
// JSON] then the frames (godot/src/net/replay_file.gd).
func (r *fightRecorder) encode(header map[string]any) ([]byte, error) {
	header["frames"] = len(r.frames)
	header["duration_ms"] = r.clock
	head, err := json.Marshal(header)
	if err != nil {
		return nil, err
	}
	var raw bytes.Buffer
	raw.WriteString("SLRP")
	raw.WriteByte(1)
	_ = binary.Write(&raw, binary.BigEndian, uint32(len(head)))
	raw.Write(head)
	for _, fr := range r.frames {
		raw.Write(fr)
	}
	var gz bytes.Buffer
	zw := gzip.NewWriter(&gz)
	if _, err := zw.Write(raw.Bytes()); err != nil {
		return nil, err
	}
	if err := zw.Close(); err != nil {
		return nil, err
	}
	return gz.Bytes(), nil
}

// replayChunk is how many recording bytes one 60035 carries.
const replayChunk = 60000

func registerOfflineTournamentHandlers(r *Router, _ *Deps) {
	r.Register(protocol.OpTournMatchesRequest, handleTournMatchesRequest)
	r.Register(protocol.OpTournReplayRequest, handleTournReplayRequest)
}

// handleTournMatchesRequest (60032 → 60033) lists a tournament's recorded
// fixtures. Like the bracket, the results are public to any coach.
func handleTournMatchesRequest(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil || s.deps.Store == nil {
		return nil
	}
	tid, err := protocol.NewReader(f.Payload).I64()
	if err != nil {
		return err
	}
	ms, err := s.deps.Store.Tournaments.Matches(tid)
	if err != nil {
		return err
	}
	if len(ms) > 255 {
		ms = ms[:255]
	}
	w := protocol.NewWriter().I64(tid).U8(uint8(len(ms)))
	for _, m := range ms {
		w.I32(m.Slot).StringU8UTF8(m.WinnerName).StringU8UTF8(m.LoserName).I32(m.Rounds)
	}
	frame, err := protocol.EncodeS2C(protocol.OpTournMatches, w.Bytes())
	if err != nil {
		return err
	}
	return s.Send(frame)
}

// handleTournReplayRequest (60034 → 60035 × n) sends one recording.
func handleTournReplayRequest(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil || s.deps.Store == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	tid, err := r.I64()
	if err != nil {
		return err
	}
	slot, err := r.I32()
	if err != nil {
		return err
	}
	m, err := s.deps.Store.Tournaments.Match(tid, slot)
	if err != nil || m == nil || len(m.Replay) == 0 {
		return err
	}
	count := (len(m.Replay) + replayChunk - 1) / replayChunk
	if count > 0xFFFF {
		return nil
	}
	for i := 0; i < count; i++ {
		end := (i + 1) * replayChunk
		if end > len(m.Replay) {
			end = len(m.Replay)
		}
		w := protocol.NewWriter().I64(tid).I32(slot).U16(uint16(i)).U16(uint16(count))
		w.Raw(m.Replay[i*replayChunk : end])
		frame, err := protocol.EncodeS2C(protocol.OpTournReplayChunk, w.Bytes())
		if err != nil {
			return err
		}
		if err := s.Send(frame); err != nil {
			return err
		}
	}
	return nil
}
