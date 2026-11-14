// Package wsconn carries the game protocol over WebSocket (S44: the browser
// client cannot open a TCP socket). It is only a transport: each binary
// WebSocket message holds a run of the same bytes the TCP connection would
// carry, so a *websocket.Conn wrapped here is an ordinary net.Conn and the
// game server's Serve, its per-IP guard and its sessions stay as they are.
//
// Listen serves an HTTP endpoint that upgrades every request to WebSocket and
// hands the connections out through Accept; Dial is the client side, for the
// e2e tests.
package wsconn

import (
	"context"
	"errors"
	"io"
	"net"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

// MaxMessage caps one inbound WebSocket message. A game frame is at most
// 64 KiB (its u16 length); a client never needs more in one message.
const MaxMessage = 64 << 10

var upgrader = websocket.Upgrader{
	ReadBufferSize:  4096,
	WriteBufferSize: 4096,
	// The demo is served from its own page (itch.io or a domain of ours), so
	// the Origin is another site's. The game protocol authenticates itself
	// (login, then the session) and no cookie rides on the socket, so any
	// origin may open one.
	CheckOrigin: func(*http.Request) bool { return true },
}

// Conn is a WebSocket as a byte stream.
type Conn struct {
	ws     *websocket.Conn
	remote net.Addr
	r      io.Reader // the message being read, nil between messages
	wmu    sync.Mutex
}

// New wraps ws; remote overrides the address the stream reports (the
// client's, from the HTTP request) when not nil.
func New(ws *websocket.Conn, remote net.Addr) *Conn {
	if remote == nil {
		remote = ws.RemoteAddr()
	}
	ws.SetReadLimit(MaxMessage)
	return &Conn{ws: ws, remote: remote}
}

// Read fills p from the current binary message, moving to the next one when
// it runs out. Text messages are refused: the protocol is binary.
func (c *Conn) Read(p []byte) (int, error) {
	for {
		if c.r == nil {
			kind, r, err := c.ws.NextReader()
			if err != nil {
				return 0, mapErr(err)
			}
			if kind != websocket.BinaryMessage {
				return 0, errors.New("wsconn: text message on a binary protocol")
			}
			c.r = r
		}
		n, err := c.r.Read(p)
		if errors.Is(err, io.EOF) {
			c.r = nil
			if n > 0 {
				return n, nil
			}
			continue
		}
		return n, err
	}
}

// Write sends p as one binary message.
func (c *Conn) Write(p []byte) (int, error) {
	c.wmu.Lock()
	defer c.wmu.Unlock()
	if err := c.ws.WriteMessage(websocket.BinaryMessage, p); err != nil {
		return 0, mapErr(err)
	}
	return len(p), nil
}

// Close sends a close frame (best effort) and closes the socket.
func (c *Conn) Close() error {
	c.wmu.Lock()
	_ = c.ws.WriteControl(websocket.CloseMessage,
		websocket.FormatCloseMessage(websocket.CloseNormalClosure, ""), time.Now().Add(time.Second))
	c.wmu.Unlock()
	return c.ws.Close()
}

func (c *Conn) LocalAddr() net.Addr  { return c.ws.LocalAddr() }
func (c *Conn) RemoteAddr() net.Addr { return c.remote }

func (c *Conn) SetDeadline(t time.Time) error {
	if err := c.ws.SetReadDeadline(t); err != nil {
		return err
	}
	return c.ws.SetWriteDeadline(t)
}
func (c *Conn) SetReadDeadline(t time.Time) error  { return c.ws.SetReadDeadline(t) }
func (c *Conn) SetWriteDeadline(t time.Time) error { return c.ws.SetWriteDeadline(t) }

// mapErr turns a close into io.EOF, which is how the session's read loop
// expects a peer that went away — a browser tab closing, or a client
// quitting without a close frame (1006), is as ordinary as a TCP FIN.
func mapErr(err error) error {
	if websocket.IsCloseError(err, websocket.CloseNormalClosure, websocket.CloseGoingAway,
		websocket.CloseNoStatusReceived, websocket.CloseAbnormalClosure) {
		return io.EOF
	}
	return err
}

// Listener accepts WebSocket connections on an HTTP port.
type Listener struct {
	ln     net.Listener
	srv    *http.Server
	conns  chan net.Conn
	done   chan struct{}
	closed sync.Once
}

// Listen binds addr and serves WebSocket upgrades on every path. Behind a
// TLS proxy (wss:// on oracle-2) the proxy terminates TLS and forwards here.
func Listen(ctx context.Context, addr string) (*Listener, error) {
	var lc net.ListenConfig
	ln, err := lc.Listen(ctx, "tcp", addr)
	if err != nil {
		return nil, err
	}
	l := &Listener{ln: ln, conns: make(chan net.Conn), done: make(chan struct{})}
	l.srv = &http.Server{Handler: http.HandlerFunc(l.upgrade), ReadHeaderTimeout: 10 * time.Second}
	go func() { _ = l.srv.Serve(ln) }()
	return l, nil
}

func (l *Listener) upgrade(w http.ResponseWriter, r *http.Request) {
	ws, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		return // Upgrade already answered with the HTTP error
	}
	remote, _ := net.ResolveTCPAddr("tcp", r.RemoteAddr)
	var addr net.Addr = remote
	if remote == nil {
		addr = ws.RemoteAddr()
	}
	c := New(ws, addr)
	select {
	case l.conns <- c:
	case <-l.done:
		_ = c.Close()
	}
}

// Accept waits for the next upgraded connection.
func (l *Listener) Accept() (net.Conn, error) {
	select {
	case c := <-l.conns:
		return c, nil
	case <-l.done:
		return nil, net.ErrClosed
	}
}

// Close stops the HTTP server; open game connections are the server's.
func (l *Listener) Close() error {
	var err error
	l.closed.Do(func() {
		close(l.done)
		err = l.srv.Close()
	})
	return err
}

// Addr is the bound address.
func (l *Listener) Addr() net.Addr { return l.ln.Addr() }

// Dial opens a WebSocket to url ("ws://host:port/") as a net.Conn.
func Dial(url string, timeout time.Duration) (net.Conn, error) {
	d := websocket.Dialer{HandshakeTimeout: timeout}
	ws, _, err := d.Dial(url, nil)
	if err != nil {
		return nil, err
	}
	return New(ws, nil), nil
}
