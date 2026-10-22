package game

import (
	"time"

	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store"
)

// The ranking window is SEVEN independent leaderboards, one opcode pair each
// (client controller afl_1, dialog ladderInformationDialog.xml). The boards
// whose subsystem exists carry data (see the table); the rest are answered with
// well-formed EMPTY windows. Getting the empty forms
// byte-exact is what makes the panel open cleanly instead of throwing in the
// client's decoder.
//
//	tab         C2S            S2C            data source
//	1 vs 1      27500 dp_0     27501 azd_0    ranked coaches (strength > 0)
//	Coach       27508 aa_2     27509 jw_0     — (no coach reputation) -> empty
//	2 vs 2      27504 vg_1     27505 aka_0    — (no 2v2 teams)        -> empty
//	Clan        27502 pc_1     27503 ij_1     — (no guild system)     -> empty
//	Tournoi     27506 qk_2     27507 uj_0     tournament points (S09)
//	Ligue Pro   27514 ck_2     27515 amu_0    — (no pro league)       -> empty
//	Démon       27512 ow_2     27513 xn_2     the 24 overworld demons
//
// NOTE (corrected — see BUGS.md B-046): 27506/27507 is the **Tournoi** tab, not a
// "seasonal" board, and the real **Ligue Pro** tab is a seventh pair, 27514/27515.
// Both were previously mislabelled; the Tournoi tab was answered with SILENCE and
// so rendered blank, and 27514 had no handler at all.
//
// Every row loop in afl_1 indexes a PRE-SIZED client list (`list.get(n)`), and the
// 27515 handler additionally clears slots up to `total`. So an empty board must
// send zero for the counts — a non-zero total with zero rows would throw
// IndexOutOfBounds inside the client.

// ladderPageSize is how many ranking rows one window returns. The client requests
// successive windows by start offset as the player scrolls.
const ladderPageSize = 20

// guildLadderBoard is the board id the client's guild request carries and its
// reply must echo: ij_1 only populates the list when the echoed board == 1.
const guildLadderBoard uint16 = 1

func registerLadderHandlers(r *Router, d *Deps) {
	r.Register(protocol.OpLadderRequest, handleLadderRequest)
	r.Register(protocol.OpGuildLadderRequest, handleGuildLadderRequest)
	r.Register(protocol.OpLadder2v2Request, handleLadder2v2Request)
	r.Register(protocol.OpTournamentLadderRequest, handleTournamentLadderRequest)
	r.Register(protocol.OpProLeagueLadderRequest, handleProLeagueLadderRequest)
	r.Register(protocol.OpCoachReputationRequest, handleCoachReputationRequest)
	r.Register(protocol.OpDemonListRequest, handleDemonListRequest)
}

// demonCount is the number of overworld DemonTotems (demon ids 1..24) the Démon
// tab lists.
const demonCount = 24

// demonListPageSize is how many demons the client's Démon-list widget (ec) shows
// per page; it scrolls by this amount.
const demonListPageSize = 12

// --- 1v1 board (27500 -> 27501) ------------------------------------------------

// handleLadderRequest (27500 dp_0: [i32 windowStart]) replies with a window of the
// 1v1 leaderboard (27501). windowStart is the scroll position (0-based).
func handleLadderRequest(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	start, err := r.I32()
	if err != nil {
		return err
	}
	if start < 0 {
		start = 0
	}

	total, err := s.deps.Store.Coaches.LadderCount()
	if err != nil {
		return err
	}
	rows, err := s.deps.Store.Coaches.LadderPage(int(start), ladderPageSize)
	if err != nil {
		return err
	}
	myRank, err := s.deps.Store.Coaches.LadderRank(s.Coach.ID)
	if err != nil {
		return err
	}

	frame, err := buildLadderResponse(total, int(start), rows, myRank, s.deps.guildTagsFor(rows))
	if err != nil {
		return err
	}
	s.log.Debug("ladder 1v1", "coach", s.Coach.Name, "start", start,
		"total", total, "rows", len(rows), "myRank", myRank)
	return s.Send(frame)
}

