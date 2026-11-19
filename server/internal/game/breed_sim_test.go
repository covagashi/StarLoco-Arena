package game

import (
	"encoding/json"
	"fmt"
	"math"
	"os"
	"slices"
	"sort"
	"strings"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// breed_sim_test.go: S46 phase D, class against class, on demand:
//
//	S46_BREEDS=100 go test ./internal/game/ -run TestBreedSim -v -timeout 60m
//
// Two measures, AI against AI (the S29 tournament path), sides alternating:
//   - duels: one fighter of each class against one of each other class;
//   - trios: the class alongside a fixed Iop + Cra, against the same pair
//     with each other class, so a class is seen in a team.
//
// Each class fights naked with simKit: its dearest creature, its best heal,
// then its damaging spells (breedSpellRepertoire), six at most — what a
// player would take, where ghosts and challenges carry only the damage.

var simAllBreeds = []uint8{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}

// simKit is a class's six spells for the simulation (see the file header).
func simKit(d *Deps, br uint8) []domain.FighterSpell {
	var summon, heal *gamedata.Spell
	for _, sp := range d.Spells.All() {
		if sp == nil || sp.BreedID != int32(br) || sp.AP <= 0 {
			continue
		}
		if aiSpellSummons(sp) && (summon == nil || sp.AP > summon.AP || sp.AP == summon.AP && sp.ID < summon.ID) {
			summon = sp
		}
		if aiSpellHealsAlly(sp) && (heal == nil || sp.ID < heal.ID) {
			heal = sp
		}
	}
	drop := map[int32]bool{} // S46_DROP=69,73: leave these out (to see what a spell weighs)
	for _, f := range strings.Split(os.Getenv("S46_DROP"), ",") {
		var v int32
		if _, err := fmt.Sscan(f, &v); err == nil {
			drop[v] = true
		}
	}
	if summon != nil && drop[summon.ID] {
		summon = nil
	}
	if heal != nil && drop[heal.ID] {
		heal = nil
	}
	var ids []int32
	for _, sp := range []*gamedata.Spell{summon, heal} {
		if sp != nil {
			ids = append(ids, sp.ID)
		}
	}
	for _, s := range breedSpellRepertoire(d.Spells, br) {
		if len(ids) < maxLoadoutSpells && !slices.Contains(ids, s.SpellID) && !drop[s.SpellID] {
			ids = append(ids, s.SpellID)
		}
	}
	out := make([]domain.FighterSpell, len(ids))
	for i, id := range ids {
		out[i] = domain.FighterSpell{Slot: int16(i), SpellID: id}
	}
	return out
}

func breedTeam(d *Deps, id uint, breeds ...uint8) *domain.GhostTeam {
	var roster []domain.Fighter
	for _, br := range breeds {
		roster = append(roster, domain.Fighter{Name: fighterBreedName(br), BreedID: br,
			Spells: simKit(d, br)})
	}
	js, _ := json.Marshal(roster)
	return &domain.GhostTeam{ID: id, Name: fmt.Sprint(id), Roster: string(js)}
}

// breedMatrix plays every pair once (n fights) and returns wr[a][b], how
// often a beats b, with team(x) building the side for class x.
func breedMatrix(t *testing.T, d *Deps, n int, team func(id uint, br uint8) *domain.GhostTeam) map[uint8]map[uint8]float64 {
	wr := map[uint8]map[uint8]float64{}
	for _, a := range simAllBreeds {
		wr[a] = map[uint8]float64{}
	}
	only := map[uint8]bool{} // S46_ONLY=4,10: just the pairs with these classes
	for _, f := range strings.Split(os.Getenv("S46_ONLY"), ",") {
		var v int
		if _, err := fmt.Sscan(f, &v); err == nil {
			only[uint8(v)] = true
		}
	}
	for i, a := range simAllBreeds {
		wr[a][a] = 0.5
		for _, b := range simAllBreeds[i+1:] {
			if len(only) > 0 && !only[a] && !only[b] {
				wr[a][b], wr[b][a] = math.NaN(), math.NaN()
				continue
			}
			w := winRate(t, d, team(1, a), team(2, b), n)
			wr[a][b], wr[b][a] = w, 1-w
		}
	}
	return wr
}

func logBreedMatrix(t *testing.T, title string, wr map[uint8]map[uint8]float64) {
	t.Logf("%s — row beats column", title)
	var head strings.Builder
	head.WriteString("| |")
	for _, b := range simAllBreeds {
		fmt.Fprintf(&head, " %d |", b)
	}
	head.WriteString(" mean |")
	t.Log(head.String())
	type avg struct {
		br uint8
		v  float64
	}
	var avgs []avg
	for _, a := range simAllBreeds {
		var row strings.Builder
		fmt.Fprintf(&row, "| %d %s |", a, fighterBreedName(a))
		sum := 0.0
		for _, b := range simAllBreeds {
			fmt.Fprintf(&row, " %.2f |", wr[a][b])
			if a != b && !math.IsNaN(wr[a][b]) {
				sum += wr[a][b]
			}
		}
		k := 0
		for _, b := range simAllBreeds {
			if a != b && !math.IsNaN(wr[a][b]) {
				k++
			}
		}
		m := sum / float64(max(k, 1))
		fmt.Fprintf(&row, " **%.2f** |", m)
		t.Log(row.String())
		avgs = append(avgs, avg{a, m})
	}
	sort.Slice(avgs, func(i, j int) bool { return avgs[i].v > avgs[j].v })
	var rank strings.Builder
	for _, x := range avgs {
		fmt.Fprintf(&rank, "%s %.2f, ", fighterBreedName(x.br), x.v)
	}
	t.Logf("%s ranking: %s", title, strings.TrimSuffix(rank.String(), ", "))
}

func TestBreedSim(t *testing.T) {
	n := 0
	fmt.Sscan(os.Getenv("S46_BREEDS"), &n)
	if n <= 0 {
		t.Skip("set S46_BREEDS=<fights per pair>")
	}
	d := simDeps(t)
	for _, b := range simAllBreeds {
		var ids []int32
		for _, s := range simKit(d, b) {
			ids = append(ids, s.SpellID)
		}
		t.Logf("class %d %s plays %v", b, fighterBreedName(b), ids)
	}
	simRounds, simFights, simCapped = 0, 0, 0
	logBreedMatrix(t, "duels", breedMatrix(t, d, n, func(id uint, br uint8) *domain.GhostTeam {
		return breedTeam(d, id, br)
	}))
	t.Logf("duels: %d fights, %.1f rounds on average, %d by the round cap",
		simFights, float64(simRounds)/float64(max(simFights, 1)), simCapped)
	simRounds, simFights, simCapped = 0, 0, 0
	logBreedMatrix(t, "trios (+ Iop + Cra)", breedMatrix(t, d, n, func(id uint, br uint8) *domain.GhostTeam {
		return breedTeam(d, id, br, 8, 9)
	}))
	t.Logf("trios: %d fights, %.1f rounds on average, %d by the round cap",
		simFights, float64(simRounds)/float64(max(simFights, 1)), simCapped)
}
