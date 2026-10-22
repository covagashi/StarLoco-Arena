package game

import (
	"path/filepath"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/store/storetest"
)

// statsDeps is a Deps on a real store with two persisted coaches.
func statsDeps(t *testing.T) (*Deps, *domain.Coach, *domain.Coach) {
	t.Helper()
	st, err := storetest.Open(t, filepath.Join(t.TempDir(), "stats.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })
	accA, _ := st.Accounts.CreateAccount("sa", "pw", false)
	accB, _ := st.Accounts.CreateAccount("sb", "pw", false)
	a, _ := st.Coaches.Create(accA.ID, "StatA", 0, 0, 0)
	b, _ := st.Coaches.Create(accB.ID, "StatB", 0, 0, 0)
	d := &Deps{Store: st, Fights: NewFightManager(), World: NewRegistry(150), Log: testLogger()}
	return d, a, b
}

// statsFight is a ranked 1v1 between a (team 0) and b (team 1), one fighter each.
func statsFight(a, b *domain.Coach, fa, fb *domain.Fighter) *Fight {
	mk := func(c *domain.Coach, fr *domain.Fighter, side uint8) *FightTeam {
		return &FightTeam{ID: side, Members: []*FightMember{{Coach: c}},
			Fighters: []*FightFighter{{WireID: FighterWireIDBase + int64(c.ID), CoachID: c.ID,
				TeamID: side, Fighter: fr, MaxHP: 100, HP: 100, AP: 6, MP: 3}}}
	}
	f := &Fight{Teams: [2]*FightTeam{mk(a, fa, 0), mk(b, fb, 1)},
		readyPresent: map[uint]bool{}, readyObserve: map[uint]bool{}, readyAction: map[uint]bool{}}
	f.Timeline = buildTimeline(f)
	f.setPhase(PhaseAction)
	return f
}

// win ends f with team `winner` standing.
func win(d *Deps, f *Fight, winner uint8) {
	d.Fights.Create(f)
	for _, ff := range f.allFighters() {
		if ff.TeamID != winner {
			ff.HP = 0
		}
	}
	d.checkFightEnd(f)
}

func TestRankedFightStatistics(t *testing.T) {
	d, a, b := statsDeps(t)
	a.Standing = 500
	b.Strength = 1500 // level 13 against a's unranked 0 / level 1 after the first fight
	feca := &domain.Fighter{ID: 9001, BreedID: 1, Budget: 2100, TotalXP: 900, XP: 40}
	iop := &domain.Fighter{ID: 9002, BreedID: 8, Budget: 1800}

	for i := 0; i < 3; i++ {
		win(d, statsFight(a, b, feca, iop), 0)
	}
	get := func(c *domain.Coach, id int16) int32 { return d.Store.Coaches.StatValue(c.ID, id) }
	if got := get(a, statWinStreak1v1); got != 3 {
		t.Errorf("1v1 streak = %d, want 3", got)
	}
	if got := get(a, statWonSolo); got != 3 {
		t.Errorf("won with a single fighter = %d, want 3", got)
	}
	if got := get(a, statBiggestFeca); got != 2100 {
		t.Errorf("biggest Feca (levels 1-20) = %d, want 2100", got)
	}
	if got := get(a, statMostXPSpent); got != 860 {
		t.Errorf("most XP spent = %d, want 860", got)
	}
	if got := get(a, statReputation); got != a.Standing || got <= 500 {
		t.Errorf("reputation = %d, want the coach's %d (500 plus what the fights paid)", got, a.Standing)
	}
	if got := get(a, statForce1v1); got != a.Strength || got == 0 {
		t.Errorf("max 1v1 force = %d, want %d", got, a.Strength)
	}
	// b started at level 13 and a at level 1 (unranked): a gap of 12 on the
	// first win, smaller after.
	if got := get(a, statLevelGap1v1); got != 12 {
		t.Errorf("level gap = %d, want 12", got)
	}
	if got := get(b, statBiggestFeca+7); got != 0 {
		t.Errorf("the loser's Iop was recorded: %d", got)
	}

	// A loss resets the current streak but keeps the best.
	win(d, statsFight(a, b, feca, iop), 1)
	win(d, statsFight(a, b, feca, iop), 0)
	if got := get(a, statWinStreak1v1); got != 3 {
		t.Errorf("best streak after a loss = %d, want 3", got)
	}
	if got := get(a, statServerStreakBase+streakMode1v1); got != 1 {
		t.Errorf("current streak = %d, want 1", got)
	}

	// A strong coach's Feca lands in the 20-40 variant.
	a.Strength = 2000
	win(d, statsFight(a, b, &domain.Fighter{ID: 9003, BreedID: 1, Budget: 2600}, iop), 0)
	if got := get(a, tieredStat(statBiggestFeca, 2000)); got != 2600 || tieredStat(statBiggestFeca, 2000) != 342 {
		t.Errorf("biggest Feca (levels 20-40) = %d at id %d, want 2600 at 342",
			got, tieredStat(statBiggestFeca, 2000))
	}

	// Practice and challenges keep no streak.
	before := get(a, statServerStreakBase+streakMode1v1)
	p := statsFight(a, b, feca, iop)
	p.Practice = true
	win(d, p, 0)
	if got := get(a, statServerStreakBase+streakMode1v1); got != before || before != 2 {
		t.Errorf("streak %d -> %d across a practice fight, want 2 -> 2", before, got)
	}
}

func TestGiveUpStatistics(t *testing.T) {
	d, a, b := statsDeps(t)
	f := statsFight(a, b, &domain.Fighter{ID: 9101, BreedID: 2}, &domain.Fighter{ID: 9102, BreedID: 3})
	d.Fights.Create(f)
	d.forfeitCoach(f, b.ID)
	if got := d.Store.Coaches.StatValue(b.ID, statLostByGiveUp); got != 1 {
		t.Errorf("lost by giving up = %d, want 1", got)
	}
	if got := d.Store.Coaches.StatValue(a.ID, statLostByGiveUp); got != 0 {
		t.Errorf("the winner was counted as giving up: %d", got)
	}
}

func TestEvolutionDeathAndWoundStatistics(t *testing.T) {
	d, a, b := statsDeps(t)
	f := statsFight(a, b, &domain.Fighter{ID: 9201, BreedID: 4}, &domain.Fighter{ID: 9202, BreedID: 5})
	f.Evolution = true
	d.recordFightStatistics(f, fightOutcome{winnerTeam: 0,
		deaths: map[uint]int32{b.ID: 2}, wounds: map[uint]int32{a.ID: 1, b.ID: 1}})
	want := map[int16][2]int32{ // stat: {a, b}
		statEvoDeathsTaken: {0, 2}, statEvoWoundsTaken: {1, 1},
		statEvoDeathsDealt: {2, 0}, statEvoWoundsDealt: {1, 1},
		statWinStreakEvo: {1, 0},
	}
	for id, w := range want {
		if ga, gb := d.Store.Coaches.StatValue(a.ID, id), d.Store.Coaches.StatValue(b.ID, id); ga != w[0] || gb != w[1] {
			t.Errorf("stat %d: a=%d b=%d, want %v", id, ga, gb, w)
		}
	}
}

// 171: in a 2v2, the coach that gives up while its ally plays on.
func TestGiveUpBeforeAllyIn2v2(t *testing.T) {
	d, a, b := statsDeps(t)
	accC, _ := d.Store.Accounts.CreateAccount("sc", "pw", false)
	accD, _ := d.Store.Accounts.CreateAccount("sd", "pw", false)
	c, _ := d.Store.Coaches.Create(accC.ID, "StatC", 0, 0, 0)
	e, _ := d.Store.Coaches.Create(accD.ID, "StatD", 0, 0, 0)
	f := statsFight(a, b, &domain.Fighter{ID: 9301, BreedID: 1}, &domain.Fighter{ID: 9302, BreedID: 2})
	join := func(t *FightTeam, co *domain.Coach, id uint) {
		t.Members = append(t.Members, &FightMember{Coach: co})
		t.Fighters = append(t.Fighters, &FightFighter{WireID: FighterWireIDBase + int64(co.ID), CoachID: co.ID,
			TeamID: t.ID, Fighter: &domain.Fighter{ID: id, BreedID: 3}, MaxHP: 100, HP: 100})
	}
	join(f.Teams[0], c, 9303)
	join(f.Teams[1], e, 9304)
	f.Timeline = buildTimeline(f)
	d.Fights.Create(f)
	d.forfeitCoach(f, b.ID)
	for _, w := range []struct {
		co   *domain.Coach
		want int32
	}{{b, 1}, {e, 0}, {a, 0}} {
		if got := d.Store.Coaches.StatValue(w.co.ID, statGaveUpFirst2v2); got != w.want {
			t.Errorf("%s: gave up before the ally = %d, want %d", w.co.Name, got, w.want)
		}
	}
	if got := d.Store.Coaches.StatValue(a.ID, statWinStreak2v2); got != 1 {
		t.Errorf("2v2 streak = %d, want 1", got)
	}
}
