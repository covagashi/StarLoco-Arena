package game

import "github.com/StarLoco/arena-2.70/internal/gamedata"

// effectarea.go implements persistent ground-effect areas — traps and glyphs.
// A spell effect with action id 66 ("Pose un piège", KindTrap) places an area at
// the target cell from a type-210 StaticEffect template (params[0] = template
// id). The area lingers on the battlefield and, when a fighter TRIGGERS it,
// replays the template's inner effects on that fighter. This is a port of the
// v2.04b server's EffectArea system (internal/combat/effectarea.go), adapted to
// the 2.70 fight/effect model.
//
// Trigger model: the 2.70 data uses a 10000-range trigger enum, recovered from
// the client's he_1.a (B-076): 10001 = a fighter ENTERS the footprint (the
// classic trap); 10008 = it moves while staying INSIDE it (Bruma, Bruma
// mortal); 10000 = it STARTS its turn on the footprint (the SPECIAL map tiles /
// glyphs). We fire on those three. 10002 (left) only un-applies, and 10003 /
// 10006 are fired by nothing in the client; see sprints/S19.
//
// Firing is SERVER-AUTHORITATIVE: the trap's inner effects are resolved through
// the normal effect resolver, each broadcasting its own RUNNING_EFFECT, so the
// client renders the trap's damage/state exactly like a spell's. The area's own
// lifetime is governed by maxExec (>=63 / <0 = unlimited); a finite area removes
// itself once exhausted.

// EffectArea trigger event ids (2.70 enum, from the shipped trap/special data).
const (
	trapTriggerTurnStart int32 = 10000 // start of a fighter's turn while on the footprint (glyph/special)
	trapTriggerWalkOn    int32 = 10001 // a fighter enters the footprint during movement (trap)
	trapTriggerStay      int32 = 10008 // a fighter moves from one footprint cell to another
)

// trapWireIDOffset namespaces live-area ids well clear of coach, fighter and
// summon id spaces (summon uses 1<<28), so an area id never collides.
const trapWireIDOffset int64 = 1 << 29

// effectArea is one live trap/glyph/aura on the battlefield.
type effectArea struct {
	id         int64                  // unique wire id (allocated server-side)
	templateID int32                  // the type-210 template it was placed from
	effectID   int32                  // source effect's generic effectId — the key action 149 removes by
	tmpl       *gamedata.StaticEffect // footprint + inner effects
	center     Pos                    // the cell it was placed on (fixed traps)
	caster     *FightFighter          // who placed it (the inner effects' caster)
	maxExec    int32                  // remaining firings; >=63 / <0 = unlimited
	// follow makes this an AURA: its centre tracks this fighter's live cell (the
	// caster) instead of `center`, it fires only on turn-start, and it lives for
	// `turnsLeft` rounds (and dies with `follow`).
	follow    *FightFighter
	turnsLeft int32
	// expires marks a fixed trap placed by an effect with a finite duration:
	// the client drops the area when that running effect ends (ds_1.aK), so
	// it lives turnsLeft rounds, like an aura. An infinite or zero duration
	// leaves it to maxExec alone.
	expires bool
}

// isAura reports whether this area follows a fighter (an aura vs a fixed trap).
func (a *effectArea) isAura() bool { return a.follow != nil }

// unlimited reports whether the area never self-removes from firing count.
func (a *effectArea) unlimited() bool { return a.maxExec >= 63 || a.maxExec < 0 }

// exhausted reports whether the area should be removed: a finite trap that used
// up its firings, or an aura whose lifetime elapsed or whose caster died.
func (a *effectArea) exhausted() bool {
	if a.isAura() {
		return a.turnsLeft <= 0 || a.follow == nil || a.follow.HP <= 0
	}
	if a.expires && a.turnsLeft <= 0 {
		return true
	}
	return !a.unlimited() && a.maxExec <= 0
}

// currentCenter is the area's live centre — the followed fighter's cell for an
// aura, else the fixed placement cell.
func (a *effectArea) currentCenter() Pos {
	if a.follow != nil {
		return a.follow.Pos
	}
	return a.center
}

// firesOnEnter / firesOnTurnStart report which trigger events fire this area. An
// aura fires only on turn-start (for whoever starts a turn inside it); a trap
// uses its template's AppTriggers.
func (a *effectArea) firesOnEnter() bool {
	return !a.isAura() && containsI32(a.tmpl.AppTriggers, trapTriggerWalkOn)
}
func (a *effectArea) firesOnStay() bool {
	return !a.isAura() && containsI32(a.tmpl.AppTriggers, trapTriggerStay)
}
func (a *effectArea) firesOnTurnStart() bool {
	return a.isAura() || containsI32(a.tmpl.AppTriggers, trapTriggerTurnStart)
}

