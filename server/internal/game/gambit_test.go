package game

import (
	"encoding/json"
	"fmt"
	"strings"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// gambit_test.go exercises the gambit rule engine (gambit.go, gambit_eval.go)
// against the REAL spell table shipped in server/data-dist, because the part
// worth proving is not that a rule struct round-trips: it is that a rule naming
// a real spell id goes through the same range / line-of-sight / AP / cooldown /
// friendly-fire gates a human coach's cast goes through, and falls back to the
// archetype AI the moment it cannot.
//
// The spells below are read out of the shipped data, not invented:
//
//	 38  2 AP, range 1-4, single cell, needs LoS, no cast limits  (the workhorse)
//	 75  4 AP, range 1-4, single cell, needs LoS, no cast limits  (the stronger one)
//	148  5 AP, range 1-2, single cell, COOLDOWN 1 turn            (the cooldown case)
//	133  3 AP, range 0-3, single cell, pure heal                  (the support case)
//	 51  3 AP, range 1-1, a SUMMON — harms nobody                 (see below)
//	 22  3 AP, range 1-2, pure heal                               (never in a loadout here)
//
// Spell 51 is in the list for a reason worth keeping: it is the id the design
// doc uses in its own example rule, `cast spell 51 at weakest_enemy` — and in
// the real data 51 is a summoning spell, which the engine must refuse to aim at
// an enemy rather than cast because a document said so. That is exactly the
// "anything the client cannot express falls back to the archetype AI" clause,
// caught on the doc's own example.
const (
	realSpellCheap    int32 = 38
	realSpellStrong   int32 = 75
	realSpellCooldown int32 = 148
	realSpellHeal     int32 = 133
	realSpellSummon   int32 = 51
	realSpellUnknown  int32 = 22
)

// gambitScene is a 2v2 of session-less fighters (so every one of them is
// AI-driven and reaches runAITurn) on the practice arena, with the real spell
// table loaded.
//
// Geometry, on the arena's walkable band (x 6-14, y 15-16):
//
//	self  (7,15)  init 100 — acts first
//	ally  (7,16)  init 40
//	enemy (11,15) init 70 — 4 cells away: inside 38/75's range, outside 148's
//	weak  (12,16) init 50 — 6 cells away: outside every range in the loadout
//
// Crit and fumble rates are 0 so a cast's effects always land: a fumbled cast
// spends the AP and applies nothing, which would make "did this rule's cast
// land" flaky for reasons that have nothing to do with the rule engine. The
// determinism test below puts the dice back.
type gambitScene struct {
	f                       *Fight
	self, ally, enemy, weak *FightFighter
}

func newGambitScene(t *testing.T) *gambitScene {
	t.Helper()
	gd := openRealGameData(t)
	spells, err := gd.LoadSpells()
	if err != nil {
		t.Fatalf("LoadSpells: %v", err)
	}
	return newGambitSceneWith(t, spells)
}

func newGambitSceneWith(t *testing.T, spells *gamedata.Spells) *gambitScene {
	t.Helper()
	loadout := []int32{realSpellCheap, realSpellStrong, realSpellCooldown, realSpellHeal, realSpellSummon}
	mk := func(wire int64, coach uint, team uint8, name string, x, y, init int32) *FightFighter {
		fs := make([]domain.FighterSpell, 0, len(loadout))
		for _, id := range loadout {
			fs = append(fs, domain.FighterSpell{SpellID: id})
		}
		return &FightFighter{
			WireID: wire, CoachID: coach, TeamID: team,
			Pos: Pos{X: x, Y: y},
			// The signature spell makes classifyAI read "aggressive" (it damages,
			// and MP 3 is under the kite threshold), so the archetype fallback is
			// identifiable by name in the decision log.
			SummonSpellID: realSpellCheap,
			Fighter: &domain.Fighter{
				ID: uint(wire), BreedID: 1, Name: name, Spells: fs,
			},
			HP: 200, MaxHP: 200, AP: 6, MaxAP: 6, MP: 3, MaxMP: 3, Init: init,
		}
	}
	sc := &gambitScene{
		self:  mk(101, 1, 0, "SELF", 7, 15, 100),
		ally:  mk(102, 1, 0, "ALLY", 7, 16, 40),
		enemy: mk(201, 2, 1, "ENEMY", 11, 15, 70),
		weak:  mk(202, 2, 1, "WEAK", 12, 16, 50),
	}
	sc.f = &Fight{
		Teams: [2]*FightTeam{
			{ID: 0, Fighters: []*FightFighter{sc.self, sc.ally}},
			{ID: 1, Fighters: []*FightFighter{sc.enemy, sc.weak}},
		},
		deps: &Deps{
			Spells: spells,
			Fights: NewFightManager(),
			Log:    testLogger(),
		},
		readyPresent: map[uint]bool{}, readyObserve: map[uint]bool{}, readyAction: map[uint]bool{},
	}
	sc.f.SetSeed(20261013)
	sc.f.Timeline = buildTimeline(sc.f)
	sc.f.turnIndex = 0
	sc.f.tableTurn = 1
	sc.f.setPhase(PhaseAction)
	if cur := sc.f.currentFighter(); cur != sc.self {
		t.Fatalf("scene built with the wrong fighter on turn: %v", cur)
	}
	return sc
}

// rules attaches a ruleset to a fighter THROUGH THE PARSER, so every rule a
// test plays with is one the schema accepts — a test must not be able to hand
// the engine a rule the real intake path would have rejected.
func (sc *gambitScene) rules(t *testing.T, ff *FightFighter, body string) {
	t.Helper()
	doc := fmt.Sprintf(`{"version":%d,"rules":[%s]}`, gambitSchemaVersion, body)
	if err := ff.setGambitRulesJSON([]byte(doc)); err != nil {
		t.Fatalf("setGambitRulesJSON(%s): %v", doc, err)
	}
}

// runTurn plays one AI turn for the fighter on turn and drops the timer the
// end-of-turn armed, like the determinism tests do.
func (sc *gambitScene) runTurn(t *testing.T, ff *FightFighter) {
	t.Helper()
	sc.f.runAITurn(ff)
	sc.f.stopClock()
}

// behaviorDetails returns every "which plan is this fighter playing" row of the
// decision log, which is where both a fired gambit rule and an archetype choice
// land (fightlog.go).
func (sc *gambitScene) behaviorDetails() []string {
	var out []string
	for _, d := range sc.f.decisionLog() {
		if d.Kind == decisionBehavior {
			out = append(out, d.Detail)
		}
	}
	return out
}

func (sc *gambitScene) castDetails() []string {
	var out []string
	for _, d := range sc.f.decisionLog() {
		if d.Kind == decisionCast {
			out = append(out, d.Detail)
		}
	}
	return out
}

// TestGambitRuleSetParsesDocExample: the design doc's own rule shape decodes
// into the vocabulary, carries its schema version, and round-trips back to JSON
// — the contract phase 3's storage and phase 4's editor are written against.
func TestGambitRuleSetParsesDocExample(t *testing.T) {
	doc := []byte(`{
	  "version": 1,
	  "rules": [
	    { "if": {"kind": "enemy_hp_pct_below", "value": 40},
	      "do": {"kind": "cast", "spell": 51, "target": "weakest_enemy"} },
	    { "if": {"kind": "always"},
	      "do": {"kind": "close_combat"} }
	  ]
	}`)
	rs, err := parseGambitRules(doc)
	if err != nil {
		t.Fatalf("parseGambitRules: %v", err)
	}
	if rs.Version != gambitSchemaVersion {
		t.Errorf("version = %d, want %d", rs.Version, gambitSchemaVersion)
	}
	if len(rs.Rules) != 2 {
		t.Fatalf("rules = %d, want 2", len(rs.Rules))
	}
	first := rs.Rules[0]
	if first.If.Kind != gambitEnemyHPBelow || first.If.Value != 40 {
		t.Errorf("rule 1 condition = %s, want enemy_hp_pct_below:40", first.If)
	}
	if first.Do.Kind != gambitCast || first.Do.Spell != 51 || first.Do.Target != gambitTargetWeakestEnemy {
		t.Errorf("rule 1 action = %s, want cast:51@weakest_enemy", first.Do)
	}
	if rs.Rules[1].Do.Kind != gambitCloseCombat {
		t.Errorf("rule 2 action = %s, want close_combat", rs.Rules[1].Do)
	}
	// The rendering that goes into the decision log must identify the rule.
	if got, want := first.String(), "if=enemy_hp_pct_below:40 do=cast:51@weakest_enemy"; got != want {
		t.Errorf("rule String() = %q, want %q", got, want)
	}

	// Re-encode and re-parse: what the server stores it can read back.
	enc, err := json.Marshal(rs)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}
	back, err := parseGambitRules(enc)
	if err != nil {
		t.Fatalf("re-parse of %s: %v", enc, err)
	}
	if fmt.Sprint(back) != fmt.Sprint(rs) {
		t.Errorf("round trip changed the ruleset:\n got %v\nwant %v", back, rs)
	}
}

