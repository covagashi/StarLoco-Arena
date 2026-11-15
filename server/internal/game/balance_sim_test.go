package game

import (
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"math"
	"os"
	"path/filepath"
	"sort"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/store/storetest"
)

// balance_sim_test.go: S40's AI-against-AI check, slow, run on demand:
//
//	S40_SIM=40 go test ./internal/game/ -run TestBalanceSim -v -timeout 60m
//
// (the number is the fights per matchup). It plays full offline fights (the
// S29 tournament path) between mirrored teams, so only the gear differs, and
// prints a report: does a fighter card's budget cost (its Value, what the
// league caps) follow what it adds to winning?
//
// Limits: the AI never plays a fighter card's weapon attack (closeCombatAI is
// the generic close combat), so a weapon is measured by its passive bonuses
// only; and the breeds are fixed (breed balance is S46).

var simBreeds = []uint8{8, 9, 1} // Iop, Cra, Feca: a hitter, a ranged, a tank

func simDeps(t *testing.T) *Deps {
	t.Helper()
	b := gamedata.LoadBundle(gamedata.Discover(filepath.Join("..", "..", "data-dist")),
		slog.New(slog.NewTextHandler(io.Discard, nil)))
	if b.Spells == nil {
		t.Skip("no game data")
	}
	st, err := storetest.Open(t, filepath.Join(t.TempDir(), "sim.db"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = st.Close() })
	d := &Deps{Store: st, Log: slog.New(slog.NewTextHandler(io.Discard, nil)),
		Fights: NewFightManager(), World: NewRegistry(50)}
	d.UseGameData(b)
	return d
}

// simTeam is a ghost of simBreeds; the first `wearers` fighters wear gear
// (card ids), the rest fight naked.
func simTeam(d *Deps, id uint, gear []int32, wearers int) *domain.GhostTeam {
	var roster []domain.Fighter
	for i, br := range simBreeds {
		fr := domain.Fighter{Name: fighterBreedName(br), BreedID: br,
			Spells: breedSpellRepertoire(d.Spells, br)}
		for _, cid := range gear {
			if fc := d.FighterCards.Get(cid); fc != nil && i < wearers {
				fr.Objects = append(fr.Objects, domain.FighterObject{TemplateID: cid, Slot: int16(fc.Type) - 1})
			}
		}
		roster = append(roster, fr)
	}
	js, _ := json.Marshal(roster)
	return &domain.GhostTeam{ID: id, Name: fmt.Sprint(id), Roster: string(js)}
}

// simRounds/simFights add up every simulated fight's length, for the report.
var simRounds, simFights, simCapped int

// winRate plays n fights, sides alternating, and returns how often a won.
func winRate(t *testing.T, d *Deps, a, b *domain.GhostTeam, n int) float64 {
	t.Helper()
	wins := 0.0
	played := 0
	for i := 0; i < n; i++ {
		x, y := a, b
		if i%2 == 1 {
			x, y = b, a
		}
		m, err := d.runOfflineMatch(x, y, "a", "b")
		if err != nil || m == nil {
			continue
		}
		played++
		simRounds += int(m.Rounds)
		simFights++
		if m.Rounds > offlineRoundCap {
			simCapped++
		}
		aSide := uint(0)
		if i%2 == 1 {
			aSide = 1
		}
		if m.WinnerCoachID == aSide {
			wins++
		}
	}
	if played == 0 {
		return math.NaN()
	}
	return wins / float64(played)
}

// initiativeOf is the initiative a card gives: Bonus.Init (which already sums
// the 76 gains) less its 77 losses.
func initiativeOf(fc *gamedata.FighterCard) int32 {
	v := fc.Bonus.Init
	for _, e := range fc.EquipEffects {
		if len(e.Params) > 0 && e.ActionID == 77 {
			v -= int32(math.Abs(float64(e.Params[0])))
		}
	}
	return v
}

// withoutInitiative copies the catalogue with every initiative bonus removed.
func withoutInitiative(src *gamedata.FighterCards) *gamedata.FighterCards {
	var out []*gamedata.FighterCard
	for _, fc := range src.All() {
		c := *fc
		c.Bonus.Init = 0
		c.EquipEffects = nil
		for _, e := range fc.EquipEffects {
			if e.ActionID != 76 && e.ActionID != 77 {
				c.EquipEffects = append(c.EquipEffects, e)
			}
		}
		out = append(out, &c)
	}
	return gamedata.NewFighterCards(out...)
}

