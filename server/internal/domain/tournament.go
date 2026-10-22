package domain

import "time"

// Tournament is a standing tournament the server offers, editable from the web
// admin console.
//
// These used to be a compiled-in table, which meant changing the server's
// tournament line-up needed a rebuild. A row is one EDITION of a tournament: it
// opens for registration, plays its search periods on a schedule and finishes
// (FinishedAt). A repeating tournament is not reset in place when it ends; the
// scheduler creates the next edition as a new row (PreviousID points back), so
// the finished one keeps its registrations and bracket as history and the next
// starts with a fresh wire id.
//
// DefID is the part an operator cannot be allowed to get wrong. It references a
// real client definition (a data.bdat type-1000 `aub` record; retail ships 22,
// ids {1, 4..24}), and the client dereferences it unguarded — a row pointing at
// a definition the client does not have takes the client down with a null
// dereference rather than showing an error. That rule is enforced when a
// tournament is saved; see internal/web's tournament validation. A definition
// with an inscription card (13: card 16, 19: card 808 "Ticket MasterCoach")
// costs one of that card to enter, taken at registration (4607).
type Tournament struct {
	ID uint `gorm:"primaryKey"`

	// DefID is the client definition id (aub.Bw()).
	DefID uint16 `gorm:"not null"`

	// Name and Short go out in fields the wire length-prefixes with a SIGNED
	// byte, so anything past 127 bytes is truncated by the writer.
	Name  string `gorm:"size:127;not null"`
	Short string `gorm:"size:127;not null"`
	// Description is length-prefixed with 16 bits; the cap here is editorial,
	// not protocol.
	Description string `gorm:"size:1000;not null"`
	// Organizer is the label shown as who runs the tournament.
	Organizer string `gorm:"size:127;not null"`

	// Enabled hides a tournament from players without deleting it, so a
	// seasonal event can be prepared in advance and switched on later.
	Enabled bool `gorm:"not null;default:true"`
	// RegistrationOpen still lists the tournament but refuses new sign-ups.
	RegistrationOpen bool `gorm:"not null;default:true"`

	// Position orders the list players see; ties fall back to ID.
	Position int `gorm:"not null;default:0"`

	// SearchPeriodStart / SearchPeriodMinutes describe the tournament's
	// opponent-search period: the window in which entrants are expected to press
	// Combattre, and outside which retail declares the absentees forfeit.
	//
	// This is the SAME schedule the client is shown. The calendar event (17003
	// qr_0) carries a "phase" pair which used to be invented as now+1h..now+2h on
	// every request - display-only, and drifting each time the window was opened.
	// Driving both from these columns is what stops the advertised schedule and
	// the server's own idea of it from disagreeing.
	//
	// A zero SearchPeriodStart means "not scheduled"; the calendar then falls back
	// to the old synthesized window so existing rows keep working.
	SearchPeriodStart   time.Time
	SearchPeriodMinutes int32 `gorm:"not null;default:0"`

	// SearchPeriods is how many search periods the edition plays, one bracket
	// round each at most (a 16-entrant draw needs 4). PeriodIntervalMinutes is
	// the gap from one period's START to the next's. 0 periods on a scheduled
	// row means 1, so rows scheduled before these columns existed keep their
	// single window.
	SearchPeriods         int32 `gorm:"not null;default:0"`
	PeriodIntervalMinutes int32 `gorm:"not null;default:0"`

	// RepeatDays > 0 makes the scheduler open the next edition, that many days
	// later, when this one finishes. Retail's admin scheduler had the same
	// "repeat" switch (tournamentAdminCreationDialog).
	RepeatDays int32 `gorm:"not null;default:0"`

	// FinishedAt is set once, by the scheduler, when the edition ends: a winner
	// is decided or its last search period has closed. A finished edition is
	// no longer listed to players. WinnerCoachID is 0 when nobody won (an empty
	// draw, or fixtures nobody turned up for).
	FinishedAt    *time.Time
	WinnerCoachID uint `gorm:"not null;default:0"`

	// PreviousID is the edition this one was repeated from (0 = the first). It
	// is what "the next tournament of the same type" means for the carry-over
	// question (28618), which needs an edition to carry INTO.
	PreviousID uint `gorm:"index;not null;default:0"`

	// CreatorCoachID is the coach who created this tournament with the
	// "Création de Tournoi" card (17010), or 0 for an official one set up from
	// the console. Player tournaments award no tournament points and do not
	// count as official wins (statistic 187), so they cannot be used to farm
	// the board among friends.
	CreatorCoachID uint `gorm:"index;not null;default:0"`

	CreatedAt time.Time
	UpdatedAt time.Time
}