// buildLadderResponse builds LADDER_RESPONSE (27501 azd_0):
//
//	[i32 total][i32 windowStart][i32 windowEnd][i32 myRank]
//	(windowEnd-windowStart) × {
//	  [i32 nameLen][name][i32 guildLen][guild]
//	  [i16 rating][i32 _][i32 _][i32 streak][i32 _][i32 wins][i32 losses]
//	}
//	[u8 searchButton]
//
// CRITICAL: the client loops `for j < (windowEnd - windowStart)`, so windowEnd
// MUST equal windowStart + len(rows) or it reads past the buffer (→ decode
// exception → the whole list stays blank). buildLadderResponse owns that so no
// caller can desynchronise it. The client derives each row's rank number and
// level/rank icon itself (from windowStart + index and the rating), so we send
// only name, guild, rating, streak, wins, losses; the three filler i32s are read
// and discarded. myRank drives the self-highlight (0 = unranked, matches no row).
func buildLadderResponse(total, windowStart int, rows []store.LadderEntry, myRank int, guildOf map[string]string) ([]byte, error) {
	windowEnd := windowStart + len(rows) // load-bearing: see the loop note above
	w := protocol.NewWriter().
		I32(int32(total)).
		I32(int32(windowStart)).
		I32(int32(windowEnd)).
		I32(int32(myRank))

	for _, e := range rows {
		writeLadderString(w, e.Name)
		writeLadderString(w, guildOf[e.Name]) // clan tag (blank when clanless)

		w.U16(uint16(int16(e.Strength))) // rating (glicko; client renders level/rank)
		w.I32(0)                         // discarded
		w.I32(0)                         // discarded
		w.I32(e.ConsecutiveWins)         // streak (consecutive victories)
		w.I32(0)                         // discarded
		w.I32(e.StatWins)                // total victories
		w.I32(e.StatLosses)              // total defeats
	}
	w.U8(1) // search button visible

	return protocol.EncodeS2C(protocol.OpLadderResponse, w.Bytes())
}

// --- guild board (27502 -> 27503) ----------------------------------------------

// guildLadderRow is one clan-ranking row (clan name + its leader + score). The
// production reply is always empty (no guild system); the type exists so the
// layout is exercised by a test and ready when guilds land.
type guildLadderRow struct {
	guild  string
	leader string
	score  int32
}

// handleGuildLadderRequest (27502 pc_1: [i16 board][i32 windowStart]) answers the
// Clan tab with a well-formed EMPTY guild window — guilds are not modelled.
func handleGuildLadderRequest(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	if _, err := r.U16(); err != nil { // board selector (client always sends 1)
		return err
	}
	start, err := r.I32()
	if err != nil {
		return err
	}
	if start < 0 {
		start = 0
	}
	frame, err := buildGuildLadder(int(start), s.deps.guildLadderRows())
	if err != nil {
		return err
	}
	s.log.Debug("ladder guild (empty)", "coach", s.Coach.Name, "start", start)
	return s.Send(frame)
}

// buildGuildLadder builds GUILD_LADDER (27503 ij_1):
//
//	[i16 board=1][i32 windowStart][i32 rowCount]
//	rowCount × {[i32 len][guildName][i32 len][leaderName][i32 score]}
//
// The board id MUST be 1 or the client (ij_1, `if cB() == 1`) skips the whole
// list.
func buildGuildLadder(windowStart int, rows []guildLadderRow) ([]byte, error) {
	w := protocol.NewWriter().
		U16(guildLadderBoard).
		I32(int32(windowStart)).
		I32(int32(len(rows)))
	for _, e := range rows {
		writeLadderString(w, e.guild)
		writeLadderString(w, e.leader)
		w.I32(e.score)
	}
	return protocol.EncodeS2C(protocol.OpGuildLadder, w.Bytes())
}

// --- 2v2 board (27504 -> 27505) ------------------------------------------------

