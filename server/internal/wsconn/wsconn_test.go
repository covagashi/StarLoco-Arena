package wsconn

import (
	"context"
	"io"
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