// TestGambitRuleSetRejectsMalformed is the "rejected rather than crashing or
// silently passing" requirement, one case per way a ruleset can be wrong.
//
// Each case must come back as an ERROR and must leave the fighter's rules
// untouched: a half-understood list plays a strategy its author never wrote,
// so the only safe outcome is no list at all (and therefore the archetype AI).
func TestGambitRuleSetRejectsMalformed(t *testing.T) {
	cases := []struct{ name, doc string }{
		{"not json", `{"version":1,`},
		{"empty document", ``},
		{"no version", `{"rules":[{"if":{"kind":"always"},"do":{"kind":"pass"}}]}`},
		{"future version", `{"version":2,"rules":[{"if":{"kind":"always"},"do":{"kind":"pass"}}]}`},
		{"no rules", `{"version":1,"rules":[]}`},
		{"null rules", `{"version":1,"rules":null}`},
		{"unknown condition kind", `{"version":1,"rules":[{"if":{"kind":"enemy_is_ugly","value":5},"do":{"kind":"pass"}}]}`},
		{"condition without kind", `{"version":1,"rules":[{"if":{"value":5},"do":{"kind":"pass"}}]}`},
		{"unknown action kind", `{"version":1,"rules":[{"if":{"kind":"always"},"do":{"kind":"flee"}}]}`},
		{"action without kind", `{"version":1,"rules":[{"if":{"kind":"always"},"do":{"spell":38}}]}`},
		{"unknown field", `{"version":1,"rules":[{"if":{"kind":"always"},"do":{"kind":"cast","spel":38,"target":"self"}}]}`},
		{"unknown top-level field", `{"version":1,"rules":[{"if":{"kind":"always"},"do":{"kind":"pass"}}],"elo":1200}`},
		{"trailing content", `{"version":1,"rules":[{"if":{"kind":"always"},"do":{"kind":"pass"}}]} {"version":1}`},
		{"cast without spell", `{"version":1,"rules":[{"if":{"kind":"always"},"do":{"kind":"cast","target":"self"}}]}`},
		{"cast without target", `{"version":1,"rules":[{"if":{"kind":"always"},"do":{"kind":"cast","spell":38}}]}`},
		{"unknown cast target", `{"version":1,"rules":[{"if":{"kind":"always"},"do":{"kind":"cast","spell":38,"target":"the_healer"}}]}`},
		{"negative spell", `{"version":1,"rules":[{"if":{"kind":"always"},"do":{"kind":"cast","spell":-1,"target":"self"}}]}`},
		{"spell on a move", `{"version":1,"rules":[{"if":{"kind":"always"},"do":{"kind":"move_toward","spell":38}}]}`},
		{"target on a pass", `{"version":1,"rules":[{"if":{"kind":"always"},"do":{"kind":"pass","target":"self"}}]}`},
		{"value on always", `{"version":1,"rules":[{"if":{"kind":"always","value":3},"do":{"kind":"pass"}}]}`},
		{"hp pct 0", `{"version":1,"rules":[{"if":{"kind":"self_hp_pct_below","value":0},"do":{"kind":"pass"}}]}`},
		{"hp pct 101", `{"version":1,"rules":[{"if":{"kind":"ally_hp_pct_below","value":101},"do":{"kind":"pass"}}]}`},
		{"turn 0", `{"version":1,"rules":[{"if":{"kind":"turn_ge","value":0},"do":{"kind":"pass"}}]}`},
		{"distance too large", `{"version":1,"rules":[{"if":{"kind":"nearest_enemy_distance_le","value":65},"do":{"kind":"pass"}}]}`},
		{"negative distance", `{"version":1,"rules":[{"if":{"kind":"nearest_enemy_distance_le","value":-1},"do":{"kind":"pass"}}]}`},
		{"ally count too large", `{"version":1,"rules":[{"if":{"kind":"ally_count_le","value":17},"do":{"kind":"pass"}}]}`},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			ff := &FightFighter{WireID: 1}
			if err := ff.setGambitRulesJSON([]byte(c.doc)); err == nil {
				t.Fatalf("accepted a malformed ruleset: %s", c.doc)
			}
			if ff.Gambits != nil {
				t.Error("a rejected ruleset was attached to the fighter anyway")
			}
		})
	}

	// Too many rules: built rather than written out, but the same rejection.
	var b strings.Builder
	b.WriteString(fmt.Sprintf(`{"version":%d,"rules":[`, gambitSchemaVersion))
	for i := 0; i <= maxGambitRules; i++ {
		if i > 0 {
			b.WriteByte(',')
		}
		b.WriteString(`{"if":{"kind":"always"},"do":{"kind":"pass"}}`)
	}
	b.WriteString(`]}`)
	if _, err := parseGambitRules([]byte(b.String())); err == nil {
		t.Errorf("accepted %d rules, want the cap of %d enforced", maxGambitRules+1, maxGambitRules)
	}
}

