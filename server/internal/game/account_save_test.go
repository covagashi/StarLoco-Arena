package game

import (
	"testing"
	"time"
)

func TestValidEmail(t *testing.T) {
	for in, want := range map[string]string{
		" Ana@Example.COM ": "ana@example.com",
		"a.b+c@mail.co":     "a.b+c@mail.co",
	} {
		if got, ok := validEmail(in); !ok || got != want {
			t.Errorf("validEmail(%q) = %q,%v, want %q,true", in, got, ok, want)
		}
	}
	for _, bad := range []string{"", "ana", "ana@", "@x.com", "ana@localhost", "a@@b.com",
		"ana @x.com", "Ana <ana@x.com>", "ana@x..com", "ana@.x.com", "ana@x.com.",
		"a@b.c" /* too short */, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa@x.com"} {
		if _, ok := validEmail(bad); ok {
			t.Errorf("validEmail(%q) accepted", bad)
		}
	}
}

func TestResetPerIPHour(t *testing.T) {
	now := time.Now()
	g := newConnGuard(Limits{ResetPerIPHour: 2})
	g.now = func() time.Time { return now }
	if !g.allowReset("1.2.3.4") || !g.allowReset("1.2.3.4") {
		t.Fatal("the first two reset requests must pass")
	}
	if g.allowReset("1.2.3.4") {
		t.Error("a third reset request inside the hour passed")
	}
	if !g.allowReset("5.6.7.8") {
		t.Error("another address was blocked")
	}
	now = now.Add(61 * time.Minute)
	if !g.allowReset("1.2.3.4") {
		t.Error("the cap did not reset after an hour")
	}
}
