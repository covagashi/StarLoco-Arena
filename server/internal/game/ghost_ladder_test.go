package game

import (
	"encoding/json"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
)

// TestFillerGhosts: twelve server-made ghosts, made once, each a legal mix of
// distinct breeds armed with its breed's spells and two rules the gambit
// parser accepts, rated 700 to 1360.
func TestFillerGhosts(t *testing.T) {
	d, st, _ := ghostFixture(t)
	spells, err := openRealGameData(t).LoadSpells()
	if err != nil {
		t.Fatal(err)
	}
	d.Spells = spells
	d.ensureFillerGhosts()
	d.ensureFillerGhosts() // once
	n, _ := st.Ghosts.CountFillers()
	if n != fillerGhostCount {
		t.Fatalf("fillers = %d, want %d", n, fillerGhostCount)
	}
	all, _ := st.Ghosts.Candidates()
	for _, c := range all {
		g, _ := st.Ghosts.Get(c.ID)
		var roster []domain.Fighter
		_ = json.Unmarshal([]byte(g.Roster), &roster)
		seen := map[uint8]bool{}
		for _, fr := range roster {
			if seen[fr.BreedID] || len(fr.Spells) == 0 {
				t.Errorf("filler %q: breed %d repeated or without spells", g.Name, fr.BreedID)
			}
			seen[fr.BreedID] = true
		}
		team, err := d.buildGhostTeam(1, nil, g)
		if err != nil {
			t.Fatalf("filler %q does not field: %v", g.Name, err)
		}
		for i, ff := range team.Fighters {
			if ff.Gambits == nil {
				t.Errorf("filler %q fighter %d: rules refused", g.Name, i)
			}
		}
		if g.EloGhost < 700 || g.EloGhost > 1360 {
			t.Errorf("filler %q rated %d", g.Name, g.EloGhost)
		}
	}
}

// TestPickGhostFor: a player's ghost inside the band beats a nearer filler;
// outside it the nearest of all wins; never the challenger's own.
func TestPickGhostFor(t *testing.T) {
	d, st, coach := ghostFixture(t)
	mk := func(owner uint, elo int32) uint {
		g := &domain.GhostTeam{CoachID: owner, Name: "g", Roster: "[]", EloGhost: elo}
		_ = st.Ghosts.Create(g)
		return g.ID
	}
	filler := mk(domain.GhostFillerCoach, 1010)
	player := mk(999, 1150)
	own := mk(coach.ID, 1000)
	if g := d.pickGhostFor(coach.ID, 1000); g == nil || g.ID != player {
		t.Errorf("rating 1000: want the player's ghost within %d, got %+v", ghostMatchBand, g)
	}
	if g := d.pickGhostFor(coach.ID, 700); g == nil || g.ID != filler {
		t.Errorf("rating 700: want the nearest (the filler), got %+v", g)
	}
	if g := d.pickGhostFor(coach.ID, 1000); g != nil && g.ID == own {
		t.Error("matched against its own ghost")
	}
}

// TestGhostElo: an even win is +16; against a player's ghost both move by the
// same amount, against a filler only the challenger does, at half K; a replay
// moves nothing.
func TestGhostElo(t *testing.T) {
	if got := eloMove(1000, 1000, 1, ghostEloK); got != 16 {
		t.Errorf("even win = %+d, want +16", got)
	}
	if got := eloMove(1000, 1400, 0, ghostEloK); got != -3 {
		t.Errorf("expected loss to a far stronger side = %+d, want -3", got)
	}
	d, st, coach := ghostFixture(t)
	player := &domain.GhostTeam{CoachID: 999, Name: "p", Roster: "[]", EloGhost: 1000}
	filler := &domain.GhostTeam{CoachID: domain.GhostFillerCoach, Name: "f", Roster: "[]", EloGhost: 1000}
	_ = st.Ghosts.Create(player)
	_ = st.Ghosts.Create(filler)

	d.rateGhostFight(player.ID, coach.ID, 0) // we win
	me, _ := st.Ghosts.Rating(coach.ID)
	pg, _ := st.Ghosts.Get(player.ID)
	if me.Elo != 1016 || pg.EloGhost != 984 || me.Fights != 1 || me.Wins != 1 || pg.Battles != 1 || pg.Wins != 0 {
		t.Errorf("vs player: me %+v, ghost elo %d battles %d wins %d", me, pg.EloGhost, pg.Battles, pg.Wins)
	}
	d.rateGhostFight(filler.ID, coach.ID, 1) // we lose to the filler
	me, _ = st.Ghosts.Rating(coach.ID)
	fg, _ := st.Ghosts.Get(filler.ID)
	if fg.EloGhost != 1000 || fg.Wins != 1 {
		t.Errorf("a filler's rating must not move: %d (wins %d)", fg.EloGhost, fg.Wins)
	}
	if me.Elo != 1016-8 {
		t.Errorf("vs filler at half K: %d, want %d", me.Elo, 1016-8)
	}
	// a replay is recorded but not rated
	f := &Fight{seed: 1, ghost: &ghostFightInfo{ghostID: player.ID, challenger: coach.ID, replayOf: 1},
		arena: &practiceArena, deps: d}
	d.recordGhostFight(f, 0)
	again, _ := st.Ghosts.Rating(coach.ID)
	if again.Elo != me.Elo || again.Fights != me.Fights {
		t.Errorf("a replay moved the rating: %+v → %+v", me, again)
	}
}

// TestGhostLadder: best first, only coaches who fought, and RankOf agrees.
func TestGhostLadder(t *testing.T) {
	_, st, _ := ghostFixture(t)
	for _, r := range []domain.GhostRating{
		{CoachID: 10, Elo: 1100, Fights: 3}, {CoachID: 11, Elo: 1250, Fights: 5},
		{CoachID: 12, Elo: 900, Fights: 1}, {CoachID: 13, Elo: 2000, Fights: 0},
	} {
		if err := st.Ghosts.SaveRating(r); err != nil {
			t.Fatal(err)
		}
	}
	top, _ := st.Ghosts.Ladder(10)
	var ids []uint
	for _, r := range top {
		ids = append(ids, r.CoachID)
	}
	if len(ids) != 3 || ids[0] != 11 || ids[1] != 10 || ids[2] != 12 {
		t.Errorf("ladder = %v, want [11 10 12]", ids)
	}
	if rk, _ := st.Ghosts.RankOf(10); rk != 2 {
		t.Errorf("rank of 10 = %d, want 2", rk)
	}
	if rk, _ := st.Ghosts.RankOf(13); rk != 0 {
		t.Errorf("a coach with no fights is unranked, got %d", rk)
	}
	// SaveRating updates in place
	_ = st.Ghosts.SaveRating(domain.GhostRating{CoachID: 12, Elo: 1300, Fights: 2})
	if rk, _ := st.Ghosts.RankOf(12); rk != 1 {
		t.Errorf("after the update 12 leads, got rank %d", rk)
	}
}