// TestGambitConditionKindsEvaluateBothWays covers every condition kind in the
// v1 vocabulary firing and NOT firing against real fight state. A condition
// that is always true (or always false) would make a whole ruleset meaningless,
// and neither shows up in a test that only checks one direction.
func TestGambitConditionKindsEvaluateBothWays(t *testing.T) {
	cond := func(kind gambitConditionKind, v int32) gambitCondition {
		return gambitCondition{Kind: kind, Value: v}
	}
	cases := []struct {
		name string
		c    gambitCondition
		// setup mutates the scene; want is what the condition must then say.
		setup func(sc *gambitScene)
		want  bool
	}{
		{"always", cond(gambitAlways, 0), nil, true},

		{"self hp below, hurt", cond(gambitSelfHPBelow, 50), func(sc *gambitScene) { sc.self.HP = 90 }, true},
		{"self hp below, healthy", cond(gambitSelfHPBelow, 50), nil, false},
		{"self hp below, exactly at the threshold is not below",
			cond(gambitSelfHPBelow, 50), func(sc *gambitScene) { sc.self.HP = 100 }, false},

		{"enemy hp below, one is hurt", cond(gambitEnemyHPBelow, 50), func(sc *gambitScene) { sc.weak.HP = 10 }, true},
		{"enemy hp below, both healthy", cond(gambitEnemyHPBelow, 50), nil, false},
		{"enemy hp below ignores an invisible enemy", cond(gambitEnemyHPBelow, 50), func(sc *gambitScene) {
			sc.weak.HP = 10
			sc.weak.addState(stateInvisible, 3)
		}, false},
		{"enemy hp below ignores a dead enemy", cond(gambitEnemyHPBelow, 50), func(sc *gambitScene) {
			sc.weak.HP = 0
		}, false},
		{"enemy hp below ignores the fighter's own side", cond(gambitEnemyHPBelow, 50), func(sc *gambitScene) {
			sc.ally.HP = 5
			sc.self.HP = 5
		}, false},

		{"ally hp below, ally is hurt", cond(gambitAllyHPBelow, 50), func(sc *gambitScene) { sc.ally.HP = 20 }, true},
		{"ally hp below, ally is healthy", cond(gambitAllyHPBelow, 50), nil, false},
		{"ally hp below does not count the fighter itself", cond(gambitAllyHPBelow, 50), func(sc *gambitScene) {
			sc.self.HP = 1
		}, false},

		{"nearest enemy within 4", cond(gambitNearestEnemyDistLE, 4), nil, true},
		{"nearest enemy not within 3", cond(gambitNearestEnemyDistLE, 3), nil, false},
		{"nearest enemy ignores an invisible one", cond(gambitNearestEnemyDistLE, 4), func(sc *gambitScene) {
			sc.enemy.addState(stateInvisible, 3) // leaves only WEAK, 6 cells away
		}, false},

		{"turn_ge 1 on round 1", cond(gambitTurnGE, 1), nil, true},
		{"turn_ge 2 on round 1", cond(gambitTurnGE, 2), nil, false},
		{"turn_ge 3 on round 4", cond(gambitTurnGE, 3), func(sc *gambitScene) { sc.f.tableTurn = 4 }, true},

		{"ally_count_le 1 with one ally", cond(gambitAllyCountLE, 1), nil, true},
		{"ally_count_le 0 with one ally", cond(gambitAllyCountLE, 0), nil, false},
		{"ally_count_le 0 once alone", cond(gambitAllyCountLE, 0), func(sc *gambitScene) { sc.ally.HP = 0 }, true},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			sc := newGambitScene(t)
			if c.setup != nil {
				c.setup(sc)
			}
			if got := sc.f.gambitConditionHolds(sc.self, c.c); got != c.want {
				t.Errorf("%s = %v, want %v", c.c, got, c.want)
			}
		})
	}
}