// teamLadderRow is one 2v2 best-team row. Production is always empty (no 2v2
// teams); the type keeps the layout tested and ready.
type teamLadderRow struct {
	coaches string // the pair's coach names (client model oR, may be composite)
	team    string // team name
	guild   string
	rating  int16
	streak  int32
	wins    int32
	losses  int32
}

// handleLadder2v2Request (27504 vg_1: [i32 windowStart]) answers the 2v2 tab with
// a well-formed EMPTY window — 2v2 teams are not modelled.
func handleLadder2v2Request(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	start, err := r.I32()
	if err != nil {
		return err
	}
	if start < 0 {
		start = 0
	}
	frame, err := build2v2Ladder(0, int(start), nil, nil)
	if err != nil {
		return err
	}
	s.log.Debug("ladder 2v2 (empty)", "coach", s.Coach.Name, "start", start)
	return s.Send(frame)
}

// build2v2Ladder builds LADDER_2V2 (27505 aka_0):
//
//	[i32 total][i32 windowStart][i32 windowEnd][i32 iconCount]{i32}×iconCount
//	(windowEnd-windowStart) × {
//	  [i32 len][coachNames][i32 len][teamName][i32 len][guild]
//	  [i16 rating][i32 _][i32 _][i32 streak][i32 _][i32 wins][i32 losses]
//	}
//	[i32 searchButton]    <- NOTE: a full i32 here, unlike 27501's u8
//
// Same windowEnd = windowStart + len(rows) contract as 27501.
func build2v2Ladder(total, windowStart int, rows []teamLadderRow, icons []int32) ([]byte, error) {
	windowEnd := windowStart + len(rows)
	w := protocol.NewWriter().
		I32(int32(total)).
		I32(int32(windowStart)).
		I32(int32(windowEnd)).
		I32(int32(len(icons)))
	for _, ic := range icons {
		w.I32(ic)
	}
	for _, e := range rows {
		writeLadderString(w, e.coaches)
		writeLadderString(w, e.team)
		writeLadderString(w, e.guild)
		w.U16(uint16(e.rating))
		w.I32(0) // discarded
		w.I32(0) // discarded
		w.I32(e.streak)
		w.I32(0) // discarded
		w.I32(e.wins)
		w.I32(e.losses)
	}
	w.I32(1) // search button visible (i32, not u8)
	return protocol.EncodeS2C(protocol.OpLadder2v2Response, w.Bytes())
}

// --- coach reputation board (27508 -> 27509) -----------------------------------

// handleCoachReputationRequest (27508 aa_2: [i32 startRank]) answers the "Coach"
// tab — coaches ranked by DEMON reputation. Reputation is a guild/demon mechanic
// that is not modelled, so every coach is at 0 and the board is a well-formed
// EMPTY window (distinct from the 1v1 board, which ranks by strength).
func handleCoachReputationRequest(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	start, err := r.I32()
	if err != nil {
		return err
	}
	if start < 0 {
		start = 0
	}
	frame, err := buildCoachReputation(int(start), nil)
	if err != nil {
		return err
	}
	s.log.Debug("ladder coach-reputation (empty)", "coach", s.Coach.Name, "start", start)
	return s.Send(frame)
}

// coachReputationRow is one coach-reputation row. Production is always empty (no
// reputation system); the type keeps the layout tested and ready.
type coachReputationRow struct {
	reputation int32
	coach      string
	team       string
	wins       int32
	losses     int32
	guild      string
	demonID    int16
}

// buildCoachReputation builds COACH_REPUTATION (27509 jw_0), a derived-count
// window (like 27501):
//
//	[i32 total][i32 windowStart][i32 windowEnd][i32 localCoachIdx]
//	(windowEnd-windowStart) × {
//	  [i32 reputation][i32 len][coach][i32 len][team]
//	  [i32 wins][i32 losses][i32 len][guild][i16 demonId]
//	}
//	[u8 searchButton]
//
// localCoachIdx highlights the caller's own row (rank-1 == idx); -1 = no match.
func buildCoachReputation(windowStart int, rows []coachReputationRow) ([]byte, error) {
	windowEnd := windowStart + len(rows)
	localIdx := -1
	w := protocol.NewWriter().
		I32(int32(len(rows))).
		I32(int32(windowStart)).
		I32(int32(windowEnd)).
		I32(int32(localIdx))
	for _, e := range rows {
		w.I32(e.reputation)
		writeLadderString(w, e.coach)
		writeLadderString(w, e.team)
		w.I32(e.wins)
		w.I32(e.losses)
		writeLadderString(w, e.guild)
		w.U16(uint16(e.demonID))
	}
	w.U8(0) // no search button on the empty reputation board
	return protocol.EncodeS2C(protocol.OpCoachReputation, w.Bytes())
}

