package game

import (
	"errors"
	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"gorm.io/gorm"
)

func registerInventoryHandlers(r *Router, d *Deps) {
	r.Register(protocol.OpCoachInventoryUpdateRequest, handleInventoryRequest)
	r.Register(protocol.OpCoachEquipmentUpdateRequest, handleEquipmentRequest)
	r.Register(protocol.OpAddToTome, handleAddToTome)
}

// grantStarterCards gives a brand-new coach a handful of cards so the inventory
// UI isn't empty. Picks the lowest-id templates from gamedata (deterministic).
func (s *Session) grantStarterCards(coach *domain.Coach) {
	if s.deps.Cards == nil || len(coach.Inventory) > 0 {
		return
	}
	// Take up to 10 lowest card ids.
	ids := make([]int32, 0, s.deps.Cards.Len())
	for id := range s.deps.Cards.All() {
		ids = append(ids, id)
	}
	sortInt32(ids)
	if len(ids) > 10 {
		ids = ids[:10]
	}
	db := s.deps.Store.DB()
	for _, id := range ids {
		card := domain.CoachCard{CoachID: coach.ID, TemplateID: id, Quantity: 1}
		db.Create(&card)
		coach.Inventory = append(coach.Inventory, card)
	}
	s.log.Info("granted starter cards", "count", len(ids), "coach", coach.Name)
}

// pushInventory sends the coach's full inventory as a CoachInventoryUpdate
// (5200): section 3 (updated inventory) lists each unequipped card as
// {i32 referenceCardId, i16 quantity}.
func (s *Session) pushInventory(coach *domain.Coach) error {
	w := protocol.NewWriter()
	w.U16(0) // section 1: added-equip (none)
	w.U16(0) // section 2: removed shorts (none)

	// section 3: updated inventory (unequipped cards)
	inv := make([]domain.CoachCard, 0, len(coach.Inventory))
	for _, c := range coach.Inventory {
		if c.Pos == 0 {
			inv = append(inv, c)
		}
	}
	w.U16(uint16(len(inv)))
	for _, c := range inv {
		w.I32(c.TemplateID) // card wy_2 = [i32 referenceCardId]
		w.U16(uint16(c.Quantity))
	}

	w.U16(0) // section 4: ints (none)

	frame, err := protocol.EncodeS2C(protocol.OpCoachInventoryUpdate, w.Bytes())
	if err != nil {
		return err
	}
	if err := s.Send(frame); err != nil {
		return err
	}
	// Every card grant the player can see goes through here (shop, fusion, fight
	// winnings, challenge rewards, exchange, mail), so this is the one place that
	// catches them all for the card-gated achievements. Hooking each grant site
	// individually would leave whichever one is added next silently uncovered.
	s.evaluateAchievements()
	return nil
}

// handleInventoryRequest processes CoachInventoryUpdateRequest(5203):
// [u16 count] + count×i64 uid, and answers by re-pushing the inventory.
//
// It does NOT act on the uids, and that is a protocol limit rather than an
// unfinished feature — worth stating, because "implement the destructive ops"
// looks like a small task until you ask what the uids identify.
//
// What the message means: `sj_1.yG` builds it from the cards that were in the
// client's reference set but are no longer in its current inventory view, and
// sends it right after the 5201 equipment layout. So 5203 is "these cards are
// gone from my inventory" — a REMOVAL notice, not a lock. (Our opcode comment
// used to say "remove/lock"; there is no lock here and no action discriminator
// in the payload at all.)
//
// Why the uids are unusable: the client's card object gets its unique id in
// `eb_1.b(ByteBuffer)`, which reads ONLY the i32 reference-card id off the wire
// and then assigns `this.aFL = uq_1.ahR()` — a client-local monotonic counter
// (`bRK + (bRI & 0xFFFFFF)`, incrementing). The server never sends a per-card
// identity and never sees that number, so an incoming uid cannot be resolved to
// a CoachCard row. Deleting "the card the player probably meant" would be
// guessing at destructive removals against bound and undestructible cards.
//
// Making this work means giving inventory cards a server-assigned identity on
// the wire first (section 3 of the 5200 push currently carries only
// {i32 templateId, u16 quantity}), which is a wire-format change, not a handler
// change.
func handleInventoryRequest(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	return s.pushInventory(s.Coach)
}

