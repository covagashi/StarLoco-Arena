package game

import (
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

func registerElementHandlers(r *Router, d *Deps) {
	r.Register(protocol.OpInteractiveElementAction, handleInteractiveElementAction)
	r.Register(protocol.OpFireworkLaunch, handleFireworkLaunch)
}

// handleFireworkLaunch handles FIREWORK_LAUNCH (opcode 22095, client axf_0):
// [i32 cardId][i32 x][i32 y][i64 elementId]. The client fires this when a firework
// card is launched from a "cardUsingSwitch" element; the visual only plays once
// the server echoes FIREWORK_SHOW (22094), which also lets nearby coaches see it.
func handleFireworkLaunch(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	cardID, err := r.I32()
	if err != nil {
		return err
	}
	x, err := r.I32()
	if err != nil {
		return err
	}
	y, err := r.I32()
	if err != nil {
		return err
	}
	elementID, err := r.I64()
	if err != nil {
		return err
	}

	// 22094 carries an extra z the launch request doesn't; the client positions the
	// particle relative to the element, so 0 is correct.
	w := protocol.NewWriter().I32(cardID).I32(x).I32(y).I32(0).I64(elementID)
	frame, err := protocol.EncodeS2C(protocol.OpFireworkShow, w.Bytes())
	if err != nil {
		return err
	}
	if err := s.Send(frame); err != nil {
		return err
	}
	for _, other := range s.deps.World.SessionsNear(s.Coach.PosX, s.Coach.PosY, s.Coach.ID) {
		_ = other.Send(frame)
	}
	s.log.Debug("firework", "coach", s.Coach.Name, "card", cardID, "element", elementID)
	return nil
}

// handleInteractiveElementAction handles INTERACTIVE_ELEMENT_ACTION (opcode 201,
// client bd_2): [i64 elementInstanceId][i16 actionOrdinal]. EVERY interactive
// element emits this when clicked; what the server owes in response depends on the
// element's kind (see elements.go):
//
//   - Card Master: opens NO UI on its own — it arms its handler and waits for the
//     server to push the catalogue (5401), which is what opens AND populates the
//     shop. This is the only in-world way to open it (opcode 5300 is the client's
//     debug-console opener, not a shop request).
//   - Zaap / Fusion altar / mailbox / graveyard: open their dialog locally from
//     client-side data; the server owes nothing here. Their follow-up actions
//     arrive as their own opcodes (Zaap -> 4512, fusion -> 5490). A fusion
//     altar's 201 is remembered, because the 5490 does not say which altar.
//
// The element is looked up in the coach's world first, then in any world: the
// Godot client's lobby lists every island's services (instance ids are unique
// across worlds, so the id is enough).
func handleInteractiveElementAction(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	instanceID, err := r.I64()
	if err != nil {
		return err
	}
	action, _ := r.U16()

	el, ok := elementAt(s.currentWorld, instanceID)
	if !ok {
		// The Godot lobby reaches every island's services without travelling.
		el, ok = elementAnywhere(instanceID)
	}
	if !ok {
		s.log.Debug("element action: unknown element",
			"element", instanceID, "world", s.currentWorld, "action", action)
		return nil
	}
	s.log.Debug("element action", "element", instanceID, "kind", el.kind.String(),
		"action", action, "coach", s.Coach.Name)

	if el.kind == kindFusionLab {
		// Remember which altar was opened: the 5490 that follows names none.
		s.fusionLabID = el.arg
		return nil
	}
	if el.kind == kindCardMaster {
		// el.arg is the Card Master's catalogue id (descriptor "cardListId"). The
		// client treats the shopId as opaque and echoes it back on every purchase
		// (5400/5450), so stamping the real id keeps those requests attributable to
		// this Card Master.
		frame, err := buildShopCatalog(s.deps.Cards, el.arg, el.mode)
		if err != nil {
			return err
		}
		return s.Send(frame)
	}
	return nil
}
