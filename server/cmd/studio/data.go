package main

import (
	"sort"
	"strconv"
	"strings"
)

// This file exposes the read-only game-data catalogs to the frontend. Every
// method reuses the existing, byte-exact decoders via the cached gamedata
// catalogs built in app.go -- there is no format logic here, only loading,
// sorting, and flattening into DTOs the UI can render as tables.

// DataCounts is a quick summary of how many records each catalog holds, used to
// populate the nav badges and the overview page. A load error string (empty
// when fine) lets the UI show a failure inline instead of failing the panel.
type DataCounts struct {
	Spells        int    `json:"spells"`
	CoachCards    int    `json:"coachCards"`
	FighterCards  int    `json:"fighterCards"`
	Summonings    int    `json:"summonings"`
	StaticEffects int    `json:"staticEffects"`
	Error         string `json:"error"`
}

// GetDataCounts loads every catalog and returns their record counts. A
// missing/invalid data dir yields an Error string rather than a hard fail.
func (a *App) GetDataCounts() DataCounts {
	a.mu.Lock()
	defer a.mu.Unlock()
	var c DataCounts
	if err := a.ensureLoaded(); err != nil {
		c.Error = err.Error()
	}
	if err := a.ensureCards(); err != nil && c.Error == "" {
		c.Error = err.Error()
	}
	if a.spells != nil {
		c.Spells = a.spells.Len()
	}
	if a.cardContent != nil {
		c.CoachCards = a.cardContent.Cards.Len()
		c.FighterCards = a.cardContent.Fighters.Len()
	}
	if a.summonings != nil {
		c.Summonings = a.summonings.Len()
	}
	if a.staticEffects != nil {
		c.StaticEffects = a.staticEffects.Len()
	}
	return c
}

// SpellDTO is a flattened spell template for the table UI.
type SpellDTO struct {
	ID           int32 `json:"id"`
	BreedID      int32 `json:"breedId"`
	Value        int32 `json:"value"`
	ScriptID     int32 `json:"scriptId"`
	AP           int   `json:"ap"`
	RangeMin     int   `json:"rangeMin"`
	RangeMax     int   `json:"rangeMax"`
	TestLoS      bool  `json:"testLoS"`
	OnlyLine     bool  `json:"onlyLine"`
	NeedFreeCell bool  `json:"needFreeCell"`
	Effects      int   `json:"effects"`
}

// GetSpells returns every spell template, sorted by ID.
func (a *App) GetSpells() ([]SpellDTO, error) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if err := a.ensureLoaded(); err != nil {
		return nil, err
	}
	if a.spells == nil {
		return []SpellDTO{}, nil
	}
	out := make([]SpellDTO, 0, a.spells.Len())
	for _, sp := range a.spells.All() {
		out = append(out, SpellDTO{
			ID:           sp.ID,
			BreedID:      sp.BreedID,
			Value:        sp.Value,
			ScriptID:     sp.ScriptID,
			AP:           int(sp.AP),
			RangeMin:     int(sp.RangeMin),
			RangeMax:     int(sp.RangeMax),
			TestLoS:      sp.TestLoS,
			OnlyLine:     sp.OnlyLine,
			NeedFreeCell: sp.NeedFreeCell,
			Effects:      len(sp.Effects),
		})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out, nil
}

// CoachCardDTO is a flattened coach-card template for the table UI.
type CoachCardDTO struct {
	ID int32 `json:"id"`
	// CardType is the card kind (2..13 = equipment slots, 20 = Zaap, ...). The
	// JSON key stays "iconRef" for the existing frontend contract, but the field
	// was always the card TYPE — see gamedata.CoachCard.Type.
	CardType    int32  `json:"iconRef"`
	CardSet     int32  `json:"cardSet"`
	Value       int32  `json:"value"`
	Rank        int32  `json:"rank"`
	Price       string `json:"price"`       // "currencyType:amount" pairs
	Purchasable bool   `json:"purchasable"` // has a non-empty price
	// The rest of the fields CoachCardEdit can change (S40).
	RequiredLevel    int32 `json:"reqLevel"`
	ObtainableInDraw bool  `json:"inDraw"`
	DropPercent      int32 `json:"dropPercent"`
	Bound            bool  `json:"bound"`
	Undestructible   bool  `json:"undestructible"`
}

// GetCoachCards returns every coach-card template, sorted by ID.
func (a *App) GetCoachCards() ([]CoachCardDTO, error) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if err := a.ensureCards(); err != nil {
		return nil, err
	}
	cards := a.cardContent.Cards
	out := make([]CoachCardDTO, 0, cards.Len())
	for _, cc := range cards.All() {
		out = append(out, CoachCardDTO{
			ID:          cc.ID,
			CardType:    cc.Type,
			CardSet:     cc.CardSet,
			Value:       cc.Value,
			Rank:        cc.Rank,
			Price:       formatPrice(cc.Price),
			Purchasable: len(cc.Price) > 0,

			RequiredLevel:    cc.RequiredLevel,
			ObtainableInDraw: cc.ObtainableInDraw,
			DropPercent:      cc.DropPercent,
			Bound:            cc.Bound,
			Undestructible:   cc.Undestructible,
		})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out, nil
}

