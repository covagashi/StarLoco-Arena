package game

import (
	"testing"
	"time"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// turnModeFrames drains a session's queue and returns the 8250 payloads.
func turnModeFrames(s *Session) [][]byte {
	var out [][]byte
	for {
		select {
		case fr := <-s.out:
			if len(fr) >= 4 && int(fr[2])<<8|int(fr[3]) == protocol.OpTurnDuration {
				out = append(out, fr[4:])
			}
		default:
			return out
		}
	}
}

// The penalty end to end, as the client's adu_0 / aez_0.eN compute it: a
// minute of idle turns reduces the coach's turns (8250 normal=0), the next
// own turn gets half and every one after a sixth, a summon's turn half
// without moving it on, and the first combat action restores them (8250
// normal=1).
func TestIdleCoachGetsShorterTurns(t *testing.T) {
	f := buildTestFight()
	sess := &Session{log: testLogger(), out: make(chan []byte, writeQueueSize), quit: make(chan struct{})}
	f.Teams[0].Members[0].Session = sess
	ff := f.Teams[0].Fighters[0]
	summon := &FightFighter{WireID: ff.WireID + 1, CoachID: ff.CoachID, TeamID: 0, Father: ff, HP: 10}
	base := f.turnClockFor()

	f.noteIdleTurn(ff, base) // 30 s: not yet
	if got := f.humanTurnClock(ff); got != base {
		t.Fatalf("after 30 s idle the clock is %v, want %v", got, base)
	}
	f.noteIdleTurn(ff, base) // a minute: reduced
	frames := turnModeFrames(sess)
	if len(frames) != 1 || len(frames[0]) != 9 || frames[0][8] != 0 {
		t.Fatalf("8250 frames after a minute idle = %x, want one [coach][0]", frames)
	}
	if got := f.humanTurnClock(summon); got != base/2 {
		t.Errorf("a summon's turn = %v, want half (%v)", got, base/2)
	}
	if got := f.humanTurnClock(ff); got != base/2 {
		t.Errorf("first reduced turn = %v, want half (%v)", got, base/2)
	}
	if got := f.humanTurnClock(ff); got != base/6 {
		t.Errorf("next reduced turn = %v, want a sixth (%v)", got, base/6)
	}
	f.noteIdleTurn(ff, base/6) // more idling sends nothing new
	if frames := turnModeFrames(sess); len(frames) != 0 {
		t.Errorf("a second 8250 while already reduced: %x", frames)
	}

	f.noteCombatAction(ff)
	frames = turnModeFrames(sess)
	if len(frames) != 1 || frames[0][8] != 1 {
		t.Fatalf("8250 frames after acting = %x, want one [coach][1]", frames)
	}
	if got := f.humanTurnClock(ff); got != base {
		t.Errorf("restored clock = %v, want %v", got, base)
	}
	// Acting also clears the idle time: one more idle turn is not a minute.
	f.noteIdleTurn(ff, base)
	if got := f.humanTurnClock(ff); got != base {
		t.Errorf("one idle turn after acting reduced the clock to %v", got)
	}
}

// Through the real clock: a coach that lets its turns run out with no action
// has its turns reduced.
func TestIdleTurnsThroughTheClock(t *testing.T) {
	defer restoreClocks(presentationClock, placementClock, observationClock, turnClock)
	defer func(d time.Duration) { idleBeforePenalty = d }(idleBeforePenalty)
	turnClock = 40 * time.Millisecond
	idleBeforePenalty = 80 * time.Millisecond // two idle turns, as a minute is at 30 s
	f := buildTestFight()
	f.deps = &Deps{Fights: NewFightManager(), Log: testLogger()}
	for _, t := range f.Teams { // coach-played sides, not AI ones
		t.Members[0].Session = &Session{log: testLogger(), out: make(chan []byte, writeQueueSize),
			quit: make(chan struct{})}
	}
	idler := f.Timeline[0]
	f.startActor()
	defer func() { f.stopActor(); f.waitStopped() }()
	f.setPhase(PhaseAction)
	f.Post(func(f *Fight) { f.beginTurn(idler) })

	mode := func() int {
		got := make(chan int, 1)
		f.Post(func(f *Fight) { got <- f.memberOfCoach(idler.CoachID).turnMode })
		select {
		case m := <-got:
			return m
		case <-time.After(200 * time.Millisecond):
			return -1
		}
	}
	deadline := time.Now().Add(3 * time.Second)
	for mode() < turnModeReduced {
		if time.Now().After(deadline) {
			t.Fatal("the idle coach's turns were never reduced")
		}
		time.Sleep(5 * time.Millisecond)
	}
}

// 22093 (use a title card) is answered 3212 "Todavía no está operativo".
func TestTitleCardIsAnsweredNotYetImplemented(t *testing.T) {
	s := &Session{log: testLogger(), out: make(chan []byte, 4), quit: make(chan struct{}),
		Coach: &domain.Coach{ID: 1}}
	if err := handleUseTitleCard(s, &protocol.C2SFrame{Payload: []byte{0, 0, 0, 207}}); err != nil {
		t.Fatal(err)
	}
	select {
	case fr := <-s.out:
		if op := int(fr[2])<<8 | int(fr[3]); op != protocol.OpChatErrNotImplemented || len(fr) != 4 {
			t.Errorf("answer = opcode %d, %d bytes; want an empty 3212", op, len(fr))
		}
	default:
		t.Error("no answer to 22093")
	}
}
