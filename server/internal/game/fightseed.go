package game

import (
	crand "crypto/rand"
	"encoding/binary"
	"math/rand"
	"time"
)

// fightseed.go makes a fight's dice reproducible.
//
// Every roll a fight makes — damage dice, crit/fumble, tackle, the event-card
// shuffle, the post-fight wound/morale/tiredness draws — comes from the single
// *rand.Rand returned by rngSource(). That stream used to be seeded from
// time.Now(), which made a fight a one-off: nothing could re-derive what it
// rolled. Seeding it from a seed STORED ON THE FIGHT instead means the same
// seed plus the same inputs replays the same fight, which is what server-side
// verification, replays and balance debugging all need.
//
// The seed lives on the Fight and nowhere else: fights are in-memory only (the
// FightManager is the whole fight store — there is no fight row to migrate), so
// storing it needed no schema change. It is deliberately NOT on the wire: a
// client that knew the seed could foresee its own crits.

// newFightSeed draws a fresh dice seed. It is unpredictable on purpose —
// crypto/rand, not the clock and not a counter — because the seed is the only
// thing standing between a modified client and knowing every roll of its fight
// in advance. Always non-zero: 0 is the "no seed assigned yet" sentinel.
func newFightSeed() int64 {
	var b [8]byte
	if _, err := crand.Read(b[:]); err == nil {
		// >>1 keeps the value non-negative, which keeps logged seeds readable and
		// round-trippable through anything that prints them.
		if v := int64(binary.BigEndian.Uint64(b[:]) >> 1); v != 0 {
			return v
		}
	}
	// crypto/rand failing is close to impossible; fall back to the clock rather
	// than refusing to start the fight. |1 keeps it non-zero.
	return (time.Now().UnixNano() >> 1) | 1
}

// Seed returns the fight's stored dice seed, or 0 if it has not been assigned
// one yet (a Fight built directly, before its first roll).
func (f *Fight) Seed() int64 {
	if f == nil {
		return 0
	}
	return f.seed
}

// SetSeed stores an explicit dice seed and discards any RNG already derived
// from the previous one, so the next roll comes from the new seed. Call it
// BEFORE the fight rolls anything — replaying a fight means setting its seed at
// creation, not part-way through.
func (f *Fight) SetSeed(seed int64) {
	if f == nil {
		return
	}
	f.seed = seed
	f.rng = nil
}

// rngSource returns the fight's damage/dice RNG, deriving it from the stored
// fight seed on first use. Tests may set f.rng beforehand for deterministic
// rolls; setting f.seed (or SetSeed) does the same thing through the stored
// seed, which is what the real fight paths use.
func (f *Fight) rngSource() *rand.Rand {
	if f.rng == nil {
		if f.seed == 0 {
			// A fight that never went through FightManager.Create (a unit test, a
			// scripted scenario) still gets a seed, so there is always one value
			// that reproduces the rolls it is about to make.
			f.seed = newFightSeed()
		}
		f.rng = rand.New(rand.NewSource(f.seed))
	}
	return f.rng
}
