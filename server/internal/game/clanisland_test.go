package game

import (
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/store"
	"github.com/StarLoco/arena-2.70/internal/store/storetest"
)

// TestClanIslandDestResolvesTheGuildsOwnIsland: card 859 is the one Zaap card
// with no fixed destination, so the whole point is that two clans go to
// DIFFERENT worlds and each arrives at that world's own Zaap instance. A fixed
// fallback would satisfy "it teleports somewhere" and be wrong.
func TestClanIslandDestResolvesTheGuildsOwnIsland(t *testing.T) {
	st, err := storetest.Open(t, filepath.Join(t.TempDir(), "island.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })
	d := &Deps{Store: st}

	// A clan reaches its island by SERVING A DEMON and out-giving everyone else
	// serving it - the island is demon N's, not the clan's. Two clans on
	// different demons therefore hold different islands.
	mk := func(login, coachName, guildName string, demon int16) uint {
		t.Helper()
		acc, err := st.Accounts.CreateAccount(login, "secret", false)
		if err != nil {
			t.Fatalf("account: %v", err)
		}
		c, err := st.Coaches.Create(acc.ID, coachName, 1, 2, 0)
		if err != nil {
			t.Fatalf("coach: %v", err)
		}
		g, err := st.Guilds.Create(guildName, c.ID, "Chef", "Membre")
		if err != nil {
			t.Fatalf("guild: %v", err)
		}
		activateClan(t, st, g.ID, guildName)
		if err := st.Guilds.SetDemon(g.ID, demon); err != nil {
			t.Fatalf("affiliate: %v", err)
		}
		if _, err := st.Guilds.AddDemonReputation(g.ID, demon, 100); err != nil {
			t.Fatalf("reputation: %v", err)
		}
		return c.ID
	}
	a := mk("isl_a", "ChefA", "ClanA", 1)
	b := mk("isl_b", "ChefB", "ClanB", 2)

	da, ok := d.clanIslandDest(a)
	if !ok {
		t.Fatal("clan A got no island")
	}
	db, ok := d.clanIslandDest(b)
	if !ok {
		t.Fatal("clan B got no island")
	}
	if da.world == db.world {
		t.Errorf("both clans resolve to world %d", da.world)
	}
	for _, got := range []zaapDest{da, db} {
		want, ok := clanIslandZaap[got.world]
		if !ok {
			t.Fatalf("world %d is not a clan island", got.world)
		}
		if got.instanceID != want {
			t.Errorf("world %d -> instance %d, want %d (docs/OVERWORLD-MAP.md)",
				got.world, got.instanceID, want)
		}
	}
	// Stable across calls: a clan's island must not move under it.
	if again, _ := d.clanIslandDest(a); again.world != da.world {
		t.Errorf("clan A's island moved from %d to %d", da.world, again.world)
	}
}

// TestClanIslandDestRefusesAClanlessCoach: card 859 must do nothing for a coach
// in no clan rather than dropping it on some default island.
func TestClanIslandDestRefusesAClanlessCoach(t *testing.T) {
	st, err := storetest.Open(t, filepath.Join(t.TempDir(), "island2.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })
	d := &Deps{Store: st}

	acc, _ := st.Accounts.CreateAccount("isl_solo", "secret", false)
	c, _ := st.Coaches.Create(acc.ID, "Solo", 1, 2, 0)

	if dest, ok := d.clanIslandDest(c.ID); ok {
		t.Errorf("a clanless coach was sent to world %d", dest.world)
	}
}

// TestClanIslandTableMatchesTheDocumentedZaaps checks the transcription against
// its SOURCE rather than against itself.
//
// The instance ids were copied by hand out of docs/OVERWORLD-MAP.md, and an
// earlier version of this test compared them to the very map it was validating -
// which passes no matter what is in it. Parsing the document makes a typo
// visible; without that, a wrong instance id teleports a clan to a Zaap that is
// not on its island (or does not exist) and nothing catches it before a player
// does.
func TestClanIslandTableMatchesTheDocumentedZaaps(t *testing.T) {
	raw, err := os.ReadFile(filepath.Join("..", "..", "docs", "OVERWORLD-MAP.md"))
	if err != nil {
		t.Skipf("overworld map doc not available: %v", err)
	}
	// Rows carry TWO islands each - | world | inst | cell | alt | world | inst |
	// cell | alt | - and the last row has an EMPTY left half, so the halves are
	// parsed independently rather than with one all-or-nothing pattern. (A regex
	// that demanded digits in the first two cells silently dropped world 109.)
	doc := map[int16]int64{}
	for _, line := range strings.Split(string(raw), "\n") {
		line = strings.TrimSpace(line)
		if !strings.HasPrefix(line, "|") {
			continue
		}
		cells := strings.Split(strings.Trim(line, "|"), "|")
		for i := 0; i+1 < len(cells); i += 4 {
			w, err1 := strconv.Atoi(strings.TrimSpace(cells[i]))
			inst, err2 := strconv.Atoi(strings.TrimSpace(cells[i+1]))
			if err1 != nil || err2 != nil {
				continue
			}
			if int16(w) < store.GuildIslandFirst || int16(w) > store.GuildIslandLast {
				continue
			}
			// World 102 ships two Zaaps; the table lists it twice and the code
			// uses the first, so the second must not overwrite it.
			if _, seen := doc[int16(w)]; !seen {
				doc[int16(w)] = int64(inst)
			}
		}
	}
	if len(doc) != 24 {
		t.Fatalf("parsed %d islands from the doc, want 24 - the table format changed", len(doc))
	}
	if len(clanIslandZaap) != len(doc) {
		t.Errorf("code maps %d islands, doc lists %d", len(clanIslandZaap), len(doc))
	}
	for w, wantInst := range doc {
		got, ok := clanIslandZaap[w]
		if !ok {
			t.Errorf("world %d is documented but missing from the code", w)
			continue
		}
		if got != wantInst {
			t.Errorf("world %d -> instance %d, but the doc says %d", w, got, wantInst)
		}
	}
}

// TestClanIslandCardTracksIslandOwnership: the destination logic is unreachable
// unless the coach actually HOLDS card 859, and nothing grants it - which made
// the whole feature dead on arrival until this was wired.
//
// Granted when the clan holds an island and revoked when it does not, so the Zaap
// dialog never lists a destination that silently does nothing.
func TestClanIslandCardTracksIslandOwnership(t *testing.T) {
	st, err := storetest.Open(t, filepath.Join(t.TempDir(), "card.db"))
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })
	d := &Deps{Store: st, Log: testLogger()}
	s := &Session{deps: d, log: testLogger()}

	acc, _ := st.Accounts.CreateAccount("card_a", "secret", false)
	c, _ := st.Coaches.Create(acc.ID, "Chef", 1, 2, 0)
	g, err := st.Guilds.Create("ClanCarte", c.ID, "Chef", "Membre")
	if err != nil {
		t.Fatalf("guild: %v", err)
	}
	activateClan(t, st, g.ID, "carte")

	has := func() bool {
		for _, card := range c.Inventory {
			if card.TemplateID == clanIslandZaapCard {
				return true
			}
		}
		return false
	}
	owned := func() map[int32]bool {
		m := map[int32]bool{}
		for _, card := range c.Inventory {
			m[card.TemplateID] = true
		}
		return m
	}

	// No demon yet: no island, so no card.
	s.syncClanIslandCard(c, owned())
	if has() {
		t.Fatal("a clan with no island was given the island zaap")
	}

	// Serve a demon and lead it: the card appears.
	if err := st.Guilds.SetDemon(g.ID, 4); err != nil {
		t.Fatalf("affiliate: %v", err)
	}
	if _, err := st.Guilds.AddDemonReputation(g.ID, 4, 100); err != nil {
		t.Fatalf("reputation: %v", err)
	}
	s.syncClanIslandCard(c, owned())
	if !has() {
		t.Fatal("the demon's leading clan was not given the island zaap")
	}

	// A rival out-serves the demon: the island - and the card - move away.
	acc2, _ := st.Accounts.CreateAccount("card_b", "secret", false)
	c2, _ := st.Coaches.Create(acc2.ID, "Rival", 1, 2, 0)
	g2, _ := st.Guilds.Create("ClanRival", c2.ID, "Chef", "Membre")
	activateClan(t, st, g2.ID, "rival")
	if err := st.Guilds.SetDemon(g2.ID, 4); err != nil {
		t.Fatalf("affiliate rival: %v", err)
	}
	if _, err := st.Guilds.AddDemonReputation(g2.ID, 4, 500); err != nil {
		t.Fatalf("reputation rival: %v", err)
	}
	s.syncClanIslandCard(c, owned())
	if has() {
		t.Error("an overtaken clan kept the island zaap - the dialog would offer a dead destination")
	}
}

// activateClan recruits filler members until the clan clears the activity
// threshold. A clan below it is not a contender at all, so without this these
// tests would assert on a clan that can never hold an island.
func activateClan(t *testing.T, st *store.Store, guildID uint, tag string) {
	t.Helper()
	members, err := st.Guilds.Members(guildID)
	if err != nil {
		t.Fatalf("members: %v", err)
	}
	for i := len(members); i < store.GuildActiveMinMembers; i++ {
		suffix := tag + strconv.Itoa(i)
		acc, err := st.Accounts.CreateAccount("filler_"+suffix, "secret", false)
		if err != nil {
			t.Fatalf("filler account: %v", err)
		}
		c, err := st.Coaches.Create(acc.ID, "Filler"+suffix, 1, 2, 0)
		if err != nil {
			t.Fatalf("filler coach: %v", err)
		}
		if err := st.Guilds.AddMember(guildID, c.ID); err != nil {
			t.Fatalf("filler join: %v", err)
		}
	}
}

// TestInactiveClanGetsNoIslandCard is the player-visible end of the activity
// rule: founding a clan alone and dumping cards into a demon must not put the
// island Zaap in your hand, however much reputation it buys.
func TestInactiveClanGetsNoIslandCard(t *testing.T) {
	st, err := storetest.Open(t, filepath.Join(t.TempDir(), "solo.db"))
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })
	s := &Session{deps: &Deps{Store: st, Log: testLogger()}, log: testLogger()}

	acc, _ := st.Accounts.CreateAccount("solo_card", "secret", false)
	c, _ := st.Coaches.Create(acc.ID, "SoloChef", 1, 2, 0)
	g, err := st.Guilds.Create("ClanDUnSeul", c.ID, "Chef", "Membre")
	if err != nil {
		t.Fatalf("guild: %v", err)
	}
	if err := st.Guilds.SetDemon(g.ID, 11); err != nil {
		t.Fatalf("demon: %v", err)
	}
	if _, err := st.Guilds.AddDemonReputation(g.ID, 11, 1_000_000); err != nil {
		t.Fatalf("reputation: %v", err)
	}

	s.syncClanIslandCard(c, map[int32]bool{})
	for _, card := range c.Inventory {
		if card.TemplateID == clanIslandZaapCard {
			t.Fatal("a one-member clan bought the island zaap with reputation alone")
		}
	}

	// Recruiting to the threshold is what actually earns it.
	activateClan(t, st, g.ID, "solocard")
	s.syncClanIslandCard(c, map[int32]bool{})
	found := false
	for _, card := range c.Inventory {
		if card.TemplateID == clanIslandZaapCard {
			found = true
		}
	}
	if !found {
		t.Error("the clan reached the threshold while leading its demon but got no island zaap")
	}
}