// TestGambitCastTargetsResolve pins the closed target vocabulary, including the
// cases that resolve to nobody — a rule with no target is a rule that cannot
// act, which is what makes it fall through instead of misfiring.
func TestGambitCastTargetsResolve(t *testing.T) {
	sc := newGambitScene(t)
	// WEAK is the hurt one, and it is the FAR enemy: "weakest" must not quietly
	// mean "nearest".
	sc.weak.HP = 30

	if got := sc.f.gambitResolveTarget(sc.self, gambitTargetSelf); got != sc.self {
		t.Errorf("self -> %v, want SELF", got)
	}
	if got := sc.f.gambitResolveTarget(sc.self, gambitTargetNearestEnemy); got != sc.enemy {
		t.Errorf("nearest_enemy -> %v, want ENEMY at 4 cells", got)
	}
	if got := sc.f.gambitResolveTarget(sc.self, gambitTargetWeakestEnemy); got != sc.weak {
		t.Errorf("weakest_enemy -> %v, want WEAK (30 HP, 6 cells away)", got)
	}
	if got := sc.f.gambitResolveTarget(sc.self, gambitTargetWeakestAlly); got != sc.ally {
		t.Errorf("weakest_ally -> %v, want ALLY", got)
	}

	// weakest_ally deliberately excludes the fighter asking: alone, it resolves
	// to nobody rather than to self.
	sc.ally.HP = 0
	if got := sc.f.gambitResolveTarget(sc.self, gambitTargetWeakestAlly); got != nil {
		t.Errorf("weakest_ally with no living ally -> %v, want nil", got)
	}
	// An invisible enemy is not a target the engine may aim at.
	sc.enemy.addState(stateInvisible, 3)
	sc.weak.addState(stateInvisible, 3)
	if got := sc.f.gambitResolveTarget(sc.self, gambitTargetWeakestEnemy); got != nil {
		t.Errorf("weakest_enemy with every enemy invisible -> %v, want nil", got)
	}
	if got := sc.f.gambitResolveTarget(sc.self, gambitTarget("the_healer")); got != nil {
		t.Errorf("an unknown target spec resolved to %v, want nil", got)
	}
}

// TestGambitFirstMatchWinsByRuleOrder is the priority guarantee: with two rules
// that both hold, the EARLIER one acts and the later one does not. Checked in
// both orders, so an engine that walked the list backwards (or sorted it)
// cannot pass.
func TestGambitFirstMatchWinsByRuleOrder(t *testing.T) {
	const passFirst = `{"if":{"kind":"always"},"do":{"kind":"pass"}},
	                   {"if":{"kind":"always"},"do":{"kind":"cast","spell":38,"target":"nearest_enemy"}}`
	const castFirst = `{"if":{"kind":"always"},"do":{"kind":"cast","spell":38,"target":"nearest_enemy"}},
	                   {"if":{"kind":"always"},"do":{"kind":"pass"}}`

	t.Run("pass listed first wins", func(t *testing.T) {
		sc := newGambitScene(t)
		sc.rules(t, sc.self, passFirst)
		sc.runTurn(t, sc.self)

		if sc.enemy.HP != sc.enemy.MaxHP {
			t.Errorf("enemy HP %d/%d: the lower-priority cast rule acted",
				sc.enemy.HP, sc.enemy.MaxHP)
		}
		if sc.self.AP != sc.self.MaxAP {
			t.Errorf("AP = %d, want %d spent on nothing (the pass won)", sc.self.AP, sc.self.MaxAP)
		}
		got := sc.behaviorDetails()
		if len(got) != 1 || !strings.Contains(got[0], "rule=1") || !strings.Contains(got[0], "do=pass") {
			t.Errorf("behaviour rows = %v, want exactly one naming rule 1's pass", got)
		}
	})

	t.Run("cast listed first wins", func(t *testing.T) {
		sc := newGambitScene(t)
		sc.rules(t, sc.self, castFirst)
		sc.runTurn(t, sc.self)

		if sc.enemy.HP >= sc.enemy.MaxHP {
			t.Errorf("enemy HP %d/%d: rule 1's cast did not act", sc.enemy.HP, sc.enemy.MaxHP)
		}
		// Rule 1 is the one that opens the turn; the pass below it only gets a
		// look once the casts have spent the AP.
		got := sc.behaviorDetails()
		if len(got) == 0 || !strings.Contains(got[0], "rule=1") || !strings.Contains(got[0], "do=cast:38") {
			t.Fatalf("behaviour rows = %v, want rule 1's cast first", got)
		}
		if len(sc.castDetails()) == 0 {
			t.Error("no cast row: the higher-priority cast rule never acted")
		}
	})
}

