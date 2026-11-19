package game

import (
	"github.com/StarLoco/arena-2.70/content"
	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// breedBaseStats holds the per-breed base combat stats the retail client derives
// a fighter's characteristics from. Ported field-for-field from the client's
// Breed.java and verified LIVE against the 2.70 client's HP gauge: an Iop reads
// 75, a Feca 70.
//
// A fighter's real max HP is this base plus its equipped cards' HP bonuses; for a
// card-less fighter it is exactly the base. The server MUST use the same max HP
// the client derives, otherwise damage numbers and death timing desync — the
// server previously hardcoded HP=1000 while the client showed ~70, so a 200-point
// spell read as "1000 -> 800" server-side but "75 -> dead" client-side.
type breedBaseStats struct {
	HP, AP, MP, Init int32
	CCElement        int // close-combat (weapon) attack element; the AP cost + damage are uniform (see closeCombat* consts)
	// Block is the breed's chance to hold an adjacent enemy in place (client
	// characteristic Lr.brd, xq's 13th ctor arg -> DT()); Dodge is its chance to
	// slip away (Lr.bre, 14th arg -> DU()). See tackle.go.
	//
	// Dodge is 100 for EVERY breed, which the client's own help text states
	// independently: "Tous les personnages ont, de base, 100% en esquive" — a
	// clean cross-check that these two arguments are identified correctly.
	// Block varies and tracks class identity: Feca (the blocker) 60, Iop and
	// Pandawa 40, Sram and Sacrier 20, everyone else 0.
	Block, Dodge int32
}

// Close-combat ("corps-à-corps", the unarmed punch — opcode 8111) constants.
// VERIFIED uniform across breeds against the 2.70 client's own breed table (enum
// xq): every entry carries the same trio 5/5/7, exposed as DO()/DP()/DQ(). The
// client renders the tooltip "Corps à corps (N AP)" from xq.DO(), which is this
// AP cost.
//
// Close combat is deliberately weapon-INDEPENDENT: the client's close-combat
// targeting mode (agd_1) sends 8111 with only the fighter and the target cell —
// no card id — so an unarmed fighter can always punch. Attacking WITH a weapon is
// the separate FIGHTER_CARD_USE action (8107, fightercard_use.go), which uses the
// weapon's own AP cost, range and damage.
const (
	closeCombatAP          int32 = 5
	closeCombatDamages     int32 = 5
	closeCombatCritDamages int32 = 7
)

// breedTable maps breed id (1..12) -> base stats. Since S46 it is our data,
// server/content/rules/breeds.json (gamedata.Breed), read once at start-up.
//
// It started as the 2.70 client's own breed enum `xq`. The enum is obfuscated,
// but v2.04b ships the UNOBFUSCATED twin of the very same table (`Breed.java`),
// and the two line up argument for argument, which is what pinned each column:
//
//	           id  HP  AP  MP  INIT  crit  fumble  VALUE  element  ccAP ccDmg ccCrit
//	2.04b FECA  1  70   6   3    50     5       1    400    WATER     5    5      7
//	2.70  Feca  1  70   6   3    20     0       0    600    ban       5    5      7
//
// The client reached them as ok()=HP, ol()=AP, om()=MP, DK()=initiative,
// DN()=close-combat element, DO()/DP()/DQ()=the 5/5/7 close-combat trio. 2.70's
// initiatives are unique per breed (no ties); its close-combat elements split
// 3/3/3/3 (fire Xelor, Eniripsa, Pandawa; water Feca, Enutrof, Ecaflip; air
// Sram, Cra, Sacrier; earth Osamodas, Iop, Sadida).
var breedTable = loadBreedTable()

func loadBreedTable() map[uint8]breedBaseStats {
	bs, err := gamedata.LoadBreeds(content.Rules)
	if err != nil {
		panic(err) // embedded, so only a broken checkout gets here
	}
	m := map[uint8]breedBaseStats{}
	for _, b := range bs.All() {
		m[b.ID] = breedBaseStats{HP: b.HP, AP: b.AP, MP: b.MP, Init: b.Init,
			CCElement: b.CCElement, Block: b.Block, Dodge: b.Dodge}
	}
	return m
}

// Base critical/fumble rates (%), from the 2.70 client's breed table (xq's 6th and
// 7th ctor args -> DL()/DM() -> characteristics Lr.bqU/bqV, which ee_2 renders as
// "criticalHitBonus"/"criticalMissMalus"). Every 2.70 breed carries 0/0, where
// v2.04b carried 5/1.
//
// So in 2.70 crit is entirely EARNED, not innate: a fighter with no crit gear
// cannot land a critical hit. The value IS the percentage — the client's own help
// text says "Pourcentage de chance de faire un coup critique à chaque fois que le
// combattant lance un sort ou porte une attaque" — and the shipped data only makes
// sense that way: spells 144 and 425 grant **+100** crit for one turn, i.e. a
// guaranteed critical, which is only exactly-guaranteed if the base is 0.
//
// The sources that raise it (all action 70, all already wired through
// computeFighterStats / applyBuff):
//   - 5 fighter cards, permanently while equipped: +5, +10, +20, +20, +30
//   - self-buff spells (14: +15/+20 permanent; 144/425: +100 for a turn)
//   - 4 per-round event cards: +25, +25, +50, +100
//
// Action 71 lowers it the same way (spell 15: -100 for a turn = cannot crit).
const (
	baseCritRate   int32 = 0
	baseFumbleRate int32 = 0
)

// breedBase returns a breed's base stats, falling back to a neutral profile for
// unknown breeds (monsters/placeholders) so a fighter is never left with 0 HP or
// 0 AP/MP.
func breedBase(breedID uint8) breedBaseStats {
	if s, ok := breedTable[breedID]; ok {
		return s
	}
	return breedBaseStats{HP: 70, AP: 6, MP: 3, Init: 0}
}

// fighterMaxHP returns the base max HP the client displays for a breed. Unknown
// breeds (monsters/placeholders) fall back to a neutral 70 so a fight never has a
// 0-HP fighter.
func fighterMaxHP(breedID uint8) int32 { return breedBase(breedID).HP }

// fighterStats are a fighter's derived in-fight maxima: the breed base plus every
// equipped fighter-card's passive (FIGHTER_CARD_EQUIP) CharacBuff bonus. The 2.70
// client computes these exact numbers on its own from the same equipped-card ids
// the 8000 blob carries (it applies each card's equip effects when the card lands
// in the fighter's inventory), so the server MUST add the same bonuses or its
// authoritative HP/AP/MP will drift from the client's gauges.
type fighterStats struct {
	MaxHP, MaxAP, MaxMP, Init, Range int32
	// CritRate/FumbleRate are the fighter's critical-hit / fumble percentages
	// (breed base + card actions 70/71), rolled per cast (see rollCrit/rollFumble).
	CritRate, FumbleRate int32
	// Block/Dodge are the tackle percentages (breed base + card actions 120-123):
	// Block holds an adjacent enemy in place, Dodge slips away. See tackle.go.
	Block, Dodge int32
	// Stats is the elemental damage/resistance profile accumulated from the
	// equipped cards' passive effects (breed base contributes none). Consumed by
	// the damage formula (combat_stats.go).
	Stats combatStats
}

// computeFighterStats derives a fighter's maxima from its breed and equipped
// cards. cat may be nil (data files absent) or fr may have no cards, in which
// case the result is exactly the breed base.
// computeFighterStatsWithConditions is computeFighterStats plus the fighter's
// persistent conditions (wounds/blessings). Conditions are applied LAST, after
// breed and equipment, because they are penalties on the finished fighter — a
// broken leg takes a movement point off whatever the gear provided.
func computeFighterStatsWithConditions(fr *domain.Fighter, cat *gamedata.FighterCards,
	conds *gamedata.Conditions, boards *gamedata.SphereBoards) fighterStats {
	st := computeFighterStats(fr, cat)
	// Sphere Board nodes come after equipment and BEFORE conditions: a bought
	// sphere is permanent growth of the fighter itself, so it belongs with what
	// the fighter is, while a wound is a penalty on the finished article. The
	// client applies each node's rows through the same accumulator when the node
	// is bought (`ee_2.a` -> `xj_0.a`), so these must be the same rows.
	for _, ef := range sphereFightEffects(fr, boards) {
		st.applyPassiveEffect(ef)
	}
	for _, ef := range conditionFightEffects(conds, fr) {
		st.applyPassiveEffect(ef)
	}
	// A wound must never drive a resource below zero (a fighter with 0 AP would
	// be unplayable, and negative HP is nonsense).
	st.MaxHP = maxInt32(st.MaxHP, 1)
	st.MaxAP = maxInt32(st.MaxAP, 0)
	st.MaxMP = maxInt32(st.MaxMP, 0)
	st.Block = clampInt32(st.Block, 0, 100)
	st.Dodge = clampInt32(st.Dodge, 0, 100)
	return st
}

func maxInt32(a, b int32) int32 {
	if a > b {
		return a
	}
	return b
}

func computeFighterStats(fr *domain.Fighter, cat *gamedata.FighterCards) fighterStats {
	var breedID uint8
	if fr != nil {
		breedID = fr.BreedID
	}
	base := breedBase(breedID)
	st := fighterStats{MaxHP: base.HP, MaxAP: base.AP, MaxMP: base.MP, Init: base.Init,
		CritRate: baseCritRate, FumbleRate: baseFumbleRate,
		Block: base.Block, Dodge: base.Dodge}
	if fr == nil || cat == nil {
		return st
	}
	for _, obj := range fr.Objects {
		card := cat.Get(obj.TemplateID)
		if card == nil {
			continue
		}
		st.MaxHP += card.Bonus.HP
		st.MaxAP += card.Bonus.AP
		st.MaxMP += card.Bonus.MP
		st.Init += card.Bonus.Init
		st.Range += card.Bonus.Range
		for _, ef := range card.EquipEffects {
			st.applyPassiveEffect(ef)
		}
	}
	return st
}

// applyPassiveEffect folds one always-on effect row into a stat profile.
//
// Shared by EQUIPPED CARDS and by persistent FIGHTER CONDITIONS (gamedata type
// 902) — both are `Ht` rows that simply exist for the whole fight, so they must
// resolve identically. That sharing is the whole reason a wound works at all: a
// light leg wound is "action 123, param 20", i.e. exactly the same shape as a
// card that lowers dodge.
func (st *fighterStats) applyPassiveEffect(ef gamedata.Effect) {
	if len(ef.Params) == 0 {
		return
	}
	v := int32(ef.Params[0])
	switch {
	case ef.ActionID == 70: // crit-rate boost
		st.CritRate += v
	case ef.ActionID == 71: // fumble-rate boost
		st.FumbleRate += v
	case ef.ActionID == 147: // crit-rate malus
		st.CritRate -= v
	case ef.ActionID == 148: // fumble-rate malus
		st.FumbleRate -= v
	case ef.ActionID == 120: // block % gain
		st.Block += v
	case ef.ActionID == 121: // block % loss  (a light ARM wound)
		st.Block -= v
	case ef.ActionID == 122: // dodge % gain
		st.Dodge += v
	case ef.ActionID == 123: // dodge % loss  (a light LEG wound)
		st.Dodge -= v
	case ef.ActionID == 11: // max HP gain
		st.MaxHP += v
	case ef.ActionID == 12: // max HP loss
		st.MaxHP -= v
	case ef.ActionID == 13: // AP gain
		st.MaxAP += v
	case ef.ActionID == 14: // AP loss  (a serious ARM wound)
		st.MaxAP -= v
	case ef.ActionID == 17: // MP gain
		st.MaxMP += v
	case ef.ActionID == 18: // MP loss  (a serious LEG wound)
		st.MaxMP -= v
	case ef.ActionID == 76: // initiative gain
		st.Init += v
	case ef.ActionID == 77: // initiative loss (a light OTHER wound)
		st.Init -= v
	case isStatBuff(ef.ActionID):
		// Combat-stat bonuses the flat Bonus summary omits — elemental
		// damage/resistance (mh_2 21-55, 80-83) and scalar characteristics
		// (AP/MP-loss resist 86/87, rebound 89, heal power 78/79) —
		// accumulate into the combat stat profile.
		st.Stats.apply(ef.ActionID, v)
	}
}

// fighterInit returns a fighter's initiative for turn ordering. It prefers the
// pre-computed Init (breed + card bonuses set at fight build time) and falls back
// to the raw breed base when unset (e.g. lightweight tests). The client applies
// no initiative re-sort of its own (its comparator is a no-op), so the order the
// server puts fighters in IS the order the client plays.
func fighterInit(ff *FightFighter) int32 {
	if ff == nil {
		return 0
	}
	if ff.Init != 0 {
		return ff.Init
	}
	if ff.Fighter != nil {
		return breedBase(ff.Fighter.BreedID).Init
	}
	return 0
}
