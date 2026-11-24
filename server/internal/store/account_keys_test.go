package store

import (
	"errors"
	"testing"
	"time"

	"github.com/StarLoco/arena-2.70/internal/domain"
)

// S51: a demo account saved with an email keeps everything (coach included),
// stops being demo, logs in with the new password and still with the demo's
// key (now a browser key).
func TestClaimDemo(t *testing.T) {
	s := newTestStore(t)
	demo, err := s.Accounts.CreateDemoAccount("demo-aaaaaaaaaaaaaaaaaaa1", "demokey")
	if err != nil {
		t.Fatal(err)
	}
	coach, err := s.Coaches.Create(demo.ID, "Visitor", 0, 0, 0)
	if err != nil {
		t.Fatal(err)
	}
	if err := s.Accounts.ClaimDemo(demo.ID, "  Ana@Example.COM ", "secret123"); err != nil {
		t.Fatalf("ClaimDemo: %v", err)
	}
	acc, err := s.Accounts.FindByName("ana@example.com")
	if err != nil {
		t.Fatalf("the claimed account is not under its lower-cased email: %v", err)
	}
	if acc.ID != demo.ID || acc.IsDemo {
		t.Errorf("claimed account: id=%d demo=%v, want id %d and not demo", acc.ID, acc.IsDemo, demo.ID)
	}
	if acc.CoachID == nil || *acc.CoachID != coach.ID {
		t.Errorf("the coach was lost: coach_id=%v, want %d", acc.CoachID, coach.ID)
	}
	if !s.Accounts.VerifyPassword(acc, "secret123") {
		t.Error("the new password does not open the account")
	}
	if s.Accounts.VerifyPassword(acc, "demokey") {
		t.Error("the demo key is still the password")
	}
	if !s.Accounts.VerifyKey(acc.ID, "demokey") {
		t.Error("the demo key is not a browser key after the claim")
	}
	if s.Accounts.VerifyKey(acc.ID, "other") {
		t.Error("a wrong key opened the account")
	}
	// A second claim: not demo any more.
	if err := s.Accounts.ClaimDemo(demo.ID, "b@example.com", "secret123"); !errors.Is(err, ErrNotDemo) {
		t.Errorf("re-claim: err = %v, want ErrNotDemo", err)
	}
}

func TestClaimDemoRefusals(t *testing.T) {
	s := newTestStore(t)
	if _, err := s.Accounts.CreateAccount("ana@example.com", "pw", false); err != nil {
		t.Fatal(err)
	}
	plain, _ := s.Accounts.CreateAccount("plain", "pw", false)
	demo, _ := s.Accounts.CreateDemoAccount("demo-aaaaaaaaaaaaaaaaaaa1", "demokey")

	if err := s.Accounts.ClaimDemo(demo.ID, "ANA@example.com", "secret123"); !errors.Is(err, ErrNameTaken) {
		t.Errorf("taken email: err = %v, want ErrNameTaken", err)
	}
	acc, _ := s.Accounts.FindByID(demo.ID)
	if !acc.IsDemo || acc.Name != "demo-aaaaaaaaaaaaaaaaaaa1" {
		t.Errorf("a refused claim changed the account: %+v", acc)
	}
	if n, _ := s.Accounts.CountKeys(demo.ID); n != 0 {
		t.Errorf("a refused claim left %d keys", n)
	}
	if err := s.Accounts.ClaimDemo(plain.ID, "p@example.com", "secret123"); !errors.Is(err, ErrNotDemo) {
		t.Errorf("non-demo: err = %v, want ErrNotDemo", err)
	}
}

func TestAccountKeys(t *testing.T) {
	s := newTestStore(t)
	acc, _ := s.Accounts.CreateAccount("ana@example.com", "pw", false)
	other, _ := s.Accounts.CreateAccount("bob@example.com", "pw", false)
	if err := s.Accounts.AddKey(acc.ID, "k1"); err != nil {
		t.Fatal(err)
	}
	if !s.Accounts.VerifyKey(acc.ID, "k1") {
		t.Error("an added key does not verify")
	}
	if s.Accounts.VerifyKey(other.ID, "k1") || s.Accounts.VerifyKey(acc.ID, "") {
		t.Error("a key opened another account, or the empty key passed")
	}
	var k domain.AccountKey
	s.DB().Where("account_id = ?", acc.ID).First(&k)
	if k.KeyHash == "k1" || len(k.KeyHash) != 64 {
		t.Errorf("key stored as %q, want its sha256 hex", k.KeyHash)
	}
	for i := 0; i < maxAccountKeys+3; i++ {
		if err := s.Accounts.AddKey(acc.ID, "x"+string(rune('a'+i))); err != nil {
			t.Fatal(err)
		}
	}
	if n, _ := s.Accounts.CountKeys(acc.ID); n != maxAccountKeys {
		t.Errorf("%d keys kept, want the cap %d", n, maxAccountKeys)
	}
	if err := s.Accounts.ClearKeys(acc.ID); err != nil {
		t.Fatal(err)
	}
	if s.Accounts.VerifyKey(acc.ID, "xa") {
		t.Error("a cleared key still opens the account")
	}
}

