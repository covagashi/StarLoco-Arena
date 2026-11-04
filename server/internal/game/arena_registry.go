package game

import (
	"math/rand"
	"sort"
	"sync"
)

// The server plays the prototype's six arenas, embedded in the binary (see
// gamedata.LoadFightMaps). Each has its own shape, start cells and special
// cells, so a Fight carries the arena it is being played on rather than the
// whole package sharing one.
//
// A bare Deps (a unit test) has an empty registry, and everything falls back
// to the hand-decoded world 5, which is why practiceArena still exists.

// arenaRegistry is the arenas one server plays on. It lives on Deps rather than
// in package globals: with globals, the first server in a process to load the
// map files switched every other server in that process off the fallback, which
// is exactly what parallel e2e servers with and without game data did (S08).
// The zero value is the empty registry (fallback only).
type arenaRegistry struct {
	mu    sync.RWMutex
	cache map[uint16]*arena
	ids   []uint16 // sorted, for deterministic random selection
	// release are the arenas new fights are drawn on: the prototype's own
	// (gamedata.FightMaps.Release), or every arena when there are none.
	release []uint16
}

// initArenas converts every decoded fight map into an arena. Safe to call once at
// start-up; a nil or empty set leaves the fallback in place.
func (d *Deps) initArenas() {
	if d == nil || d.FightMaps == nil || d.FightMaps.Len() == 0 {
		return
	}
	r := &d.arenas
	r.mu.Lock()
	defer r.mu.Unlock()
	r.cache = make(map[uint16]*arena, d.FightMaps.Len())
	r.ids = r.ids[:0]
	for _, id := range d.FightMaps.IDs() {
		m := d.FightMaps.Get(id)
		if m == nil {
			continue
		}
		a := newArenaFromMap(m)
		r.cache[a.worldID] = a
		r.ids = append(r.ids, a.worldID)
	}
	sort.Slice(r.ids, func(i, j int) bool { return r.ids[i] < r.ids[j] })
	r.release = r.release[:0]
	for _, id := range d.FightMaps.Release() {
		if r.cache[uint16(id)] != nil {
			r.release = append(r.release, uint16(id))
		}
	}
	if len(r.release) == 0 {
		r.release = append(r.release, r.ids...)
	}
}

// arenaByID returns the arena for a world id. An unknown id (an old ghost's
// arena that is no longer played) gets the first release arena, or the
// fallback when none is loaded.
func (d *Deps) arenaByID(id uint16) *arena {
	if d == nil {
		return &practiceArena
	}
	d.arenas.mu.RLock()
	defer d.arenas.mu.RUnlock()
	if a := d.arenas.cache[id]; a != nil {
		return a
	}
	if len(d.arenas.release) > 0 {
		return d.arenas.cache[d.arenas.release[0]]
	}
	return &practiceArena
}

// pickArena chooses an arena for a new fight. With map data loaded this rotates
// over the release arenas (the prototype's six, S36), so fights are not all
// played on world 5.
func (d *Deps) pickArena() *arena { return d.pickArenaSeating(1) }

// pickArenaSeating chooses an arena that can seat at least n coaches PER SIDE.
//
// Not every arena seats two a side: of the prototype's six, only arenas 3, 4
// and 5 (worlds 12, 15, 21) do. If none qualifies the choice is widened rather
// than failed - a fight on a pedestal-less map still plays correctly, the
// coaches simply have no avatar (buildActorAppearForFight skips them).
func (d *Deps) pickArenaSeating(n int) *arena {
	if d == nil {
		return &practiceArena
	}
	r := &d.arenas
	r.mu.RLock()
	defer r.mu.RUnlock()
	if len(r.release) == 0 {
		return &practiceArena
	}
	if n > 1 {
		eligible := make([]*arena, 0, len(r.release))
		for _, id := range r.release {
			if a := r.cache[id]; a != nil && a.coachCapacity() >= n {
				eligible = append(eligible, a)
			}
		}
		if len(eligible) > 0 {
			return eligible[rand.Intn(len(eligible))]
		}
	}
	return r.cache[r.release[rand.Intn(len(r.release))]]
}

// loadedArenaCount reports how many arenas the registry holds (0 = fallback only).
func (d *Deps) loadedArenaCount() int {
	if d == nil {
		return 0
	}
	d.arenas.mu.RLock()
	defer d.arenas.mu.RUnlock()
	return len(d.arenas.ids)
}

// hasArena reports whether a world id is a loaded arena (not the fallback).
func (d *Deps) hasArena(id uint16) bool {
	if d == nil {
		return false
	}
	d.arenas.mu.RLock()
	defer d.arenas.mu.RUnlock()
	return d.arenas.cache[id] != nil
}
