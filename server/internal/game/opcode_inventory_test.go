package game

import (
	"fmt"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"testing"
)

// OPCODE-INVENTORY.md is the planning document, and its own header says
// "anything marked `-` is a gap". That makes a stale row worse than a missing
// one: it either invites work that is already done, or reports coverage that
// does not exist. STATUS.md has long declared "the H count must equal the
// r.Register count" as an invariant, but it was hand-counted and had drifted to
// 82 vs 105 - twenty rows still calling implemented opcodes gaps, and three
// handlers with no row at all.
//
// These tests make that invariant machine-checked, in the same spirit as
// internal/config's config_template_test.go (which fails if a config field has
// no key in the shipped template). The C2S direction is checked against the
// router's real handler map rather than against a parallel list, so it cannot
// disagree with what the server actually serves.

const opcodeInventoryPath = "../../docs/OPCODE-INVENTORY.md"

// A row looks like: | 509 | C2S | H | GuildCreate (atM) | `handleGuildCreate` |
// The direction column is required to be a real direction so that numeric rows
// in the document's other tables cannot be mistaken for opcode rows.
var (
	inventoryRowRe = regexp.MustCompile(`^\|\s*\*{0,2}(\d+)\*{0,2}\s*\|([^|]*)\|([^|]*)\|`)
	opcodeConstRe  = regexp.MustCompile(`(?m)^\s*(Op\w+)[^=\n]*=\s*(\d+)`)
)

// inventoryStatuses parses the inventory into opcode -> status cell.
func inventoryStatuses(t *testing.T) map[uint16]string {
	t.Helper()
	raw, err := os.ReadFile(filepath.FromSlash(opcodeInventoryPath))
	if err != nil {
		t.Skipf("OPCODE-INVENTORY.md not readable (%v)", err)
	}
	out := make(map[uint16]string)
	for _, line := range strings.Split(string(raw), "\n") {
		m := inventoryRowRe.FindStringSubmatch(strings.TrimSpace(line))
		if m == nil {
			continue
		}
		switch strings.TrimSpace(m[2]) {
		case "C2S", "S2C", "both":
		default:
			continue
		}
		n, err := strconv.ParseUint(m[1], 10, 16)
		if err != nil {
			continue
		}
		out[uint16(n)] = strings.TrimSpace(strings.ReplaceAll(m[3], "*", ""))
	}
	if len(out) == 0 {
		t.Fatalf("parsed no opcode rows from %s - the table format changed and this "+
			"test would silently pass forever", opcodeInventoryPath)
	}
	return out
}

// registeredOpcodes returns every opcode RegisterAll binds a handler to.
// A zero Deps is enough: registration only takes function references (and
// constructs the guild-invite map), it never dereferences the dependencies.
func registeredOpcodes(t *testing.T) map[uint16]bool {
	t.Helper()
	r := NewRouter(slog.New(slog.NewTextHandler(io.Discard, nil)))
	RegisterAll(r, &Deps{})
	out := make(map[uint16]bool, len(r.handlers))
	for op := range r.handlers {
		out[op] = true
	}
	if len(out) == 0 {
		t.Fatal("RegisterAll bound no handlers")
	}
	return out
}

func TestOpcodeInventoryMarksEveryRegisteredHandler(t *testing.T) {
	status := inventoryStatuses(t)
	var noRow, notMarked []string
	for op := range registeredOpcodes(t) {
		st, ok := status[op]
		if !ok {
			noRow = append(noRow, strconv.Itoa(int(op)))
			continue
		}
		if !strings.Contains(st, "H") {
			notMarked = append(notMarked, fmt.Sprintf("%d (status %q)", op, st))
		}
	}
	sort.Strings(noRow)
	sort.Strings(notMarked)
	if len(noRow) > 0 {
		t.Errorf("%d registered handler(s) have no row in OPCODE-INVENTORY.md: %s",
			len(noRow), strings.Join(noRow, ", "))
	}
	if len(notMarked) > 0 {
		t.Errorf("%d registered handler(s) are not marked H (the document calls them gaps): %s",
			len(notMarked), strings.Join(notMarked, ", "))
	}
}

