package game

import (
	"errors"
	"time"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store"
)

func registerFighterHandlers(r *Router, d *Deps) {
	r.Register(protocol.OpFighterCreate, handleFighterCreate)
	r.Register(protocol.OpFighterDelete, handleFighterDelete)
	r.Register(protocol.OpUpdateFighterInventory, handleFighterInventoryUpdate)
	r.Register(protocol.OpTeamPresetListRequest, handleTeamPresetListRequest)
}

// handleTeamPresetListRequest (6031) is sent by the client when it opens the
// team-management panel AND when it opens the overworld GRAVEYARD. It replies with
// BOTH the fighter roster (6006) AND the team preset list (6030):
//
//   - the team panel's fighter grid is repopulated from this 6006 on every open,
//     and the client clears its cache when the panel closes, so without re-pushing
//     the roster here the grid is empty after a close/reopen;
//   - the graveyard loader files evolution (type-2) fighters into its roster from
//     a 6006 received while it is the active frame — a login-time 6006 does NOT
//     reach it — so the graveyard is only ever populated by this reply.
//
// ORDER MATTERS: 6006 first, then 6030. The graveyard opens behind a full-screen
// "loading" veil that ONLY 6030 dismisses (there is no timeout and it cannot be
// closed), so 6030 must come last, once the content it displays has arrived.
func handleTeamPresetListRequest(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	if err := s.pushFighterList(); err != nil {
		return err
	}
	return s.pushTeamPresetList()
}

// handleFighterCreate (6001 C2S: [u8 flag][i16 slot][i16 blobLen][et_2 blob])
// validates + persists a new fighter and replies FighterCreateResult(6000).
func handleFighterCreate(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	flag, err := r.U8()
	if err != nil {
		return err
	}
	slot, err := r.U16()
	if err != nil {
		return err
	}
	blobLen, err := r.U16()
	if err != nil {
		return err
	}
	blob, err := r.Bytes(int(blobLen))
	if err != nil {
		return err
	}
	fb, err := decodeFighterBlob(blob)
	if err != nil {
		return s.sendFighterCreateError()
	}
	// SECURITY: cap the fighter pool. The client refuses to even OPEN the creation
	// dialog past 100 (hu_2.java:30-43) and retail answered 6000 with status 20
	// ("Nombre maximum de combattants atteint"), so this is a retail rule, not a
	// new one. Unbounded creation grows the DB, makes every relog serialize the
	// whole roster into 6006, and supplies the ammunition for an oversized fight
	// roster since ownership is all buildFightTeamFor requires.
	if existing, err := s.deps.Store.Fighters.ListByCoach(s.Coach.ID); err == nil &&
		len(existing) >= maxFightersPerCoach {
		s.log.Warn("fighter creation refused: pool full",
			"coach", s.Coach.ID, "have", len(existing))
		return s.sendFighterCreateStatus(fighterCreateNoMoreRoom)
	}

	// An empty or unusable fighter name is REFUSED, not silently renamed.
	// buildFighter used to fall back to "Noob", which accepted the input and
	// merely disguised it; the retail client refuses its own form with
	// error.fighterCreation.invalidName, so refusing is also what a legitimate
	// player already sees.
	if _, ok := validateFighterName(fb.Name); !ok {
		s.log.Warn("rejected fighter name", "coach", s.Coach.ID, "len", len(fb.Name))
		return s.sendFighterCreateError()
	}

	fighter := s.buildFighter(s.Coach.ID, fb)
	if err := s.deps.Store.Fighters.Create(fighter); err != nil {
		return s.sendFighterCreateError()
	}
	// S10: statistic 211, "recruited three warriors from the class masters"
	// (achievement 276). The server cannot tell which screen the fighter was
	// made from, so every recruit counts.
	s.noteRecruit()
	s.log.Info("fighter created", "name", fighter.Name, "breed", fighter.BreedID,
		"budget", fighter.Budget, "id", fighter.ID)

	// FighterCreateResult(6000): [u8 0][i64 coachId][i64 fighterId][i16 len]
	// [et_2 blob][u8 flag][i16 slot].
	w := protocol.NewWriter().
		U8(0).
		I64(int64(s.Coach.ID)).
		I64(int64(fighter.ID))
	fbBlob := encodeFighterBlob(fighter, s.deps.SphereBoards)
	w.U16(uint16(len(fbBlob)))
	w.Raw(fbBlob)
	w.U8(flag).U16(slot)

	frame, err := protocol.EncodeS2C(protocol.OpFighterCreateResult, w.Bytes())
	if err != nil {
		return err
	}
	if err := s.Send(frame); err != nil {
		return err
	}
	// Re-push the full roster (6006) so the team-management grid reflects the
	// new fighter. The client only ever receives 6006 as a server push (there
	// is no C2S list request), and it does not re-request when the panel is
	// reopened — so without this, a newly created fighter would not appear, and
	// reopening the panel would show a stale (login-time) roster.
	return s.pushFighterList()
}

