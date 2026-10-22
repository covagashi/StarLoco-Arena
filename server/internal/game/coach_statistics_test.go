package game

import (
	"path/filepath"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store"
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

// The in-fight half (fight_statistics.go), through the real effect paths, then
// banked at the end of a ranked fight.
func TestInFightStatistics(t *testing.T) {
	d, a, b := statsDeps(t)
	f := statsFight(a, b, &domain.Fighter{ID: 9401, BreedID: 1}, &domain.Fighter{ID: 9402, BreedID: 2})
	f.deps = d
	fa, fb := f.Teams[0].Fighters[0], f.Teams[1].Fighters[0]
	fa.Pos, fb.Pos = Pos{X: 7, Y: 15}, Pos{X: 12, Y: 15}
	fb.MaxAP, fb.AP = 6, 6

	// Turn 1: 30 + 30 to the enemy and 20 to a's own fighter (not counted).
	f.applyHPDelta(fa, fb, 1, 0, -30)
	f.applyHPDelta(fa, fb, 1, 0, -30)
	f.applyHPDelta(fa, fa, 1, 0, -20)
	f.applyFighterMove(fa, []Pos{{X: 8, Y: 15}, {X: 9, Y: 15}})
	f.closeStatTurn()
	// Turn 2: 25 more, then the AP drain leaves b 4 AP short.
	f.applyHPDelta(fa, fb, 1, 0, -25)
	f.applyStatDrain(fa, gamedata.Effect{ActionID: 84, Params: []float32{4}}, fb.Pos, true, false)
	f.closeStatTurn()

	s := f.memberStats[a.ID]
	if s == nil {
		t.Fatal("no tally for the attacker")
	}
	if s.damage != 85 || s.bestTurnDamage != 60 || s.mpUsed != 2 || s.bestTurnMP != 2 || s.bestAPRemoved != 4 {
		t.Errorf("tally = %+v, want damage 85, best turn 60, MP 2/2, AP removed 4", *s)
	}
	if f.memberStats[b.ID] != nil && f.memberStats[b.ID].damage != 0 {
		t.Errorf("the victim was credited damage: %+v", *f.memberStats[b.ID])
	}

	// The killing blow, then the fight ends and the tally is banked.
	win(d, f, 0) // sets b's HP to 0 without a blow; the kill below is a's
	get := func(id int16) int32 { return d.Store.Coaches.StatValue(a.ID, id) }
	for id, want := range map[int16]int32{
		statFightDamage: 85, statTurnDamage: 60, statTurnMP: 2, statMPUsed: 2, statAPRemoved: 4,
	} {
		if got := get(id); got != want {
			t.Errorf("stat %d = %d, want %d", id, got, want)
		}
	}
}

func TestKillsTrapsAndDeathCells(t *testing.T) {
	d, a, b := statsDeps(t)
	f := statsFight(a, b, &domain.Fighter{ID: 9501, BreedID: 1}, &domain.Fighter{ID: 9502, BreedID: 2})
	f.deps = d
	fa, fb := f.Teams[0].Fighters[0], f.Teams[1].Fighters[0]
	f.applyHPDelta(fa, fb, 1, 0, -fb.HP) // a kill in this turn
	f.closeStatTurn()
	if s := f.memberStats[a.ID]; s.bestTurnKills != 1 {
		t.Errorf("kills in a turn = %d, want 1", s.bestTurnKills)
	}

	// A trap a placed kills b: credited to a, the area's owner.
	fb.HP = 100
	f.firingArea = &effectArea{caster: fa, tmpl: walkOnTrap()}
	f.applyHPDelta(fa, fb, 1, 0, -100)
	f.firingArea = nil
	if s := f.memberStats[a.ID]; s.trapKills != 1 {
		t.Errorf("trap kills = %d, want 1", s.trapKills)
	}
	// A killer cell: counted on the victim's coach.
	fb.HP = 100
	f.noteDeathCell(fb)
	if s := f.memberStats[b.ID]; s == nil || s.deathCells != 1 {
		t.Errorf("death-cell deaths for the victim = %+v, want 1", s)
	}
	// Practice banks none of it.
	f.Practice = true
	win(d, f, 0)
	if got := d.Store.Coaches.StatValue(a.ID, statTrapKills); got != 0 {
		t.Errorf("a practice fight banked %d trap kills", got)
	}
}

func TestBestResistanceIsElementPlusGeneral(t *testing.T) {
	var s combatStats
	s.resPct[1], s.resPct[2], s.resPctAll = 30, 45, 20
	if got := s.bestResistance(); got != 65 {
		t.Errorf("armour = %d, want 65 (45 + 20)", got)
	}
}

// A shield tile (world 5, 7,9) counts as a bonus cell and as armour.
func TestBonusCellAndArmourFromATile(t *testing.T) {
	f, ff := specialFight(Pos{X: 7, Y: 9})
	ff.CoachID = 77
	f.applyTurnStartSpecialCell(ff)
	s := f.memberStats[77]
	if s == nil || s.bonusCells != 1 || s.bestArmour != 10 {
		t.Errorf("tally = %+v, want 1 bonus cell and armour 10", s)
	}
}

// 161: an Eniripsa's close-combat blow that kills an enemy.
func TestEniripsaPunchKill(t *testing.T) {
	f, caster, enemy := trapTestFight()
	caster.CoachID, enemy.CoachID = 61, 62
	caster.Fighter = &domain.Fighter{ID: 1, BreedID: breedEniripsa}
	enemy.Pos = Pos{X: 8, Y: 15} // next to the caster at 7,15
	enemy.HP = 1
	f.closeCombat(caster, enemy.Pos)
	if enemy.HP > 0 {
		t.Skip("the blow fumbled or missed; the seed did not land a hit")
	}
	if s := f.memberStats[61]; s == nil || s.eniripsaPunches != 1 {
		t.Errorf("Eniripsa punch kills = %+v, want 1", s)
	}
	// A spell kill by the same Eniripsa does not count.
	enemy.HP = 1
	f.applyHPDelta(caster, enemy, 1, 0, -1)
	if s := f.memberStats[61]; s.eniripsaPunches != 1 {
		t.Errorf("a non-punch kill counted: %d", s.eniripsaPunches)
	}
}

func TestChallengeAndLadderStatistics(t *testing.T) {
	d, a, b := statsDeps(t)
	fight := func(challenge int32, spell bool) {
		f := statsFight(a, b, &domain.Fighter{ID: 9601, BreedID: 1}, &domain.Fighter{ID: 9602, BreedID: 2})
		f.ChallengeID, f.Practice = challenge, true
		if spell {
			f.stat(a.ID).castSpell = true
		}
		win(d, f, 0)
	}
	fight(challengeHellsTofus, false)
	fight(challengeHellsTofus, true)
	fight(challengeLimero, true)  // a spell: does not count
	fight(challengeLimero, false) // punches only
	get := func(id int16) int32 { return d.Store.Coaches.StatValue(a.ID, id) }
	if got := get(statHellsTofus); got != 2 {
		t.Errorf("Hell's tofus wins = %d, want 2", got)
	}
	if got := get(statLimeroByPunches); got != 1 {
		t.Errorf("Limero by punches = %d, want 1", got)
	}

	// A ranked 1v1 win puts a first on a two-coach ladder: 2500 - 1.
	win(d, statsFight(a, b, &domain.Fighter{ID: 9603, BreedID: 1}, &domain.Fighter{ID: 9604, BreedID: 2}), 0)
	if got := get(statLadderGap1v1); got != 2499 {
		t.Errorf("ladder gap = %d, want 2499", got)
	}

	// Serious wounds in evolution are counted on their own.
	f := statsFight(a, b, &domain.Fighter{ID: 9605, BreedID: 1}, &domain.Fighter{ID: 9606, BreedID: 2})
	f.Evolution = true
	d.recordFightStatistics(f, fightOutcome{winnerTeam: 0,
		wounds: map[uint]int32{a.ID: 3}, serious: map[uint]int32{a.ID: 2}})
	if got := get(statEvoSerious); got != 2 {
		t.Errorf("serious wounds = %d, want 2", got)
	}
}

func TestSessionStatistics(t *testing.T) {
	d, a, _ := statsDeps(t)
	s := &Session{log: testLogger(), deps: d, Coach: a}

	worn := []domain.CoachCard{{Pos: 1}, {Pos: 2}, {Pos: 10}, {Pos: 0}, {Pos: 13}}
	if got := wornItems(worn); got != 2 {
		t.Errorf("worn items = %d, want 2 (slot 0 and 1; the pet slot, the bag and slot 12 are not clothing)", got)
	}
	s.noteStat(statWornItems, 5, true)
	s.noteStat(statWornItems, 3, true)
	s.noteStat(statEvoConsumables, 1, false)
	s.noteStat(statEvoConsumables, 1, false)
	if w, c := d.Store.Coaches.StatValue(a.ID, statWornItems), d.Store.Coaches.StatValue(a.ID, statEvoConsumables); w != 5 || c != 2 {
		t.Errorf("worn best = %d, consumables = %d, want 5 / 2", w, c)
	}
}

// 220 through the real 6003 handler: deleting a living evolution fighter
// counts, a dead one and a plain one do not.
func TestDeletingALivingEvolutionFighter(t *testing.T) {
	d, a, _ := statsDeps(t)
	s := &Session{log: testLogger(), deps: d, Coach: a, out: make(chan []byte, writeQueueSize),
		quit: make(chan struct{})}
	mk := func(name string, evo bool, state uint8) uint {
		fr := &domain.Fighter{CoachID: a.ID, BreedID: 1, Name: name, Evolution: evo, State: state}
		if err := d.Store.Fighters.Create(fr); err != nil {
			t.Fatalf("create fighter: %v", err)
		}
		return fr.ID
	}
	for _, id := range []uint{
		mk("Living", true, domain.FighterStateTitular),
		mk("Fallen", true, domain.FighterStateDead),
		mk("Plain", false, domain.FighterStateTitular),
	} {
		payload := protocol.NewWriter().I64(int64(id)).Bytes()
		if err := handleFighterDelete(s, &protocol.C2SFrame{Payload: payload}); err != nil {
			t.Fatalf("delete %d: %v", id, err)
		}
	}
	if got := d.Store.Coaches.StatValue(a.ID, statEvoLivingDelete); got != 1 {
		t.Errorf("living evolution fighters deleted = %d, want 1", got)
	}
}

// 208 through useConsumableOnFighter with a real morale card: counted for an
// evolution fighter only.
func TestEvolutionConsumableCounts(t *testing.T) {
	d, a, _ := statsDeps(t)
	gd := openRealGameData(t)
	cards, err := gd.LoadCards()
	if err != nil {
		t.Fatal(err)
	}
	d.Cards = cards
	var morale int32
	for id, c := range cards.All() {
		if p, ok := c.EffectParam(aiMorale); ok && p > 0 && c.HasUsableAction {
			morale = id
			break
		}
	}
	if morale == 0 {
		t.Skip("no usable morale card in the data")
	}
	if err := d.Store.Coaches.GrantCards(a.ID, []store.GrantCard{{TemplateID: morale, Quantity: 2}}); err != nil {
		t.Fatal(err)
	}
	s := &Session{log: testLogger(), deps: d, Coach: a, out: make(chan []byte, writeQueueSize),
		quit: make(chan struct{})}
	for _, evo := range []bool{false, true} {
		fr := &domain.Fighter{CoachID: a.ID, BreedID: 1, Name: "Drinker", Evolution: evo, Morale: 10}
		_ = d.Store.Fighters.Create(fr)
		if err := s.useConsumableOnFighter(fr, morale); err != nil {
			t.Fatal(err)
		}
	}
	if got := d.Store.Coaches.StatValue(a.ID, statEvoConsumables); got != 1 {
		t.Errorf("evolution consumables = %d, want 1", got)
	}
}
