package e2e

import (
	"testing"
	"time"

	"github.com/StarLoco/arena-2.70/internal/game"
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/testclient"
)

// fakeMailer keeps the reset codes the server would have emailed.
type fakeMailer struct{ codes chan [2]string }

func (m *fakeMailer) SendResetCode(to, code string) error {
	m.codes <- [2]string{to, code}
	return nil
}

func accountCode(t *testing.T, c *testclient.Client, op uint16) uint8 {
	t.Helper()
	f, _, err := c.WaitFor(op, testclient.DefaultTimeout)
	if err != nil {
		t.Fatalf("waiting for %d: %v", op, err)
	}
	return testclient.NewR(f.Payload).U8()
}

// S51, «Guardar mi progreso»: a demo account saved with an email keeps its
// coach; the browser comes back with email + its demo key (now a device
// key), the player from anywhere with email + password («Ya tengo cuenta»,
// which hands out a new key); an email login never auto-registers; a
// forgotten password is reset with the emailed code, before logging in,
// and the reset forgets every device key.
func TestSaveDemoAccount(t *testing.T) {
	t.Parallel()
	mailer := &fakeMailer{codes: make(chan [2]string, 4)}
	st, addr := testServerWithDeps(t, func(d *game.Deps) {
		// auto-registration ON: an "@" login must still never create one.
		d.Limits = game.Limits{DemoAccounts: true}
		d.Mailer = mailer
	})
	const demo = "demo-aaaaaaaaaaaaaaaaaaa1"
	dial := func() *testclient.Client {
		c, err := testclient.Dial(addr)
		if err != nil {
			t.Fatalf("dial: %v", err)
		}
		t.Cleanup(func() { _ = c.Close() })
		return c
	}
	login := func(name, pw string) error {
		c := dial()
		defer c.Close()
		return c.Login(name, pw)
	}

	c, coachID := dialLogin(t, addr, demo, "Visitor") // key "pw"
	claim := func(email, pw string) uint8 {
		_ = c.Send(3, protocol.OpClaimAccount, testclient.NewW().Str8(email).Str8(pw).Bytes())
		return accountCode(t, c, protocol.OpClaimAccountResult)
	}
	if code := claim("not-an-email", "secret123"); code != protocol.AccountSaveBadEmail {
		t.Errorf("bad email: code %d", code)
	}
	if code := claim("ana@example.com", "short"); code != protocol.AccountSaveWeakPass {
		t.Errorf("short password: code %d", code)
	}
	if _, err := st.Accounts.CreateAccount("taken@example.com", "whatever1", false); err != nil {
		t.Fatal(err)
	}
	if code := claim("Taken@Example.com", "secret123"); code != protocol.AccountSaveEmailTaken {
		t.Errorf("taken email: code %d", code)
	}
	if code := claim(" Ana@Example.com ", "secret123"); code != protocol.AccountSaveOK {
		t.Fatalf("claim: code %d", code)
	}
	if code := claim("ana2@example.com", "secret123"); code != protocol.AccountSaveNotDemo {
		t.Errorf("second claim: code %d, want not demo", code)
	}
	_ = c.Close()

	acc, err := st.Accounts.FindByName("ana@example.com")
	if err != nil || acc.IsDemo || acc.CoachID == nil || int64(*acc.CoachID) != coachID {
		t.Fatalf("saved account = %+v (%v), want the demo's coach %d and not demo", acc, err, coachID)
	}
	if err := login(demo, "pw"); err == nil {
		// auto-register is on, so the old demo login now makes a NEW demo
		// account — that is fine, it is not the saved one.
		if a, _ := st.Accounts.FindByName(demo); a != nil && a.ID == acc.ID {
			t.Error("the old demo login still names the saved account")
		}
	}

	// The browser: email (any case) + the demo key.
	if err := login("ANA@example.com", "pw"); err != nil {
		t.Errorf("email + demo key: %v", err)
	}
	// «Ya tengo cuenta»: email + password, then a new device key.
	c2 := dial()
	if err := c2.Login("ana@example.com", "secret123"); err != nil {
		t.Fatalf("email + password: %v", err)
	}
	_ = c2.Send(3, protocol.OpIssueKey, nil)
	f, _, err := c2.WaitFor(protocol.OpDeviceKey, testclient.DefaultTimeout)
	if err != nil {
		t.Fatal(err)
	}
	key := testclient.NewR(f.Payload).Str8()
	if len(key) != 32 {
		t.Fatalf("device key %q, want 32 hex chars", key)
	}
	_ = c2.Close()
	if err := login("ana@example.com", key); err != nil {
		t.Errorf("email + issued key: %v", err)
	}
	if err := login("ana@example.com", "wrong-one"); err == nil {
		t.Error("a wrong password opened the saved account")
	}

	// An unknown email never auto-registers, even with auto_register on.
	if err := login("typo@example.com", "secret123"); err == nil {
		t.Error("an unknown email login was accepted")
	}
	if _, err := st.Accounts.FindByName("typo@example.com"); err == nil {
		t.Error("an unknown email login created an account")
	}

	// Forgot the password: before logging in.
	r := dial()
	_ = r.Send(3, protocol.OpResetRequest, testclient.NewW().Str8("nobody@example.com").Bytes())
	if code := accountCode(t, r, protocol.OpResetRequestResult); code != protocol.AccountSaveOK {
		t.Errorf("unknown email reset: code %d, want sent (no enumeration)", code)
	}
	_ = r.Send(3, protocol.OpResetRequest, testclient.NewW().Str8("Ana@Example.com").Bytes())
	if code := accountCode(t, r, protocol.OpResetRequestResult); code != protocol.AccountSaveOK {
		t.Fatalf("reset request: code %d", code)
	}
	var sent [2]string
	select {
	case sent = <-mailer.codes:
	case <-time.After(5 * time.Second):
		t.Fatal("no code emailed")
	}
	select {
	case extra := <-mailer.codes:
		t.Errorf("an unknown email got a code: %v", extra)
	default:
	}
	if sent[0] != "ana@example.com" || len(sent[1]) != 6 {
		t.Fatalf("emailed %v", sent)
	}
	confirm := func(code, pw string) uint8 {
		_ = r.Send(3, protocol.OpResetConfirm, testclient.NewW().Str8("ana@example.com").Str8(code).Str8(pw).Bytes())
		return accountCode(t, r, protocol.OpResetConfirmResult)
	}
	wrong := "000000"
	if sent[1] == wrong {
		wrong = "111111"
	}
	if code := confirm(wrong, "newsecret1"); code != protocol.AccountSaveWrongCode {
		t.Errorf("wrong code: %d", code)
	}
	if code := confirm(sent[1], "short"); code != protocol.AccountSaveWeakPass {
		t.Errorf("weak new password: %d", code)
	}
	if code := confirm(sent[1], "newsecret1"); code != protocol.AccountSaveOK {
		t.Fatalf("reset confirm: %d", code)
	}
	if code := confirm(sent[1], "newsecret2"); code != protocol.AccountSaveCodeExpired {
		t.Errorf("code reused: %d, want expired", code)
	}
	if err := login("ana@example.com", "newsecret1"); err != nil {
		t.Errorf("login with the new password: %v", err)
	}
	for _, old := range []string{"secret123", "pw", key} {
		if err := login("ana@example.com", old); err == nil {
			t.Errorf("%q still opens the account after the reset", old)
		}
	}
}