// clanIslandWorlds is the set of worlds that are clan islands, derived from the
// demon table rather than restated, so it cannot drift from the allocation.
func clanIslandWorlds() map[int16]bool {
	out := make(map[int16]bool, store.DemonCount)
	for d := int16(1); d <= store.DemonCount; d++ {
		if w, ok := store.IslandWorldForDemon(d); ok {
			out[w] = true
		}
	}
	return out
}

// TestEveryClanIslandHasAReachableZaap is the test that was missing: the island
// allocation, the card grant and the destination table were each correct, and the
// teleport still failed on a live client with "destination zaap missing" because
// worlds 86-109 were not in the generator's policy list, so no element of theirs
// was ever served.
//
// zaapAt is what the handler actually calls, so this asserts the path a teleport
// really takes rather than a table in isolation.
func TestEveryClanIslandHasAReachableZaap(t *testing.T) {
	for demon := int16(1); demon <= store.DemonCount; demon++ {
		world, ok := store.IslandWorldForDemon(demon)
		if !ok {
			t.Fatalf("demon %d has no island world", demon)
		}
		inst, ok := clanIslandZaap[world]
		if !ok {
			t.Errorf("world %d (demon %d) has no clan-island zaap instance", world, demon)
			continue
		}
		z, ok := zaapAt(world, inst)
		if !ok {
			t.Errorf("demon %d's island (world %d, instance %d) has no registered zaap - "+
				"a teleport there is refused as \"destination zaap missing\"", demon, world, inst)
			continue
		}
		if z.cellX == 0 && z.cellY == 0 {
			t.Errorf("world %d zaap sits at the origin, which is not a real cell", world)
		}
	}
}

