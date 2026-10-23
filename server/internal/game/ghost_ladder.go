package game

import (
	"encoding/json"
	"fmt"
	"math"
	"strconv"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// ghost_ladder.go is async PvP phase 5 (sprints/S14): the mode works with one
// coach online.
//
//   - Filler ghosts: fillerGhostCount server-made teams (CoachID 0), built from
//     the breeds' own spells with two simple rules each, rated from 700 to
//     1360. They are made on the first ghost request, never shipped in
//     data-dist (that directory is the maintainer's call).
//   - Matchmaking: 60014 with ghost id 0 picks the ghost nearest the
//     challenger's rating — a player's ghost within ghostMatchBand first, else
//     the nearest of all, fillers included.
//   - Ratings: Elo. Against a player's ghost both move (K = 32); against a
//     filler only the challenger does, at half K — fillers anchor the scale. A
//     replay (60014 with a fight id) moves nothing.
//   - Rewards: none in cards; the ladder is the reward (the README default).
//   - No decay (an open question for the owner).

const (
	fillerGhostCount = 12
	ghostMatchBand   = 200
	ghostEloK        = 32.0
	ghostEloFloor    = 100
)

// fillerSpec is filler i: its breeds and its fixed rating.
func fillerSpec(i int) (breeds []uint8, elo int32) {
	a := uint8(i%12) + 1
	b := uint8((i*5+3)%12) + 1
	if b == a {
		b = a%12 + 1
	}
	breeds = []uint8{a, b}
	if i >= 6 {
		c := uint8((i*7+5)%12) + 1
		for c == a || c == b {
			c = c%12 + 1
		}
		breeds = append(breeds, c)
	}
	return breeds, 700 + int32(i)*60
}

// ensureFillerGhosts makes the missing fillers, once per process.
func (d *Deps) ensureFillerGhosts() {
	d.fillerOnce.Do(func() {
		if d.Store == nil || d.Store.Ghosts == nil || d.Spells == nil {
			return
		}
		n, err := d.Store.Ghosts.CountFillers()
		if err != nil {
			return
		}
		for i := int(n); i < fillerGhostCount; i++ {
			if err := d.Store.Ghosts.Create(d.fillerGhost(i)); err != nil {
				d.Log.Warn("filler ghost not saved", "i", i, "err", err)
				return
			}
		}
	})
}

// fillerGhost builds filler i: breed base fighters armed with their breed's
// repertoire, each with two rules — finish a hurt enemy with its signature
// spell, back off when nearly dead — and the archetype AI for the rest.
func (d *Deps) fillerGhost(i int) *domain.GhostTeam {
	breeds, elo := fillerSpec(i)
	roster := make([]domain.Fighter, 0, len(breeds))
	rules := map[string]json.RawMessage{}
	name := ""
	for k, br := range breeds {
		fr := domain.Fighter{Name: fighterBreedName(br), BreedID: br,
			Spells: breedSpellRepertoire(d.Spells, br)}
		roster = append(roster, fr)
		if name != "" {
			name += " · "
		}
		name += fr.Name
		if sig := pickBreedSpell(d.Spells, br); sig != 0 {
			rules[strconv.Itoa(k)] = json.RawMessage(fmt.Sprintf(`{"version":1,"rules":[`+
				`{"if":{"kind":"self_hp_pct_below","value":25},"do":{"kind":"move_away"}},`+
				`{"if":{"kind":"enemy_hp_pct_below","value":40},"do":{"kind":"cast","spell":%d,"target":"weakest_enemy"}}]}`, sig))
		}
	}
	rosterJSON, _ := json.Marshal(roster)
	rulesJSON, _ := json.Marshal(rules)
	return &domain.GhostTeam{CoachID: domain.GhostFillerCoach, Name: name,
		Roster: string(rosterJSON), Rules: string(rulesJSON), EloGhost: elo}
}

// pickGhostFor chooses a ghost for coachID rated `rating`: a player's ghost
// within ghostMatchBand, nearest first, else the nearest of all. Never the
// coach's own. Ties go to the lower id, so the pick is stable.
func (d *Deps) pickGhostFor(coachID uint, rating int32) *domain.GhostTeam {
	all, err := d.Store.Ghosts.Candidates()
	if err != nil {
		return nil
	}
	var bestReal, bestAny *domain.GhostTeam
	dist := func(g *domain.GhostTeam) int32 {
		x := g.EloGhost - rating
		if x < 0 {
			return -x
		}
		return x
	}
	for i := range all {
		g := &all[i]
		if g.CoachID == coachID && coachID != domain.GhostFillerCoach {
			continue
		}
		if bestAny == nil || dist(g) < dist(bestAny) {
			bestAny = g
		}
		if g.CoachID != domain.GhostFillerCoach && dist(g) <= ghostMatchBand &&
			(bestReal == nil || dist(g) < dist(bestReal)) {
			bestReal = g
		}
	}
	if bestReal != nil {
		return bestReal
	}
	return bestAny
}

// eloExpected is the chance an `a`-rated side beats a `b`-rated one.
func eloExpected(a, b int32) float64 {
	return 1 / (1 + math.Pow(10, float64(b-a)/400))
}

// eloMove is the rating change for a side rated `a` against `b` that scored
// `score` (1 win, 0 loss), at factor k.
func eloMove(a, b int32, score, k float64) int32 {
	return int32(math.Round(k * (score - eloExpected(a, b))))
}

// rateGhostFight moves the ratings after a fresh fight against a ghost (not a
// replay). Runs on the fight actor from recordGhostFight; errors are logged.
func (d *Deps) rateGhostFight(ghostID, challenger uint, winnerTeam int8) {
	g, err := d.Store.Ghosts.Get(ghostID)
	if err != nil || g == nil {
		return
	}
	me, err := d.Store.Ghosts.Rating(challenger)
	if err != nil {
		return
	}
	won := winnerTeam == 0
	score := 0.0
	if won {
		score = 1
	}
	k := ghostEloK
	filler := g.CoachID == domain.GhostFillerCoach
	if filler {
		k /= 2
	}
	delta := eloMove(me.Elo, g.EloGhost, score, k)
	before := me.Elo
	me.Elo = max32(me.Elo+delta, ghostEloFloor)
	me.Fights++
	if won {
		me.Wins++
	}
	if err := d.Store.Ghosts.SaveRating(me); err != nil {
		d.Log.Warn("ghost rating not saved", "coach", challenger, "err", err)
	}
	g.Battles++
	if !won {
		g.Wins++
	}
	if !filler {
		g.EloGhost = max32(g.EloGhost-delta, ghostEloFloor)
	}
	if err := d.Store.Ghosts.SaveRecord(g.ID, g.EloGhost, g.Battles, g.Wins); err != nil {
		d.Log.Warn("ghost record not saved", "ghost", g.ID, "err", err)
	}
	d.Log.Info("ghost fight rated", "coach", challenger, "elo", before, "to", me.Elo,
		"ghost", g.ID, "ghost_elo", g.EloGhost, "filler", filler)
}

func max32(a, b int32) int32 {
	if a > b {
		return a
	}
	return b
}

// handleGhostLadder (60016) answers 60017: the caller's own rating, rank and
// record, then the top 50 coaches.
func handleGhostLadder(s *Session, _ *protocol.C2SFrame) error {
	if s.Coach == nil || !s.ghostAllowed() {
		return nil
	}
	s.deps.ensureFillerGhosts()
	me, err := s.deps.Store.Ghosts.Rating(s.Coach.ID)
	if err != nil {
		return err
	}
	rank, _ := s.deps.Store.Ghosts.RankOf(s.Coach.ID)
	top, err := s.deps.Store.Ghosts.Ladder(50)
	if err != nil {
		return err
	}
	w := protocol.NewWriter().I32(me.Elo).I32(int32(rank)).I32(me.Fights).I32(me.Wins).
		U16(uint16(len(top)))
	for _, r := range top {
		name := "?"
		if c, err := s.deps.Store.Coaches.Get(r.CoachID); err == nil && c != nil {
			name = c.Name
		}
		mine := uint8(0)
		if r.CoachID == s.Coach.ID {
			mine = 1
		}
		w.StringU8UTF8(name).I32(r.Elo).I32(r.Fights).I32(r.Wins).U8(mine)
	}
	frame, err := protocol.EncodeS2C(protocol.OpGhostLadder, w.Bytes())
	if err != nil {
		return err
	}
	return s.Send(frame)
}
