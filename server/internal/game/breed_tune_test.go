package game

import (
	"fmt"
	"math"
	"os"
	"strings"
	"testing"

	"github.com/StarLoco/arena-2.70/content"
	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// breed_tune_test.go: S46 phase D, the class balance search, on demand:
//
//	S46_TUNE=8 S46_BREEDS=100 go test ./internal/game/ -run TestBreedTune -v -timeout 120m
//
// One damage multiplier per class (every damage effect of its spells, the
// critical ones too) and, for the Curandero (owner: "curas más fuertes"), a
// heal multiplier instead. Each round rebuilds the spells from the shipped
// ones with the multipliers, rounded as the data stores them (floor(v·m +
// 0.5), at least 1; dice scale their faces), plays the duels and
// the trios, and moves each class's lever and its HP so the duel mean and
// the trio mean head to 0.5 (tuneStep). S46_TUNE_WRITE=1 writes the last
// round's data into server/content/rules.

// healTuned are the classes tuned by their heals rather than their damage;
// summonTuned by their creatures' HP. The Jardinero went that way first (its
// damage at ×2.6 had left it at 0.36 in trios), but its dolls at ×2.5 HP
// still left it at 0.32: since then its dolls stay at ×2 (S46_TUNE_FROM) and
// its damage is the lever, like everyone's.
var (
	healTuned   = map[uint8]bool{7: true}
	summonTuned = map[uint8]bool{}
)

// scaledSummonings is orig with the HP of the creatures each class's spells
// call scaled by sm[class].
func scaledSummonings(orig *gamedata.Summonings, spells *gamedata.Spells, sm map[uint8]float64) *gamedata.Summonings {
	scale := map[int32]float64{}
	for _, sp := range spells.All() {
		m := sm[uint8(sp.BreedID)]
		if m == 0 || m == 1 {
			continue
		}
		for _, ef := range sp.Effects {
			if ef.Kind() == gamedata.KindSummon && len(ef.Params) > 0 {
				scale[int32(ef.Params[0])] = m
			}
		}
	}
	var out []*gamedata.Summoning
	for id, tm := range orig.All() {
		c := *tm
		if m, ok := scale[id]; ok {
			c.HP = int32(scaleParam(float32(c.HP), m))
		}
		out = append(out, &c)
	}
	return gamedata.NewSummonings(out...)
}

func scaleParam(v float32, m float64) float32 {
	return float32(max(1, math.Floor(float64(v)*m+0.5)))
}

// scaleEffect scales a damage or heal effect's amount (one value, or a dice
// roll's faces).
func scaleEffect(ef gamedata.Effect, m float64) gamedata.Effect {
	p := append([]float32(nil), ef.Params...)
	switch len(p) {
	case 1:
		p[0] = scaleParam(p[0], m)
	case 3:
		p[1] = max(2, scaleParam(p[1], m))
	}
	ef.Params = p
	return ef
}

// scaledSpells is orig with each class's damage (dm) and heals (hm) scaled.
func scaledSpells(orig *gamedata.Spells, dm, hm map[uint8]float64) *gamedata.Spells {
	var out []*gamedata.Spell
	for _, sp := range orig.All() {
		c := *sp
		br := uint8(sp.BreedID)
		c.Effects = make([]gamedata.Effect, len(sp.Effects))
		for i, ef := range sp.Effects {
			_, dmg := ef.FlatDamage()
			switch {
			case dmg && dm[br] != 0 && dm[br] != 1:
				ef = scaleEffect(ef, dm[br])
			case ef.Kind() == gamedata.KindHeal && hm[br] != 0 && hm[br] != 1:
				ef = scaleEffect(ef, hm[br])
			}
			c.Effects[i] = ef
		}
		out = append(out, &c)
	}
	return gamedata.NewSpells(out...)
}

// tuneJ is how a class's duel and trio means move per unit of log multiplier
// of its damage-side lever and of its HP, measured on the Relojero and the
// Zahorí (2026-11-19: damage ×1.4 / ×0.7 and HP ×1.4 / ×0.7, alone, 80 fights
// a pair): damage moves the duels about twice as much as the trios, HP both
// alike, so the two levers can aim at the two means. Its inverse drives each
// step.
var tuneJ = [2][2]float64{{0.7, 0.6}, {0.35, 0.5}} // rows duel, trio; cols lever, HP

// tuneStep is the damped (lever, HP) change in log for errors (ed, et).
func tuneStep(ed, et, damp float64) (float64, float64) {
	det := tuneJ[0][0]*tuneJ[1][1] - tuneJ[0][1]*tuneJ[1][0]
	dl := (tuneJ[1][1]*ed - tuneJ[0][1]*et) / det
	dh := (-tuneJ[1][0]*ed + tuneJ[0][0]*et) / det
	return damp * dl, damp * dh
}

func TestBreedTune(t *testing.T) {
	rounds, n := -1, 0
	fmt.Sscan(os.Getenv("S46_TUNE"), &rounds)
	fmt.Sscan(os.Getenv("S46_BREEDS"), &n)
	if rounds < 0 || n <= 0 {
		t.Skip("set S46_TUNE=<rounds> S46_BREEDS=<fights per pair>")
	}
	d := simDeps(t)
	orig, origSum := d.Spells, d.Summonings
	keepBreeds := map[uint8]breedBaseStats{}
	for b, st := range breedTable {
		keepBreeds[b] = st
	}
	t.Cleanup(func() {
		for b, st := range keepBreeds {
			breedTable[b] = st
		}
	})
	dm, hm, sm, hp := map[uint8]float64{}, map[uint8]float64{}, map[uint8]float64{}, map[uint8]float64{}
	for _, b := range simAllBreeds {
		dm[b], hm[b], sm[b], hp[b] = 1, 1, 1, 1
	}
	// S46_TUNE_FROM="1:d=0.8,h=1,s=1,hp=1 2:..." starts from a previous line
	for _, f := range strings.Fields(os.Getenv("S46_TUNE_FROM")) {
		var b uint8
		var dv, hv, sv, pv float64
		if _, err := fmt.Sscanf(f, "%d:d=%g,h=%g,s=%g,hp=%g", &b, &dv, &hv, &sv, &pv); err == nil {
			dm[b], hm[b], sm[b], hp[b] = dv, hv, sv, pv
		}
	}
	lever := func(b uint8) map[uint8]float64 {
		switch {
		case healTuned[b]:
			return hm
		case summonTuned[b]:
			return sm
		}
		return dm
	}
	apply := func() {
		d.Spells = scaledSpells(orig, dm, hm)
		d.Summonings = scaledSummonings(origSum, orig, sm)
		for b, st := range keepBreeds {
			if m, ok := hp[b]; ok {
				st.HP = int32(scaleParam(float32(st.HP), m))
			}
			breedTable[b] = st
		}
	}
	duel := func(id uint, br uint8) *domain.GhostTeam { return breedTeam(d, id, br) }
	trio := func(id uint, br uint8) *domain.GhostTeam { return breedTeam(d, id, br, 8, 9) }
	mean := func(wr map[uint8]map[uint8]float64, a uint8) float64 {
		s := 0.0
		for _, b := range simAllBreeds {
			if a != b {
				s += wr[a][b]
			}
		}
		return s / float64(len(simAllBreeds)-1)
	}
	line := func() string {
		var out strings.Builder
		for _, b := range simAllBreeds {
			fmt.Fprintf(&out, "%d:d=%.3f,h=%.3f,s=%.3f,hp=%.3f ", b, dm[b], hm[b], sm[b], hp[b])
		}
		return out.String()
	}
	damp := 0.4
	fmt.Sscan(os.Getenv("S46_TUNE_DAMP"), &damp)
	// S46_TUNE_COMMON=1: one lever per class on the mean of duel and trio. The
	// two-lever step went to extremes (Pandawa damage ×2.5 with HP ×0.6): a
	// class whose duel and trio differ a lot cannot be fixed by these numbers.
	common := os.Getenv("S46_TUNE_COMMON") != ""
	// S46_TUNE_TRIO=1: the owner's target (2026-11-19), trios 40-60 and duels
	// 35-65, one lever per class, HP kept.
	trioFirst := os.Getenv("S46_TUNE_TRIO") != ""
	// the landscape is in steps (a point of damage changes how many hits a
	// fighter takes, and flips a whole pairing), so keep the best round
	bestWorst, bestLine := math.Inf(1), ""
	for r := 0; r <= rounds; r++ {
		apply()
		played := line()
		dw, tw := breedMatrix(t, d, n, duel), breedMatrix(t, d, n, trio)
		var row strings.Builder
		worst := 0.0
		for _, b := range simAllBreeds {
			md, mt := mean(dw, b), mean(tw, b)
			if trioFirst {
				worst = math.Max(worst, math.Max(math.Abs(mt-0.5)-0.1, math.Abs(md-0.5)-0.15))
			} else {
				worst = math.Max(worst, math.Max(math.Abs(md-0.5), math.Abs(mt-0.5)))
			}
			fmt.Fprintf(&row, "%s d%.2f t%.2f ×%.2f hp×%.2f | ", fighterBreedName(b), md, mt, lever(b)[b], hp[b])
			if r == rounds {
				continue
			}
			var dl, dh float64
			if trioFirst {
				// owner: trios 40-60, duels 35-65 — aim the trio at 0.5 and
				// pull a duel only once it leaves its band
				e := 0.5 - mt
				if md < 0.35 {
					e += 0.35 - md
				} else if md > 0.65 {
					e += 0.65 - md
				}
				dl = damp * e / 0.45
			} else if common {
				// one lever on the mean of the two; HP stays
				dl = damp * (1 - (md+mt)) / (tuneJ[0][0] + tuneJ[1][0])
			} else {
				dl, dh = tuneStep(0.5-md, 0.5-mt, damp)
			}
			l := lever(b)
			l[b] = math.Min(2.5, math.Max(0.5, l[b]*math.Exp(dl)))
			hp[b] = math.Min(1.4, math.Max(0.7, hp[b]*math.Exp(dh)))
		}
		t.Logf("round %d (worst %.2f off): %s", r, worst, row.String())
		if worst < bestWorst {
			bestWorst, bestLine = worst, played
		}
		if r < rounds {
			t.Logf("next: %s", line())
		}
	}
	t.Logf("multipliers of the last round: %s", line())
	t.Logf("best round (worst %.2f off): %s", bestWorst, bestLine)
	if os.Getenv("S46_TUNE_WRITE") != "" {
		writeTuned(t, d)
	}
}

// writeTuned writes the last round's spells, creatures and class HP into
// server/content/rules (S46_TUNE_WRITE=1): the data that was measured.
func writeTuned(t *testing.T, d *Deps) {
	t.Helper()
	r, err := gamedata.LoadRulesContent(content.Rules)
	if err != nil {
		t.Fatal(err)
	}
	r.Spells, r.Summonings = d.Spells, d.Summonings
	var bs []*gamedata.Breed
	for _, b := range r.Breeds.All() {
		c := *b
		c.HP = breedTable[b.ID].HP
		bs = append(bs, &c)
	}
	r.Breeds = gamedata.NewBreeds(bs...)
	if err := gamedata.WriteRulesContent("../../content/rules", r); err != nil {
		t.Fatal(err)
	}
	t.Log("wrote ../../content/rules")
}
