package store

import (
	"errors"
	"sync"
	"time"

	"gorm.io/gorm"

	"github.com/StarLoco/arena-2.70/internal/domain"
)

// ErrMailboxFull is returned when the recipient already holds the maximum number
// of mails (the client shows "votre boîte aux lettres est pleine").
var ErrMailboxFull = errors.New("store: mailbox full")

// MailRepo persists in-game mail.
type MailRepo struct{ db *gorm.DB }

// ListForCoach returns every mail still visible to a coach: those it received and
// has not deleted, plus those it sent and has not deleted. Newest first.
func (r *MailRepo) ListForCoach(coachID uint) ([]domain.Mail, error) {
	var out []domain.Mail
	err := r.db.Preload("Cards").
		Where("(receiver_id = ? AND deleted_by_receiver = ?) OR (sender_id = ? AND deleted_by_sender = ?)",
			coachID, false, coachID, false).
		Order("sent_at_millis DESC").
		Find(&out).Error
	return out, err
}

// InboxCount counts the mails currently occupying a coach's inbox (what the
// capacity limit applies to).
func (r *MailRepo) InboxCount(coachID uint) (int64, error) {
	var n int64
	err := r.db.Model(&domain.Mail{}).
		Where("receiver_id = ? AND deleted_by_receiver = ?", coachID, false).
		Count(&n).Error
	return n, err
}

// Send stores a new mail, rejecting it when the recipient's inbox is full.
// Attachments are capped at domain.MailMaxAttachments; title/body are truncated
// to the client's own input limits. Returns the stored mail (with its new id).
func (r *MailRepo) Send(m *domain.Mail, cardIDs []int32) (*domain.Mail, error) {
	// SECURITY: truncate BEFORE the mailbox-full check.
	//
	// The order used to be reversed, and the handler echoes the record back on
	// ErrMailboxFull - so a ~64 KB body made that reply exceed MaxFrameLen,
	// EncodeS2C errored, and the error propagated up to kill the session. Only the
	// sender was affected, but it was a self-inflicted disconnect reachable from
	// one frame, and it existed purely because the size bound came second.
	//
	// Bounding first also means every early return below carries an already-safe
	// record, which is the property worth having rather than a fix for one path.
	if len(cardIDs) > domain.MailMaxAttachments {
		cardIDs = cardIDs[:domain.MailMaxAttachments]
	}
	m.Title = truncate(m.Title, domain.MailMaxTitle)
	m.Body = truncate(m.Body, domain.MailMaxBody)

	n, err := r.InboxCount(m.ReceiverID)
	if err != nil {
		return nil, err
	}
	if n >= domain.MailboxCapacity {
		return nil, ErrMailboxFull
	}
	if m.SentAtMillis == 0 {
		m.SentAtMillis = time.Now().UnixMilli()
	}
	m.Cards = make([]domain.MailCard, 0, len(cardIDs))
	for _, id := range cardIDs {
		m.Cards = append(m.Cards, domain.MailCard{TemplateID: id})
	}
	if err := r.db.Create(m).Error; err != nil {
		return nil, err
	}
	return m, nil
}

// Delete hides a mail from one side. When both sides have deleted it the row (and
// any uncollected attachments) is removed for good.
func (r *MailRepo) Delete(coachID uint, mailIDs []uint) error {
	if len(mailIDs) == 0 {
		return nil
	}
	return r.db.Transaction(func(tx *gorm.DB) error {
		var mails []domain.Mail
		if err := tx.Where("id IN ?", mailIDs).Find(&mails).Error; err != nil {
			return err
		}
		for i := range mails {
			m := &mails[i]
			switch {
			case m.ReceiverID == coachID:
				m.DeletedByReceiver = true
			case m.SenderID == coachID:
				m.DeletedBySender = true
			default:
				continue // not this coach's mail
			}
			if m.DeletedByReceiver && m.DeletedBySender {
				if err := tx.Where("mail_id = ?", m.ID).Delete(&domain.MailCard{}).Error; err != nil {
					return err
				}
				if err := tx.Delete(&domain.Mail{}, m.ID).Error; err != nil {
					return err
				}
				continue
			}
			if err := tx.Model(&domain.Mail{}).Where("id = ?", m.ID).
				Updates(map[string]any{
					"deleted_by_receiver": m.DeletedByReceiver,
					"deleted_by_sender":   m.DeletedBySender,
				}).Error; err != nil {
				return err
			}
		}
		return nil
	})
}

