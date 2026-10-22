package game

import (
	"sort"
	"sync"
	"time"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// Tournaments in 2.70 are scheduled events. The tournament totem (or the calendar
// menu button) opens a window that fires two empty requests — the calendar (17002)
// and the tournament list (28601) — and the server answers with the events (17003)
// and the registerable tournaments (28602). Clicking "register" sends 4607, which
// we accept with 28608; the bracket button sends 28649, answered by an empty tree
// (28650).
//
// Each row is an edition with a schedule (see domain.Tournament): registration
// until the first search period, then one bracket round per period, settled by
// forfeit when a period closes, and finished by the scheduler
// (tournament_schedule.go) once there is a winner or the last period is over.
// A row with no schedule keeps the older standing behaviour: always open,
// never finishing.
//
// The line-up lives in the database (domain.Tournament) and is edited from the web
// admin console, so changing it no longer needs a rebuild. A fresh database is
// seeded with the three that used to be compiled in.
//
// Each tournament references a REAL client definition id (a data.bdat type-1000
// `aub` record; the retail client ships 22 of them, ids {1,4..24}). The client's
// list/detail/register code dereferences that definition unguarded, so a row whose
// defId is not one of those 22 would NPE the client, and only definitions whose
// inscription card is 0 can ever complete registration here. Both rules are
// enforced where tournaments are created — see internal/web's validateTournament,
// which checks them against the decoded catalogue before anything reaches a player.

// tournamentWindow is how long a standing tournament stays on the calendar / open
// for registration, measured from "now" at request time.
const tournamentWindow = 7 * 24 * time.Hour

// tournamentContentTypeID is the client content id whose prototype decodes a
// tournament calendar entry (data.bdat type-700 record id 4 -> class qr_0). A 17003
// entry must lead with a registered content id or the client's awa_0 decoder NPEs.
const tournamentContentTypeID int32 = 4

// coachStatus values carried by a 28602 row (client enum, lower = deeper round):
// -128 means "not registered" (the register button stays eligible); 0..3 are
// qualified phases. We report a freshly registered coach as "first round".
const (
	tournamentCoachNotRegistered int8 = -128
	tournamentCoachFirstRound    int8 = 3
)

// tournamentRegistrationStore is the slice of the store the manager needs. Kept
// as an interface so the manager can be built without a database (unit tests, and
// any dev run without a store) and so this file does not depend on the store
// package.
type tournamentRegistrationStore interface {
	ListRegistrations() ([]domain.TournamentRegistration, error)
	AddRegistration(coachID uint, tid int64) error
	RemoveRegistration(coachID uint, tid int64) error
	ListSlots() ([]domain.TournamentSlot, error)
	SetSlot(tid int64, slot int32, coachID uint) error
	MarkCarried(coachID uint, tid int64) error
}

// TournamentManager records which coaches have registered for which standing
// tournaments, cached in memory and written through to the store. Thread-safe.
//
// It used to be process-lived only, which meant every restart silently
// un-registered everybody — the player saw themselves signed up, the server
// bounced, and their entry was gone with no message (B-101). Registrations are
// keyed by the tournament's WIRE id, which is derived from its row id and so is
// stable across restarts; that is what makes persisting them meaningful.
//
// The store is optional: with none, the manager behaves exactly as it used to.
type TournamentManager struct {
	mu  sync.Mutex
	reg map[uint]map[int64]bool // coachID -> set of registered tournament wire ids
	// ready holds the one entrant waiting for a match in each tournament. It is
	// process-lived on purpose: a "ready" state is a player sitting in front of a
	// waiting dialog, which cannot survive their disconnection anyway.
	ready map[int64]map[uint]bool // tournament wire id -> coaches waiting for a fixture
	// advanced records who has won through to each bracket slot ABOVE the first
	// round: tournament -> slot -> coach. Written through to the store, and
	// primed from it at boot, so a restart no longer resets every tournament to
	// its first round.
	//
	// Only slots above the first round are kept. The first round is derived from
	// the registrations, so a seeding cannot drift away from who is entered.
	advanced map[int64]map[int32]uint
	// presets is the team preset each waiting coach readied with, so a fixture
	// fields each side's own team rather than the one the second searcher sent.
	presets map[uint]uint16
	// marks is the scheduler's progress per tournament: periods already settled
	// and opened. Process-lived: on a restart the first tick re-derives it from
	// the clock (see periodMarks).
	marks map[int64]tournamentMarks
	// carried holds the entries made by accepting the carry-over (28617):
	// tournament -> coach. They are seeded ahead of new entrants.
	carried map[int64]map[uint]bool
	store   tournamentRegistrationStore
}

// tournamentMarks is how far the scheduler has taken one tournament.
type tournamentMarks struct {
	settled int // search periods closed and settled
	opened  int // search periods announced as open
}

// NewTournamentManager returns an empty, non-persisting registration tracker.
func NewTournamentManager() *TournamentManager {
	return &TournamentManager{reg: make(map[uint]map[int64]bool)}
}

// NewTournamentManagerWithStore returns a tracker primed from the store and
// writing through to it. A load failure is returned rather than swallowed: an
// operator restarting into an empty tournament list should hear about it, not
// discover it from players.
func NewTournamentManagerWithStore(s tournamentRegistrationStore) (*TournamentManager, error) {
	m := &TournamentManager{reg: make(map[uint]map[int64]bool), store: s}
	if s == nil {
		return m, nil
	}
	regs, err := s.ListRegistrations()
	if err != nil {
		return m, err
	}
	for _, r := range regs {
		set := m.reg[r.CoachID]
		if set == nil {
			set = make(map[int64]bool)
			m.reg[r.CoachID] = set
		}
		set[r.TournamentWireID] = true
		if r.Carried {
			m.markCarriedLocked(r.CoachID, r.TournamentWireID)
		}
	}
	// Prime the bracket. A failure here is returned like a registration failure:
	// starting with a silently empty bracket would look exactly like "everyone
	// was knocked back to the first round".
	slots, err := s.ListSlots()
	if err != nil {
		return m, err
	}
	for _, sl := range slots {
		if m.advanced[sl.TournamentWireID] == nil {
			if m.advanced == nil {
				m.advanced = map[int64]map[int32]uint{}
			}
			m.advanced[sl.TournamentWireID] = map[int32]uint{}
		}
		m.advanced[sl.TournamentWireID][sl.Slot] = sl.CoachID
	}
	return m, nil
}

// Loaded reports how many registrations are held, for the startup log.
func (m *TournamentManager) Loaded() int {
	m.mu.Lock()
	defer m.mu.Unlock()
	n := 0
	for _, set := range m.reg {
		n += len(set)
	}
	return n
}

// Register marks coachID as registered for tid. It is idempotent; the return value
// reports whether this call was the one that added the registration.
func (m *TournamentManager) Register(coachID uint, tid int64) bool {
	m.mu.Lock()
	set := m.reg[coachID]
	if set == nil {
		set = make(map[int64]bool)
		m.reg[coachID] = set
	}
	if set[tid] {
		m.mu.Unlock()
		return false
	}
	set[tid] = true
	store := m.store
	m.mu.Unlock()

	// Write through outside the lock: the store call can block, and nothing else
	// needs to observe the registration atomically with its persistence.
	if store != nil {
		_ = store.AddRegistration(coachID, tid)
	}
	return true
}

// RegisterCarried registers a coach that accepted the carry-over into tid.
// Unlike Register it also flags an existing entry, so a coach that had already
// signed up again still gets its seeding priority.
func (m *TournamentManager) RegisterCarried(coachID uint, tid int64) {
	m.Register(coachID, tid)
	m.mu.Lock()
	m.markCarriedLocked(coachID, tid)
	store := m.store
	m.mu.Unlock()
	if store != nil {
		_ = store.MarkCarried(coachID, tid)
	}
}

func (m *TournamentManager) markCarriedLocked(coachID uint, tid int64) {
	if m.carried == nil {
		m.carried = map[int64]map[uint]bool{}
	}
	if m.carried[tid] == nil {
		m.carried[tid] = map[uint]bool{}
	}
	m.carried[tid][coachID] = true
}

// FixturesWon counts the fixtures a coach actually won in a tournament: the
// stored slots above the first round, which only a played fixture or a forfeit
// fills. Byes are derived, never stored, so they do not count.
func (m *TournamentManager) FixturesWon(tid int64, coachID uint) int {
	m.mu.Lock()
	defer m.mu.Unlock()
	n := 0
	for _, c := range m.advanced[tid] {
		if c == coachID {
			n++
		}
	}
	return n
}

// Unregister withdraws coachID from tid. Idempotent; reports whether anything was
// actually removed.
func (m *TournamentManager) Unregister(coachID uint, tid int64) bool {
	m.mu.Lock()
	set := m.reg[coachID]
	if !set[tid] {
		m.mu.Unlock()
		return false
	}
	delete(set, tid)
	if len(set) == 0 {
		delete(m.reg, coachID)
	}
	store := m.store
	m.mu.Unlock()

	if store != nil {
		_ = store.RemoveRegistration(coachID, tid)
	}
	return true
}

// IsRegistered reports whether coachID is registered for tid.
func (m *TournamentManager) IsRegistered(coachID uint, tid int64) bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.reg[coachID][tid]
}

