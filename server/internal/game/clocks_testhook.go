package game

import "time"

// clocks_testhook.go exposes the fight phase/turn clocks so an OUT-OF-PACKAGE test
// (the e2e wire suite) can shrink them. It is not used by the server binary.
//
// Why this exists: the production turn clock is 30s, but the e2e fight tests wait
// only 15s for a fighter's turn. That makes a missed window a GUARANTEED failure
// rather than a slow pass — if a test does not act inside its turn, the next
// FIGHTER_TURN_BEGIN cannot arrive until the 30s clock expires. On a loaded
// machine that turned the three full-fight tests into rotating false alarms, which
// is worse than useless: a suite that cries wolf gets ignored, and it nearly
// masked a real regression during the breed-initiative work.
//
// Shrinking the turn clock makes a missed window cost seconds instead of half a
// minute, so the tests measure BEHAVIOUR rather than machine load.

// SetTurnClockForTest overrides the per-fighter turn clock and returns a function
// that restores the previous value. Intended for tests only.
func SetTurnClockForTest(d time.Duration) (restore func()) {
	prev := turnClock
	turnClock = d
	return func() { turnClock = prev }
}

// SetAITurnClockForTest shortens how long an AI turn lingers. The e2e package
// sets it once in TestMain (it is a package global, like the turn clock): an
// AI-vs-AI ghost fight runs ~90 turns, which at the production 1.2 s made
// that one test take three minutes.
func SetAITurnClockForTest(d time.Duration) (restore func()) {
	prev := aiTurnClock
	aiTurnClock = d
	return func() { aiTurnClock = prev }
}
