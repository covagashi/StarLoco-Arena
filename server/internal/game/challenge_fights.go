package game

import (
	"sort"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/store"
)

// challenge_fights.go builds the opponent side of a CHALLENGE fight — the
// scripted PvE fights behind the overworld's DemonChallenge and BreedMaster
// elements (both send C2S 26330 [i32 challengeId][i16 99]).
//
// Why the server invents this: the client's challenge table (data.bdat type
// 400) carries only presentation data — name, description, rewards, time limit.
// Its loader discards everything else, so there is NO opponent roster anywhere
// in the client and nothing it can render that would contradict us. The team we
// build here is authoritative, and arrives through the ordinary fight messages
// (8000 CREATE_FIGHT + actor spawns) exactly like a coach's team.
//
// The opponents are session-less, which is what makes them work for free: the
// fight engine already pre-marks a session-less team ready in every phase gate
// (startFightWithTeams) and hands its fighters to the built-in AI each turn
// (Fight.isAIControlled -> runAITurn). See ai.go.

// The CREATE_FIGHT (8000) fight KIND. It travels in the message's first i32 and
// the client reads it back as aKl(); the i8 that looks like a kind byte is never
// read at all. See buildCreateFight and BUGS.md B-095.
//
// fightKindNormal is everything ordinary: ranked, practice and challenge-free.
const fightKindNormal int32 = 1

// fightKindTournament (aKl()==3) makes the client take its tournament result
// path. Unused until the tournament live-match layer exists.
const fightKindTournament int32 = 3

// fightKindChallenge marks a challenge fight. The client gates its end-of-fight
// challenge reward/XP panel on aKl() == 5 (WE, case 8300) and resolves the
// challenge itself with ahy_1.axg().dC(asy()).
const fightKindChallenge int32 = 5

// fightKindEvolution is the LETHAL
// evolution fight (client aKl()==6): the client opens its evolution result
// dialog, and — the functional part — downed fighters persist as dead. See
// persistEvolutionDeaths.
const fightKindEvolution int32 = 6

// challengeCoachID is the synthetic coach id owning every challenge opponent
// team. Like sparringCoachID it sits far above any real DB coach id so it can
// never collide with a live coach; it is never persisted and holds no session.
const challengeCoachID uint = 1<<31 + 1

// --- challenge completion -----------------------------------------------------
//
// Completion is entirely SERVER-owned. The client has no challenge->criterion
// mapping and never writes these: a grep of every or_0.<C>.tI() use finds zero
// writes of 213..217, and the end-of-fight path (WE, case 8300) only *displays*
// challenge data — it sends no 22003. So if the server doesn't record a
// completion, nothing does.
//
// Two separate concerns, deliberately kept in two id ranges:
//
//   - CLIENT criteria (or_0 enum ids, <= handshake.MaxCriterionID). The client
//     reads these to gate content. They ride in the 2052 descriptor's 0x200 blob.
//   - SERVER bookkeeping (statChallengeDoneBase + challengeId). Used only to
//     decide whether a challenge has already paid out. Sits above the criterion
//     enum so it can never collide, and is filtered out of the 2052 blob.

// challengeCriterion maps a minute-demon challenge to the client criterion that
// records beating it. Recovered by matching the or_0 enum's French descriptions
// against each challenge's content.30.<id> name — the mapping exists nowhere in
// the data files:
//
//	214 "a terminé le défi du premier démon des minutes"   <-> challenge 34 "Premier Défi des minutes"
//	215 "...deuxième..."                                   <-> challenge 35
//	216 "...troisième..."                                  <-> challenge 36
//	217 "...quatrième..."                                  <-> challenge 32
//
// These four ARE the definition of achievement 278, which is what the client
// checks before letting the 12th-minute boss (challenge 33) be fought at all —
// so setting them is what makes that boss reachable.
var challengeCriterion = map[int32]uint16{
	34: 214,
	35: 215,
	36: 216,
	32: 217,
	// The Demon III chain (S10): "défi N du démon III en mode évolution
	// réussi". They are achievements 280 (198), 281 (199) and 284 (all
	// three), which open the next challenge of the chain (QB) and fire the
	// tutorial scenarios 105/106/107 on the client.
	29: 198,
	30: 199,
	31: 200,
	// 226 "asked Baan for the basics of combat" (achievement 446): the
	// "Tutorial de Baan" challenge is those basics.
	46: 226,
}

