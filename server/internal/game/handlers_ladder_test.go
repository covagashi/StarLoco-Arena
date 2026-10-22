package game

import (
	"encoding/binary"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store"
)

// ladderCur is a big-endian cursor that mimics the client's ael_2 decoder. It
// tracks position so a test can assert the client would consume EXACTLY the whole
// payload — the property that separates a rendering list from a blank one (the
// client loops on a row count and reads with no bounds check, so an over- or
// under-stated count leaves the panel empty).
type ladderCur struct {
	b   []byte
	i   int
	t   *testing.T
	err bool
}

func (c *ladderCur) i32() int32 {
	if c.i+4 > len(c.b) {
		c.err = true
		c.t.Fatalf("read i32 past end at %d of %d", c.i, len(c.b))
	}
	v := int32(binary.BigEndian.Uint32(c.b[c.i:]))
	c.i += 4
	return v
}

func (c *ladderCur) i16() int16 {
	if c.i+2 > len(c.b) {
		c.err = true
		c.t.Fatalf("read i16 past end at %d of %d", c.i, len(c.b))
	}
	v := int16(binary.BigEndian.Uint16(c.b[c.i:]))
	c.i += 2
	return v
}

func (c *ladderCur) u8() uint8 {
	if c.i+1 > len(c.b) {
		c.err = true
		c.t.Fatalf("read u8 past end at %d of %d", c.i, len(c.b))
	}
	v := c.b[c.i]
	c.i++
	return v
}

// str reads [i32 len][utf8], the ladder string encoding.
func (c *ladderCur) str() string {
	n := int(c.i32())
	if n < 0 || c.i+n > len(c.b) {
		c.err = true
		c.t.Fatalf("string len %d past end at %d of %d", n, c.i, len(c.b))
	}
	s := string(c.b[c.i : c.i+n])
	c.i += n
	return s
}

// done asserts the cursor consumed the whole payload — no trailing bytes (would
// mean the client under-reads and later frames desync) and no overrun (asserted
// per-read). This is the core invariant for every ladder reply.
func (c *ladderCur) done() {
	if c.i != len(c.b) {
		c.t.Errorf("client would consume %d of %d payload bytes", c.i, len(c.b))
	}
}

// payloadOf strips the [u16 len][u16 opcode] header, asserting the opcode.
func payloadOf(t *testing.T, frame []byte, wantOp uint16) []byte {
	t.Helper()
	if len(frame) < 4 {
		t.Fatalf("frame too short: %d bytes", len(frame))
	}
	if op := binary.BigEndian.Uint16(frame[2:4]); op != wantOp {
		t.Fatalf("opcode = %d, want %d", op, wantOp)
	}
	return frame[4:]
}

// TestLadder1v1RowContract is the load-bearing test: the client loops
// `for j < (windowEnd - windowStart)`, so windowEnd must equal windowStart +
// len(rows) and every row must be exactly the right shape, or the client reads
// past the buffer and the whole list stays blank.
func TestLadder1v1RowContract(t *testing.T) {
	rows := []store.LadderEntry{
		{Name: "Alice", Strength: 1500, StatWins: 10, StatLosses: 3, ConsecutiveWins: 4},
		{Name: "Bob", Strength: 1200, StatWins: 5, StatLosses: 8, ConsecutiveWins: 0},
	}
	frame, err := buildLadderResponse(42, 20, rows, 21, map[string]string{"Alice": "Les Bouftous"})
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	c := &ladderCur{b: payloadOf(t, frame, protocol.OpLadderResponse), t: t}

	if got := c.i32(); got != 42 {
		t.Errorf("total = %d, want 42", got)
	}
	start := c.i32()
	end := c.i32()
	if start != 20 || end != 22 {
		t.Errorf("window = [%d,%d), want [20,22) (end must be start+rows)", start, end)
	}
	if got := c.i32(); got != 21 {
		t.Errorf("myRank = %d, want 21", got)
	}
	for j := int32(0); j < end-start; j++ { // the client's exact loop
		name := c.str()
		// The clan tag column: reserved and always empty until guilds existed,
		// now carrying the coach's clan. Asserted per row because a tag attached
		// to the WRONG row is the failure mode that looks fine in aggregate.
		guild := c.str()
		wantGuild := ""
		if name == "Alice" {
			wantGuild = "Les Bouftous"
		}
		if guild != wantGuild {
			t.Errorf("row %s: clan tag = %q, want %q", name, guild, wantGuild)
		}
		rating := c.i16()
		c.i32()           // discarded
		c.i32()           // discarded
		streak := c.i32() // consecutive victories
		c.i32()           // discarded
		wins := c.i32()
		losses := c.i32()
		want := rows[j]
		if name != want.Name {
			t.Errorf("row %d name = %q, want %q", j, name, want.Name)
		}
		if int32(rating) != want.Strength {
			t.Errorf("row %d rating = %d, want %d", j, rating, want.Strength)
		}
		if streak != want.ConsecutiveWins || wins != want.StatWins || losses != want.StatLosses {
			t.Errorf("row %d stats = (streak %d, wins %d, losses %d), want (%d,%d,%d)",
				j, streak, wins, losses, want.ConsecutiveWins, want.StatWins, want.StatLosses)
		}
	}
	if c.u8() != 1 {
		t.Error("search-button flag should be 1")
	}
	c.done()
}