// --- demon list board (27512 -> 27513) -----------------------------------------

// handleDemonListRequest (27512 ow_2: [i16 flag][i32 startIndex]) answers the
// "Démon" tab: the 24 overworld demons (ids 1..24), a page of 12 at a time. Each
// demon's guild reputation is 0 (no guild system), so we list the demon ROSTER
// with empty guilds — real structure, honestly zeroed, rather than a blank tab.
func handleDemonListRequest(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	if _, err := r.U16(); err != nil { // flag (client sends 1)
		return err
	}
	start, err := r.I32()
	if err != nil {
		return err
	}
	if start < 0 {
		start = 0
	}
	frame, err := buildDemonList(int(start))
	if err != nil {
		return err
	}
	s.log.Debug("ladder demon-list", "coach", s.Coach.Name, "start", start)
	return s.Send(frame)
}

// buildDemonList builds DEMON_LIST (27513 xn_2), an explicit-count window with a
// leading status flag that MUST be 1 for the client (ec) to populate its rows:
//
//	[i16 statusFlag=1][i32 startIndex][i32 count]
//	count × {[i16 demonId][i64 quarterlyRepPts][i32 len][guildName]}
//
// Serves demon ids [startIndex+1 .. startIndex+12] capped at 24, so a scroll to
// startIndex 12 shows demons 13..24.
func buildDemonList(startIndex int) ([]byte, error) {
	count := demonCount - startIndex
	if count < 0 {
		count = 0
	}
	if count > demonListPageSize {
		count = demonListPageSize
	}
	w := protocol.NewWriter().
		U16(1). // status flag: 1 = populate
		I32(int32(startIndex)).
		I32(int32(count))
	for i := 0; i < count; i++ {
		demonID := startIndex + i + 1 // demon ids are 1-based
		w.U16(uint16(demonID))
		w.I64(0)                 // quarterly reputation points (no guild activity)
		writeLadderString(w, "") // leading guild (none)
	}
	return protocol.EncodeS2C(protocol.OpDemonList, w.Bytes())
}

// --- Tournoi board (27506 -> 27507) --------------------------------------------

// handleTournamentLadderRequest handles the "Tournoi" tab (27506 qk_2):
//
//	[i32 monthStart][i32 trimStart][i32 yearStart][i8 month][i8 trimester][i16 year]
//
// It replies with 27507 (uj_0), the tournament-POINTS board: three windows in
// one message (the month, trimester and year the player picked), each ranking
// the coaches by the points earned in editions that finished in that period
// (S09). The client's selectors are 0-based (month 0-11, `"month" + m`;
// trimester 0-3, shown +1) and its year buttons only reach this year and last;
// a request with year 0 (the Godot client's first one) means "now".
//
// This tab previously received NO reply and therefore rendered blank — it was
// mislabelled "seasonal" (see B-046).
func handleTournamentLadderRequest(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	var starts [3]int32
	for i := range starts {
		starts[i], _ = r.I32()
		if starts[i] < 0 {
			starts[i] = 0
		}
	}
	month, err := r.U8()
	if err != nil {
		return err
	}
	trimester, err := r.U8()
	if err != nil {
		return err
	}
	year, err := r.U16()
	if err != nil {
		return err
	}
	if year == 0 {
		now := time.Now()
		year, month = uint16(now.Year()), uint8(now.Month()-1)
		trimester = month / 3
	}
	month, trimester = month%12, trimester%4

	var wins [3]tournamentLadderWindow
	var mine [3]int32
	if s.deps.Store != nil && s.deps.Store.Tournaments != nil {
		for i, p := range tournamentLadderPeriods(month, trimester, year) {
			rows, _, err := s.deps.Store.Tournaments.PointsBoard(p[0], p[1], int(starts[i]), tournamentLadderPage)
			if err != nil {
				return err
			}
			pts, rank, err := s.deps.Store.Tournaments.PointsAndRank(s.Coach.ID, p[0], p[1])
			if err != nil {
				return err
			}
			wins[i] = tournamentLadderWindow{start: int(starts[i]), rows: rows, myRank: rank}
			mine[i] = pts
		}
	}
	frame, err := buildTournamentLadder(month, trimester, year, mine, wins)
	if err != nil {
		return err
	}
	s.log.Debug("tournament ladder", "coach", s.Coach.Name, "month", month,
		"trimester", trimester, "year", year)
	return s.Send(frame)
}

