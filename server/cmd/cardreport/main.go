// Command cardreport measures the game's own cards (S40 step 2): what each
// fighter-card stat costs in budget, which cards are cheap or dear for what
// they give, what the coach cards do by rank, and how many wins a card costs.
//
//	go run ./cmd/cardreport [content dir]   (default: the embedded content)
//
// Facts it builds on (server code, 2026-11-14):
//   - only fighter cards act in a fight: their Value is the budget cost
//     (fighter.go computeFighterBudget, breed base 600, team cap 6000);
//   - coach cards are the META layer (XP, wounds, morale, drops...), applied
//     after the fight; their Parameters are never read in a fight;
//   - a ranked win pays 50 tokens, a loss nothing (handlers_shop.go).
package main

import (
	"fmt"
	"math"
	"os"
	"sort"
	"strings"

	"github.com/StarLoco/arena-2.70/content"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

const tokensPerWin = 50 // fightWinReward

func main() {
	var (
		cc  *gamedata.CardContent
		err error
	)
	if len(os.Args) > 1 {
		cc, err = gamedata.LoadCardContent(os.DirFS(os.Args[1]))
	} else {
		cc, err = gamedata.LoadCardContent(content.Cards)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "cardreport:", err)
		os.Exit(1)
	}
	fighterReport(cc.Fighters)
	coachReport(cc.Cards)
}

// --- fighter cards ----------------------------------------------------------

// stat is one priced feature of a fighter card.
type stat struct {
	name string
	of   func(c *gamedata.FighterCard) float64
}

// expected is an effect's mean magnitude (Effect.Roll's rules, averaged).
func expected(e gamedata.Effect) float64 {
	p := e.Params
	switch len(p) {
	case 0:
		return 0
	case 3:
		count, faces, mod := float64(p[0]), float64(p[1]), float64(p[2])
		if count <= 0 || faces <= 1 {
			return math.Max(0, count*math.Max(faces, 1)+mod)
		}
		return math.Max(0, count*(faces+1)/2+mod)
	default:
		return math.Abs(float64(p[0]))
	}
}

// equipSum sums Params[0] of the equip effects with the given action ids,
// signed: the first id raises, the second lowers.
func equipSum(c *gamedata.FighterCard, up, down []int32) float64 {
	var v float64
	for _, e := range c.EquipEffects {
		if len(e.Params) == 0 {
			continue
		}
		for _, id := range up {
			if e.ActionID == id {
				v += math.Abs(float64(e.Params[0]))
			}
		}
		for _, id := range down {
			if e.ActionID == id {
				v -= math.Abs(float64(e.Params[0]))
			}
		}
	}
	return v
}

func ids(from, to int32, step int32) []int32 {
	var out []int32
	for i := from; i <= to; i += step {
		out = append(out, i)
	}
	return out
}

// weaponDamage is the mean damage of one weapon use: the normal (non-critical)
// effects of the damaging kinds. Effects with different target-condition
// masks are alternatives (card 34 carries one 8-damage hit per breed mask, of
// which one applies), so they are summed per mask and the best mask counts.
func weaponDamage(c *gamedata.FighterCard) float64 {
	byMask := map[string]float64{}
	for _, e := range c.UseEffects {
		if e.IsCritical {
			continue
		}
		switch e.Kind() {
		case gamedata.KindDamage, gamedata.KindLeech, gamedata.KindScaledAP, gamedata.KindScaledMP, gamedata.KindPercentHP:
			byMask[fmt.Sprint(e.Targets)] += expected(e)
		}
	}
	var best float64
	for _, d := range byMask {
		best = math.Max(best, d)
	}
	return best
}

