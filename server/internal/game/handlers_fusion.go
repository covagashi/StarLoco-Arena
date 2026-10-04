package game

import (
	"errors"
	"math/rand"
	"sync"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store"
)

// Fusion result codes carried by FusionResult(5491).
const (
	fusionResultOK    uint8 = 0 // request processed (outcome in the card ids)
	fusionResultError uint8 = 1 // malformed / invalid request
)

// The altar's SUCCESS die is its own quality field: `roll < lab.Quality +
// Σ inputs' FusionQuality` wins. Evidence: the fusion panel (`ajt_1`) exposes
// exactly three numbers — "labPower" (the altar's power), "kardsPower"
// (Σ inputs' RequiredLevel − target.FusionPower) and "quality" (the altar's
// tA byte). Power and quality are the only lab stats the player is shown,
// and the boost cards (family 27) carry exactly the same pair: FusionPower
// for the power side, FusionQuality for the quality side. Quality runs
// 1..50 across the 30 labs — a percentage scale, and the only field left to
// roll on once power covers the recipe cost.
const fusionMaxRoll = 100

// maxFusionInputs bounds the ids accepted from a single 5490 request.
const maxFusionInputs = 32

// fusionRand is the RNG used for fusion rolls; tests may reseed it via
// SeedFusionRand for deterministic outcomes. Guarded by its own mutex —
// rand.Rand is not goroutine-safe and every session shares this stream.
var (
	fusionRand   = rand.New(rand.NewSource(1))
	fusionRandMu sync.Mutex
)

// SeedFusionRand reseeds the fusion RNG (test hook for deterministic outcomes).
func SeedFusionRand(seed int64) {
	fusionRandMu.Lock()
	fusionRand = rand.New(rand.NewSource(seed))
	fusionRandMu.Unlock()
}

// fusionRoll draws one 0..fusionMaxRoll-1 outcome from the shared stream.
func fusionRoll() int {
	fusionRandMu.Lock()
	defer fusionRandMu.Unlock()
	return fusionRand.Intn(fusionMaxRoll)
}

func registerFusionHandlers(r *Router, d *Deps) {
	r.Register(protocol.OpFusionRequest, handleFusionRequest)
}

