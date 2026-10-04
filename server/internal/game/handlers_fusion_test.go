package game

// Deliberately NOT parallel: TestFusionBoostInputsFeedTheDie seeds the shared
// package-level fusionRand for a deterministic die, and a parallel sibling
// fusing at the same moment would consume stream values.

import (
	"path/filepath"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store"
)

// fusionFixture builds a coach with a card set and a single lab (selected via
// Default() by putting the coach in a world with no elements), then runs a
// 5490 request and returns the decoded [result][obtained][notObtained][recovered]
// plus the coach's post-request quantity of a template.
func fusionFixture(t *testing.T, lab *gamedata.FusionLab, cards ...*gamedata.CoachCard) (
	*Session, *store.Store, func(ids ...int32) (uint8, int32, int32, int32), func(int32) int64) {
	t.Helper()
	st, err := store.Open(filepath.Join(t.TempDir(), "fusion.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })
	acc, _ := st.Accounts.CreateAccount("fuseA", "pw", false)
	coach, _ := st.Coaches.Create(acc.ID, "Fuser", 0, 0, 0)
	d := &Deps{
		Store: st, Log: testLogger(),
		Cards:      gamedata.NewCards(cards...),
		FusionLabs: gamedata.NewFusionLabs(lab),
	}
	s := &Session{
		log: testLogger(), deps: d, Coach: coach,
		out: make(chan []byte, writeQueueSize), quit: make(chan struct{}),
		currentWorld: 9999, // no elements -> fusionLab() returns Default()
	}
	fuse := func(ids ...int32) (uint8, int32, int32, int32) {
		t.Helper()
		w := protocol.NewWriter().I32(int32(len(ids)))
		for _, id := range ids {
			w.I32(id)
		}
		if err := handleFusionRequest(s, &protocol.C2SFrame{Payload: w.Bytes()}); err != nil {
			t.Fatalf("handleFusionRequest: %v", err)
		}
		payload := drainPayload(t, s, protocol.OpFusionResult)
		if payload == nil {
			t.Fatal("no FusionResult frame emitted")
		}
		r := protocol.NewReader(payload)
		res, _ := r.U8()
		obt, _ := r.I32()
		notObt, _ := r.I32()
		rec, _ := r.I32()
		return res, obt, notObt, rec
	}
	qty := func(tid int32) int64 {
		t.Helper()
		var n int64
		st.DB().Model(&domain.CoachCard{}).
			Where("coach_id = ? AND template_id = ?", coach.ID, tid).
			Select("COALESCE(SUM(quantity),0)").Scan(&n)
		return n
	}
	return s, st, fuse, qty
}

func grantFusionCards(t *testing.T, st *store.Store, coachID uint, grants ...domain.CoachCard) {
	t.Helper()
	for i := range grants {
		grants[i].CoachID = coachID
		if err := st.DB().Create(&grants[i]).Error; err != nil {
			t.Fatalf("grant %d: %v", grants[i].TemplateID, err)
		}
	}
}

// TestFusionTargetMustBeFusionCard pins the client's own gate (add.java
// "mustBeFusionCard": tz()!=0 || tA()!=0): naming a plain card as the target
// refuses the request WITHOUT consuming inputs — the old invented same-set
// rule is gone, this is the actual one.
func TestFusionTargetMustBeFusionCard(t *testing.T) {
	s, st, fuse, qty := fusionFixture(t,
		&gamedata.FusionLab{ID: 1, Power: 50, Quality: 100, Slots: 6},
		&gamedata.CoachCard{ID: 10, Value: 10, RequiredLevel: 5},
		&gamedata.CoachCard{ID: 11, Value: 10, RequiredLevel: 5},
		&gamedata.CoachCard{ID: 99, Value: 10, RequiredLevel: 5}, // no fp/fq
	)
	grantFusionCards(t, st, s.Coach.ID,
		domain.CoachCard{TemplateID: 10, Quantity: 1},
		domain.CoachCard{TemplateID: 11, Quantity: 1},
	)
	res, obt, notObt, rec := fuse(10, 11, 99)
	if res != fusionResultOK || obt != 0 || notObt != 0 || rec != 0 {
		t.Fatalf("non-fusion target -> (%d,%d,%d,%d), want (0,0,0,0) bare refusal", res, obt, notObt, rec)
	}
	if qty(10) != 1 || qty(11) != 1 {
		t.Fatal("refused fusion consumed inputs")
	}
}

// TestFusionSuccessAtFullQuality: lab quality 100 + affordable recipe -> the
// die always lands; inputs are consumed and the target granted.
func TestFusionSuccessAtFullQuality(t *testing.T) {
	s, st, fuse, qty := fusionFixture(t,
		&gamedata.FusionLab{ID: 1, Power: 0, Quality: 100, Slots: 6},
		&gamedata.CoachCard{ID: 10, Value: 100, RequiredLevel: 30},
		&gamedata.CoachCard{ID: 11, Value: 100, RequiredLevel: 30},
		&gamedata.CoachCard{ID: 943, Value: 200, RequiredLevel: 0, FusionPower: 5},
	)
	grantFusionCards(t, st, s.Coach.ID,
		domain.CoachCard{TemplateID: 10, Quantity: 1},
		domain.CoachCard{TemplateID: 11, Quantity: 1},
	)
	// kardsPower = 30+30-5 = 55 >= 0; quality = 100 -> always wins.
	res, obt, notObt, rec := fuse(10, 11, 943)
	if res != fusionResultOK || obt != 943 || notObt != 0 || rec != 0 {
		t.Fatalf("fusion = (%d,%d,%d,%d), want (0,943,0,0)", res, obt, notObt, rec)
	}
	if qty(10) != 0 || qty(11) != 0 || qty(943) != 1 {
		t.Fatalf("post-fusion qtys = (%d,%d,%d), want (0,0,1)", qty(10), qty(11), qty(943))
	}
}

// TestFusionFailAtZeroQuality: lab quality 0 -> the die never lands; inputs are
// consumed, one comes back as leftovers and notObtained names the target (the
// client's "fusionRecipeFailed" + "fusionLeftovers" rendering).
func TestFusionFailAtZeroQuality(t *testing.T) {
	s, st, fuse, qty := fusionFixture(t,
		&gamedata.FusionLab{ID: 1, Power: 0, Quality: 0, Slots: 6},
		&gamedata.CoachCard{ID: 10, Value: 100, RequiredLevel: 30},
		&gamedata.CoachCard{ID: 11, Value: 100, RequiredLevel: 30},
		&gamedata.CoachCard{ID: 943, Value: 200, RequiredLevel: 0, FusionPower: 5},
	)
	grantFusionCards(t, st, s.Coach.ID,
		domain.CoachCard{TemplateID: 10, Quantity: 1},
		domain.CoachCard{TemplateID: 11, Quantity: 1},
	)
	res, obt, notObt, rec := fuse(10, 11, 943)
	if res != fusionResultOK || obt != 0 || notObt != 943 || rec != 10 {
		t.Fatalf("failed fusion = (%d,%d,%d,%d), want (0,0,943,10)", res, obt, notObt, rec)
	}
	// inputs 10+11 consumed, one 10 recovered -> net 10:1, 11:0, no 943.
	if qty(10) != 1 || qty(11) != 0 || qty(943) != 0 {
		t.Fatalf("post-fusion qtys = (%d,%d,%d), want (1,0,0)", qty(10), qty(11), qty(943))
	}
}

// TestFusionRecipeUnaffordable: when inputs' RequiredLevel plus lab power can't
// cover the target's FusionPower the request names the target in notObtained
// and consumes nothing.
func TestFusionRecipeUnaffordable(t *testing.T) {
	s, st, fuse, qty := fusionFixture(t,
		&gamedata.FusionLab{ID: 1, Power: 0, Quality: 100, Slots: 6},
		&gamedata.CoachCard{ID: 10, Value: 10, RequiredLevel: 0},
		&gamedata.CoachCard{ID: 11, Value: 10, RequiredLevel: 0},
		&gamedata.CoachCard{ID: 947, Value: 20, RequiredLevel: 0, FusionPower: 30},
	)
	grantFusionCards(t, st, s.Coach.ID,
		domain.CoachCard{TemplateID: 10, Quantity: 1},
		domain.CoachCard{TemplateID: 11, Quantity: 1},
	)
	res, obt, notObt, rec := fuse(10, 11, 947)
	if res != fusionResultOK || obt != 0 || notObt != 947 || rec != 0 {
		t.Fatalf("unaffordable fusion = (%d,%d,%d,%d), want (0,0,947,0)", res, obt, notObt, rec)
	}
	if qty(10) != 1 || qty(11) != 1 {
		t.Fatal("unaffordable fusion consumed inputs")
	}
}

// TestFusionBoostInputsFeedTheDie: feeding a fusion card as input adds its
// FusionQuality to the success die — a quality-0 altar plus a 50-fq boost card
// still wins on a 50-side die, so a high seed must sometimes succeed and a
// >50 roll must fail. The same input's FusionPower counts toward the recipe.
func TestFusionBoostInputsFeedTheDie(t *testing.T) {
	s, st, fuse, qty := fusionFixture(t,
		&gamedata.FusionLab{ID: 1, Power: 0, Quality: 0, Slots: 6},
		&gamedata.CoachCard{ID: 10, Value: 10, RequiredLevel: 0},
		&gamedata.CoachCard{ID: 869, Value: 10, RequiredLevel: 0, FusionPower: 50, FusionQuality: 30},
		&gamedata.CoachCard{ID: 947, Value: 25, RequiredLevel: 0, FusionPower: 30},
	)
	grantFusionCards(t, st, s.Coach.ID,
		domain.CoachCard{TemplateID: 10, Quantity: 1},
		domain.CoachCard{TemplateID: 869, Quantity: 1},
	)
	// quality = lab 0 + boost fq 30 = 30 -> wins iff roll < 30.
	SeedFusionRand(4) // first Intn(100) lands < 30 on this stream
	res, obt, _, _ := fuse(10, 869, 947)
	if res != fusionResultOK || obt != 947 {
		t.Fatalf("boost-fed fusion = (%d,%d), want (0,947)", res, obt)
	}
	if qty(947) != 1 || qty(869) != 0 {
		t.Fatalf("post-fusion = %d target, %d boost", qty(947), qty(869))
	}
}

// TestFusionSlotLimit: the record's Slots counts the target slot too
// (azi()-1 inputs) — an altar with Slots=3 takes only 2 input cards.
func TestFusionSlotLimit(t *testing.T) {
	s, st, fuse, _ := fusionFixture(t,
		&gamedata.FusionLab{ID: 1, Power: 50, Quality: 100, Slots: 3},
		&gamedata.CoachCard{ID: 10, Value: 10, RequiredLevel: 30},
		&gamedata.CoachCard{ID: 11, Value: 10, RequiredLevel: 30},
		&gamedata.CoachCard{ID: 12, Value: 10, RequiredLevel: 30},
		&gamedata.CoachCard{ID: 943, Value: 20, RequiredLevel: 0, FusionPower: 5},
	)
	grantFusionCards(t, st, s.Coach.ID,
		domain.CoachCard{TemplateID: 10, Quantity: 1},
		domain.CoachCard{TemplateID: 11, Quantity: 1},
		domain.CoachCard{TemplateID: 12, Quantity: 1},
	)
	res, _, _, _ := fuse(10, 11, 12, 943) // 3 inputs on a 3-slot altar
	if res != fusionResultError {
		t.Fatalf("3 inputs on Slots=3 altar = result %d, want error %d", res, fusionResultError)
	}
}