// criterionAllMinuteDemons is or_0 213, "the player finished all the minute-demon
// challenges" — the aggregate over the four above PLUS the boss (33). Criterion
// 218 ("spoke to Demon I after finishing the 5") is client-set (arw), not ours.
const criterionAllMinuteDemons uint16 = 213

// minuteDemonChallenges are the five challenges criterion 213 aggregates.
var minuteDemonChallenges = []int32{34, 35, 36, 32, 33}

// statChallengeDoneBase namespaces the server's own per-challenge completion
// flags: stat id = base + challengeId. Chosen above handshake.MaxCriterionID
// (1007) so it can never collide with a real client criterion; these are stored
// but never sent (buildCriteriaBlob drops anything above that ceiling).
const statChallengeDoneBase int16 = 2000

// challengeDoneStat is the bookkeeping stat id for one challenge.
func challengeDoneStat(challengeID int32) int16 {
	return statChallengeDoneBase + int16(challengeID)
}

// isSyntheticCoach reports whether a coach id belongs to a server-invented
// fight opponent (the "Tester" sparring partner or a challenge's opponent side)
// rather than a real DB row. Reward and persistence paths must skip these: they
// have no account, and writing to their id would create orphan inventory rows.
//
// Note this is NOT the same test as "has no Session" — a real coach that
// disconnected mid-fight also has no session, and must still be paid if it wins.
func isSyntheticCoach(coachID uint) bool {
	return coachID == sparringCoachID || coachID == challengeCoachID || coachID == ghostCoachID ||
		coachID == offlineCoachID || coachID == recorderCoachID
}

// breedMasterChallenge maps the twelve BreedMaster "test this breed" challenges
// to the breed each master teaches. Read off the world-35 BreedMaster element
// descriptors, whose shape is `nameId;?;154;breedId;challengeId`:
//
//	176;155;154;8;17  -> challenge 17 = Iop(8)      173;161;154;11;21 -> 21 = Sacrier(11)
//	177;158;154;1;18  -> challenge 18 = Feca(1)     178;157;154;3;22  -> 22 = Enutrof(3)
//	175;159;154;2;19  -> challenge 19 = Osamodas(2) 174;166;154;12;23 -> 23 = Pandawa(12)
//	171;160;154;4;20  -> challenge 20 = Sram(4)     179;163;154;7;24  -> 24 = Eniripsa(7)
//	170;165;154;5;25  -> challenge 25 = Xelor(5)    180;162;154;6;27  -> 27 = Ecaflip(6)
//	181;156;154;9;26  -> challenge 26 = Cra(9)      172;164;154;10;28 -> 28 = Sadida(10)
//
// This matches the type-400 table, where 17..28 are twelve consecutive records
// sharing the shape [45, 33..44, 36, 0, 5, 0].
var breedMasterChallenge = map[int32]uint8{
	17: 8, 18: 1, 19: 2, 20: 4, 21: 11, 22: 3,
	23: 12, 24: 7, 25: 5, 26: 9, 27: 6, 28: 10,
}

