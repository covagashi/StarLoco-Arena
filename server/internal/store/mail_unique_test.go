package store

import (
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
)

// TestMailDoesNotStackUniqueCards covers the unique-card rule on mail CLAIM.
//
// The retail client only WARNS here (ay.java:213-218 shows
// error.mail.uniqueCoachCardAlreadyThere and sends 15006 regardless), and its own
// message - "you can't receive ALL the kards from this email" - says the server
// was expected to grant a subset. Without the rule, mailing a unique card from a
// second account and claiming it while already holding one pushes quantity past 1
// on a template the game guarantees is singular; the retail client then refuses
// to render the extra copy, desyncing the inventory permanently.
func TestMailDoesNotStackUniqueCards(t *testing.T) {
	st := newTestStore(t)

	const uniqueTmpl, ordinaryTmpl = int32(300), int32(100)
	st.Mail.IsUnique = func(id int32) bool { return id == uniqueTmpl }

	// A real coach row is required: coach_cards has a FOREIGN KEY on it.
	acc, err := st.Accounts.CreateAccount("mailuniq", "pw", false)
	if err != nil {
		t.Fatalf("account: %v", err)
	}
	coach, err := st.Coaches.Create(acc.ID, "MailUniq", 0, 0, 0)
	if err != nil {
		t.Fatalf("coach: %v", err)
	}
	receiver := coach.ID

	// The receiver already holds one of each.
	for _, tmpl := range []int32{uniqueTmpl, ordinaryTmpl} {
		if err := st.DB().Create(&domain.CoachCard{
			CoachID: receiver, TemplateID: tmpl, Quantity: 1,
		}).Error; err != nil {
			t.Fatalf("seed %d: %v", tmpl, err)
		}
	}

	m := &domain.Mail{SenderID: 1, SenderName: "S", ReceiverID: receiver,
		ReceiverName: "R", Title: "t", Body: "b"}
	stored, sErr := st.Mail.Send(m, []int32{uniqueTmpl, ordinaryTmpl})
	if sErr != nil {
		t.Fatalf("send: %v", sErr)
	}
	if _, err := st.Mail.TakeAttachments(receiver, stored.ID); err != nil {
		t.Fatalf("take: %v", err)
	}

	qty := map[int32]int16{}
	var rows []domain.CoachCard
	if err := st.DB().Where("coach_id = ?", receiver).Find(&rows).Error; err != nil {
		t.Fatalf("load: %v", err)
	}
	for _, r := range rows {
		qty[r.TemplateID] += r.Quantity
	}

	if qty[uniqueTmpl] != 1 {
		t.Errorf("unique template quantity = %d, want 1 - a card the game "+
			"guarantees is singular was duplicated", qty[uniqueTmpl])
	}
	// The ordinary card must still stack, or the guard is too broad.
	if qty[ordinaryTmpl] != 2 {
		t.Errorf("ordinary template quantity = %d, want 2 - the rule must only "+
			"apply to unique cards", qty[ordinaryTmpl])
	}
}
