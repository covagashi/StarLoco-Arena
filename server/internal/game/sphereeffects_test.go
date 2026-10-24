package game

import (
	"path/filepath"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/store/storetest"
)

// sphereEffectBoards builds a board whose nodes carry the payloads under test:
// a stat bonus, a stat MALUS, a spell, and an equipment pool.
func sphereEffectBoards() *gamedata.SphereBoards {
	fx := func(action int32, param float32) []gamedata.Effect {
		return []gamedata.Effect{{ActionID: action, Params: []float32{param}}}
	}
	return gamedata.NewSphereBoards(
		[]*gamedata.SphereBoard{{ID: 21, Season: 1, Breed: 8, RootX: 1, RootY: 1}},
		[]*gamedata.Sphere{
			{ID: 100, BoardID: 21, X: 1, Y: 1, Effects: fx(13, 1)},  // +1 AP
			{ID: 101, BoardID: 21, X: 2, Y: 1, Effects: fx(11, 25)}, // +25 max HP
			{ID: 102, BoardID: 21, X: 3, Y: 1, Effects: fx(14, 1)},  // MALUS: -1 AP
			{ID: 103, BoardID: 21, X: 4, Y: 1, SpellID: 555},
			{ID: 104, BoardID: 21, X: 5, Y: 1, EquipmentPoolID: 9},
			{ID: 105, BoardID: 21, X: 6, Y: 1, SpellID: 555}, // the same spell again
		},
	)
}

func withSpheres(ids ...int32) *domain.Fighter {
	f := &domain.Fighter{ID: 1, BreedID: 8} // Iop: 75 HP, 6 AP, 3 MP
	for _, id := range ids {
		f.Spheres = append(f.Spheres, domain.FighterSphere{FighterID: 1, SphereID: id})
	}
	return f
}

// TestSpheresChangeFighterStatsInFight is the payoff: a bought node must actually
// change how the fighter plays, through the same accumulator equipped cards and
// wounds already use.
func TestSpheresChangeFighterStatsInFight(t *testing.T) {
	boards := sphereEffectBoards()

	base := computeFighterStatsWithConditions(withSpheres(), nil, nil, boards)
	if base.MaxAP != 6 || base.MaxHP != 75 {
		t.Fatalf("Iop with no spheres = AP %d / HP %d, want 6 / 75", base.MaxAP, base.MaxHP)
	}

	got := computeFighterStatsWithConditions(withSpheres(100, 101), nil, nil, boards)
	if got.MaxAP != 7 {
		t.Errorf("AP = %d, want 7 (+1 from sphere 100)", got.MaxAP)
	}
	if got.MaxHP != 100 {
		t.Errorf("max HP = %d, want 100 (+25 from sphere 101)", got.MaxHP)
	}

	// A node the fighter does NOT own must change nothing.
	unowned := computeFighterStatsWithConditions(withSpheres(100), nil, nil, boards)
	if unowned.MaxHP != 75 {
		t.Errorf("max HP = %d, want 75 - an unbought node was applied", unowned.MaxHP)
	}
}

// The board sells penalties on purpose ("un sacrifice qu'un combattant doit
// faire"), so a malus node must cost the fighter exactly as its rows say.
func TestMalusSpheresAreAppliedToo(t *testing.T) {
	boards := sphereEffectBoards()
	got := computeFighterStatsWithConditions(withSpheres(100, 102), nil, nil, boards)
	if got.MaxAP != 6 {
		t.Errorf("AP = %d, want 6 (+1 then -1) - a malus node was skipped", got.MaxAP)
	}
}

// Wounds are penalties on the FINISHED fighter, so they land after spheres. With
// only additive rows the order is invisible in the totals; what must hold is that
// both are applied.
func TestSpheresAndWoundsBothApply(t *testing.T) {
	boards := sphereEffectBoards()
	f := withSpheres(100)
	f.Conditions = []domain.FighterCondition{{ConditionID: 5, Remaining: -1}} // serious arm: -1 AP

	got := computeFighterStatsWithConditions(f, nil, woundCatalogue(), boards)
	if got.MaxAP != 6 {
		t.Errorf("AP = %d, want 6 (6 +1 sphere -1 wound)", got.MaxAP)
	}
}