// demonChallengeBreeds are the breeds fielded by the overworld's demon
// challenges. The five "minute demons" (Totem Arena / world 79) and world 23's
// Barnaby demon are the only DemonChallenge elements we spawn.
//
// Composition is ours to choose (see the file header), so it is picked to be
// legible rather than arbitrary: each demon fields a themed trio/pair, and the
// gated boss (challenge 33, "Démon de la 12ème minute", which the client only
// offers once the other four are beaten) fields the largest team.
var demonChallengeBreeds = map[int32][]uint8{
	34: {8, 11},        // Imix, 58th minute — bruisers (Iop, Sacrier)
	35: {9, 5},         // 52ème minute — ranged (Cra, Xelor)
	36: {4, 7},         // 46ème minute — Sram + Eniripsa
	32: {2, 10, 6},     // 25ème minute — summoners (Osamodas, Sadida, Ecaflip)
	33: {8, 11, 5, 12}, // 12ème minute — the gated boss
	45: {1, 3},         // 37ème seconde (world 23) — Feca, Enutrof
}

// trialChallengeBreeds are the twelve challenges no element ever spawned (they
// lived on islands this lobby dropped), brought into Historia as chapters 4
// and 5 in S26. Themed on each challenge's name, growing towards the last.
var trialChallengeBreeds = map[int32][]uint8{
	6:  {1, 8, 7},     // Positioning, Strength and Medicine — Feca, Iop, Eniripsa
	9:  {11, 4},       // Bomberdoll — Sacrier, Sram
	11: {8, 9},        // The Mega Crackler — Iop, Cra
	15: {5, 6, 10},    // Xelorite Space-Time Paradox — Xelor, Ecaflip, Sadida
	37: {4, 10},       // Time: Poison — Sram, Sadida
	38: {8, 11, 12},   // Time: Violence — Iop, Sacrier, Pandawa
	39: {9, 5},        // Time: Death Bridge — Cra, Xelor
	40: {6, 3},        // Time: Cawotte — Ecaflip, Enutrof
	41: {12, 2},       // Time: Lake — Pandawa, Osamodas
	42: {4, 9, 5},     // Time: Foggy Quay — Sram, Cra, Xelor
	43: {7, 1, 12},    // Time: Altruism — Eniripsa, Feca, Pandawa
	44: {8, 11, 9, 4}, // Time: 5 Seconds — the last one
}

// defaultChallengeBreeds is the fallback for a challenge that is real (present
// in the type-400 table) but has no hand-authored composition — the ~21 records
// no element we spawn references. Mirroring the player's team size keeps such a
// fight fair instead of trivially winnable or impossible.
var defaultChallengeBreeds = []uint8{8, 9, 1, 5}

// challengeOpponentBreeds picks the breeds the challenge fields. mirror is the
// player's team size, used only by the fallback.
func challengeOpponentBreeds(challengeID int32, mirror int) []uint8 {
	if breed, ok := breedMasterChallenge[challengeID]; ok {
		// A breed master tests you one-on-one, with the breed it teaches.
		return []uint8{breed}
	}
	if breeds, ok := demonChallengeBreeds[challengeID]; ok {
		return breeds
	}
	if breeds, ok := trialChallengeBreeds[challengeID]; ok {
		return breeds
	}
	if mirror < 1 {
		mirror = 1
	}
	if mirror > len(defaultChallengeBreeds) {
		mirror = len(defaultChallengeBreeds)
	}
	return defaultChallengeBreeds[:mirror]
}

// breedName is the display name of each of the twelve breeds (client classes),
// used to label a challenge's opponent fighters legibly ("Iop", "Sacrieur")
// instead of an anonymous "Démon 1/2/3". Ids match breedTable / Breed.java.
var breedName = map[uint8]string{
	1: "Féca", 2: "Osamodas", 3: "Enutrof", 4: "Sram",
	5: "Xélor", 6: "Ecaflip", 7: "Eniripsa", 8: "Iop",
	9: "Crâ", 10: "Sadida", 11: "Sacrieur", 12: "Pandawa",
}

// fighterBreedName returns a breed's display name, or a neutral fallback so a
// fighter is never nameless.
func fighterBreedName(breedID uint8) string {
	if n, ok := breedName[breedID]; ok {
		return n
	}
	return "Champion"
}