// tournamentLadderPage is how many rows one window carries: the client's three
// lists (`adn_1` dxh/dxi/dxj) are pre-sized to 10 and indexed without a check.
const tournamentLadderPage = 10

// tournamentLadderWindow is one of the board's three windows.
type tournamentLadderWindow struct {
	start  int
	rows   []store.PointsEntry
	myRank int
}

// tournamentLadderPeriods is [from, to) for the month, trimester and year
// windows, in server time.
func tournamentLadderPeriods(month, trimester uint8, year uint16) [3][2]time.Time {
	y := int(year)
	at := func(m int) time.Time { return time.Date(y, time.Month(m), 1, 0, 0, 0, 0, time.Local) }
	return [3][2]time.Time{
		{at(int(month) + 1), at(int(month) + 2)},
		{at(int(trimester)*3 + 1), at(int(trimester)*3 + 4)},
		{at(1), at(13)},
	}
}

// buildTournamentLadder builds TOURNAMENT_LADDER (27507 uj_0):
//
//	[i8 month][i8 trimester][i16 year]
//	[i32 myPointsMonth][i32 myPointsTrimester][i32 myPointsYear]
//	3 × { [i32 count][i32 start][i32 end][i32 myRank]
//	      (end-start) × {[i32 nameLen][name][i32 points]}
//	      [i8 searchButton] }
//
// end MUST equal start + len(rows): the client loops `end - start` times. The
// first i32 is not the board's size but how far the client clears its list
// after the rows (`afl_1` 27507: `for n = rows; n < count; ++n list.get(n).clear()`),
// so it is the page size whenever there are rows (stale rows from the previous
// page are cleared) and 0 on an empty board, which the 10-slot list allows
// either way.
func buildTournamentLadder(month, trimester uint8, year uint16, mine [3]int32, wins [3]tournamentLadderWindow) ([]byte, error) {
	w := protocol.NewWriter().U8(month).U8(trimester).U16(year)
	for _, p := range mine {
		w.I32(p)
	}
	for _, win := range wins {
		count := 0
		if len(win.rows) > 0 {
			count = tournamentLadderPage
		}
		w.I32(int32(count)).
			I32(int32(win.start)).
			I32(int32(win.start + len(win.rows))).
			I32(int32(win.myRank))
		for _, e := range win.rows {
			writeLadderString(w, e.Name)
			w.I32(e.Points)
		}
		w.U8(1) // search button enabled
	}
	return protocol.EncodeS2C(protocol.OpTournamentLadder, w.Bytes())
}

// --- Ligue Pro board (27514 -> 27515) ------------------------------------------

// proLeagueIDs are the pro-league definition ids the CLIENT can name: it renders
// the tab's title from i18n group 58 keyed by the league id, and only
// content.58.1 ("Arena Ligue Pro") and content.58.3 ("Ligue des légendes") exist.
// Any other id renders as the raw miss marker "!content.58.N!".
var proLeagueIDs = map[int32]bool{1: true, 3: true}

