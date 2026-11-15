package gamedata

// parameters.go decodes `np_1` — the client's "gameplay parameter" element.
//
// It is a small polymorphic record carried by coach cards (field 19), and by
// parts of the challenge and tournament tables. Its element layout was the last
// unknown blocking those three records, which is why the coach-card decoder used
// to stop at field 18.
//
// Layout, from `np_1.k(ByteBuffer)` (and confirmed against its writer `cd()` and
// its size function `nj()`):
//
//	[i32 type][i32 id][i32 parentId][u8 n][i32 × n params][i16 effectVersion]
//	  if effectVersion != 0: [i32 effectId][Ht blob]
//
// `nj()` returns `13 + 4*len(params) + (effect != nil ? effect.nj()+2+4 : 2)`,
// which is exactly 4+4+4+1 for the header plus the trailing short — a useful
// cross-check that no field is missing.
//
// TWO TRAPS, both different from the effect lists elsewhere in this format:
//
//  1. The trailing effect is written **version first, then id** — the reverse of
//     the `[i32 id][i16 ver][i32 len]` framing `decodeEffectList` uses.
//  2. It has **no length prefix**: `Ht.a(buffer, id, ver)` consumes it inline. So
//     an `np_1` carrying an effect can only be skipped by fully parsing that
//     effect, and a decoder that guesses will silently desynchronise the rest of
//     the record. We therefore refuse to guess — see ParameterEffectUnsupported.

// ParamTypeVictoryCondition (14, "Condition de victoire") is the ONE np_1 type
// that overrides the element layout. Its class `wi_0` reads
//
//	[i32 id][i32 parentId][mp_2 blob]
//
// with no param array and no trailing effect. Decoding it with the generic
// layout reads the mp_2's leading bytes as a param count and desynchronises the
// rest of the record — which is exactly what happened to challenges 14 and
// 37..44 before this case existed.
const ParamTypeVictoryCondition int32 = 14

// VictoryCondition is the `mp_2` payload of a type-14 parameter:
//
//	[i16 type][i32 id][u8 n][i32 × n params][u8 isNecessary][i32 victoryPoints][u8 affectedTeam]
//
// (`mp_2.i` / `mp_2.cd`; its `nj()` = 7 + 4*len + 1 + 4 + 1 confirms the shape.)
//
// The three trailing scalars are named from the client's OWN column names: it
// carries a second constructor that hydrates the same object from a SQL row,
//
//	mp_2.a(rs.getShort("condition_type"), rs.getInt("condition_id"),
//	       rs.getArray("condition_parameters"), rs.getBoolean("condition_is_necessary"),
//	       rs.getInt("condition_victory_points"), rs.getByte("condition_affected_team"))
//
// and its argument order is the wire order, so each field's meaning is pinned by
// the retail schema rather than guessed.
//
// NONE of the three has a single caller in the client — `rh()`, `ri()` and
// `rj()` are pure accessors, exactly like the drop-table modifiers. Retail
// arbitrated victory conditions server-side; see game/victory.go.
type VictoryCondition struct {
	Type   int16
	ID     int32
	Params []int32
	// IsNecessary is `condition_is_necessary`. True on all 9 shipped conditions.
	IsNecessary bool
	// VictoryPoints is `condition_victory_points`, the score a non-necessary
	// condition contributes. 0 on all 9 shipped conditions.
	VictoryPoints int32
	// AffectedTeam is `condition_affected_team` — which side the condition wins
	// FOR. 0 on all 9 shipped conditions.
	AffectedTeam uint8
}

// Victory-condition subtypes: the client's `qk_1` enum, each with one concrete
// `mp_2` subclass whose one-line evaluator IS the semantics.
//
//	1 cy_1  "Posséder une position"                    a fighter of the team is
//	                                                   alive on cell (p[0], p[1])
//	2 fp_1  "Posséder un nombre de points de victoire"  team victory points >= p[0]
//	3 ct_1  "Tuer des combattants d'une classe"         >= p[1] (default 1) enemies
//	                                                   of breed p[0] are dead
//	4 ajm_0 "Atteindre un tour donné"                   fight.roundCounter > p[0]
//	1000    "Aucune condition sur ce combat"            no condition
//
// ONLY subtype 4 occurs in the shipped data (9 challenges); see game/victory.go
// for which of these the server evaluates and why.
const (
	VictoryHoldPosition int16 = 1
	VictoryPointsTotal  int16 = 2
	VictoryKillBreed    int16 = 3
	VictoryReachTurn    int16 = 4
	VictoryNoCondition  int16 = 1000
)

// VictoryConditions returns every type-14 victory condition in an np_1 list, in
// data order.
func VictoryConditions(ps []Parameter) []VictoryCondition {
	var out []VictoryCondition
	for _, p := range ps {
		if p.Type == ParamTypeVictoryCondition && p.Victory != nil {
			out = append(out, *p.Victory)
		}
	}
	return out
}

// FightStartEffects returns the inline effects carried by type-12 parameters
// ("Lance un effet sur tous les combattants à la création du combat").
func FightStartEffects(ps []Parameter) []Effect {
	var out []Effect
	for _, p := range ps {
		if p.Type == ParamTypeFightStartEffect && p.Effect != nil {
			out = append(out, *p.Effect)
		}
	}
	return out
}

