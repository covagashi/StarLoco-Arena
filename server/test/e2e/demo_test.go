package e2e

import (
	"testing"

	"github.com/StarLoco/arena-2.70/internal/game"
	"github.com/StarLoco/arena-2.70/internal/testclient"
)

// S44: the web demo's "Play" button logs in under a "demo-…" login the
// browser generated. With demo_accounts on, that creates a demo account
// even though auto-registration is off, a few per address and hour; any
// other unknown login is still refused.
func TestDemoAccounts(t *testing.T) {
	t.Parallel()
	st, addr := testServerWithDeps(t, func(d *game.Deps) {
		d.Limits = game.Limits{DisableAutoRegister: true, DemoAccounts: true, DemoPerIPHour: 2}
	})
	login := func(name, pw string) error {
		c, err := testclient.Dial(addr)
		if err != nil {
			t.Fatalf("dial: %v", err)
		}
		defer c.Close()
		return c.Login(name, pw)
	}

	first := "demo-aaaaaaaaaaaaaaaaaaa1"
	c, _ := dialLogin(t, addr, first, "Visitor")
	_ = c.Close()
	acc, err := st.Accounts.FindByName(first)
	if err != nil {
		t.Fatalf("the demo login made no account: %v", err)
	}
	if !acc.IsDemo || acc.IsAdmin {
		t.Errorf("demo account: is_demo=%v is_admin=%v, want true/false (even as the first account)",
			acc.IsDemo, acc.IsAdmin)
	}
	if err := login(first, "pw"); err != nil {
		t.Errorf("the same browser could not come back: %v", err)
	}
	if err := login(first, "other"); err == nil {
		t.Error("a demo account opened with the wrong key")
	}
	if err := login("plainname", "pw"); err == nil {
		t.Error("an ordinary unknown login was created with auto-registration off")
	}
	if err := login("demo-short", "pw"); err == nil {
		t.Error("a login that is not a generated demo login made an account")
	}
	if err := login("demo-aaaaaaaaaaaaaaaaaaa2", "pw"); err != nil {
		t.Errorf("second demo account from one address refused: %v", err)
	}
	if err := login("demo-aaaaaaaaaaaaaaaaaaa3", "pw"); err == nil {
		t.Error("a third demo account in the hour from one address was created (cap 2)")
	}
}

// Without demo_accounts a demo login is only an ordinary login: refused
// when auto-registration is off.
func TestDemoAccountsOffByDefault(t *testing.T) {
	t.Parallel()
	_, addr := testServerWithDeps(t, func(d *game.Deps) {
		d.Limits = game.Limits{DisableAutoRegister: true}
	})
	c, err := testclient.Dial(addr)
	if err != nil {
		t.Fatalf("dial: %v", err)
	}
	defer c.Close()
	if err := c.Login("demo-aaaaaaaaaaaaaaaaaaa1", "pw"); err == nil {
		t.Error("a demo account was created with demo_accounts off")
	}
}
