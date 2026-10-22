package game

// target_conditions.go ports the client's FightTargetValidator so the server
// filters an area effect's EXPANDED targets by the effect's own target-condition
// bitmask (gamedata.Effect.Targets). This is what makes a "Target: All" (area
// 32767) self-buff land only on its caster, and an area damage spell hit only the
// intended side. A single-target (point) effect is NOT filtered here — the client
// already validated its aimed cell; only server-expanded area/all targets need
// server-side filtering.
//
// Model (FightTargetValidator.getTargetValidity): Targets is a list of condition
// bitmasks. A target is VALID if ANY condition passes (OR across the list); a
// condition passes only if ALL its set bits hold (AND within one condition). An
// empty Targets list means "no restriction".

const (
	condIsCaster      int64 = 2   // CONDITION_IS_CASTER
	condIsAlly        int64 = 4   // CONDITION_IS_ALLY (same team, includes caster)
	condIsEnemy       int64 = 8   // CONDITION_IS_ENEMY (different team)
	condIsHuman       int64 = 16  // CONDITION_IS_HUMAN (a real, non-summon fighter)
	condIsSummoned    int64 = 32  // CONDITION_IS_SUMMONED
	condIsEffectArea  int64 = 64  // CONDITION_IS_EFFECT_AREA (never a fighter)
	condIsAllyNotSelf int64 = 128 // CONDITION_IS_ALLY_EXCEPT_CASTER
	condIsNotCaster   int64 = 256 // CONDITION_IS_NOT_CASTER

	// 512 / 1024 test the target's breed against the ZERO breed rather than
	// against a numbered slot, so they are separate from the two banks below:
	//
	//	aLc: (0x200 & c) != 0 && (!(t instanceof gn_0) || t.NY().lV() != xq.axE.lV())  -> reject
	//	     (0x400 & c) != 0 && (!(t instanceof gn_0) || t.NY().lV() == xq.axE.lV())  -> reject
	//
	// `xq.axE` is breed id 0 — the stat-less pseudo-breed the client lists
	// between axD(-1) and the 14 real breeds, i.e. "no player breed". So 512 =
	// "is a creature", 1024 = "is a real player-breed fighter".
	//
	// In THIS server's model those two coincide with condIsSummoned /
	// condIsHuman, because only a summon has no Fighter row and breedOf then
	// returns 0. They are still evaluated on the breed id, exactly as the client
	// writes them, rather than aliased to isSummon() — the client keeps them
	// distinct (16/32 test its `Dk()` summon flag, 512/1024 test the breed), and
	// aliasing would silently diverge if the two ever disagree.
	condBreedIsZero    int64 = 512  // target's breed IS 0 (a creature/summon)
	condBreedIsNotZero int64 = 1024 // target's breed is NOT 0 (a real breed)

	// Breed conditions come in a POSITIVE and a NEGATIVE bank, per the client's
	// condition evaluator (aLc.a): bit 16+k means "target's breed IS k+1", and
	// bit 32+k means "target's breed is NOT k+1". Each set bit is checked
	// independently and all must hold, so two positive breed bits in one
	// condition can never pass.
	//
	// 2.70 widened this from the 12 breeds of the 2006 client to 14 slots. The
	// negative bank is not decorative: "Dieu Enutrof" (event 8) buffs Enutrofs
	// with one effect and everyone-but-Enutrofs with the other, and the second
	// effect is expressed purely as bit 34 = "not breed 3".
	breedIsMask    int64 = 0x3FFF0000     // bits 16..29 — target's breed IS k+1
	breedIsNotMask int64 = 0x3FFF00000000 // bits 32..45 — target's breed is NOT k+1
	breedSlots           = 14

	// evaluableTargetBits is every bit targetConditionPasses can actually decide.
	// A condition carrying anything outside this set is one this server cannot
	// represent — notably `aLc`'s bit 62 ("the target is a ground effect area"),
	// which belongs to a targeting mode we do not model. Callers that gate a
	// whole CAST on a mask check this first and stay permissive rather than
	// rejecting a spell they cannot judge; see spellTargetMaskAllows.
	evaluableTargetBits = condIsCaster | condIsAlly | condIsEnemy | condIsHuman |
		condIsSummoned | condIsEffectArea | condIsAllyNotSelf | condIsNotCaster |
		condBreedIsZero | condBreedIsNotZero | breedIsMask | breedIsNotMask | 1 |
		stateTargetBits
)

