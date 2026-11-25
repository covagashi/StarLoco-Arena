package game

import (
	"github.com/StarLoco/arena-2.70/internal/domain"
)

// Nilo's practice (challenge 46, "Tutorial de Baan"), S52. The owner chose
// (2026-11-25) «1 contra 1 con un muñeco»: the coach's FIRST titular alone,
// on the smallest arena, against a training dummy that never acts, standing a
// few steps from the player's start so the first turn reaches it, and that
// falls to exactly two blows of whatever the player hits it with — the
// client's guided practice (godot/src/fight/practice_*.gd) says "one more and
// it falls" after the first, and that is true by construction:
//
//   - every damaging hit on the dummy takes HALF its maximum life (rounded up),
//     whatever the attack, a critical included (dummyBlow);
//   - its maximum life is twice the base damage of the player's lesson attack
//     (the cheapest damaging spell that reaches the next cell, else the weapon),
//     so the number that floats over it reads like that attack's own (at most
//     a breed-1 fighter's life, which the wire counts it from).
//
// Nothing else changes: every other challenge is built as before.

const (
	// practiceChallenge is Nilo's practice.
	practiceChallenge int32 = 46
	// practiceWorld is the arena it is played on: world 15, the smallest of the
	// six (101 floor cells), its start cells close together.
	practiceWorld uint16 = 15
	// dummyName is the dummy's wire name. The client shows its own words for it
	// (godot/src/gamedata/ai_names.gd → npc.316) and its figure (the stuffed
	// sack, summon look 8003), so keep the two in step.
	dummyName = "Mannequin"
	// dummySteps is how many steps from the player's start cell the dummy
	// stands: the cell beside it is two steps away, inside any fighter's MP.
	dummySteps       = 3
	dummyMinHP int32 = 10
	// practiceNoSuddenDeath is the practice's sudden-death turn: never.
	practiceNoSuddenDeath int32 = 1 << 30
)

// dummyBlow is the damage a hit of `dmg` really deals to `ff`: half the
// dummy's maximum life for a training dummy, `dmg` for everyone else.
func dummyBlow(ff *FightFighter, dmg int32) int32 {
	if ff == nil || !ff.Dummy || dmg <= 0 {
		return dmg
	}
	return (ff.MaxHP + 1) / 2
}

// practiceArenaFor is the arena Nilo's practice is played on (the fallback
// arena when the maps are not loaded, as in unit tests).
func (d *Deps) practiceArenaFor() *arena {
	if d.hasArena(practiceWorld) {
		return d.arenaByID(practiceWorld)
	}
	return d.pickArena()
}

// lessonDamage is the base damage of the player's lesson attack: the cheapest
// damaging spell it can cast at the next cell, else the bare-hand blow.
func (d *Deps) lessonDamage(ff *FightFighter) int32 {
	best, bestAP := closeCombatDamages, int8(127)
	if d == nil || d.Spells == nil || ff == nil || ff.Fighter == nil {
		return best
	}
	for _, fs := range ff.Fighter.Spells {
		sp := d.Spells.Get(fs.SpellID)
		if sp == nil || sp.AP <= 0 || int32(sp.AP) > ff.MaxAP || sp.RangeMin > 1 || sp.RangeMax < 1 {
			continue
		}
		dmg, _, ok := sp.Damage()
		if !ok || dmg <= 0 {
			continue
		}
		if sp.AP < bestAP {
			best, bestAP = dmg, sp.AP
		}
	}
	return best
}

// buildDummyTeam is the practice's other side: one dummy, placed dummySteps
// steps (on foot, round fighters and scenery) from the player's fighter,
// the candidate nearest the arena's centre; it never acts (runAITurn), has
// no AP or MP and no initiative, so the player opens.
func (d *Deps) buildDummyTeam(side uint8, a *arena, player *FightTeam) *FightTeam {
	coach := &domain.Coach{ID: challengeCoachID, Name: challengeOpponentName(practiceChallenge)}
	var from Pos
	var lead *FightFighter
	if player != nil && len(player.Fighters) > 0 {
		lead = player.Fighters[0]
		from = lead.Pos
	}
	hp := 2 * d.lessonDamage(lead)
	// at most its breed's life: the wire counts the dummy's from there
	// (writeCombatFighterBlob)
	hp = max(dummyMinHP, min(fighterMaxHP(1), hp))
	ff := &FightFighter{
		WireID:  FighterWireIDBase + int64(practiceChallenge)*1024 + int64(side)*8,
		CoachID: challengeCoachID,
		TeamID:  side,
		Fighter: &domain.Fighter{Name: dummyName, BreedID: 1},
		Pos:     dummyCell(a, from),
		MaxHP:   hp, HP: hp,
		// below any fighter (0 would read the breed's): the player's side chooses
		Init:  -1,
		Dummy: true,
	}
	return &FightTeam{ID: side, Members: []*FightMember{{Coach: coach}}, Fighters: []*FightFighter{ff}}
}

// dummyCell is the floor cell dummySteps steps from `from` (fewer when the
// arena is too small) that is nobody's start cell, nearest the centre.
func dummyCell(a *arena, from Pos) Pos {
	start := map[[2]int32]bool{}
	for _, side := range []uint8{0, 1} {
		for _, c := range a.startCells(side) {
			start[[2]int32{c.X, c.Y}] = true
		}
	}
	type node struct {
		p    Pos
		dist int
	}
	seen := map[[2]int32]bool{{from.X, from.Y}: true}
	queue := []node{{from, 0}}
	var best Pos
	bestDist, bestCentre := -1, int32(1<<30)
	for len(queue) > 0 {
		n := queue[0]
		queue = queue[1:]
		if n.dist > 0 && !start[[2]int32{n.p.X, n.p.Y}] {
			centre := absI32(n.p.X-a.centerX) + absI32(n.p.Y-a.centerY)
			if n.dist > bestDist || (n.dist == bestDist && centre < bestCentre) {
				best, bestDist, bestCentre = n.p, n.dist, centre
			}
		}
		if n.dist == dummySteps {
			continue
		}
		for _, s := range [][2]int32{{1, 0}, {-1, 0}, {0, 1}, {0, -1}} {
			x, y := n.p.X+s[0], n.p.Y+s[1]
			if seen[[2]int32{x, y}] || !a.walkable(x, y) {
				continue
			}
			seen[[2]int32{x, y}] = true
			queue = append(queue, node{Pos{X: x, Y: y, Z: a.at(x, y).alt}, n.dist + 1})
		}
	}
	if bestDist < 0 {
		return from
	}
	return best
}
