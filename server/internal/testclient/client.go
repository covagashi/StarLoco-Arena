// Package testclient is a scripted wire-protocol client used to drive the
// server through end-to-end flows in tests (no GUI). It speaks the same framing
// the real 2.70 client does: C2S frames carry a 5-byte header
// [u16 totalLen][u8 arch][u16 opcode][payload]; S2C frames are read as
// [u16 totalLen][u16 opcode][payload]. All fields big-endian.
package testclient

import (
	"bufio"
	"encoding/binary"
	"fmt"
	"io"
	"net"
	"time"

	"github.com/StarLoco/arena-2.70/internal/wsconn"
)

// Client is a single scripted connection to the server.
type Client struct {
	conn net.Conn
	r    *bufio.Reader
}

// Dial connects to addr.
func Dial(addr string) (*Client, error) {
	conn, err := net.DialTimeout("tcp", addr, 3*time.Second)
	if err != nil {
		return nil, err
	}
	return &Client{conn: conn, r: bufio.NewReader(conn)}, nil
}

// DialWS connects over WebSocket (S44, the browser client's transport):
// url is "ws://host:port/". The framing inside is the same.
func DialWS(url string) (*Client, error) {
	conn, err := wsconn.Dial(url, 3*time.Second)
	if err != nil {
		return nil, err
	}
	return &Client{conn: conn, r: bufio.NewReader(conn)}, nil
}

// Close closes the connection.
func (c *Client) Close() error { return c.conn.Close() }

// Frame is a decoded server-to-client message.
type Frame struct {
	Opcode  uint16
	Payload []byte
}

// Send writes a C2S frame with the given arch byte, opcode and payload.
func (c *Client) Send(arch byte, opcode uint16, payload []byte) error {
	total := 5 + len(payload)
	buf := make([]byte, total)
	binary.BigEndian.PutUint16(buf[0:2], uint16(total))
	buf[2] = arch
	binary.BigEndian.PutUint16(buf[3:5], opcode)
	copy(buf[5:], payload)
	_, err := c.conn.Write(buf)
	return err
}

// Recv reads the next S2C frame (with a read deadline).
func (c *Client) Recv(timeout time.Duration) (*Frame, error) {
	_ = c.conn.SetReadDeadline(time.Now().Add(timeout))
	var header [4]byte
	if _, err := io.ReadFull(c.r, header[:]); err != nil {
		return nil, err
	}
	total := binary.BigEndian.Uint16(header[0:2])
	opcode := binary.BigEndian.Uint16(header[2:4])
	if total < 4 {
		return nil, fmt.Errorf("testclient: short frame len=%d", total)
	}
	payload := make([]byte, int(total)-4)
	if _, err := io.ReadFull(c.r, payload); err != nil {
		return nil, err
	}
	return &Frame{Opcode: opcode, Payload: payload}, nil
}

// WaitFor reads frames until one with the given opcode arrives (or timeout),
// returning it. Intervening frames are collected and returned too.
func (c *Client) WaitFor(opcode uint16, timeout time.Duration) (*Frame, []*Frame, error) {
	deadline := time.Now().Add(timeout)
	var seen []*Frame
	for time.Now().Before(deadline) {
		f, err := c.Recv(time.Until(deadline))
		if err != nil {
			return nil, seen, err
		}
		if f.Opcode == opcode {
			return f, seen, nil
		}
		seen = append(seen, f)
	}
	return nil, seen, fmt.Errorf("testclient: timeout waiting for opcode %d (saw %d frames)", opcode, len(seen))
}

// DrainReceived reads whatever frames are immediately available (short timeout),
// used to flush the server's push burst after an action.
// DrainReceived reads frames until the connection goes quiet for `quiet`, or
// until an overall cap elapses.
//
// The cap is the important half and it was missing. Without it this loops for as
// long as the server keeps sending frames closer together than `quiet` - a fight
// broadcasting phase changes, or a handler answering a burst of requests - so a
// call meant to "drain for 250ms" can block forever. That is an unbounded wait on
// the test's main goroutine, and it showed up as TestPlacementRejectsIllegal-
// CellsAndPhases hanging for 8m55s on a Linux runner and taking the whole e2e
// package past its 10-minute timeout, intermittently and only under load.
//
// Draining is best-effort by nature - callers use it to discard traffic they do
// not care about - so hitting the cap returns what was read rather than failing.
func (c *Client) DrainReceived(quiet time.Duration) []*Frame {
	var frames []*Frame
	deadline := time.Now().Add(drainCap(quiet))
	for time.Now().Before(deadline) {
		f, err := c.Recv(quiet)
		if err != nil {
			return frames
		}
		frames = append(frames, f)
	}
	return frames
}

// drainCap bounds a drain at 20 quiet-periods, with a floor and ceiling so that
// both the 30ms polling drains and the 250ms gate drains stay sane.
func drainCap(quiet time.Duration) time.Duration {
	cap := quiet * 20
	if cap < time.Second {
		cap = time.Second
	}
	if cap > 5*time.Second {
		cap = 5 * time.Second
	}
	return cap
}