// TestLadder1v1EmptyIsWellFormed: an empty board must still render (17 bytes, zero
// rows) rather than blank-with-error.
func TestLadder1v1EmptyIsWellFormed(t *testing.T) {
	frame, err := buildLadderResponse(0, 0, nil, 0, nil)
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	p := payloadOf(t, frame, protocol.OpLadderResponse)
	if len(p) != 4*4+1 {
		t.Fatalf("empty 1v1 payload = %d bytes, want 17", len(p))
	}
	c := &ladderCur{b: p, t: t}
	if c.i32() != 0 || c.i32() != 0 || c.i32() != 0 || c.i32() != 0 {
		t.Error("empty header should be all zeros")
	}
	c.u8()
	c.done()
}

// TestGuildLadderBoardIsOne: the client (ij_1) skips the whole clan list unless
// the echoed board == 1, so the empty guild reply must still carry board 1.
func TestGuildLadderBoardIsOne(t *testing.T) {
	frame, err := buildGuildLadder(0, nil)
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	c := &ladderCur{b: payloadOf(t, frame, protocol.OpGuildLadder), t: t}
	if got := c.i16(); got != 1 {
		t.Errorf("guild board = %d, want 1 (else the client shows nothing)", got)
	}
	if c.i32() != 0 { // windowStart
		t.Error("windowStart should be 0")
	}
	if got := c.i32(); got != 0 { // row count
		t.Errorf("row count = %d, want 0 (no guilds)", got)
	}
	c.done()
}

// TestGuildLadderRows proves the row layout (clan name + leader + score) even
// though production sends none — guards the format for when guilds land.
func TestGuildLadderRows(t *testing.T) {
	rows := []guildLadderRow{
		{guild: "Bworks", leader: "Kerub", score: 900},
		{guild: "Brakmar", leader: "Oto", score: 700},
	}
	frame, _ := buildGuildLadder(0, rows)
	c := &ladderCur{b: payloadOf(t, frame, protocol.OpGuildLadder), t: t}
	c.i16() // board
	c.i32() // start
	if got := c.i32(); got != 2 {
		t.Fatalf("row count = %d, want 2", got)
	}
	for _, want := range rows {
		if g, l, sc := c.str(), c.str(), c.i32(); g != want.guild || l != want.leader || sc != want.score {
			t.Errorf("row = (%q,%q,%d), want (%q,%q,%d)", g, l, sc, want.guild, want.leader, want.score)
		}
	}
	c.done()
}

// TestLadder2v2EmptyIsWellFormed: the 2v2 reply ends with an i32 flag (NOT the u8
// the 1v1 reply uses); the empty form must be exactly 5 i32s.
func TestLadder2v2EmptyIsWellFormed(t *testing.T) {
	frame, err := build2v2Ladder(0, 0, nil, nil)
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	p := payloadOf(t, frame, protocol.OpLadder2v2Response)
	if len(p) != 5*4 {
		t.Fatalf("empty 2v2 payload = %d bytes, want 20", len(p))
	}
	c := &ladderCur{b: p, t: t}
	total, start, end, iconCount := c.i32(), c.i32(), c.i32(), c.i32()
	if total != 0 || start != 0 || end != 0 || iconCount != 0 {
		t.Errorf("empty header = (%d,%d,%d,%d), want zeros", total, start, end, iconCount)
	}
	if c.i32() != 1 {
		t.Error("trailing search flag (i32) should be 1")
	}
	c.done()
}

// TestCoachReputationEmpty: the Coach reputation tab (27509) is a derived-count
// window (like 27501) ending in a u8 flag; the empty form must be exactly 17
// bytes and fully consumed.
func TestCoachReputationEmpty(t *testing.T) {
	frame, err := buildCoachReputation(0, nil)
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	p := payloadOf(t, frame, protocol.OpCoachReputation)
	if len(p) != 4*4+1 {
		t.Fatalf("empty coach-reputation payload = %d bytes, want 17", len(p))
	}
	c := &ladderCur{b: p, t: t}
	total, start, end := c.i32(), c.i32(), c.i32()
	if total != 0 || start != 0 || end != 0 {
		t.Errorf("header = (%d,%d,%d), want zeros", total, start, end)
	}
	if idx := c.i32(); idx != -1 {
		t.Errorf("localCoachIdx = %d, want -1 (no self row)", idx)
	}
	c.u8() // search flag
	c.done()
}