// The priced features. Element stats use the combat_stats.go ranges, each a
// +/- pair per element (fire, earth, water, air): 21-28 flat resistance,
// 29-36 resistance %, 40-47 flat damage, 48-55 damage %; 80/81 and 82/83 are
// the all-element resistance % and damage %.
var stats = []stat{
	{"HP", func(c *gamedata.FighterCard) float64 {
		return float64(c.Bonus.HP) + equipSum(c, nil, []int32{12})
	}},
	{"AP", func(c *gamedata.FighterCard) float64 { return float64(c.Bonus.AP) + equipSum(c, nil, []int32{14}) }},
	{"MP", func(c *gamedata.FighterCard) float64 { return float64(c.Bonus.MP) + equipSum(c, nil, []int32{18}) }},
	{"Init", func(c *gamedata.FighterCard) float64 { return float64(c.Bonus.Init) + equipSum(c, nil, []int32{77}) }},
	{"Range", func(c *gamedata.FighterCard) float64 { return float64(c.Bonus.Range) }},
	{"Crit%", func(c *gamedata.FighterCard) float64 { return equipSum(c, []int32{70}, []int32{147}) }},
	{"Block/Dodge%", func(c *gamedata.FighterCard) float64 {
		return equipSum(c, []int32{120, 122}, []int32{121, 123})
	}},
	{"ResFlat", func(c *gamedata.FighterCard) float64 { return equipSum(c, ids(21, 27, 2), ids(22, 28, 2)) }},
	{"Res%", func(c *gamedata.FighterCard) float64 {
		return equipSum(c, ids(29, 35, 2), ids(30, 36, 2)) + 4*equipSum(c, []int32{80}, []int32{81})
	}},
	{"DmgFlat", func(c *gamedata.FighterCard) float64 { return equipSum(c, ids(40, 46, 2), ids(41, 47, 2)) }},
	{"Dmg%", func(c *gamedata.FighterCard) float64 {
		return equipSum(c, ids(48, 54, 2), ids(49, 55, 2)) + 4*equipSum(c, []int32{82}, []int32{83})
	}},
	{"Heal%", func(c *gamedata.FighterCard) float64 { return equipSum(c, []int32{78}, []int32{79}) }},
	{"Rebound%", func(c *gamedata.FighterCard) float64 { return equipSum(c, []int32{89}, nil) }},
	{"WeaponDmg/AP", func(c *gamedata.FighterCard) float64 {
		if c.APCost <= 0 {
			return 0
		}
		return weaponDamage(c) / float64(c.APCost)
	}},
}

// knownEquip are the equip action ids the stats above price.
var knownEquip = func() map[int32]bool {
	m := map[int32]bool{12: true, 14: true, 18: true, 77: true, 70: true, 147: true, 120: true, 121: true, 122: true, 123: true, 80: true, 81: true, 82: true, 83: true,
		11: true, 13: true, 17: true, 76: true, 72: true, // folded into Bonus (72 = range)
		78: true, 79: true, 89: true}
	for i := int32(21); i <= 55; i++ {
		m[i] = true
	}
	return m
}()