// handleFusionRequest (5490 C2S: [i32 count]{i32 cardId}) runs the Fusion Lab.
//
// THE LAST ID IS THE TARGET, NOT AN INPUT. The client builds the array as the
// input list with the chosen card inserted at index 0 (`add.java`:
// `jg_02.v(0, ajt_16.azv())`), and `ahg_0.encode()` then writes it REVERSED, so
// the player's chosen card lands last on the wire. `azv()` is `cCr`, which the
// fusion panel exposes as the property "fusionCard" — the card the player is
// trying to MAKE. Reading every id as an input, as this used to, both consumed
// the player's chosen card as fuel and threw away their choice.
//
// The outcome is therefore the CHOSEN card, not a random one. The gate on what
// may be chosen is the client's own ("mustBeFusionCard"): only cards carrying
// FusionPower/FusionQuality may be named — plus the value ceiling below, since
// a player-supplied target otherwise lets anyone fuse two commons into the best
// card in the game.
//
// Replies with FusionResult(5491) carrying [obtained][notObtained][recovered],
// which the client renders as four distinct outcomes (`cp_0`, case 5491):
// obtained -> "fusionSuccess", notObtained -> "fusionRecipeFailed", recovered ->
// "fusionLeftovers", none -> "fusionFailed". Sending the target back as
// notObtained on a failed roll is what makes the client name the card that was
// missed instead of showing a bare failure.
func handleFusionRequest(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	n, err := r.I32()
	if err != nil {
		return err
	}
	// >= 3: the target plus the client's own minimum of two inputs
	// (`ajt_1`'s "canFusion" is `cCq.size() >= 2`).
	if n < 3 || n > maxFusionInputs || s.deps.Cards == nil {
		return s.sendFusionResult(fusionResultError, 0, 0, 0)
	}
	ids := make([]int32, 0, n)
	for i := int32(0); i < n; i++ {
		id, err := r.I32()
		if err != nil {
			return err
		}
		ids = append(ids, id)
	}
	target := ids[len(ids)-1]
	inputs := ids[:len(ids)-1]

	// The altar bounds how many cards may be fed in — the record's slot count
	// is azi(), which the client renders minus one because it counts the
	// TARGET slot alongside the inputs ("slotCount" = azi() - 1).
	if lab := s.fusionLab(); lab != nil && len(inputs) > int(lab.Slots)-1 {
		return s.sendFusionResult(fusionResultError, 0, 0, 0)
	}

	// The target must be a FUSION card — the client's own slot gate
	// (`add.java` case 20172: `xj.tz() != 0 || xj.tA() != 0`, else the toast
	// "mustBeFusionCard"). Exactly 7 cards qualify — all family-27 "boost"
	// cards in set 149 — because the 2.70 fusion lab's only output is boost
	// cards; it is not a generic card upgrader. (The same-set constraint that
	// used to sit here was an invention and was strictly wrong: boost inputs
	// are level 0, so same-set recipes could never cover any cost.)
	tc := s.deps.Cards.Get(target)
	if tc == nil || (tc.FusionPower == 0 && tc.FusionQuality == 0) {
		return s.sendFusionResult(fusionResultOK, 0, 0, 0)
	}

	// The recipe, straight out of the client's formula plus the altar the
	// coach is standing at. Both power terms push on the same side:
	//
	//	kardsPower = Σ inputs' RequiredLevel − target's FusionPower
	//	power      = kardsPower + lab.Power + Σ inputs' FusionPower ≥ 0
	//	quality    = lab.Quality + Σ inputs' FusionQuality — the success die,
	//	             and the floor the target's FusionQuality demands
	//
	// Inputs that are themselves fusion cards feed their fp/fq into the
	// matching side: that is what the "boost" cards are for.
	var boostPower, boostQuality int32
	for _, id := range inputs {
		if c := s.deps.Cards.Get(id); c != nil {
			boostPower += int32(c.FusionPower)
			boostQuality += int32(c.FusionQuality)
		}
	}
	var labPower, labQuality int32
	if lab := s.fusionLab(); lab != nil {
		labPower, labQuality = int32(lab.Power), int32(lab.Quality)
	}
	if power := s.kardsPower(inputs, tc) + labPower + boostPower; power < 0 {
		return s.sendFusionResult(fusionResultOK, 0, target, 0) // cannot afford it
	}
	quality := labQuality + boostQuality
	if quality < int32(tc.FusionQuality) {
		return s.sendFusionResult(fusionResultOK, 0, target, 0) // not fine enough
	}

	// SECURITY: the target may not be worth more than what was consumed.
	//
	// The recipe above covers a card's fusion COST (RequiredLevel/FusionPower),
	// not its kama VALUE — a handful of cheap high-level inputs could still
	// meet the recipe for a 46 100-value target. Card CONSERVATION was always
	// correct (ConsumeAndGrant is transactional and tallies duplicates); this
	// is a VALUE break, and it fed handleDemonAffiliate, which scores clan
	// reputation by card value.
	//
	// A value ceiling is the smallest rule that closes it without inventing a
	// new mechanic: fusion may transform what you own, not multiply its worth.
	// The allowance keeps ordinary fusion useful - the point of the feature is
	// to trade several cards for one better one - while removing the unbounded
	// jump.
	// SECURITY: an "undestructible" card may not be fused away. The client blocks
	// the gesture (add.java:22-24) and 65 shipped cards carry the flag; consuming
	// one is irreversible player-data loss.
	for _, id := range inputs {
		if !s.deps.cardIsTradable(id) {
			s.log.Warn("fusion refused: input card is bound or undestructible",
				"coach", s.Coach.ID, "card", id)
			return s.sendFusionResult(fusionResultOK, 0, target, 0)
		}
	}

	if inVal, outVal := s.cardsValue(inputs), int64(tc.Value); outVal > inVal*fusionValueAllowance {
		s.log.Info("fusion refused: target worth more than the inputs",
			"coach", s.Coach.ID, "target", target, "target_value", outVal,
			"inputs_value", inVal)
		return s.sendFusionResult(fusionResultOK, 0, target, 0)
	}

	// Roll the altar's quality die. The flat 60% this replaces was a stand-in:
	// with the real fields read off the panel, the lab's quality is the only
	// die-shaped number left — and it is what the fq boost cards feed.
	if int32(fusionRoll()) < quality {
		if err := s.deps.Store.Coaches.ConsumeAndGrant(s.Coach.ID, inputs, target); err != nil {
			if errors.Is(err, store.ErrCardNotOwned) {
				return s.sendFusionResult(fusionResultOK, 0, 0, 0)
			}
			return err
		}
		s.refreshAndPushInventory()
		s.log.Info("fusion success", "coach", s.Coach.Name, "obtained", target)
		return s.sendFusionResult(fusionResultOK, target, 0, 0)
	}

	// Failure: consume the inputs, return one as leftovers, and name the card
	// that was missed so the client can say so.
	recovered := inputs[0]
	if err := s.deps.Store.Coaches.ConsumeAndGrant(s.Coach.ID, inputs, recovered); err != nil {
		if errors.Is(err, store.ErrCardNotOwned) {
			return s.sendFusionResult(fusionResultOK, 0, 0, 0)
		}
		return err
	}
	s.refreshAndPushInventory()
	s.log.Info("fusion failed", "coach", s.Coach.Name, "missed", target, "recovered", recovered)
	return s.sendFusionResult(fusionResultOK, 0, target, recovered)
}