// CountFor returns how many coaches are registered for tid. The web console
// shows it next to each tournament, so an admin can see whether anyone would be
// affected before editing or deleting one.
func (m *TournamentManager) CountFor(tid int64) int {
	m.mu.Lock()
	defer m.mu.Unlock()
	n := 0
	for _, set := range m.reg {
		if set[tid] {
			n++
		}
	}
	return n
}

// EntrantsFor returns the coach ids registered for a tournament, ordered so the
// bracket is stable between requests (the client re-asks on every page turn).
//
// Registration order is not recoverable - the tracker is a set - so ids are
// sorted, which at least guarantees the same seeding every time rather than map
// order shuffling the bracket under the player. Entrants carried over from an
// unfinished edition come first: the draw takes 16, and the carry-over is a
// promise of a place in it.
func (m *TournamentManager) EntrantsFor(tid int64) []uint {
	m.mu.Lock()
	defer m.mu.Unlock()
	var out []uint
	for coachID, set := range m.reg {
		if set[tid] {
			out = append(out, coachID)
		}
	}
	carried := m.carried[tid]
	sort.Slice(out, func(i, j int) bool {
		if carried[out[i]] != carried[out[j]] {
			return carried[out[i]]
		}
		return out[i] < out[j]
	})
	return out
}

