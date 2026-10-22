package game

import (
	"time"

	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// turn_penalty.go is the retail answer to a coach who stops playing without
// leaving: "No has realizado ninguna acción de combate desde hace más de un
// minuto … Por ahora, se reducirá la duración de tus turnos"
// (cheat.turnDuration.decreased).
//
// The client already does its half. 8250 [i64 coachId][u8 normal] sets the
// coach's turn mode (of_1 → aez_0.nw: 1 normal, 2 reduced), and its turn
// timer is the fight's turn clock divided by aez_0.eN(isSummon) (adu_0.f):
// in mode 2 the next turn of one of the coach's own fighters gets half, and
// that turn moves the mode to 6, so every turn after it gets a sixth; a
// summon's turn reads 2 without moving it. 8250 with normal = 1 puts it back.
// The server owns the trigger and the clock that actually ends the turn,
// which must match what the client shows.

// idleBeforePenalty is the client text's "más de un minuto" (a var so tests
// can shorten it).
var idleBeforePenalty = time.Minute

// Turn modes, as aez_0.dBh holds them.
const (
	turnModeNormal  = 1
	turnModeReduced = 2 // the first reduced turn: half
	turnModeSixth   = 6 // every one after it
)

// turnDivisor is aez_0.eN for the coach that owns ff: what its turn clock is
// divided by, advancing a fresh penalty from half to a sixth exactly when the
// client does.
func (m *FightMember) turnDivisor(ff *FightFighter) time.Duration {
	switch m.turnMode {
	case turnModeReduced:
		if !ff.isSummon() {
			m.turnMode = turnModeSixth
		}
		return turnModeReduced
	case turnModeSixth:
		return turnModeSixth
	}
	return turnModeNormal
}

// humanTurnClock is the clock for a coach-played turn of ff.
func (f *Fight) humanTurnClock(ff *FightFighter) time.Duration {
	clock := f.turnClockFor()
	if m := f.memberOfCoach(ff.CoachID); m != nil {
		clock /= m.turnDivisor(ff)
	}
	return clock
}

// noteIdleTurn adds a coach-played turn that ran out its clock with no action
// to its owner's idle time, and reduces the coach's turns once that passes a
// minute.
func (f *Fight) noteIdleTurn(ff *FightFighter, clock time.Duration) {
	m := f.memberOfCoach(ff.CoachID)
	if m == nil || m.Coach == nil || m.turnMode != turnModeNormal && m.turnMode != 0 {
		return
	}
	m.idle += clock
	if m.idle < idleBeforePenalty {
		return
	}
	m.turnMode = turnModeReduced
	f.broadcastTurnMode(m.Coach.ID, false)
	f.logfDebug("turn duration reduced (idle)", "fight", f.ID, "coach", m.Coach.ID, "idle", m.idle)
}

// noteCombatAction clears the coach's idle time and, if its turns were
// reduced, puts them back.
func (f *Fight) noteCombatAction(ff *FightFighter) {
	if ff == nil {
		return
	}
	m := f.memberOfCoach(ff.CoachID)
	if m == nil || m.Coach == nil {
		return
	}
	m.idle = 0
	if m.turnMode == turnModeReduced || m.turnMode == turnModeSixth {
		m.turnMode = turnModeNormal
		f.broadcastTurnMode(m.Coach.ID, true)
	}
}

// broadcastTurnMode sends 8250 (client wc_2): [i64 coachId][u8 normal].
func (f *Fight) broadcastTurnMode(coachID uint, normal bool) {
	w := protocol.NewWriter().I64(int64(coachID)).U8(boolByte(normal))
	if frame, err := protocol.EncodeS2C(protocol.OpTurnDuration, w.Bytes()); err == nil {
		f.broadcast(frame)
	}
}
