package game

import (
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// buildTestFight makes a minimal 2-fighter fight for phase tests.
func buildTestFight() *Fight {
	mk := func(coachID uint, name string, side uint8) *FightTeam {
		coach := &domain.Coach{ID: coachID, Name: name}
		fr := &domain.Fighter{ID: coachID * 10, BreedID: 1, Name: name + "F"}
		return &FightTeam{
			ID: side, Members: []*FightMember{{Coach: coach}},
			Fighters: []*FightFighter{{
				WireID: FighterWireIDBase + int64(coachID), CoachID: coachID,
				TeamID: side, Fighter: fr, MaxHP: 1000, HP: 1000, AP: 6, MP: 3,
			}},
		}
	}
	f := &Fight{
		Teams:        [2]*FightTeam{mk(1, "A", 0), mk(2, "B", 1)},
		readyPresent: map[uint]bool{}, readyObserve: map[uint]bool{}, readyAction: map[uint]bool{},
	}
	f.Timeline = buildTimeline(f)
	return f
}

// TestCreateFightEncodes verifies the 8000 blob encodes without error and has
// the expected leading bytes.
func TestCreateFightEncodes(t *testing.T) {
	f := buildTestFight()
	frame, err := buildCreateFight(f, nil, false)
	if err != nil {
		t.Fatalf("buildCreateFight: %v", err)
	}
	// Frame = [u16 totalLen][u16 opcode=8000][payload]; payload[0] = error byte 0.
	if len(frame) < 5 {
		t.Fatalf("frame too short: %d", len(frame))
	}
	opcode := uint16(frame[2])<<8 | uint16(frame[3])
	if opcode != 8000 {
		t.Errorf("opcode = %d, want 8000", opcode)
	}
	if frame[4] != 0 {
		t.Errorf("error byte = %d, want 0", frame[4])
	}

	// The spectator blob is identical except for the single spectator-flag byte.
	spec, err := buildCreateFight(f, nil, true)
	if err != nil {
		t.Fatalf("buildCreateFight(spectator): %v", err)
	}
	if len(spec) != len(frame) {
		t.Fatalf("spectator blob length %d != player blob length %d", len(spec), len(frame))
	}
	diff := 0
	for i := range frame {
		if frame[i] != spec[i] {
			diff++
		}
	}
	if diff != 1 {
		t.Errorf("spectator flag should flip exactly 1 byte, got %d", diff)
	}
}

// TestFightPhaseProgression drives the ready-gates and checks phase transitions.
func TestFightPhaseProgression(t *testing.T) {
	f := buildTestFight()
	f.setPhase(PhasePresentation)

	// One coach ready for placement: not enough.
	if f.markReady(f.readyPresent, 1) {
		t.Error("one ready should not advance")
	}
	// Both ready: advance.
	if !f.markReady(f.readyPresent, 2) {
		t.Error("both ready should advance")
	}

	// Observation gate.
	f.markReady(f.readyObserve, 1)
	if !f.markReady(f.readyObserve, 2) {
		t.Error("both observe-ready should advance")
	}

	// Action gate.
	f.markReady(f.readyAction, 1)
	if !f.markReady(f.readyAction, 2) {
		t.Error("both action-ready should advance")
	}
}

// TestTimelineOrder confirms both fighters are in the turn order.
func TestTimelineOrder(t *testing.T) {
	f := buildTestFight()
	if len(f.Timeline) != 2 {
		t.Fatalf("timeline len = %d, want 2", len(f.Timeline))
	}
}

// TestTimelineInitiativeOrder verifies the turn order is initiative-descending
// (breed base init). The client replays this order verbatim (no client-side
// re-sort), so it decides who acts first each round.
func TestTimelineInitiativeOrder(t *testing.T) {
	mk := func(coachID uint, breed, side uint8) *FightTeam {
		return &FightTeam{
			ID: side, Members: []*FightMember{{Coach: &domain.Coach{ID: coachID}}},
			Fighters: []*FightFighter{{
				WireID: FighterWireIDBase + int64(coachID), CoachID: coachID,
				TeamID: side, Fighter: &domain.Fighter{BreedID: breed},
			}},
		}
	}
	// Team A = Iop (breed 8, init 40); team B = Xelor (breed 5, init 70).
	// Xelor's higher initiative must put it first despite being team B.
	f := &Fight{Teams: [2]*FightTeam{mk(1, 8, 0), mk(2, 5, 1)}}
	tl := buildTimeline(f)
	if len(tl) != 2 {
		t.Fatalf("timeline len = %d, want 2", len(tl))
	}
	if tl[0].Fighter.BreedID != 5 {
		t.Errorf("first to act = breed %d, want 5 (Xelor init 70 > Iop init 40)", tl[0].Fighter.BreedID)
	}
}

// TestIsAIControlled verifies that only a fighter whose team has no live session
// (the synthetic sparring side of a practice fight) is treated as AI — those are
// the ones that auto-pass on the short aiTurnClock. A fighter on a team with a
// live session (a real coach) must never be AI-controlled.
func TestIsAIControlled(t *testing.T) {
	f := buildTestFight()
	// buildTestFight leaves both teams session-less, so every fighter is AI.
	for _, ff := range f.allFighters() {
		if !f.isAIControlled(ff) {
			t.Errorf("session-less fighter %d should be AI-controlled", ff.WireID)
		}
	}
	// Attach a live session to team 0: its fighter is now human-driven, while
	// team 1 (still session-less) stays AI.
	f.Teams[0].Members[0].Session = &Session{}
	if human := f.Teams[0].Fighters[0]; f.isAIControlled(human) {
		t.Error("fighter on a team with a live session must not be AI-controlled")
	}
	if ai := f.Teams[1].Fighters[0]; !f.isAIControlled(ai) {
		t.Error("fighter on a session-less team must be AI-controlled")
	}
	// A fighter not attached to any team resolves to AI (defensive default).
	orphan := &FightFighter{WireID: 999}
	if !f.isAIControlled(orphan) {
		t.Error("orphan fighter should default to AI-controlled")
	}
}

// TestAutopilotHandsFightersToTheAI: /AUTOPILOT (S11 reels) makes a coach's
// fighters AI-played while its session stays attached — so the coach's client
// still gets every frame — and turning it off gives them back.
func TestAutopilotHandsFightersToTheAI(t *testing.T) {
	f := buildTestFight()
	m := f.Teams[0].Members[0]
	m.Session = &Session{}
	human := f.Teams[0].Fighters[0]
	if f.isAIControlled(human) {
		t.Fatal("a live coach's fighter starts human-played")
	}
	m.Autopilot = true
	if !f.isAIControlled(human) {
		t.Error("autopilot on: the AI plays the coach's fighter")
	}
	if m.Session == nil {
		t.Error("autopilot must keep the session (the client still watches)")
	}
	m.Autopilot = false
	if f.isAIControlled(human) {
		t.Error("autopilot off: the coach plays again")
	}
}

// TestCoachActionDeckNeverEmitsCardIDs locks the id NAMESPACE of the 8000 coach
// deck blob. It used to carry `CoachCard.TemplateID`, which is wrong: the client
// deserialises this blob with `new ajO(je_1.Wa(), 8)`, and `je_1`'s castable map
// is filled only by `apS` from the SPELL records — cards live in a separate
// registry (`la_0.XJ()`). A card id there either misses (the client logs
// "impossible d'ajouter l'item" and drops it) or COLLIDES with an unrelated spell
// and renders it as a castable action card; 65 of the 325 cards with a usable
// action collide that way.
//
// Equipped cards must therefore never reach the blob, no matter how many the
// coach has.
func TestCoachActionDeckNeverEmitsCardIDs(t *testing.T) {
	coach := &domain.Coach{Inventory: []domain.CoachCard{
		{TemplateID: 101, Pos: 2},
		{TemplateID: 200, Pos: 0},
		{TemplateID: 102, Pos: 1},
	}}
	f := &Fight{deps: &Deps{Spells: gamedata.NewSpells(
		&gamedata.Spell{ID: 101}, // a spell that COLLIDES with an equipped card id
		&gamedata.Spell{ID: 102},
	)}}

	w := protocol.NewWriter()
	writeCoachActionDeck(w, f, coach)
	if got := w.Bytes(); len(got) != 2 || got[0] != 0 || got[1] != 0 {
		t.Errorf("deck blob = % x, want 0000 (empty): equipped CARD ids must never "+
			"be emitted into a SPELL-id field, even when the ids collide", got)
	}

	// nil coach -> empty blob too.
	w2 := protocol.NewWriter()
	writeCoachActionDeck(w2, f, nil)
	if got := w2.Bytes(); len(got) != 2 || got[0] != 0 || got[1] != 0 {
		t.Errorf("empty deck blob = % x, want 0000", got)
	}
}

// TestFilterCoachDeckSpellIDs covers the safety net that will matter the day the
// deck actually has a source: only ids the client can resolve get emitted, deduped
// and capped at the client's own capacity (`new ajO(je_1.Wa(), 8)`).
func TestFilterCoachDeckSpellIDs(t *testing.T) {
	spells := gamedata.NewSpells(
		&gamedata.Spell{ID: 10}, &gamedata.Spell{ID: 11}, &gamedata.Spell{ID: 12},
		&gamedata.Spell{ID: 13}, &gamedata.Spell{ID: 14}, &gamedata.Spell{ID: 15},
		&gamedata.Spell{ID: 16}, &gamedata.Spell{ID: 17}, &gamedata.Spell{ID: 18},
	)
	// Unknown ids and 0 are dropped; duplicates collapse.
	got := filterCoachDeckSpellIDs(spells, []int32{10, 999, 0, 11, 10, 12})
	want := []int32{10, 11, 12}
	if len(got) != len(want) {
		t.Fatalf("filtered = %v, want %v", got, want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("filtered = %v, want %v (order preserved)", got, want)
		}
	}

	// Capacity: 9 valid ids must be trimmed to the client's 8.
	all := []int32{10, 11, 12, 13, 14, 15, 16, 17, 18}
	if got := filterCoachDeckSpellIDs(spells, all); len(got) != coachActionDeckCapacity {
		t.Errorf("filtered %d ids, want the client cap of %d", len(got), coachActionDeckCapacity)
	}
	if got := filterCoachDeckSpellIDs(nil, all); got != nil {
		t.Errorf("no spell table should yield nil, got %v", got)
	}
}

// TestFighterMaxHP locks the breed base-HP table to the values the 2.70 client
// derives on its HP gauge (verified live: an Iop reads 75, a Feca 70), so the
// server's authoritative HP stays in step with the client and damage/death
// timing agree. Unknown breeds fall back to 70.
func TestFighterMaxHP(t *testing.T) {
	cases := map[uint8]int32{
		1:  70, // Feca
		5:  60, // Xelor
		8:  75, // Iop
		11: 80, // Sacrier
		12: 75, // Pandawa
	}
	for breed, want := range cases {
		if got := fighterMaxHP(breed); got != want {
			t.Errorf("fighterMaxHP(breed %d) = %d, want %d", breed, got, want)
		}
	}
	if got := fighterMaxHP(200); got != 70 {
		t.Errorf("fighterMaxHP(unknown breed) = %d, want 70 fallback", got)
	}
}

// TestComputeFighterStats verifies a fighter's in-fight maxima are the breed base
// plus the sum of its equipped fighter-cards' passive bonuses — the same figure
// the 2.70 client derives from the equipped-card ids in the 8000 blob, so the
// server's authoritative HP/AP/MP stays in step with the client gauges.
func TestComputeFighterStats(t *testing.T) {
	cat := gamedata.NewFighterCards(
		&gamedata.FighterCard{ID: 118, Bonus: gamedata.FighterStatBonus{HP: 40}},
		&gamedata.FighterCard{ID: 106, Bonus: gamedata.FighterStatBonus{AP: 1}},
		&gamedata.FighterCard{ID: 21, Bonus: gamedata.FighterStatBonus{Init: 10}},
		&gamedata.FighterCard{ID: 50, Bonus: gamedata.FighterStatBonus{Range: 1}},
	)
	// Iop (breed 8): base HP75 AP6 MP3 Init10 Range0, crit 5% / fumble 1%.
	// (Init is 10 in 2.70 — it was 40 in the 2.04b table we used to carry.)
	iop := fighterStats{MaxHP: 75, MaxAP: 6, MaxMP: 3, Init: 10, CritRate: 0, FumbleRate: 0, Block: 40, Dodge: 100}
	if got := computeFighterStats(&domain.Fighter{BreedID: 8}, cat); got != iop {
		t.Errorf("no-card stats = %+v, want %+v", got, iop)
	}
	// Equip +40 HP, +1 AP, +10 init and +1 range cards.
	fr := &domain.Fighter{BreedID: 8, Objects: []domain.FighterObject{
		{TemplateID: 118}, {TemplateID: 106}, {TemplateID: 21}, {TemplateID: 50},
	}}
	want := fighterStats{MaxHP: 115, MaxAP: 7, MaxMP: 3, Init: 20, Range: 1, CritRate: 0, FumbleRate: 0, Block: 40, Dodge: 100}
	if got := computeFighterStats(fr, cat); got != want {
		t.Errorf("equipped stats = %+v, want %+v", got, want)
	}
	// A nil catalog (data files absent) yields the breed base regardless of cards.
	if got := computeFighterStats(fr, nil); got != iop {
		t.Errorf("nil-catalog stats = %+v, want breed base %+v", got, iop)
	}
	// Unknown breed falls back to a neutral profile (HP70 AP6 MP3 Init0).
	unk := fighterStats{MaxHP: 70, MaxAP: 6, MaxMP: 3, Init: 0, CritRate: 0, FumbleRate: 0}
	if got := computeFighterStats(&domain.Fighter{BreedID: 200}, cat); got != unk {
		t.Errorf("unknown-breed stats = %+v, want %+v", got, unk)
	}
}

// TestCombatFighterBlobLayout locks the gn_0.b fighter record byte count so the
// 8000 fight-presentation can't silently regress (a wrong count underflows the
// client). For an empty-inventory fighter with an N-char name the record is:
//
//	i64(8)+u8(1)+[u8+name](1+N)+6*u8(6)+i32(4)
//	+i16 spellLen(2)+i16 cardLen(2)+[i16 sphereLen(2)+u8 sphereCount(1)]
//	+2*i16count(4)+3*i32(12)
//	= 43 + N
//
// The sphere blob MUST carry its leading count byte even when empty (sH.b reads
// it unconditionally; a 0-length blob underflows and fails the whole fighter).
func TestCombatFighterBlobLayout(t *testing.T) {
	w := protocol.NewWriter()
	ff := &FightFighter{
		WireID:  123,
		Fighter: &domain.Fighter{Name: "Hero", BreedID: 5, Sex: 1, Skin: 2, Hair: 3, Eye: 4},
	}
	writeCombatFighterBlob(w, ff)
	got := len(w.Bytes())
	want := 43 + len("Hero")
	if got != want {
		t.Fatalf("fighter blob = %d bytes, want %d", got, want)
	}
}