// demonChallengeName is the opponent-coach name shown in the fight UI for each
// demon challenge. Since S26 (owner, 2026-10-25) the time demons carry Maya
// day signs (tzolk'in) in the order they are fought, one name in every
// language; the client renames them the same way (godot npc_rename.gd). The
// retail names were "Démon de la 58ème minute" … and "… 37ème seconde".
var demonChallengeName = map[int32]string{
	34: "Imix",     // 58th minute
	35: "Ik'",      // 52nd minute
	36: "Ak'bal",   // 46th minute
	32: "K'an",     // 25th minute
	33: "Chikchan", // 12th minute, the gated boss
	45: "Kimi",     // 37th second (Barnaby)
}

// challengeOpponentName labels the opponent coach shown in the fight UI: the
// demon's own name for a demon challenge, the breed-master label otherwise.
func challengeOpponentName(challengeID int32) string {
	if name, ok := demonChallengeName[challengeID]; ok {
		return name
	}
	if _, ok := breedMasterChallenge[challengeID]; ok {
		return "Maître d'élevage"
	}
	if _, ok := demonChallengeBreeds[challengeID]; ok {
		return "Démon"
	}
	return "Défi"
}

// recordChallengeVictory is the whole victory side of a challenge: it records
// completion, sets the client criteria that gate later content, and pays the
// reward cards — but only the FIRST time. A repeat win is idempotent: criteria
// stay set, no further cards.
//
// Unsolicited criteria changes reach the client only in the 2052 descriptor, so
// a newly-set criterion becomes visible on its next coach load. That is fine for
// these: the only consumer is the 12th-minute boss's gate, which the client
// re-evaluates from its local set on each click. (Opcode 22002 carries the same
// data but must only ever be sent as the REPLY to 22001 — see
// protocol.OpStatisticData and BUGS.md B-105.)
// Returns the card ids actually granted, so the caller can show them on the
// end-of-fight panel ("Cartes gagnées"). Empty on a repeat clear.
func (d *Deps) recordChallengeVictory(coachID uint, sess *Session, challengeID int32) []int32 {
	if d.Store == nil || challengeID == 0 {
		return nil
	}
	first := !d.challengeAlreadyDone(coachID, challengeID)

	// Always (re)assert the criteria — cheap, idempotent, and it self-heals a
	// coach whose flags were lost or who completed a challenge before this
	// tracking existed.
	if crit, ok := challengeCriterion[challengeID]; ok {
		d.setCriterion(coachID, int16(crit), 1)
	}
	if err := d.Store.Coaches.UpsertStat(coachID, challengeDoneStat(challengeID), 1); err != nil {
		d.Log.Warn("record challenge completion", "coach", coachID,
			"challenge", challengeID, "err", err)
	}
	// The aggregate flag needs the completion set above to be visible, so it is
	// evaluated last.
	d.maybeSetAllMinuteDemons(coachID)

	// Criteria just moved, so achievements may have completed. Runs after the
	// aggregate flag so a challenge that finishes a set unlocks in the same pass.
	if sess != nil {
		sess.evaluateAchievements()
	}

	if !first {
		d.Log.Info("challenge re-cleared; no repeat reward",
			"coach", coachID, "challenge", challengeID)
		return nil
	}
	granted := d.awardChallengeRewards(coachID, sess, challengeID)
	if len(granted) == 0 {
		// No card to pay: the first clear pays tokens instead (S26).
		d.creditTokens(coachID, sess, challengeTokenReward, "challenge first clear")
	}
	return granted
}

// challengeAlreadyDone reports whether this coach has cleared the challenge
// before. On a store error it answers false (pay out rather than silently
// withhold a reward the player earned).
func (d *Deps) challengeAlreadyDone(coachID uint, challengeID int32) bool {
	c, err := d.Store.Coaches.Get(coachID)
	if err != nil {
		return false
	}
	want := challengeDoneStat(challengeID)
	for _, st := range c.Stats {
		if st.StatID == want && st.Value > 0 {
			return true
		}
	}
	return false
}

