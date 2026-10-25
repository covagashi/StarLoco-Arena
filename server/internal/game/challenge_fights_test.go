package game

import (
	"testing"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// openChallengeData loads the real type-400 table, skipping (not failing) when
// the data files are absent — the repo convention for real-data tests.
func openChallengeData(t *testing.T) *gamedata.Challenges {
	t.Helper()
	st := openRealGameData(t)
	defs, err := st.LoadChallenges()
	if err != nil {
		t.Fatalf("LoadChallenges: %v", err)
	}
	return defs
}

// TestChallengeTableDecodes pins the shape of the real challenge table. The
// decoder has no length guard beyond `cur`, so a layout drift would silently
// yield garbage ids rather than an error.
func TestChallengeTableDecodes(t *testing.T) {
	defs := openChallengeData(t)
	if got := defs.Len(); got != 39 {
		t.Errorf("challenge count = %d, want 39", got)
	}
	// Every id in the table must be positive and round-trip through Get.
	for id, ch := range defs.All() {
		if id <= 0 || ch == nil || ch.ID != id {
			t.Fatalf("bad entry %d -> %+v", id, ch)
		}
		if defs.Get(id) != ch {
			t.Errorf("Get(%d) did not return the stored definition", id)
		}
	}
	// Spot-check two records decoded byte-for-byte from the dump.
	if ch := defs.Get(32); ch == nil {
		t.Fatal("challenge 32 missing")
	} else {
		if want := [6]int32{50, 64, 41, 0, 5, 0}; ch.Fields != want {
			t.Errorf("challenge 32 fields = %v, want %v", ch.Fields, want)
		}
		if got, want := ch.RewardCards, []int32{187, 189, 194}; len(got) != len(want) {
			t.Errorf("challenge 32 rewards = %v, want %v", got, want)
		}
	}
	if ch := defs.Get(45); ch == nil {
		t.Fatal("challenge 45 missing")
	} else if want := [6]int32{60, 0, 76, 542, 1, 0}; ch.Fields != want {
		t.Errorf("challenge 45 fields = %v, want %v", ch.Fields, want)
	}
}

// TestChallengeTimeFlagInactiveForSpawnedDemons pins the finding that closed the
// "per-challenge time limit" question: the client's time/XP end-fight panel is
// gated on GE.QE(), and that flag is 0 for EVERY challenge we spawn — every breed
// master, every minute demon, and world 23's Barnaby demon. So there is no
// per-challenge turn limit for the server to enforce, and the minute-demon names
// are flavour.
//
// If this ever flips, the decode or the data changed and the "nothing to enforce"
// conclusion in docs/OVERWORLD-MAP.md must be revisited.
func TestChallengeTimeFlagInactiveForSpawnedDemons(t *testing.T) {
	defs := openChallengeData(t)

	spawned := []int32{17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 32, 34, 35, 36, 45}
	for _, id := range spawned {
		ch := defs.Get(id)
		if ch == nil {
			t.Errorf("challenge %d missing", id)
			continue
		}
		if ch.TimeChallenge != 0 {
			t.Errorf("challenge %d TimeChallenge = %d, want 0 (no time limit expected)",
				id, ch.TimeChallenge)
		}
	}
	// Document the whole-table picture: report any challenge that DOES set the
	// flag, so the "dormant mechanic" claim is backed by the full table, not just
	// the spawned subset.
	var active []int32
	for id, ch := range defs.All() {
		if ch.TimeChallenge != 0 {
			active = append(active, id)
		}
	}
	t.Logf("challenges with a non-zero time flag across the whole table: %v", active)
}

// TestEveryReferencedChallengeExists is the invariant that matters at runtime:
// every challenge id referenced by a DemonChallenge or BreedMaster element we
// spawn must exist in the table, or clicking it refuses with 26310 and the
// element is dead content.
func TestEveryReferencedChallengeExists(t *testing.T) {
	defs := openChallengeData(t)
	for id := range breedMasterChallenge {
		if defs.Get(id) == nil {
			t.Errorf("breed-master challenge %d is not in the type-400 table", id)
		}
	}
	for id := range demonChallengeBreeds {
		if defs.Get(id) == nil {
			t.Errorf("demon challenge %d is not in the type-400 table", id)
		}
	}
}

// TestBreedMasterChallengeCoversAllBreeds: the twelve breed masters must map to
// the twelve distinct breeds, one each.
func TestBreedMasterChallengeCoversAllBreeds(t *testing.T) {
	if len(breedMasterChallenge) != 12 {
		t.Fatalf("breed-master challenges = %d, want 12", len(breedMasterChallenge))
	}
	seen := map[uint8]int32{}
	for challengeID, breed := range breedMasterChallenge {
		if breed < 1 || breed > 12 {
			t.Errorf("challenge %d -> breed %d out of range 1..12", challengeID, breed)
		}
		if prev, dup := seen[breed]; dup {
			t.Errorf("breed %d taught by both challenge %d and %d", breed, prev, challengeID)
		}
		seen[breed] = challengeID
	}
	if len(seen) != 12 {
		t.Errorf("distinct breeds = %d, want 12", len(seen))
	}
}

// TestChallengeOpponentBreeds covers the three selection paths.
func TestChallengeOpponentBreeds(t *testing.T) {
	// A breed master tests you one-on-one with the breed it teaches.
	if got := challengeOpponentBreeds(17, 4); len(got) != 1 || got[0] != 8 {
		t.Errorf("challenge 17 breeds = %v, want [8] (Iop, solo)", got)
	}
	// A demon fields its authored team regardless of the player's size.
	if got := challengeOpponentBreeds(33, 1); len(got) != 4 {
		t.Errorf("challenge 33 (boss) breeds = %v, want 4 fighters", got)
	}
	// An unauthored challenge mirrors the player's team size...
	for _, mirror := range []int{1, 2, 3, 4} {
		if got := challengeOpponentBreeds(3, mirror); len(got) != mirror {
			t.Errorf("fallback with mirror=%d = %v, want %d fighters", mirror, got, mirror)
		}
	}
	// ...and is clamped at both ends so it never yields an empty or absurd team.
	if got := challengeOpponentBreeds(3, 0); len(got) != 1 {
		t.Errorf("fallback with mirror=0 = %v, want 1 fighter", got)
	}
	if got := challengeOpponentBreeds(3, 99); len(got) != len(defaultChallengeBreeds) {
		t.Errorf("fallback with mirror=99 = %v, want clamp to %d", got, len(defaultChallengeBreeds))
	}
}

// TestChallengeRewardsResolveToRealCards: the type-400 reward lists must all be
// real card templates, or a victory would grant phantom inventory rows the
// client cannot render.
func TestChallengeRewardsResolveToRealCards(t *testing.T) {
	st := openRealGameData(t)
	defs, err := st.LoadChallenges()
	if err != nil {
		t.Fatalf("LoadChallenges: %v", err)
	}
	cards, err := st.LoadCards()
	if err != nil {
		t.Fatalf("LoadCards: %v", err)
	}
	// danglingRewardCards are reward ids the shipped data references but does not
	// define. Card 184 is awarded by challenges 9 and 37 yet appears in neither the
	// coach-card (type 100) nor fighter-card (type 250) table — a defect in the
	// game data, not in our decoder. awardChallengeRewards filters these, so this
	// set documents the known ones and fails if a NEW one appears (which would more
	// likely mean the decoder drifted).
	danglingRewardCards := map[int32]bool{184: true}

	rewarding := 0
	for id, ch := range defs.All() {
		if len(ch.RewardCards) > 0 {
			rewarding++
		}
		for _, cardID := range ch.RewardCards {
			if cards.Get(cardID) != nil {
				continue
			}
			if danglingRewardCards[cardID] {
				continue // known bad data; filtered before granting
			}
			t.Errorf("challenge %d rewards card %d, which is not in the card table",
				id, cardID)
		}
	}
	if rewarding == 0 {
		t.Error("no challenge awards any card — reward decoding is probably broken")
	}
	// Guard the filter itself: the dangling ids must really be absent, otherwise
	// this allow-list is silently masking working cards.
	for cardID := range danglingRewardCards {
		if cards.Get(cardID) != nil {
			t.Errorf("card %d is in the allow-list of dangling rewards but DOES exist; "+
				"drop it from danglingRewardCards", cardID)
		}
	}
	// The twelve breed masters award nothing; that is expected, not a bug.
	for id := range breedMasterChallenge {
		if ch := defs.Get(id); ch != nil && len(ch.RewardCards) != 0 {
			t.Logf("note: breed-master challenge %d now lists rewards %v", id, ch.RewardCards)
		}
	}
}

// TestChallengeOpponentNaming pins the opponent labels: demon challenges show the
// demon's own name, breed masters show the master label, and every fighter is
// named by its breed. All twelve breed names must be present so a fighter of any
// breed is never left with the fallback.
func TestChallengeOpponentNaming(t *testing.T) {
	// Every breed 1..12 has a display name.
	for b := uint8(1); b <= 12; b++ {
		if _, ok := breedName[b]; !ok {
			t.Errorf("breed %d has no display name", b)
		}
	}
	if got := fighterBreedName(99); got != "Champion" {
		t.Errorf("unknown breed name = %q, want the Champion fallback", got)
	}

	// Demon challenges are labelled with their own name...
	for id := range demonChallengeName {
		if got := challengeOpponentName(id); got != demonChallengeName[id] {
			t.Errorf("challenge %d opponent = %q, want %q", id, got, demonChallengeName[id])
		}
	}
	// ...and every demon-challenge id we field a team for has a name (no anonymous
	// "Démon").
	for id := range demonChallengeBreeds {
		if _, ok := demonChallengeName[id]; !ok {
			t.Errorf("demon challenge %d has a team but no name", id)
		}
	}
	// Breed masters share the generic master label.
	for id := range breedMasterChallenge {
		if got := challengeOpponentName(id); got != "Maître d'élevage" {
			t.Errorf("breed-master challenge %d opponent = %q, want the master label", id, got)
		}
	}
}

// TestPickBreedSpellDeterministic: the AI reads exactly one spell per fighter, so
// the pick must be stable across runs (map iteration order must not leak) and
// must actually be a damaging spell of that breed.
func TestPickBreedSpellDeterministic(t *testing.T) {
	st := openRealGameData(t)
	spells, err := st.LoadSpells()
	if err != nil {
		t.Fatalf("LoadSpells: %v", err)
	}
	for breed := uint8(1); breed <= 12; breed++ {
		first := pickBreedSpell(spells, breed)
		if first == 0 {
			t.Errorf("breed %d: no damaging spell found — its AI would be a passive blocker", breed)
			continue
		}
		for i := 0; i < 8; i++ {
			if got := pickBreedSpell(spells, breed); got != first {
				t.Fatalf("breed %d: pick is non-deterministic (%d then %d)", breed, first, got)
			}
		}
		sp := spells.Get(first)
		if sp == nil {
			t.Errorf("breed %d: picked spell %d not in table", breed, first)
			continue
		}
		if sp.BreedID != int32(breed) {
			t.Errorf("breed %d: picked spell %d belongs to breed %d", breed, first, sp.BreedID)
		}
		if _, _, ok := sp.Damage(); !ok {
			t.Errorf("breed %d: picked spell %d does no damage", breed, first)
		}
	}
	// No spell data must not panic.
	if got := pickBreedSpell(nil, 1); got != 0 {
		t.Errorf("pickBreedSpell(nil) = %d, want 0", got)
	}
}

// TestBuildChallengeTeamIsAIReady asserts the properties the fight engine relies
// on: a session-less team (so it is pre-marked ready and AI-driven), distinct
// wire ids, live HP, and a spell so the AI is not a statue.
func TestBuildChallengeTeamIsAIReady(t *testing.T) {
	st := openRealGameData(t)
	spells, err := st.LoadSpells()
	if err != nil {
		t.Fatalf("LoadSpells: %v", err)
	}
	d := &Deps{Spells: spells}
	team := d.buildChallengeTeam(1, practiceArena.startCells(1), 33, 2)

	if team.Session() != nil {
		t.Error("challenge team must have no Session (else it never readies and gets no AI)")
	}
	if team.Coach() == nil || team.Coach().ID != challengeCoachID {
		t.Errorf("challenge team coach = %+v, want synthetic id %d", team.Coach(), challengeCoachID)
	}
	// The opponent coach carries the demon's own name (Chikchan since S26:
	// the 12th-minute demon); each fighter is named by
	// its breed so the fight is legible.
	if team.Coach().Name != "Chikchan" {
		t.Errorf("challenge 33 coach name = %q, want the 12th-minute demon's name", team.Coach().Name)
	}
	for i, ff := range team.Fighters {
		if want := fighterBreedName(ff.Fighter.BreedID); ff.Fighter.Name != want {
			t.Errorf("fighter %d name = %q, want breed name %q", i, ff.Fighter.Name, want)
		}
	}
	if team.Coach().ID == sparringCoachID {
		t.Error("challenge coach id collides with the sparring coach id")
	}
	if len(team.Fighters) != 4 {
		t.Fatalf("challenge 33 fighters = %d, want 4", len(team.Fighters))
	}
	seen := map[int64]bool{}
	for i, ff := range team.Fighters {
		if seen[ff.WireID] {
			t.Errorf("fighter %d: duplicate wire id %d", i, ff.WireID)
		}
		seen[ff.WireID] = true
		if ff.HP <= 0 || ff.MaxHP <= 0 {
			t.Errorf("fighter %d: HP %d/%d, want > 0", i, ff.HP, ff.MaxHP)
		}
		if ff.AP <= 0 || ff.MP <= 0 {
			t.Errorf("fighter %d: AP/MP %d/%d, want > 0", i, ff.AP, ff.MP)
		}
		if ff.TeamID != 1 {
			t.Errorf("fighter %d: team %d, want 1", i, ff.TeamID)
		}
		if ff.SummonSpellID == 0 {
			t.Errorf("fighter %d (breed %d): no spell — the AI would just block",
				i, ff.Fighter.BreedID)
		}
		if ff.isSummon() {
			t.Errorf("fighter %d: must not look like a summon (Father set)", i)
		}
		// A demon fights from a repertoire, not one spell. Every breed in the
		// shipped table has at least two damaging spells, and the loadout is
		// capped like a real fighter's.
		if n := len(ff.Fighter.Spells); n < 2 || n > maxFighterSpells {
			t.Errorf("fighter %d (breed %d): %d spells, want 2..%d",
				i, ff.Fighter.BreedID, n, maxFighterSpells)
		}
		// The archetype spell must be castable too, or classifyAI and the
		// repertoire would disagree about what this fighter does.
		if !fighterKnowsSpell(ff, ff.SummonSpellID) {
			t.Errorf("fighter %d: does not know its own SummonSpellID %d", i, ff.SummonSpellID)
		}
	}
	// Wire ids must not collide with a different challenge's team.
	other := d.buildChallengeTeam(1, practiceArena.startCells(1), 32, 2)
	for _, a := range team.Fighters {
		for _, b := range other.Fighters {
			if a.WireID == b.WireID {
				t.Errorf("wire id %d shared between challenge 33 and 32", a.WireID)
			}
		}
	}
}

// TestTrialChallengesFieldTheirOwnTeams (S26): the twelve challenges brought
// into Historia chapters 4 and 5 field their authored teams, not the mirror
// fallback, and every one is a story challenge.
func TestTrialChallengesFieldTheirOwnTeams(t *testing.T) {
	for id, want := range trialChallengeBreeds {
		got := challengeOpponentBreeds(id, 1)
		if len(got) != len(want) {
			t.Errorf("challenge %d fields %v, want %v", id, got, want)
		}
		if !isStoryChallenge(id) {
			t.Errorf("challenge %d is not in a Historia chapter", id)
		}
	}
}
