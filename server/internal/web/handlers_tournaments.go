package web

import (
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/store"
)

// tournamentRow decorates a stored tournament with what the admin list shows
// alongside it: how the client will read its definition, and how many coaches
// have signed up.
type tournamentRow struct {
	domain.Tournament
	TeamType      string
	KnownDef      bool
	Registrations int
	// Phase is where the scheduler has the edition, in words.
	Phase string
}

// tournamentPhase describes an edition's state for the console.
func (s *Server) tournamentPhase(t *domain.Tournament, now time.Time) string {
	switch {
	case t.Finished():
		if t.WinnerCoachID == 0 {
			return "Finished, no winner"
		}
		name := fmt.Sprintf("coach %d", t.WinnerCoachID)
		if c, err := s.store.Coaches.Get(t.WinnerCoachID); err == nil && c != nil {
			name = c.Name
		}
		return "Finished, won by " + name
	case !t.Scheduled():
		return "Unscheduled (always open)"
	case now.Before(t.SearchPeriodStart):
		return "Registration until " + t.SearchPeriodStart.In(time.Local).Format(consoleTimeLayout)
	}
	if i := t.OpenPeriodAt(now); i >= 0 {
		return fmt.Sprintf("Search period %d of %d open", i+1, t.PeriodCount())
	}
	if next := t.NextPeriodStartAt(now); !next.IsZero() {
		return "Next period " + next.In(time.Local).Format(consoleTimeLayout)
	}
	return "Finishing"
}

// consoleTimeLayout is how the console shows a schedule time (server local).
const consoleTimeLayout = "2006-01-02 15:04"

// formTimeLayout is the <input type="datetime-local"> wire format.
const formTimeLayout = "2006-01-02T15:04"

type tournamentsData struct {
	*baseData
	AdminTab string
	Rows     []tournamentRow
	// CatalogueLoaded reports whether the decoded definitions are available.
	// Without them the editor still works, but nothing can be validated.
	CatalogueLoaded bool
}

func (s *Server) decorate(t domain.Tournament) tournamentRow {
	row := tournamentRow{Tournament: t, TeamType: "unknown"}
	if s.tournamentDefs != nil {
		if d := s.tournamentDefs.Get(int16(t.DefID)); d != nil {
			row.KnownDef = true
			row.TeamType = teamTypeLabel(d.TeamType)
		}
	} else {
		// Nothing to check against, so do not cry wolf.
		row.KnownDef = true
	}
	if s.live.TournamentRegistrations != nil {
		row.Registrations = s.live.TournamentRegistrations(t.WireID())
	}
	row.Phase = s.tournamentPhase(&t, time.Now())
	return row
}

func (s *Server) handleAdminTournaments(w http.ResponseWriter, r *http.Request, sess session) {
	list, err := s.store.Tournaments.List()
	if err != nil {
		s.log.Error("web: list tournaments failed", "err", err)
		s.renderError(w, r, http.StatusInternalServerError, "The tournaments could not be loaded.")
		return
	}
	d := &tournamentsData{
		baseData:        s.newBase(w, r, "Tournaments", "admin"),
		AdminTab:        "tournaments",
		CatalogueLoaded: len(s.tournamentChoices()) > 0,
	}
	for _, t := range list {
		d.Rows = append(d.Rows, s.decorate(t))
	}
	s.render(w, http.StatusOK, "admin_tournaments.html", d)
}

// ---------------------------------------------------------------------------
// Create / edit
// ---------------------------------------------------------------------------

type tournamentFormData struct {
	*baseData
	AdminTab string
	Error    string
	// IsNew switches the form between create and edit.
	IsNew   bool
	Form    domain.Tournament
	Choices []tournamentChoice
	// Registrations is shown when editing, so an admin knows whether anyone
	// would be affected by a change.
	Registrations int
	// Start is the schedule's first period start, in the form's local format.
	Start string
}

// setForm fills the form from a tournament, including its start time.
func (d *tournamentFormData) setForm(t domain.Tournament) {
	d.Form = t
	d.Start = ""
	if !t.SearchPeriodStart.IsZero() {
		d.Start = t.SearchPeriodStart.In(time.Local).Format(formTimeLayout)
	}
}