// defaultProLeagueID is the league reported when the client has no valid selection.
const defaultProLeagueID int32 = 1

// handleProLeagueLadderRequest handles the "Ligue Pro" tab (27514 ck_2):
// [i32 windowStart][i32 leagueId][i32 pageSize]. Replies with 27515 (amu_0).
//
// The pro league is not modelled, so this is a well-formed EMPTY board.
//
// The league id ROUND-TRIPS: the client stores whatever id our reply carries and
// sends it back on the next request (afl_1.dGO is only ever assigned from 27515).
// It starts at 0, and the real league table is pushed by a packet we never send, so
// a bare echo would answer 0 and the tab would be titled "!content.58.0!" — the
// client's raw i18n-miss marker. We therefore normalise an unknown id to the first
// real league, which titles the tab "Arena Ligue Pro" and, because the client keeps
// our value, is self-correcting from then on. A valid selection is preserved.
// This opcode previously had NO handler at all (see B-046).
func handleProLeagueLadderRequest(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	_, _ = r.I32() // window start
	leagueID, err := r.I32()
	if err != nil {
		return err
	}
	if !proLeagueIDs[leagueID] {
		leagueID = defaultProLeagueID
	}

	frame, err := buildProLeagueLadder(leagueID)
	if err != nil {
		return err
	}
	s.log.Debug("pro-league ladder (empty)", "coach", s.Coach.Name, "league", leagueID)
	return s.Send(frame)
}

// buildProLeagueLadder builds PRO_LEAGUE_LADDER (27515 amu_0):
//
//	[i32 total][i32 start][i32 end][i32 myRank][i32 leagueId]
//	(end-start) × {[i32 nameLen][name][i32 guildLen][guild][i16 rating]}
//	[i8 searchButton]
//
// total MUST be 0 here: after filling `end-start` rows the client CLEARS list slots
// from `end-start` up to `total` via list.get(i), so a non-zero total with no rows
// would index past the pre-sized list and throw.
func buildProLeagueLadder(leagueID int32) ([]byte, error) {
	w := protocol.NewWriter().
		I32(0).        // total (also the clear-loop bound — must be 0 when empty)
		I32(0).        // window start
		I32(0).        // window end (= start + rows)
		I32(0).        // my rank
		I32(leagueID). // echoed league id (drives the league name lookup)
		U8(1)          // search button enabled
	return protocol.EncodeS2C(protocol.OpProLeagueLadder, w.Bytes())
}

// writeLadderString writes a ladder string as [i32 len][bytes], the framing every
// ladder reply uses. Delegates to StringU32 so the text goes out in the wire
// charset (cp1252) with a byte-accurate length — a coach name with an accent used
// to be both mangled and mis-counted here.
func writeLadderString(w *protocol.Writer, s string) {
	w.StringU32(s)
}

// guildTagsFor resolves the clan tag for a page of ladder rows in one query.
// Returns an empty (never nil) map so a store without guilds behaves exactly as
// the reserved empty column did.
func (d *Deps) guildTagsFor(rows []store.LadderEntry) map[string]string {
	if d == nil || d.Store == nil || d.Store.Guilds == nil || len(rows) == 0 {
		return map[string]string{}
	}
	names := make([]string, 0, len(rows))
	for _, e := range rows {
		names = append(names, e.Name)
	}
	tags, err := d.Store.Guilds.NamesByCoachName(names)
	if err != nil {
		return map[string]string{}
	}
	return tags
}

// guildLadderRows builds the clan board. Nil (an empty board) when guilds are
// unavailable, which is what this returned before they existed.
func (d *Deps) guildLadderRows() []guildLadderRow {
	if d == nil || d.Store == nil || d.Store.Guilds == nil {
		return nil
	}
	entries, err := d.Store.Guilds.Ladder(ladderPageSize)
	if err != nil {
		return nil
	}
	out := make([]guildLadderRow, 0, len(entries))
	for _, e := range entries {
		out = append(out, guildLadderRow{guild: e.Name, leader: e.Leader, score: e.Score})
	}
	return out
}
