package gamedata

// conditions.go decodes FIGHTER CONDITIONS (record type 902, client class
// `ahm_1` → runtime `aiz_2`).
//
// A "condition" is a persistent status a fighter carries BETWEEN fights: the
// wound layer (a broken leg, a serious head wound), the blessings a coach card
// can grant ("Agile", "Invincible"), and the curses ("Fatigué", "Alité").
// They are the missing half of the coach META layer — the part that makes a
// fight leave a mark.
//
// Each record carries EITHER meta effects OR in-fight effects, never both
// (verified across all 111 shipped records):
//
//   - Meta effects (`akw_0`, the AI enum) act on the post-fight report — e.g. a
//     head wound is "AI 1: -10% XP".
//   - In-fight effects (`Ht`, the same structure spells use) act on the fighter's
//     characteristics for the whole fight — e.g. a leg wound is "action 123:
//     -20% dodge". Every shipped row has ContainerType "FIGHTER_CONDITION" and an
//     infinite duration, i.e. it lasts the entire fight.
//
// `Type` is a mutual-exclusion class, not a category label: a fighter may hold
// only one condition per type (see the apply rules in game/conditions.go). The
// wound types are laid out so that a SERIOUS wound is exactly `light + 10`, which
// is what lets the wound roller upgrade a light wound in place.

// Wound type ranges (aiz_2.ayT / ayU). Body parts in order: leg, arm, head,
// torso, other.
const (
	condTypeLightFirst   = 1
	condTypeLightLast    = 5
	condTypeSeriousFirst = 11
	condTypeSeriousLast  = 15
	// condSeriousOffset turns a light wound type into its serious counterpart.
	condSeriousOffset = 10
)

// DurationPermanent is the `grade` value meaning "never expires" — the value
// every wound carries. A wound only goes away by being healed.
const DurationPermanent int8 = -1

// Condition is one decoded fighter-condition definition.
type Condition struct {
	ID int16
	// Duration is the client's `grade` (aiz_2.ayW): how many fights the condition
	// lasts by default. -1 = permanent. A coach card that applies this condition
	// may override it (217 of 220 such card effects just repeat this value).
	Duration int8
	// Type is the mutual-exclusion class. 1..5 light wounds, 11..15 serious
	// wounds (light+10), 20 blessings, 21 ailments (the ONLY stacking type),
	// 40/50/60..63 meta grants, 70 pet-style permanent grants.
	Type int16
	// MetaEffects are `akw_0` entries (AI enum) applied to the post-fight report.
	MetaEffects []CardSetEffect
	// FightEffects are `Ht` rows applied to the fighter's characteristics for the
	// duration of a fight.
	FightEffects []Effect
}

// IsLightWound reports aiz_2.ayT(): types 1..5.
func (c *Condition) IsLightWound() bool {
	return c != nil && c.Type >= condTypeLightFirst && c.Type <= condTypeLightLast
}

// IsSeriousWound reports aiz_2.ayU(): types 11..15.
func (c *Condition) IsSeriousWound() bool {
	return c != nil && c.Type >= condTypeSeriousFirst && c.Type <= condTypeSeriousLast
}

// IsWound reports whether this is any wound (light or serious).
func (c *Condition) IsWound() bool { return c.IsLightWound() || c.IsSeriousWound() }

// SeriousTypeOf maps a light wound type to its serious counterpart (leg 1 → 11).
func SeriousTypeOf(lightType int16) int16 { return lightType + condSeriousOffset }

// LightTypeOf maps a serious wound type back to its body part (leg 11 → 1).
func LightTypeOf(seriousType int16) int16 { return seriousType - condSeriousOffset }

// BodyPartOf returns the body-part type (1..5) of any wound, light or serious.
func (c *Condition) BodyPartOf() int16 {
	switch {
	case c.IsLightWound():
		return c.Type
	case c.IsSeriousWound():
		return LightTypeOf(c.Type)
	}
	return 0
}

// WoundBodyParts is the number of distinct body parts a fighter can wound.
const WoundBodyParts = condTypeLightLast - condTypeLightFirst + 1

// Conditions holds every condition definition, indexed by id and by type.
type Conditions struct {
	byID   map[int16]*Condition
	byType map[int16][]*Condition
	ids    []int16
}

// NewConditions builds a catalog from explicit definitions (tests/tooling).
func NewConditions(defs ...*Condition) *Conditions {
	out := &Conditions{byID: make(map[int16]*Condition, len(defs))}
	for _, d := range defs {
		if d != nil {
			out.byID[d.ID] = d
		}
	}
	out.reindex()
	return out
}

func (c *Conditions) reindex() {
	c.ids = make([]int16, 0, len(c.byID))
	c.byType = make(map[int16][]*Condition, len(c.byID))
	for id, cond := range c.byID {
		c.ids = append(c.ids, id)
		c.byType[cond.Type] = append(c.byType[cond.Type], cond)
	}
	// Ascending id everywhere, so selection from these slices is deterministic
	// (the wound roller picks from them with the fight's own RNG).
	for t := range c.byType {
		byType := c.byType[t]
		for i := 1; i < len(byType); i++ {
			for j := i; j > 0 && byType[j].ID < byType[j-1].ID; j-- {
				byType[j], byType[j-1] = byType[j-1], byType[j]
			}
		}
	}
	for i := 1; i < len(c.ids); i++ {
		for j := i; j > 0 && c.ids[j] < c.ids[j-1]; j-- {
			c.ids[j], c.ids[j-1] = c.ids[j-1], c.ids[j]
		}
	}
}

// Get returns a condition by id, or nil.
func (c *Conditions) Get(id int16) *Condition {
	if c == nil {
		return nil
	}
	return c.byID[id]
}

// OfType returns every condition of a mutual-exclusion class, ascending by id.
func (c *Conditions) OfType(t int16) []*Condition {
	if c == nil {
		return nil
	}
	return c.byType[t]
}

// IDs returns every condition id, ascending.
func (c *Conditions) IDs() []int16 {
	if c == nil {
		return nil
	}
	return c.ids
}

// Len is the number of decoded conditions.
func (c *Conditions) Len() int {
	if c == nil {
		return 0
	}
	return len(c.byID)
}