// TestGambitCastGoesThroughRealSpellValidation is the "over real spell data"
// requirement: a rule naming a real spell id must be validated exactly as a
// normal cast is, and must fall back cleanly when that validation says no.
//
// Every sub-case uses the same rule list — a cast rule followed by a
// close-combat rule — so what changes between them is only whether the real
// spell is castable this turn.
func TestGambitCastGoesThroughRealSpellValidation(t *testing.T) {
	castThen := func(spell int32) string {
		return fmt.Sprintf(`{"if":{"kind":"always"},"do":{"kind":"cast","spell":%d,"target":"nearest_enemy"}},
		                     {"if":{"kind":"always"},"do":{"kind":"close_combat"}}`, spell)
	}

	t.Run("in range and affordable: it casts", func(t *testing.T) {
		sc := newGambitScene(t)
		sc.rules(t, sc.self, castThen(realSpellStrong))
		sc.runTurn(t, sc.self)

		if sc.enemy.HP >= sc.enemy.MaxHP {
			t.Fatalf("enemy HP %d/%d: the rule's real-spell cast never landed",
				sc.enemy.HP, sc.enemy.MaxHP)
		}
		casts := sc.castDetails()
		if len(casts) == 0 {
			t.Fatal("no cast row in the decision log")
		}
		want := fmt.Sprintf("spell=%d", realSpellStrong)
		if !strings.Contains(casts[0], want) {
			t.Errorf("cast row %q does not name %s", casts[0], want)
		}
		// It must be the RULE that cast it, not the archetype happening to pick
		// the same spell: the plan row says which.
		if got := sc.behaviorDetails(); len(got) == 0 || !strings.Contains(got[0], "gambit rule=1") {
			t.Errorf("behaviour rows = %v, want rule 1 to have ordered the cast", got)
		}
	})

	t.Run("out of range: the rule falls through", func(t *testing.T) {
		sc := newGambitScene(t)
		// 148 reaches 1-2 cells; the nearest enemy is 4 away.
		sc.rules(t, sc.self, castThen(realSpellCooldown))
		sc.self.MP = 0 // pin it in place so nothing can close the gap
		sc.runTurn(t, sc.self)

		for _, d := range sc.castDetails() {
			if strings.Contains(d, fmt.Sprintf("spell=%d", realSpellCooldown)) {
				t.Errorf("cast row %q: a spell with range 1-2 reached 4 cells", d)
			}
		}
		// Falling back is the point: the archetype picks a spell that DOES reach,
		// so the turn is still played.
		if got := sc.behaviorDetails(); len(got) == 0 || got[len(got)-1] != "aggressive" {
			t.Errorf("behaviour rows = %v, want the archetype (aggressive) to have taken the turn", got)
		}
		if sc.enemy.HP >= sc.enemy.MaxHP {
			t.Errorf("enemy HP %d/%d: the archetype fallback did not act either",
				sc.enemy.HP, sc.enemy.MaxHP)
		}
	})

	t.Run("on cooldown: the rule falls through", func(t *testing.T) {
		sc := newGambitScene(t)
		sp := sc.f.deps.Spells.Get(realSpellCooldown)
		if sp == nil || sp.Cooldown == 0 {
			t.Fatalf("spell %d is no longer a cooldown spell in the shipped data", realSpellCooldown)
		}
		// Walk into its range, then burn its cooldown the way a cast would.
		sc.self.Pos = Pos{X: 10, Y: 15} // 1 cell from ENEMY
		sc.self.MP = 0
		sc.self.CastHistory.storeCast(sp.LimitKeyID(), sp.EffectiveCooldown(), sp.CastMaxPerTurn,
			sp.CastMaxPerTarget, sc.f.tableTurn, sc.enemy.WireID, true)

		sc.rules(t, sc.self, castThen(realSpellCooldown))
		sc.runTurn(t, sc.self)

		for _, d := range sc.castDetails() {
			if strings.Contains(d, fmt.Sprintf("spell=%d", realSpellCooldown)) {
				t.Errorf("cast row %q: a spell on cooldown was cast by a rule", d)
			}
		}
		// The second rule can act from here, and its row proves the walk
		// continued past the rule it could not use.
		if got := sc.behaviorDetails(); len(got) == 0 || !strings.Contains(got[0], "do=close_combat") {
			t.Errorf("behaviour rows = %v, want rule 2 (close_combat) to have acted", got)
		}
	})

	t.Run("unaffordable: the rule falls through", func(t *testing.T) {
		sc := newGambitScene(t)
		sc.self.AP = 3 // 75 costs 4
		sc.self.MP = 0
		sc.rules(t, sc.self, castThen(realSpellStrong))
		sc.runTurn(t, sc.self)

		for _, d := range sc.castDetails() {
			if strings.Contains(d, fmt.Sprintf("spell=%d", realSpellStrong)) {
				t.Errorf("cast row %q: a 4 AP spell was cast on 3 AP", d)
			}
		}
	})

	t.Run("a spell the fighter does not know: the rule falls through", func(t *testing.T) {
		sc := newGambitScene(t)
		if fighterKnowsSpell(sc.self, realSpellUnknown) {
			t.Fatalf("test fighter unexpectedly knows spell %d", realSpellUnknown)
		}
		sc.rules(t, sc.self, castThen(realSpellUnknown))
		sc.self.MP = 0
		sc.runTurn(t, sc.self)

		for _, d := range sc.castDetails() {
			if strings.Contains(d, fmt.Sprintf("spell=%d", realSpellUnknown)) {
				t.Errorf("cast row %q: a rule cast a spell outside the loadout", d)
			}
		}
	})

	t.Run("no line of sight: the rule falls through", func(t *testing.T) {
		sc := newGambitScene(t)
		sp := sc.f.deps.Spells.Get(realSpellCheap)
		if sp == nil || !sp.TestLoS {
			t.Fatalf("spell %d no longer needs line of sight in the shipped data", realSpellCheap)
		}
		// (7,18) is off the walkable band, so nothing can see it; aim the rule at
		// an enemy standing where the fighter cannot shoot.
		sc.enemy.Pos = Pos{X: 6, Y: 11}
		sc.weak.Pos = Pos{X: 6, Y: 12}
		sc.self.Pos = Pos{X: 6, Y: 16}
		sc.self.MP = 0
		if sc.f.Arena().hasLineOfSight(sc.self.Pos, sc.enemy.Pos) {
			t.Skip("the practice arena has line of sight between these cells; nothing to prove here")
		}
		sc.rules(t, sc.self, castThen(realSpellCheap))
		sc.runTurn(t, sc.self)

		if sc.enemy.HP != sc.enemy.MaxHP {
			t.Errorf("enemy HP %d/%d: a rule cast through a wall", sc.enemy.HP, sc.enemy.MaxHP)
		}
	})
}