// firstRoundSlots maps each entrant to its first-round bracket slot.
//
// Seeding is by sorted coach id (see EntrantsFor): registration ORDER is not
// recoverable from a set, and a stable-but-arbitrary seeding is far better than
// one that reshuffles with Go's map iteration every time the client turns a page.
func (m *TournamentManager) firstRoundSlots(tid int64) map[uint]int32 {
	out := map[uint]int32{}
	for i, coachID := range m.EntrantsFor(tid) {
		if i >= bracketEntrants {
			break
		}
		out[coachID] = int32(bracketFirstRoundSlot + i)
	}
	return out
}

// RecordMatchResult advances the winner of a tournament fixture one round.
//
// The bracket is a binary heap, so the pair in slots 2i / 2i+1 is decided into
// slot i. The two coaches must actually FACE each other - siblings in the tree -
// or the result is ignored. ReadyUp only ever offers a coach its sibling, so
// that should not arise through the queue; it is still checked, because a fight
// can be ended by a GM command and putting a coach in a slot it never played for
// is worse than declining to advance it.
//
// Returns the slot the winner ends up in, which is not always the parent of the
// pair: if the next round is unopposed the bye carries it further, and a caller
// asking "has this decided the tournament?" must see the slot it actually
// reached. 0 means the result did not fit.
func (m *TournamentManager) RecordMatchResult(tid int64, winner, loser uint) int32 {
	slots := m.firstRoundSlots(tid)

	m.mu.Lock()
	defer m.mu.Unlock()
	ws, wok := m.slotOfLocked(tid, winner, slots)
	ls, lok := m.slotOfLocked(tid, loser, slots)
	if !wok || !lok || ws == ls {
		return 0
	}
	// Siblings share a parent: floor(a/2) == floor(b/2), and they must differ.
	if ws/2 != ls/2 {
		return 0
	}
	parent := ws / 2
	if parent < bracketWinnerSlot {
		return 0
	}
	if m.advanced[tid] == nil {
		if m.advanced == nil {
			m.advanced = map[int64]map[int32]uint{}
		}
		m.advanced[tid] = map[int32]uint{}
	}
	m.advanced[tid][parent] = winner
	if m.store != nil {
		// Write through while holding the lock: the in-memory bracket and the
		// stored one must not be able to disagree about who is in a slot.
		if err := m.store.SetSlot(tid, parent, winner); err != nil {
			return parent // the round still stands for this session
		}
	}
	// Re-derive: winning into the parent can expose a bye above it, and the
	// caller needs the slot the winner actually reached - a final decided by a
	// bye is still a tournament win.
	if final, ok := topSlotOf(m.bracketSlotsLocked(tid, slots), winner); ok {
		return final
	}
	return parent
}

