package e2e

// NOTE: the tests in this file are deliberately NOT parallel. They seed
// game.SeedFusionRand, a package-level RNG, with different values to force a
// success or a failure - so running two of them concurrently makes each observe
// the other's seed. Sequential tests complete before the parallel phase resumes,
// which is what keeps that safe.

import (
	"testing"
	"time"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/game"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/store"
	"github.com/StarLoco/arena-2.70/internal/testclient"
)

// fusionCatalog: cards 700/701 are plain inputs (RequiredLevel 0, like the real
// boost fodder); 702 is a FUSION target — the client's slot gate
// ("mustBeFusionCard": tz()!=0 || tA()!=0) requires FusionPower||FusionQuality,
// so a plain card can never be named as a target. 900 is in a different set —
// set membership is NOT a fusion constraint (the old same-set rule was an
// invention; mixing sets is legal).
func fusionCatalog() *gamedata.Cards {
	return gamedata.NewCards(
		&gamedata.CoachCard{ID: 700, CardSet: 5, Price: map[uint8]int32{1: 10}},
		&gamedata.CoachCard{ID: 701, CardSet: 5, Price: map[uint8]int32{1: 10}},
		&gamedata.CoachCard{ID: 702, CardSet: 5, Price: map[uint8]int32{1: 10},
			FusionQuality: 30},
		&gamedata.CoachCard{ID: 900, CardSet: 9, Price: map[uint8]int32{1: 10}},
		// An EXPENSIVE target, like the 7 real ones (all type 27 / set 149):
		// costs 30 fusion power and needs an altar of quality 30. The inputs
		// above are RequiredLevel 0, so they can never cover it.
		&gamedata.CoachCard{ID: 703, CardSet: 5, Price: map[uint8]int32{1: 10},
			FusionPower: 30, FusionQuality: 30},
	)
}

// fusionLabsAt returns the lab table the e2e world resolves to. The default
// start world (0) carries lab elements whose args are ids 2-7; fusionLab()
// picks the NEAREST one, so we give every candidate the same quality to make
// the success die deterministic whichever altar is chosen.
func fusionLabsAt(quality uint8) *gamedata.FusionLabs {
	labs := make([]*gamedata.FusionLab, 0, 6)
	for _, id := range []int64{2, 3, 4, 5, 6, 7} {
		labs = append(labs, &gamedata.FusionLab{ID: id, Power: 0, Quality: quality, Slots: 6})
	}
	return gamedata.NewFusionLabs(labs...)
}

// TestFusionTargetCostIsEnforced covers the target's own cost, which is the
// client's formula: kardsPower = Σ inputs' RequiredLevel − target's FusionPower.
// Only 7 cards in the game carry a non-zero FusionPower/FusionQuality, so for
// everything else this is a no-op — which is what makes it safe. Here the target
// costs 30 and the inputs are level 0, so it must be refused, and refused by
// NAMING the target (notObtained) so the client says which card was missed.
func TestFusionTargetCostIsEnforced(t *testing.T) {
	game.SeedFusionRand(3) // a seed that would otherwise SUCCEED
	st, addr := testServerWithDeps(t, func(d *game.Deps) {
		d.Cards = fusionCatalog()
		d.FusionLabs = fusionLabsAt(100)
	})
	a, aID := dialLogin(t, addr, "fus_d", "FusD")
	reachWorld(t, a)
	a.DrainReceived(200 * time.Millisecond)

	st.DB().Create(&domain.CoachCard{CoachID: uint(aID), TemplateID: 700, Quantity: 1})
	st.DB().Create(&domain.CoachCard{CoachID: uint(aID), TemplateID: 701, Quantity: 1})
	q700Before := ownedQty(t, st, uint(aID), 700)

	// inputs 700+701 (level 0), target 703 (costs 30) -> unaffordable.
	req := testclient.NewW().I32(3).I32(700).I32(701).I32(703).Bytes()
	_ = a.Send(3, testclient.OpFusionRequest, req)

	f, _, err := a.WaitFor(testclient.OpFusionResult, testclient.DefaultTimeout)
	if err != nil {
		t.Fatalf("no FusionResult(5491): %v", err)
	}
	res, obtained, notObtained, _ := parseFusion(f.Payload)
	if res != 0 {
		t.Fatalf("fusion result = %d, want 0", res)
	}
	if obtained != 0 {
		t.Errorf("obtained %d: an unaffordable target must not be granted", obtained)
	}
	if notObtained != 703 {
		t.Errorf("notObtained = %d, want the refused target 703", notObtained)
	}
	// Nothing may be consumed for a fusion that was never legal.
	time.Sleep(150 * time.Millisecond)
	if q := ownedQty(t, st, uint(aID), 700); q != q700Before {
		t.Errorf("card 700 qty changed on an unaffordable fusion: %d -> %d", q700Before, q)
	}
}

