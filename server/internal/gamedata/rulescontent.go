package gamedata

import (
	"cmp"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
)

// rulescontent.go reads and writes the rest of the game's rules data (S43):
// every table the server still decoded from data.bdat after S40 took the
// cards. Same path as the cards: the data.bdat structs as JSON in
// server/content/rules/, embedded by package content, with the retail ids.
//
//	spells.json                  spell templates (by id)
//	summonings.json              summoned creatures
//	static_effects.json          glyphs, traps and other static effects
//	challenges.json              challenge definitions
//	achievements.json            achievement definitions
//	achievement_categories.json  their categories and subcategories
//	conditions.json              fighter conditions
//	fusion_labs.json             fusion labs
//	map_bonuses.json             per-map bonuses
//	tournaments.json             tournament definitions
//	tournament_levels.json       the tournament level list, in record order
//	sphere_boards.json           sphere boards
//	spheres.json                 the nodes of those boards
//	equipment_pools.json         equipment pools
//	npc_dialogs.json             NPC dialog reply rows
//
// One record per line, sorted by id, so a redesign diffs record by record.

// RulesContent is the rules data of one content tree.
type RulesContent struct {
	Spells         *Spells
	Summonings     *Summonings
	StaticEffects  *StaticEffects
	Challenges     *Challenges
	Achievements   *Achievements
	Conditions     *Conditions
	FusionLabs     *FusionLabs
	MapBonuses     *MapBonuses
	Tournaments    *Tournaments
	SphereBoards   *SphereBoards
	EquipmentPools *EquipmentPools
	NpcDialogs     *NpcDialogs
}

const (
	rulesSpells          = "spells.json"
	rulesSummonings      = "summonings.json"
	rulesStaticEffects   = "static_effects.json"
	rulesChallenges      = "challenges.json"
	rulesAchievements    = "achievements.json"
	rulesAchievementCats = "achievement_categories.json"
	rulesConditions      = "conditions.json"
	rulesFusionLabs      = "fusion_labs.json"
	rulesMapBonuses      = "map_bonuses.json"
	rulesTournaments     = "tournaments.json"
	rulesTournamentLvls  = "tournament_levels.json"
	rulesSphereBoards    = "sphere_boards.json"
	rulesSpheres         = "spheres.json"
	rulesEquipmentPools  = "equipment_pools.json"
	rulesNpcDialogs      = "npc_dialogs.json"
)

// LoadRulesContent decodes a rules content tree (content.Rules, or os.DirFS of
// a checkout). Like the cards, it is ours and must load whole.
func LoadRulesContent(fsys fs.FS) (*RulesContent, error) {
	var (
		spells  []*Spell
		sums    []*Summoning
		statics []*StaticEffect
		chals   []*Challenge
		achs    []*Achievement
		cats    []*AchievementCategory
		conds   []*Condition
		labs    []*FusionLab
		bonuses []*MapBonus
		tourns  []*TournamentDef
		levels  []int
		boards  []*SphereBoard
		spheres []*Sphere
		pools   []*EquipmentPool
		dialogs []*NpcDialogReply
	)
	for _, f := range []struct {
		name string
		into any
	}{
		{rulesSpells, &spells},
		{rulesSummonings, &sums},
		{rulesStaticEffects, &statics},
		{rulesChallenges, &chals},
		{rulesAchievements, &achs},
		{rulesAchievementCats, &cats},
		{rulesConditions, &conds},
		{rulesFusionLabs, &labs},
		{rulesMapBonuses, &bonuses},
		{rulesTournaments, &tourns},
		{rulesTournamentLvls, &levels},
		{rulesSphereBoards, &boards},
		{rulesSpheres, &spheres},
		{rulesEquipmentPools, &pools},
		{rulesNpcDialogs, &dialogs},
	} {
		if err := readContentFile(fsys, f.name, f.into); err != nil {
			return nil, err
		}
	}
	if len(spells) == 0 {
		return nil, fmt.Errorf("rules content: %s is empty", rulesSpells)
	}

	ach := NewAchievements(achs...)
	for _, c := range cats {
		ach.categories[c.ID] = c
	}
	ach.reindex()
	tn := NewTournaments(tourns...)
	for _, l := range levels {
		tn.levels = append(tn.levels, uint8(l))
	}
	return &RulesContent{
		Spells:         NewSpells(spells...),
		Summonings:     NewSummonings(sums...),
		StaticEffects:  NewStaticEffects(statics...),
		Challenges:     NewChallenges(chals...),
		Achievements:   ach,
		Conditions:     NewConditions(conds...),
		FusionLabs:     NewFusionLabs(labs...),
		MapBonuses:     NewMapBonuses(bonuses...),
		Tournaments:    tn,
		SphereBoards:   NewSphereBoards(boards, spheres),
		EquipmentPools: NewEquipmentPools(pools...),
		NpcDialogs:     NewNpcDialogs(dialogs...),
	}, nil
}

