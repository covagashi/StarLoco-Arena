package main

import "github.com/StarLoco/arena-2.70/internal/gamedata"

// S37: every spell is drawn by the client's own effect library
// (godot/src/fx/vfx.gd) from a three-part recipe read off its effects, not
// from a per-spell animation:
//
//	shape  bolt | hit | area | aura | curse | heal | summon | trap | tp
//	elem   neutral | fire | earth | water | air (of the first damaging effect)
//	k      1-3 intensity, from the AP cost
//	z      zone size in cells (area / trap), 0 = one cell
type vfxRecipe struct {
	Shape string `json:"s"`
	Elem  string `json:"e"`
	K     int8   `json:"k"`
	Zone  int32  `json:"z,omitempty"`
}

// elemOf names the element of a damaging action id (direct, "par sort",
// leech, AP/MP-scaled, zone and line damage); ok is false for anything else.
func elemOf(action int32) (string, bool) {
	names := [...]string{"neutral", "fire", "earth", "water", "air"}
	switch action {
	case 1, 6, 130, 151, 152:
		return names[0], true
	case 2, 7, 131, 156, 157, 165, 178:
		return names[1], true
	case 3, 8, 132, 162, 163, 168, 181:
		return names[2], true
	case 4, 9, 133, 160, 161, 166, 179:
		return names[3], true
	case 5, 10, 134, 158, 159, 167, 180:
		return names[4], true
	case 61, 125: // poison, % of max HP
		return names[0], true
	}
	return "", false
}

// curseIDs are the debuffs and AP/MP removals: drawn sinking into the
// target instead of rising round it.
var curseIDs = map[int32]bool{12: true, 14: true, 16: true, 18: true, 20: true,
	71: true, 73: true, 77: true, 81: true, 83: true, 85: true, 101: true,
	102: true, 103: true, 121: true, 123: true, 147: true, 148: true,
	169: true, 177: true}

func spellVfx(s *gamedata.Spell) vfxRecipe {
	r := vfxRecipe{Elem: "neutral", K: 1}
	switch {
	case s.AP >= 5:
		r.K = 3
	case s.AP >= 3:
		r.K = 2
	}
	var damage, heal, summon, trap, tp, curse, area bool
	for _, ef := range s.Effects {
		if ef.IsCritical {
			continue
		}
		if e, ok := elemOf(ef.ActionID); ok {
			if !damage {
				r.Elem = e
			}
			damage = true
			if ef.AreaShape > 1 && (ef.AreaShape == 32767 || len(ef.AreaSize) > 0 && ef.AreaSize[0] > 0) {
				area = true
				if r.Zone == 0 && len(ef.AreaSize) > 0 {
					r.Zone = ef.AreaSize[0]
				}
			}
			continue
		}
		switch ef.Kind() {
		case gamedata.KindHeal:
			heal = true
		case gamedata.KindSummon:
			summon = true
		case gamedata.KindTrap, gamedata.KindAura:
			trap = true
			if r.Zone == 0 && len(ef.AreaSize) > 0 {
				r.Zone = ef.AreaSize[0]
			}
		case gamedata.KindTeleport, gamedata.KindSwap:
			tp = true
		}
		if curseIDs[ef.ActionID] {
			curse = true
		}
	}
	switch {
	case summon:
		r.Shape = "summon"
	case trap:
		r.Shape = "trap"
	case tp:
		r.Shape = "tp"
	case damage && area:
		r.Shape = "area"
	case damage && s.RangeMax >= 2:
		r.Shape = "bolt"
	case damage:
		r.Shape = "hit"
	case heal:
		r.Shape = "heal"
	case curse:
		r.Shape = "curse"
	default:
		r.Shape = "aura"
	}
	if r.Shape != "area" && r.Shape != "trap" {
		r.Zone = 0
	}
	return r
}
