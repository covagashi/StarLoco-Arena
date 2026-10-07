package web

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	"github.com/StarLoco/arena-2.70/internal/domain"
)

// The retail client's bug dialog POSTs multipart/form-data to
// `<bugReportURL><lang>/bug-report` and reads the reply, expecting the first
// line to be exactly "OK" (client aOG.a: anything else is logged as
// "Error while calling BugReport website"). The player is told the report was
// sent BEFORE the request is made, so a failure here is invisible to them -
// which is why every branch below still answers 200/"OK" once the body has been
// accepted, and problems are logged server-side instead.
//
// The form's field names come straight from the client and are matched verbatim:
//
//	screenshot                        JPEG file, "screenBug.jpg"
//	bug[title] [type]                 what the player wrote
//	bug[seen_comportment]             ... "what happened"
//	bug[awaited_comportment]          ... "what should have happened"
//	bug[way_to_reproduce]
//	log, replay                       client log tail + replay buffer
//	user[character][id] [name]        the client's own claim, NOT authenticated
//	user[character][world][x] [y] [name]
//	user[account][id] [name]
//	user[lang]
//	config[...]                       screen, client_version, OS, VM, memory,
//	                                  graphic-device, and thread-<id> (dropped)
const (
	// maxBugReportBody caps the whole multipart body. A screenshot is a
	// full-size JPEG (~100-400 KB) and the log can be long, so this is generous
	// - but it is a hard stop, because the endpoint is unauthenticated.
	maxBugReportBody = 12 << 20 // 12 MiB
	// maxBugReportMemory is what multipart may buffer in RAM; the rest spills
	// to temp files that ParseMultipartForm cleans up.
	maxBugReportMemory = 1 << 20 // 1 MiB
	// maxBugText bounds the free-text columns. TEXT is only 64 KiB on MySQL, so
	// staying under it keeps the same schema working on every supported dialect
	// instead of silently truncating on one (cf. B-125).
	maxBugText = 60000
	// maxScreenshot bounds what is written to disk per report.
	maxScreenshot = 8 << 20
)

// handleBugReport accepts a submission from the client's bug dialog.
//
// It is deliberately UNAUTHENTICATED: the client sends no session or password
// with this request, so there is nothing to authenticate against. Everything the
// player's client claims about itself is therefore treated as untrusted input -
// the account name is stored as claimed AND resolved to a real account id only
// if it matches, so the admin console can show "claims to be X" without implying
// the server believes it.
func (s *Server) handleBugReport(w http.ResponseWriter, r *http.Request) {
	if !s.cfg.BugReportsEnabled {
		http.NotFound(w, r)
		return
	}

	// Rate limited on the same per-address basis as sign-up, because this
	// endpoint writes rows and files with no credential attached.
	if !s.bugLimiter.allow(s.clientIP(r)) {
		s.log.Warn("bug report rate limited", "addr", s.clientIP(r))
		// Still "OK": the player was already told it was sent, and telling the
		// client otherwise only produces a log line on their machine.
		writeBugOK(w)
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, maxBugReportBody)
	if err := r.ParseMultipartForm(maxBugReportMemory); err != nil {
		s.log.Warn("bug report: cannot parse body", "err", err)
		writeBugOK(w)
		return
	}
	defer func() {
		if r.MultipartForm != nil {
			_ = r.MultipartForm.RemoveAll()
		}
	}()

	form := r.MultipartForm
	if form == nil {
		writeBugOK(w)
		return
	}

	get := func(name string) string { return firstValue(form.Value, name) }

	report := &domain.BugReport{
		Title:     truncate(get("bug[title]"), 255),
		Type:      truncate(get("bug[type]"), 120),
		Seen:      truncateTail(get("bug[seen_comportment]"), maxBugText),
		Awaited:   truncateTail(get("bug[awaited_comportment]"), maxBugText),
		Reproduce: truncateTail(get("bug[way_to_reproduce]"), maxBugText),

		AccountName: truncate(get("user[account][name]"), 64),
		CoachName:   truncate(get("user[character][name]"), 64),
		CoachRef:    atoi64(get("user[character][id]")),
		WorldX:      int32(atoi64(get("user[character][world][x]"))),
		WorldY:      int32(atoi64(get("user[character][world][y]"))),
		WorldName:   truncate(get("user[character][world][name]"), 120),
		Lang:        truncate(get("user[lang]"), 16),

		ClientVersion: truncate(get("config[client_version]"), 120),
		ScreenWidth:   int32(atoi64(get("config[screen][width]"))),
		ScreenHeight:  int32(atoi64(get("config[screen][height]"))),
		Fullscreen:    strings.EqualFold(get("config[screen][fullscreen]"), "true"),
		SystemInfo:    truncateTail(systemInfo(form.Value), maxBugText),

		// The client sends the log tail as text; keep the END of it, which is
		// where the stack trace that prompted the report will be.
		Log:    truncateTail(get("log"), maxBugText),
		Replay: truncateTail(get("replay"), maxBugText),

		RemoteAddr: s.clientIP(r),
	}
	if report.Title == "" {
		report.Title = "(no title)"
	}

	// Resolve the claimed account name to a real id, without trusting it.
	if report.AccountName != "" {
		if acc, err := s.store.Accounts.FindByName(report.AccountName); err == nil && acc != nil {
			report.AccountID = acc.ID
		}
	}

	if name, err := s.storeScreenshot(form.File); err != nil {
		s.log.Warn("bug report: screenshot not stored", "err", err)
	} else {
		report.ScreenshotFile = name
	}

	if err := s.store.BugReports.Create(report); err != nil {
		s.log.Error("bug report: cannot store", "err", err)
		writeBugOK(w)
		return
	}

	s.log.Info("bug report received",
		"id", report.ID, "title", report.Title, "type", report.Type,
		"account", report.AccountName, "coach", report.CoachName,
		"screenshot", report.ScreenshotFile != "")
	// Optional operator notification (Discord-compatible webhook). Async on
	// purpose: the report is already stored, and a chat outage must not delay
	// or fail the reply to a player.
	if s.cfg.BugReportWebhook != "" {
		go s.forwardBugReportWebhook(report)
	}
	writeBugOK(w)
}