// bracketSlotsLocked builds the whole bracket: entrants seeded into the first
// round, everyone who has won through above it, and the byes that follow from a
// short draw. Caller holds mu and supplies the seeding.
//
// Byes are DERIVED here rather than stored, so they always agree with the
// current entrant list: a coach that got a bye because its half of the draw was
// empty stops getting one the moment somebody registers there, with no stored
// slot left behind to contradict the seeding.
func (m *TournamentManager) bracketSlotsLocked(tid int64, first map[uint]int32) map[int32]uint {
	out := make(map[int32]uint, len(first))
	seeded := make(map[int32]bool, len(first))
	for coachID, slot := range first {
		out[slot] = coachID
		seeded[slot] = true
	}
	for slot, coachID := range m.advanced[tid] {
		out[slot] = coachID
	}
	applyByes(out, seeded)
	return out
}

// slotOfLocked finds a coach's current slot: the highest round it has reached,
// counting byes, and falling back to its first-round seat. Caller holds mu.
func (m *TournamentManager) slotOfLocked(tid int64, coachID uint, first map[uint]int32) (int32, bool) {
	return topSlotOf(m.bracketSlotsLocked(tid, first), coachID)
}

// topSlotOf returns the furthest a coach has got up the tree. Lower slot number
// = nearer the root, so the smallest occupied slot wins.
func topSlotOf(slots map[int32]uint, coachID uint) (int32, bool) {
	best := int32(0)
	for slot, c := range slots {
		if c == coachID && (best == 0 || slot < best) {
			best = slot
		}
	}
	return best, best != 0
}

// BracketSlots returns the whole current bracket: entrants in the first round,
// everyone who has won through above it, and any byes.
func (m *TournamentManager) BracketSlots(tid int64) map[int32]uint {
	slots := m.firstRoundSlots(tid)
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.bracketSlotsLocked(tid, slots)
}

// ForfeitResult is one fixture settled because only one side turned up.
type ForfeitResult struct {
	Winner uint
	Loser  uint
	Slot   int32 // the slot the winner took
}

