package game

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"math/big"
	"net/mail"
	"strings"
	"time"

	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store"
)

// «Guardar mi progreso» (S51): a web demo account becomes an ordinary one
// under the player's email and a password, without losing anything; the
// browser keeps a device key instead of the password (on itch.io every HTML5
// game shares one origin); a forgotten password is reset with a 6-digit code
// emailed to the player and typed back in the game. All over the game socket:
// in itch.io's iframe, leaving for the web portal would only confuse.

const (
	minPasswordLen = 8
	maxPasswordLen = 72 // bcrypt's limit, in bytes
	maxEmailLen    = 64 // Account.Name's column
	// maxKeysPerSession bounds 60072 on one socket (the client asks once,
	// right after logging in with the password).
	maxKeysPerSession = 3
	// resetResendGap is how soon one account may get another reset code.
	resetResendGap = time.Minute
)

func registerAccountSaveHandlers(r *Router, _ *Deps) {
	r.Register(protocol.OpClaimAccount, handleClaimAccount)
	r.Register(protocol.OpIssueKey, handleIssueKey)
	r.Register(protocol.OpResetRequest, handleResetRequest)
	r.Register(protocol.OpResetConfirm, handleResetConfirm)
}

// validEmail normalises an email login (trimmed, lower-cased) and reports
// whether it looks like an address: one "@", a dotted domain, no spaces or
// display name, and short enough to be an account name.
func validEmail(raw string) (string, bool) {
	e := store.NormalizeEmail(raw)
	if len(e) < 6 || len(e) > maxEmailLen || strings.Count(e, "@") != 1 ||
		strings.ContainsAny(e, " \t\r\n<>\"(),;:\\[]") {
		return e, false
	}
	at := strings.IndexByte(e, '@')
	local, domain := e[:at], e[at+1:]
	if local == "" || !strings.Contains(domain, ".") || strings.HasPrefix(domain, ".") ||
		strings.HasSuffix(domain, ".") || strings.Contains(domain, "..") {
		return e, false
	}
	if a, err := mail.ParseAddress(e); err != nil || a.Address != e {
		return e, false
	}
	return e, true
}

func validPassword(pw string) bool { return len(pw) >= minPasswordLen && len(pw) <= maxPasswordLen }

func (s *Session) sendAccountCode(op uint16, code uint8) error {
	frame, err := protocol.EncodeS2C(op, protocol.NewWriter().U8(code).Bytes())
	if err != nil {
		return err
	}
	return s.Send(frame)
}

// handleClaimAccount (60070) saves the caller's demo account under an email
// and a password (store.ClaimDemo), then answers 60071.
func handleClaimAccount(s *Session, f *protocol.C2SFrame) error {
	if s.Account == nil || s.deps.Store == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	email, err1 := r.StringU8UTF8()
	pw, err2 := r.StringU8UTF8()
	if err1 != nil || err2 != nil {
		return nil
	}
	reply := func(code uint8) error { return s.sendAccountCode(protocol.OpClaimAccountResult, code) }
	if !s.Account.IsDemo {
		return reply(protocol.AccountSaveNotDemo)
	}
	email, ok := validEmail(email)
	if !ok {
		return reply(protocol.AccountSaveBadEmail)
	}
	if !validPassword(pw) {
		return reply(protocol.AccountSaveWeakPass)
	}
	// The claim costs a bcrypt hash: same budget as a login.
	if !s.allowLoginAttempt() {
		return reply(protocol.AccountSaveRateLimited)
	}
	switch err := s.deps.Store.Accounts.ClaimDemo(s.Account.ID, email, pw); {
	case errors.Is(err, store.ErrNameTaken):
		return reply(protocol.AccountSaveEmailTaken)
	case errors.Is(err, store.ErrNotDemo):
		return reply(protocol.AccountSaveNotDemo)
	case err != nil:
		s.log.Error("claim account failed", "account", s.Account.ID, "err", err)
		return reply(protocol.AccountSaveFailed)
	}
	s.log.Info("demo account saved", "account", s.Account.ID, "from", s.Account.Name, "email", email)
	s.Account.Name = email
	s.Account.IsDemo = false
	if err := reply(protocol.AccountSaveOK); err != nil {
		return err
	}
	if s.godot.Load() {
		return s.sendClientConfig() // account_demo is now 0
	}
	return nil
}