// MarkRead flags a received mail as read.
func (r *MailRepo) MarkRead(coachID, mailID uint) error {
	return r.db.Model(&domain.Mail{}).
		Where("id = ? AND receiver_id = ?", mailID, coachID).
		Update("read", true).Error
}

// TakeAttachments hands every card attached to a mail to its RECEIVER: the cards
// are granted to the coach's inventory and detached from the mail, atomically.
// Returns the template ids actually collected (empty if there were none).
// isUnique reports whether a template may exist only once per coach. Injected by
// the game layer so the store does not need the gamedata tables; nil means "no
// uniqueness data", in which case the rule is skipped.
var (
	isUniqueMu sync.RWMutex
	isUnique   func(templateID int32) bool
)

// SetUniqueCardPredicate wires the uniqueness rule into the mail store.
func SetUniqueCardPredicate(fn func(templateID int32) bool) {
	isUniqueMu.Lock()
	isUnique = fn
	isUniqueMu.Unlock()
}

// cardIsUnique reads the injected predicate under its lock — parallel e2e
// servers each call SetUniqueCardPredicate at boot while in-flight
// TakeAttachments transactions are reading it.
func cardIsUnique(templateID int32) bool {
	isUniqueMu.RLock()
	fn := isUnique
	isUniqueMu.RUnlock()
	return fn != nil && fn(templateID)
}

func (r *MailRepo) TakeAttachments(coachID, mailID uint) ([]int32, error) {
	var collected []int32
	err := r.db.Transaction(func(tx *gorm.DB) error {
		var m domain.Mail
		if err := tx.Preload("Cards").First(&m, mailID).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return ErrNotFound
			}
			return err
		}
		if m.ReceiverID != coachID || len(m.Cards) == 0 {
			return nil // not yours, or nothing to collect
		}
		for _, c := range m.Cards {
			var existing domain.CoachCard
			err := tx.Where("coach_id = ? AND template_id = ? AND pos = 0", coachID, c.TemplateID).
				First(&existing).Error
			switch {
			case err == nil:
				// SECURITY: a unique card may not stack past 1. The retail client
				// only WARNS here (ay.java:213-218 shows
				// error.mail.uniqueCoachCardAlreadyThere and sends 15006 anyway),
				// and its own message - "you can't receive ALL the kards from this
				// email" - says the server was expected to grant a subset. Without
				// this, mailing a unique card from a second account and claiming it
				// while already holding one pushes quantity past 1 on a template the
				// game guarantees is singular; the retail client then refuses to
				// render the extra copy, desyncing the inventory permanently.
				if cardIsUnique(c.TemplateID) {
					continue // leave it in the mail rather than duplicating it
				}
				if err := tx.Model(&domain.CoachCard{}).Where("id = ?", existing.ID).
					Update("quantity", gorm.Expr("quantity + 1")).Error; err != nil {
					return err
				}
			case errors.Is(err, gorm.ErrRecordNotFound):
				if err := tx.Create(&domain.CoachCard{
					CoachID: coachID, TemplateID: c.TemplateID, Quantity: 1,
				}).Error; err != nil {
					return err
				}
			default:
				return err
			}
			collected = append(collected, c.TemplateID)
		}
		// Mail keeps existing (so it can still be read) but loses its attachments.
		return tx.Where("mail_id = ?", m.ID).Delete(&domain.MailCard{}).Error
	})
	if err != nil {
		return nil, err
	}
	return collected, nil
}

// truncate clips s to at most n runes (the client counts characters, not bytes).
func truncate(s string, n int) string {
	r := []rune(s)
	if len(r) <= n {
		return s
	}
	return string(r[:n])
}