func TestOpcodeInventoryClaimsNoHandlerWeDoNotHave(t *testing.T) {
	// The dangerous direction: a row marked H with no handler reports coverage
	// that does not exist, so the client's packet is silently dropped by the
	// router while the document says it is served.
	registered := registeredOpcodes(t)
	var phantom []string
	for op, st := range inventoryStatuses(t) {
		if strings.Contains(st, "H") && !registered[op] {
			phantom = append(phantom, strconv.Itoa(int(op)))
		}
	}
	sort.Strings(phantom)
	if len(phantom) > 0 {
		t.Errorf("%d opcode(s) marked H in OPCODE-INVENTORY.md have no registered handler: %s",
			len(phantom), strings.Join(phantom, ", "))
	}
}

func TestOpcodeInventoryMarksEveryEmittedFrame(t *testing.T) {
	// The S2C half cannot be read off a runtime structure the way handlers can,
	// so it is recovered from the source: every EncodeS2C(protocol.OpX) call in
	// the two packages that build frames. Names that do not resolve to a
	// constant are skipped rather than failed - this test polices the document,
	// not the spelling of the source.
	values := opcodeConstValues(t)
	emitted := emittedOpcodes(t, values)
	if len(emitted) == 0 {
		t.Skip("no EncodeS2C call sites found - source layout changed")
	}
	status := inventoryStatuses(t)
	var noRow, notMarked []string
	for op := range emitted {
		st, ok := status[op]
		if !ok {
			noRow = append(noRow, strconv.Itoa(int(op)))
			continue
		}
		if !strings.Contains(st, "E") {
			notMarked = append(notMarked, fmt.Sprintf("%d (status %q)", op, st))
		}
	}
	sort.Strings(noRow)
	sort.Strings(notMarked)
	if len(noRow) > 0 {
		t.Errorf("%d emitted frame(s) have no row in OPCODE-INVENTORY.md: %s",
			len(noRow), strings.Join(noRow, ", "))
	}
	if len(notMarked) > 0 {
		t.Errorf("%d emitted frame(s) are not marked E: %s",
			len(notMarked), strings.Join(notMarked, ", "))
	}
}

// opcodeConstValues maps protocol opcode constant names to their numeric value.
func opcodeConstValues(t *testing.T) map[string]uint16 {
	t.Helper()
	raw, err := os.ReadFile(filepath.FromSlash("../protocol/opcodes.go"))
	if err != nil {
		t.Skipf("opcodes.go not readable (%v)", err)
	}
	out := make(map[string]uint16)
	for _, m := range opcodeConstRe.FindAllStringSubmatch(string(raw), -1) {
		if n, err := strconv.ParseUint(m[2], 10, 16); err == nil {
			out[m[1]] = uint16(n)
		}
	}
	return out
}

var encodeS2CRe = regexp.MustCompile(`EncodeS2C\(\s*protocol\.(Op\w+)`)

// emittedOpcodes scans the packages that build S2C frames for EncodeS2C sites.
func emittedOpcodes(t *testing.T, values map[string]uint16) map[uint16]bool {
	t.Helper()
	out := make(map[uint16]bool)
	for _, dir := range []string{".", "../handshake"} {
		entries, err := os.ReadDir(filepath.FromSlash(dir))
		if err != nil {
			continue
		}
		for _, e := range entries {
			name := e.Name()
			if e.IsDir() || !strings.HasSuffix(name, ".go") || strings.HasSuffix(name, "_test.go") {
				continue
			}
			raw, err := os.ReadFile(filepath.Join(filepath.FromSlash(dir), name))
			if err != nil {
				continue
			}
			for _, m := range encodeS2CRe.FindAllStringSubmatch(string(raw), -1) {
				if v, ok := values[m[1]]; ok {
					out[v] = true
				}
			}
		}
	}
	return out
}