// handleIssueKey (60072) gives a saved account's browser a new device key
// (16 random bytes, hex) and stores its hash; the browser logs in with email
// + key from then on. A demo account, or a socket past its budget, gets "".
func handleIssueKey(s *Session, _ *protocol.C2SFrame) error {
	if s.Account == nil || s.deps.Store == nil {
		return nil
	}
	key := ""
	if !s.Account.IsDemo && s.keysIssued < maxKeysPerSession {
		var b [16]byte
		if _, err := rand.Read(b[:]); err != nil {
			return err
		}
		k := hex.EncodeToString(b[:])
		if err := s.deps.Store.Accounts.AddKey(s.Account.ID, k); err != nil {
			s.log.Error("issue key failed", "account", s.Account.ID, "err", err)
		} else {
			key = k
			s.keysIssued++
			s.log.Info("device key issued", "account", s.Account.ID)
		}
	}
	frame, err := protocol.EncodeS2C(protocol.OpDeviceKey, protocol.NewWriter().StringU8UTF8(key).Bytes())
	if err != nil {
		return err
	}
	return s.Send(frame)
}

// sixDigits is a uniformly random 6-digit code.
func sixDigits() (string, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(1_000_000))
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%06d", n.Int64()), nil
}

// handleResetRequest (60074) emails a reset code to a saved account. It
// works before authentication (the player cannot log in) and answers
// "sent" for an unknown email too, so the answer never tells whether an
// email plays here. Capped per address (connGuard.allowReset) and per
// account (one code a minute, silently).
func handleResetRequest(s *Session, f *protocol.C2SFrame) error {
	if s.deps.Store == nil {
		return nil
	}
	raw, err := protocol.NewReader(f.Payload).StringU8UTF8()
	if err != nil {
		return nil
	}
	reply := func(code uint8) error { return s.sendAccountCode(protocol.OpResetRequestResult, code) }
	email, ok := validEmail(raw)
	if !ok {
		return reply(protocol.AccountSaveBadEmail)
	}
	if s.guard != nil && !s.guard.allowReset(s.remoteIP) {
		s.log.Warn("password reset rate limit hit", "ip", s.remoteIP)
		return reply(protocol.AccountSaveRateLimited)
	}
	acc, err := s.deps.Store.Accounts.FindByName(email)
	if err != nil || acc.IsDemo {
		s.log.Info("password reset for an unknown email (answered as sent)", "email", email)
		return reply(protocol.AccountSaveOK)
	}
	now := time.Now()
	if at, pending, _ := s.deps.Store.Accounts.ResetRequestedAt(acc.ID); pending && now.Sub(at) < resetResendGap {
		s.log.Info("password reset asked again too soon (no new code)", "account", acc.ID)
		return reply(protocol.AccountSaveOK)
	}
	code, err := sixDigits()
	if err != nil {
		return err
	}
	if err := s.deps.Store.Accounts.CreateResetCode(acc.ID, code, now); err != nil {
		s.log.Error("password reset: store code", "account", acc.ID, "err", err)
		return reply(protocol.AccountSaveFailed)
	}
	if m := s.deps.Mailer; m != nil {
		go func() { _ = m.SendResetCode(email, code) }() // SMTP is slow; it logs its own failure
	} else {
		s.log.Info("password reset code NOT emailed (mail not configured, dev mode: logged instead)",
			"to", email, "code", code)
	}
	return reply(protocol.AccountSaveOK)
}

// handleResetConfirm (60076) sets a new password with the emailed code
// (store.ResetPassword, which also forgets every device key). Works before
// authentication; the client then logs in with email + new password.
func handleResetConfirm(s *Session, f *protocol.C2SFrame) error {
	if s.deps.Store == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	raw, err1 := r.StringU8UTF8()
	code, err2 := r.StringU8UTF8()
	pw, err3 := r.StringU8UTF8()
	if err1 != nil || err2 != nil || err3 != nil {
		return nil
	}
	reply := func(c uint8) error { return s.sendAccountCode(protocol.OpResetConfirmResult, c) }
	email, ok := validEmail(raw)
	if !ok {
		return reply(protocol.AccountSaveBadEmail)
	}
	if !validPassword(pw) {
		return reply(protocol.AccountSaveWeakPass)
	}
	if !s.allowLoginAttempt() { // a right code costs a bcrypt hash
		return reply(protocol.AccountSaveRateLimited)
	}
	acc, err := s.deps.Store.Accounts.FindByName(email)
	if err != nil || acc.IsDemo {
		return reply(protocol.AccountSaveWrongCode)
	}
	switch err := s.deps.Store.Accounts.ResetPassword(acc.ID, strings.TrimSpace(code), pw, time.Now()); {
	case errors.Is(err, store.ErrResetWrong):
		return reply(protocol.AccountSaveWrongCode)
	case errors.Is(err, store.ErrResetExpired):
		return reply(protocol.AccountSaveCodeExpired)
	case err != nil:
		s.log.Error("password reset failed", "account", acc.ID, "err", err)
		return reply(protocol.AccountSaveFailed)
	}
	s.log.Info("password reset done", "account", acc.ID)
	return reply(protocol.AccountSaveOK)
}