func (s *Server) newTournamentForm(w http.ResponseWriter, r *http.Request, title string, isNew bool) *tournamentFormData {
	return &tournamentFormData{
		baseData: s.newBase(w, r, title, "admin"),
		AdminTab: "tournaments",
		IsNew:    isNew,
		Choices:  s.tournamentChoices(),
	}
}

func (s *Server) handleAdminTournamentNew(w http.ResponseWriter, r *http.Request, sess session) {
	d := s.newTournamentForm(w, r, "New tournament", true)
	d.setForm(domain.Tournament{
		Enabled:          true,
		RegistrationOpen: true,
		Organizer:        "StarLoco",
		// A sensible schedule to edit: four daily one-hour periods, enough for
		// a full 16-entrant draw.
		SearchPeriodMinutes:   60,
		SearchPeriods:         4,
		PeriodIntervalMinutes: 24 * 60,
	})
	// Default to the first offered definition so the form is valid as-is.
	if len(d.Choices) > 0 {
		d.Form.DefID = d.Choices[0].DefID
	}
	// The start is left empty: an admin has to pick it on purpose.
	s.render(w, http.StatusOK, "admin_tournament_form.html", d)
}

// readTournamentForm pulls a tournament out of a posted form. A start that
// does not parse comes back as an error for the form to show.
func readTournamentForm(r *http.Request) (domain.Tournament, error) {
	defID, _ := strconv.ParseUint(r.PostFormValue("def_id"), 10, 16)
	pos, _ := strconv.Atoi(r.PostFormValue("position"))
	num := func(name string) int32 {
		n, _ := strconv.Atoi(strings.TrimSpace(r.PostFormValue(name)))
		return int32(n)
	}
	var start time.Time
	if v := strings.TrimSpace(r.PostFormValue("search_start")); v != "" {
		var err error
		if start, err = time.ParseInLocation(formTimeLayout, v, time.Local); err != nil {
			return domain.Tournament{}, errors.New("The start time could not be read; use the date picker.")
		}
	}
	return domain.Tournament{
		SearchPeriodStart:     start,
		SearchPeriodMinutes:   num("search_minutes"),
		SearchPeriods:         num("search_periods"),
		PeriodIntervalMinutes: num("period_interval"),
		RepeatDays:            num("repeat_days"),
		DefID:                 uint16(defID),
		Name:                  r.PostFormValue("name"),
		Short:                 r.PostFormValue("short"),
		Description:           r.PostFormValue("description"),
		Organizer:             r.PostFormValue("organizer"),
		Enabled:               r.PostFormValue("enabled") != "",
		RegistrationOpen:      r.PostFormValue("registration_open") != "",
		Position:              pos,
	}, nil
}

func (s *Server) handleAdminTournamentCreate(w http.ResponseWriter, r *http.Request, sess session) {
	if !s.requirePost(w, r, sess) {
		return
	}
	d := s.newTournamentForm(w, r, "New tournament", true)
	form, err := readTournamentForm(r)
	d.setForm(form)
	if err == nil {
		err = s.validateTournament(&d.Form)
	}
	if err != nil {
		d.Start = r.PostFormValue("search_start")
		d.Error = err.Error()
		s.render(w, http.StatusBadRequest, "admin_tournament_form.html", d)
		return
	}
	t := d.Form
	if err := s.store.Tournaments.Create(&t); err != nil {
		s.log.Error("web: create tournament failed", "err", err)
		d.Error = "The tournament could not be saved."
		s.render(w, http.StatusInternalServerError, "admin_tournament_form.html", d)
		return
	}
	s.log.Info("web: tournament created", "name", t.Name, "defID", t.DefID, "by", sess.AccountID)
	setFlash(w, "success", "Tournament “"+t.Name+"” created.")
	redirect(w, r, "/admin/tournaments")
}