// TestGambitCastKeepsTheFriendlyFireAndSupportGates: a rule is an instruction,
// not an exemption. The gates that stop the archetype AI nuking its own team
// and healing its enemies apply to a rule-driven cast too — otherwise a ghost's
// owner could author what the AI is specifically prevented from doing.
func TestGambitCastKeepsTheFriendlyFireAndSupportGates(t *testing.T) {
	t.Run("a harmful spell is never aimed at an ally", func(t *testing.T) {
		sc := newGambitScene(t)
		sc.ally.HP = 100
		sc.self.MP = 0
		sc.rules(t, sc.self, `{"if":{"kind":"always"},"do":{"kind":"cast","spell":38,"target":"weakest_ally"}}`)
		sc.runTurn(t, sc.self)

		// The rule is refused, so the archetype plays the turn — and the archetype
		// may legitimately HEAL this ally (ai_support.go). What must never appear
		// is a damage spell aimed at the ally's cell.
		if sc.ally.HP < 100 {
			t.Errorf("ally HP = %d, want 100 or more: a rule landed a damage spell on its own side", sc.ally.HP)
		}
		atAlly := fmt.Sprintf("spell=38 target=(%d,%d)", sc.ally.Pos.X, sc.ally.Pos.Y)
		for _, d := range sc.castDetails() {
			if strings.Contains(d, atAlly) {
				t.Errorf("cast row %q aimed a damage spell at the fighter's own ally", d)
			}
		}
	})

	t.Run("a heal is never aimed at an enemy", func(t *testing.T) {
		sc := newGambitScene(t)
		sc.enemy.HP = 100
		// Stand 3 cells away, INSIDE 133's range, so nothing but the engine's own
		// gate can be what stops the cast.
		sc.self.Pos = Pos{X: 8, Y: 15}
		sc.self.MP = 0
		sc.rules(t, sc.self, `{"if":{"kind":"always"},"do":{"kind":"cast","spell":133,"target":"nearest_enemy"}}`)
		sc.runTurn(t, sc.self)

		atEnemy := fmt.Sprintf("spell=133 target=(%d,%d)", sc.enemy.Pos.X, sc.enemy.Pos.Y)
		for _, d := range sc.castDetails() {
			if strings.Contains(d, atEnemy) {
				t.Errorf("cast row %q: a rule aimed a heal at an opponent", d)
			}
		}
		if sc.enemy.HP > 100 {
			t.Errorf("enemy HP = %d, want 100 or less: a rule healed an opponent", sc.enemy.HP)
		}
	})

	t.Run("a heal aimed at an ally does cast", func(t *testing.T) {
		sc := newGambitScene(t)
		sc.ally.HP = 100
		sc.ally.Pos = Pos{X: 8, Y: 15} // inside 133's range 0-3, with line of sight
		sc.self.MP = 0
		sc.rules(t, sc.self, `{"if":{"kind":"ally_hp_pct_below","value":60},"do":{"kind":"cast","spell":133,"target":"weakest_ally"}}`)
		sc.runTurn(t, sc.self)

		if sc.ally.HP <= 100 {
			t.Errorf("ally HP = %d, want more than 100: the support rule never cast", sc.ally.HP)
		}
		// The archetype's own support cast would heal the same ally, so the plan
		// row is what proves the RULE did it.
		if got := sc.behaviorDetails(); len(got) == 0 || !strings.Contains(got[0], "gambit rule=1") {
			t.Errorf("behaviour rows = %v, want rule 1 to have ordered the heal", got)
		}
	})

	// The design doc's own example rule names spell 51, which in the real data
	// is a SUMMON — it harms nobody, so it cannot be aimed at an enemy. The
	// engine must decline and fall back rather than cast it because a document
	// said so.
	t.Run("the doc's example spell is not castable at an enemy", func(t *testing.T) {
		sc := newGambitScene(t)
		sp := sc.f.deps.Spells.Get(realSpellSummon)
		if sp == nil {
			t.Fatalf("spell %d missing from the shipped data", realSpellSummon)
		}
		if aiSpellHarmsEnemy(sp) {
			t.Skipf("spell %d now harms enemies in the shipped data", realSpellSummon)
		}
		sc.self.Pos = Pos{X: 10, Y: 15} // adjacent: 51 has range 1-1
		sc.self.MP = 0
		sc.rules(t, sc.self, fmt.Sprintf(
			`{"if":{"kind":"enemy_hp_pct_below","value":100},"do":{"kind":"cast","spell":%d,"target":"weakest_enemy"}}`,
			realSpellSummon))
		sc.runTurn(t, sc.self)

		for _, d := range sc.castDetails() {
			if strings.Contains(d, fmt.Sprintf("spell=%d", realSpellSummon)) {
				t.Errorf("cast row %q: a non-harmful spell was fired at an enemy", d)
			}
		}
		if got := sc.behaviorDetails(); len(got) == 0 || got[len(got)-1] != "aggressive" {
			t.Errorf("behaviour rows = %v, want the archetype to have taken the turn", got)
		}
	})
}

// TestGambitNoRuleFiresArchetypeDrivesTheTurn is the fallback the whole design
// rests on: when nothing in the list can act, the turn is played by classifyAI
// exactly as it was before gambits existed — the fighter does NOT stand there.
func TestGambitNoRuleFiresArchetypeDrivesTheTurn(t *testing.T) {
	sc := newGambitScene(t)
	// Neither rule can ever act here: 22 is not in the loadout, and nothing is
	// adjacent. Both are deliberately non-movement rules, so the archetype is
	// the only thing that can move this fighter.
	sc.rules(t, sc.self, `{"if":{"kind":"always"},"do":{"kind":"cast","spell":22,"target":"self"}},
	                      {"if":{"kind":"always"},"do":{"kind":"close_combat"}}`)
	before := sc.self.Pos
	sc.runTurn(t, sc.self)

	behaviors := sc.behaviorDetails()
	if len(behaviors) != 1 || behaviors[0] != "aggressive" {
		t.Fatalf("behaviour rows = %v, want exactly one archetype row (aggressive)", behaviors)
	}
	for _, d := range behaviors {
		if strings.Contains(d, "gambit") {
			t.Errorf("behaviour row %q: a rule was recorded as fired when none could act", d)
		}
	}
	// And the archetype really played: it closed distance and/or cast.
	acted := sc.self.Pos != before || len(sc.castDetails()) > 0
	if !acted {
		t.Error("the fighter neither moved nor cast; the archetype fallback did not run")
	}
}

