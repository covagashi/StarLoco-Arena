package game

import (
	"fmt"
	"sort"
	"strings"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// stateSummary renders a fighter's active states compactly for the dev fight
// dump, e.g. "[immune:2 stab:1]" (empty when the fighter has none).
func (ff *FightFighter) stateSummary() string {
	if ff == nil || len(ff.States) == 0 {
		return ""
	}
	names := map[fighterState]string{
		stateRooted: "root", statePetrified: "petrify", stateStabilized: "stab",
		stateAnchored: "anchor", stateIntransposable: "intransp",
		stateInvisible: "invis", stateImmune: "immune", stateSkipTurn: "skip",
		stateDrunk: "drunk", stateMaskClass: "maskCls", stateMaskCoward: "maskCow",
		stateMaskBerzerk: "maskBzk",
	}
	parts := make([]string, 0, len(ff.States))
	for s, turns := range ff.States {
		if turns > 0 {
			parts = append(parts, fmt.Sprintf("%s:%d", names[s], turns))
		}
	}
	sort.Strings(parts)
	return "[" + strings.Join(parts, " ") + "]"
}

// states.go models the status effects a spell can inflict (mh_2 state actions)
// and enforces them server-side. On the wire a state is an ordinary running
// effect (the standard 3-part blob, value 0, Nx = duration) whose action id
// selects the client handler that renders + tracks the state; the server mirrors
// it with a per-fighter remaining-turn count and applies the rule the client
// cannot enforce on a server-driven (summon/AI) fighter:
//
// Each state maps 1:1 onto a FIGHTER PROPERTY the client tracks (enum avx_0),
// and the client itself tells us exactly what each one forbids — the four
// displacement immunities are NOT interchangeable:
//
//   - rooted (65 "Immobilisé" → property dex): the client's rc_0 sets the
//     fighter's MP characteristic (Lr.bqz) to 0, so a rooted fighter cannot
//     WALK. This is the only state that stops self-movement.
//   - petrified (96 → dew): cannot act — its turn is skipped (the client zeroes
//     both AP and MP for this property).
//   - stabilised (94 "Stabilisation" → dev): blocks ONLY Push (37) and Pull
//     (38) — mv_1 gates exactly na_2/sa_2 on this property.
//   - anchored (127 "S'enraciner" → deA): blocks ONLY Carry (58 Jk).
//   - intransposable (128 "Rendre intransposable" → deB): blocks ONLY
//     swap-position (64 aox_1).
//   - invisible (57): unseen — the AI cannot target it.
//   - immune (95 death-immunity / 124 immunity): takes no damage.
//   - skip-turn (56 "Fin de tour" / 111 "Passe son tour"): its next turn(s) are
//     passed; the count is consumed one per skipped turn (not aged per round).
//
// 127 and 128 were previously folded into rooted/stabilised. That was wrong in a
// way that mattered: 127 made its target unable to move at all (and zeroed its
// MP), when in the real client it only prevents being picked up. It is also what
// the round-1 event card "Cloué au lit" (event 14 = 94+127+128) applies, so the
// bug froze the whole arena on the opening round. See BUGS.md B-053.
type fighterState uint8

const (
	stateRooted fighterState = iota
	statePetrified
	stateStabilized
	stateAnchored
	stateIntransposable
	stateInvisible
	stateImmune
	stateSkipTurn
	// The following are states that cast-criteria read (see criteria.go) rather
	// than the server enforcing a movement/damage rule. Drunk (126) is set by its
	// spell. The three Masqueraider masks (173/174/175) are permanent (infinite
	// duration) and mutually exclusive — a mask-switch spell strips the previously
	// worn mask via its bundled action-149 removes (see removeEffectByID), not an
	// ad-hoc rule; each spell is also self-gated by cannotCastWhenMask<self>.
	stateDrunk
	stateMaskClass
	stateMaskCoward
	stateMaskBerzerk
	// stateRedirected is the client's deC, set by 139 "Redirection des
	// dégâts" (aOp). The redirect itself is visual; the state is what target
	// mask bit 55 reads.
	stateRedirected
)

// stateByAction maps an mh_2 state action id to the modelled state.
var stateByAction = map[int32]fighterState{
	65:  stateRooted,         // Immobilisé            → dex: MP = 0, cannot walk
	96:  statePetrified,      // Pétrifié, ne peut jouer → dew: AP+MP = 0
	94:  stateStabilized,     // Stabilisation          → dev: no push (37) / pull (38)
	127: stateAnchored,       // S'enraciner            → deA: cannot be carried (58)
	128: stateIntransposable, // Rendre intransposable  → deB: cannot be swapped (64)
	57:  stateInvisible,      // Devenir invisible
	95:  stateImmune,         // Immunisé aux effets de mort
	124: stateImmune,         // Devenir immunisé
	56:  stateSkipTurn,       // Fin de tour
	111: stateSkipTurn,       // Passe son tour
	126: stateDrunk,          // Devenir ivre (tracked for canCastWhenDrunk)
	173: stateMaskClass,      // Porter le masque classe   (tracked for canCastWhenMaskClass)
	174: stateMaskCoward,     // Porter le masque trouillard (canCastWhenMaskCoward)
	175: stateMaskBerzerk,    // Porter le masque berzerk  (canCastWhenMaskBerzerk)
}

// consumeSkipTurn spends one skipped turn, clearing the state at zero. Called
// from beginTurn when the fighter's turn is passed by a skip-turn state.
func (ff *FightFighter) consumeSkipTurn() {
	if ff == nil || ff.States[stateSkipTurn] <= 0 {
		return
	}
	if ff.States[stateSkipTurn] <= 1 {
		delete(ff.States, stateSkipTurn)
	} else {
		ff.States[stateSkipTurn]--
	}
}

// classifyState returns the state an action id inflicts, and whether it is one.
func classifyState(actionID int32) (fighterState, bool) {
	s, ok := stateByAction[actionID]
	return s, ok
}

// hasState reports whether ff currently carries state s.
func (ff *FightFighter) hasState(s fighterState) bool {
	return ff != nil && ff.States[s] > 0
}

// addState grants (or extends, never shortens) state s for `turns` table-turns.
func (ff *FightFighter) addState(s fighterState, turns int32) {
	if turns <= 0 {
		turns = 1
	}
	if ff.States == nil {
		ff.States = make(map[fighterState]int32)
	}
	if turns > ff.States[s] {
		ff.States[s] = turns
	}
}

// applyState inflicts the effect's status on the fighter at `cell` for its
// duration and broadcasts the state running-effect so the client renders it.
// Rooting also zeroes the target's MP this turn (matching the client's rc_0).
func (f *Fight) applyState(caster *FightFighter, ef gamedata.Effect, cell Pos) {
	victim := f.fighterAtCell(cell)
	if victim == nil {
		return
	}
	st, ok := classifyState(ef.ActionID)
	if !ok {
		return
	}
	turns, infinite := ef.DurationTurns()
	dur := turns
	if infinite {
		dur = infiniteStateTurns
	}
	victim.addState(st, dur)
	if st == stateRooted {
		victim.MP = 0
	}
	// Remember which effect set this state so action 149 can strip it by effectId
	// (e.g. a mask-switch spell removing the previously-worn mask).
	if victim.stateSrc == nil {
		victim.stateSrc = make(map[fighterState]int32)
	}
	victim.stateSrc[st] = ef.EffectID
	eff, _ := buildRunningEffect(f.nextActionUID(), ef.ActionID, ef.EffectID,
		caster.WireID, victim.WireID, victim.Pos, 0, 0, false,
		sourceSpellPart(f.sourceSpellID))
	f.broadcast(eff)
}

// infiniteStateTurns is the remaining-turn count used for an "infinite"
// (duration ≥ 63) state — large enough to outlast any practice fight, and left
// un-decremented by tickStates so it persists.
const infiniteStateTurns int32 = 63

// tickStates ages every fighter's finite states by one table-turn and clears
// those that expire. Infinite states (≥ 63) are left untouched. Called at each
// new table turn alongside tickBuffs.
func (f *Fight) tickStates() {
	for _, ff := range f.allFighters() {
		if len(ff.States) == 0 {
			continue
		}
		for s, turns := range ff.States {
			if turns >= infiniteStateTurns || s == stateSkipTurn {
				continue // permanent, or (skip-turn) consumed per turn not per round
			}
			if turns <= 1 {
				delete(ff.States, s)
				delete(ff.stateSrc, s)
			} else {
				ff.States[s] = turns - 1
			}
		}
	}
}

// effectiveAP / effectiveMP mirror the client's `gn_0.d(characteristic)` — the
// EFFECTIVE-value getter, as opposed to `gn_0.c`, which returns the raw stored
// value:
//
//	d(Lr.bqz /*MP*/): 0 if the fighter has avx_0.dew (petrified) OR dex (rooted)
//	d(Lr.bqy /*AP*/): 0 if the fighter has avx_0.dew (petrified)
//
// The client DERIVES the zero rather than storing it, which matters in two ways.
// It is not merely cosmetic: "damage par PA/PM possédé" scales off this value,
// so a rooted caster's MP-scaled spell deals nothing in the retail client while
// the raw reading would have it deal full damage. And because it is derived, a
// root that ends restores the resource immediately, with nothing to restore —
// which is why refillFighter deliberately still refills the RAW value.
func (ff *FightFighter) effectiveAP() int32 {
	if ff == nil {
		return 0
	}
	if ff.hasState(statePetrified) {
		return 0
	}
	return ff.AP
}

func (ff *FightFighter) effectiveMP() int32 {
	if ff == nil {
		return 0
	}
	if ff.hasState(statePetrified) || ff.hasState(stateRooted) {
		return 0
	}
	return ff.MP
}

// canAct reports whether this fighter may take a combat action right now.
//
// SECURITY: being "on turn" is not the same as being able to act. beginTurn does
// not skip a petrified or skipping fighter synchronously - it broadcasts
// FIGHTER_TURN_BEGIN, refills raw AP/MP, and ARMS a 1200 ms timer to end the turn
// (handlers_fight.go). For those 1200 ms isCurrentTurn is true and the resources
// are full, so a modified client could cast, use cards and move freely: an effect
// whose entire purpose is to cost a turn cost nothing.
//
// The retail client refuses a petrified caster in both of its validators
// (mv_1.java:298-300 for spells, :415-417 for cards) and its pathfinder returns 0
// MP for petrified or rooted, so no honest client ever sends these.
func (ff *FightFighter) canAct() bool {
	if ff == nil || ff.HP <= 0 {
		return false
	}
	return !ff.hasState(statePetrified)
}