func TestResetCodes(t *testing.T) {
	s := newTestStore(t)
	acc, _ := s.Accounts.CreateAccount("ana@example.com", "oldpass1", false)
	_ = s.Accounts.AddKey(acc.ID, "browser")
	now := time.Now()

	if err := s.Accounts.ResetPassword(acc.ID, "123456", "newpass1", now); !errors.Is(err, ErrResetExpired) {
		t.Errorf("no code asked: err = %v, want ErrResetExpired", err)
	}

	// Expiry.
	_ = s.Accounts.CreateResetCode(acc.ID, "111111", now)
	if err := s.Accounts.VerifyResetCode(acc.ID, "111111", now.Add(ResetCodeTTL+time.Second)); !errors.Is(err, ErrResetExpired) {
		t.Errorf("expired code: err = %v, want ErrResetExpired", err)
	}

	// A new request replaces the old one.
	_ = s.Accounts.CreateResetCode(acc.ID, "222222", now)
	_ = s.Accounts.CreateResetCode(acc.ID, "333333", now)
	if at, ok, _ := s.Accounts.ResetRequestedAt(acc.ID); !ok || at.IsZero() {
		t.Error("ResetRequestedAt sees no pending code")
	}
	if err := s.Accounts.VerifyResetCode(acc.ID, "222222", now); !errors.Is(err, ErrResetWrong) {
		t.Errorf("replaced code: err = %v, want ErrResetWrong", err)
	}

	// Attempts: 5 wrong tries in all end it, even for the right code after.
	for i := 0; i < ResetMaxAttempts-1; i++ {
		if err := s.Accounts.VerifyResetCode(acc.ID, "000000", now); !errors.Is(err, ErrResetWrong) {
			t.Fatalf("wrong try %d: err = %v", i+2, err)
		}
	}
	if err := s.Accounts.VerifyResetCode(acc.ID, "333333", now); !errors.Is(err, ErrResetExpired) {
		t.Errorf("right code after %d wrong: err = %v, want ErrResetExpired", ResetMaxAttempts, err)
	}

	// The right code: new password, browser keys gone, code used up.
	_ = s.Accounts.CreateResetCode(acc.ID, "444444", now)
	if err := s.Accounts.ResetPassword(acc.ID, "444444", "newpass1", now.Add(time.Minute)); err != nil {
		t.Fatalf("ResetPassword: %v", err)
	}
	got, _ := s.Accounts.FindByID(acc.ID)
	if !s.Accounts.VerifyPassword(got, "newpass1") || s.Accounts.VerifyPassword(got, "oldpass1") {
		t.Error("the password did not change")
	}
	if s.Accounts.VerifyKey(acc.ID, "browser") {
		t.Error("a browser key survived the reset")
	}
	if err := s.Accounts.ResetPassword(acc.ID, "444444", "again123", now); !errors.Is(err, ErrResetExpired) {
		t.Errorf("code reused: err = %v, want ErrResetExpired", err)
	}
}

// Deleting an account takes its keys and reset code with it.
func TestDeleteAccountRemovesKeys(t *testing.T) {
	s := newTestStore(t)
	acc, _ := s.Accounts.CreateAccount("ana@example.com", "pw", false)
	_ = s.Accounts.AddKey(acc.ID, "k")
	_ = s.Accounts.CreateResetCode(acc.ID, "123456", time.Now())
	if err := s.Accounts.DeleteAccount(acc.ID); err != nil {
		t.Fatal(err)
	}
	var n int64
	s.DB().Model(&domain.AccountKey{}).Count(&n)
	var m int64
	s.DB().Model(&domain.PasswordReset{}).Count(&m)
	if n != 0 || m != 0 {
		t.Errorf("left %d keys and %d reset codes", n, m)
	}
}