// TestClanIslandZaapsMatchTheDocumentedTable checks the generated element table
// against docs/OVERWORLD-MAP.md, which recorded these cells by hand from the
// client's env layers. It is the independent oracle for the island worlds, in the
// role goldenWorldElements plays for the eleven original ones.
func TestClanIslandZaapsMatchTheDocumentedTable(t *testing.T) {
	raw, err := os.ReadFile(filepath.Join("..", "..", "docs", "OVERWORLD-MAP.md"))
	if err != nil {
		t.Skipf("docs unavailable: %v", err)
	}
	sec := string(raw)
	i := strings.Index(sec, "### Clan island Zaaps")
	if i < 0 {
		t.Fatal("the Clan island Zaaps section is gone from OVERWORLD-MAP.md")
	}
	sec = sec[i:]
	if j := strings.Index(sec, "\n## "); j > 0 {
		sec = sec[:j]
	}
	// The prose uses typographic minus/dash characters, so world 109's alt is
	// written with U+2212 rather than an ASCII hyphen. Normalise instead of
	// rewriting the document: a regex that quietly skips the one negative altitude
	// in the table is worse than one that understands it.
	sec = strings.NewReplacer("\u2212", "-", "\u2013", "-", "\u2014", "-").Replace(sec)

	// | world | inst | cell | alt | world | inst | cell | alt |  - two islands per
	// row. The delimiting pipes are deliberately NOT matched: the halves share the
	// pipe between them, so anchoring on it consumes the separator and silently
	// finds only the first island of every row.
	row := regexp.MustCompile(`(\d+)\s*\|\s*(\d+)\s*\|\s*\((-?\d+),\s*(-?\d+)\)\s*\|\s*(-?\d+)`)
	n := func(s string) int64 { v, _ := strconv.ParseInt(s, 10, 64); return v }

	documented := 0
	seen := map[int64]bool{}
	for _, m := range row.FindAllStringSubmatch(sec, -1) {
		world, inst := int16(n(m[1])), n(m[2])
		x, y, alt := int32(n(m[3])), int32(n(m[4])), int16(n(m[5]))
		documented++
		seen[inst] = true

		z, ok := zaapAt(world, inst)
		if !ok {
			t.Errorf("world %d instance %d is documented but the server serves no zaap there",
				world, inst)
			continue
		}
		if z.cellX != x || z.cellY != y || z.alt != alt {
			t.Errorf("world %d instance %d: served (%d,%d) alt %d, documented (%d,%d) alt %d",
				world, inst, z.cellX, z.cellY, z.alt, x, y, alt)
		}
	}
	if documented < 25 {
		t.Fatalf("parsed only %d documented island zaaps; the table format changed", documented)
	}

	// And nothing served on an island world is undocumented.
	for world := range clanIslandWorlds() {
		for _, e := range worldElements[world] {
			if e.kind == kindZaap && !seen[e.instanceID] {
				t.Errorf("world %d serves zaap instance %d, which OVERWORLD-MAP.md does not document",
					world, e.instanceID)
			}
		}
	}
}

