package game

import (
	"github.com/StarLoco/arena-2.70/internal/domain"
)

// Fighter creation limits (from the client rules).
const (
	maxFighterNameLen = 16
	maxFighterSpells  = 6
	// breedBaseValue is the value every breed contributes to a fighter's budget
	// before its cards. 600 in 2.70: it is the 8th argument of the client's breed
	// table (xq), the position v2.04b's unobfuscated Breed.java exposes as
	// getValue() and holds 400 in. Ours was the 2.04b figure, so every fighter's
	// budget was 200 short. See BUGS.md B-058.
	breedBaseValue = 600
	minBreedID     = 1
	maxBreedID     = 14

	// Fighter-inventory (6010/6011) loadout slot counts, from the client — and
	// note which is which, because the names used to be the wrong way round:
	// SPELLS live in `ajv_2(6)` (ee_2.java:137) and EQUIPMENT in `en_1(…,5,…)`
	// (ee_2.java:139).
	maxLoadoutSpells = 6

	// maxFighterEquipSlots is the fighter's equipment capacity. It is not an
	// arbitrary cap: `en_1` refuses any position outside [0,size) outright
	// ("Impossible d'ajouter un item : position en dehors des limites"), and the
	// five positions are fixed per item type by `vi_1` — weapon 0, pet 1, cloak 2,
	// hat 3, dofus 4.
	maxFighterEquipSlots = 5
	maxLoadoutCards      = maxFighterEquipSlots
)

// validBreed reports whether a breed id is a legal player breed.
func validBreed(id uint8) bool { return id >= minBreedID && id <= maxBreedID }

// sanitizeFighterName trims + caps the name, falling back to "Noob" (the
// client's own fallback) if empty.
// sanitizeFighterName normalises a fighter/team name that has ALREADY been
// accepted by validateFighterName / validateTeamName at the handler.
//
// SECURITY: this used to be TrimSpace + a BYTE-boundary cut at 16, which split
// multi-byte runes and persisted invalid UTF-8, and it stripped no markup - so a
// fighter name reached other clients with '<' and '>' intact (the renderer parses
// markup unescaped, see B-104).
//
// The "Noob" fallback remains ONLY as a last-resort invariant so no code path can
// ever persist an empty name. It is no longer the way empty input is handled:
// entry points reject that outright, because falling back accepted hostile input
// and merely disguised it. If this fallback is ever observed in practice, an
// unguarded caller has appeared.
func sanitizeFighterName(name string) string {
	return sanitizeNameWithFallback(name, maxFighterNameLen, "Noob")
}

// buildFighter validates a decoded blob into a persistable Fighter owned by
// coachID, computing its budget server-side. Invalid spells/cards are dropped.
func (s *Session) buildFighter(coachID uint, fb *FighterBlob) *domain.Fighter {
	breed := fb.BreedID
	if !validBreed(breed) {
		breed = minBreedID
	}
	f := &domain.Fighter{
		CoachID: coachID,
		BreedID: breed,
		Name:    sanitizeFighterName(fb.Name),
		Sex:     fb.Sex & 1,
		Hair:    fb.Hair,
		Skin:    fb.Skin,
		Eye:     fb.Eye,
		// The client tells us which roster it is recruiting for, via the et_2
		// type byte. This was decoded into FighterBlob.Type and then never read,
		// so a fighter created on the Évolution tab came straight back as a
		// CLASSIC one and the evolution roster could never be populated at all.
		Evolution: fb.Type == fighterBlobTypeEvolution,
	}

	// Spells: breed-legal, deduped, capped at 6.
	//
	// The breed-legality check used to be deferred here ("would need spell
	// gamedata"); it is now filterLoadoutSpellIDs, because the deferral was a
	// security hole rather than a rough edge - see spell_legality.go.
	for _, id := range filterLoadoutSpellIDs(s.deps, breed, fb.SpellIDs) {
		if len(f.Spells) >= maxFighterSpells {
			break
		}
		f.Spells = append(f.Spells, domain.FighterSpell{SpellID: id})
	}
	// Cards: one per slot, at the position the card's TYPE demands.
	//
	// This path used to dedupe on the INCOMING slot and stop there - no cap, and
	// the sender's position taken on trust. That made it the only writer able to
	// persist a loadout the client can never hold, and the dev roster's ten-row
	// fighters (slots 0..9) can only have come through here: the 6011 handler has
	// been capped at 6 since the first commit, so it could not have produced them.
	// Whatever sent that blob, the hole was real, so it is closed rather than
	// merely explained.
	incoming := make([]domain.FighterObject, 0, len(fb.Cards))
	slotUsed := make(map[int16]bool)
	for _, c := range fb.Cards {
		if slotUsed[c.Slot] {
			continue
		}
		slotUsed[c.Slot] = true
		incoming = append(incoming, domain.FighterObject{TemplateID: c.ID, Slot: c.Slot})
	}
	// SECURITY: an EVOLUTION fighter may only wear what its Sphere Board unlocked.
	// The 6011 loadout path applied entitledEquip and this one did not, so a
	// freshly created evolution fighter (et_2 type byte 2) could be handed any
	// equipment templates for free - a brand-new fighter has zero bought nodes, so
	// the client can never offer these and 6011 would strip them all.
	f.Objects = s.entitledEquip(f, s.canonicalEquipSlots(incoming))

	f.Budget = s.computeFighterBudget(f)
	return f
}

// computeFighterBudget = breed base (breedBaseValue, 600) + Σ card values (+ spell prices when
// spell gamedata is available). Clamped to int16. Values come from the FIGHTER-card
// table — see computeLoadoutBudget for why using the coach-card table was wrong.
func (s *Session) computeFighterBudget(f *domain.Fighter) int16 {
	value := breedBaseValue
	if s.deps.FighterCards != nil {
		for _, obj := range f.Objects {
			if card := s.deps.FighterCards.Get(obj.TemplateID); card != nil {
				value += int(card.Value)
			}
		}
	}
	// Spell prices require a spell gamedata table (not yet loaded); treated as 0.
	if value > 32767 {
		value = 32767
	}
	return int16(value)
}

// equipForWire returns the subset of a fighter's stored equipment the client can
// actually accept: at most one item per position, positions in [0,
// maxFighterEquipSlots), in ascending order.
//
// The client's fighter inventory is a fixed 5-slot ArrayInventory whose position
// is the item type's own fixed slot (vi_1: weapon 0, pet 1, cloak 2, hat 3, dofus
// 4), enforced by the ne_2 position checker. Anything else is refused on arrival,
// so filtering here keeps the server's picture of a fighter equal to the client's
// instead of quietly diverging by however many extra rows the database holds.
func equipForWire(objs []domain.FighterObject) []domain.FighterObject {
	if len(objs) == 0 {
		return objs
	}
	var out []domain.FighterObject
	seen := make(map[int16]bool, maxFighterEquipSlots)
	for slot := int16(0); slot < maxFighterEquipSlots; slot++ {
		for _, o := range objs {
			if o.Slot == slot && !seen[slot] {
				seen[slot] = true
				out = append(out, o)
				break
			}
		}
	}
	return out
}