// Parameter is one decoded `np_1` element.
type Parameter struct {
	// Type selects the concrete subclass (the client's `ajr_2` enum: Rx, wb_1,
	// qt_2 …). An unknown type still decodes — the client falls back to a generic
	// `aIE(type)` holder rather than failing — so this is data, not a tag we must
	// recognise.
	Type int32
	// ID and ParentID are the element's own id and the id it refines.
	ID       int32
	ParentID int32
	// Params are the element's operands (`JI`).
	Params []int32
	// EffectVersion is 0 when the element carries no trailing effect.
	EffectVersion int16
	// EffectID is meaningful only when EffectVersion != 0.
	EffectID int32
	// Victory is set only for ParamTypeVictoryCondition, whose element layout is
	// different (see that constant).
	Victory *VictoryCondition
	// Effect is the trailing inline `Ht` effect, present iff EffectVersion != 0.
	// Rule type 12 ("Lance un effet sur tous les combattants a la creation du
	// combat") is the shipped user.
	Effect *Effect
}

// HasEffect reports whether this element carries a trailing inline `Ht` effect.
func (p *Parameter) HasEffect() bool { return p.EffectVersion != 0 }

// Rule types from the client's `ajr_2` enum. Only the ones the server acts on
// are named; the full table is in docs/DATA-COVERAGE.md §5b.
const (
	ParamTypeBudget          int32 = 1  // "Modifie le budget"
	ParamTypeMinFighters     int32 = 2  // "Modifie le nombre minimum de combattant"
	ParamTypeMaxFighters     int32 = 3  // "Modifie le nombre maximum de combattant"
	ParamTypeTurnDurationMS  int32 = 10 // "Modifie la durée en milliseconde du tour de chaque combattant"
	ParamTypeSuddenDeathTurn int32 = 11 // "Modifie le tour du début de la mort subite"
	// ParamTypeFightStartEffect carries an inline `Ht` effect applied to every
	// fighter when the fight is created. Challenges 29/30/31 use it.
	ParamTypeFightStartEffect int32 = 12
	ParamTypeBonusCellMult    int32 = 13 // "Multiplie les effets des cases bonus"
	ParamTypeArena            int32 = 29 // "Choisir une arène"
	// ParamTypeNoBudgetLimit carries no parameters; its i18n label is the whole
	// rule ("content.54.1000 = Pas de limite de budget"). Challenge 12 uses it.
	ParamTypeNoBudgetLimit int32 = 1000
)

// The 900-930 block is a SECOND namespace: not rules, but the typed OPERANDS
// rules are composed with. Every one of them is literally named "Paramètre de …"
// in the client's `ajr_2` enum, and in the shipped data every single instance
// carries a value (245 of them), while the 13 rule types that appear on coach
// cards each appear exactly ONCE with an EMPTY parameter array.
//
// That is the answer to a question that blocked "enforce the remaining np_1
// rules" for a long time. The pieces:
//
//   - a rule declares how many operands it needs (`np_1.T()`);
//   - a parameter carries a value and needs none (`aIE`, the only subclass whose
//     `sp()` is true, with a DYNAMIC type id);
//   - `np_1.b(a, b)` CONCATENATES a's params with b's until `rg().length >= T()`;
//   - `je_2.a(np_1[])` walks the array accumulating exactly that way, applying a
//     rule the moment it has enough operands and then resetting;
//   - `jk_1` — which registers itself as "coachCardFightParametersManager" —
//     pairs each under-parameterised rule with every compatible parameter to
//     build the selectable combinations (`WN`, whose fields are "selected",
//     "description", "activated", "forbidden": a picker UI).
//
// So those empty-parameter rules are a CATALOGUE for composing a custom ruleset,
// not rules to enforce as shipped — which is why hunting for their missing
// operands never found any. Enforceable rules arrive already parameterised, from
// the challenge records (types 10/12/13/14). The counts read like a catalogue
// too: 14 class parameters (the 14 breeds), 10 spell parameters per breed (every
// breed has exactly 10 spells), 27 arena ids.
//
// Pinned by TestNp1RuleCatalogueShape, which fails if a rule ever ships WITH
// operands — i.e. the moment this reading stops being true.
const (
	ParamTypeArgClass      int32 = 900 // "Paramètre de classe"
	ParamTypeArgFecaSpell  int32 = 901 // "Paramètre de sort de Féca" (902-912 = the other breeds)
	ParamTypeArgLowBudget  int32 = 913 // "Paramètre de budget faible"
	ParamTypeArgSword      int32 = 914 // "Paramètre d'équipement épée" (915-923 = the other slots)
	ParamTypeArgHighBudget int32 = 924 // "Paramètre de budget élevé"
	ParamTypeArgGameTurn   int32 = 925 // "Paramètre de tour de jeu"
	ParamTypeArgTimeMS     int32 = 926 // "Paramètre de temps (en millisecondes)"
	ParamTypeArgArenaID    int32 = 927 // "Paramètre d'id d'arène"
	ParamTypeArgFighterNum int32 = 928 // "Paramètre de nombre de combattant"
	ParamTypeArgRogueSpell int32 = 929 // "Paramètre de sort de Roublard"
	ParamTypeArgZobalSpell int32 = 930 // "Paramètre de sort de Zobal" — last of the pool
)

// FirstParam returns params[0] of the first parameter of the given type, and
// whether one was present. Rules are single-valued in the shipped data, so
// "first wins" is the whole rule; a caller that needs to sum should iterate.
func FirstParam(ps []Parameter, typ int32) (int32, bool) {
	for _, p := range ps {
		if p.Type == typ && len(p.Params) > 0 {
			return p.Params[0], true
		}
	}
	return 0, false
}