// TestGambitUnknownKindFallsBackInsteadOfActing covers a ruleset that reached
// the engine WITHOUT going through the parser (a future caller's bug, a
// hand-built struct). An unrecognised kind must read as "does not apply" — the
// engine falls back, it never guesses, and it never panics.
func TestGambitUnknownKindFallsBackInsteadOfActing(t *testing.T) {
	sc := newGambitScene(t)
	sc.self.Gambits = &gambitRuleSet{
		Version: gambitSchemaVersion,
		Rules: []gambitRule{
			{If: gambitCondition{Kind: "enemy_is_ugly", Value: 1}, Do: gambitAction{Kind: gambitPass}},
			{If: gambitCondition{Kind: gambitAlways}, Do: gambitAction{Kind: "flee"}},
		},
	}
	// The same ruleset must also be refused by validation, which is what keeps it
	// from ever arriving this way through the real intake path.
	if err := sc.self.Gambits.validate(); err == nil {
		t.Error("validate() accepted unknown condition/action kinds")
	}

	if fired := sc.f.gambitTurn(sc.self); fired {
		t.Error("gambitTurn reported a rule fired from unknown kinds")
	}
	sc.runTurn(t, sc.self)

	if got := sc.behaviorDetails(); len(got) != 1 || got[0] != "aggressive" {
		t.Errorf("behaviour rows = %v, want the archetype to have played the turn", got)
	}
}

// TestGambitFiredRuleLandsInTheDecisionLog: phase 1's decision log is how a
// replay explains a fight. A fired rule must occupy the same slot the archetype
// name occupies, identified well enough to find it in the author's list.
func TestGambitFiredRuleLandsInTheDecisionLog(t *testing.T) {
	sc := newGambitScene(t)
	sc.enemy.HP = 60 // 30% of 200: the first rule's condition holds
	sc.rules(t, sc.self, `{"if":{"kind":"enemy_hp_pct_below","value":40},"do":{"kind":"cast","spell":38,"target":"weakest_enemy"}},
	                      {"if":{"kind":"always"},"do":{"kind":"pass"}}`)
	sc.runTurn(t, sc.self)

	log := sc.f.decisionLog()
	if len(log) == 0 {
		t.Fatal("empty decision log after a gambit turn")
	}
	first := log[0]
	if first.Kind != decisionBehavior {
		t.Fatalf("first row = %s, want the behaviour (plan) row", first)
	}
	want := "gambit rule=1 if=enemy_hp_pct_below:40 do=cast:38@weakest_enemy"
	if first.Detail != want {
		t.Errorf("first row detail = %q, want %q", first.Detail, want)
	}
	if first.WireID != sc.self.WireID || first.Round != 1 {
		t.Errorf("first row = %s, want wire %d on round 1", first, sc.self.WireID)
	}
	if !first.AI {
		t.Error("the fired-rule row is not marked AI-driven")
	}
	// The cast it ordered is logged under it, so a replay reads the rule and then
	// what it did.
	if len(log) < 2 || log[1].Kind != decisionCast {
		t.Fatalf("row 2 = %v, want the cast the rule ordered", log[1:])
	}
	if !strings.Contains(log[1].Detail, "spell=38") {
		t.Errorf("cast row %q does not name spell 38", log[1].Detail)
	}
}

// TestGambitMovementAndPassActions covers the three non-cast actions that
// change state, including the no-op case that must NOT consume the turn.
func TestGambitMovementAndPassActions(t *testing.T) {
	t.Run("move_toward closes distance", func(t *testing.T) {
		sc := newGambitScene(t)
		sc.rules(t, sc.self, `{"if":{"kind":"always"},"do":{"kind":"move_toward"}},
		                      {"if":{"kind":"always"},"do":{"kind":"pass"}}`)
		before := manhattanDist(sc.self.Pos, sc.enemy.Pos)
		sc.runTurn(t, sc.self)
		if after := manhattanDist(sc.self.Pos, sc.enemy.Pos); after >= before {
			t.Errorf("distance %d -> %d, want the move_toward rule to have closed it", before, after)
		}
	})

	t.Run("move_away breaks contact", func(t *testing.T) {
		sc := newGambitScene(t)
		sc.self.Pos = Pos{X: 10, Y: 15} // adjacent to ENEMY
		sc.rules(t, sc.self, `{"if":{"kind":"nearest_enemy_distance_le","value":1},"do":{"kind":"move_away"}},
		                      {"if":{"kind":"always"},"do":{"kind":"pass"}}`)
		sc.runTurn(t, sc.self)
		if got := manhattanDist(sc.self.Pos, sc.enemy.Pos); got <= 1 {
			t.Errorf("distance to the enemy = %d, want more than 1 after move_away", got)
		}
	})

	t.Run("close_combat hits an adjacent enemy", func(t *testing.T) {
		sc := newGambitScene(t)
		sc.self.Pos = Pos{X: 10, Y: 15}
		sc.self.MP = 0
		sc.rules(t, sc.self, `{"if":{"kind":"always"},"do":{"kind":"close_combat"}}`)
		sc.runTurn(t, sc.self)

		if sc.enemy.HP >= sc.enemy.MaxHP {
			t.Errorf("enemy HP %d/%d: the close_combat rule did not land", sc.enemy.HP, sc.enemy.MaxHP)
		}
		if sc.self.AP >= sc.self.MaxAP {
			t.Errorf("AP = %d, want some spent on weapon attacks", sc.self.AP)
		}
	})

	t.Run("a rule that changes nothing does not consume the turn", func(t *testing.T) {
		sc := newGambitScene(t)
		// Already adjacent, so moveTowardNearestOpponent finds nothing better:
		// the rule is ready but achieves nothing, and the turn must still get
		// played — by the next rule, or failing that by the archetype.
		sc.self.Pos = Pos{X: 10, Y: 15}
		sc.rules(t, sc.self, `{"if":{"kind":"always"},"do":{"kind":"move_toward"}}`)
		sc.runTurn(t, sc.self)

		behaviors := sc.behaviorDetails()
		if len(behaviors) < 2 || !strings.Contains(behaviors[0], "do=move_toward") {
			t.Fatalf("behaviour rows = %v, want the chosen rule then the archetype", behaviors)
		}
		if behaviors[len(behaviors)-1] != "aggressive" {
			t.Errorf("behaviour rows = %v, want the archetype to have played the turn", behaviors)
		}
	})
}