// contains reports whether cell lies within the area's footprint (shape+size at
// its live centre). A point/sizeless footprint matches only its exact cell; a
// circle/cross/T uses the shared zone hit-test (the area has no directional
// source, so centre doubles as source — matching the v2.04b Contains()).
func (a *effectArea) contains(cell Pos) bool {
	center := a.currentCenter()
	shape := a.tmpl.AreaShape
	if shape == areaShapePoint || shape == 0 || len(a.tmpl.AreaSize) == 0 {
		return cell.X == center.X && cell.Y == center.Y
	}
	return pointInArea(shape, a.tmpl.AreaSize, center, center, cell)
}

// applySetEffectArea (action 66) places a ground-effect area at the cast cell
// from the template named by the effect's params[0]. It acts on the CELL, not on
// a target fighter (so resolveEffect dispatches it before the per-target loop).
func (f *Fight) applySetEffectArea(caster *FightFighter, ef gamedata.Effect, target Pos) {
	if caster == nil || len(ef.Params) == 0 || f.deps == nil || f.deps.StaticEffects == nil {
		return
	}
	templateID := int32(ef.Params[0])
	tmpl := f.deps.StaticEffects.Get(templateID)
	if tmpl == nil || !f.Arena().walkable(target.X, target.Y) {
		return // unknown template / off-map cell: the cast still animated, this is a no-op
	}
	center := Pos{X: target.X, Y: target.Y, Z: f.Arena().altitudeAt(target.X, target.Y)}
	f.effectAreaSeq++
	area := &effectArea{
		id:         FighterWireIDBase + trapWireIDOffset + f.effectAreaSeq,
		templateID: templateID,
		effectID:   ef.EffectID,
		tmpl:       tmpl,
		center:     center,
		caster:     caster,
		maxExec:    tmpl.MaxExec,
	}
	if turns, infinite := ef.DurationTurns(); !infinite && turns > 0 {
		area.expires, area.turnsLeft = true, turns
	}
	f.effectAreas = append(f.effectAreas, area)

	// Broadcast the creation RUNNING_EFFECT (action 66). There is no target
	// fighter (a trap targets a cell), so — like teleport — the target mirrors
	// the caster so ajR() resolves; the client reads the template id from the
	// VALUE field and renders the trap at the cell.
	eff, _ := buildRunningEffect(f.nextActionUID(), ef.ActionID, ef.EffectID,
		caster.WireID, caster.WireID, center, templateID, 0, false)
	f.broadcast(eff)

	if f.deps.Log != nil {
		f.deps.Log.Debug("effect-area placed", "area", area.id, "template", templateID,
			"type", tmpl.Type, "cell", center, "shape", tmpl.AreaShape, "maxExec", tmpl.MaxExec,
			"innerEffects", len(tmpl.Effects))
	}
}

// applySetAura (action 176) places a caster-followed ground-effect area from the
// template named by params[0]: it tracks the caster's live cell and fires on
// turn-start for fighters that begin a turn inside its radius. Acts on the
// caster, so resolveEffect dispatches it single-shot (not per aimed target).
func (f *Fight) applySetAura(caster *FightFighter, ef gamedata.Effect, _ Pos) {
	if caster == nil || len(ef.Params) == 0 || f.deps == nil || f.deps.StaticEffects == nil {
		return
	}
	templateID := int32(ef.Params[0])
	tmpl := f.deps.StaticEffects.Get(templateID)
	if tmpl == nil {
		return // unknown template: cast still animated, no-op
	}
	turns, infinite := ef.DurationTurns()
	if infinite {
		turns = infiniteStateTurns
	}
	if turns <= 0 {
		turns = 1
	}
	f.effectAreaSeq++
	area := &effectArea{
		id:         FighterWireIDBase + trapWireIDOffset + f.effectAreaSeq,
		templateID: templateID,
		effectID:   ef.EffectID,
		tmpl:       tmpl,
		center:     caster.Pos,
		caster:     caster,
		maxExec:    tmpl.MaxExec,
		follow:     caster,
		turnsLeft:  turns,
	}
	f.effectAreas = append(f.effectAreas, area)
	eff, _ := buildRunningEffect(f.nextActionUID(), ef.ActionID, ef.EffectID,
		caster.WireID, caster.WireID, caster.Pos, templateID, 0, false)
	f.broadcast(eff)
	if f.deps.Log != nil {
		f.deps.Log.Debug("aura placed", "area", area.id, "template", templateID,
			"caster", caster.WireID, "turns", turns)
	}
}

