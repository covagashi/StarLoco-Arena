package game

import (
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// Client-config opcodes are a Godot-client extension: the retail client never
// sends 60000, so the wire protocol the retail client sees stays untouched.
// The answer is a key/value map rather than a fixed layout so new runtime
// settings (feature flags, motd, announcement text) can ride the same frame
// without a new opcode.
//
// Wire (60001 S2C): [u8 n] then n × {[u8 keyLen][key][u16 valueLen][value]}.
// Keys today: "web_base_url" — the portal's public address, e.g.
// "https://arena.example.com", which the client's bug reporter POSTs to
// ("/{lang}/bug-report"). Absent when the portal is disabled.
func registerClientConfigHandlers(r *Router, d *Deps) {
	r.Register(protocol.OpClientConfigRequest, handleClientConfigRequest)
}

func handleClientConfigRequest(s *Session, _ *protocol.C2SFrame) error {
	w := protocol.NewWriter()
	keys := 0
	if s.deps.WebBaseURL != "" {
		keys++
	}
	w.U8(uint8(keys))
	if s.deps.WebBaseURL != "" {
		w.StringU8("web_base_url")
		w.StringU16(s.deps.WebBaseURL)
	}
	frame, err := protocol.EncodeS2C(protocol.OpClientConfig, w.Bytes())
	if err != nil {
		return err
	}
	return s.Send(frame)
}
