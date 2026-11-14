package game

import (
	"math/rand/v2"
	"sort"
	"strconv"
	"strings"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store"
)

// Card picks and leagues (S40, owner 2026-11-14).
//
// Every few wins — Ranking and the ghost ladder alike — the server offers
// three coach cards and the coach keeps one (domain.PickEvery: every 3 wins
// for the first ten picks, then every 5). The offer waits until it is taken,
// across fights and sessions; wins keep counting meanwhile, up to one more
// offer's worth. It is a source on top of the shop and the drops. The fighter
// cards are not offered: Elite fighters can already wear all of them, within
// their league's budget.
//
// The league (domain.League) rides along so the client can show the budget a
// team must fit before it queues.

// pickOfferSize is how many cards an offer holds.
const pickOfferSize = 3

// pickableFamilies are the card types an offer may hold: the coach's
// equipment (2-13, which carries the set bonuses), Historia's consumables
// (24) and cosmetics (1, 25 fireworks, 28). Not the colour cards (29, season
// rewards only), nor arenas, fusion, combat or dofus cards.
var pickableTypes = func() map[int32]bool {
	m := map[int32]bool{1: true, 24: true, 25: true, 28: true}
	for t := int32(2); t <= 13; t++ {
		m[t] = true
	}
	return m
}()

// pickTier is the rarity tier the client shows (cards.gd tier_of): black,
// copper, silver, gold.
func pickTier(rank int32) int {
	switch {
	case rank <= 2:
		return 0
	case rank <= 5:
		return 1
	case rank <= 8:
		return 2
	}
	return 3
}

// drawPickOffer chooses pickOfferSize distinct pickable cards, the coach's
// unowned ones first, spread over as many rarity tiers as it can: a rare card
// is different, not better, so an offer shows the range rather than a ladder.
func drawPickOffer(cards *gamedata.Cards, owned map[int32]bool, rng *rand.Rand) []int32 {
	if cards == nil {
		return nil
	}
	var fresh, have []*gamedata.CoachCard
	for _, c := range cards.All() {
		if !pickableTypes[c.Type] || c.Value <= 0 {
			continue
		}
		if owned[c.ID] {
			have = append(have, c)
		} else {
			fresh = append(fresh, c)
		}
	}
	// Map iteration is random but not uniform; sort first so the shuffle alone
	// decides (and a seeded rng repeats).
	for _, l := range [][]*gamedata.CoachCard{fresh, have} {
		sortCardsByID(l)
		rng.Shuffle(len(l), func(i, j int) { l[i], l[j] = l[j], l[i] })
	}
	pool := append(fresh, have...)
	var out []int32
	tiers := map[int]bool{}
	taken := map[int32]bool{}
	// First pass: one card per tier not yet shown; second: anything left.
	for pass := 0; pass < 2 && len(out) < pickOfferSize; pass++ {
		for _, c := range pool {
			if len(out) == pickOfferSize {
				break
			}
			if taken[c.ID] || pass == 0 && tiers[pickTier(c.Rank)] {
				continue
			}
			taken[c.ID] = true
			tiers[pickTier(c.Rank)] = true
			out = append(out, c.ID)
		}
	}
	return out
}

func sortCardsByID(l []*gamedata.CoachCard) {
	sort.Slice(l, func(i, j int) bool { return l[i].ID < l[j].ID })
}

func encodeOffer(ids []int32) string {
	parts := make([]string, len(ids))
	for i, id := range ids {
		parts[i] = strconv.Itoa(int(id))
	}
	return strings.Join(parts, ",")
}

func decodeOffer(s string) []int32 {
	var out []int32
	for _, p := range strings.Split(s, ",") {
		if n, err := strconv.Atoi(strings.TrimSpace(p)); err == nil && n > 0 {
			out = append(out, int32(n))
		}
	}
	return out
}

// ownedCards is the set of card templates a coach holds.
func (d *Deps) ownedCards(coachID uint) map[int32]bool {
	owned := map[int32]bool{}
	if c, err := d.Store.Coaches.Get(coachID); err == nil && c != nil {
		for _, cc := range c.Inventory {
			if cc.Quantity > 0 {
				owned[cc.TemplateID] = true
			}
		}
	}
	return owned
}

// refillOffer makes an offer when there is none and the wins pay for one.
func (d *Deps) refillOffer(p *domain.CardPick) {
	every := domain.PickEvery(p.Picks)
	if p.Offer != "" || p.Wins < every {
		return
	}
	offer := drawPickOffer(d.Cards, d.ownedCards(p.CoachID), d.pickRand())
	if len(offer) == 0 {
		return
	}
	p.Wins -= every
	p.Offer = encodeOffer(offer)
}

// pickRand is the offer's randomness (a test seeds pickRng).
func (d *Deps) pickRand() *rand.Rand {
	if d.pickRng != nil {
		return d.pickRng
	}
	return rand.New(rand.NewPCG(rand.Uint64(), rand.Uint64()))
}

