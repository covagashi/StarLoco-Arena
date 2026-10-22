package web

import (
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// testCatalogue is a stand-in for the decoded type-1000 definitions: two that a
// tournament may use, one that needs an entry card, and (implicitly) every other
// id, which the client does not have at all.
func testCatalogue() *gamedata.Tournaments {
	return gamedata.NewTournaments(
		&gamedata.TournamentDef{ID: 1, TeamType: gamedata.TournamentTeamClassic},
		&gamedata.TournamentDef{ID: 17, TeamType: gamedata.TournamentTeamGraveyard},
		&gamedata.TournamentDef{ID: 13, TeamType: gamedata.TournamentTeamClassic, InscriptionCard: 16},
	)
}

// newTournamentPortal is a portal with the catalogue wired in, signed in as an
// admin.
func newTournamentPortal(t *testing.T) *portal {
	t.Helper()
	p := newPortal(t)
	p.self.tournamentDefs = testCatalogue()
	p.self.live.TournamentDefs = p.self.tournamentDefs
	p.register("owner", "password1") // first account => admin
	return p
}

func TestTournamentSeedIsPresent(t *testing.T) {
	p := newTournamentPortal(t)

	list, err := p.st.Tournaments.List()
	if err != nil {
		t.Fatalf("List: %v", err)
	}
	if len(list) != 3 {
		t.Fatalf("a fresh database should be seeded with 3 tournaments, got %d", len(list))
	}
	pg := p.get("/admin/tournaments")
	if pg.Code != http.StatusOK {
		t.Fatalf("status = %d", pg.Code)
	}
	for _, want := range []string{"Tournoi 1v1 Classique", "Tournoi des Champions", "Tournoi du Cimetiere"} {
		if !strings.Contains(pg.Body, want) {
			t.Errorf("the tournament list is missing %q", want)
		}
	}
	// The decoded catalogue should be reflected: def 17 is the graveyard type.
	if !strings.Contains(pg.Body, "graveyard") {
		t.Error("the list does not show the team type decoded from the catalogue")
	}
}

// The whole point of validating: an id the client does not have is a crash, not
// a cosmetic error, so the console must refuse it.
func TestTournamentRejectsUnknownDefinition(t *testing.T) {
	p := newTournamentPortal(t)
	token := p.csrfFrom(p.get("/admin/tournaments/new"))

	pg := p.post("/admin/tournaments/new", url.Values{
		"csrf_token": {token},
		"name":       {"Crash Cup"},
		"def_id":     {"999"}, // not in the catalogue
		"enabled":    {"1"},
	})
	if pg.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400", pg.Code)
	}
	if !strings.Contains(pg.Body, "not one this game client knows about") {
		t.Error("no explanation of why the type was refused")
	}
	list, _ := p.st.Tournaments.List()
	for _, tr := range list {
		if tr.Name == "Crash Cup" {
			t.Fatal("a tournament with an unknown definition id was saved — this crashes every client")
		}
	}
}

// A definition that needs an entry card can never be joined on this server,
// because nothing grants the card.
func TestTournamentRejectsDefinitionNeedingACard(t *testing.T) {
	p := newTournamentPortal(t)
	token := p.csrfFrom(p.get("/admin/tournaments/new"))

	pg := p.post("/admin/tournaments/new", url.Values{
		"csrf_token": {token},
		"name":       {"Ticketed Cup"},
		"def_id":     {"13"}, // exists, but InscriptionCard = 16
		"enabled":    {"1"},
	})
	if pg.Code != http.StatusBadRequest {
		t.Errorf("status = %d, want 400", pg.Code)
	}
	list, _ := p.st.Tournaments.List()
	for _, tr := range list {
		if tr.Name == "Ticketed Cup" {
			t.Fatal("a tournament nobody could register for was saved")
		}
	}
}

// The picker must only offer definitions that pass both rules, so the default
// path cannot produce a broken tournament.
func TestTournamentPickerOffersOnlyUsableDefinitions(t *testing.T) {
	p := newTournamentPortal(t)
	body := p.get("/admin/tournaments/new").Body

	if !strings.Contains(body, `value="1"`) || !strings.Contains(body, `value="17"`) {
		t.Error("the picker is missing a usable definition")
	}
	if strings.Contains(body, `value="13"`) {
		t.Error("the picker offers definition 13, which needs an entry card nobody can get")
	}
	if !strings.Contains(body, "graveyard") {
		t.Error("the picker does not describe what each definition is")
	}
}

func TestTournamentNameLimits(t *testing.T) {
	p := newTournamentPortal(t)
	token := p.csrfFrom(p.get("/admin/tournaments/new"))

	// 128 bytes: one past what the wire's signed length prefix can express.
	pg := p.post("/admin/tournaments/new", url.Values{
		"csrf_token": {token},
		"name":       {strings.Repeat("x", 128)},
		"def_id":     {"1"},
	})
	if pg.Code != http.StatusBadRequest {
		t.Errorf("128-byte name: status = %d, want 400", pg.Code)
	}

	if pg := p.post("/admin/tournaments/new", url.Values{
		"csrf_token": {token}, "name": {"  "}, "def_id": {"1"},
	}); pg.Code != http.StatusBadRequest {
		t.Errorf("blank name: status = %d, want 400", pg.Code)
	}
}