// sendFighterCreateError replies with a non-zero create result.
func (s *Session) sendFighterCreateError() error {
	frame, err := protocol.EncodeS2C(protocol.OpFighterCreateResult,
		protocol.NewWriter().U8(1).Bytes())
	if err != nil {
		return err
	}
	return s.Send(frame)
}

// handleFighterDelete (6003 C2S: [i64 fighterId][i16 slot]) deletes a fighter
// (scoped to the owner) and replies FighterDeleteResult(6002).
func handleFighterDelete(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	// SECURITY: no roster or loadout edits while queued / in a fight. The
	// matchmaker snapshots fighter IDS but the fight re-reads their STATS, so
	// editing while queued swaps a cheap legal roster for an expensive one
	// after pairing. Retail refused this with code 69.
	if s.rosterLocked() {
		return s.refuseRosterEdit("fighter delete")
	}
	r := protocol.NewReader(f.Payload)
	fighterID, err := r.I64()
	if err != nil {
		return err
	}
	before, _ := s.deps.Store.Fighters.Get(uint(fighterID))
	ok, err := s.deps.Store.Fighters.Delete(uint(fighterID), s.Coach.ID)
	if err != nil {
		return err
	}
	if ok && before != nil && before.Evolution &&
		before.State != domain.FighterStateDead && before.State != domain.FighterStateGraveyard {
		s.noteStat(statEvoLivingDelete, 1, false)
	}
	result := uint8(0)
	if !ok {
		result = 1 // not found / not owned
	}
	w := protocol.NewWriter().U8(result).I64(fighterID).I64(0)
	frame, err := protocol.EncodeS2C(protocol.OpFighterDeleteResult, w.Bytes())
	if err != nil {
		return err
	}
	if err := s.Send(frame); err != nil {
		return err
	}
	if ok {
		s.log.Info("fighter deleted", "id", fighterID)
		// Re-push the roster so the grid drops the deleted fighter (6006 is a
		// server push only; the client never re-requests the list).
		return s.pushFighterList()
	}
	return nil
}

// buildFighterList builds FighterInformationList(6006) for a coach's roster:
// [i64 serverTimeSecs][u8 count]{i64 id, u16 blobLen, et_2 blob}.
//
// IMPORTANT: the leading i64 (jt_2.Wm() / bmN) is NOT the coach id — it is a
// server timestamp in SECONDS. The client computes each fighter's form/fatigue
// as (now - Wm()) / 3600 hours (xi_0/awy callbacks → et_2.a); sending the coach
// id here made that a nonsensically large hour count, which zeroed the fighter's
// form and prevented the roster from rendering on a panel reopen (the create
// result 6000 does NOT apply this fatigue, which is why fighters showed on first
// create but vanished after close/reopen).
func buildFighterList(coachID uint, fighters []domain.Fighter, boards *gamedata.SphereBoards) ([]byte, error) {
	nowSecs := time.Now().Unix()
	w := protocol.NewWriter().I64(nowSecs).U8(uint8(len(fighters)))
	for i := range fighters {
		blob := encodeFighterBlob(&fighters[i], boards)
		w.I64(int64(fighters[i].ID))
		w.U16(uint16(len(blob)))
		w.Raw(blob)
	}
	return protocol.EncodeS2C(protocol.OpFighterInformationList, w.Bytes())
}