// TestClanIslandZaapAltitudesMatchTheTopology checks the one field that cannot be
// eyeballed. The arrival `alt` in ENTER_INSTANCE must be the cell's lowest walkable
// altitude, because the client seeds its overworld pathfinder with the coach's cell
// and altitude and needs a walkable layer at exactly that height; when it does not
// match, the coach arrives, renders correctly, and simply cannot walk - no error,
// no packet, nothing to see.
//
// Real-data test: skips when the shipped maps are absent, per repo convention.
func TestClanIslandZaapAltitudesMatchTheTopology(t *testing.T) {
	root := filepath.Join("..", "..", "data-dist")
	if _, err := os.Stat(filepath.Join(root, "maps", "tplg")); err != nil {
		t.Skipf("shipped maps unavailable: %v", err)
	}
	for world := range clanIslandWorlds() {
		topo, err := gamedata.LoadWorldTopology(root, world)
		if err != nil {
			t.Errorf("world %d: topology unavailable: %v", world, err)
			continue
		}
		for _, e := range worldElements[world] {
			if e.kind != kindZaap {
				continue
			}
			got, ok := topo.LowestWalkableAlt(e.cellX, e.cellY)
			if !ok {
				t.Errorf("world %d instance %d: cell (%d,%d) has NO walkable layer - "+
					"a coach arriving there could never move", world, e.instanceID, e.cellX, e.cellY)
				continue
			}
			if got != e.alt {
				t.Errorf("world %d instance %d cell (%d,%d): served alt %d, topology says %d "+
					"- the coach would arrive unable to walk",
					world, e.instanceID, e.cellX, e.cellY, e.alt, got)
			}
		}
	}
}