// handleAddToTome processes AddToTome(5204, client `ajm_2`): [i32 templateId].
// Fired by the card context-menu "inscribe in grimoire" action (`ST.b(8)`) —
// the client marks the entry `isInTome` locally at click time, so there is no
// reply to send. Cards carry no instance uid on the wire (2.70 mints them
// client-side, `eb_1`/`uq_1.ahR()`), which is why the id is the template — all
// client lookups use `Math.abs(wy_2.jf())`. Our tome is grow-only and login
// sync already records every owned template, so the honest behaviour is to
// verify the coach actually holds the card and ensure it is recorded: an
// explicitly inscribed card then survives being traded away, matching the
// grimoire's "collection that never forgets" semantics.
func handleAddToTome(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	id, err := r.I32()
	if err != nil {
		return err
	}
	if id < 0 {
		id = -id
	}
	if id == 0 {
		return nil
	}
	owned := false
	for _, card := range s.Coach.Inventory {
		if card.TemplateID == id && card.Quantity > 0 {
			owned = true
			break
		}
	}
	if !owned {
		s.log.Debug("add-to-tome for unowned card dropped", "coach", s.Coach.Name, "template", id)
		return nil
	}
	_, err = s.deps.Store.Coaches.SyncTome(s.Coach.ID, []int32{id})
	return err
}

// handleEquipmentRequest processes CoachEquipmentUpdateRequest(5201): 14×i32
// slot references (0 = empty). Persists the equipped layout and re-pushes.
func handleEquipmentRequest(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	// SECURITY: no equipment changes while queued or in a fight.
	//
	// runPostFightMeta reads the LIVE inventory at fight END (sessionSetBonus /
	// opposingSetBonus), so a coach could fight in whatever gear it liked and then
	// equip a wound-cancel / death-reduction / XP% set in the last seconds and have
	// it apply to the outcome. In evolution mode that is a way to dodge permanent
	// death, and opposingSetBonus lets the same trick push maluses onto the
	// opponent at settlement time.
	if s.rosterLocked() {
		return s.refuseRosterEdit("coach equipment")
	}
	r := protocol.NewReader(f.Payload)
	var slots [14]int32
	for i := range slots {
		v, err := r.I32()
		if err != nil {
			break
		}
		slots[i] = v
	}
	s.applyEquipment(s.Coach, slots)
	return s.pushInventory(s.Coach)
}

// applyEquipment sets Pos for each inventory card according to the 14 wire
// slots (slot value = card TemplateID; Pos = slotIndex+1; 0 = unequipped).
// applyEquipment writes the coach's 14 equipment slots.
//
// CORRECTNESS: Pos lives on the STACK row, not on a copy, so setting it used to
// equip the whole stack. A CoachCard{TemplateID: X, Quantity: 5, Pos: 0} became
// Pos: 3 in one write and all five copies vanished from pushInventory (which
// filters Pos == 0), became untradeable (handlers_exchange keys on pos = 0),
// unfusable and unmailable - while counting as ONE for set bonuses. Unequipping
// restored them, so it was loss-of-availability rather than destruction, but the
// inventory a player saw did not match the one they had.
//
// It also produced duplicate rows: BuyCards stacks only onto a pos = 0 row, so
// buying X while X was equipped created a second row, and a later "unequip all"
// reset both to pos = 0. Nothing enforces uniqueness on (coach, template, pos),
// so downstream First() lookups then saw only one of them.
//
// Equipping now SPLITS one unit off the stack and merges it back on unequip, so a
// row is only ever wholly equipped or wholly not.
func (s *Session) applyEquipment(coach *domain.Coach, slots [14]int32) {
	db := s.deps.Store.DB()

	err := db.Transaction(func(tx *gorm.DB) error {
		// Unequip everything first, merging each freed unit back into the coach's
		// unequipped stack for that template so stacks do not fragment over time.
		for i := range coach.Inventory {
			row := &coach.Inventory[i]
			if row.Pos == 0 {
				continue
			}
			if err := mergeIntoUnequippedStack(tx, coach.ID, row); err != nil {
				return err
			}
		}
		// Re-read: merging may have deleted rows and changed quantities.
		var inv []domain.CoachCard
		if err := tx.Where("coach_id = ?", coach.ID).Find(&inv).Error; err != nil {
			return err
		}

		for slotIdx, templateID := range slots {
			if templateID == 0 {
				continue
			}
			// SECURITY: the card's TYPE decides its slot (aMK.java:6-36). Without
			// this any owned template could occupy any of the 14 slots, so fourteen
			// cards of one set unlocked every set threshold at once - and those
			// thresholds drive resurrection chance, XP, morale, fatigue, reputation
			// and wound/death chance.
			// A template gamedata does not know is ALLOWED through: we cannot judge
			// a type we never decoded, and it is harmless because the thing this
			// rule protects - equippedCountsPerSet - skips unknown templates too
			// (they have no CardSet), so an unknown card can never drive a set
			// threshold. It still has to be owned. This also keeps the rule inert
			// on a data-less build rather than making every equip fail.
			if tmpl := s.cardTemplate(templateID); tmpl != nil &&
				!coachCardFitsSlot(tmpl.Type, int16(slotIdx)) {
				s.log.Info("equip refused: card type cannot occupy that slot",
					"coach", coach.ID, "card", templateID,
					"type", tmpl.Type, "slot", slotIdx)
				continue
			}
			pos := int16(slotIdx + 1)
			if err := equipOneUnit(tx, coach.ID, templateID, pos, inv); err != nil {
				return err
			}
		}
		return tx.Where("coach_id = ?", coach.ID).Find(&coach.Inventory).Error
	})
	if err != nil {
		// SECURITY/OBSERVABILITY: these writes used to be fire-and-forget, so a
		// failed equip looked exactly like a successful one and the client's view
		// silently diverged from the database.
		s.log.Warn("apply equipment", "coach", coach.ID, "err", err)
	}
}