// pushFighterList sends the coach's current roster.
func (s *Session) pushFighterList() error {
	fighters, err := s.deps.Store.Fighters.ListByCoach(s.Coach.ID)
	if err != nil {
		return err
	}
	frame, err := buildFighterList(s.Coach.ID, fighters, s.deps.SphereBoards)
	if err != nil {
		return err
	}
	return s.Send(frame)
}

// handleFighterInventoryUpdate (6011 C2S) equips a fighter's spells + cards.
// Layout: [i64 fighterId][i16 teamId][i16 lenSpells][spells][i16 lenCards][cards]
//
// The SPELL blob comes FIRST. `bp_1.encode()` writes `Oh().cd()` then
// `Oi().cd()`, and on the fighter those are `Oh() -> ajv_2 aTs` (the 6-slot SPELL
// inventory, a flat [i32 spellId] list) and `Oi() -> en_1 aTr` (the 5-slot ITEM
// inventory, [i16 slot][i32 cardId] pairs) - see gn_0.java:513,517 and
// ee_2.java:137,139.
//
// This used to be read the other way round. The two shapes happen to line up
// (flat list first, slotted pairs second) so nothing ever failed to parse; the
// CONTENTS were simply transposed, storing spell ids as equipped cards and card
// ids as spells. That is why every fighter came out of the loadout screen with
// `spells=0 objects=<n>` and could not cast anything. The fighter CREATE path
// (fighter_codec.go) always read this correctly, so the two disagreed.
//
// Persists the loadout and replies UpdatedFighterInventory(6010).
func handleFighterInventoryUpdate(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	// SECURITY: no roster or loadout edits while queued / in a fight. The
	// matchmaker snapshots fighter IDS but the fight re-reads their STATS, so
	// editing while queued swaps a cheap legal roster for an expensive one
	// after pairing. Retail refused this with code 69.
	if s.rosterLocked() {
		return s.refuseRosterEdit("loadout")
	}
	r := protocol.NewReader(f.Payload)
	fighterID, err := r.I64()
	if err != nil {
		return err
	}
	if _, err := r.U16(); err != nil { // teamId (unused server-side)
		return err
	}
	spellsLen, err := r.U16()
	if err != nil {
		return err
	}
	spellsBlob, err := r.Bytes(int(spellsLen))
	if err != nil {
		return err
	}
	cardsLen, err := r.U16()
	if err != nil {
		return err
	}
	cardsBlob, err := r.Bytes(int(cardsLen))
	if err != nil {
		return err
	}

	// Resolve the STORED fighter once, up front. Everything below is validated
	// against it rather than against anything the request claims: the breed drives
	// spell legality, and the sphere entitlement drives card legality.
	//
	// This lookup used to happen only for the card check, further down. Hoisting it
	// is what lets the spell filter exist at all - the breed is not in the request,
	// and taking it from the request would defeat the point.
	stored, ferr := s.deps.Store.Fighters.Get(uint(fighterID))
	if ferr != nil || stored == nil || stored.CoachID != s.Coach.ID {
		// Not this coach's fighter (or gone).
		//
		// The ownership half of this is DEFENCE IN DEPTH, not the live guard:
		// SaveLoadout already scopes its update with
		// WHERE id = ? AND coach_id = ?, and a mutation removing this line does
		// not reproduce the IDOR. It is here because the breed we validate spells
		// against has to come from the STORED fighter - taking it from the request
		// would let the client pick its own legality rule - and because decoding a
		// loadout against a fighter we do not own is pointless work.
		return nil
	}

	// SECURITY: the client authors this list, and castSpellByFighter gates casting
	// on it - so without a legality filter a forged 6011 let any fighter cast any
	// of the 203 spells, persistently. See spell_legality.go.
	spells := filterLoadoutSpells(s.deps, stored.BreedID, decodeLoadoutSpells(spellsBlob))
	cards := s.canonicalEquipSlots(decodeLoadoutCards(cardsBlob))

	// An evolution fighter may only wear what its Sphere Board nodes unlocked.
	cards = s.entitledEquip(stored, cards)

	// Recompute budget from the new loadout (breed base + card values).
	budget := s.computeLoadoutBudget(cards)

	err = s.deps.Store.Fighters.SaveLoadout(uint(fighterID), s.Coach.ID, cards, spells, budget)
	if errors.Is(err, store.ErrNotFound) {
		return s.sendFighterInventoryResult(fighterID, 1, nil, nil) // not owned
	}
	if err != nil {
		return err
	}
	s.log.Info("fighter loadout updated", "fighter", fighterID,
		"cards", len(cards), "spells", len(spells), "budget", budget)

	return s.sendFighterInventoryResult(fighterID, 0, cards, spells)
}