// TestOpcodeInventorySummaryMatchesTable pins the one opcode count the docs
// keep. Three documents used to carry three different hand counts (S08); now
// STATUS.md and COVERAGE.md link to this block and this test recounts it.
func TestOpcodeInventorySummaryMatchesTable(t *testing.T) {
	raw, err := os.ReadFile(filepath.FromSlash(opcodeInventoryPath))
	if err != nil {
		t.Skipf("OPCODE-INVENTORY.md not readable (%v)", err)
	}
	doc := string(raw)
	start := strings.Index(doc, "## Summary counts")
	end := strings.Index(doc, "## Master table")
	if start < 0 || end < start {
		t.Fatal("Summary counts / Master table headings not found")
	}
	claimed := make(map[string]int)
	cellRe := regexp.MustCompile(`^\|([^|]+)\|\s*\**(\d+)\**\s*\|$`)
	for _, line := range strings.Split(doc[start:end], "\n") {
		if m := cellRe.FindStringSubmatch(strings.TrimSpace(line)); m != nil {
			n, _ := strconv.Atoi(m[2])
			claimed[strings.TrimSpace(strings.ReplaceAll(m[1], "*", ""))] = n
		}
	}

	status := inventoryStatuses(t)
	dirs := inventoryDirections(t)
	var h, e, i, x, gap int
	for op, st := range status {
		switch {
		case st == "H+E":
			h++
			e++
		case st == "H":
			h++
		case st == "E":
			e++
		case st == "I":
			i++
		case st == "X":
			x++
		case st == "-":
			gap++
		default:
			t.Errorf("opcode %d (%s): unknown status %q", op, dirs[op], st)
		}
	}
	want := map[string]int{
		"Rows in the master table": len(status),
		"C2S handled (H)":          h,
		"S2C emitted (E)":          e,
		"Inactive (I)":             i,
		"Never implement (X)":      x,
		"Not implemented (-)":      gap,
	}
	for label, n := range want {
		got, ok := claimed[label]
		if !ok {
			t.Errorf("summary has no %q row", label)
			continue
		}
		if got != n {
			t.Errorf("summary %q = %d, the table counts %d", label, got, n)
		}
	}
	if h != len(registeredOpcodes(t)) {
		t.Errorf("H rows = %d, RegisterAll binds %d", h, len(registeredOpcodes(t)))
	}
}

// inventoryDirections maps opcode -> direction cell, for error messages.
func inventoryDirections(t *testing.T) map[uint16]string {
	t.Helper()
	raw, err := os.ReadFile(filepath.FromSlash(opcodeInventoryPath))
	if err != nil {
		t.Skipf("OPCODE-INVENTORY.md not readable (%v)", err)
	}
	out := make(map[uint16]string)
	for _, line := range strings.Split(string(raw), "\n") {
		if m := inventoryRowRe.FindStringSubmatch(strings.TrimSpace(line)); m != nil {
			if n, err := strconv.ParseUint(m[1], 10, 16); err == nil {
				out[uint16(n)] = strings.TrimSpace(m[2])
			}
		}
	}
	return out
}

// TestCoverageAgreesWithInventory: COVERAGE.md is the audit/test matrix and
// lists only some opcodes, but where it lists one, its Impl column must agree
// with the inventory (28612/28614 were "—" there while emitted, S08).
func TestCoverageAgreesWithInventory(t *testing.T) {
	raw, err := os.ReadFile(filepath.FromSlash("../../COVERAGE.md"))
	if err != nil {
		t.Skipf("COVERAGE.md not readable (%v)", err)
	}
	status := inventoryStatuses(t)
	rowRe := regexp.MustCompile(`^\|\s*(\d+)\s*\|[^|]*\|[^|]*\|([^|]*)\|`)
	rows := 0
	for _, line := range strings.Split(string(raw), "\n") {
		m := rowRe.FindStringSubmatch(strings.TrimSpace(line))
		if m == nil {
			continue
		}
		n, err := strconv.ParseUint(m[1], 10, 16)
		if err != nil {
			continue
		}
		rows++
		op := uint16(n)
		impl := strings.HasPrefix(strings.TrimSpace(m[2]), "✓")
		st, ok := status[op]
		if !ok {
			t.Errorf("COVERAGE.md lists %d, which has no inventory row", op)
			continue
		}
		inInventory := strings.ContainsAny(st, "HE")
		if impl != inInventory {
			t.Errorf("opcode %d: COVERAGE Impl %q, inventory status %q", op,
				strings.TrimSpace(m[2]), st)
		}
	}
	if rows == 0 {
		t.Fatal("parsed no opcode rows from COVERAGE.md")
	}
}