// Scheduled reports whether the edition has a search schedule. An unscheduled
// row keeps the old standing behaviour: always open, never finishing.
func (t *Tournament) Scheduled() bool {
	return t != nil && !t.SearchPeriodStart.IsZero() && t.SearchPeriodMinutes > 0
}

// Finished reports whether the scheduler has ended this edition.
func (t *Tournament) Finished() bool { return t != nil && t.FinishedAt != nil }

// PeriodCount is how many search periods a scheduled edition plays (>= 1).
func (t *Tournament) PeriodCount() int {
	if !t.Scheduled() {
		return 0
	}
	if t.SearchPeriods <= 1 {
		return 1
	}
	return int(t.SearchPeriods)
}

// Period returns the start and end of search period i (0-based).
//
// The interval is clamped to at least the period's own length: periods that
// overlapped would have two windows open at once and settle each other's
// fixtures mid-search.
func (t *Tournament) Period(i int) (start, end time.Time) {
	length := time.Duration(t.SearchPeriodMinutes) * time.Minute
	step := time.Duration(t.PeriodIntervalMinutes) * time.Minute
	if step < length {
		step = length
	}
	start = t.SearchPeriodStart.Add(time.Duration(i) * step)
	return start, start.Add(length)
}

// SearchPeriodEnd is when the FIRST search period closes, or the zero time if
// none is scheduled.
func (t *Tournament) SearchPeriodEnd() time.Time {
	if !t.Scheduled() {
		return time.Time{}
	}
	_, end := t.Period(0)
	return end
}

// LastPeriodEnd is when the edition's final search period closes: past it,
// nothing more can be decided and the edition finishes.
func (t *Tournament) LastPeriodEnd() time.Time {
	if !t.Scheduled() {
		return time.Time{}
	}
	_, end := t.Period(t.PeriodCount() - 1)
	return end
}

// OpenPeriodAt returns the index of the search period containing `now`, or -1.
func (t *Tournament) OpenPeriodAt(now time.Time) int {
	if t.Finished() {
		return -1
	}
	for i := 0; i < t.PeriodCount(); i++ {
		start, end := t.Period(i)
		if !now.Before(start) && now.Before(end) {
			return i
		}
	}
	return -1
}

// ClosedPeriodsAt counts the search periods that have ended by `now`.
func (t *Tournament) ClosedPeriodsAt(now time.Time) int {
	n := 0
	for i := 0; i < t.PeriodCount(); i++ {
		if _, end := t.Period(i); !now.Before(end) {
			n++
		}
	}
	return n
}

// NextPeriodStartAt returns the start of the first period still ahead of `now`,
// or the zero time when none is.
func (t *Tournament) NextPeriodStartAt(now time.Time) time.Time {
	if t.Finished() {
		return time.Time{}
	}
	for i := 0; i < t.PeriodCount(); i++ {
		if start, _ := t.Period(i); start.After(now) {
			return start
		}
	}
	return time.Time{}
}

// SearchPeriodOpenAt reports whether any search window contains `now`.
func (t *Tournament) SearchPeriodOpenAt(now time.Time) bool {
	return t.OpenPeriodAt(now) >= 0
}

// RegistrationOpenAt is RegistrationOpen as of `now`: a scheduled edition stops
// taking entrants when its first search period starts (the draw is fixed from
// then on), and a finished one never takes any.
func (t *Tournament) RegistrationOpenAt(now time.Time) bool {
	if t == nil || !t.RegistrationOpen || t.Finished() {
		return false
	}
	return !t.Scheduled() || now.Before(t.SearchPeriodStart)
}

