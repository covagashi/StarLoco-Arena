package game

import (
	"gorm.io/gorm"
	"math/rand"
	"time"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// resurrectRand is the RNG for resurrection success rolls; tests reseed it via
// SeedResurrectRand for deterministic outcomes (mirrors the fusion RNG).
var resurrectRand = rand.New(rand.NewSource(time.Now().UnixNano()))

// SeedResurrectRand reseeds the resurrection RNG (test hook).
func SeedResurrectRand(seed int64) { resurrectRand = rand.New(rand.NewSource(seed)) }

// rollResurrect reports whether a resurrection of the given percent succeeds,
// mirroring the client's nz_1 effect: rand(1..100) <= pct. 100 always succeeds,
// <=0 never does.
func rollResurrect(pct int32) bool {
	if pct >= 100 {
		return true
	}
	if pct <= 0 {
		return false
	}
	return int32(resurrectRand.Intn(100))+1 <= pct
}

// Evolution mode: the fighter lifecycle behind the overworld GRAVEYARD.
//
// A fighter carries a state byte (domain.FighterState*). While that state is not
// "titular" the fighter is serialized as a type-2 et_2 blob (see
// writeEvolutionTail), which is what files it into the client's evolution roster;
// the graveyard list is exactly the evolution fighters whose state is 3.
//
// Both client actions here are applied OPTIMISTICALLY client-side and consume no
// reply, so the server's job is to reproduce the same state machine, persist it,
// and push refreshed data (6006 + inventory) so a relog agrees with the screen.
//
// See docs/OVERWORLD-MAP.md ("Graveyard / evolution mode").

func registerEvolutionHandlers(r *Router, d *Deps) {
	r.Register(protocol.OpFighterSetState, handleFighterSetState)
	r.Register(protocol.OpFighterUseItemOn, handleFighterUseItemOn)
}

// handleFighterSetState handles FIGHTER_SET_STATE (23000 Jc):
// [i64 fighterId][u8 legendaryToggle]. The message does not carry the NEW state —
// the client computed it locally — so the server replays the same transitions:
//
//	titular  <-> bench          (0 <-> 1)
//	dead      -> graveyard      (2  -> 3, capped at GraveyardCapacity)
//	legendary titular <-> bench (4 <-> 5)
//
// A fighter already in the graveyard stays there: it only comes back via a
// resurrection item (handleFighterUseItemOn).
func handleFighterSetState(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	fighterID, err := r.I64()
	if err != nil {
		return err
	}
	legendary, _ := r.U8() // toggle flag; the transitions below already cover it

	fighter, err := s.deps.Store.Fighters.Get(uint(fighterID))
	if err != nil || fighter == nil || fighter.CoachID != s.Coach.ID {
		return nil // unknown fighter, or not this coach's
	}

	next, ok := nextFighterState(fighter.State)
	if !ok {
		s.log.Debug("fighter state change ignored", "fighter", fighterID,
			"state", fighter.State, "legendary", legendary)
		return nil
	}
	// SECURITY: every destination has a capacity, and only the graveyard's was
	// enforced. The client refuses each of these with its own message and blocks
	// the send (hu_2.java:596-658, nb_0.java:61-88), so any request that reaches
	// here past a cap is forged.
	//
	// The TITULAR cap is the one that mattered: titularRoster feeds evolution and
	// PvE challenge fights, and its 6-limit came only from a `max` argument passed
	// by one caller. Nothing stopped the stored line-up itself from growing.
	if full, err := s.stateIsFull(next); err == nil && full {
		s.log.Debug("fighter state change refused: destination full",
			"coach", s.Coach.Name, "to", next)
		return s.pushFighterList()
	}
	if err := s.setFighterState(fighter, next); err != nil {
		return err
	}
	s.log.Info("fighter state", "coach", s.Coach.Name, "fighter", fighterID,
		"from", fighter.State, "to", next)
	return s.pushFighterList()
}

// nextFighterState returns the state a fighter moves to when the client toggles
// it, and whether the transition is allowed at all.
func nextFighterState(cur uint8) (uint8, bool) {
	switch cur {
	case domain.FighterStateTitular:
		return domain.FighterStateBench, true
	case domain.FighterStateBench:
		return domain.FighterStateTitular, true
	case domain.FighterStateDead:
		return domain.FighterStateGraveyard, true
	case domain.FighterStateLegendary:
		return domain.FighterStateLegBench, true
	case domain.FighterStateLegBench:
		return domain.FighterStateLegendary, true
	default: // graveyard: only a resurrection item gets you out
		return cur, false
	}
}

// handleFighterUseItemOn handles FIGHTER_USE_ITEM (22099 bw):
// [i64 fighterId][i32 cardTemplateId] — the player dropped a consumable kard onto
// a dead or interred fighter. On success the fighter is resurrected:
//
//	graveyard (3) -> bench   (1)
//	dead      (2) -> titular (0)
//
// The card is consumed either way (as in retail), and the refreshed roster +
// inventory are pushed. The client consumes no direct reply.
func handleFighterUseItemOn(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	fighterID, err := r.I64()
	if err != nil {
		return err
	}
	cardID, err := r.I32()
	if err != nil {
		return err
	}

	fighter, err := s.deps.Store.Fighters.Get(uint(fighterID))
	if err != nil || fighter == nil || fighter.CoachID != s.Coach.ID {
		return nil
	}
	revived, ok := resurrectedState(fighter.State)
	if !ok {
		// The fighter is ALIVE, so this is one of the other consumables — a
		// healing potion, a rest balm, a morale boost. Those are the cards a
		// coach actually uses between fights to keep a roster going; without
		// them the wound layer is a one-way ratchet.
		return s.useConsumableOnFighter(fighter, cardID)
	}
	// The card must be what the retail graveyard lets you pick AND drop:
	//   - an Evolution consumable (type 24): the graveyard only lists the
	//     "evolutionSets" (aij_0, aMK.dYy). Equipment also carries the
	//     resurrection effect — its chance to come back during a fight — and
	//     accepting it let a modified client gamble a 57-value Weerdtrot Jacket
	//     (1%) instead of a 33200-value Resurrection (100%);
	//   - with a resurrection effect (action 13): the drop checks xj.DF() →
	//     nz_1.aaF() (aks_2 event 23056, "noConsumableEffectOnDeadFighter").
	// Anything else does nothing and is NOT consumed. param[0] of the effect is
	// the success %. With no card catalogue (dev without data files) fall back
	// to a certain resurrection so the feature still works.
	pct := int32(100)
	if s.deps.Cards != nil {
		card := s.deps.Cards.Get(cardID)
		if card == nil || card.Type != gamedata.CardTypeEvolution || card.ResurrectPercent <= 0 {
			s.log.Debug("use item: not a resurrection consumable",
				"coach", s.Coach.Name, "card", cardID)
			return nil
		}
		// The card's own chance, plus any unlocked SET bonus. The client sums
		// every source of a given AI action the same way (sj_1 accumulates them
		// into one entry per action id), so a coach wearing enough of a set that
		// grants resurrection is meant to be luckier.
		pct = card.ResurrectPercent + s.setBonusFor(aiActionResurrect)
		if pct > 100 {
			pct = 100
		}
	}

	// Resurrecting lands the fighter on the bench, which the client caps.
	if revived == domain.FighterStateBench {
		if n, err := s.countFightersInState(domain.FighterStateBench); err == nil &&
			n >= domain.BenchCapacity {
			s.log.Debug("bench full; resurrection refused", "coach", s.Coach.Name)
			return nil
		}
	}
	if !s.consumeCard(cardID) {
		s.log.Debug("resurrection card not owned", "coach", s.Coach.Name, "card", cardID)
		return nil
	}
	// The card is spent whether or not the roll succeeds — that is the gamble.
	// Push the inventory delta first so the count drops either way.
	s.refreshAndPushInventory()

	if !rollResurrect(pct) {
		// Failure: the card is gone but the fighter stays dead. The client has no
		// "failed" message — it learns from the roster staying unchanged (so we
		// deliberately do NOT push the fighter list here).
		s.log.Info("resurrection failed", "coach", s.Coach.Name, "fighter", fighterID,
			"card", cardID, "pct", pct)
		return nil
	}

	if err := s.setFighterState(fighter, revived); err != nil {
		return err
	}
	s.log.Info("fighter resurrected", "coach", s.Coach.Name, "fighter", fighterID,
		"card", cardID, "to", revived, "pct", pct)
	return s.pushFighterList()
}

// resurrectedState maps a dead/interred state to what a successful resurrection
// returns the fighter to, and whether it can be resurrected at all.
func resurrectedState(cur uint8) (uint8, bool) {
	switch cur {
	case domain.FighterStateGraveyard:
		return domain.FighterStateBench, true
	case domain.FighterStateDead:
		return domain.FighterStateTitular, true
	default:
		return cur, false
	}
}

// setFighterState persists a fighter's evolution state.
func (s *Session) setFighterState(f *domain.Fighter, state uint8) error {
	return s.deps.Store.Fighters.SetState(f.ID, state)
}

// countFightersInState counts how many of the coach's fighters sit in a state
// (used for the graveyard / bench capacity checks).
func (s *Session) countFightersInState(state uint8) (int, error) {
	var n int64
	err := s.deps.Store.DB().Model(&domain.Fighter{}).
		Where("coach_id = ? AND state = ?", s.Coach.ID, state).
		Count(&n).Error
	return int(n), err
}

// consumeCard removes one unit of an unequipped card from the coach's inventory,
// reporting whether it was actually owned.
// SECURITY: this was a read-then-write with no transaction, no guard on the value
// it read, and discarded write errors - so it returned true even when nothing had
// been written. Two goroutines acting for the same coach could both read
// quantity=1 and both "succeed": the card is consumed once and its effect applied
// twice, or a delete runs twice and both callers believe they spent something.
//
// The window is real. kick() closes the socket but the old session's bufio.Reader
// keeps serving frames already buffered (up to 4 KB), so pipelining consumable
// uses on one socket and re-authenticating on another runs two goroutines for one
// coach. Callers are 22099, 5470 and 23009 - all client-reachable.
//
// It is now a single conditional UPDATE. The decrement happens in the database
// (quantity = quantity - 1, not a value read earlier) and the WHERE clause carries
// the precondition, so exactly one of two concurrent callers can match. Errors are
// propagated rather than dropped.
func (s *Session) consumeCard(templateID int32) bool {
	db := s.deps.Store.DB()
	res := db.Model(&domain.CoachCard{}).
		Where("coach_id = ? AND template_id = ? AND pos = 0 AND quantity > 0",
			s.Coach.ID, templateID).
		UpdateColumn("quantity", gorm.Expr("quantity - 1"))
	if res.Error != nil {
		s.log.Warn("consume card", "coach", s.Coach.ID, "template", templateID, "err", res.Error)
		return false
	}
	if res.RowsAffected == 0 {
		return false // not owned, or someone else took the last one first
	}
	// Tidy up a row that has reached zero. Losing this delete is harmless (the
	// quantity > 0 predicate above already makes an empty row unusable), so its
	// failure must not turn a successful consume into a reported failure.
	if err := db.Where("coach_id = ? AND template_id = ? AND pos = 0 AND quantity <= 0",
		s.Coach.ID, templateID).Delete(&domain.CoachCard{}).Error; err != nil {
		s.log.Warn("prune empty card row", "coach", s.Coach.ID, "template", templateID, "err", err)
	}
	return true
}

// stateIsFull reports whether a fighter state has reached its capacity.
//
// Capacities are the retail client's own (hu_2.java / nb_0.java): 6 titular,
// 7 bench, 5 graveyard, 6 legendary titular, 9 legendary bench.
func (s *Session) stateIsFull(state uint8) (bool, error) {
	var cap int
	switch state {
	case domain.FighterStateTitular:
		cap = maxTeamMembers // 6
	case domain.FighterStateBench:
		cap = domain.BenchCapacity // 7
	case domain.FighterStateGraveyard:
		cap = domain.GraveyardCapacity // 5
	case domain.FighterStateLegendary:
		cap = maxTeamMembers // 6
	case domain.FighterStateLegBench:
		cap = legendaryBenchCapacity // 9
	default:
		return false, nil // no capacity concept
	}
	n, err := s.countFightersInState(state)
	if err != nil {
		return false, err
	}
	return n >= cap, nil
}

// legendaryBenchCapacity mirrors hu_2.java:640-643 (`n8 >= 9`).
const legendaryBenchCapacity = 9