// sendFighterInventoryResult replies with UpdatedFighterInventory(6010):
// [i64 fighterId][i8 result]; when result==0 also
// [i16 lenCards][cards][i16 lenSpells][spells] echoing the stored loadout.
func (s *Session) sendFighterInventoryResult(fighterID int64, result uint8, cards []domain.FighterObject, spells []domain.FighterSpell) error {
	w := protocol.NewWriter().I64(fighterID).U8(result)
	if result == 0 {
		// Same order as the request: spells first, then the slotted cards.
		sb := encodeLoadoutSpells(spells)
		w.U16(uint16(len(sb)))
		w.Raw(sb)
		cb := encodeLoadoutCards(cards)
		w.U16(uint16(len(cb)))
		w.Raw(cb)
	}
	frame, err := protocol.EncodeS2C(protocol.OpUpdatedFighterInventory, w.Bytes())
	if err != nil {
		return err
	}
	return s.Send(frame)
}

// decodeLoadoutSpells parses the Oh/ajv_2 SPELL blob: concatenated [i32 spellId]
// with no slot and no count - `ajv_2` is a flat inventory, so the position is
// just the order. Capped at maxLoadoutSpells (the client's holds 6).
func decodeLoadoutSpells(blob []byte) []domain.FighterSpell {
	r := protocol.NewReader(blob)
	out := make([]domain.FighterSpell, 0, maxLoadoutSpells)
	for r.Remaining() >= 4 && len(out) < maxLoadoutSpells {
		id, err := r.I32()
		if err != nil {
			break
		}
		out = append(out, domain.FighterSpell{SpellID: id, Slot: int16(len(out))})
	}
	return out
}

// decodeLoadoutCards parses the Oi/en_1 ITEM blob: concatenated
// [i16 slot][i32 cardId] with no count.
//
// The slot is NOT a free index: it is the item's fixed equipment position from
// the client's `vi_1` enum - weapon 0, pet 1, cloak 2, hat 3, dofus 4 - and the
// client's own position checker (`ne_2.a`) rejects an item whose position is not
// its type's. The inventory holds exactly maxFighterEquipSlots of them
// (`ee_2.java:139`, `new en_1(..., 5, ...)`), so anything outside that range
// cannot be stored client-side and is dropped here rather than persisted and
// re-sent forever.
func decodeLoadoutCards(blob []byte) []domain.FighterObject {
	r := protocol.NewReader(blob)
	out := make([]domain.FighterObject, 0, maxFighterEquipSlots)
	slotUsed := make(map[int16]bool)
	for r.Remaining() >= 6 && len(out) < maxFighterEquipSlots {
		slot, err := r.U16()
		if err != nil {
			break
		}
		id, err := r.I32()
		if err != nil {
			break
		}
		s := int16(slot)
		if s < 0 || s >= maxFighterEquipSlots || slotUsed[s] {
			continue
		}
		slotUsed[s] = true
		out = append(out, domain.FighterObject{TemplateID: id, Slot: s})
	}
	return out
}

// encodeLoadoutCards serializes cards as the Oh/ajv_2 blob: [i32 cardId]* (no
// slot, no count).
func encodeLoadoutCards(cards []domain.FighterObject) []byte {
	w := protocol.NewWriter()
	for _, c := range cards {
		w.U16(uint16(c.Slot)).I32(c.TemplateID)
	}
	return w.Bytes()
}