// writeBugOK sends the one reply the client accepts. aOG.a reads the first line
// and logs an error unless it is exactly "OK".
func writeBugOK(w http.ResponseWriter) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	_, _ = io.WriteString(w, "OK\n")
}

// storeScreenshot writes the uploaded JPEG into the configured directory and
// returns its file name. An empty name (with a nil error) means there was
// nothing to store, or storage is switched off.
func (s *Server) storeScreenshot(files map[string][]*multipart.FileHeader) (string, error) {
	dir := strings.TrimSpace(s.cfg.BugReportDir)
	if dir == "" {
		return "", nil
	}
	hdrs := files["screenshot"]
	if len(hdrs) == 0 {
		return "", nil
	}
	if hdrs[0].Size > maxScreenshot {
		return "", fmt.Errorf("screenshot is %d bytes, over the %d cap", hdrs[0].Size, maxScreenshot)
	}

	src, err := hdrs[0].Open()
	if err != nil {
		return "", err
	}
	defer func() { _ = src.Close() }()

	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", err
	}

	// Random name: the client always calls it "screenBug.jpg", and the name is
	// echoed nowhere, so there is no reason to let a submitted string anywhere
	// near a filesystem path.
	var buf [16]byte
	if _, err := rand.Read(buf[:]); err != nil {
		return "", err
	}
	name := hex.EncodeToString(buf[:]) + ".jpg"

	dst, err := os.OpenFile(filepath.Join(dir, name), os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o644)
	if err != nil {
		return "", err
	}
	defer func() { _ = dst.Close() }()

	if _, err := io.Copy(dst, io.LimitReader(src, maxScreenshot)); err != nil {
		_ = os.Remove(filepath.Join(dir, name))
		return "", err
	}
	return name, nil
}

// screenshotPath resolves a stored screenshot's name to a path, refusing
// anything that is not a plain file name. The names are generated here, so this
// can only fire on a tampered database row - but it is the difference between
// that and an arbitrary file read.
func (s *Server) screenshotPath(name string) (string, bool) {
	dir := strings.TrimSpace(s.cfg.BugReportDir)
	if dir == "" || name == "" {
		return "", false
	}
	if name != filepath.Base(name) || strings.ContainsAny(name, `/\`) {
		return "", false
	}
	return filepath.Join(dir, name), true
}

// systemInfo flattens the config[...] fields into one "key=value" per line,
// dropping the per-thread block. The client sends five fields for EVERY live
// thread, which is hundreds of lines that never help triage and would dominate
// the stored text.
func systemInfo(values map[string][]string) string {
	keys := make([]string, 0, len(values))
	for k := range values {
		if !strings.HasPrefix(k, "config[") {
			continue
		}
		if strings.HasPrefix(k, "config[thread-") {
			continue
		}
		switch k {
		case "config[screen][width]", "config[screen][height]",
			"config[screen][fullscreen]", "config[client_version]":
			continue // stored as their own columns
		}
		keys = append(keys, k)
	}
	sort.Strings(keys)

	var b strings.Builder
	for _, k := range keys {
		b.WriteString(strings.TrimPrefix(k, "config"))
		b.WriteString(" = ")
		b.WriteString(firstValue(values, k))
		b.WriteByte('\n')
	}
	return b.String()
}

func firstValue(m map[string][]string, key string) string {
	if v := m[key]; len(v) > 0 {
		return strings.TrimSpace(v[0])
	}
	return ""
}

func atoi64(s string) int64 {
	n, err := strconv.ParseInt(strings.TrimSpace(s), 10, 64)
	if err != nil {
		// The client sends floats for the screen size (getWidth() on a
		// Dimension2D), e.g. "1024.0" - take the integer part rather than 0.
		if f, ferr := strconv.ParseFloat(strings.TrimSpace(s), 64); ferr == nil {
			return int64(f)
		}
		return 0
	}
	return n
}

// truncate keeps the FRONT of a short field (a title reads from the left).
func truncate(s string, n int) string {
	s = strings.TrimSpace(s)
	if len(s) <= n {
		return s
	}
	return s[:n]
}

// truncateTail keeps the END of a long field: for a log, the last lines are the
// ones that describe the crash.
func truncateTail(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return "[... truncated ...]\n" + s[len(s)-n:]
}