// maybeSetAllMinuteDemons sets criterion 213 once all five minute demons are
// cleared. No-op until then.
func (d *Deps) maybeSetAllMinuteDemons(coachID uint) {
	c, err := d.Store.Coaches.Get(coachID)
	if err != nil {
		return
	}
	done := make(map[int16]bool, len(c.Stats))
	for _, st := range c.Stats {
		if st.Value > 0 {
			done[st.StatID] = true
		}
	}
	for _, id := range minuteDemonChallenges {
		if !done[challengeDoneStat(id)] {
			return
		}
	}
	d.setCriterion(coachID, int16(criterionAllMinuteDemons), 1)
}

// setCriterion persists one client criterion. Errors are logged, never
// propagated — a criterion must not break fight teardown.
func (d *Deps) setCriterion(coachID uint, id int16, value int32) {
	if err := d.Store.Coaches.UpsertStat(coachID, id, value); err != nil {
		d.Log.Warn("set criterion", "coach", coachID, "criterion", id, "err", err)
		return
	}
	d.Log.Info("criterion set", "coach", coachID, "criterion", id, "value", value)
}

// awardChallengeRewards grants the challenge's reward cards to a victorious
// coach and pushes the refreshed inventory so they appear without a relog.
//
// The card list comes straight from the type-400 record (verified: every value
// resolves in the type-100 card table). Duplicates in the list stack, so the
// grant is aggregated per template.
//
// Errors are logged, never propagated — a reward must not break fight teardown.
// Safe to call from the fight-actor goroutine: it only touches the store and
// does one Send, mirroring awardFightWin.
//
// Called only for a FIRST clear; see recordChallengeVictory.
func (d *Deps) awardChallengeRewards(coachID uint, sess *Session, challengeID int32) []int32 {
	if d.Store == nil {
		return nil
	}
	ch := d.ChallengeDefs.Get(challengeID)
	if ch == nil || len(ch.RewardCards) == 0 {
		return nil // plenty of challenges award nothing (e.g. all twelve breed masters)
	}
	// Filter rewards that name a card the game does not ship. The real table has
	// such a dangling reference — challenges 9 and 37 both award card 184, which
	// is in neither the coach-card (type 100) nor fighter-card (type 250) table —
	// and inserting it would leave an inventory row the client cannot render.
	qty := make(map[int32]int16, len(ch.RewardCards))
	for _, id := range ch.RewardCards {
		if d.Cards != nil && d.Cards.Get(id) == nil {
			d.Log.Warn("challenge reward names an unknown card; skipping",
				"challenge", challengeID, "card", id)
			continue
		}
		qty[id]++
	}
	if len(qty) == 0 {
		return nil
	}
	grants := make([]store.GrantCard, 0, len(qty))
	for id, n := range qty {
		grants = append(grants, store.GrantCard{TemplateID: id, Quantity: n})
	}
	if err := d.Store.Coaches.GrantCards(coachID, grants); err != nil {
		d.Log.Warn("award challenge rewards", "coach", coachID,
			"challenge", challengeID, "err", err)
		return nil
	}
	// The granted list, expanded by quantity — the panel shows one card icon per
	// copy won, not one per distinct template.
	granted := make([]int32, 0, len(ch.RewardCards))
	for id, n := range qty {
		for i := int16(0); i < n; i++ {
			granted = append(granted, id)
		}
	}
	sort.Slice(granted, func(i, j int) bool { return granted[i] < granted[j] })
	d.Log.Info("awarded challenge rewards", "coach", coachID,
		"challenge", challengeID, "cards", ch.RewardCards)
	if sess == nil {
		return granted
	}
	fresh, err := d.Store.Coaches.Get(coachID)
	if err != nil {
		return granted
	}
	if sess.Coach != nil {
		sess.Coach.SetInventory(fresh.Inventory)
	}
	if err := sess.pushInventory(fresh); err != nil {
		d.Log.Warn("push inventory after challenge reward", "coach", coachID, "err", err)
	}
	return granted
}