// The client's SECOND target evaluator, aLc.a(target, caster) at aLc.java:89-131.
// Every one of these bits REJECTS the target when it holds, and all but the first
// are read off the TARGET.
//
// SECURITY: the whole bank used to be unrepresentable, so spellTargetMaskAllows
// hit its escape hatch and skipped the entire mask - a spell whose mask used any
// of these was cast with no target validation at all. That is fine while no
// shipped spell relies on them and dangerous the moment one does, which is
// exactly the kind of data-drift this project has been bitten by before.
//
// Every bit of the bank is decidable from state this server models (the state
// mapping is the one in states.go, whose comments name the very same client enum
// members: dev/dew/dex/deA/deB/deC). Bits 55 and 58-61 were not until S19: 55
// needed the damage-redirect state, and 58-61 compare damage against
// resistance, which combat_stats.go now holds.
const (
	condTargetIntransposable int64 = 1 << 49 // deB, on target OR caster
	condTargetStabilized     int64 = 1 << 50 // dev
	condTargetAnchored       int64 = 1 << 51 // deA - cannot be carried
	condTargetAtFullHP       int64 = 1 << 52 // HP >= MaxHP
	condTargetNoAP           int64 = 1 << 53 // AP == 0 or AP-loss resist >= 100
	condTargetNoMP           int64 = 1 << 54 // MP == 0 or MP-loss resist >= 100
	condTargetRedirected     int64 = 1 << 55 // deC - under a damage redirect (139, aOp)
	condTargetRooted         int64 = 1 << 56 // dex
	condTargetPetrified      int64 = 1 << 57 // dew
	// 58-61: the caster's damage % against the target's resistance % in one
	// element (ig_1.a), rejected below -60. The element of each bit is ig_1's
	// own pairing of the Lr characteristics: bqH/bqD earth, bqI/bqE air,
	// bqG/bqC water, bqF/bqB fire.
	condTargetResistsEarth int64 = 1 << 58
	condTargetResistsAir   int64 = 1 << 59
	condTargetResistsWater int64 = 1 << 60
	condTargetResistsFire  int64 = 1 << 61

	stateTargetBits = condTargetIntransposable | condTargetStabilized |
		condTargetAnchored | condTargetAtFullHP | condTargetNoAP |
		condTargetNoMP | condTargetRedirected | condTargetRooted | condTargetPetrified |
		condTargetResistsEarth | condTargetResistsAir | condTargetResistsWater |
		condTargetResistsFire

	resistGapReject int32 = -60  // aLc: ig_1.a(...) < -60
	statBound       int32 = 1000 // Lr's [-1000, 1000] clamp (gn_0.a)
)

// elementalEdge is ig_1.a: the caster's all + element damage %, clamped, less
// the target's all + element resistance %, clamped.
func elementalEdge(caster, target *FightFighter, elem int) int32 {
	var dmg int32
	if caster != nil {
		dmg = clampInt32(caster.Stats.dmgPctAll+caster.Stats.dmgPct[elem], -statBound, statBound)
	}
	res := clampInt32(target.Stats.resPctAll+target.Stats.resPct[elem], -statBound, statBound)
	return dmg - res
}

