package game

import (
	"math/rand"
	"sync"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/store"
)

// drops.go wires the post-fight card draw — the mechanic behind the AI18-21
// card effects, which sat inert for a long time under "not recoverable from
// the client". It turned out the client ships the whole algorithm dead:
// `alb_1` (ported as gamedata.DrawTable) is registered by every card through
// `eh_2`/`la_0.XJ().a()` but has no call site in the client — because the draw
// ran server-side and the class is shared Ankama library code.
//
// The surviving unknowns are only the two call-site arguments, and the data
// answers both:
//
//	n2 (the bucket level, 0-50) — the draw tier. Buckets correlate 1:1 with
//	    RequiredLevel tiers (lvl0→b1-10, lvl5→11-15, lvl10→16-19, lvl15→20-24,
//	    lvl20→25-29, lvl25→30-34, lvl30→35-37, lvl35/40→42-49), and the pet
//	    i18n says a familiar "simule un niveau de plus pour le joueur" — the
//	    draw runs at the PLAYER's evolution level, shifted by the equipped
//	    AI20/AI21 params.
//	n3 (the bonus) — the map's own AI19 action (type-1600 record: arenas
//	    86-109 carry +1..25%) plus every equipped card's AI19/AI18 params.
//
// The draw is worth exactly one card per call (`cl` loops until one keeps).
// The map record's second field, eliteDropBonus ("Bonus Elite : N"), is the
// one unproven byte — displayed bare, it reads as a count, so we grant it as
// N EXTRA draws on non-practice wins (the reading consistent with both its
// name and its formatting; flagged here if evidence ever contradicts it).

// AI-enum ids for the drop family (AI.aHN..aHQ); the post-fight META ids live
// in postfight_apply.go.
const (
	aiDropBonus    int32 = 18 // "Modification du bonus au drop"
	aiDropChance   int32 = 19 // "Modification des chances de drop"
	aiDropMinLevel int32 = 20 // "Modification du niveau minimum des objets droppés"
	aiDropMaxLevel int32 = 21 // "Modification du niveau maximum des objets droppés"
)

// drawTableOnce builds the alb_1 table lazily so tests can inject Deps{Cards}
// without ever thinking about the table, and a server without gamedata simply
// never drops.
var (
	drawTableOnce sync.Once
	drawTable     *gamedata.DrawTable
	drawTableRNG  = rand.New(rand.NewSource(rand.Int63()))
)

func (d *Deps) cardDrawTable() *gamedata.DrawTable {
	if d == nil || d.Cards == nil {
		return nil
	}
	if d.DrawTable != nil {
		return d.DrawTable
	}
	drawTableOnce.Do(func() {
		if drawTable == nil {
			drawTable = gamedata.NewDrawTable(d.Cards, drawTableRNG)
		}
	})
	return drawTable
}

// equippedEffectBonus sums params[0] of the given AI action over the coach's
// EQUIPPED cards' own effect arrays — the card-level counterpart of
// setBonusFor, which only sees set bonuses. The same level gate applies
// ("your evolution level is too low to benefit from this equipment's
// bonuses", sj_1.java:346-366): a card the coach cannot benefit from
// contributes nothing.
func (s *Session) equippedEffectBonus(action int32) int32 {
	if s == nil || s.Coach == nil || s.deps == nil || s.deps.Cards == nil {
		return 0
	}
	level := StandingToLevel(s.Coach.Standing)
	var total int32
	for _, inv := range s.Coach.Inventory {
		if inv.Pos < 1 {
			continue
		}
		tmpl := s.deps.Cards.Get(inv.TemplateID)
		if tmpl == nil || tmpl.RequiredLevel > level {
			continue
		}
		for _, ef := range tmpl.Effects {
			if ef.Action == action && len(ef.Params) > 0 {
				total += ef.Params[0]
			}
		}
	}
	return total
}

// rollFightDrops runs the post-fight card draw for a victorious real coach and
// grants the results. Returns the granted template ids (one entry per copy —
// the wonCards blob shows an icon per card), nil when the draw ran dry (no
// table, empty pool, or a reject streak hitting the roll cap).
func (d *Deps) rollFightDrops(f *Fight, coach *domain.Coach, sess *Session) []int32 {
	t := d.cardDrawTable()
	if t == nil || d.Store == nil || coach == nil {
		return nil
	}
	// n2: the coach's evolution level, shifted by the drop-level effects it
	// has equipped (the familiar "simulates one more level" of the i18n).
	level := int(StandingToLevel(coach.Standing))
	level += int(sess.equippedEffectBonus(aiDropMinLevel)) +
		int(sess.equippedEffectBonus(aiDropMaxLevel))
	// n3: the map's own drop-chance action (type-1600) plus every equipped
	// drop-chance/bonus modifier the coach wears.
	var bonus int32
	if d.MapBonuses != nil && f != nil && f.Arena() != nil {
		bonus += d.MapBonuses.DropChanceBonus(int16(f.Arena().worldID))
	}
	bonus += sess.equippedEffectBonus(aiDropChance) + sess.equippedEffectBonus(aiDropBonus)

	draws := 1
	if f != nil && !f.Practice && d.MapBonuses != nil && f.Arena() != nil {
		if mb := d.MapBonuses.Get(int16(f.Arena().worldID)); mb != nil {
			draws += int(mb.EliteDropBonus)
		}
	}

	var won []int32
	for i := 0; i < draws; i++ {
		c := t.Draw(level, bonus)
		if c == nil {
			break
		}
		won = append(won, c.ID)
	}
	if len(won) == 0 {
		return nil
	}
	grants := make([]store.GrantCard, 0, len(won))
	for _, id := range won {
		grants = append(grants, store.GrantCard{TemplateID: id, Quantity: 1})
	}
	if err := d.Store.Coaches.GrantCards(coach.ID, grants); err != nil {
		d.Log.Warn("fight drop grant failed", "coach", coach.ID, "err", err)
		return nil
	}
	d.Log.Info("fight drops", "coach", coach.Name, "level", level, "bonus", bonus,
		"draws", draws, "cards", won)
	// Same inventory refresh as awardChallengeRewards: the session's view stays
	// stale without it even though the 8300 blob already names the won cards.
	if sess != nil {
		if fresh, err := d.Store.Coaches.Get(coach.ID); err == nil {
			if sess.Coach != nil {
				sess.Coach.SetInventory(fresh.Inventory)
			}
			if err := sess.pushInventory(fresh); err != nil {
				d.Log.Warn("push inventory after fight drop", "coach", coach.ID, "err", err)
			}
		}
	}
	return won
}
