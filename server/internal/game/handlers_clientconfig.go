package game

import (
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"strconv"
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
// "offline_tournaments" = "1" when classic tournaments play themselves
// (S29); absent otherwise. "fighter_slots" = how many fighters the coach may
// own (S50: 8, up to 10 earned).
func registerClientConfigHandlers(r *Router, d *Deps) {
	r.Register(protocol.OpClientConfigRequest, handleClientConfigRequest)
}

func handleClientConfigRequest(s *Session, _ *protocol.C2SFrame) error {
	s.godot.Store(true)
	if err := s.sendClientConfig(); err != nil {
		return err
	}
	if err := s.sendCosmetics(nil); err != nil { // S37: the coach's cosmetics ride along
		return err
	}
	// S40: the card picks and the league ride along too.
	if err := s.sendCardPicks(); err != nil {
		return err
	}
	return s.sendLeague()
}

// sendClientConfig is 60001, the key/value map above. Sent again when a value
// changes during the session (S50: a fighter slot earned).
func (s *Session) sendClientConfig() error {
	type kv struct{ k, v string }
	var pairs []kv
	if s.deps.WebBaseURL != "" {
		pairs = append(pairs, kv{"web_base_url", s.deps.WebBaseURL})
	}
	if s.deps.OfflineTournaments {
		pairs = append(pairs, kv{"offline_tournaments", "1"})
	}
	if s.Coach != nil {
		s.Coach.Mu.Lock()
		slots := fighterSlots(s.Coach)
		s.Coach.Mu.Unlock()
		pairs = append(pairs, kv{"fighter_slots", strconv.Itoa(slots)})
	}
	if s.Account != nil {
		// S51: a demo account offers «Guardar mi progreso».
		demo := "0"
		if s.Account.IsDemo {
			demo = "1"
		}
		pairs = append(pairs, kv{"account_demo", demo})
	}
	w := protocol.NewWriter()
	w.U8(uint8(len(pairs)))
	for _, p := range pairs {
		w.StringU8(p.k)
		w.StringU16(p.v)
	}
	frame, err := protocol.EncodeS2C(protocol.OpClientConfig, w.Bytes())
	if err != nil {
		return err
	}
	return s.Send(frame)
}