func fighterReport(fcs *gamedata.FighterCards) {
	var cards []*gamedata.FighterCard
	for _, c := range fcs.All() {
		cards = append(cards, c)
	}
	sort.Slice(cards, func(i, j int) bool { return cards[i].ID < cards[j].ID })

	fmt.Printf("# Fighter cards (%d) — they alone act in a fight; Value is the budget cost\n\n", len(cards))

	// Which equip effects exist, and which the score does not price.
	unpriced := map[int32]int{}
	for _, c := range cards {
		for _, e := range c.EquipEffects {
			if !knownEquip[e.ActionID] {
				unpriced[e.ActionID]++
			}
		}
	}
	if len(unpriced) > 0 {
		fmt.Printf("Equip effects not priced (action: cards): %v\n\n", unpriced)
	}

	// Features in use.
	var used []stat
	for _, s := range stats {
		for _, c := range cards {
			if s.of(c) != 0 {
				used = append(used, s)
				break
			}
		}
	}
	// Least squares Value ≈ Σ price_s · stat_s (no intercept: a card that gives
	// nothing costs nothing), with a small ridge so a stat seen on one card
	// cannot take a wild price.
	n, k := len(cards), len(used)
	x := make([][]float64, n)
	y := make([]float64, n)
	for i, c := range cards {
		x[i] = make([]float64, k)
		for j, s := range used {
			x[i][j] = s.of(c)
		}
		y[i] = float64(c.Value)
	}
	price := ridge(x, y, 1e-3)

	fmt.Println("## What a stat costs in budget (fitted on the current values)")
	fmt.Println()
	fmt.Println("| Stat | Cards with it | Budget per point |")
	fmt.Println("|---|---|---|")
	for j, s := range used {
		var with int
		for i := range cards {
			if x[i][j] != 0 {
				with++
			}
		}
		fmt.Printf("| %s | %d | %.1f |\n", s.name, with, price[j])
	}

	type row struct {
		c        *gamedata.FighterCard
		fit, res float64
		desc     string
	}
	var rows []row
	var ssRes, ssTot, mean float64
	for _, v := range y {
		mean += v
	}
	mean /= float64(n)
	for i, c := range cards {
		var fit float64
		var parts []string
		for j, s := range used {
			fit += price[j] * x[i][j]
			if x[i][j] != 0 {
				parts = append(parts, fmt.Sprintf("%s %+g", s.name, round1(x[i][j])))
			}
		}
		res := y[i] - fit
		ssRes += res * res
		ssTot += (y[i] - mean) * (y[i] - mean)
		if c.Usable() {
			parts = append(parts, fmt.Sprintf("weapon %dAP r%d-%d", c.APCost, c.RangeMin, c.RangeMax))
		}
		rows = append(rows, row{c, fit, res, strings.Join(parts, ", ")})
	}
	fmt.Printf("\nFit: R² = %.2f over %d cards (1 = the values follow the stats exactly).\n\n", 1-ssRes/ssTot, n)

	sort.Slice(rows, func(i, j int) bool { return rows[i].res/math.Max(rows[i].fit, 50) < rows[j].res/math.Max(rows[j].fit, 50) })
	show := func(title string, rs []row) {
		fmt.Println("## " + title)
		fmt.Println()
		fmt.Println("| Card | Value | Worth by its stats | Gives |")
		fmt.Println("|---|---|---|---|")
		for _, r := range rs {
			fmt.Printf("| %d | %d | %.0f | %s |\n", r.c.ID, r.c.Value, r.fit, r.desc)
		}
		fmt.Println()
	}
	m := 10
	if len(rows) < 2*m {
		m = len(rows) / 2
	}
	show("Cheapest for what they give (most power per budget)", rows[:m])
	show("Dearest for what they give", rows[len(rows)-m:])

	// The budget a full fighter can reach.
	bySlot := map[int16][]int32{}
	for _, c := range cards {
		bySlot[c.Type] = append(bySlot[c.Type], c.Value)
	}
	fmt.Println("## Value range by card type (slot)")
	fmt.Println()
	fmt.Println("| Type | Cards | Min | Median | Max |")
	fmt.Println("|---|---|---|---|---|")
	var types []int
	for t := range bySlot {
		types = append(types, int(t))
	}
	sort.Ints(types)
	maxFull := 600
	for _, t := range types {
		v := bySlot[int16(t)]
		sort.Slice(v, func(i, j int) bool { return v[i] < v[j] })
		fmt.Printf("| %d | %d | %d | %d | %d |\n", t, len(v), v[0], v[len(v)/2], v[len(v)-1])
		maxFull += int(v[len(v)-1])
	}
	fmt.Printf("\nA fighter: 600 base; with the dearest card of every type, %d.\n\n", maxFull)
}

func round1(v float64) float64 { return math.Round(v*10) / 10 }

// ridge solves (XᵀX + λ·diag(XᵀX)) b = Xᵀy by Gaussian elimination.
func ridge(x [][]float64, y []float64, lambda float64) []float64 {
	k := len(x[0])
	a := make([][]float64, k)
	b := make([]float64, k)
	for i := range a {
		a[i] = make([]float64, k)
	}
	for r := range x {
		for i := 0; i < k; i++ {
			b[i] += x[r][i] * y[r]
			for j := 0; j < k; j++ {
				a[i][j] += x[r][i] * x[r][j]
			}
		}
	}
	for i := 0; i < k; i++ {
		a[i][i] += lambda*a[i][i] + 1e-9
	}
	for col := 0; col < k; col++ {
		piv := col
		for r := col + 1; r < k; r++ {
			if math.Abs(a[r][col]) > math.Abs(a[piv][col]) {
				piv = r
			}
		}
		a[col], a[piv] = a[piv], a[col]
		b[col], b[piv] = b[piv], b[col]
		for r := 0; r < k; r++ {
			if r == col || a[col][col] == 0 {
				continue
			}
			f := a[r][col] / a[col][col]
			for c := col; c < k; c++ {
				a[r][c] -= f * a[col][c]
			}
			b[r] -= f * b[col]
		}
	}
	out := make([]float64, k)
	for i := range out {
		if a[i][i] != 0 {
			out[i] = b[i] / a[i][i]
		}
	}
	return out
}