// parseFusion reads a FusionResult(5491): [i8 result][i32 obt][i32 notObt][i32 rec].
func parseFusion(payload []byte) (result uint8, obtained, notObtained, recovered int32) {
	r := testclient.NewR(payload)
	return r.U8(), r.I32(), r.I32(), r.I32()
}

// TestFusionSuccess: fusing two cards into a fusion target succeeds when the
// altar's quality covers the die (quality 100 -> always), consuming the inputs
// and granting the chosen target.
func TestFusionSuccess(t *testing.T) {
	game.SeedFusionRand(3)
	st, addr := testServerWithDeps(t, func(d *game.Deps) {
		d.Cards = fusionCatalog()
		d.FusionLabs = fusionLabsAt(100)
	})
	a, aID := dialLogin(t, addr, "fus_a", "FusA")
	reachWorld(t, a)
	a.DrainReceived(200 * time.Millisecond)

	// Seed inventory: one 700 and one 701 (same set).
	st.DB().Create(&domain.CoachCard{CoachID: uint(aID), TemplateID: 700, Quantity: 1})
	st.DB().Create(&domain.CoachCard{CoachID: uint(aID), TemplateID: 701, Quantity: 1})

	// Snapshot the pre-fusion 700/701/702 total (starter grants may add copies).
	before := setTotal(t, st, uint(aID))

	// 5490: [i32 count]{i32 cardId}. The LAST id is the TARGET the player chose
	// ("fusionCard"); the client puts it there by inserting it at index 0 and
	// then reversing in encode(). Here: inputs 700+701, target 702.
	req := testclient.NewW().I32(3).I32(700).I32(701).I32(702).Bytes()
	_ = a.Send(3, testclient.OpFusionRequest, req)

	f, _, err := a.WaitFor(testclient.OpFusionResult, testclient.DefaultTimeout)
	if err != nil {
		t.Fatalf("no FusionResult(5491): %v", err)
	}
	res, obtained, notObtained, recovered := parseFusion(f.Payload)
	if res != 0 {
		t.Fatalf("fusion result = %d, want 0", res)
	}
	if obtained == 0 {
		t.Fatalf("expected an obtained card on success, got obt=%d notObt=%d rec=%d",
			obtained, notObtained, recovered)
	}
	// The outcome must be the card the PLAYER chose, not a random one from the set.
	if obtained != 702 {
		t.Errorf("obtained %d, want the chosen target 702", obtained)
	}

	// Net change: two inputs consumed, one obtained granted => total -1.
	time.Sleep(150 * time.Millisecond)
	after := setTotal(t, st, uint(aID))
	if after != before-1 {
		t.Errorf("700/701/702 total = %d after fusion, want %d (consumed 2, granted 1)", after, before-1)
	}
}

// setTotal returns the coach's total quantity of templates 700/701/702.
func setTotal(t *testing.T, st *store.Store, coachID uint) int16 {
	t.Helper()
	c, err := st.Coaches.Get(coachID)
	if err != nil {
		t.Fatalf("get coach: %v", err)
	}
	var total int16
	for _, card := range c.Inventory {
		if card.TemplateID == 700 || card.TemplateID == 701 || card.TemplateID == 702 {
			total += card.Quantity
		}
	}
	return total
}

