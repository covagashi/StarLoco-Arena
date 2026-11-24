// Package mail sends the server's few emails (S51: the password-reset code)
// over SMTP with implicit TLS (port 465). Without a configured host it only
// logs what it would have sent — the dev mode the smokes read the code from.
package mail

import (
	"crypto/rand"
	"crypto/tls"
	"encoding/hex"
	"fmt"
	"log/slog"
	"mime"
	"net"
	"net/smtp"
	"strconv"
	"strings"
	"time"
)

// Config is where and as whom to send.
type Config struct {
	Host     string
	Port     int // default 465 (implicit TLS)
	Username string
	Password string
	From     string // the sender address
	FromName string // default "Pippop Arena"
}

// Enabled reports whether the config can send at all.
func (c Config) Enabled() bool {
	return strings.TrimSpace(c.Host) != "" && strings.TrimSpace(c.From) != ""
}

// Mailer sends the reset codes.
type Mailer struct {
	cfg Config
	log *slog.Logger
	// send delivers a built message; swapped in tests.
	send func(cfg Config, to string, msg []byte) error
}

// New builds a Mailer; an unconfigured one logs instead of sending.
func New(cfg Config, log *slog.Logger) *Mailer {
	if cfg.Port == 0 {
		cfg.Port = 465
	}
	if strings.TrimSpace(cfg.FromName) == "" {
		cfg.FromName = "Pippop Arena"
	}
	if log == nil {
		log = slog.Default()
	}
	return &Mailer{cfg: cfg, log: log, send: sendTLS}
}

// SendResetCode emails a password-reset code to the address.
func (m *Mailer) SendResetCode(to, code string) error {
	if !m.cfg.Enabled() {
		m.log.Info("password reset code NOT emailed (mail not configured, dev mode: logged instead)",
			"to", to, "code", code)
		return nil
	}
	msg := BuildResetMessage(m.cfg, to, code, time.Now())
	if err := m.send(m.cfg, to, msg); err != nil {
		m.log.Warn("password reset email failed", "to", to, "err", err)
		return err
	}
	m.log.Info("password reset code emailed", "to", to)
	return nil
}

// ResetSubject is the reset email's subject; the player-facing name is
// always Pippop Arena.
const ResetSubject = "Pippop Arena — tu código"

// BuildResetMessage is the whole RFC 5322 message: short, Spanish then
// English, plain text.
func BuildResetMessage(cfg Config, to, code string, now time.Time) []byte {
	body := "Tu código para cambiar la contraseña de Pippop Arena:\r\n\r\n" +
		"    " + code + "\r\n\r\n" +
		"Escríbelo en el juego. Caduca en 15 minutos.\r\n" +
		"Si no lo has pedido tú, ignora este correo.\r\n\r\n" +
		"---\r\n\r\n" +
		"Your code to change your Pippop Arena password:\r\n\r\n" +
		"    " + code + "\r\n\r\n" +
		"Type it in the game. It expires in 15 minutes.\r\n" +
		"If you did not ask for it, ignore this email.\r\n"
	var id [12]byte
	_, _ = rand.Read(id[:])
	domain := cfg.From
	if i := strings.LastIndex(domain, "@"); i >= 0 {
		domain = domain[i+1:]
	}
	var b strings.Builder
	fmt.Fprintf(&b, "From: %s <%s>\r\n", mime.QEncoding.Encode("utf-8", cfg.FromName), cfg.From)
	fmt.Fprintf(&b, "To: <%s>\r\n", to)
	fmt.Fprintf(&b, "Subject: %s\r\n", mime.QEncoding.Encode("utf-8", ResetSubject))
	fmt.Fprintf(&b, "Date: %s\r\n", now.Format(time.RFC1123Z))
	fmt.Fprintf(&b, "Message-ID: <%s@%s>\r\n", hex.EncodeToString(id[:]), domain)
	b.WriteString("MIME-Version: 1.0\r\n")
	b.WriteString("Content-Type: text/plain; charset=UTF-8\r\n")
	b.WriteString("Content-Transfer-Encoding: 8bit\r\n\r\n")
	b.WriteString(body)
	return []byte(b.String())
}

// sendTLS delivers over SMTP wrapped in TLS from the first byte (465).
func sendTLS(cfg Config, to string, msg []byte) error {
	addr := net.JoinHostPort(cfg.Host, strconv.Itoa(cfg.Port))
	dialer := &net.Dialer{Timeout: 15 * time.Second}
	conn, err := tls.DialWithDialer(dialer, "tcp", addr, &tls.Config{ServerName: cfg.Host, MinVersion: tls.VersionTLS12})
	if err != nil {
		return err
	}
	_ = conn.SetDeadline(time.Now().Add(30 * time.Second))
	c, err := smtp.NewClient(conn, cfg.Host)
	if err != nil {
		_ = conn.Close()
		return err
	}
	defer func() { _ = c.Close() }()
	if cfg.Username != "" {
		if err := c.Auth(smtp.PlainAuth("", cfg.Username, cfg.Password, cfg.Host)); err != nil {
			return err
		}
	}
	if err := c.Mail(cfg.From); err != nil {
		return err
	}
	if err := c.Rcpt(to); err != nil {
		return err
	}
	w, err := c.Data()
	if err != nil {
		return err
	}
	if _, err := w.Write(msg); err != nil {
		return err
	}
	if err := w.Close(); err != nil {
		return err
	}
	return c.Quit()
}