// byKey returns the values of m sorted by their key.
func byKey[K cmp.Ordered, V any](m map[K]V) []V {
	keys := make([]K, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	slices.Sort(keys)
	out := make([]V, 0, len(keys))
	for _, k := range keys {
		out = append(out, m[k])
	}
	return out
}

// WriteRulesContent writes r as a rules content tree under dir (cmd/exportrules),
// the inverse of LoadRulesContent.
func WriteRulesContent(dir string, r *RulesContent) error {
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	var cats []*AchievementCategory
	for _, id := range r.Achievements.CategoryIDs() {
		cats = append(cats, r.Achievements.Category(id))
	}
	var achs []*Achievement
	for _, id := range r.Achievements.IDs() {
		achs = append(achs, r.Achievements.Get(id))
	}
	var conds []*Condition
	for _, id := range r.Conditions.IDs() {
		conds = append(conds, r.Conditions.Get(id))
	}
	var levels []int
	for _, l := range r.Tournaments.Levels() {
		levels = append(levels, int(l))
	}
	var boards []*SphereBoard
	var spheres []*Sphere
	for _, id := range r.SphereBoards.BoardIDs() {
		boards = append(boards, r.SphereBoards.Board(id))
	}
	spheres = byKey(r.SphereBoards.spheres)
	var pools []*EquipmentPool
	for _, id := range r.EquipmentPools.IDs() {
		pools = append(pools, r.EquipmentPools.Get(id))
	}

	for _, w := range []struct {
		name string
		fn   func(string) error
	}{
		{rulesSpells, func(p string) error { return writeContentFile(p, byKey(r.Spells.All())) }},
		{rulesSummonings, func(p string) error { return writeContentFile(p, byKey(r.Summonings.All())) }},
		{rulesStaticEffects, func(p string) error { return writeContentFile(p, byKey(r.StaticEffects.All())) }},
		{rulesChallenges, func(p string) error { return writeContentFile(p, byKey(r.Challenges.All())) }},
		{rulesAchievements, func(p string) error { return writeContentFile(p, achs) }},
		{rulesAchievementCats, func(p string) error { return writeContentFile(p, cats) }},
		{rulesConditions, func(p string) error { return writeContentFile(p, conds) }},
		{rulesFusionLabs, func(p string) error { return writeContentFile(p, byKey(r.FusionLabs.All())) }},
		{rulesMapBonuses, func(p string) error { return writeContentFile(p, byKey(r.MapBonuses.byMap)) }},
		{rulesTournaments, func(p string) error { return writeContentFile(p, byKey(r.Tournaments.All())) }},
		{rulesTournamentLvls, func(p string) error { return writeContentFile(p, levels) }},
		{rulesSphereBoards, func(p string) error { return writeContentFile(p, boards) }},
		{rulesSpheres, func(p string) error { return writeContentFile(p, spheres) }},
		{rulesEquipmentPools, func(p string) error { return writeContentFile(p, pools) }},
		{rulesNpcDialogs, func(p string) error { return writeContentFile(p, r.NpcDialogs.Rows()) }},
	} {
		if err := w.fn(filepath.Join(dir, w.name)); err != nil {
			return err
		}
	}
	return nil
}

// LoadRetailRulesContent decodes the same tables from a data.bdat directory. It
// is the source of cmd/exportrules and the reference of the parity test.
func LoadRetailRulesContent(bdatDir string) (*RulesContent, error) {
	st, err := Open(bdatDir)
	if err != nil {
		return nil, err
	}
	r := &RulesContent{}
	for _, step := range []func() error{
		func() (err error) { r.Spells, err = st.LoadSpells(); return },
		func() (err error) { r.Summonings, err = st.LoadSummonings(); return },
		func() (err error) { r.StaticEffects, err = st.LoadStaticEffects(); return },
		func() (err error) { r.Challenges, err = st.LoadChallenges(); return },
		func() (err error) { r.Achievements, err = st.LoadAchievements(); return },
		func() (err error) { r.Conditions, err = st.LoadConditions(); return },
		func() (err error) { r.FusionLabs, err = st.LoadFusionLabs(); return },
		func() (err error) { r.MapBonuses, err = st.LoadMapBonuses(); return },
		func() (err error) { r.Tournaments, err = st.LoadTournaments(); return },
		func() (err error) { r.SphereBoards, err = st.LoadSphereBoards(); return },
		func() (err error) { r.EquipmentPools, err = st.LoadEquipmentPools(); return },
		func() (err error) { r.NpcDialogs, err = st.LoadNpcDialogs(); return },
	} {
		if err := step(); err != nil {
			return nil, err
		}
	}
	return r, nil
}