// mergeIntoUnequippedStack returns one equipped row's unit to the coach's
// unequipped stack for the same template, deleting the now-empty equipped row.
func mergeIntoUnequippedStack(tx *gorm.DB, coachID uint, row *domain.CoachCard) error {
	var base domain.CoachCard
	err := tx.Where("coach_id = ? AND template_id = ? AND pos = 0", coachID, row.TemplateID).
		First(&base).Error
	switch {
	case err == nil:
		if uErr := tx.Model(&domain.CoachCard{}).Where("id = ?", base.ID).
			UpdateColumn("quantity", gorm.Expr("quantity + ?", row.Quantity)).Error; uErr != nil {
			return uErr
		}
		return tx.Delete(&domain.CoachCard{}, row.ID).Error
	case errors.Is(err, gorm.ErrRecordNotFound):
		// No unequipped stack yet: this row simply becomes it.
		return tx.Model(&domain.CoachCard{}).Where("id = ?", row.ID).
			UpdateColumn("pos", 0).Error
	default:
		return err
	}
}

// equipOneUnit moves exactly ONE copy of templateID into pos, splitting the
// unequipped stack when it holds more than one.
func equipOneUnit(tx *gorm.DB, coachID uint, templateID int32, pos int16, inv []domain.CoachCard) error {
	var stack domain.CoachCard
	err := tx.Where("coach_id = ? AND template_id = ? AND pos = 0 AND quantity > 0",
		coachID, templateID).First(&stack).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil // not owned; silently ignore, as the old code did
	}
	if err != nil {
		return err
	}
	if stack.Quantity <= 1 {
		return tx.Model(&domain.CoachCard{}).Where("id = ?", stack.ID).
			UpdateColumn("pos", pos).Error
	}
	if err := tx.Model(&domain.CoachCard{}).Where("id = ?", stack.ID).
		UpdateColumn("quantity", gorm.Expr("quantity - 1")).Error; err != nil {
		return err
	}
	return tx.Create(&domain.CoachCard{
		CoachID:    coachID,
		TemplateID: templateID,
		Quantity:   1,
		Pos:        pos,
	}).Error
}

// sortInt32 sorts a slice of int32 ascending (small, no import needed).
func sortInt32(a []int32) {
	for i := 1; i < len(a); i++ {
		for j := i; j > 0 && a[j-1] > a[j]; j-- {
			a[j-1], a[j] = a[j], a[j-1]
		}
	}
}

// cardTemplate is a nil-safe lookup: Deps.Cards is nil on a data-less build (and
// in tests), and dereferencing it here dropped the session with a panic.
func (s *Session) cardTemplate(templateID int32) *gamedata.CoachCard {
	if s.deps == nil || s.deps.Cards == nil {
		return nil
	}
	return s.deps.Cards.Get(templateID)
}