// breedSpellRepertoire is the spell loadout an AI-controlled challenge fighter of
// this breed fights with, strongest first, capped like a real coach fighter's.
//
// A demon used to carry exactly ONE spell (pickBreedSpell) and cast it for the
// whole fight, which made every challenge predictable. A real fighter of the same
// breed picks up to maxFighterSpells, so giving demons the same budget is both
// more authentic and the point of the AI repertoire work.
//
// Same filter as pickBreedSpell — the breed's spells that deal damage and cost
// AP — so the two can never disagree about what is usable. Ordered by damage
// descending, ties by id, so the cap keeps the most useful spells and the result
// is deterministic. Measured against the shipped table, breeds have 1-7 such
// spells (typically 3-4), so the cap only ever trims breed 11.
func breedSpellRepertoire(spells *gamedata.Spells, breedID uint8) []domain.FighterSpell {
	if spells == nil {
		return nil
	}
	type cand struct {
		id  int32
		dmg int32
	}
	var cands []cand
	for id, sp := range spells.All() {
		if sp == nil || sp.BreedID != int32(breedID) || sp.AP <= 0 {
			continue
		}
		dmg, _, ok := sp.Damage()
		if !ok {
			continue
		}
		cands = append(cands, cand{id: id, dmg: dmg})
	}
	sort.Slice(cands, func(i, j int) bool {
		if cands[i].dmg != cands[j].dmg {
			return cands[i].dmg > cands[j].dmg
		}
		return cands[i].id < cands[j].id
	})
	if len(cands) > maxFighterSpells {
		cands = cands[:maxFighterSpells]
	}
	out := make([]domain.FighterSpell, 0, len(cands))
	for i, c := range cands {
		out = append(out, domain.FighterSpell{Slot: int16(i), SpellID: c.id})
	}
	return out
}

// pickBreedSpell chooses the spell an AI-controlled challenge fighter of this
// breed casts. The AI derives its whole behaviour from this one spell
// (classifyAI: a damaging spell -> aggressive/kite, none -> a passive blocker),
// so leaving it at 0 would make every challenge a fight against statues.
//
// The choice is made from the REAL spell table rather than hardcoded: among the
// breed's damaging spells, take the cheapest castable one (lowest AP), breaking
// ties by lowest id so it is deterministic across runs. Returns 0 when there is
// no spell data or the breed has no damaging spell, which the AI handles as a
// blocker.
func pickBreedSpell(spells *gamedata.Spells, breedID uint8) int32 {
	if spells == nil {
		return 0
	}
	type cand struct {
		id int32
		ap int8
	}
	var best []cand
	for id, sp := range spells.All() {
		if sp == nil || sp.BreedID != int32(breedID) {
			continue
		}
		if _, _, ok := sp.Damage(); !ok {
			continue
		}
		if sp.AP <= 0 {
			continue
		}
		best = append(best, cand{id: id, ap: sp.AP})
	}
	if len(best) == 0 {
		return 0
	}
	sort.Slice(best, func(i, j int) bool {
		if best[i].ap != best[j].ap {
			return best[i].ap < best[j].ap
		}
		return best[i].id < best[j].id
	})
	return best[0].id
}