// SettleClosedPeriod advances every undecided fixture in which exactly one side
// was actually searching, and returns what it decided.
//
// This is what lets a tournament progress when the two halves of a fixture are
// never online together: retail's rule is that a search period closes and whoever
// was not looking for an opponent is declared forfeit.
//
// `present` must report whether a coach can really fight right now. Being in the
// ready set is NOT enough on its own: nothing clears that set on disconnect, so
// readying up and then logging off would otherwise be a way to win fixtures while
// absent - the exact behaviour the forfeit rule exists to punish.
//
// Neither side searching decides nothing. There is no fair winner to pick, and
// picking one would hand the tournament to whoever happened to be seeded lower.
//
// Idempotent by construction: it only touches fixtures whose parent slot is still
// empty, so running it again after a period settles is a no-op. That is why no
// "already settled" flag is stored anywhere.
func (m *TournamentManager) SettleClosedPeriod(tid int64, present func(uint) bool) []ForfeitResult {
	if present == nil {
		return nil
	}
	first := m.firstRoundSlots(tid)

	m.mu.Lock()
	defer m.mu.Unlock()
	slots := m.bracketSlotsLocked(tid, first)
	readySet := m.ready[tid]

	var out []ForfeitResult
	// Deepest first, and only from the even side of each pair so a fixture is
	// considered once.
	for slot := int32(bracketSlots) - 2; slot >= 2; slot -= 2 {
		a, okA := slots[slot]
		b, okB := slots[slot^1]
		if !okA || !okB {
			continue // not a contested fixture; an empty side is a bye, not a forfeit
		}
		parent := slot / 2
		if _, decided := slots[parent]; decided {
			continue
		}
		aIn := readySet[a] && present(a)
		bIn := readySet[b] && present(b)
		if aIn == bIn {
			continue
		}
		winner, loser := a, b
		if bIn {
			winner, loser = b, a
		}
		if m.advanced[tid] == nil {
			if m.advanced == nil {
				m.advanced = map[int64]map[int32]uint{}
			}
			m.advanced[tid] = map[int32]uint{}
		}
		m.advanced[tid][parent] = winner
		if m.store != nil {
			if err := m.store.SetSlot(tid, parent, winner); err != nil {
				delete(m.advanced[tid], parent) // do not diverge from the store
				continue
			}
		}
		delete(readySet, a)
		delete(readySet, b)
		// The winner may now ride byes further up; report where it actually landed.
		landed := parent
		if s, ok := topSlotOf(m.bracketSlotsLocked(tid, first), winner); ok {
			landed = s
		}
		out = append(out, ForfeitResult{Winner: winner, Loser: loser, Slot: landed})
	}
	return out
}

// FixtureDecidesTournament reports whether the winner of the pair that decides
// `parent` goes on to win the whole tournament without playing again - that is,
// every round above `parent` is a bye.
//
// "The parent slot is the root" is NOT the same question, and using it instead is
// wrong for every draw that is not exactly full: with four entrants the pair at
// slots 8/9 decides slot 4, and the byes above carry that winner to the root, so
// it IS the final even though its parent is not slot 1.
func (m *TournamentManager) FixtureDecidesTournament(tid int64, parent int32) bool {
	first := m.firstRoundSlots(tid)
	seeded := make(map[int32]bool, len(first))
	for _, s := range first {
		seeded[s] = true
	}
	for slot := parent; slot > bracketWinnerSlot; slot /= 2 {
		lo, hi := firstRoundRange(slot ^ 1)
		for s := lo; s <= hi; s++ {
			if seeded[s] {
				return false // somebody can still arrive to contest this round
			}
		}
	}
	return true
}

// ReadyUp records that a registered entrant is ready to play its next tournament
// match, and returns its opponent once that opponent is ready too.
//
// The opponent is not "whoever else is waiting" - it is the entrant occupying the
// SIBLING slot in the bracket, and nobody else. In a binary heap the pair that
// decides slot i is 2i and 2i+1, so a coach's opponent sits at `slot ^ 1`.
//
// This used to pair any two ready entrants of the tournament. That was safe -
// advanceTournamentBracket refuses to advance a non-sibling result - but it meant
// two players could be sent into a match that advanced neither of them, which is
// worse than waiting: it looks like a tournament fixture and settles nothing.
//
// The caller is expected to have checked IsRegistered; this guards the pairing.
func (m *TournamentManager) ReadyUp(tid int64, coachID uint) (uint, bool) {
	// Computed outside the lock: BracketSlots takes it itself.
	slots := m.BracketSlots(tid)
	mySlot := int32(0)
	for slot, c := range slots {
		if c == coachID && (mySlot == 0 || slot < mySlot) {
			mySlot = slot
		}
	}

	m.mu.Lock()
	defer m.mu.Unlock()
	if m.ready == nil {
		m.ready = make(map[int64]map[uint]bool)
	}
	if m.ready[tid] == nil {
		m.ready[tid] = make(map[uint]bool)
	}
	// No seat in the bracket (not entered, or the draw is full): it can wait, but
	// it can never be anyone's sibling, so it will not be paired.
	if mySlot > bracketWinnerSlot {
		if opponent, ok := slots[mySlot^1]; ok && opponent != coachID && m.ready[tid][opponent] {
			delete(m.ready[tid], opponent)
			delete(m.ready[tid], coachID)
			return opponent, true
		}
	}
	m.ready[tid][coachID] = true
	return 0, false
}