// TestSphereSpellsReachTheFight: a Spell sphere has to make the fighter able to
// CAST it. Both the cast validator and the AI read Fighter.Spells, so the fighter
// handed to the fight must carry them.
func TestSphereSpellsReachTheFight(t *testing.T) {
	boards := sphereEffectBoards()
	f := withSpheres(103)
	// Spare capacity on purpose: with it, an append that forgot to COPY the slice
	// would write through into the persisted fighter's own array instead of
	// reallocating, which is the aliasing bug this guards.
	f.Spells = make([]domain.FighterSpell, 1, 8)
	f.Spells[0] = domain.FighterSpell{FighterID: 1, SpellID: 1}

	got := fighterWithSphereSpells(f, boards)
	ff := &FightFighter{Fighter: got}
	if !fighterKnowsSpell(ff, 555) {
		t.Error("a spell unlocked by a bought sphere cannot be cast")
	}
	if !fighterKnowsSpell(ff, 1) {
		t.Error("the fighter's own spell was lost")
	}

	// The persisted record must NOT be mutated: a sphere spell is derived from the
	// board every time, and writing it back would duplicate it on every load.
	if len(f.Spells) != 1 {
		t.Errorf("the stored fighter grew to %d spells; the copy leaked", len(f.Spells))
	}

	// A sphere granting a spell the fighter ALREADY knows must not duplicate it -
	// the cast path would still work, but the client is sent this list too.
	dup := withSpheres(103)
	dup.Spells = []domain.FighterSpell{{FighterID: 1, SpellID: 555}}
	merged := fighterWithSphereSpells(dup, boards)
	n555 := 0
	for _, sp := range merged.Spells {
		if sp.SpellID == 555 {
			n555++
		}
	}
	if n555 != 1 {
		t.Errorf("a spell the fighter already knew appears %d times, want 1", n555)
	}

	// The same spell from two nodes is still one spell.
	both := fighterWithSphereSpells(withSpheres(103, 105), boards)
	n := 0
	for _, sp := range both.Spells {
		if sp.SpellID == 555 {
			n++
		}
	}
	if n != 1 {
		t.Errorf("spell 555 appears %d times, want 1", n)
	}
}

func TestSphereDerivedListsAreDeduplicatedAndOrdered(t *testing.T) {
	boards := sphereEffectBoards()
	f := withSpheres(105, 103, 104)

	if got := sphereSpellIDs(f, boards); len(got) != 1 || got[0] != 555 {
		t.Errorf("spell ids = %v, want [555]", got)
	}
	if got := sphereEquipmentPools(f, boards); len(got) != 1 || got[0] != 9 {
		t.Errorf("pool ids = %v, want [9]", got)
	}
	// A node id the data no longer knows must be skipped, not panic.
	if got := sphereSpellIDs(withSpheres(9999), boards); len(got) != 0 {
		t.Errorf("unknown node produced %v", got)
	}
}

// TestEvolutionTailCarriesSphereSpellsAndPools reads the two lists back out of the
// blob. `ee_2` assigns them straight from here (aRE = NI(), aRF = NJ()) and never
// re-derives them, so an empty list is a spell that ceases to exist on relog.
func TestEvolutionTailCarriesSphereSpellsAndPools(t *testing.T) {
	boards := sphereEffectBoards()
	f := withSpheres(103, 104)
	f.Name, f.Evolution, f.State = "F", true, 1

	blob := encodeFighterBlob(f, boards)
	p := 1 + 2 + 1
	p += 1 + len(f.Name)
	p += 1 + 1 + 1 + 1 + 1
	p += 2 + int(beU16(blob[p:])) // spell blob
	p += 2 + int(beU16(blob[p:])) // card blob

	q := p + 12 + 3                 // board, xp, totalXp, tiredness, morale, state
	q += 4                          // cursor
	q += 2 + 4*int(beU16(blob[q:])) // owned nodes
	q += 1 + 3*int(blob[q])         // conditions

	if n := beU16(blob[q:]); n != 1 {
		t.Fatalf("sphere-spell count = %d, want 1", n)
	}
	if got := be32(blob[q+2:]); got != 555 {
		t.Errorf("sphere spell = %d, want 555", got)
	}
	if n := beU16(blob[q+6:]); n != 1 {
		t.Fatalf("equipment-pool count = %d, want 1", n)
	}
	if got := be32(blob[q+8:]); got != 9 {
		t.Errorf("equipment pool = %d, want 9", got)
	}
}