// stateConditionRejects reports whether any modelled state bit in cond rules the
// target out. Mirrors aLc.java:89-131, where each matching bit returns dMP
// ("not a legal target").
func stateConditionRejects(caster, target *FightFighter, cond int64) bool {
	if target == nil {
		return false
	}
	// Bit 49 is the only one that also inspects the CASTER (aLc.java:91).
	if cond&condTargetIntransposable != 0 &&
		(target.hasState(stateIntransposable) ||
			(caster != nil && caster.hasState(stateIntransposable))) {
		return true
	}
	if cond&condTargetStabilized != 0 && target.hasState(stateStabilized) {
		return true
	}
	if cond&condTargetAnchored != 0 && target.hasState(stateAnchored) {
		return true
	}
	if cond&condTargetAtFullHP != 0 && target.HP >= target.MaxHP {
		return true
	}
	if cond&condTargetNoAP != 0 && (target.AP == 0 || target.Stats.resAPLoss >= 100) {
		return true
	}
	if cond&condTargetNoMP != 0 && (target.MP == 0 || target.Stats.resMPLoss >= 100) {
		return true
	}
	if cond&condTargetRedirected != 0 && target.hasState(stateRedirected) {
		return true
	}
	for _, r := range [...]struct {
		bit  int64
		elem int
	}{
		{condTargetResistsEarth, elemEarth}, {condTargetResistsAir, elemAir},
		{condTargetResistsWater, elemWater}, {condTargetResistsFire, elemFire},
	} {
		if cond&r.bit != 0 && elementalEdge(caster, target, r.elem) < resistGapReject {
			return true
		}
	}
	if cond&condTargetRooted != 0 && target.hasState(stateRooted) {
		return true
	}
	if cond&condTargetPetrified != 0 && target.hasState(statePetrified) {
		return true
	}
	return false
}

// effectTargetAllowed reports whether `target` satisfies any of the effect's
// target conditions cast by `caster`. Empty conditions = permissive (always).
func effectTargetAllowed(caster, target *FightFighter, targets []int64) bool {
	if len(targets) == 0 {
		return true
	}
	for _, cond := range targets {
		if targetConditionPasses(caster, target, cond) {
			return true
		}
	}
	return false
}

// targetConditionPasses evaluates ONE condition bitmask: it passes iff every set
// role/breed bit holds for the target. A zero condition (no bits) passes for
// everyone. (CONDITION_IN_AOE / bit 1 is a no-op here — every candidate the area
// resolver produced is already in the area.)
func targetConditionPasses(caster, target *FightFighter, cond int64) bool {
	// The state bank (aLc's second evaluator) is a REJECT list, evaluated before
	// the role/breed bits: any bit that holds disqualifies the target outright.
	if stateConditionRejects(caster, target, cond) {
		return false
	}

	isSelf := target == caster
	sameTeam := caster != nil && target != nil && caster.TeamID == target.TeamID

	if cond&condIsCaster != 0 && !isSelf {
		return false
	}
	if cond&condIsNotCaster != 0 && isSelf {
		return false
	}
	if cond&condIsAllyNotSelf != 0 && (isSelf || caster == nil || !sameTeam) {
		return false
	}
	if cond&condIsAlly != 0 && (caster == nil || !sameTeam) {
		return false
	}
	if cond&condIsEnemy != 0 && (caster == nil || sameTeam) {
		return false
	}
	if cond&condIsHuman != 0 && target.isSummon() {
		return false
	}
	if cond&condIsSummoned != 0 && !target.isSummon() {
		return false
	}
	if cond&condIsEffectArea != 0 {
		return false // a resolved fighter is never a ground area
	}
	if cond&condBreedIsZero != 0 && targetBreed(target) != 0 {
		return false
	}
	if cond&condBreedIsNotZero != 0 && targetBreed(target) == 0 {
		return false
	}
	if cond&(breedIsMask|breedIsNotMask) != 0 && !breedConditionAllows(cond, target) {
		return false
	}
	return true
}

// breedConditionAllows reports whether target satisfies every breed bit set in
// cond, positive and negative alike (the client checks each bit on its own and
// rejects on the first failure — aLc.a).
//
// A summon has no breed of its own, so it can never satisfy a POSITIVE breed
// condition; conversely it always satisfies a NEGATIVE one ("not an Enutrof" is
// true of something that is not any breed).
// targetBreed is the target's breed id, or 0 for a summon or a missing target —
// which is exactly the client's `xq.axE` ("no breed") slot.
func targetBreed(target *FightFighter) int64 {
	if target == nil || target.isSummon() {
		return 0
	}
	return int64(breedOf(target))
}

func breedConditionAllows(cond int64, target *FightFighter) bool {
	breed := targetBreed(target)
	for k := 0; k < breedSlots; k++ {
		if cond&(int64(1)<<(16+k)) != 0 && breed != int64(k+1) {
			return false // must BE breed k+1
		}
		if cond&(int64(1)<<(32+k)) != 0 && breed == int64(k+1) {
			return false // must NOT be breed k+1
		}
	}
	return true
}
