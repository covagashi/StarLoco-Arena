package gamedata

import (
	"math/rand"
	"sync"
)

// carddraw.go ports `alb_1`, the random card-draw table the retail client
// ships dead — registered into by every `xj` via `eh_2` (`la_0.XJ().a(card)`)
// but with no call site, because the drawing lived server-side and the class
// is shared Ankama library code. Its whole algorithm fits on one screen:
//
//	cards are bucketed into 51 lists by ka_1.bK(card.getValue())
//	pk(n)   : while the bucket is empty, --n; then a uniform pick
//	cl(n2,n3): loop {
//	    c = pk(n2)
//	    if (c.ts() + n3 >= 100 || nextInt(100) - n3 <= c.ts()) return c
//	}
//
// So the draw is: pick uniformly in the value bucket at index n2 (walking to
// lower-value buckets when that one is empty), then run an acceptance roll —
// the card's own DropPercent plus the call-time bonus n3 is its keep chance.
// A pct=0 card is a rare drop that only a positive bonus can ever keep, and
// the loop guarantees exactly one card per call.
const (
	// drawBuckets is the fixed table width (`dVP = new jg_0[51]`).
	drawBuckets = 51
	// maxDropRolls caps the acceptance loop. The retail loop is unbounded and
	// terminates because pct+bonus >= 1 always accepts eventually (pct >= 0);
	// the cap only guards a pathological all-zero-bonus/all-zero-pct table,
	// which cannot happen while pct=100 cards exist — but keeps a data error
	// from hanging the post-fight path.
	maxDropRolls = 100000
)

// DrawTable is the loaded `alb_1`: every card registered, the draw pool
// bucketed by value.
type DrawTable struct {
	byID    map[int32]*CoachCard
	buckets [drawBuckets][]int32
	rng     *rand.Rand
	// mu serializes Draw: rand.Rand is not goroutine-safe and one table is
	// shared by every concurrent session rolling post-fight drops.
	mu sync.Mutex
}

// NewDrawTable builds the draw table from a loaded card set, matching
// `alb_1.a(oj_0)`: every card is registered, but only `to()` (ObtainableInDraw)
// enters a bucket.
func NewDrawTable(cards *Cards, rng *rand.Rand) *DrawTable {
	t := &DrawTable{byID: make(map[int32]*CoachCard), rng: rng}
	if t.rng == nil {
		t.rng = rand.New(rand.NewSource(rand.Int63()))
	}
	if cards == nil {
		return t
	}
	for _, c := range cards.All() {
		t.byID[c.ID] = c
		if c.ObtainableInDraw {
			b := valueBucket(c.Value)
			t.buckets[b] = append(t.buckets[b], c.ID)
		}
	}
	return t
}

// valueBucket is `ka_1.bK`: the value->bucket curve. Values are card worth in
// kamas; the curve is the same piecewise table the client uses for currency
// tiers, capped at index 50.
func valueBucket(v int32) int {
	switch {
	case v <= 0:
		return 0
	case v >= 50000:
		return 50
	case v < 10:
		return 1
	case v < 100:
		return int(v / 10)
	case v < 200:
		return 10
	case v < 3400:
		return int((v-200)/400 + 11)
	case v < 4000:
		return 19
	case v < 29000:
		return int((v-2000)/3000 + 20)
	default:
		return int(v / 1000)
	}
}

// Get returns a card by id (`alb_1.pj`).
func (t *DrawTable) Get(id int32) *CoachCard {
	if t == nil {
		return nil
	}
	return t.byID[id]
}

// pick draws a uniform id from bucket n, walking down to the first non-empty
// bucket below it (`alb_1.pk`). Returns false when every bucket at or below n
// is empty — retail would index underflow; we answer honestly instead.
func (t *DrawTable) pick(n int) (int32, bool) {
	if t == nil {
		return 0, false
	}
	if n > drawBuckets-1 {
		n = drawBuckets - 1
	}
	for n >= 0 && len(t.buckets[n]) == 0 {
		n--
	}
	if n < 0 {
		return 0, false
	}
	b := t.buckets[n]
	return b[t.rng.Intn(len(b))], true
}

// Draw is `alb_1.cl(n2, n3)`: pick from bucket n2, keep the card with
// probability (DropPercent + bonus) — auto-accept at >= 100 — retrying until
// one sticks. Returns nil only when the pool is empty.
func (t *DrawTable) Draw(n int, bonus int32) *CoachCard {
	t.mu.Lock()
	defer t.mu.Unlock()
	for i := 0; i < maxDropRolls; i++ {
		id, ok := t.pick(n)
		if !ok {
			return nil
		}
		c := t.byID[id]
		if c == nil {
			continue
		}
		if c.DropPercent+bonus >= 100 || int32(t.rng.Intn(100))-bonus <= c.DropPercent {
			return c
		}
	}
	return nil
}

// PoolLen reports how many cards are in the draw pool (testing).
func (t *DrawTable) PoolLen() int {
	if t == nil {
		return 0
	}
	n := 0
	for _, b := range t.buckets {
		n += len(b)
	}
	return n
}