func (Tournament) TableName() string { return "tournaments" }

// TournamentRegistration is one coach's entry into one standing tournament.
//
// Keyed by the tournament's WIRE id rather than its row id, because that is what
// the client sends in 4607 and what every reply is keyed by. The wire id is
// derived from the row id (see WireID), so it is stable across restarts — which
// is precisely what makes storing it safe.
//
// This used to live only in memory, so every restart silently un-registered
// everyone (B-101).
// The field is deliberately named for what it holds — the WIRE id, not the
// tournament row id — because the two differ by TournamentWireBase and confusing
// them would silently register people for the wrong thing.
// TournamentSlot records who occupies a bracket slot.
//
// The bracket is a 1-indexed binary heap (see game.bracket*): slot 1 is the
// winner, 16-31 the first round, and slot i is decided by the pair in 2i / 2i+1.
// Only slots ABOVE the first round are stored - the first round is derived from
// the registrations, so seeding cannot drift away from who is actually entered.
type TournamentSlot struct {
	ID uint `gorm:"primaryKey"`

	TournamentWireID int64 `gorm:"index;not null;uniqueIndex:idx_tourn_slot"`
	Slot             int32 `gorm:"not null;uniqueIndex:idx_tourn_slot"`
	CoachID          uint  `gorm:"index;not null"`

	CreatedAt time.Time
}
type TournamentRegistration struct {
	ID      uint `gorm:"primaryKey"`
	CoachID uint `gorm:"index;not null;uniqueIndex:idx_tourn_reg_coach_tid"`

	TournamentWireID int64 `gorm:"index;not null;uniqueIndex:idx_tourn_reg_coach_tid"`

	// PrizeAwarded records that this coach has already been paid this
	// tournament's reward card.
	//
	// SECURITY: awardTournamentPrize had no already-paid record at all, and the
	// path that reaches it (28611, the tournament search) re-derives
	// "unopposed in this tournament" from persisted bracket state - so it stays
	// true forever once you hold the root slot, and each packet paid another copy
	// of the reward card. This row already carries a unique (coach, tournament)
	// index, which makes it the natural place to make payment idempotent.
	PrizeAwarded bool `gorm:"not null;default:false"`

	// Set when the edition finishes (S09). Points are the tournament points
	// this entry earned (see game.tournamentPoints). Unfinished marks a coach
	// still in contention when an edition ended without a winner, which is who
	// is offered the carry-over (28618); CarryOffered records that the offer
	// went out, since a "no" sends nothing back. Carried marks an entry made by
	// accepting it (28617): carried entrants are seeded ahead of new ones.
	Points       int32 `gorm:"not null;default:0"`
	Unfinished   bool  `gorm:"not null;default:false"`
	CarryOffered bool  `gorm:"not null;default:false"`
	Carried      bool  `gorm:"not null;default:false"`

	CreatedAt time.Time
}

func (TournamentRegistration) TableName() string { return "tournament_registrations" }

// TournamentWireBase keeps synthetic tournament handles clear of coach and
// fighter wire ids. The value only has to be stable, unique and non-zero.
//
// It lives here rather than in the game package because both the wire layer and
// the admin console need to agree on how a row id becomes a wire id.
const TournamentWireBase int64 = 2_600_000

// WireID is the handle the client sees. Deriving it from the row id keeps it
// stable across restarts, which matters because registrations are keyed by it.
func (t *Tournament) WireID() int64 { return TournamentWireBase + int64(t.ID) }

// TournamentKindPrivate is the 28602 wire kind (ks_1) every tournament here
// uses: a registerable event whose opponent search the entrant starts from the
// alert list, which is the only shape this server runs. It is deliberately not
// editable from the console — the other kinds pull the client into flows that
// have no server behind them.
const TournamentKindPrivate uint8 = 1

// Official reports whether the tournament was set up from the console rather
// than created by a player.
func (t *Tournament) Official() bool { return t != nil && t.CreatorCoachID == 0 }