// encodeLoadoutSpells serializes spells as the Oi/en_1 blob:
// [i16 slot][i32 spellId]* (no count).
func encodeLoadoutSpells(spells []domain.FighterSpell) []byte {
	w := protocol.NewWriter()
	for _, sp := range spells {
		w.I32(sp.SpellID)
	}
	return w.Bytes()
}

// computeLoadoutBudget = breed base (400) + Σ card values (spell prices need
// spell gamedata; treated as 0). Clamped to int16.
//
// The values MUST come from the FIGHTER-card table (type 250): a fighter's
// objects are its equipment (client ve_0), not coach cards. Both tables are keyed
// by small ints and overlap almost completely, so looking equipment up in the
// coach-card table (type 100) silently returned an unrelated card's price — 66 of
// the 75 fighter cards got a wrong value and NONE matched (card 85 is worth 200
// but scored 18200), which saturated the int16 clamp and broke team budgeting.
func (s *Session) computeLoadoutBudget(cards []domain.FighterObject) int16 {
	value := breedBaseValue
	if s.deps.FighterCards != nil {
		for _, c := range cards {
			if card := s.deps.FighterCards.Get(c.TemplateID); card != nil {
				value += int(card.Value)
			}
		}
	}
	if value > 32767 {
		value = 32767
	}
	return int16(value)
}

// canonicalEquipSlots rewrites each equipped card's position to the one its TYPE
// demands, and drops anything that then collides.
//
// The position in the fighter's item inventory is not free: the client builds
// each equipment piece with `vi_1.ap((byte)uh_0.getType())` (eh_2.java:81), so a
// card's record type IS its slot type - weapon 1, pet 2, cloak 3, hat 4, dofus 5,
// at positions 0..4 - and `ne_2.a` refuses any item whose position is not its
// type's, with "impossible d'ajouter l'item <id>". Trusting the incoming position
// therefore produced rejections even when it was inside the 5-slot range.
//
// With no card table loaded it falls back to equipForWire, which cannot know an
// item's type but can still enforce the shape the inventory demands: one item per
// position, positions inside [0, maxFighterEquipSlots). A data-less dev server
// therefore still cannot persist a loadout the client would refuse outright,
// while nothing is silently emptied for want of game data.
func (s *Session) canonicalEquipSlots(cards []domain.FighterObject) []domain.FighterObject {
	if len(cards) == 0 {
		return cards
	}
	if s.deps == nil || s.deps.FighterCards == nil {
		return equipForWire(cards)
	}
	out := make([]domain.FighterObject, 0, len(cards))
	used := make(map[int16]bool, maxFighterEquipSlots)
	for _, c := range cards {
		fc := s.deps.FighterCards.Get(c.TemplateID)
		if fc == nil {
			continue // not a fighter card: the client has nowhere to put it
		}
		slot := int16(fc.Type) - 1 // vi_1: type 1 (weapon) sits at position 0
		if slot < 0 || slot >= maxFighterEquipSlots || used[slot] {
			continue
		}
		used[slot] = true
		c.Slot = slot
		out = append(out, c)
	}
	return out
}

// maxFightersPerCoach mirrors the client's own pool limit (hu_2.java:30:
// `adY.atu().amq().size() <= 100`), which retail also enforced server-side via
// FighterCreateResult status 20.
const maxFightersPerCoach = 100

// fighterCreateNoMoreRoom is the client's status 20 on 6000, rendered as
// "Nombre maximum de combattants atteint !" (ce_1.java:76-79).
const fighterCreateNoMoreRoom uint8 = 20

// sendFighterCreateStatus answers 6001 with a specific failure status, so the
// client shows the right reason instead of a generic error.
func (s *Session) sendFighterCreateStatus(status uint8) error {
	frame, err := protocol.EncodeS2C(protocol.OpFighterCreateResult,
		protocol.NewWriter().U8(status).Bytes())
	if err != nil {
		return err
	}
	return s.Send(frame)
}
