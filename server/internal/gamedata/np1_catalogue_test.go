package gamedata

import (
	"testing"
)

// TestNp1RuleCatalogueShape pins the interpretation of the `np_1` rule types that
// blocked "enforce the remaining np_1 rules" for a long time.
//
// The client splits np_1 into TWO namespaces, and the enum ajr_2 names them:
//
//	1-32     the RULES        "Modifie le budget", "Sort interdit", "Choisir une arene"
//	900-930  the PARAMETERS   every one literally "Parametre de ..." - de classe,
//	                          d'id d'arene, de nombre de combattant, de temps, ...
//	1000     "Aucune limite sur ce combat"
//
// A rule declares how many operands it needs (np_1.T()); a parameter carries a
// typed value and needs none (aIE, the only subclass with sp() == true).
// np_1.b(a, b) CONCATENATES a rule's params with the following entry's until the
// rule has T() of them, and je_2.a(np_1[]) walks the array accumulating exactly
// that way before applying. jk_1 - which registers itself as
// "coachCardFightParametersManager" - pairs each under-parameterised rule with
// every compatible parameter to build the selectable combinations.
//
// So the 13 rule entries sitting on coach cards with EMPTY parameter arrays are a
// CATALOGUE for building a custom ruleset, not rules to enforce as shipped. That
// is why hunting for their missing operands never found any: the operands live in
// the 900-930 pool and are attached when a ruleset is composed.
//
// This test fails the moment that shape changes - i.e. the moment the catalogue
// reading stops being true and the question deserves re-opening.
func TestNp1RuleCatalogueShape(t *testing.T) {
	st, err := openContent(t)
	if err != nil {
		t.Fatal(err)
	}
	cards, err := st.LoadCards()
	if err != nil {
		t.Fatal(err)
	}

	rules := map[int32]int{} // type -> instances
	rulesWithArgs := map[int32]int{}
	params := map[int32]int{} // type -> instances
	paramsNoValue := 0
	for _, c := range cards.All() {
		for _, p := range c.Parameters {
			switch {
			case p.Type >= ParamTypeArgClass && p.Type <= ParamTypeArgZobalSpell:
				params[p.Type]++
				if len(p.Params) == 0 {
					paramsNoValue++
				}
			case p.Type >= 1 && p.Type <= 32:
				rules[p.Type]++
				if len(p.Params) > 0 {
					rulesWithArgs[p.Type]++
				}
			}
		}
	}

	// The PARAMETER pool must exist and every entry must carry its value —
	// that is what makes it an operand pool rather than more templates.
	if len(params) == 0 {
		t.Fatal("no 900-930 parameter entries decoded — either the decode broke or " +
			"the catalogue model is wrong; re-read ajr_2 and jk_1 before trusting it")
	}
	if paramsNoValue != 0 {
		t.Errorf("%d parameter-pool entries carry NO value; the 900-930 block is "+
			"supposed to be the operand pool", paramsNoValue)
	}

	// The RULE entries must remain a catalogue: one per type, none parameterised.
	// If a rule ever ships WITH operands it is a real rule and must be enforced.
	for ty, n := range rules {
		if n != 1 {
			t.Errorf("rule type %d has %d instances, want exactly 1 (catalogue entry)", ty, n)
		}
		if rulesWithArgs[ty] != 0 {
			t.Errorf("rule type %d now ships WITH operands (%d of %d) — it is a real "+
				"rule, not a catalogue entry, and should be enforced", ty, rulesWithArgs[ty], n)
		}
	}
	t.Logf("catalogue: %d rule types (1 instance each, no operands), "+
		"%d parameter types (all carrying values)", len(rules), len(params))
}