// TestFusionFailureLeftovers: a failed quality die consumes the inputs and
// returns one as recovered leftovers. Quality 50 passes the target's fq floor
// (30) so the roll actually happens, and seed 1 rolls 81 -> miss.
func TestFusionFailureLeftovers(t *testing.T) {
	game.SeedFusionRand(1) // first Intn(100) = 81 -> fails a quality-50 die
	st, addr := testServerWithDeps(t, func(d *game.Deps) {
		d.Cards = fusionCatalog()
		d.FusionLabs = fusionLabsAt(50)
	})
	a, aID := dialLogin(t, addr, "fus_b", "FusB")
	reachWorld(t, a)
	a.DrainReceived(200 * time.Millisecond)

	st.DB().Create(&domain.CoachCard{CoachID: uint(aID), TemplateID: 700, Quantity: 1})
	st.DB().Create(&domain.CoachCard{CoachID: uint(aID), TemplateID: 701, Quantity: 1})

	req := testclient.NewW().I32(3).I32(700).I32(701).I32(702).Bytes()
	_ = a.Send(3, testclient.OpFusionRequest, req)

	f, _, err := a.WaitFor(testclient.OpFusionResult, testclient.DefaultTimeout)
	if err != nil {
		t.Fatalf("no FusionResult(5491): %v", err)
	}
	res, obtained, notObtained, recovered := parseFusion(f.Payload)
	if res != 0 {
		t.Fatalf("fusion result = %d, want 0", res)
	}
	if obtained != 0 {
		t.Errorf("failure should not obtain a card, got %d", obtained)
	}
	// The client renders notObtained as "fusionRecipeFailed" - it names the card
	// that was missed, so a bare failure would lose that message.
	if notObtained != 702 {
		t.Errorf("notObtained = %d, want the missed target 702", notObtained)
	}
	if recovered == 0 {
		t.Error("failure should recover leftovers")
	}
}

// TestFusionNonFusionTargetFails: naming a card without
// FusionPower/FusionQuality as the target hits the client's "mustBeFusionCard"
// gate -> plain fail (all ids 0), inputs untouched. (Mixing sets is legal —
// the only real gate is the target's fp||fq, which 700 lacks.)
func TestFusionNonFusionTargetFails(t *testing.T) {
	st, addr := testServerWithDeps(t, func(d *game.Deps) {
		d.Cards = fusionCatalog()
		d.FusionLabs = fusionLabsAt(100)
	})
	a, aID := dialLogin(t, addr, "fus_c", "FusC")
	reachWorld(t, a)
	a.DrainReceived(200 * time.Millisecond)

	st.DB().Create(&domain.CoachCard{CoachID: uint(aID), TemplateID: 701, Quantity: 1})
	st.DB().Create(&domain.CoachCard{CoachID: uint(aID), TemplateID: 900, Quantity: 1})

	q701Before := ownedQty(t, st, uint(aID), 701)
	q900Before := ownedQty(t, st, uint(aID), 900)

	// inputs 701+900 (mixed sets — legal), target 700 (no fp/fq — illegal).
	req := testclient.NewW().I32(3).I32(701).I32(900).I32(700).Bytes()
	_ = a.Send(3, testclient.OpFusionRequest, req)

	f, _, err := a.WaitFor(testclient.OpFusionResult, testclient.DefaultTimeout)
	if err != nil {
		t.Fatalf("no FusionResult(5491): %v", err)
	}
	res, obtained, notObtained, recovered := parseFusion(f.Payload)
	if res != 0 || obtained != 0 || notObtained != 0 || recovered != 0 {
		t.Fatalf("non-fusion target should be a plain fail (all 0), got res=%d o=%d n=%d r=%d",
			res, obtained, notObtained, recovered)
	}
	// Inputs untouched (no consume on an invalid target).
	time.Sleep(100 * time.Millisecond)
	if q := ownedQty(t, st, uint(aID), 701); q != q701Before {
		t.Errorf("card 701 qty changed on invalid fusion: %d -> %d", q701Before, q)
	}
	if q := ownedQty(t, st, uint(aID), 900); q != q900Before {
		t.Errorf("card 900 qty changed on invalid fusion: %d -> %d", q900Before, q)
	}
}

// ownedQty returns the coach's total quantity of one template.
func ownedQty(t *testing.T, st *store.Store, coachID uint, tmpl int32) int16 {
	t.Helper()
	c, err := st.Coaches.Get(coachID)
	if err != nil {
		t.Fatalf("get coach: %v", err)
	}
	var q int16
	for _, card := range c.Inventory {
		if card.TemplateID == tmpl {
			q += card.Quantity
		}
	}
	return q
}
