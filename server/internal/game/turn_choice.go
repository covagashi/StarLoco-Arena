package game

import (
	"sort"

	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// turn_choice.go: who opens the fight (S46, owner 2026-11-19: "el que gana la
// iniciativa elige turno").
//
// Moving second was an advantage: whoever steps into the other's reach first
// takes the first hit, so high initiative LOST fights (+30 on all three: 16 %
// in the mirror). Now the turns alternate team by team, each team in its own
// initiative order, and the team with more initiative (the sum of its
// fighters') chooses during placement whether it opens or cedes. Initiative is
// therefore always worth having: at worst its owner picks what the other side
// would have had.
//
// A human chooser sends 60050 while placing (no choice = open); a server-driven
// one (challenge AI, ghosts) decides at the end of placement, when the cells
// are known (aiOpens). 60051 tells every Godot session the order. The opening
// side's fighters walk further on their first turn (openerFirstTurnMP).

// openerFirstTurnMP is the MP the opening side's fighters get on top of their
// own on their first turn (owner 2026-11-19: "+PM al que abre"). With the
// retail numbers the opener walked into reach first and lost (27 % in the
// mirror); after S46's class pass and AI fixes opening is even with or
// without it (TestTurnChoiceSim: +0 0.49, +2 0.47, +3 0.51) and +4 tips it
// (0.71). +2 is kept as the owner's rule at its least disruptive. (A first
// +2 had looked right only because the bonus made the opener's AI a kiter
// that walked away on turn 1; see classifyAI.) Sent in 60051 so the client
// counts it.
var openerFirstTurnMP int32 = 2

// openerBonusMP is the extra MP ff starts this turn with: its first turn, on
// the opening side, and not a summon.
func (f *Fight) openerBonusMP(ff *FightFighter) int32 {
	if ff.turnsTaken != 0 || ff.isSummon() || ff.TeamID != f.opener {
		return 0
	}
	return openerFirstTurnMP
}

// teamInitiative is a side's initiative: the sum of its fighters'.
func teamInitiative(t *FightTeam) (sum, best int32) {
	if t == nil {
		return 0, 0
	}
	for _, ff := range t.Fighters {
		v := fighterInit(ff)
		sum += v
		best = max(best, v)
	}
	return sum, best
}

// initiativeChooser is the side that chooses: more initiative, then the
// fastest single fighter, then side 0.
func initiativeChooser(f *Fight) uint8 {
	s0, b0 := teamInitiative(f.Teams[0])
	s1, b1 := teamInitiative(f.Teams[1])
	if s1 > s0 || s1 == s0 && b1 > b0 {
		return 1
	}
	return 0
}

// buildTimelineOpening orders the fighters for the given opening side: the
// sides alternate, each in descending initiative (stable, so ties keep the
// team order); the larger side's leftovers go last.
func buildTimelineOpening(f *Fight, opener uint8) []*FightFighter {
	var sides [2][]*FightFighter
	for i, t := range f.Teams {
		if t == nil {
			continue
		}
		s := append([]*FightFighter(nil), t.Fighters...)
		sort.SliceStable(s, func(a, b int) bool { return fighterInit(s[a]) > fighterInit(s[b]) })
		sides[i] = s
	}
	first, second := sides[opener&1], sides[(opener+1)&1]
	var tl []*FightFighter
	for i := 0; i < max(len(first), len(second)); i++ {
		if i < len(first) {
			tl = append(tl, first[i])
		}
		if i < len(second) {
			tl = append(tl, second[i])
		}
	}
	return tl
}

// setOpener rebuilds the timeline with `opener` opening. Placement only: the
// order is fixed once the action phase starts.
func (f *Fight) setOpener(opener uint8) {
	f.opener = opener & 1
	f.Timeline = buildTimelineOpening(f, f.opener)
}

// chooserIsServerDriven reports whether no real coach sits on the choosing side.
func (f *Fight) chooserIsServerDriven() bool {
	t := f.Teams[f.chooser]
	if t == nil {
		return true
	}
	for _, m := range t.Members {
		if m.Session != nil {
			return false
		}
	}
	return true
}

// aiOpens is a server-driven chooser's pick, on the placed cells: open when
// one of its fighters could hurt an enemy on its first turn (its walk, the
// opener's extra MP, its longest harmful range); otherwise cede. Measured
// after S46: its pick 0.48, always opening 0.51, always ceding 0.54 —
// within the noise, so initiative no longer decides fights.
func (f *Fight) aiOpens() bool {
	t := f.Teams[f.chooser]
	if t == nil {
		return true
	}
	for _, ff := range t.Fighters {
		reach := ff.MaxMP + openerFirstTurnMP + f.aiStrikeRange(ff)
		for _, o := range f.allFighters() {
			if o.HP > 0 && f.areOpponents(ff, o) && manhattanDist(ff.Pos, o.Pos) <= reach {
				return true
			}
		}
	}
	return false
}

// serverChooserOpens is how a server-driven chooser decides; the balance
// simulation swaps it to measure a fixed policy.
var serverChooserOpens = (*Fight).aiOpens

// settleOpener runs as placement ends: a server-driven chooser decides now.
func (f *Fight) settleOpener() {
	if f.chooserIsServerDriven() {
		if serverChooserOpens(f) {
			f.setOpener(f.chooser)
		} else {
			f.setOpener(f.chooser ^ 1)
		}
	}
	f.sendTurnOrder(nil)
}

// buildTurnOrder is 60051: [u8 chooser side][u8 opening side][u8 opener's
// first-turn MP][u8 n]{[i64 wireId]}.
func buildTurnOrder(f *Fight) ([]byte, error) {
	w := protocol.NewWriter()
	w.U8(f.chooser)
	w.U8(f.opener)
	w.U8(uint8(openerFirstTurnMP))
	w.U8(uint8(len(f.Timeline)))
	for _, ff := range f.Timeline {
		w.I64(ff.WireID)
	}
	return protocol.EncodeS2C(protocol.OpTurnOrder, w.Bytes())
}

// sendTurnOrder sends 60051 to one session, or (nil) to every Godot coach and
// every spectator (the replay recorder among them).
func (f *Fight) sendTurnOrder(to *Session) {
	frame, err := buildTurnOrder(f)
	if err != nil {
		return
	}
	if to != nil {
		if to.godot.Load() {
			_ = to.Send(frame)
		}
		return
	}
	for _, s := range f.sessions() {
		if s.godot.Load() {
			_ = s.Send(frame)
		}
	}
	for _, s := range f.spectators {
		_ = s.Send(frame)
	}
}

func registerTurnChoiceHandlers(r *Router, _ *Deps) {
	r.Register(protocol.OpTurnChoice, handleTurnChoice)
}

// handleTurnChoice is 60050 [u8 open]: the choosing coach opens (1) or cedes
// (0). Placement only, and only a coach of the choosing side.
func handleTurnChoice(s *Session, frame *protocol.C2SFrame) error {
	f := s.deps.Fights.ByCoach(coachID(s))
	if f == nil {
		return nil
	}
	r := protocol.NewReader(frame.Payload)
	open, err := r.U8()
	if err != nil {
		return nil
	}
	cid := s.Coach.ID
	f.Post(func(f *Fight) {
		if f.applyTurnChoice(cid, open != 0) {
			f.sendTurnOrder(nil)
		}
	})
	return nil
}

// applyTurnChoice is coach cid opening (or ceding) for the choosing side. It
// reports whether the choice was taken: placement only, the choosing side only.
func (f *Fight) applyTurnChoice(cid uint, open bool) bool {
	if f.Phase() != PhasePlacement {
		return false
	}
	t := f.Teams[f.chooser]
	if t == nil || t.MemberFor(cid) == nil {
		return false
	}
	if open {
		f.setOpener(f.chooser)
	} else {
		f.setOpener(f.chooser ^ 1)
	}
	return true
}
