// Package clientdata builds the JSON tables the Godot client reads from the
// game's own content (server/content), so a change to a card or a spell
// reaches both sides (S43). They live in godot/assets/content/, tracked; the
// client loads them through AssetPaths ("content/spells.json").
//
//	go run ./cmd/exportclient
//
// rewrites them, and TestClientDataUpToDate fails while they differ from what
// the content builds. It replaced the dump* commands that read the retail data.
package clientdata

import (
	"cmp"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"slices"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// Build returns every client table by file name.
func Build(cards *gamedata.CardContent, rules *gamedata.RulesContent) (map[string][]byte, error) {
	tables := map[string]any{
		"spells.json":       spells(rules.Spells),
		"effects.json":      effects(rules.Spells, cards.Fighters),
		"areas.json":        areas(rules.StaticEffects),
		"cards.json":        coachCards(cards.Cards),
		"cardsetfx.json":    cardSetFx(cards.Sets),
		"fusionlabs.json":   fusionLabs(rules.FusionLabs),
		"fightercards.json": fighterCards(cards.Fighters),
		"spheres.json":      spheres(rules.SphereBoards),
		"npcdialogs.json":   npcDialogs(rules),
	}
	out := make(map[string][]byte, len(tables))
	for name, v := range tables {
		b, err := json.Marshal(v)
		if err != nil {
			return nil, fmt.Errorf("%s: %w", name, err)
		}
		out[name] = append(b, '\n')
	}
	return out, nil
}

// Write writes the tables built from the content into dir.
func Write(dir string, cards *gamedata.CardContent, rules *gamedata.RulesContent) (map[string][]byte, error) {
	files, err := Build(cards, rules)
	if err != nil {
		return nil, err
	}
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return nil, err
	}
	for name, b := range files {
		if err := os.WriteFile(filepath.Join(dir, name), b, 0o644); err != nil {
			return nil, err
		}
	}
	return files, nil
}

// zones returns the deduped [shape, size...] tuples of effects for the
// client's area preview (point, empty and "all" produce no tint).
func zones(effs []gamedata.Effect) [][]int32 {
	var out [][]int32
	seen := map[string]bool{}
	for _, ef := range effs {
		if ef.AreaShape <= 1 || ef.AreaShape == 32767 || len(ef.AreaSize) == 0 {
			continue
		}
		row := append([]int32{ef.AreaShape}, ef.AreaSize...)
		if key := fmt.Sprint(row); !seen[key] {
			seen[key] = true
			out = append(out, row)
		}
	}
	return out
}

type spellRec struct {
	ID    int32 `json:"id"`
	AP    int8  `json:"ap"`
	Min   int8  `json:"min"`
	Max   int8  `json:"max"`
	Value int32 `json:"value"`
	// Cast gates for the range overlay: the client enforces the same rules
	// before it ever sends 8109 (see spellTargetValidFrom).
	LoS     bool    `json:"los"`            // TestLoS: needs line of sight
	Line    bool    `json:"line"`           // OnlyLine: same row/col only
	Free    bool    `json:"free"`           // NeedFreeCell: empty target cell
	NoBoost bool    `json:"noboost"`        // RangeNotBoostable
	Masks   []int64 `json:"mask,omitempty"` // cast-level TargetMasks (only when enforced)
	// Cast-frequency limits for the spell-bar lock: parent key, effective
	// cooldown (63 = once per fight), per-turn and per-target caps.
	LimitKey  int32 `json:"lk,omitempty"`
	Cooldown  uint8 `json:"cd,omitempty"`
	PerTurn   uint8 `json:"mpt,omitempty"`
	PerTarget uint8 `json:"mptt,omitempty"`
	// Zones are the effect zones for the area preview.
	Zones [][]int32 `json:"zn,omitempty"`
	// FX is the S37 effect-library recipe (vfx.go).
	FX vfxRecipe `json:"fx"`
}

// spells: {breed: [spell...]} for the 12 classes.
func spells(sp *gamedata.Spells) map[int32][]spellRec {
	byBreed := map[int32][]spellRec{}
	for _, s := range byKey(sp.All()) {
		if s.BreedID < 1 || s.BreedID > 12 {
			continue
		}
		r := spellRec{ID: s.ID, AP: s.AP, Min: s.RangeMin, Max: s.RangeMax,
			Value: s.Value, LoS: s.TestLoS, Line: s.OnlyLine,
			Free: s.NeedFreeCell, NoBoost: s.RangeNotBoostable,
			LimitKey: s.LimitKeyID(), Cooldown: s.EffectiveCooldown(),
			PerTurn: s.CastMaxPerTurn, PerTarget: s.CastMaxPerTarget,
			Zones: zones(s.Effects), FX: spellVfx(s)}
		if s.EnforceTargetMasks {
			r.Masks = s.TargetMasks
		}
		byBreed[s.BreedID] = append(byBreed[s.BreedID], r)
	}
	return byBreed
}

type effectRec struct {
	Action   int32     `json:"a"`
	Turns    int32     `json:"d"`
	Infinite bool      `json:"i"`
	Params   []float32 `json:"p,omitempty"`
}

