package web

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/StarLoco/arena-2.70/internal/domain"
)

// forwardBugReportWebhook pushes an accepted bug report to the configured
// Discord-compatible webhook. It runs asynchronously from the handler: the
// report is already stored locally, so a webhook outage only delays a
// notification and must never slow or fail the player's 200/OK.
//
// The body is the standard incoming-webhook shape ({content, embeds[]}),
// which Discord accepts natively and most chat "webhook" integrations parse.
// Player free text goes through json.Marshal, not string concatenation.
func (s *Server) forwardBugReportWebhook(report *domain.BugReport) {
	url := s.cfg.BugReportWebhook
	if url == "" {
		return
	}
	payload := map[string]any{
		"username": "Bug Reports",
		"embeds": []map[string]any{{
			"title":       webhookText(report.Title, 256),
			"description": webhookText(report.Seen, 1500),
			"color":       0xE74C3C,
			"fields": webhookFields(
				webhookField("Type", report.Type, true),
				webhookField("Account", report.AccountName, true),
				webhookField("Coach", report.CoachName, true),
				webhookField("World", webhookWorld(report), true),
				webhookField("Lang", report.Lang, true),
				webhookField("Client", report.ClientVersion, true),
				webhookField("Expected", report.Awaited, false),
				webhookField("Reproduce", report.Reproduce, false),
			),
			"footer": map[string]any{"text": fmt.Sprintf("report #%d", report.ID)},
		}},
	}
	body, err := json.Marshal(payload)
	if err != nil {
		s.log.Warn("bug report webhook: marshal failed", "err", err)
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		s.log.Warn("bug report webhook: request failed", "err", err)
		return
	}
	req.Header.Set("Content-Type", "application/json")

	// Never log the URL: a webhook URL is a credential - anyone holding it can
	// post to the channel.
	resp, err := s.webhookHTTP().Do(req)
	if err != nil {
		s.log.Warn("bug report webhook: post failed", "err", err)
		return
	}
	defer func() { _ = resp.Body.Close() }()
	// Discord answers 200 or 204 on success; treat any other status as a
	// transient misconfiguration worth one log line, not an operator alarm.
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		s.log.Warn("bug report webhook: unexpected status", "status", resp.StatusCode)
	}
}

// webhookHTTP resolves the HTTP client used for webhook posts: the injected
// test client when present, else a default with a bounded timeout.
func (s *Server) webhookHTTP() *http.Client {
	if s.webhookClient != nil {
		return s.webhookClient
	}
	return &http.Client{Timeout: 10 * time.Second}
}

func webhookField(name, value string, inline bool) map[string]any {
	return map[string]any{
		"name":   name,
		"value":  webhookText(value, 512),
		"inline": inline,
	}
}

func webhookFields(fields ...map[string]any) []map[string]any {
	out := make([]map[string]any, 0, len(fields))
	for _, f := range fields {
		if f["value"] == "" {
			continue
		}
		out = append(out, f)
	}
	return out
}

func webhookWorld(r *domain.BugReport) string {
	if r.WorldName == "" && r.WorldX == 0 && r.WorldY == 0 {
		return ""
	}
	return fmt.Sprintf("%s (%d, %d)", r.WorldName, r.WorldX, r.WorldY)
}

// webhookText bounds one string. Discord rejects payloads over its limits and
// reports can carry a 60k-char log tail; a notification needs only the gist.
func webhookText(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n-1] + "…"
}