// TestCoachReputationRows proves the full row layout even though production sends
// none — guards the format for when reputation lands.
func TestCoachReputationRows(t *testing.T) {
	rows := []coachReputationRow{
		{reputation: 1200, coach: "Kro", team: "Duo", wins: 9, losses: 2, guild: "Bworks", demonID: 7},
	}
	frame, _ := buildCoachReputation(0, rows)
	c := &ladderCur{b: payloadOf(t, frame, protocol.OpCoachReputation), t: t}
	if total, start, end := c.i32(), c.i32(), c.i32(); total != 1 || start != 0 || end != 1 {
		t.Errorf("header = (%d,%d,%d), want (1,0,1)", total, start, end)
	}
	c.i32() // localIdx
	if rep := c.i32(); rep != 1200 {
		t.Errorf("reputation = %d, want 1200", rep)
	}
	if coach, team := c.str(), c.str(); coach != "Kro" || team != "Duo" {
		t.Errorf("names = (%q,%q)", coach, team)
	}
	if w, l := c.i32(), c.i32(); w != 9 || l != 2 {
		t.Errorf("W/L = %d/%d, want 9/2", w, l)
	}
	if guild := c.str(); guild != "Bworks" {
		t.Errorf("guild = %q, want Bworks", guild)
	}
	if d := c.i16(); d != 7 {
		t.Errorf("demonId = %d, want 7", d)
	}
	c.u8()
	c.done()
}

// TestDemonListRoster: the Démon tab (27513) lists the 24 demons a page of 12 at
// a time, with the leading status flag == 1 so the client populates rows.
func TestDemonListRoster(t *testing.T) {
	// Page 1: demons 1..12.
	frame, err := buildDemonList(0)
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	c := &ladderCur{b: payloadOf(t, frame, protocol.OpDemonList), t: t}
	if flag := c.i16(); flag != 1 {
		t.Errorf("status flag = %d, want 1 (else the client shows nothing)", flag)
	}
	if start := c.i32(); start != 0 {
		t.Errorf("start = %d, want 0", start)
	}
	if count := c.i32(); count != 12 {
		t.Fatalf("count = %d, want 12", count)
	}
	for i := 0; i < 12; i++ {
		id := c.i16()
		if int(id) != i+1 {
			t.Errorf("row %d demonId = %d, want %d", i, id, i+1)
		}
		if pts := c.i64(); pts != 0 {
			t.Errorf("row %d reputation = %d, want 0", i, pts)
		}
		if g := c.str(); g != "" {
			t.Errorf("row %d guild = %q, want empty", i, g)
		}
	}
	c.done()

	// Last page (start 12): demons 13..24.
	c = &ladderCur{b: payloadOf(t, mustBuildDemonList(t, 12), protocol.OpDemonList), t: t}
	c.i16()
	if start := c.i32(); start != 12 {
		t.Errorf("start = %d, want 12", start)
	}
	if count := c.i32(); count != 12 {
		t.Fatalf("count = %d, want 12", count)
	}
	if first := c.i16(); first != 13 {
		t.Errorf("first demon on page 2 = %d, want 13", first)
	}

	// Past the end: zero rows, still well-formed.
	c = &ladderCur{b: payloadOf(t, mustBuildDemonList(t, 24), protocol.OpDemonList), t: t}
	c.i16()
	c.i32()
	if count := c.i32(); count != 0 {
		t.Errorf("count past end = %d, want 0", count)
	}
	c.done()
}

func (c *ladderCur) i64() int64 {
	if c.i+8 > len(c.b) {
		c.err = true
		c.t.Fatalf("read i64 past end at %d of %d", c.i, len(c.b))
	}
	v := int64(binary.BigEndian.Uint64(c.b[c.i:]))
	c.i += 8
	return v
}

func mustBuildDemonList(t *testing.T, start int) []byte {
	t.Helper()
	f, err := buildDemonList(start)
	if err != nil {
		t.Fatalf("buildDemonList(%d): %v", start, err)
	}
	return f
}