func TestTournamentCreateEditDelete(t *testing.T) {
	p := newTournamentPortal(t)
	token := p.csrfFrom(p.get("/admin/tournaments/new"))

	// Create.
	pg := p.post("/admin/tournaments/new", url.Values{
		"csrf_token": {token},
		"name":       {"Winter Cup"}, "short": {"Winter"},
		"description": {"A seasonal event."}, "organizer": {"Ankama"},
		"def_id": {"17"}, "position": {"9"},
		"enabled": {"1"}, "registration_open": {"1"},
	})
	if pg.Code != http.StatusOK {
		t.Fatalf("create: status = %d", pg.Code)
	}
	var created *domain.Tournament
	list, _ := p.st.Tournaments.List()
	for i := range list {
		if list[i].Name == "Winter Cup" {
			created = &list[i]
		}
	}
	if created == nil {
		t.Fatal("the tournament was not created")
	}
	if created.DefID != 17 || created.Short != "Winter" || created.Organizer != "Ankama" {
		t.Errorf("fields were not saved: %+v", created)
	}

	// Edit.
	path := "/admin/tournaments/" + strconv.FormatUint(uint64(created.ID), 10)
	editToken := p.csrfFrom(p.get(path))
	pg = p.post(path, url.Values{
		"csrf_token": {editToken},
		"name":       {"Spring Cup"}, "short": {"Spring"},
		"description": {"Renamed."}, "organizer": {"Ankama"},
		"def_id": {"1"}, "position": {"2"},
		"enabled": {"1"}, "registration_open": {"1"},
	})
	if pg.Code != http.StatusOK {
		t.Fatalf("edit: status = %d", pg.Code)
	}
	updated, err := p.st.Tournaments.Get(created.ID)
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	if updated.Name != "Spring Cup" || updated.DefID != 1 {
		t.Errorf("the edit did not take: %+v", updated)
	}

	// Delete.
	pg = p.post(path+"/delete", url.Values{"csrf_token": {editToken}})
	if pg.Code != http.StatusOK {
		t.Fatalf("delete: status = %d", pg.Code)
	}
	if _, err := p.st.Tournaments.Get(created.ID); err == nil {
		t.Error("the tournament was not deleted")
	}
}

// Hiding a tournament must take it off what players are sent, without losing it.
func TestTournamentToggleHidesFromPlayers(t *testing.T) {
	p := newTournamentPortal(t)
	list, _ := p.st.Tournaments.List()
	target := list[0]
	path := "/admin/tournaments/" + strconv.FormatUint(uint64(target.ID), 10)

	token := p.csrfFrom(p.get("/admin/tournaments"))
	p.post(path+"/toggle", url.Values{"csrf_token": {token}})

	got, err := p.st.Tournaments.Get(target.ID)
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	if got.Enabled {
		t.Fatal("the tournament is still enabled after being hidden")
	}
	// Still stored...
	if all, _ := p.st.Tournaments.List(); len(all) != len(list) {
		t.Error("hiding a tournament deleted it")
	}
	// ...but no longer offered to players.
	enabled, err := p.st.Tournaments.ListEnabled()
	if err != nil {
		t.Fatalf("ListEnabled: %v", err)
	}
	for _, e := range enabled {
		if e.ID == target.ID {
			t.Error("a hidden tournament is still sent to players")
		}
	}
}

// Zero values must persist: GORM's struct Updates skips them, which would
// silently ignore exactly the edits an admin most often makes.
func TestTournamentEditPersistsClearedFields(t *testing.T) {
	p := newTournamentPortal(t)
	list, _ := p.st.Tournaments.List()
	target := list[0]
	path := "/admin/tournaments/" + strconv.FormatUint(uint64(target.ID), 10)

	token := p.csrfFrom(p.get(path))
	pg := p.post(path, url.Values{
		"csrf_token": {token},
		"name":       {target.Name}, "short": {target.Short},
		"description": {""}, // cleared
		"organizer":   {"StarLoco"},
		"def_id":      {strconv.Itoa(int(target.DefID))},
		"position":    {"0"}, // zeroed
		// enabled and registration_open both omitted => false
	})
	if pg.Code != http.StatusOK {
		t.Fatalf("status = %d", pg.Code)
	}
	got, _ := p.st.Tournaments.Get(target.ID)
	if got.Description != "" {
		t.Error("an emptied description was not saved")
	}
	if got.Position != 0 {
		t.Error("a zeroed position was not saved")
	}
	if got.Enabled || got.RegistrationOpen {
		t.Error("unticking a checkbox did not save as false")
	}
}