// SetReadyPreset records the preset a coach readied with.
func (m *TournamentManager) SetReadyPreset(coachID uint, preset uint16) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.presets == nil {
		m.presets = map[uint]uint16{}
	}
	m.presets[coachID] = preset
}

// ReadyPreset returns the preset a coach readied with.
func (m *TournamentManager) ReadyPreset(coachID uint) (uint16, bool) {
	m.mu.Lock()
	defer m.mu.Unlock()
	p, ok := m.presets[coachID]
	return p, ok
}

// ClearReady empties one tournament's ready set and returns who was in it: the
// coaches left waiting when a search period closes.
func (m *TournamentManager) ClearReady(tid int64) []uint {
	m.mu.Lock()
	defer m.mu.Unlock()
	var out []uint
	for c := range m.ready[tid] {
		out = append(out, c)
	}
	delete(m.ready, tid)
	sort.Slice(out, func(i, j int) bool { return out[i] < out[j] })
	return out
}

// Forget drops a finished tournament from memory. Its registrations and slots
// stay in the store as the edition's history; the manager only caches what can
// still change.
func (m *TournamentManager) Forget(tid int64) {
	m.mu.Lock()
	defer m.mu.Unlock()
	for coachID, set := range m.reg {
		delete(set, tid)
		if len(set) == 0 {
			delete(m.reg, coachID)
		}
	}
	delete(m.ready, tid)
	delete(m.advanced, tid)
	delete(m.marks, tid)
	delete(m.carried, tid)
}

// periodMarks returns the scheduler's progress for a tournament. The first time
// a tournament is seen, periods already closed count as settled: the ready set
// is process-lived, so after a restart there is nobody to settle them for, and
// settling a closed period with the CURRENT period's searchers would hand out
// forfeits mid-search.
func (m *TournamentManager) periodMarks(tid int64, closedNow int) tournamentMarks {
	m.mu.Lock()
	defer m.mu.Unlock()
	if mk, ok := m.marks[tid]; ok {
		return mk
	}
	mk := tournamentMarks{settled: closedNow, opened: closedNow}
	if m.marks == nil {
		m.marks = map[int64]tournamentMarks{}
	}
	m.marks[tid] = mk
	return mk
}

func (m *TournamentManager) setPeriodMarks(tid int64, mk tournamentMarks) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.marks == nil {
		m.marks = map[int64]tournamentMarks{}
	}
	m.marks[tid] = mk
}

// CancelReady removes a coach from every tournament's ready set.
func (m *TournamentManager) CancelReady(coachID uint) bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	found := false
	for _, set := range m.ready {
		if set[coachID] {
			delete(set, coachID)
			found = true
		}
	}
	return found
}

// buildTournamentCalendar builds TOURNAMENT_CALENDAR (17003 awa_0): the scheduled
// events the tournament window shows on its calendar and under "Tournois du jour".
// Each entry is [i32 typeId=4][qr_0 body]; the body is the shared event base
// (iz_0) + the duration base (th_2) + the tournament fields. The registration-period
// list MUST hold at least one pair: the client's qr_0 reads element 0 of it
// unguarded when rendering the "registration period" label.
func buildTournamentCalendar(ts []domain.Tournament) ([]byte, error) {
	now := time.Now()
	w := protocol.NewWriter().U16(uint16(len(ts))) // [i16 count]
	for i := range ts {
		writeTournamentEvent(w, &ts[i], now)
	}
	return protocol.EncodeS2C(protocol.OpTournamentCalendar, w.Bytes())
}

