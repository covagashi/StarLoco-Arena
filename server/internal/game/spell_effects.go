package game

import (
	"math/rand"
	"time"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// activeBuff is a timed characteristic buff/debuff applied to a fighter. Only
// RESOURCE buffs (AP/MP/HP/Range) carry a modelled delta the server reverts on
// expiry; a pure-stat buff (resistance/damage%/…) is tracked with delta 0 so the
// client's buff icon has a server-side counterpart but the flat-damage model is
// unaffected. An infinite buff (duration ≥ 63) is applied permanently and never
// tracked here.
type activeBuff struct {
	actionID   int32
	effectID   int32 // source effect's generic effectId — the key action 149 removes by
	res        gamedata.BuffResource
	delta      int32 // signed amount already applied to the resource (0 = render-only)
	affectsMax bool
	turnsLeft  int32
	// infinite marks a permanent buff (duration ≥ 63, e.g. a mask's stat malus): it
	// is tracked (so action 149 can strip + revert it) but never aged by tickBuffs.
	infinite bool
	// statBuff marks a combat-stat buff applied to the fighter's combatStats —
	// elemental damage/resistance (mh_2 21-55, 80-83) or a scalar characteristic
	// (AP/MP-loss resist 86/87, damage rebound 89, heal power 78/79). delta holds
	// the rolled value, reverted at expiry via Stats.apply(actionID, -delta).
	statBuff bool
}

// rngSource returns the fight's damage/dice RNG, lazily seeding it. Tests may set
// f.rng beforehand for deterministic rolls.
func (f *Fight) rngSource() *rand.Rand {
	if f.rng == nil {
		f.rng = rand.New(rand.NewSource(time.Now().UnixNano()))
	}
	return f.rng
}

// resolveSpellEffects applies every effect of a cast spell against the target
// cell, broadcasting the matching RUNNING_EFFECT (8120) per effect so the client
// renders each one. Every effect kind the practice/real spells carry is handled
// here (damage variants, heal, AP/MP loss/gain/steal, positioning, buffs); the
// exotic state/summon/glyph effects are recognised and skipped (see EffectKind).
func (f *Fight) resolveSpellEffects(caster *FightFighter, sp *gamedata.Spell, target Pos, crit bool) {
	// Remember which spell is resolving so every effect broadcast can name its
	// source in blob part 4. The client's buff bar drops any running effect whose
	// source is not a spell (ee_2.java:562), so this is what makes buff icons
	// appear at all. Saved/restored rather than just cleared: an effect can
	// resolve nested effects (collision damage, trap springs, poison ticks).
	prev := f.sourceSpellID
	f.sourceSpellID = sp.ID
	defer func() { f.sourceSpellID = prev }()
	for _, ef := range selectEffectsForCrit(sp.Effects, crit) {
		f.resolveEffect(caster, ef, target)
	}
}

// fighterAtCell returns the living fighter that a single-target effect on cell
// (x,y) hits, ignoring altitude, or nil. A CARRIED fighter is skipped — it is
// held on its carrier's cell and is not independently targetable, so a cast on
// that cell resolves onto the carrier (the front fighter). (x,y) is the unit of
// targeting — the client owns per-cell z.
func (f *Fight) fighterAtCell(cell Pos) *FightFighter {
	for _, ff := range f.allFighters() {
		if ff.HP > 0 && ff.CarriedByFighter == nil && ff.Pos.X == cell.X && ff.Pos.Y == cell.Y {
			return ff
		}
	}
	return nil
}

// resolveEffect applies a single decoded spell effect, dispatching on its
// mechanic classification (gamedata.EffectKind). Positioning and summon effects
// act on a single target/cell; every other kind is a PER-TARGET effect applied
// once to each fighter in the effect's area-of-effect (just the fighter on the
// target cell for a point/no-area spell — see areaFighters).
func (f *Fight) resolveEffect(caster *FightFighter, ef gamedata.Effect, target Pos) {
	switch ef.Kind() {
	case gamedata.KindTeleport:
		f.applyTeleport(caster, ef, target)
		return
	case gamedata.KindSwap:
		f.applySwap(caster, ef, target)
		return
	case gamedata.KindPush:
		f.applyPushPull(caster, ef, target, true)
		return
	case gamedata.KindPull:
		f.applyPushPull(caster, ef, target, false)
		return
	case gamedata.KindSelfPush:
		f.applySelfPush(caster, ef, target)
		return
	case gamedata.KindSpellCooldown:
		f.applySpellCooldown(caster, ef)
		return
	case gamedata.KindCurseBonusCells:
		f.applyCurseBonusCells(caster, ef, target)
		return
	case gamedata.KindSummon:
		f.applySummon(caster, ef, target)
		return
	case gamedata.KindTrap:
		f.applySetEffectArea(caster, ef, target)
		return
	case gamedata.KindCarry:
		f.applyCarry(caster, ef, target)
		return
	case gamedata.KindThrow:
		f.applyThrow(caster, ef, target)
		return
	case gamedata.KindAura:
		f.applySetAura(caster, ef, target)
		return
	case gamedata.KindZoneMPLoss:
		f.applyZoneMPLoss(caster, ef, target)
		return
	case gamedata.KindZoneAPLoss:
		f.applyZoneAPLoss(caster, ef, target)
		return
	case gamedata.KindZoneDamage:
		f.applyZoneDamage(caster, ef, target)
		return
	case gamedata.KindLineDamage:
		f.applyLineDamage(caster, ef, target)
		return
	case gamedata.KindDamageTransfer:
		f.applyDamageTransfer(caster, ef, target)
		return
	case gamedata.KindUnsupported:
		// state/glyph/… : the cast still animated and its other effects still
		// resolved; this one is a documented no-op.
		return
	}
	// Per-target effect: apply once per fighter in the effect's area (a single
	// fighter on the target cell for a point/no-area spell; every fighter in the
	// zone for a circle/cross/T; every living fighter for an "empty"/all area).
	for _, victim := range f.areaFighters(caster, ef, target) {
		f.applyPerTargetEffect(caster, ef, victim.Pos)
	}
}

// applyPerTargetEffect resolves one cell-targeting effect against the fighter on
// `cell` (one fighter in the area loop of resolveEffect).
func (f *Fight) applyPerTargetEffect(caster *FightFighter, ef gamedata.Effect, cell Pos) {
	switch ef.Kind() {
	case gamedata.KindDamage:
		f.applyDamageEffect(caster, ef, cell, false)
	case gamedata.KindLeech:
		f.applyDamageEffect(caster, ef, cell, true)
	case gamedata.KindPoison:
		f.applyPoison(caster, ef, cell)
	case gamedata.KindScaledAP:
		f.applyScaledDamage(caster, ef, cell, true)
	case gamedata.KindScaledMP:
		f.applyScaledDamage(caster, ef, cell, false)
	case gamedata.KindPercentHP:
		f.applyPercentHP(caster, ef, cell)
	case gamedata.KindHeal:
		f.applyHeal(caster, ef, cell)
	case gamedata.KindInstantDeath:
		f.applyInstantDeath(caster, ef, cell)
	case gamedata.KindAPLoss:
		f.applyStatDrain(caster, ef, cell, true, false)
	case gamedata.KindMPLoss:
		f.applyStatDrain(caster, ef, cell, false, false)
	case gamedata.KindAPSteal:
		f.applyStatDrain(caster, ef, cell, true, true)
	case gamedata.KindMPSteal:
		f.applyStatDrain(caster, ef, cell, false, true)
	case gamedata.KindAPGain:
		f.applyResourceGain(caster, ef, cell, true)
	case gamedata.KindMPGain:
		f.applyResourceGain(caster, ef, cell, false)
	case gamedata.KindBuff:
		f.applyBuff(caster, ef, cell)
	case gamedata.KindState:
		f.applyState(caster, ef, cell)
	case gamedata.KindDispel:
		f.applyDispel(caster, ef, cell)
	case gamedata.KindRemoveEffect:
		f.applyRemoveEffect(caster, ef, cell)
	case gamedata.KindVisual:
		f.applyVisualEffect(caster, ef, cell)
	case gamedata.KindRevealInvisible:
		f.applyRevealInvisible(caster, ef, cell)
	case gamedata.KindSpellReturn:
		f.applySpellReturn(caster, ef, cell)
	}
}

// applyDispel (62 "Désenvoûtement") strips the fighter at `cell` of its
// enchantments: every tracked (finite) buff is reverted — undoing its resource
// or elemental stat change — and every TIMED state is cleared. The dispel
// running-effect is broadcast so the client plays it.
//
// PERMANENT things survive, states as well as buffs. The buff loop always did
// this ("dispel leaves permanent enchantments"); the state loop did not, and
// cleared the map wholesale. That silently un-rooted summons: innate creature
// properties are applied at spawn as INFINITE states (applySummonInnateProperties
// — 22 of the 53 shipped creatures are rooted, 21 anchored, 18 stabilised, 15
// intransposable), so one dispel made a stationary summon mobile, or a
// carry-proof one carryable, for the rest of the fight. Those are not
// enchantments to be undone; they are what the creature IS.
//
// The same rule already governs ageing: tickStates leaves any state at
// >= infiniteStateTurns untouched. Dispel now agrees with it.
//
// NOTE — the client's model is richer, and is the eventual general fix. It keeps
// fighter properties in a REFERENCE-COUNTED store (`Kt`: `g()` increments,
// `h()` decrements and removes at zero, `c()` reads the count, and `b()` is
// "count != 0"), so a summon's innate root and a spell's root coexist as count 2
// and removing one leaves the other. This server's `States` map holds remaining
// TURNS, which conflates "how long" with "how many sources" — the same shortcut
// behind the buff-stacking gap in the roadmap. Keeping infinite states is the
// correct behaviour for every case the shipped data actually produces; counting
// sources would additionally fix overlapping FINITE ones.
func (f *Fight) applyDispel(caster *FightFighter, ef gamedata.Effect, cell Pos) {
	victim := f.fighterAtCell(cell)
	if victim == nil {
		return
	}
	kept := victim.Buffs[:0]
	for _, b := range victim.Buffs {
		if b.infinite {
			kept = append(kept, b) // dispel leaves permanent enchantments (e.g. a mask's malus)
			continue
		}
		f.revertBuff(victim, b)
	}
	victim.Buffs = kept
	for s, turns := range victim.States {
		if turns >= infiniteStateTurns {
			continue // innate/permanent: not an enchantment to strip
		}
		delete(victim.States, s)
		delete(victim.stateSrc, s)
	}
	eff, _ := buildRunningEffect(f.nextActionUID(), ef.ActionID, ef.EffectID,
		caster.WireID, victim.WireID, victim.Pos, 0, 0, false)
	f.broadcast(eff)
}

// applyRemoveEffect (149 "Retire un effet") strips from the fighter at `cell`
// every running-effect whose SOURCE effectId equals params[0] — a tracked buff
// (reverting its stat change), a status state, or an aura this fighter placed —
// up to params[1] removals (default: all). Each removal mirrors an early expiry.
// The 149 running-effect is broadcast so the client's dw_0 drops the same effects
// on its side (it reads params[0] from the effect's own local definition).
func (f *Fight) applyRemoveEffect(caster *FightFighter, ef gamedata.Effect, cell Pos) {
	victim := f.fighterAtCell(cell)
	if victim == nil {
		return
	}
	if len(ef.Params) > 0 {
		rid := int32(ef.Params[0])
		limit := int32(-1) // default: remove ALL matches
		if len(ef.Params) > 1 {
			limit = int32(ef.Params[1])
		}
		f.removeEffectByID(victim, rid, limit)
	}
	eff, _ := buildRunningEffect(f.nextActionUID(), ef.ActionID, ef.EffectID,
		caster.WireID, victim.WireID, victim.Pos, 0, 0, false)
	f.broadcast(eff)
}

// removeEffectByID strips from ff every buff, state and self-placed aura whose
// source effectId is rid, reverting each like an early expiry, up to `limit`
// removals across all three (-1 = unlimited). Buffs first, then states, then
// auras — the order only matters when a finite limit is given.
func (f *Fight) removeEffectByID(ff *FightFighter, rid, limit int32) {
	remaining := limit
	take := func() bool {
		if remaining < 0 {
			return true
		}
		if remaining == 0 {
			return false
		}
		remaining--
		return true
	}
	// Tracked buffs: revert the stat change and drop.
	if len(ff.Buffs) > 0 {
		kept := ff.Buffs[:0]
		for _, b := range ff.Buffs {
			if b.effectID == rid && take() {
				f.revertBuff(ff, b)
				continue
			}
			kept = append(kept, b)
		}
		ff.Buffs = kept
	}
	// Status states (e.g. the displaced mask).
	for s, src := range ff.stateSrc {
		if src == rid && take() {
			delete(ff.States, s)
			delete(ff.stateSrc, s)
		}
	}
	// Auras this fighter placed (a mask's self-aura): destroy the area.
	if len(f.effectAreas) > 0 {
		kept := f.effectAreas[:0]
		for _, a := range f.effectAreas {
			if a.effectID == rid && a.caster == ff && take() {
				continue
			}
			kept = append(kept, a)
		}
		f.effectAreas = kept
	}
}

// applyVisualEffect broadcasts a client-visual-only effect (look change 60/98,
// drunk 126, damage redirect 139) on the fighter at `cell` so the client renders
// it; the server keeps no state for it. Its duration comes from the effect record
// the client resolves itself, so Nx (turns already elapsed) is 0.
func (f *Fight) applyVisualEffect(caster *FightFighter, ef gamedata.Effect, cell Pos) {
	victim := f.fighterAtCell(cell)
	if victim == nil {
		return
	}
	val := ef.Roll(f.rngSource())
	eff, _ := buildRunningEffect(f.nextActionUID(), ef.ActionID, ef.EffectID,
		caster.WireID, victim.WireID, victim.Pos, val, 0, false,
		sourceSpellPart(f.sourceSpellID))
	f.broadcast(eff)
}

// --- HP effects (damage / leech / heal / %HP / instant death) ---

// applyDamageEffect rolls the effect's magnitude and removes it from the fighter
// on the target cell, broadcasting the effect's own RUNNING_EFFECT id so the
// right element/animation plays. When leech is set (ids 6-10) the caster also
// heals the damage dealt (capped at the victim's HP before the hit) — the client
// heals the caster from the same effect, so no separate heal packet is sent.
func (f *Fight) applyDamageEffect(caster *FightFighter, ef gamedata.Effect, target Pos, leech bool) {
	victim := f.fighterAtCell(target)
	if victim == nil {
		return
	}
	base := ef.Roll(f.rngSource())
	if base <= 0 {
		return
	}
	// Spell return (88): the WHOLE hit changes target before anything is
	// computed. This must happen server-side now that we send blob part 4,
	// because part 4 is what lets the client register its own `amv_1` trigger -
	// and that trigger redirects locally on receipt. If the server did not
	// redirect too, the client would show the caster taking a hit the server
	// gave the victim.
	if f.consumeSpellReturn(victim) {
		if victim == caster {
			return // a self-hit has nowhere to bounce
		}
		victim = caster
		target = caster.Pos
	}
	// Run the Dofus damage formula: the rolled base is boosted by the caster's
	// elemental damage stats and reduced by the victim's resistances (neutral /
	// poison bypasses both — see damageElement). A fully-resisted hit deals 0.
	final := f.computeElementalDamage(caster, victim, base, damageElement(ef.ActionID))
	// Damage rebound (89): reflect a share of the mitigated hit back to the
	// attacker before it lands, reducing what the victim takes.
	final = f.applyDamageRebound(caster, victim, final, ef.EffectID)
	before := victim.HP
	f.applyHPDelta(caster, victim, ef.ActionID, ef.EffectID, -final)
	if leech && final > 0 {
		heal := final
		if heal > before {
			heal = before // can't leech more life than the target had
		}
		f.healSilently(caster, heal)
	}
}

// applyPoison (61 "Poison") deals its first tick immediately (poison is neutral,
// so it already bypasses resistance in computeElementalDamage) and, if the effect
// carries a table-turn duration, tracks a recurring DoT that re-rolls and re-hits
// the victim at each new table turn (see tickPoisons). A one-shot poison (no
// duration) simply hits once. Ported from the v2.04b ActiveEffectPoisonTick model.
func (f *Fight) applyPoison(caster *FightFighter, ef gamedata.Effect, target Pos) {
	f.applyDamageEffect(caster, ef, target, false) // immediate first tick
	victim := f.fighterAtCell(target)
	if victim == nil || victim.HP <= 0 {
		return
	}
	turns, infinite := ef.DurationTurns()
	if infinite {
		turns = infiniteStateTurns
	}
	if turns <= 0 {
		return // no recurring ticks
	}
	victim.Poisons = append(victim.Poisons, &activePoison{
		caster: caster, actionID: ef.ActionID, effectID: ef.EffectID,
		params: ef.Params, turnsLeft: turns,
	})
}

// tickPoisons re-applies every fighter's active poison DoTs at a new table turn:
// each poison re-rolls its damage from its params and hits the bearer (bypassing
// resistance), then ages by one turn (infinite poisons persist). A dead fighter's
// poisons stop. Called from endTurn's new-table-turn block.
func (f *Fight) tickPoisons() {
	for _, ff := range f.allFighters() {
		if len(ff.Poisons) == 0 {
			continue
		}
		if ff.HP <= 0 {
			ff.Poisons = nil // a dead fighter's poison stops ticking
			continue
		}
		kept := ff.Poisons[:0]
		for _, p := range ff.Poisons {
			if ff.HP <= 0 {
				continue // died to an earlier poison this boundary — drop the rest
			}
			base := (gamedata.Effect{ActionID: p.actionID, Params: p.params}).Roll(f.rngSource())
			if base > 0 {
				f.applyHPDelta(p.caster, ff, p.actionID, p.effectID, -base)
			}
			if p.turnsLeft < infiniteStateTurns {
				p.turnsLeft--
			}
			if p.turnsLeft > 0 && ff.HP > 0 {
				kept = append(kept, p)
			}
		}
		ff.Poisons = kept
	}
}

// applyScaledDamage deals ELEMENTAL damage scaled by the caster's CURRENT AP (or
// MP) — the client tooltip's "par PA/PM possédé". The per-point magnitude (a
// flat/dice roll) is multiplied by the resource, then run through the elemental
// resist formula for the effect's element (156/157 fire, 158/159 air, 160/161
// water, 162/163 earth; 151/152 neutral) and reduced by any damage rebound. The
// client renders the server value verbatim under the effect's own action id.
func (f *Fight) applyScaledDamage(caster *FightFighter, ef gamedata.Effect, target Pos, ap bool) {
	victim := f.fighterAtCell(target)
	if victim == nil {
		return
	}
	perPoint := ef.Roll(f.rngSource())
	// EFFECTIVE, not raw: the client scales this off gn_0.d, so a rooted caster
	// reads 0 MP and a petrified one reads 0 of either. Reading the raw value
	// would make a rooted fighter's MP-scaled spell hit at full strength.
	resource := caster.effectiveMP()
	if ap {
		resource = caster.effectiveAP()
	}
	val := perPoint * resource
	if val <= 0 {
		return
	}
	final := f.computeElementalDamage(caster, victim, val, damageElement(ef.ActionID))
	final = f.applyDamageRebound(caster, victim, final, ef.EffectID)
	f.applyHPDelta(caster, victim, ef.ActionID, ef.EffectID, -final)
}

// applyPercentHP removes a percentage (params[0]) of the victim's MAX HP.
func (f *Fight) applyPercentHP(caster *FightFighter, ef gamedata.Effect, target Pos) {
	victim := f.fighterAtCell(target)
	if victim == nil {
		return
	}
	pct := ef.Roll(f.rngSource())
	val := victim.MaxHP * pct / 100
	if val <= 0 {
		return
	}
	f.applyHPDelta(caster, victim, ef.ActionID, ef.EffectID, -val)
}

// applyHeal restores HP (capped at MaxHP inside applyHPDelta) to the fighter on
// the target cell (self for a range-0 cast). The rolled base is scaled by the
// CASTER's heal power (actions 78/79): healed = base*(100+healPct)/100, a port of
// the v2.04b ComputeHeal (integer truncation — the client renders the server
// value verbatim). healPct is clamped to the Dofus [-100,100] bound.
func (f *Fight) applyHeal(caster *FightFighter, ef gamedata.Effect, target Pos) {
	victim := f.fighterAtCell(target)
	if victim == nil {
		return
	}
	val := ef.Roll(f.rngSource())
	if val <= 0 {
		return
	}
	if caster != nil {
		val = val * (100 + clampPct(caster.Stats.healPct)) / 100
	}
	if val <= 0 {
		return
	}
	f.applyHPDelta(caster, victim, gamedata.ActionHeal, ef.EffectID, +val)
}

// applyInstantDeath reduces the target to 0 HP (broadcasts the effect + death).
func (f *Fight) applyInstantDeath(caster *FightFighter, ef gamedata.Effect, target Pos) {
	victim := f.fighterAtCell(target)
	if victim == nil || victim.HP <= 0 {
		return
	}
	f.applyHPDelta(caster, victim, ef.ActionID, ef.EffectID, -victim.HP)
}

// applyHPDelta changes victim HP by delta (negative = damage, positive = heal),
// clamped to [0, MaxHP], broadcasts the effect's 8120 with the ACTUAL magnitude
// (the client applies the wire value verbatim), and FIGHTER_DIES on death.
func (f *Fight) applyHPDelta(caster, victim *FightFighter, runEffectID, genericID, delta int32) {
	// An immune fighter takes no damage (a heal still lands).
	if delta < 0 && victim.hasState(stateImmune) {
		return
	}
	// Damage transfer (129): redirect a share of incoming damage to the linked
	// absorber before it lands (one hop — the absorber's own resist/immune/link is
	// NOT re-checked, matching the reference redirect).
	if delta < 0 && victim.transfer != nil {
		if to := victim.transfer.to; to != nil && to != victim && to.HP > 0 {
			transferred := (-delta) * victim.transfer.pct / 100
			if transferred > 0 {
				delta += transferred
				f.dealTransferredDamage(caster, to, runEffectID, genericID, transferred)
			}
		}
	}
	before := victim.HP
	victim.HP += delta
	if victim.HP < 0 {
		victim.HP = 0
	}
	if victim.HP > victim.MaxHP {
		victim.HP = victim.MaxHP
	}
	amount := victim.HP - before
	if amount < 0 {
		amount = -amount // wire value is a magnitude
	}
	if amount == 0 {
		return
	}
	eff, _ := buildRunningEffect(f.nextActionUID(), runEffectID, genericID,
		caster.WireID, victim.WireID, victim.Pos, amount, 0, false)
	f.broadcast(eff)
	if victim.HP <= 0 {
		dies, _ := buildFighterDies(f.nextActionUID(), victim.WireID)
		f.broadcast(dies)
		victim.breakCarryLinks()
	}
}

// dealTransferredDamage applies a redirected damage portion straight to the
// absorber's HP (no immune/resist/transfer re-check — a single hop) and
// broadcasts it, killing the absorber if it drops to 0.
func (f *Fight) dealTransferredDamage(caster, to *FightFighter, runEffectID, genericID, amount int32) {
	if to == nil || amount <= 0 {
		return
	}
	to.HP -= amount
	if to.HP < 0 {
		to.HP = 0
	}
	casterID := to.WireID
	if caster != nil {
		casterID = caster.WireID
	}
	eff, _ := buildRunningEffect(f.nextActionUID(), runEffectID, genericID,
		casterID, to.WireID, to.Pos, amount, 0, false)
	f.broadcast(eff)
	if to.HP <= 0 {
		dies, _ := buildFighterDies(f.nextActionUID(), to.WireID)
		f.broadcast(dies)
		to.breakCarryLinks()
	}
}

// applyDamageRebound reflects a share of a mitigated elemental hit back to the
// attacker (action 89 "Renvoie les dégâts" / DmgRebound), returning the damage
// the victim actually takes (reduced by the reflected portion). A port of the
// v2.04b ComputeHPLoss rebound tail: rebound = final*pct/100, subtracted from the
// victim's damage and dealt straight to the attacker as neutral HP loss (no
// re-rebound, no transfer). Self-hits, a nil caster and a zero rebound stat are
// no-ops; pct is clamped to the Dofus [0,99] bound. Unlike the reference — which
// leaves the caster's loss un-broadcast — the reflected HP IS broadcast, matching
// the 2.70 damage-transfer convention (the client renders server HP verbatim and
// would otherwise desync the attacker's gauge).
func (f *Fight) applyDamageRebound(caster, victim *FightFighter, final, genericID int32) int32 {
	if caster == nil || caster == victim || final <= 0 {
		return final
	}
	pct := victim.Stats.dmgRebound
	if pct <= 0 {
		return final
	}
	if pct > 99 {
		pct = 99
	}
	rebound := final * pct / 100
	if rebound <= 0 {
		return final
	}
	f.dealReboundDamage(victim, caster, rebound, genericID)
	final -= rebound
	if final < 0 {
		final = 0
	}
	return final
}

// dealReboundDamage applies reflected damage straight to the attacker's HP (no
// immune/resist/rebound re-check — a single hop) and broadcasts it as neutral HP
// loss sourced from the reflector, killing the attacker if it drops to 0.
func (f *Fight) dealReboundDamage(from, to *FightFighter, amount, genericID int32) {
	if to == nil || amount <= 0 {
		return
	}
	to.HP -= amount
	if to.HP < 0 {
		to.HP = 0
	}
	eff, _ := buildRunningEffect(f.nextActionUID(), protocol.RunEffectHPLoss, genericID,
		from.WireID, to.WireID, to.Pos, amount, 0, false,
		sourceSpellPart(f.sourceSpellID))
	f.broadcast(eff)
	if to.HP <= 0 {
		dies, _ := buildFighterDies(f.nextActionUID(), to.WireID)
		f.broadcast(dies)
		to.breakCarryLinks()
	}
}

// applyZoneMPLoss (177 "Perte de PM triggerée en zone") drains the effect's MP
// from every fighter in the spell's zone centered on the CASTER's own cell (the
// caster excluded). The MP debit is broadcast per victim as the silent MP-use so
// the client's gauge follows the server value.
func (f *Fight) applyZoneMPLoss(caster *FightFighter, ef gamedata.Effect, _ Pos) {
	f.applyZoneResourceLoss(caster, ef, false)
}

// applyZoneAPLoss (169 "Perte de points d'action triggerée en zone") is the AP
// twin of 177 — the same mh_2 family, the same shape.
func (f *Fight) applyZoneAPLoss(caster *FightFighter, ef gamedata.Effect, _ Pos) {
	f.applyZoneResourceLoss(caster, ef, true)
}

// applyZoneResourceLoss is the shared body of 169 (AP) and 177 (MP): drain the
// rolled amount from every fighter in the spell's zone centred on the CASTER,
// excluding the caster itself, clamped to what each victim actually has, and
// broadcast the silent AP/MP-use per victim so the client's gauges follow.
func (f *Fight) applyZoneResourceLoss(caster *FightFighter, ef gamedata.Effect, ap bool) {
	if caster == nil {
		return
	}
	amount := ef.Roll(f.rngSource())
	if amount <= 0 {
		return
	}
	for _, victim := range f.areaFighters(caster, ef, caster.Pos) {
		if victim == caster {
			continue
		}
		have, runEffect := victim.MP, int32(protocol.RunEffectMPUse)
		if ap {
			have, runEffect = victim.AP, int32(protocol.RunEffectAPUse)
		}
		drained := amount
		if drained > have {
			drained = have
		}
		if drained <= 0 {
			continue
		}
		if ap {
			victim.AP -= drained
		} else {
			victim.MP -= drained
		}
		eff, _ := buildRunningEffect(f.nextActionUID(), runEffect, ef.EffectID,
			caster.WireID, victim.WireID, victim.Pos, drained, 0, true,
			sourceSpellPart(f.sourceSpellID))
		f.broadcast(eff)
	}
}

// applyZoneDamage (165 fire / 166 water / 167 air / 168 earth, "Perte de points
// de vie <élément> triggerée en zone") deals elemental damage to every fighter
// in the spell's zone centred on the CASTER, the caster excluded — the same
// footprint rule as its 169/177 siblings, resolved through the ordinary
// elemental pipeline so resistance, rebound and transfer all apply.
func (f *Fight) applyZoneDamage(caster *FightFighter, ef gamedata.Effect, _ Pos) {
	if caster == nil {
		return
	}
	elem := damageElement(ef.ActionID)
	for _, victim := range f.areaFighters(caster, ef, caster.Pos) {
		if victim == caster {
			continue
		}
		// Roll PER VICTIM: the magnitude is a dice range, and every other
		// multi-target path in this resolver rolls per target.
		base := ef.Roll(f.rngSource())
		if base <= 0 {
			continue
		}
		final := f.computeElementalDamage(caster, victim, base, elem)
		final = f.applyDamageRebound(caster, victim, final, ef.EffectID)
		f.applyHPDelta(caster, victim, ef.ActionID, ef.EffectID, -final)
	}
}

// applyLineDamage (178-181 "…en ligne entre deux combattants") deals elemental
// damage to every living fighter inside the axis-aligned bounding box spanned by
// the caster and the aimed target (both excluded), each reduced by its own
// resistances (no positional/flanking bonus). It degenerates to a straight line
// when caster and target share a row or column.
func (f *Fight) applyLineDamage(caster *FightFighter, ef gamedata.Effect, target Pos) {
	if caster == nil {
		return
	}
	base := ef.Roll(f.rngSource())
	if base <= 0 {
		return
	}
	elem := damageElement(ef.ActionID)
	renderID := directElementActionID(elem)
	minX, maxX := minI32(caster.Pos.X, target.X), maxI32(caster.Pos.X, target.X)
	minY, maxY := minI32(caster.Pos.Y, target.Y), maxI32(caster.Pos.Y, target.Y)
	aimed := f.fighterAtCell(target)
	for _, victim := range f.livingFighters() {
		if victim == caster || victim == aimed {
			continue
		}
		if victim.Pos.X < minX || victim.Pos.X > maxX || victim.Pos.Y < minY || victim.Pos.Y > maxY {
			continue
		}
		dmg := f.computeElementalDamage(caster, victim, base, elem)
		if dmg <= 0 {
			continue
		}
		f.applyHPDelta(caster, victim, renderID, ef.EffectID, -dmg)
	}
}

// applyDamageTransfer (129 "Transfert de dommages") links the target so a
// percentage (params[0]) of the damage it later takes is redirected to the
// caster, for the effect's duration. (Derived — no v2.04b reference; the
// direction/percentage may need refinement once live-observed.)
func (f *Fight) applyDamageTransfer(caster *FightFighter, ef gamedata.Effect, target Pos) {
	victim := f.fighterAtCell(target)
	if caster == nil || victim == nil {
		return
	}
	pct := ef.Roll(f.rngSource())
	if pct <= 0 {
		return
	}
	if pct > 100 {
		pct = 100
	}
	turns, infinite := ef.DurationTurns()
	if infinite {
		turns = infiniteStateTurns
	}
	if turns <= 0 {
		turns = 1
	}
	victim.transfer = &damageTransfer{to: caster, pct: pct, turns: turns}
	eff, _ := buildRunningEffect(f.nextActionUID(), ef.ActionID, ef.EffectID,
		caster.WireID, victim.WireID, victim.Pos, pct, 0, false,
		sourceSpellPart(f.sourceSpellID))
	f.broadcast(eff)
}

// tickTransfers ages every fighter's damage-transfer link by one table-turn and
// drops those that expire. Called at each new table turn.
func (f *Fight) tickTransfers() {
	for _, ff := range f.allFighters() {
		if ff.transfer == nil || ff.transfer.turns >= infiniteStateTurns {
			continue
		}
		ff.transfer.turns--
		if ff.transfer.turns <= 0 {
			ff.transfer = nil
		}
	}
}

// healSilently restores HP to a fighter without broadcasting a heal effect (used
// for HP leech, where the client heals the caster from the leech effect itself).
func (f *Fight) healSilently(ff *FightFighter, amount int32) {
	if ff == nil || amount <= 0 {
		return
	}
	ff.HP += amount
	if ff.HP > ff.MaxHP {
		ff.HP = ff.MaxHP
	}
}

// --- AP/MP effects (loss / steal / gain) ---

// applyStatDrain removes up to the rolled amount of AP or MP from the fighter on
// the target cell (and, when steal is set, grants it to the caster), broadcasting
// the effect's 8120 with the actual drain. The target's flat AP/MP-loss
// resistance (ResAPLoss/ResMPLoss, actions 86/87) reduces the amount removed — a
// direct port of the v2.04b applyResistance model: a plain LOSS resists the full
// rolled value then caps at the current resource; a STEAL caps at the current
// resource first, then resists, and the caster gains exactly the resisted amount
// (matching CharacLeech). A no-target or fully-resisted effect is a silent no-op.
func (f *Fight) applyStatDrain(caster *FightFighter, ef gamedata.Effect, target Pos, ap, steal bool) {
	victim := f.fighterAtCell(target)
	if victim == nil {
		return
	}
	amount := ef.Roll(f.rngSource())
	if amount <= 0 {
		return
	}
	cur := &victim.MP
	resist := victim.Stats.resMPLoss
	if ap {
		cur = &victim.AP
		resist = victim.Stats.resAPLoss
	}
	var drained int32
	if steal {
		// Steal caps at the target's current resource, THEN applies the resist; the
		// caster gains the resisted amount.
		leeched := amount
		if leeched > *cur {
			leeched = *cur
		}
		drained = applyLossResist(leeched, resist)
	} else {
		// Loss resists the full rolled value, then removes up to the current resource.
		drained = applyLossResist(amount, resist)
		if drained > *cur {
			drained = *cur
		}
	}
	if drained <= 0 {
		return
	}
	*cur -= drained
	if steal {
		if ap {
			caster.AP += drained
		} else {
			caster.MP += drained
		}
	}
	eff, _ := buildRunningEffect(f.nextActionUID(), ef.ActionID, ef.EffectID,
		caster.WireID, victim.WireID, victim.Pos, drained, 0, false)
	f.broadcast(eff)
}

// applyResourceGain grants AP (id 15) or MP (id 19) to the fighter on the target
// cell (self for a range-0 cast), capped at that resource's ceiling.
func (f *Fight) applyResourceGain(caster *FightFighter, ef gamedata.Effect, target Pos, ap bool) {
	victim := f.fighterAtCell(target)
	if victim == nil {
		return
	}
	amount := ef.Roll(f.rngSource())
	if amount <= 0 {
		return
	}
	cur, max := &victim.MP, victim.MaxMP
	if ap {
		cur, max = &victim.AP, victim.MaxAP
	}
	gain := amount
	if *cur+gain > max {
		gain = max - *cur
	}
	if gain <= 0 {
		return
	}
	*cur += gain
	eff, _ := buildRunningEffect(f.nextActionUID(), ef.ActionID, ef.EffectID,
		caster.WireID, victim.WireID, victim.Pos, gain, 0, false)
	f.broadcast(eff)
}

// --- Positioning effects (teleport / swap / push / pull) ---

// applyTeleport moves the CASTER to the targeted cell (the client's go effect
// reads the destination from the running-effect's cell field). The cast-range
// and free-cell rules were already enforced in spellTargetValid; we still require
// a real arena cell and snap z to its altitude so the client accepts the move.
func (f *Fight) applyTeleport(caster *FightFighter, ef gamedata.Effect, target Pos) {
	if caster == nil || !f.Arena().walkable(target.X, target.Y) {
		return
	}
	if f.cellDestroyed(target.X, target.Y) {
		return // sudden death removed this cell
	}
	dest := Pos{X: target.X, Y: target.Y, Z: f.Arena().altitudeAt(target.X, target.Y)}
	from := caster.Pos
	caster.Pos = dest
	// Teleport moves the caster (part-1) to the cell in part-0; there is no target
	// fighter (go.aI()==false), so part-2 mirrors the caster.
	eff, _ := buildRunningEffect(f.nextActionUID(), ef.ActionID, ef.EffectID,
		caster.WireID, caster.WireID, dest, 0, 0, false)
	f.broadcast(eff)
	f.checkEffectAreasMove(from, dest, caster)
}

// logfDebug reports a routine gameplay rejection (a refused cast or a
// state-blocked effect) at Debug level — useful when diagnosing cast flows,
// silent in normal operation. Tests build bare Fights with a nil logger.
func (f *Fight) logfDebug(msg string, args ...any) {
	if f.deps != nil && f.deps.Log != nil {
		f.deps.Log.Debug(msg, args...)
	}
}

// applySwap exchanges the caster's and target fighter's cells.
func (f *Fight) applySwap(caster *FightFighter, ef gamedata.Effect, target Pos) {
	victim := f.fighterAtCell(target)
	if victim == nil || victim == caster {
		f.logfDebug("swap refused: no victim",
			"caster", caster.WireID, "target", target,
			"victimNil", victim == nil)
		return
	}
	if victim.hasState(stateIntransposable) {
		f.logfDebug("swap refused: intransposable",
			"caster", caster.WireID, "victim", victim.WireID)
		return // "Rendre intransposable" (128 → property deB) blocks aox_1 swaps
	}
	casterCell := caster.Pos
	victimCell := victim.Pos
	caster.Pos, victim.Pos = victim.Pos, casterCell
	// The client's aox_1 computes both cells from the live fighter positions; it
	// needs the compute path, so mustExecNow is set.
	eff, _ := buildRunningEffect(f.nextActionUID(), ef.ActionID, ef.EffectID,
		caster.WireID, victim.WireID, casterCell, 0, 0, true)
	f.logfDebug("swap applied", "caster", caster.WireID,
		"victim", victim.WireID, "cell", casterCell)
	f.broadcast(eff)
	// BOTH fighters changed cell, and the client notifies the area manager twice
	// for exactly that reason (aox_1 calls gX().a(...) once per swapped fighter).
	f.checkEffectAreasMove(casterCell, caster.Pos, caster)
	f.checkEffectAreasMove(victimCell, victim.Pos, victim)
}

// applyPushPull shoves the target fighter along the caster→target axis (push) or
// toward the caster (pull), replicating the client's ray-trace so the server's
// fighter positions stay in sync. Collision damage (neutral) is applied to the
// pushed fighter for every cell it could not travel (6/cell into void or an edge,
// 3/cell into a blocking fighter); a collision into a fighter also deals the same
// damage to that blocker. Direction is quantised to the 4 cardinal grid
// directions exactly as the client's agv_0.E.
//
// NOTE: not yet live-verifiable (no practice spell pushes); the server model is
// unit-tested and authoritative, and the native effect is broadcast for the
// client to animate.
func (f *Fight) applyPushPull(caster *FightFighter, ef gamedata.Effect, target Pos, push bool) {
	victim := f.fighterAtCell(target)
	if victim == nil || victim == caster {
		return
	}
	if victim.hasState(stateStabilized) {
		return // "Stabilisation" (94 → property dev) blocks push (37) / pull (38)
	}
	distance := ef.Roll(f.rngSource())
	if distance <= 0 {
		return
	}
	var dx, dy int32
	if push {
		dx, dy = cardinalStep(victim.Pos.X-caster.Pos.X, victim.Pos.Y-caster.Pos.Y)
	} else {
		dx, dy = cardinalStep(caster.Pos.X-victim.Pos.X, caster.Pos.Y-victim.Pos.Y)
	}
	if dx == 0 && dy == 0 {
		return
	}
	var stopAt *Pos
	if !push {
		stopAt = &caster.Pos // pull stops on the caster's cell (no collision damage)
	}
	f.shoveFighter(caster, victim, victim.WireID, ef, dx, dy, distance, stopAt)
}

// shoveFighter is the shared body of every forced displacement: push (37), pull
// (38) and self-push (153). It ray-walks `mover` up to `distance` cells along
// (dx,dy) with the client's own stopping rules, applies collision damage, moves
// the server model and broadcasts the native effect with its destination.
//
// caster/targetWireID are the effect's two fighter slots, which are NOT always
// "the shover and the shoved": for 153 the client moves the effect's CASTER
// (`azw_0` uses `bWl` where `na_2` uses `bWm`), so there the caster IS the mover
// and the target is the fighter it recoils from.
func (f *Fight) shoveFighter(caster, mover *FightFighter, targetWireID int64, ef gamedata.Effect, dx, dy, distance int32, stopAt *Pos) {
	curX, curY := mover.Pos.X, mover.Pos.Y
	curAlt := f.Arena().altitudeAt(curX, curY)
	var moved int32
	stoppedOnVoid, hitFighter := false, (*FightFighter)(nil)
	for i := int32(0); i < distance; i++ {
		nx, ny := curX+dx, curY+dy
		if stopAt != nil && nx == stopAt.X && ny == stopAt.Y {
			break
		}
		if !f.Arena().walkable(nx, ny) {
			stoppedOnVoid = true
			break
		}
		if alt := f.Arena().altitudeAt(nx, ny); alt-curAlt > 2 {
			break // cannot be shoved up a step taller than 2
		}
		if other := f.fighterAtCell(Pos{X: nx, Y: ny}); other != nil {
			hitFighter = other
			break
		}
		curX, curY, curAlt = nx, ny, f.Arena().altitudeAt(nx, ny)
		moved++
	}
	shoveFrom := mover.Pos
	if moved > 0 {
		mover.Pos = Pos{X: curX, Y: curY, Z: curAlt}
	}
	// Collision damage for the cells it could not travel.
	cellsLeft := distance - moved
	collision := int32(0)
	if cellsLeft > 0 && (stoppedOnVoid || hitFighter != nil) {
		perCell := int32(3)
		if stoppedOnVoid {
			perCell = 6
		}
		collision = cellsLeft * perCell
	}
	// Broadcast the native push/pull effect (client animates + shows its own
	// collision damage); the value carries the cells actually moved.
	//
	// The DESTINATION must ride along in part 3: the client moves the fighter to
	// the cell in that part verbatim (`na_2.java:57` m(bzW)) and never derives it
	// itself on the wire path, so without it the shove lands on null/stale.
	var blocked int64
	if hitFighter != nil {
		blocked = hitFighter.WireID
	}
	eff, _ := buildRunningEffect(f.nextActionUID(), ef.ActionID, ef.EffectID,
		caster.WireID, targetWireID, mover.Pos, moved, 0, true,
		displacementPart(mover.Pos, blocked), sourceSpellPart(f.sourceSpellID))
	f.broadcast(eff)
	if collision > 0 {
		f.applyCollisionDamage(caster, mover, collision)
		// A fighter shoved into another (push OR pull) shares the impact: the
		// blocker takes the same collision damage (v2.04b applyPushPull).
		if hitFighter != nil {
			f.applyCollisionDamage(caster, hitFighter, collision)
		}
	}
	// Being shoved onto a trap arms it, exactly as walking on would. Checked
	// after the collision so a fighter the impact already killed does not also
	// spring the trap.
	if moved > 0 && mover.HP > 0 {
		f.checkEffectAreasMove(shoveFrom, mover.Pos, mover)
	}
}

// applyCollisionDamage removes neutral collision HP from a fighter WITHOUT
// broadcasting a separate HP-loss effect (the client's push/pull effect spawns
// its own collision damage display); it only keeps the server HP model in sync
// and fires FIGHTER_DIES if the collision is lethal.
func (f *Fight) applyCollisionDamage(_ *FightFighter, victim *FightFighter, amount int32) {
	if victim == nil || amount <= 0 {
		return
	}
	victim.HP -= amount
	if victim.HP < 0 {
		victim.HP = 0
	}
	if victim.HP <= 0 {
		dies, _ := buildFighterDies(f.nextActionUID(), victim.WireID)
		f.broadcast(dies)
	}
}

// cardinalStep quantises a (dx,dy) vector to one of the four cardinal grid steps,
// matching the client's agv_0.E angle bucketing (bEK=+x, bEO=-x, bEM=+y, bEQ=-y).
// A zero vector yields (0,0).
func cardinalStep(dx, dy int32) (int32, int32) {
	if dx == 0 && dy == 0 {
		return 0, 0
	}
	ax, ay := dx, dy
	if ax < 0 {
		ax = -ax
	}
	if ay < 0 {
		ay = -ay
	}
	if ax >= ay { // dominant horizontal axis
		if dx > 0 {
			return 1, 0
		}
		return -1, 0
	}
	if dy > 0 {
		return 0, 1
	}
	return 0, -1
}

// --- Characteristic buffs / debuffs ---

// applyBuff resolves a timed characteristic buff/debuff on the fighter at the
// target cell (self for a range-0 cast). Resource buffs (AP/MP/HP/Range) are
// applied to the fighter and, when finite, tracked for revert at expiry; every
// buff — resource or pure-stat — is broadcast with its duration in the packet's
// Nx field so the client renders the buff icon + timer.
func (f *Fight) applyBuff(caster *FightFighter, ef gamedata.Effect, target Pos) {
	victim := f.fighterAtCell(target)
	if victim == nil {
		return
	}
	val := ef.Roll(f.rngSource())
	turns, infinite := ef.DurationTurns()
	res, sign, affectsMax, isResource := ef.BuffResource()

	switch {
	case isResource && res == gamedata.BuffSummons:
		// NB_SUMMONS (action 74) is a raw CharacGain whose PARAM carries the sign:
		// +1 grants a permanent summon slot (the Osamodas/Sadida/Rogue self-buff,
		// infinite duration), -1 is the Masqueraider's 1-turn summon-steal. Use the
		// signed param (Roll strips the sign) and broadcast it verbatim.
		val = signedFirstParam(ef)
		if val != 0 {
			applyResourceDelta(victim, res, val, false)
			f.trackBuff(victim, &activeBuff{actionID: ef.ActionID, effectID: ef.EffectID, res: res, delta: val}, turns, infinite)
		}
	case isResource && val > 0:
		// Resource buff (AP/MP/HP/Range): apply to the fighter and track for revert
		// (at expiry, on dispel, or when action 149 strips it by effectId).
		delta := sign * val
		applyResourceDelta(victim, res, delta, affectsMax)
		f.trackBuff(victim, &activeBuff{actionID: ef.ActionID, effectID: ef.EffectID, res: res, delta: delta, affectsMax: affectsMax}, turns, infinite)
	case isStatBuff(ef.ActionID) && val > 0:
		// Combat-stat buff — MECHANICAL: apply it to the fighter's combat stats so
		// it changes the damage/heal/loss math (elemental damage-resist, AP/MP-loss
		// resist 86/87, damage rebound 89, heal power 78/79), and track the rolled
		// value for exact revert.
		victim.Stats.apply(ef.ActionID, val)
		f.trackBuff(victim, &activeBuff{actionID: ef.ActionID, effectID: ef.EffectID, delta: val, statBuff: true}, turns, infinite)
	default:
		// Other pure-stat buff (crit, dodge, …): render-only, but keep a
		// counterpart so the buff count (and 149 removal) matches the client's.
		f.trackBuff(victim, &activeBuff{actionID: ef.ActionID, effectID: ef.EffectID}, turns, infinite)
	}

	// Nx carries the duration the client ticks down (RunningEffect.jt(Nx)), and
	// part 4 names the source spell — without it the client files the buff under
	// no spell and its buff bar skips it entirely (ee_2.java:562).
	eff, _ := buildRunningEffect(f.nextActionUID(), ef.ActionID, ef.EffectID,
		caster.WireID, victim.WireID, victim.Pos, val, 0, false,
		sourceSpellPart(f.sourceSpellID))
	f.broadcast(eff)
}

// trackBuff records b on the victim so its stat change can be reverted later — at
// expiry (tickBuffs), on dispel, or when action 149 strips it by effectId. A
// finite buff (turns > 0) counts down; an infinite one (duration ≥ 63, e.g. a
// mask's permanent malus) is flagged so tickBuffs never ages it but 149 still
// finds it. An instant (turns 0, non-infinite) buff is not tracked.
func (f *Fight) trackBuff(victim *FightFighter, b *activeBuff, turns int32, infinite bool) {
	if infinite {
		b.infinite = true
		b.turnsLeft = infiniteStateTurns
	} else if turns > 0 {
		b.turnsLeft = turns
	} else {
		return
	}
	victim.Buffs = append(victim.Buffs, b)
}

// revertBuff undoes a buff's stat contribution — resource (AP/MP/HP/Range/summons)
// or a combat stat (elemental or scalar). Called when a buff expires, is
// dispelled, or is stripped by 149.
func (f *Fight) revertBuff(ff *FightFighter, b *activeBuff) {
	switch {
	case b.statBuff:
		ff.Stats.apply(b.actionID, -b.delta)
	case b.delta != 0:
		applyResourceDelta(ff, b.res, -b.delta, b.affectsMax)
	}
}

// applyResourceDelta adjusts a fighter's resource by a signed delta. A ceiling
// buff (affectsMax) moves the max; a positive change also lifts the current value
// so it is usable this turn; the current value is re-clamped to [0, max].
func applyResourceDelta(ff *FightFighter, res gamedata.BuffResource, delta int32, affectsMax bool) {
	switch res {
	case gamedata.BuffHP:
		if affectsMax {
			ff.MaxHP += delta
			if ff.MaxHP < 0 {
				ff.MaxHP = 0
			}
		}
		ff.HP += delta
		clampResource(&ff.HP, ff.MaxHP)
	case gamedata.BuffAP:
		if affectsMax {
			ff.MaxAP += delta
			if ff.MaxAP < 0 {
				ff.MaxAP = 0
			}
		}
		if delta > 0 {
			ff.AP += delta
		}
		clampResource(&ff.AP, ff.MaxAP)
	case gamedata.BuffMP:
		if affectsMax {
			ff.MaxMP += delta
			if ff.MaxMP < 0 {
				ff.MaxMP = 0
			}
		}
		if delta > 0 {
			ff.MP += delta
		}
		clampResource(&ff.MP, ff.MaxMP)
	case gamedata.BuffRange:
		ff.Range += delta
		if ff.Range < 0 {
			ff.Range = 0
		}
	case gamedata.BuffSummons:
		// NB_SUMMONS is stored UNCLAMPED (the client characteristic is bounded by
		// Integer.MIN/MAX): a summon-steal (-1) can push the effective cap
		// (1 + NB_SUMMONS) to zero, and storing the raw value keeps apply/revert
		// symmetric (a clamp-at-write would leak a summon back on expiry).
		ff.NbSummons += delta
	case gamedata.BuffCritRate:
		ff.CritRate += delta
		if ff.CritRate < 0 {
			ff.CritRate = 0
		}
	case gamedata.BuffFumbleRate:
		ff.FumbleRate += delta
		if ff.FumbleRate < 0 {
			ff.FumbleRate = 0
		}
	case gamedata.BuffBlock:
		// Stored unclamped so a timed debuff reverts exactly; bounded at read
		// time by tackleEvasionChance.
		ff.Block += delta
	case gamedata.BuffDodge:
		ff.Dodge += delta
	}
}

func clampResource(v *int32, max int32) {
	if *v < 0 {
		*v = 0
	}
	if *v > max {
		*v = max
	}
}

// signedFirstParam returns the effect's first param with its sign preserved (0 if
// absent). Unlike Effect.Roll (which returns a positive magnitude), it is used by
// the NB_SUMMONS buff, whose param sign is the effect's direction (+1 grant /
// -1 steal). Every shipped action-74 effect is a single fixed param.
func signedFirstParam(ef gamedata.Effect) int32 {
	if len(ef.Params) == 0 {
		return 0
	}
	return int32(ef.Params[0])
}

// tickBuffs decrements every fighter's finite buffs by one table-turn and reverts
// those that expire (undoing their resource delta). Called at each new table turn
// so buff lifetimes match the round-based duration the client counts.
func (f *Fight) tickBuffs() {
	for _, ff := range f.allFighters() {
		if len(ff.Buffs) == 0 {
			continue
		}
		kept := ff.Buffs[:0]
		for _, b := range ff.Buffs {
			if b.infinite {
				kept = append(kept, b) // permanent (mask malus etc.) — aged only by 149/dispel
				continue
			}
			b.turnsLeft--
			if b.turnsLeft > 0 {
				kept = append(kept, b)
				continue
			}
			f.revertBuff(ff, b) // expired: undo its stat change
		}
		ff.Buffs = kept
	}
}

// applyFallbackDamage deals the default flat neutral hit for an unknown spell id
// or absent gamedata, so a cast is never inert (used by the e2e's spell 0 and any
// unrecognised id).
func (f *Fight) applyFallbackDamage(caster *FightFighter, target Pos) {
	victim := f.fighterAtCell(target)
	if victim == nil {
		return
	}
	dmg := int32(defaultSpellDamage)
	if dmg > victim.HP {
		dmg = victim.HP
	}
	victim.HP -= dmg
	hp, _ := buildRunningEffect(f.nextActionUID(), protocol.RunEffectHPLoss, 0,
		caster.WireID, victim.WireID, victim.Pos, dmg, 0, false)
	f.broadcast(hp)
	if victim.HP <= 0 {
		dies, _ := buildFighterDies(f.nextActionUID(), victim.WireID)
		f.broadcast(dies)
	}
}