func TestTournamentRoutesAreAdminOnly(t *testing.T) {
	p := newPortal(t)
	p.register("owner", "password1")
	p.logout()
	p.seedPlayer("player", "Rushu")
	p.login("player", "password1")

	for _, path := range []string{"/admin/tournaments", "/admin/tournaments/new"} {
		if pg := p.get(path); pg.Code != http.StatusForbidden {
			t.Errorf("%s: status = %d, want 403 for a non-admin", path, pg.Code)
		}
	}
	if pg := p.post("/admin/tournaments/new", url.Values{"name": {"x"}, "def_id": {"1"}}); pg.Code != http.StatusForbidden {
		t.Errorf("create as non-admin: status = %d, want 403", pg.Code)
	}
}

// Without game data the editor must still work, or a missing data directory
// would lock an operator out of their own tournament list.
func TestTournamentEditorWorksWithoutCatalogue(t *testing.T) {
	p := newPortal(t)
	p.register("owner", "password1")
	// no tournamentDefs wired

	pg := p.get("/admin/tournaments")
	if pg.Code != http.StatusOK {
		t.Fatalf("status = %d", pg.Code)
	}
	if !strings.Contains(pg.Body, "not loaded") {
		t.Error("no warning that types cannot be checked")
	}

	token := p.csrfFrom(p.get("/admin/tournaments/new"))
	if pg := p.post("/admin/tournaments/new", url.Values{
		"csrf_token": {token}, "name": {"Manual Cup"}, "def_id": {"4"}, "enabled": {"1"},
	}); pg.Code != http.StatusOK {
		t.Fatalf("create without a catalogue: status = %d", pg.Code)
	}
	list, _ := p.st.Tournaments.List()
	found := false
	for _, tr := range list {
		if tr.Name == "Manual Cup" {
			found = true
		}
	}
	if !found {
		t.Error("the tournament was not created")
	}
}

// TestTournamentScheduleIsSaved: the schedule fields reach the store, and the
// list shows where the edition is.
func TestTournamentScheduleIsSaved(t *testing.T) {
	p := newTournamentPortal(t)
	list, _ := p.st.Tournaments.List()
	target := list[0]
	path := "/admin/tournaments/" + strconv.FormatUint(uint64(target.ID), 10)
	start := time.Now().Add(48 * time.Hour).Truncate(time.Minute)

	token := p.csrfFrom(p.get(path))
	pg := p.post(path, url.Values{
		"csrf_token": {token}, "name": {target.Name}, "def_id": {"1"},
		"enabled": {"1"}, "registration_open": {"1"},
		"search_start":    {start.Format("2006-01-02T15:04")},
		"search_minutes":  {"60"},
		"search_periods":  {"4"},
		"period_interval": {"1440"},
		"repeat_days":     {"7"},
	})
	if pg.Code != http.StatusOK {
		t.Fatalf("status = %d: %s", pg.Code, pg.Body)
	}
	got, _ := p.st.Tournaments.Get(target.ID)
	if !got.SearchPeriodStart.Equal(start) || got.SearchPeriodMinutes != 60 ||
		got.SearchPeriods != 4 || got.PeriodIntervalMinutes != 1440 || got.RepeatDays != 7 {
		t.Fatalf("schedule not saved: %+v", got)
	}
	if body := p.get("/admin/tournaments").Body; !strings.Contains(body, "Registration until") {
		t.Error("the list does not show the edition's phase")
	}
}

// TestTournamentScheduleValidation refuses schedules the scheduler cannot run.
func TestTournamentScheduleValidation(t *testing.T) {
	p := newTournamentPortal(t)
	start := time.Now().Add(time.Hour).Format("2006-01-02T15:04")
	for name, v := range map[string]url.Values{
		"overlapping periods": {"search_start": {start}, "search_minutes": {"60"}, "search_periods": {"2"}, "period_interval": {"30"}},
		"too many periods":    {"search_start": {start}, "search_minutes": {"60"}, "search_periods": {"7"}, "period_interval": {"60"}},
		"zero-length period":  {"search_start": {start}, "search_minutes": {"0"}, "search_periods": {"1"}},
		"repeat, no start":    {"repeat_days": {"7"}},
		"editions overlap":    {"search_start": {start}, "search_minutes": {"60"}, "search_periods": {"4"}, "period_interval": {"1440"}, "repeat_days": {"2"}},
		"unreadable start":    {"search_start": {"tomorrow"}, "search_minutes": {"60"}, "search_periods": {"1"}},
	} {
		token := p.csrfFrom(p.get("/admin/tournaments/new"))
		v.Set("csrf_token", token)
		v.Set("name", "Bad "+name)
		v.Set("def_id", "1")
		if pg := p.post("/admin/tournaments/new", v); pg.Code != http.StatusBadRequest {
			t.Errorf("%s: status = %d, want 400", name, pg.Code)
		}
	}
}