// buildChallengeTeam creates the session-less opponent team for a challenge.
// Each fighter is a breed base stat line armed with one breed-appropriate spell
// so the built-in AI plays it (see pickBreedSpell).
func (d *Deps) buildChallengeTeam(side uint8, cells []Pos, challengeID int32, mirror int) *FightTeam {
	breeds := challengeOpponentBreeds(challengeID, mirror)
	coach := &domain.Coach{ID: challengeCoachID, Name: challengeOpponentName(challengeID)}
	team := &FightTeam{ID: side, Members: []*FightMember{{Coach: coach}}}

	for i, breedID := range breeds {
		pos := Pos{}
		if len(cells) > 0 {
			pos = cells[i%len(cells)]
		}
		// Name each opponent by its breed ("Iop", "Crâ") so the fight is legible;
		// the demon teams have no duplicate breeds, so these stay distinct. The
		// coach block carries the demon's own name (challengeOpponentName).
		fr := &domain.Fighter{
			Name:    fighterBreedName(breedID),
			BreedID: breedID,
			// The AI's full repertoire (see ai.go). SummonSpellID below still
			// selects the ARCHETYPE from the cheapest damaging spell, exactly as
			// before; this widens what it may actually cast during the turn.
			Spells: breedSpellRepertoire(d.Spells, breedID),
		}
		st := computeFighterStats(fr, nil) // no equipped cards: breed base only
		ff := &FightFighter{
			// Distinct from both real fighters (fighter id * 16) and the sparring
			// dummy: challenge fighters are keyed off the challenge id.
			WireID:  FighterWireIDBase + int64(challengeID)*1024 + int64(side)*8 + int64(i),
			CoachID: challengeCoachID,
			TeamID:  side,
			Fighter: fr,
			Pos:     pos,
			MaxHP:   st.MaxHP, HP: st.MaxHP,
			MaxAP: st.MaxAP, AP: st.MaxAP,
			MaxMP: st.MaxMP, MP: st.MaxMP,
			Init: st.Init, Range: st.Range,
			CritRate: st.CritRate, FumbleRate: st.FumbleRate,
			Block: st.Block, Dodge: st.Dodge,
			// SummonSpellID is the AI's "the one spell this fighter casts" hook. The
			// name is summon-era; ai.go reads it for every AI-controlled fighter.
			SummonSpellID: pickBreedSpell(d.Spells, breedID),
		}
		team.Fighters = append(team.Fighters, ff)
	}
	return team
}

// challengeUnlocked reports whether the coach may play a challenge: one with a
// linked achievement (QB, afz_0's "achievementLinkedCompleted" — 30 needs 280,
// 31 needs 281) only once that achievement is complete. Evaluated from the
// definition against the coach's criteria rather than from the announced
// achievements, which are only recorded while the coach is online.
func (d *Deps) challengeUnlocked(coachID uint, def *gamedata.Challenge) bool {
	if def == nil || def.LinkedAchievement == 0 || d.Achievements == nil || d.Store == nil {
		return true
	}
	a := d.Achievements.Get(def.LinkedAchievement)
	if a == nil {
		return true
	}
	c, err := d.Store.Coaches.Get(coachID)
	if err != nil || c == nil {
		return false
	}
	stat, hasCard := coachAchievementLookups(c, nil)
	return a.Done(stat, hasCard)
}

// awardChallengeXP pays a challenge's tutorial XP (QC) to each of the coach's
// fighters in the fight, up to the challenge's limit (QD) of total XP: 29/30/31
// pay 1/2/3 up to 1/10/15, Barnaby's 45 pays 5 up to 300. Challenge fights skip
// the post-fight META pass (fightFeedsProgression), so this is their only XP,
// and the limit is what stops it being farmed.
func (d *Deps) awardChallengeXP(f *Fight, t *FightTeam, mem *FightMember) {
	if d.ChallengeDefs == nil || d.Store == nil {
		return
	}
	def := d.ChallengeDefs.Get(f.ChallengeID)
	if def == nil || def.XP <= 0 {
		return
	}
	for _, ff := range ownFighters(t, mem) {
		if ff == nil || ff.Fighter == nil || ff.Fighter.ID == 0 {
			continue
		}
		fr := ff.Fighter
		d.refreshAccumulatingFields(fr)
		gain := def.XP
		if def.XPLimit > 0 {
			if room := def.XPLimit - fr.TotalXP; room < gain {
				gain = room
			}
		}
		if gain <= 0 {
			continue
		}
		fr.XP += gain
		fr.TotalXP += gain
		if err := d.Store.Fighters.SaveProgress(fr); err != nil {
			d.Log.Warn("challenge xp", "fighter", fr.ID, "err", err)
			continue
		}
		d.Log.Info("challenge xp", "challenge", f.ChallengeID, "fighter", fr.Name, "xp", gain)
	}
}
