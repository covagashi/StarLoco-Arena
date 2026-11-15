package wsconn

import (
	"context"
	"io"
	"net/http/httptest"
	"testing"
	"time"
)

// TestStreamAcrossMessages: bytes written as separate messages read back as
// one stream, in any split, and a closed peer reads as io.EOF.
func TestStreamAcrossMessages(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	ln, err := Listen(ctx, "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()
	got := make(chan []byte, 1)
	go func() {
		c, err := ln.Accept()
		if err != nil {
			return
		}
		buf, _ := io.ReadAll(c)
		got <- buf
	}()
	c, err := Dial("ws://"+ln.Addr().String()+"/", time.Second)
	if err != nil {
		t.Fatal(err)
	}
	for _, part := range []string{"\x00\x09", "\x03\x00\x01", "abcd"} {
		if _, err := c.Write([]byte(part)); err != nil {
			t.Fatal(err)
		}
	}
	_ = c.Close()
	select {
	case b := <-got:
		if string(b) != "\x00\x09\x03\x00\x01abcd" {
			t.Fatalf("stream = %q", b)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("no read after close")
	}
}

func TestClientAddrBehindProxy(t *testing.T) {
	cases := []struct {
		remote, fwd, want string
	}{
		{"127.0.0.1:4000", "203.0.113.7", "203.0.113.7"},            // Caddy on the host
		{"172.17.0.1:4000", "10.0.0.9, 203.0.113.7", "203.0.113.7"}, // via Docker's bridge; the proxy's own entry is last
		{"203.0.113.50:4000", "1.2.3.4", "203.0.113.50"},            // from the internet: the header is ignored
		{"127.0.0.1:4000", "", "127.0.0.1"},                         // no proxy
		{"127.0.0.1:4000", "garbage", "127.0.0.1"},
	}
	for _, c := range cases {
		r := httptest.NewRequest("GET", "/ws", nil)
		r.RemoteAddr = c.remote
		if c.fwd != "" {
			r.Header.Set("X-Forwarded-For", c.fwd)
		}
		if got := clientAddr(r).IP.String(); got != c.want {
			t.Errorf("remote %s, X-Forwarded-For %q: got %s, want %s", c.remote, c.fwd, got, c.want)
		}
	}
}
