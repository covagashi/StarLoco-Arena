package mail

import (
	"bytes"
	"io"
	"log/slog"
	"mime"
	"net/mail"
	"strings"
	"testing"
	"time"
)

func TestResetMessage(t *testing.T) {
	cfg := Config{From: "no-reply@example.com", FromName: "Pippop Arena"}
	raw := BuildResetMessage(cfg, "ana@example.com", "123456", time.Now())
	msg, err := mail.ReadMessage(bytes.NewReader(raw))
	if err != nil {
		t.Fatalf("not a valid message: %v", err)
	}
	subj, _ := new(mime.WordDecoder).DecodeHeader(msg.Header.Get("Subject"))
	if subj != ResetSubject {
		t.Errorf("subject %q, want %q", subj, ResetSubject)
	}
	from, err := mail.ParseAddress(msg.Header.Get("From"))
	if err != nil || from.Name != "Pippop Arena" || from.Address != cfg.From {
		t.Errorf("from = %+v (%v)", from, err)
	}
	body, _ := io.ReadAll(msg.Body)
	for _, want := range []string{"123456", "Caduca en 15 minutos", "expires in 15 minutes"} {
		if !strings.Contains(string(body), want) {
			t.Errorf("body lacks %q", want)
		}
	}
	if strings.Contains(string(raw), "StarLoco") {
		t.Error("the email names StarLoco; players only see Pippop Arena")
	}
}

// Unconfigured: logs the code (dev mode) and sends nothing; configured:
// hands the message to the sender.
func TestSendResetCode(t *testing.T) {
	var logBuf bytes.Buffer
	m := New(Config{}, slog.New(slog.NewTextHandler(&logBuf, nil)))
	m.send = func(Config, string, []byte) error { t.Error("an unconfigured mailer tried to send"); return nil }
	if err := m.SendResetCode("ana@example.com", "654321"); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(logBuf.String(), "code=654321") || !strings.Contains(logBuf.String(), "dev mode") {
		t.Errorf("dev mode log = %q", logBuf.String())
	}

	sent := ""
	m = New(Config{Host: "smtp.example.com", From: "no-reply@example.com"}, slog.New(slog.NewTextHandler(io.Discard, nil)))
	m.send = func(cfg Config, to string, msg []byte) error {
		if cfg.Port != 465 {
			t.Errorf("port %d, want the 465 default", cfg.Port)
		}
		sent = to
		return nil
	}
	if err := m.SendResetCode("ana@example.com", "654321"); err != nil || sent != "ana@example.com" {
		t.Errorf("configured send: to=%q err=%v", sent, err)
	}
}