// effects: every timed or infinite effect of the spells and fighter cards,
// by effect id. The client attaches and counts down buff chips from it (the
// duration is never on the wire) and resolves dispel targets.
func effects(sp *gamedata.Spells, fc *gamedata.FighterCards) map[int32]effectRec {
	out := map[int32]effectRec{}
	add := func(effs []gamedata.Effect) {
		for _, e := range effs {
			turns, inf := e.DurationTurns()
			if !inf && turns <= 0 {
				continue
			}
			out[e.EffectID] = effectRec{Action: e.ActionID, Turns: turns, Infinite: inf, Params: e.Params}
		}
	}
	for _, s := range byKey(sp.All()) {
		add(s.Effects)
	}
	for _, c := range byKey(fc.All()) {
		add(c.EquipEffects)
		add(c.UseEffects)
	}
	return out
}

type areaRec struct {
	Type    string  `json:"t"`
	Label   string  `json:"l,omitempty"`
	Shape   int32   `json:"s"`
	Size    []int32 `json:"z,omitempty"`
	MaxExec int32   `json:"m"`
	WalkOn  bool    `json:"w"`
	Inner   []int32 `json:"e,omitempty"`
}

// areas: the static-effect templates (traps, glyphs, specials). The 8120
// creation broadcast carries only the template id, so the footprint, fire
// budget and inner effects are data-side.
func areas(se *gamedata.StaticEffects) map[int32]areaRec {
	out := map[int32]areaRec{}
	for id, t := range se.All() {
		inner := make([]int32, 0, len(t.Effects))
		for _, e := range t.Effects {
			inner = append(inner, e.EffectID)
		}
		walkOn := false
		for _, tr := range t.AppTriggers {
			if tr == 10001 { // trapTriggerWalkOn
				walkOn = true
			}
		}
		out[id] = areaRec{Type: t.Type, Label: t.Label, Shape: t.AreaShape,
			Size: t.AreaSize, MaxExec: t.MaxExec, WalkOn: walkOn, Inner: inner}
	}
	return out
}

type cardRec struct {
	Type      int32           `json:"type"`
	Set       int32           `json:"set"`
	Value     int32           `json:"value"`
	Price     map[uint8]int32 `json:"price"`
	Unique    bool            `json:"unique,omitempty"`
	Tradable  bool            `json:"tradable"`            // !Bound && !Undestructible
	Resurrect int32           `json:"resurrect,omitempty"` // % chance (action 13)
	ReqLevel  int32           `json:"reqLevel,omitempty"`
	Rank      int32           `json:"rank,omitempty"`     // the rarity frame (getRank)
	FusPower  int16           `json:"fusPower,omitempty"` // fusion lab target/input power
	FusQual   uint8           `json:"fusQuality,omitempty"`
	// Firework cards (type 25): the particle kind and its RGB colour (0..255
	// per channel); the lobby draws the show from them.
	FwType   uint8     `json:"fwType,omitempty"`
	FwColour []float32 `json:"fwColour,omitempty"`
	Fx       [][]int32 `json:"fx,omitempty"` // S41: [action, params...] per effect
}

// fxRows flattens effects to [lead..., action, params...] rows.
func fxRows(effs []gamedata.CardSetEffect, lead func(gamedata.CardSetEffect) []int32) [][]int32 {
	var out [][]int32
	for _, e := range effs {
		row := append(lead(e), e.Action)
		out = append(out, append(row, e.Params...))
	}
	return out
}

// coachCards: every coach card for the shop and inventory. No names: the
// client names cards itself (S41, content_<lang>.json).
func coachCards(cards *gamedata.Cards) map[int32]cardRec {
	none := func(gamedata.CardSetEffect) []int32 { return nil }
	out := map[int32]cardRec{}
	for id, c := range cards.All() {
		out[id] = cardRec{
			Fx:   fxRows(c.Effects, none),
			Type: c.Type, Set: c.CardSet, Value: c.Value,
			Price:     c.Price,
			Unique:    c.IsUnique,
			Tradable:  !c.Bound && !c.Undestructible,
			Resurrect: c.ResurrectPercent,
			ReqLevel:  c.RequiredLevel,
			Rank:      c.Rank,
			FusPower:  c.FusionPower,
			FusQual:   c.FusionQuality,
			FwType:    c.FireworkType,
			FwColour:  c.FireworkColour,
		}
	}
	return out
}

// cardSetFx: each set's bonuses, [threshold, action, params...] rows.
func cardSetFx(sets *gamedata.CardSets) map[int32][][]int32 {
	out := map[int32][][]int32{}
	for _, id := range sets.IDs() {
		if rows := fxRows(sets.Get(id).Effects, func(e gamedata.CardSetEffect) []int32 {
			return []int32{int32(e.Threshold)}
		}); len(rows) > 0 {
			out[id] = rows
		}
	}
	return out
}

type labRec struct {
	Power   int16 `json:"power"`
	Quality uint8 `json:"quality"`
	Slots   uint8 `json:"slots"`
}

