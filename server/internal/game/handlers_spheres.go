package game

import (
	"errors"
	"slices"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store"
)

// handlers_spheres.go implements buying a Sphere Board ("Kanodo") node.
//
// The client applies the purchase to its own copy of the fighter and then tells
// the server (`awu_0`), rather than asking first: there is no reply opcode and no
// rejection path. That shapes what this handler is for. It is not a second
// opinion the player sees - it is the authority on what gets PERSISTED, and the
// client's optimistic copy is discarded on the next roster push either way.
//
// So every rule the client enforces is re-derived here from the server's own
// state, never trusted from the packet. A crafted 23009 is otherwise a free
// talent tree: the fighter id, the sphere id and the sacrificed card all arrive
// as raw numbers.

func registerSphereHandlers(r *Router, d *Deps) {
	r.Register(protocol.OpSphereBuy, handleSphereBuy)
}

// handleSphereBuy handles SPHERE_BUY (23009, `aow_2`, arch 3):
// [i64 fighterId][i32 sphereId][i32 cardTemplateId].
//
// cardTemplateId is the card offered to open a Barrier node and is 0 otherwise.
func handleSphereBuy(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	// SECURITY: no sphere purchases while queued or in a fight.
	//
	// This was the FREE TALENT TREE. BuySphere debits XP atomically in the
	// database, but the running fight holds a fighter SNAPSHOT taken at
	// fight-build time, and postFightReport.bank writes that stale row back
	// wholesale at fight end - so every node bought during the fight had its cost
	// refunded while the fighter_spheres rows (a different table, never touched by
	// SaveProgress) survived. Queue a ranked or evolution fight, buy nodes while
	// it runs, repeat: entire boards for nothing.
	//
	// Locking the purchase is the narrow fix. The write-back staleness is real but
	// wider - it also silently reverts mid-fight consumable use - and is recorded
	// separately rather than papered over here.
	if s.rosterLocked() {
		return s.refuseRosterEdit("sphere buy")
	}
	r := protocol.NewReader(f.Payload)
	fighterID, err := r.I64()
	if err != nil {
		return nil
	}
	sphereID, err := r.I32()
	if err != nil {
		return nil
	}
	cardID, _ := r.I32()
	if s.Coach == nil || s.deps.SphereBoards == nil {
		return nil
	}

	// The fighter must be one of THIS coach's, or a coach could spend someone
	// else's experience.
	fighter, ferr := s.deps.Store.Fighters.Get(uint(fighterID))
	if ferr != nil || fighter == nil || fighter.CoachID != s.Coach.ID {
		s.log.Debug("sphere buy: not this coach's fighter", "fighter", fighterID, "coach", s.Coach.ID)
		return nil
	}

	boards := s.deps.SphereBoards
	boardID, cx, cy := SphereCursor(fighter, boards)
	if boardID == 0 {
		return nil
	}
	target := boards.Sphere(sphereID)
	cursor := boards.At(boardID, cx, cy)
	if target == nil || cursor == nil || target.BoardID != boardID {
		// A node from a DIFFERENT board is the cheapest forgery available, so the
		// board id is checked rather than assumed from the node.
		s.log.Debug("sphere buy: node is not on this fighter's board",
			"sphere", sphereID, "board", boardID)
		return nil
	}

	// Only a node that DOES something can be bought; the rest are path cells.
	if !target.HasPayload() || target.DeadEnd {
		s.log.Debug("sphere buy: node is not purchasable", "sphere", sphereID)
		return nil
	}
	if !boards.Reachable(boardID, cursor, target) {
		s.log.Debug("sphere buy: no direct path from the cursor",
			"sphere", sphereID, "from", []int16{cx, cy})
		return nil
	}

	owned, oerr := s.deps.Store.Fighters.SpheresOf(fighter.ID)
	if oerr != nil {
		return oerr
	}
	cost := sphereCost(target, owned)
	if fighter.XP < cost {
		s.log.Debug("sphere buy: not enough experience",
			"sphere", sphereID, "cost", cost, "xp", fighter.XP)
		return nil
	}

	// A Barrier opens only for one of the cards it names, and only if the coach
	// actually holds that card. consumeCard is the same removal the demon totems
	// use, so a card offered but not held buys nothing. One already opened is
	// walked back through for its tenth, with no card again (S48).
	if target.IsBarrier() && !slices.Contains(owned, target.ID) {
		if !sphereAcceptsCard(target, cardID) {
			s.log.Debug("sphere buy: card not accepted by this barrier",
				"sphere", sphereID, "card", cardID)
			return nil
		}
		if !s.consumeCard(cardID) {
			s.log.Debug("sphere buy: barrier card not held", "card", cardID)
			return nil
		}
	}

	// The cursor walks onto the node just bought - including through a portal,
	// where the client also moves it to the node itself rather than to the
	// portal's arrival cell (`awu_0` sets it from the bought sphere).
	if err := s.deps.Store.Fighters.BuySphere(fighter.ID, target.ID, cost, target.X, target.Y); err != nil {
		if errors.Is(err, store.ErrSphereNotAffordable) {
			return nil
		}
		return err
	}
	fighter.XP -= cost
	fighter.SphereX, fighter.SphereY = target.X, target.Y

	s.log.Info("sphere bought", "coach", s.Coach.Name, "fighter", fighter.Name,
		"sphere", target.ID, "cost", cost, "xpLeft", fighter.XP,
		"cursor", []int16{target.X, target.Y})
	return nil
}

// sphereCost is what this fighter pays for this node.
//
// A node it already owns costs a TENTH, which is the client's own arithmetic
// (`afb_1` case 16926: `NE().contains(id) ? aus()/10 : aus()`) and matters
// because a portal can walk a fighter back over ground it has already bought.
// Integer division, deliberately: the client truncates too, and a server that
// rounded up would refuse purchases the client had already offered.
func sphereCost(s *gamedata.Sphere, owned []int32) int32 {
	for _, id := range owned {
		if id == s.ID {
			return s.XPCost / 10
		}
	}
	return s.XPCost
}

// sphereAcceptsCard reports whether a Barrier node opens for this card.
//
// The list IS the rule, with no special case for the 0 the client sends on a
// non-barrier purchase: no shipped barrier names card 0 (410 references across
// 21 distinct cards, none of them zero), so a guard for it would be a branch no
// data can reach and no test can distinguish.
func sphereAcceptsCard(s *gamedata.Sphere, cardID int32) bool {
	for _, id := range s.BarrierCards {
		if id == cardID {
			return true
		}
	}
	return false
}