// writeTournamentEvent appends one [i32 typeId][qr_0 body] calendar entry.
//
// The "Tournois du jour" filter (client vk_1.Cd -> de_2.a) reads the two event
// instants with meanings INVERTED relative to their field names: the iz_0
// "startDate" slot (OV) is really the "runs-until / not-yet-over" bound (it must be
// >= now, and >= end-of-today to stay listed for the whole day), while the th_2
// "extraDate" slot (bOF) is the "already-started" bound (it must be <= now / today).
// So the future expiry goes in the startDate slot and the past start goes in the
// extraDate slot; getting this backwards silently drops the event from the list (no
// exception, just filtered out). endDate is unused by the non-recurring filter.
func writeTournamentEvent(w *protocol.Writer, t *domain.Tournament, now time.Time) {
	startedMs := now.Add(-time.Hour).UnixMilli()      // event has already started (extraDate / bOF)
	expireMs := now.Add(tournamentWindow).UnixMilli() // event runs until (startDate slot / OV)

	// The phase pair is the opponent-search window. When the tournament has a real
	// schedule this is it; otherwise fall back to the window this used to invent
	// unconditionally, so rows created before the schedule existed still render.
	phaseStartMs := now.Add(time.Hour).UnixMilli()
	phaseEndMs := now.Add(2 * time.Hour).UnixMilli()
	if t.Scheduled() {
		// The period under way, else the next one, else the last.
		i := t.OpenPeriodAt(now)
		if i < 0 {
			i = t.PeriodCount() - 1
			for j := 0; j < t.PeriodCount(); j++ {
				if start, _ := t.Period(j); start.After(now) {
					i = j
					break
				}
			}
		}
		start, end := t.Period(i)
		phaseStartMs, phaseEndMs = start.UnixMilli(), end.UnixMilli()
	}

	w.I32(tournamentContentTypeID) // [i32 typeId] -> qr_0

	// iz_0 shared event base.
	w.I64(t.WireID()) // eventId (reuse the tournament id)
	w.I64(expireMs)   // "startDate" slot (OV) = runs-until bound: >= end-of-today keeps it listed
	w.I64(expireMs)   // endDate (bhF): unused by the non-recurring filter; mirror OV
	w.I64(0)          // recurrence period: none (single occurrence)
	w.I32(0)          // label index: title is taken from the 28602 row when present

	// th_2 duration base.
	w.I64(startedMs) // extraDate (bOF) = already-started bound: <= now / today

	// qr_0 tournament fields.
	w.I64(t.WireID()) // tournamentId (must equal the 28602 row's id: the client links them)
	w.StringU8(t.Name)
	w.StringU16(t.Description)
	w.StringU8(t.Short)
	w.U8(1).I64(phaseStartMs).I64(phaseEndMs) // one schedule (phase) pair (display only)
	w.U8(1).I64(startedMs).I64(expireMs)      // one registration-period pair (>=1 required)
}

// buildTournamentList builds TOURNAMENT_LIST (28602 ng_2): the registerable
// tournaments, keyed by their client definition id. coachStatus reflects whether
// this coach has already registered, so a re-opened window shows the right state.
func buildTournamentList(coachID uint, tm *TournamentManager, ts []domain.Tournament) ([]byte, error) {
	now := time.Now()
	w := protocol.NewWriter().I32(int32(len(ts))) // [i32 count]
	for i := range ts {
		t := &ts[i]
		status := tournamentCoachNotRegistered
		if tm != nil && tm.IsRegistered(coachID, t.WireID()) {
			status = tournamentCoachFirstRound
		}
		w.I64(t.WireID())
		w.U8(0)                                   // openedSearch: opponent search closed
		w.U8(uint8(status))                       // coachStatus
		w.U16(t.DefID)                            // tournamentDefinitionId (real aub id)
		w.U8(boolByte(t.RegistrationOpenAt(now))) // registrationOpen
		w.I32(0)                                  // fightParamCount: no special rules
		w.StringU32(t.Name)
		w.StringU32(t.Description)
		w.StringU32(t.Organizer)
		w.U8(domain.TournamentKindPrivate)
	}
	return protocol.EncodeS2C(protocol.OpTournamentList, w.Bytes())
}