func TestBalanceSim(t *testing.T) {
	n := 0
	fmt.Sscan(os.Getenv("S40_SIM"), &n)
	if n <= 0 {
		t.Skip("set S40_SIM=<fights per matchup> to run the balance simulation")
	}
	d := simDeps(t)
	all := len(simBreeds)
	naked := simTeam(d, 1, nil, 0)

	// 0. the mirror: with nothing different, about 50 %.
	t.Logf("mirror (naked vs naked): %.2f", winRate(t, d, simTeam(d, 2, nil, 0), naked, n))

	// 0b. turn order: the pure-initiative cards on all three (88 -30, 89 +30,
	// 164 +60, 162 +80), against the naked mirror.
	for _, id := range []int32{88, 89, 164, 162} {
		if fc := d.FighterCards.Get(id); fc != nil {
			t.Logf("initiative %+d on all three (card %d): %.2f", initiativeOf(fc), id,
				winRate(t, d, simTeam(d, 2, []int32{id}, all), naked, n))
		}
	}

	// From here on initiative is taken off every card, so the turn order
	// stays the mirror's and a card is measured by everything else it gives.
	d.FighterCards = withoutInitiative(d.FighterCards)

	// 1. each fighter card worn by ONE fighter (the Iop) against the naked
	// mirror; on all three nearly every card wins nearly always.
	type row struct {
		id    int32
		value int32
		wr    float64
		desc  string
	}
	var rows []row
	for id, fc := range d.FighterCards.All() {
		wr := winRate(t, d, simTeam(d, 2, []int32{id}, 1), naked, n)
		if math.IsNaN(wr) {
			continue
		}
		desc := fmt.Sprintf("type %d", fc.Type)
		if fc.Usable() {
			desc += " weapon (attack not played by the AI)"
		}
		rows = append(rows, row{id, fc.Value, wr, desc})
	}
	sort.Slice(rows, func(i, j int) bool { return rows[i].id < rows[j].id })

	// win-rate uplift against value: Pearson r, and the least-squares line
	var sx, sy, sxx, syy, sxy float64
	for _, r := range rows {
		x, y := float64(r.value), r.wr-0.5
		sx += x
		sy += y
		sxx += x * x
		syy += y * y
		sxy += x * y
	}
	k := float64(len(rows))
	slope := (k*sxy - sx*sy) / (k*sxx - sx*sx)
	icpt := (sy - slope*sx) / k
	corr := (k*sxy - sx*sy) / math.Sqrt((k*sxx-sx*sx)*(k*syy-sy*sy))
	t.Logf("cards: %d, %d fights each; uplift vs value: r = %.2f, +%.1f points of win rate per 100 budget",
		len(rows), n, corr, slope*100*100)
	sort.Slice(rows, func(i, j int) bool {
		ri := rows[i].wr - 0.5 - (icpt + slope*float64(rows[i].value))
		rj := rows[j].wr - 0.5 - (icpt + slope*float64(rows[j].value))
		return ri > rj
	})
	t.Log("| card | value | win rate vs naked | expected by value | note |")
	for _, r := range rows {
		t.Logf("| %d | %d | %.2f | %.2f | %s |", r.id, r.value, r.wr, 0.5+icpt+slope*float64(r.value), r.desc)
	}

	// 2. the league cap at work: a full bronze team against a full diamond
	// one is what the leagues keep apart.
	var cheap, dear []int32
	bySlot := map[int16][]*gamedata.FighterCard{}
	for _, fc := range d.FighterCards.All() {
		bySlot[fc.Type] = append(bySlot[fc.Type], fc)
	}
	for _, l := range bySlot {
		sort.Slice(l, func(i, j int) bool { return l[i].Value < l[j].Value || l[i].Value == l[j].Value && l[i].ID < l[j].ID })
		cheap = append(cheap, l[0].ID)
		dear = append(dear, l[len(l)-1].ID)
	}
	t.Logf("dearest gear vs cheapest gear (both sides full): %.2f",
		winRate(t, d, simTeam(d, 2, dear, all), simTeam(d, 3, cheap, all), n))
	t.Logf("%d fights, %.1f rounds on average, %d decided by the round cap (HP left)",
		simFights, float64(simRounds)/float64(max(simFights, 1)), simCapped)
}