// TestFightTeamGivesFightersTheirSphereSpellsAndStats drives the real team build.
//
// The unit tests above prove the derivation; this proves the FIGHT uses it. That
// gap is the one that matters - deriving sphere spells perfectly and then handing
// the fight the untouched fighter looks fine everywhere except in play.
func TestFightTeamGivesFightersTheirSphereSpellsAndStats(t *testing.T) {
	st, err := storetest.Open(t, filepath.Join(t.TempDir(), "sphfight.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })

	acc, _ := st.Accounts.CreateAccount("sphfight", "secret", false)
	coach, _ := st.Coaches.Create(acc.ID, "Chef", 1, 2, 0)
	f := &domain.Fighter{
		CoachID: coach.ID, BreedID: 8, Name: "Iop", Evolution: true,
		Spells:  []domain.FighterSpell{{SpellID: 1}},
		Spheres: []domain.FighterSphere{{SphereID: 100}, {SphereID: 103}},
	}
	if err := st.DB().Create(f).Error; err != nil {
		t.Fatalf("create fighter: %v", err)
	}

	d := &Deps{Store: st, Log: testLogger(), SphereBoards: sphereEffectBoards()}
	sess := &Session{deps: d, log: testLogger(), Coach: coach}
	team, err := d.buildFightTeamFor(sess, 0, []Pos{{}}, []int64{int64(f.ID)})
	if err != nil {
		t.Fatalf("build team: %v", err)
	}
	if len(team.Fighters) != 1 {
		t.Fatalf("team has %d fighters, want 1", len(team.Fighters))
	}
	ff := team.Fighters[0]

	// Sphere 100 is +1 AP on top of the Iop's 6.
	if ff.MaxAP != 7 {
		t.Errorf("AP in fight = %d, want 7 (+1 from a bought sphere)", ff.MaxAP)
	}
	// Sphere 103 unlocks spell 555.
	if !fighterKnowsSpell(ff, 555) {
		t.Error("the fighter cannot cast the spell its bought sphere unlocked")
	}
	if !fighterKnowsSpell(ff, 1) {
		t.Error("the fighter lost its own spell")
	}
	// The AI picks from the same repertoire, or a sphere spell would exist for the
	// player and not for an AI-driven copy of the same fighter.
	fight := &Fight{deps: d}
	found := false
	for _, id := range fight.aiRepertoire(ff) {
		if id == 555 {
			found = true
		}
	}
	if !found {
		t.Error("the AI repertoire omits the sphere spell")
	}
}

// TestSphereSpellMergeDoesNotAliasTheStoredFighter: the merge appends to a slice
// that came from the persisted record. Without copying it first, two merges of the
// same fighter share one backing array and the second silently rewrites the
// first's spell - the fighter already in a fight suddenly casting something else.
// It is invisible to a length check, which is why it needs its own test.
func TestSphereSpellMergeDoesNotAliasTheStoredFighter(t *testing.T) {
	boards := gamedata.NewSphereBoards(
		[]*gamedata.SphereBoard{{ID: 21, Season: 1, Breed: 8, RootX: 1, RootY: 1}},
		[]*gamedata.Sphere{
			{ID: 200, BoardID: 21, X: 1, Y: 1, SpellID: 111},
			{ID: 201, BoardID: 21, X: 2, Y: 1, SpellID: 222},
		},
	)
	f := &domain.Fighter{ID: 1, BreedID: 8}
	f.Spells = make([]domain.FighterSpell, 1, 8) // spare capacity: the hazard
	f.Spells[0] = domain.FighterSpell{SpellID: 1}

	f.Spheres = []domain.FighterSphere{{SphereID: 200}}
	first := fighterWithSphereSpells(f, boards)

	f.Spheres = []domain.FighterSphere{{SphereID: 201}}
	_ = fighterWithSphereSpells(f, boards)

	if !fighterKnowsSpell(&FightFighter{Fighter: first}, 111) {
		t.Error("the first fighter's sphere spell was overwritten by a later merge")
	}
	if fighterKnowsSpell(&FightFighter{Fighter: first}, 222) {
		t.Error("the first fighter gained a spell from a later merge")
	}
}

// --- Equipment entitlement ---------------------------------------------------

func entitlementDeps(t *testing.T) *Deps {
	t.Helper()
	return &Deps{
		Log: testLogger(),
		SphereBoards: gamedata.NewSphereBoards(
			[]*gamedata.SphereBoard{{ID: 21, Season: 1, Breed: 8, RootX: 1, RootY: 1}},
			[]*gamedata.Sphere{
				{ID: 104, BoardID: 21, X: 1, Y: 1, EquipmentPoolID: 9},
				{ID: 106, BoardID: 21, X: 2, Y: 1, EquipmentPoolID: 4},
			},
		),
		EquipmentPools: gamedata.NewEquipmentPools(
			&gamedata.EquipmentPool{ID: 9, CardIDs: []int32{500, 501}},
			&gamedata.EquipmentPool{ID: 4, CardIDs: []int32{600}},
			&gamedata.EquipmentPool{ID: 7, CardIDs: []int32{999}}, // never unlocked
		),
	}
}

func equipReq(ids ...int32) []domain.FighterObject {
	out := make([]domain.FighterObject, 0, len(ids))
	for i, id := range ids {
		out = append(out, domain.FighterObject{Slot: int16(i), TemplateID: id})
	}
	return out
}

func equipIDs(objs []domain.FighterObject) []int32 {
	out := make([]int32, 0, len(objs))
	for _, o := range objs {
		out = append(out, o.TemplateID)
	}
	return out
}

// TestEvolutionFighterMayOnlyWearUnlockedEquipment: the client cannot offer a card
// the fighter has not unlocked, so the only way one arrives is a crafted 6011 -
// which would otherwise dress a fighter in anything in the game.
func TestEvolutionFighterMayOnlyWearUnlockedEquipment(t *testing.T) {
	d := entitlementDeps(t)
	s := &Session{deps: d, log: testLogger()}

	fr := &domain.Fighter{ID: 1, BreedID: 8, Evolution: true,
		Spheres: []domain.FighterSphere{{SphereID: 104}}} // unlocks pool 9 => 500, 501

	got := equipIDs(s.entitledEquip(fr, equipReq(500, 999, 501, 600)))
	if len(got) != 2 || got[0] != 500 || got[1] != 501 {
		t.Errorf("kept %v, want [500 501] - only pool 9 is unlocked", got)
	}

	// Buying the other Item node widens what it may wear.
	fr.Spheres = append(fr.Spheres, domain.FighterSphere{SphereID: 106})
	got = equipIDs(s.entitledEquip(fr, equipReq(500, 600, 999)))
	if len(got) != 2 || got[0] != 500 || got[1] != 600 {
		t.Errorf("kept %v, want [500 600] after unlocking pool 4", got)
	}
}

// A fighter that has bought no Item node has unlocked nothing, and the client
// offers it nothing either.
func TestEvolutionFighterWithNoItemSpheresWearsNothing(t *testing.T) {
	d := entitlementDeps(t)
	s := &Session{deps: d, log: testLogger()}
	fr := &domain.Fighter{ID: 1, BreedID: 8, Evolution: true}

	if got := equipIDs(s.entitledEquip(fr, equipReq(500, 600))); len(got) != 0 {
		t.Errorf("kept %v, want nothing", got)
	}
}

// The restriction is the CLIENT'S and applies to evolution fighters alone: an
// Elite fighter's picker is every card of the slot's type, so filtering one would
// take away equipment the client is still offering.
func TestEliteFighterEquipmentIsNotRestricted(t *testing.T) {
	d := entitlementDeps(t)
	s := &Session{deps: d, log: testLogger()}
	fr := &domain.Fighter{ID: 1, BreedID: 8} // not evolution

	got := equipIDs(s.entitledEquip(fr, equipReq(500, 999, 600)))
	if len(got) != 3 {
		t.Errorf("kept %v, want all three - Elite fighters are not pool-restricted", got)
	}
}

// With no game data loaded, enforcing would strip every fighter bare. The rest of
// the server degrades this way too.
func TestEntitlementIsInertWithoutData(t *testing.T) {
	s := &Session{deps: &Deps{Log: testLogger()}, log: testLogger()}
	fr := &domain.Fighter{ID: 1, BreedID: 8, Evolution: true}
	if got := equipIDs(s.entitledEquip(fr, equipReq(500, 999))); len(got) != 2 {
		t.Errorf("kept %v, want both - entitlement must be inert without data", got)
	}
}

// TestWearableCards (S22): the Godot editor's list (60023) follows
// entitledEquip — a Historia fighter sees what its spheres unlocked, an
// Elite fighter every fighter card.
func TestWearableCards(t *testing.T) {
	d := entitlementDeps(t)
	d.FighterCards = gamedata.NewFighterCards(
		&gamedata.FighterCard{ID: 500, Type: 1}, &gamedata.FighterCard{ID: 501, Type: 2},
		&gamedata.FighterCard{ID: 600, Type: 3}, &gamedata.FighterCard{ID: 999, Type: 4})
	evo := &domain.Fighter{ID: 1, BreedID: 8, Evolution: true,
		Spheres: []domain.FighterSphere{{SphereID: 104}}}
	if got := d.wearableCards(evo); len(got) != 2 || got[0] != 500 || got[1] != 501 {
		t.Errorf("Historia fighter: %v, want [500 501] (pool 9)", got)
	}
	elite := &domain.Fighter{ID: 2, BreedID: 8}
	if got := d.wearableCards(elite); len(got) != 4 {
		t.Errorf("Elite fighter: %v, want all four cards", got)
	}
}