func (s *Server) handleAdminTournamentEdit(w http.ResponseWriter, r *http.Request, sess session) {
	id, ok := idParam(r)
	if !ok {
		s.renderError(w, r, http.StatusNotFound, "No such tournament.")
		return
	}
	t, err := s.store.Tournaments.Get(id)
	if err != nil {
		s.renderError(w, r, http.StatusNotFound, "No such tournament.")
		return
	}
	d := s.newTournamentForm(w, r, t.Name, false)
	d.setForm(*t)
	if s.live.TournamentRegistrations != nil {
		d.Registrations = s.live.TournamentRegistrations(t.WireID())
	}
	s.render(w, http.StatusOK, "admin_tournament_form.html", d)
}

func (s *Server) handleAdminTournamentSave(w http.ResponseWriter, r *http.Request, sess session) {
	if !s.requirePost(w, r, sess) {
		return
	}
	id, ok := idParam(r)
	if !ok {
		s.renderError(w, r, http.StatusNotFound, "No such tournament.")
		return
	}
	existing, err := s.store.Tournaments.Get(id)
	if err != nil {
		s.renderError(w, r, http.StatusNotFound, "No such tournament.")
		return
	}

	d := s.newTournamentForm(w, r, existing.Name, false)
	form, err := readTournamentForm(r)
	form.ID = existing.ID
	d.setForm(form)
	if err == nil {
		err = s.validateTournament(&d.Form)
	}
	if err != nil {
		d.Start = r.PostFormValue("search_start")
		d.Error = err.Error()
		s.render(w, http.StatusBadRequest, "admin_tournament_form.html", d)
		return
	}
	if err := s.store.Tournaments.Update(&d.Form); err != nil {
		s.log.Error("web: update tournament failed", "err", err)
		d.Error = "The tournament could not be saved."
		s.render(w, http.StatusInternalServerError, "admin_tournament_form.html", d)
		return
	}
	s.log.Info("web: tournament updated", "name", d.Form.Name, "id", id, "by", sess.AccountID)
	setFlash(w, "success", "Tournament “"+d.Form.Name+"” saved.")
	redirect(w, r, "/admin/tournaments")
}

// ---------------------------------------------------------------------------
// Delete / enable
// ---------------------------------------------------------------------------

func (s *Server) handleAdminTournamentDelete(w http.ResponseWriter, r *http.Request, sess session) {
	if !s.requirePost(w, r, sess) {
		return
	}
	id, ok := idParam(r)
	if !ok {
		s.renderError(w, r, http.StatusNotFound, "No such tournament.")
		return
	}
	t, err := s.store.Tournaments.Get(id)
	if err != nil {
		s.renderError(w, r, http.StatusNotFound, "No such tournament.")
		return
	}
	name := t.Name

	if err := s.store.Tournaments.Delete(id); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			s.renderError(w, r, http.StatusNotFound, "No such tournament.")
			return
		}
		s.log.Error("web: delete tournament failed", "err", err)
		setFlash(w, "error", "That tournament could not be deleted.")
	} else {
		s.log.Info("web: tournament deleted", "name", name, "id", id, "by", sess.AccountID)
		setFlash(w, "success", "Tournament “"+name+"” deleted.")
	}
	redirect(w, r, "/admin/tournaments")
}

// handleAdminTournamentToggle flips Enabled, the quickest way to take an event
// off the board without losing how it was set up.
func (s *Server) handleAdminTournamentToggle(w http.ResponseWriter, r *http.Request, sess session) {
	if !s.requirePost(w, r, sess) {
		return
	}
	id, ok := idParam(r)
	if !ok {
		s.renderError(w, r, http.StatusNotFound, "No such tournament.")
		return
	}
	t, err := s.store.Tournaments.Get(id)
	if err != nil {
		s.renderError(w, r, http.StatusNotFound, "No such tournament.")
		return
	}
	t.Enabled = !t.Enabled
	if err := s.store.Tournaments.Update(t); err != nil {
		s.log.Error("web: toggle tournament failed", "err", err)
		setFlash(w, "error", "That change could not be saved.")
	} else {
		s.log.Info("web: tournament visibility changed",
			"name", t.Name, "enabled", t.Enabled, "by", sess.AccountID)
		if t.Enabled {
			setFlash(w, "success", "“"+t.Name+"” is now visible to players.")
		} else {
			setFlash(w, "info", "“"+t.Name+"” is hidden from players.")
		}
	}
	redirect(w, r, "/admin/tournaments")
}