// cardPickWin counts a win (a real coach's, Ranking or ghost ladder) towards
// the next offer and tells the coach's client when one is ready.
func (d *Deps) cardPickWin(coachID uint) {
	if d.Store == nil || d.Store.CardPicks == nil || isSyntheticCoach(coachID) {
		return
	}
	d.pickMu.Lock()
	p, err := d.Store.CardPicks.Get(coachID)
	if err != nil {
		d.pickMu.Unlock()
		d.Log.Warn("card pick not read", "coach", coachID, "err", err)
		return
	}
	// With an offer waiting, the wins bank one more offer's worth, no more.
	if limit := domain.PickEvery(p.Picks + 1); p.Offer == "" || p.Wins < limit {
		p.Wins++
	}
	d.refillOffer(&p)
	err = d.Store.CardPicks.Save(p)
	d.pickMu.Unlock()
	if err != nil {
		d.Log.Warn("card pick not saved", "coach", coachID, "err", err)
		return
	}
	if s := d.sessionForCoach(coachID); s != nil {
		_ = s.sendCardPicks()
	}
}

func registerCardPickHandlers(r *Router, _ *Deps) {
	r.Register(protocol.OpCardPickChoose, handleCardPickChoose)
}

// handleCardPickChoose (60044) takes one card of the pending offer. A card not
// in the offer is refused silently (the client only shows the offer); the
// answer 60045 goes either way so the screen shows the truth.
func handleCardPickChoose(s *Session, f *protocol.C2SFrame) error {
	d := s.deps
	if s.Coach == nil || d.Store == nil || d.Store.CardPicks == nil {
		return nil
	}
	id, err := protocol.NewReader(f.Payload).I32()
	if err != nil {
		return nil
	}
	d.pickMu.Lock()
	p, err := d.Store.CardPicks.Get(s.Coach.ID)
	if err != nil {
		d.pickMu.Unlock()
		return err
	}
	ok := false
	for _, o := range decodeOffer(p.Offer) {
		ok = ok || o == id
	}
	if ok {
		if err := d.Store.Coaches.GrantCards(s.Coach.ID, []store.GrantCard{{TemplateID: id, Quantity: 1}}); err != nil {
			d.pickMu.Unlock()
			return err
		}
		p.Picks++
		p.Offer = ""
		d.refillOffer(&p) // banked wins may pay for the next one straight away
		err = d.Store.CardPicks.Save(p)
	}
	d.pickMu.Unlock()
	if err != nil {
		return err
	}
	if ok {
		s.log.Info("card picked", "coach", s.Coach.Name, "card", id, "picks", p.Picks)
		if fresh, err := d.Store.Coaches.Get(s.Coach.ID); err == nil && fresh != nil {
			s.Coach.SetInventory(fresh.Inventory)
			_ = s.pushInventory(fresh)
		}
	}
	return s.sendCardPicks()
}

// sendCardPicks sends 60045 to a Godot session: the wins towards the next
// offer, what it costs, and the pending offer (n = 0: none).
func (s *Session) sendCardPicks() error {
	if s.Coach == nil || s.deps.Store == nil || s.deps.Store.CardPicks == nil || !s.godot.Load() {
		return nil
	}
	p, err := s.deps.Store.CardPicks.Get(s.Coach.ID)
	if err != nil {
		return err
	}
	offer := decodeOffer(p.Offer)
	w := protocol.NewWriter().U8(uint8(min(p.Wins, 255))).U8(uint8(domain.PickEvery(p.Picks))).U8(uint8(len(offer)))
	for _, id := range offer {
		w.I32(id)
	}
	frame, err := protocol.EncodeS2C(protocol.OpCardPicks, w.Bytes())
	if err != nil {
		return err
	}
	return s.Send(frame)
}

// sendLeague sends 60046 to a Godot session: its league and team budget on
// the Ranking and on the ghost ladder.
func (s *Session) sendLeague() error {
	if s.Coach == nil || !s.godot.Load() {
		return nil
	}
	s.Coach.Mu.Lock()
	ranked := domain.RankedLeague(s.Coach.Strength)
	s.Coach.Mu.Unlock()
	elo := domain.GhostEloStart
	if s.deps.Store != nil && s.deps.Store.Ghosts != nil {
		if r, err := s.deps.Store.Ghosts.Rating(s.Coach.ID); err == nil {
			elo = r.Elo
		}
	}
	ghost := domain.GhostLeague(elo)
	w := protocol.NewWriter().U8(ranked.Tier).I32(ranked.Budget).U8(ghost.Tier).I32(ghost.Budget)
	frame, err := protocol.EncodeS2C(protocol.OpLeague, w.Bytes())
	if err != nil {
		return err
	}
	return s.Send(frame)
}