// tickEffectAreas ages auras and timed traps by one round and prunes any that
// expired (or whose caster died). Called at each new table turn alongside
// tickBuffs/tickStates.
func (f *Fight) tickEffectAreas() {
	for _, a := range f.effectAreas {
		if (a.isAura() || a.expires) && a.turnsLeft > 0 && a.turnsLeft < infiniteStateTurns {
			a.turnsLeft--
		}
	}
	f.pruneEffectAreas()
}

// checkEffectAreasMove fires any walk-on trap the applicant entered on a single
// movement step (was outside the footprint at `start`, inside it at `arrival`),
// and any stay trap it moved within (inside at both).
// Called per step by applyFighterMove (and any server-driven reposition), so
// walking THROUGH a trap mid-path triggers it. Re-entrancy from an inner effect
// that itself moves a fighter is guarded by inAreaTrigger.
func (f *Fight) checkEffectAreasMove(start, arrival Pos, applicant *FightFighter) {
	if applicant == nil || len(f.effectAreas) == 0 || f.inAreaTrigger {
		return
	}
	for _, a := range f.snapshotAreas() {
		if a.exhausted() || !a.contains(arrival) {
			continue
		}
		inBefore := a.contains(start)
		if (!inBefore && a.firesOnEnter()) || (inBefore && a.firesOnStay()) {
			f.fireEffectArea(a, applicant)
			if applicant.HP <= 0 {
				break // died in the trap; stop the walk-through
			}
		}
	}
	f.pruneEffectAreas()
}

// checkEffectAreasTurnStart fires any turn-start glyph/special the fighter stands
// on at the start of its turn. Called from beginTurn.
func (f *Fight) checkEffectAreasTurnStart(ff *FightFighter) {
	if ff == nil || len(f.effectAreas) == 0 || f.inAreaTrigger {
		return
	}
	for _, a := range f.snapshotAreas() {
		if a.exhausted() || !a.firesOnTurnStart() {
			continue
		}
		if a.isAura() && a.follow == ff {
			continue // an aura does not fire on its own caster
		}
		if a.contains(ff.Pos) {
			f.fireEffectArea(a, ff)
			if ff.HP <= 0 {
				break
			}
		}
	}
	f.pruneEffectAreas()
}

// fireEffectArea replays the template's inner effects on the triggering fighter
// (centered on its cell, exactly like the v2.04b applyEffectArea) and decrements
// a finite firing count. The inner effects broadcast their own RUNNING_EFFECTs,
// so the client renders the trap's damage/state without a bespoke message.
func (f *Fight) fireEffectArea(a *effectArea, applicant *FightFighter) {
	if !a.isAura() && !a.unlimited() && a.maxExec > 0 {
		a.maxExec-- // auras fire for their whole lifetime; only traps count down
	}
	f.inAreaTrigger = true
	f.firingArea = a
	for _, ef := range a.tmpl.Effects {
		// An aura ticks everyone in its radius, so it must respect each inner
		// effect's target conditions (e.g. an enemies-only debuff aura skips
		// allies). A trap fires unconditionally on whoever stepped on it.
		if a.isAura() && !effectTargetAllowed(a.caster, applicant, ef.Targets) {
			continue
		}
		f.resolveEffect(a.caster, ef, applicant.Pos)
	}
	f.inAreaTrigger = false
	f.firingArea = nil
	if f.deps != nil && f.deps.Log != nil {
		f.deps.Log.Debug("effect-area fired", "area", a.id, "template", a.templateID,
			"applicant", applicant.WireID, "cell", applicant.Pos, "remaining", a.maxExec)
	}
	if f.deps != nil {
		f.deps.checkFightEnd(f)
	}
}

// snapshotAreas copies the live-area slice so a firing that mutates it (self-
// removal, or a summon inner effect) can't corrupt the trigger iteration.
func (f *Fight) snapshotAreas() []*effectArea {
	out := make([]*effectArea, len(f.effectAreas))
	copy(out, f.effectAreas)
	return out
}

// pruneEffectAreas drops exhausted single-use areas.
func (f *Fight) pruneEffectAreas() {
	if len(f.effectAreas) == 0 {
		return
	}
	kept := f.effectAreas[:0]
	for _, a := range f.effectAreas {
		if !a.exhausted() {
			kept = append(kept, a)
		}
	}
	f.effectAreas = kept
}

// containsI32 reports whether v is in s.
func containsI32(s []int32, v int32) bool {
	for _, x := range s {
		if x == v {
			return true
		}
	}
	return false
}