func fusionLabs(labs *gamedata.FusionLabs) map[int64]labRec {
	out := map[int64]labRec{}
	for _, l := range labs.All() {
		out[l.ID] = labRec{Power: l.Power, Quality: l.Quality, Slots: l.Slots}
	}
	return out
}

type fighterRec struct {
	AP     int32 `json:"ap"`
	Min    int32 `json:"min"`
	Max    int32 `json:"max"`
	Usable bool  `json:"usable"` // has a FIGHTER_CARD_USE effect list (server Usable())
	// Cast gates for the range overlay: the same three rejections the server
	// validates in fightercard_use.go.
	LoS  bool `json:"los"`
	Line bool `json:"line"`
	Free bool `json:"free"`
	// Script is the card-use script id: the client maps the weapon scripts
	// 800x to their swing gestures.
	Script int32 `json:"script,omitempty"`
	// Zones are the UseEffects' zones for the area preview.
	Zones [][]int32 `json:"zn,omitempty"`
	// Type is the FIGHTER slot type (1 weapon, 2 pet, 3 cloak, 4 hat, 5
	// dofus). The coach-card table shares the id but its type is the COACH
	// slot, so the loadout editor reads this one (S22).
	Type int16 `json:"type"`
	// Value is what the card adds to the fighter's budget (Elite: 6000).
	Value int32 `json:"value"`
}

// fighterCards: the fighter cards' active abilities (8107) for the fight
// spell bar; their names are the coach card's of the same id.
func fighterCards(fc *gamedata.FighterCards) map[int32]fighterRec {
	out := map[int32]fighterRec{}
	for id, c := range fc.All() {
		out[id] = fighterRec{
			AP: c.APCost, Min: c.RangeMin, Max: c.RangeMax,
			Usable: c.Usable(), Script: c.ScriptID,
			LoS: c.TestLoS, Line: c.OnlyLine, Free: c.NeedFreeCell,
			Zones: zones(c.UseEffects), Type: c.Type, Value: c.Value,
		}
	}
	return out
}

// npcDialogs: the dialog groups' behaviour (texts are the client's own,
// dlg.<group> and dlgr.<group>.<n>), each launched challenge's mode, the
// achievements and the summon templates.
func npcDialogs(r *gamedata.RulesContent) map[string]any {
	type reply struct {
		Next   int32   `json:"next"`
		Act    int32   `json:"act,omitempty"`
		Params []int32 `json:"params,omitempty"`
	}
	type group struct {
		Replies []reply `json:"replies"`
	}
	groups := map[int32]*group{}
	// NPC dialog launches send 26330 [challengeId][mode]: the challenge's
	// mode field (afz_0.Qu() = Fields[1]), not the breedmaster's literal 99.
	modes := map[int32]int32{}
	for _, row := range r.NpcDialogs.Rows() {
		g := groups[row.Group]
		if g == nil {
			g = &group{}
			groups[row.Group] = g
		}
		g.Replies = append(g.Replies, reply{Next: row.Next, Act: row.Act, Params: row.Params})
		if row.Act == 1 && len(row.Params) > 0 {
			if ch := r.Challenges.Get(row.Params[0]); ch != nil {
				modes[row.Params[0]] = ch.Fields[1]
			}
		}
	}

	// Achievements gate the named-demon elements and feed the achievements
	// pane: done = every stat condition met AND every required card owned
	// (aau_1.a / sj_1.c); prev/super/hid drive the list filter, pts the
	// header total, cat/sub the tabs.
	type achRec struct {
		Stats map[int16]int16 `json:"stats"`
		Cards []int32         `json:"cards"`
		Prev  int16           `json:"prev"`
		Super int16           `json:"super"`
		Cat   int16           `json:"cat"`
		Sub   int16           `json:"sub"`
		Pts   int16           `json:"pts"`
		Hid   bool            `json:"hid"`
	}
	achs := map[int16]achRec{}
	for _, id := range r.Achievements.IDs() {
		a := r.Achievements.Get(id)
		stats := map[int16]int16{}
		for _, c := range a.Conditions {
			stats[c.StatID] = c.Threshold
		}
		achs[id] = achRec{Stats: stats, Cards: a.Cards, Prev: a.Previous, Super: a.Superseding,
			Cat: a.Category, Sub: a.Subcategory, Pts: a.Points, Hid: a.Hidden}
	}

	// Summon templates: a summon's running effect carries only the template
	// id, so the client builds the spawned fighter's sheet from this.
	// A nonzero particle means it dissipates on death instead of a corpse.
	type summonRec struct {
		HP       int32 `json:"hp"`
		AP       int32 `json:"ap"`
		MP       int32 `json:"mp"`
		Look     int32 `json:"look"`
		Particle int32 `json:"particle"`
	}
	sums := map[int32]summonRec{}
	for id, sm := range r.Summonings.All() {
		sums[id] = summonRec{HP: sm.HP, AP: sm.AP, MP: sm.MP,
			Look: sm.Look, Particle: int32(sm.ParticleID)}
	}
	return map[string]any{
		"groups":         groups,
		"challengeModes": modes,
		"achievements":   achs,
		"summons":        sums,
	}
}

// byKey returns the values of m sorted by key, so the tables come out the same
// on every run.
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