// --- coach cards ------------------------------------------------------------

// metaAction names the coach META actions the server applies (postfight_apply.go,
// drops.go, consumables.go, handlers_evolution.go).
var metaAction = map[int32]string{
	1: "XP %", 2: "XP flat", 3: "enemy XP %", 4: "enemy XP flat", 5: "wound chance", 6: "enemy wound chance",
	7: "death chance", 8: "enemy death chance", 9: "morale", 10: "enemy morale", 11: "cancel wounds %",
	13: "resurrection %", 14: "reputation", 15: "apply condition", 16: "fatigue", 17: "enemy fatigue",
	18: "drop bonus", 19: "drop chance", 20: "drop min level", 21: "drop max level",
}

func coachReport(cards *gamedata.Cards) {
	all := cards.All()
	fmt.Printf("# Coach cards (%d) — META layer only: nothing here acts in a fight\n\n", len(all))

	type agg struct {
		n, inDraw, priced, withFx int
		price                     []int
	}
	byRank := map[int32]*agg{}
	actionByRank := map[int32]map[int32][]float64{}
	for _, c := range all {
		a := byRank[c.Rank]
		if a == nil {
			a = &agg{}
			byRank[c.Rank] = a
			actionByRank[c.Rank] = map[int32][]float64{}
		}
		a.n++
		if c.ObtainableInDraw {
			a.inDraw++
		}
		if p, ok := c.Price[1]; ok && p > 0 {
			a.priced++
			a.price = append(a.price, int(p))
		}
		if len(c.Effects) > 0 {
			a.withFx++
		}
		for _, e := range c.Effects {
			// 15's params[0] is a condition id, not a strength: count it only.
			if e.Action == 15 {
				actionByRank[c.Rank][15] = append(actionByRank[c.Rank][15], 0)
				continue
			}
			if len(e.Params) > 0 {
				actionByRank[c.Rank][e.Action] = append(actionByRank[c.Rank][e.Action], float64(e.Params[0]))
			}
		}
	}
	var ranks []int
	for r := range byRank {
		ranks = append(ranks, int(r))
	}
	sort.Ints(ranks)

	fmt.Println("## By rank (the card frame's rarity)")
	fmt.Println()
	fmt.Println("| Rank | Cards | In draws | With effects | Token-priced | Median price | Median wins to buy |")
	fmt.Println("|---|---|---|---|---|---|---|")
	for _, r := range ranks {
		a := byRank[int32(r)]
		med, wins := "—", "—"
		if len(a.price) > 0 {
			sort.Ints(a.price)
			m := a.price[len(a.price)/2]
			med = fmt.Sprint(m)
			wins = fmt.Sprintf("%.1f", float64(m)/tokensPerWin)
		}
		fmt.Printf("| %d | %d | %d | %d | %d | %s | %s |\n", r, a.n, a.inDraw, a.withFx, a.priced, med, wins)
	}

	fmt.Println()
	fmt.Println("## Effect strength by rank (median of params[0]; n = cards; 15 shows 0, its param is a condition id)")
	fmt.Println()
	var acts []int
	seen := map[int32]bool{}
	for _, m := range actionByRank {
		for a := range m {
			if !seen[a] {
				seen[a] = true
				acts = append(acts, int(a))
			}
		}
	}
	sort.Ints(acts)
	head := "| Action |"
	sep := "|---|"
	for _, r := range ranks {
		head += fmt.Sprintf(" r%d |", r)
		sep += "---|"
	}
	fmt.Println(head)
	fmt.Println(sep)
	for _, a := range acts {
		name := metaAction[int32(a)]
		if name == "" {
			name = "?"
		}
		line := fmt.Sprintf("| %d %s |", a, name)
		for _, r := range ranks {
			v := actionByRank[int32(r)][int32(a)]
			if len(v) == 0 {
				line += " |"
				continue
			}
			sort.Float64s(v)
			line += fmt.Sprintf(" %g (%d) |", v[len(v)/2], len(v))
		}
		fmt.Println(line)
	}
	fmt.Println()
}