// TestLadder2v2Rows proves the full 2v2 row layout, including the icon list and
// the i32 trailing flag.
func TestLadder2v2Rows(t *testing.T) {
	rows := []teamLadderRow{
		{coaches: "Ann-Bo", team: "Duo", guild: "", rating: 1800, streak: 6, wins: 12, losses: 2},
	}
	frame, _ := build2v2Ladder(1, 10, rows, []int32{7, 8})
	c := &ladderCur{b: payloadOf(t, frame, protocol.OpLadder2v2Response), t: t}
	if c.i32() != 1 {
		t.Error("total")
	}
	start, end := c.i32(), c.i32()
	if start != 10 || end != 11 {
		t.Errorf("window = [%d,%d), want [10,11)", start, end)
	}
	if got := c.i32(); got != 2 {
		t.Fatalf("icon count = %d, want 2", got)
	}
	c.i32()
	c.i32() // two icons
	for j := int32(0); j < end-start; j++ {
		coaches, team, guild := c.str(), c.str(), c.str()
		rating := c.i16()
		c.i32()
		c.i32()
		streak := c.i32()
		c.i32()
		wins := c.i32()
		losses := c.i32()
		w := rows[j]
		if coaches != w.coaches || team != w.team || guild != w.guild {
			t.Errorf("row %d strings = (%q,%q,%q)", j, coaches, team, guild)
		}
		if int32(rating) != int32(w.rating) || streak != w.streak || wins != w.wins || losses != w.losses {
			t.Errorf("row %d nums = (%d,%d,%d,%d)", j, rating, streak, wins, losses)
		}
	}
	if c.i32() != 1 {
		t.Error("trailing search flag")
	}
	c.done()
}

// TestTournamentLadderEmptyIsWellFormed: the "Tournoi" tab (27507 uj_0) carries
// THREE windows in one message (month/trimester/year). The client decodes them
// back-to-back with no bounds check and indexes a PRE-SIZED list per row, so the
// empty form must be exactly 67 bytes with every count zero, and it must echo the
// period selectors so the tab keeps the state the player picked.
//
// Regression guard for B-046: this tab previously received NO reply and rendered
// blank because it was mislabelled a "seasonal" board.
func TestTournamentLadderEmptyIsWellFormed(t *testing.T) {
	frame, err := buildTournamentLadder(3, 1, 2026, [3]int32{}, [3]tournamentLadderWindow{})
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	p := payloadOf(t, frame, protocol.OpTournamentLadder)
	// [i8 m][i8 t][i16 y] + 3*i32 points + 3 * ([4*i32] + [i8]) = 4 + 12 + 51.
	if len(p) != 4+12+3*17 {
		t.Fatalf("payload = %d bytes, want 67", len(p))
	}
	c := &ladderCur{b: p, t: t}
	if m := c.u8(); m != 3 {
		t.Errorf("month = %d, want 3 (echoed)", m)
	}
	if tr := c.u8(); tr != 1 {
		t.Errorf("trimester = %d, want 1 (echoed)", tr)
	}
	if y := c.i16(); y != 2026 {
		t.Errorf("year = %d, want 2026 (echoed)", y)
	}
	for i := 0; i < 3; i++ {
		if pts := c.i32(); pts != 0 {
			t.Errorf("my points[%d] = %d, want 0", i, pts)
		}
	}
	for blk := 0; blk < 3; blk++ {
		if total := c.i32(); total != 0 {
			t.Errorf("block %d total = %d, want 0", blk, total)
		}
		start, end := c.i32(), c.i32()
		if end != start {
			t.Errorf("block %d window = [%d,%d), want end==start so the client reads 0 rows", blk, start, end)
		}
		c.i32() // my rank
		c.u8()  // search button
	}
	c.done()
}

// TestProLeagueLadderEmptyIsWellFormed: the "Ligue Pro" tab (27515 amu_0). total
// is not just a row count - after filling rows the client CLEARS list slots from
// (end-start) up to total via list.get(i), so a non-zero total with no rows would
// index past the pre-sized list and throw. The league id must be echoed because it
// drives the league-name lookup.
//
// Regression guard for B-046: 27514 previously had no handler at all.
func TestProLeagueLadderEmptyIsWellFormed(t *testing.T) {
	frame, err := buildProLeagueLadder(7)
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	p := payloadOf(t, frame, protocol.OpProLeagueLadder)
	if len(p) != 5*4+1 {
		t.Fatalf("payload = %d bytes, want 21", len(p))
	}
	c := &ladderCur{b: p, t: t}
	if total := c.i32(); total != 0 {
		t.Errorf("total = %d, want 0 (it bounds the client clear loop)", total)
	}
	start, end := c.i32(), c.i32()
	if end != start {
		t.Errorf("window = [%d,%d), want end==start", start, end)
	}
	c.i32() // my rank
	if id := c.i32(); id != 7 {
		t.Errorf("league id = %d, want 7 (echoed)", id)
	}
	c.u8() // search button
	c.done()
}