// TestGambitStepBudgetIsBounded: a crafted rule list must not be able to spin a
// turn forever. The budget is AP+MP+2 because every acting rule spends AP or
// MP, with a hard ceiling for the case that does not (a cast that gives AP
// back).
func TestGambitStepBudgetIsBounded(t *testing.T) {
	cases := []struct {
		name          string
		ap, mp, maxAP int32
		maxMP         int32
		want          int
	}{
		{"typical fighter", 6, 3, 6, 3, 11},
		{"spent fighter keeps its maximum", 0, 0, 6, 3, 11},
		{"no resources at all still allows a pass", 0, 0, 0, 0, 2},
		{"absurd AP is capped", 10000, 10000, 10000, 10000, maxGambitStepsPerTurn},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			ff := &FightFighter{AP: c.ap, MP: c.mp, MaxAP: c.maxAP, MaxMP: c.maxMP}
			if got := gambitStepBudget(ff); got != c.want {
				t.Errorf("gambitStepBudget = %d, want %d", got, c.want)
			}
		})
	}
	if got := gambitStepBudget(nil); got != 0 {
		t.Errorf("gambitStepBudget(nil) = %d, want 0", got)
	}
}

// gambitDeterminismFight is the 2v2 of the scene above with the SAME ruleset on
// every fighter and the dice switched back on, so a run exercises crit and
// fumble rolls as well as rule evaluation.
func gambitDeterminismFight(t *testing.T, seed int64) *Fight {
	t.Helper()
	sc := newGambitScene(t)
	sc.f.SetSeed(seed)
	for _, ff := range sc.f.allFighters() {
		ff.HP, ff.MaxHP = 600, 600
		ff.CritRate, ff.FumbleRate = 25, 15
		sc.rules(t, ff, `{"if":{"kind":"enemy_hp_pct_below","value":50},"do":{"kind":"cast","spell":75,"target":"weakest_enemy"}},
		                 {"if":{"kind":"nearest_enemy_distance_le","value":4},"do":{"kind":"cast","spell":38,"target":"nearest_enemy"}},
		                 {"if":{"kind":"turn_ge","value":3},"do":{"kind":"close_combat"}},
		                 {"if":{"kind":"always"},"do":{"kind":"move_toward"}}`)
	}
	return sc.f
}

// TestGambitFightIsDeterministic: phase 1's guarantee must survive the engine.
// Rule evaluation reads state and walks slices, so the same seed plus the same
// rules has to replay the same fight — otherwise a ghost fight cannot be
// verified or replayed, which is the whole reason the seed exists.
func TestGambitFightIsDeterministic(t *testing.T) {
	const seed int64 = 13371337
	const turns = 20

	first := gambitDeterminismFight(t, seed)
	runDeterminismFight(first, turns)
	want := determinismDigest(first)

	for i := 0; i < 5; i++ {
		f := gambitDeterminismFight(t, seed)
		runDeterminismFight(f, turns)
		if got := determinismDigest(f); got != want {
			t.Fatalf("run %d diverged on seed %d\n--- want ---\n%s\n--- got ---\n%s", i, seed, want, got)
		}
	}

	// Guard against the comparison proving nothing: rules must actually have
	// driven the turns, and damage must actually have been dealt.
	rules, dealt := 0, int32(0)
	for _, d := range first.decisionLog() {
		if d.Kind == decisionBehavior && strings.Contains(d.Detail, "gambit rule=") {
			rules++
		}
	}
	for _, ff := range first.allFighters() {
		dealt += ff.MaxHP - ff.HP
	}
	if rules == 0 {
		t.Fatal("no gambit rule fired over 20 turns; the determinism comparison proves nothing")
	}
	if dealt == 0 {
		t.Fatal("no damage was dealt over 20 turns; the dice are not being exercised")
	}

	// A different seed must still produce a different fight, so the digest is
	// not simply insensitive to everything.
	digests := map[string]bool{}
	for _, s := range []int64{1, 2, 3, 5, 8, 13} {
		f := gambitDeterminismFight(t, s)
		runDeterminismFight(f, turns)
		digests[determinismDigest(f)] = true
	}
	if len(digests) < 2 {
		t.Errorf("6 seeds produced %d distinct fights; the dice are not reaching the gambit turn", len(digests))
	}
}

// TestGambitRulesLeaveFightersWithoutRulesAlone: the engine is opt-in. A
// fighter with nil Gambits — every fighter in every fight today — must take the
// archetype turn it always took, and a fighter WITH rules must not change its
// neighbour's turn.
func TestGambitRulesLeaveFightersWithoutRulesAlone(t *testing.T) {
	sc := newGambitScene(t)
	sc.rules(t, sc.self, `{"if":{"kind":"always"},"do":{"kind":"pass"}}`)
	if sc.enemy.Gambits != nil {
		t.Fatal("scene gave the enemy rules")
	}

	if fired := sc.f.gambitTurn(sc.enemy); fired {
		t.Error("gambitTurn fired for a fighter with no ruleset")
	}

	// Play SELF's rule-driven turn, then the next fighter's: the one without
	// rules gets an archetype row.
	sc.runTurn(t, sc.self)
	cur := sc.f.currentFighter()
	if cur == nil || cur.Gambits != nil {
		t.Fatalf("next fighter = %v, want one without rules", cur)
	}
	sc.runTurn(t, cur)

	var found bool
	for _, d := range sc.f.decisionLog() {
		if d.Kind == decisionBehavior && d.WireID == cur.WireID {
			if strings.Contains(d.Detail, "gambit") {
				t.Errorf("fighter %d without rules logged %q", cur.WireID, d.Detail)
			}
			found = true
		}
	}
	if !found {
		t.Errorf("no behaviour row for the rule-less fighter %d", cur.WireID)
	}
}