// FighterCardDTO is a flattened fighter-card template for the table UI.
type FighterCardDTO struct {
	ID           int32 `json:"id"`
	Type         int   `json:"type"`
	Value        int32 `json:"value"`
	BonusHP      int32 `json:"bonusHP"`
	BonusAP      int32 `json:"bonusAP"`
	BonusMP      int32 `json:"bonusMP"`
	BonusInit    int32 `json:"bonusInit"`
	BonusRange   int32 `json:"bonusRange"`
	EquipEffects int   `json:"equipEffects"`
	// The weapon-attack fields FighterCardEdit can change (S40).
	APCost   int32 `json:"apCost"`
	RangeMin int32 `json:"rangeMin"`
	RangeMax int32 `json:"rangeMax"`
	Usable   bool  `json:"usable"`
}

// GetFighterCards returns every fighter-card template, sorted by ID.
func (a *App) GetFighterCards() ([]FighterCardDTO, error) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if err := a.ensureCards(); err != nil {
		return nil, err
	}
	fighters := a.cardContent.Fighters
	out := make([]FighterCardDTO, 0, fighters.Len())
	for _, fc := range fighters.All() {
		out = append(out, FighterCardDTO{
			ID:           fc.ID,
			Type:         int(fc.Type),
			Value:        fc.Value,
			BonusHP:      fc.Bonus.HP,
			BonusAP:      fc.Bonus.AP,
			BonusMP:      fc.Bonus.MP,
			BonusInit:    fc.Bonus.Init,
			BonusRange:   fc.Bonus.Range,
			EquipEffects: len(fc.EquipEffects),
			APCost:       fc.APCost,
			RangeMin:     fc.RangeMin,
			RangeMax:     fc.RangeMax,
			Usable:       fc.Usable(),
		})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out, nil
}

// SummoningDTO is a flattened summon-creature template for the table UI.
type SummoningDTO struct {
	ID           int32  `json:"id"`
	HP           int32  `json:"hp"`
	AP           int32  `json:"ap"`
	MP           int32  `json:"mp"`
	Look         int32  `json:"look"`
	PrimarySpell int32  `json:"primarySpell"`
	Spells       string `json:"spells"` // comma-separated spell ids
}

// GetSummonings returns every summon template, sorted by ID.
func (a *App) GetSummonings() ([]SummoningDTO, error) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if err := a.ensureLoaded(); err != nil {
		return nil, err
	}
	if a.summonings == nil {
		return []SummoningDTO{}, nil
	}
	out := make([]SummoningDTO, 0, a.summonings.Len())
	for _, sm := range a.summonings.All() {
		out = append(out, SummoningDTO{
			ID:           sm.ID,
			HP:           sm.HP,
			AP:           sm.AP,
			MP:           sm.MP,
			Look:         sm.Look,
			PrimarySpell: sm.PrimarySpellID(),
			Spells:       formatIDs(sm.SpellIDs),
		})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out, nil
}

// StaticEffectDTO is a flattened trap/glyph template for the table UI.
type StaticEffectDTO struct {
	ID           int32  `json:"id"`
	Type         string `json:"type"`
	Label        string `json:"label"`
	AreaShape    int32  `json:"areaShape"`
	MaxExec      int32  `json:"maxExec"`
	Unlimited    bool   `json:"unlimited"`
	AppCondition int32  `json:"appCondition"`
	AppTriggers  string `json:"appTriggers"`
	Effects      int    `json:"effects"`
}

// GetStaticEffects returns every trap/glyph template, sorted by ID.
func (a *App) GetStaticEffects() ([]StaticEffectDTO, error) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if err := a.ensureLoaded(); err != nil {
		return nil, err
	}
	if a.staticEffects == nil {
		return []StaticEffectDTO{}, nil
	}
	out := make([]StaticEffectDTO, 0, a.staticEffects.Len())
	for _, se := range a.staticEffects.All() {
		out = append(out, StaticEffectDTO{
			ID:           se.ID,
			Type:         se.Type,
			Label:        se.Label,
			AreaShape:    se.AreaShape,
			MaxExec:      se.MaxExec,
			Unlimited:    se.Unlimited(),
			AppCondition: se.AppCondition,
			AppTriggers:  formatIDs(se.AppTriggers),
			Effects:      len(se.Effects),
		})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out, nil
}

// formatIDs renders an int32 slice as a compact "1, 2, 3" string.
func formatIDs(ids []int32) string {
	if len(ids) == 0 {
		return ""
	}
	parts := make([]string, len(ids))
	for i, v := range ids {
		parts[i] = strconv.Itoa(int(v))
	}
	return strings.Join(parts, ", ")
}

// formatPrice renders a coach-card token price map as sorted "type:amount"
// pairs (deterministic order for stable table rendering).
func formatPrice(price map[uint8]int32) string {
	if len(price) == 0 {
		return ""
	}
	keys := make([]int, 0, len(price))
	for k := range price {
		keys = append(keys, int(k))
	}
	sort.Ints(keys)
	parts := make([]string, 0, len(keys))
	for _, k := range keys {
		parts = append(parts, strconv.Itoa(k)+":"+strconv.Itoa(int(price[uint8(k)])))
	}
	return strings.Join(parts, ", ")
}