// kardsPower is the client's own "kardsPower": the summed RequiredLevel of the
// input cards minus the target's FusionPower (`ajt_1`, property cCB). Negative
// means the inputs do not cover the target's cost.
func (s *Session) kardsPower(inputs []int32, target *gamedata.CoachCard) int32 {
	var total int32
	for _, id := range inputs {
		if c := s.deps.Cards.Get(id); c != nil {
			total += c.RequiredLevel
		}
	}
	if target != nil {
		total -= int32(target.FusionPower)
	}
	return total
}

// fusionLab returns the altar this fusion runs on: the fusion-lab element
// NEAREST the coach in its current world.
//
// Which altar you use matters — the six in-world altars are six different tiers
// (ids 2-7 of the type-1100 table: power 1/10/20/30/5/15, slots 2/3/4/5/2/3) —
// and the client resolves it exactly this way. `xx_2` is the fusion-altar
// interactive element, and its `gi()` parses the element's descriptor as a single
// parameter, the lab-definition id, then looks it up with `CN.by(id)`. Our
// element table already carries that value as `worldElement.arg`.
//
// The 5490 request itself names no altar (the client opens the panel locally on
// interaction and never tells the server which one), so position is the only
// signal available. Nearest wins rather than requiring adjacency: a legitimate
// client is always standing at the altar it opened, and a hard distance gate
// would risk refusing real fusions over a stale coordinate.
func (s *Session) fusionLab() *gamedata.FusionLab {
	if s.deps == nil || s.deps.FusionLabs == nil || s.Coach == nil {
		return nil
	}
	var best *worldElement
	var bestDist int32
	for i := range worldElements[s.currentWorld] {
		e := &worldElements[s.currentWorld][i]
		if e.kind != kindFusionLab {
			continue
		}
		d := abs32(e.cellX-s.Coach.PosX) + abs32(e.cellY-s.Coach.PosY)
		if best == nil || d < bestDist || (d == bestDist && e.arg < best.arg) {
			best, bestDist = e, d
		}
	}
	if best != nil {
		if lab := s.deps.FusionLabs.Get(int64(best.arg)); lab != nil {
			return lab
		}
	}
	return s.deps.FusionLabs.Default()
}

// sendFusionResult replies with FusionResult(5491):
// [i8 result][i32 obtained][i32 notObtained][i32 recovered].
func (s *Session) sendFusionResult(result uint8, obtained, notObtained, recovered int32) error {
	w := protocol.NewWriter().U8(result).I32(obtained).I32(notObtained).I32(recovered)
	frame, err := protocol.EncodeS2C(protocol.OpFusionResult, w.Bytes())
	if err != nil {
		return err
	}
	return s.Send(frame)
}

// refreshAndPushInventory reloads the coach's inventory from the store and
// pushes a fresh CoachInventoryUpdate(5200).
func (s *Session) refreshAndPushInventory() {
	if fresh, err := s.deps.Store.Coaches.Get(s.Coach.ID); err == nil {
		s.Coach.SetInventory(fresh.Inventory)
	}
	_ = s.pushInventory(s.Coach)
}

// fusionValueAllowance is how much more the fused card may be worth than the sum
// of its inputs. Fusion is meant to trade several cards for one better one, so
// the ceiling is deliberately above 1x; it exists to stop an unbounded jump from
// two commons to a set's best card, not to make fusion break even.
const fusionValueAllowance = 3

// cardsValue sums the catalogue value of the consumed cards.
func (s *Session) cardsValue(ids []int32) int64 {
	if s.deps.Cards == nil {
		return 0
	}
	var total int64
	for _, id := range ids {
		if c := s.deps.Cards.Get(id); c != nil {
			total += int64(c.Value)
		}
	}
	return total
}
