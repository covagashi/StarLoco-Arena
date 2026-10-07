package web

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	"github.com/StarLoco/arena-2.70/internal/config"
)

// webhookReceiver collects POSTed Discord payloads.
type webhookReceiver struct {
	mu     sync.Mutex
	bodies []map[string]any
}

func (r *webhookReceiver) handler(w http.ResponseWriter, req *http.Request) {
	body, _ := io.ReadAll(req.Body)
	var payload map[string]any
	r.mu.Lock()
	defer r.mu.Unlock()
	if json.Unmarshal(body, &payload) == nil {
		r.bodies = append(r.bodies, payload)
	}
	w.WriteHeader(http.StatusNoContent) // Discord's success code
}

func (r *webhookReceiver) count() int {
	r.mu.Lock()
	defer r.mu.Unlock()
	return len(r.bodies)
}

func (r *webhookReceiver) last() map[string]any {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.bodies[len(r.bodies)-1]
}

func waitForWebhook(t *testing.T, recv *webhookReceiver, want int) {
	t.Helper()
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		if recv.count() >= want {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatalf("webhook received %d posts, want %d", recv.count(), want)
}

// TestBugReportForwardsToWebhook posts a real retail-shaped report and checks
// the async Discord-compatible notification reaches the configured URL.
func TestBugReportForwardsToWebhook(t *testing.T) {
	recv := &webhookReceiver{}
	hook := httptest.NewServer(http.HandlerFunc(recv.handler))
	t.Cleanup(hook.Close)

	s, _ := newTestServer(t, func(c *config.WebConfig) {
		c.BugReportsEnabled = true
		c.BugReportDir = "" // report rows only; no screenshot dir needed here
		c.BugReportWebhook = hook.URL
	})

	body, ctype := clientBugReportBody(t, nil)
	rec := postBugReport(t, s, body, ctype)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}

	waitForWebhook(t, recv, 1)
	payload := recv.last()

	embeds, ok := payload["embeds"].([]any)
	if !ok || len(embeds) != 1 {
		t.Fatalf("payload has embeds=%v, want one embed", payload["embeds"])
	}
	embed := embeds[0].(map[string]any)
	if embed["title"] != "Zaap arch renders below the platform" {
		t.Errorf("embed title = %v", embed["title"])
	}
	if embed["description"] != "The arch is drawn under the platform" {
		t.Errorf("embed description = %v", embed["description"])
	}
	// The reporter's account name rides a field, never the webhook URL.
	fields, ok := embed["fields"].([]any)
	if !ok {
		t.Fatalf("embed fields missing: %v", embed)
	}
	found := map[string]any{}
	for _, f := range fields {
		fm := f.(map[string]any)
		found[fm["name"].(string)] = fm["value"]
	}
	if found["Account"] != "reporter" {
		t.Errorf("Account field = %v, want reporter", found["Account"])
	}
	if found["Lang"] != "fr" {
		t.Errorf("Lang field = %v, want fr", found["Lang"])
	}
}

// TestBugReportNoWebhookIsSilent: with no webhook configured the report is
// still stored and nothing is posted anywhere.
func TestBugReportNoWebhookIsSilent(t *testing.T) {
	s, st := newTestServer(t, func(c *config.WebConfig) {
		c.BugReportsEnabled = true
		c.BugReportWebhook = ""
	})
	body, ctype := clientBugReportBody(t, nil)
	if rec := postBugReport(t, s, body, ctype); rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	if _, total, err := st.BugReports.List(true, 10, 0); err != nil || total != 1 {
		t.Fatalf("stored %d reports, want 1 (err %v)", total, err)
	}
}

// TestBugReportWebhookFailureStillOK: a dead webhook URL must not leak into
// the player-visible answer - the report is already stored when it runs.
func TestBugReportWebhookFailureStillOK(t *testing.T) {
	s, _ := newTestServer(t, func(c *config.WebConfig) {
		c.BugReportsEnabled = true
		// 127.0.0.1:1 refuses instantly - an unreachable webhook.
		c.BugReportWebhook = "http://127.0.0.1:1/hook"
	})
	body, ctype := clientBugReportBody(t, nil)
	if rec := postBugReport(t, s, body, ctype); rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200 even with a dead webhook", rec.Code)
	}
	// Give the async forward a moment to fail - it must not panic.
	time.Sleep(100 * time.Millisecond)
}
