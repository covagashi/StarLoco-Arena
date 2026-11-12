package game

import (
	"fmt"
	"strconv"

	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// Cosmetics (S37): looks a coach owns and shows, never power. Today the hair
// effects only — an effect from the client's effect library on the coach's
// hair (the hair styles themselves are fixed since S35c; only the colour
// changes). The S30 shop is meant to sell them for pesetas; until it exists a
// GM grants them with /COSMETIC.
//
// The ids are the wire and the database values; the client draws each one
// (Fighter3D.HAIR_FX) and names it (ui_*.json "hairfx.<id>").
const (
	CosmeticHairFire  int32 = 1 // flames licking up from the hair
	CosmeticHairFrost int32 = 2 // a cold glow, flakes drifting off
	CosmeticHairStorm int32 = 3 // sparks crackling round it
	CosmeticHairGold  int32 = 4 // a golden shimmer
)

// isHairFx reports whether id is a hair effect.
func isHairFx(id int32) bool { return id >= CosmeticHairFire && id <= CosmeticHairGold }

func registerCosmeticHandlers(r *Router, _ *Deps) {
	r.Register(protocol.OpCosmeticEquip, handleCosmeticEquip)
}

// handleCosmeticEquip (60042) puts on a hair effect the coach owns, or takes
// it off with 0, then answers 60043. One it doesn't own is refused silently
// (the client only offers owned ones); the answer still goes, so the panel
// shows the truth.
func handleCosmeticEquip(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil || s.deps.Store == nil {
		return nil
	}
	id, err := protocol.NewReader(f.Payload).I32()
	if err != nil {
		return nil
	}
	owned, err := s.deps.Store.Coaches.Cosmetics(s.Coach.ID)
	if err != nil {
		return err
	}
	ok := id == 0
	for _, o := range owned {
		if o == id && isHairFx(id) {
			ok = true
		}
	}
	if ok {
		if err := s.deps.Store.Coaches.SetHairFx(s.Coach.ID, id); err != nil {
			return err
		}
		s.Coach.Mu.Lock()
		s.Coach.HairFx = id
		s.Coach.Mu.Unlock()
	}
	return s.sendCosmetics(owned)
}

// sendCosmetics sends 60043 to a Godot session: the hair effect it shows and
// every cosmetic it owns (nil = read them).
func (s *Session) sendCosmetics(owned []int32) error {
	if s.Coach == nil || s.deps.Store == nil || !s.godot.Load() {
		return nil
	}
	if owned == nil {
		var err error
		if owned, err = s.deps.Store.Coaches.Cosmetics(s.Coach.ID); err != nil {
			return err
		}
	}
	if len(owned) > 255 {
		owned = owned[:255]
	}
	s.Coach.Mu.Lock()
	fx := s.Coach.HairFx
	s.Coach.Mu.Unlock()
	w := protocol.NewWriter().I32(fx).U8(uint8(len(owned)))
	for _, id := range owned {
		w.I32(id)
	}
	frame, err := protocol.EncodeS2C(protocol.OpCosmetics, w.Bytes())
	if err != nil {
		return err
	}
	return s.Send(frame)
}

// gmCosmetic is /COSMETIC <coach> <id>: grants a cosmetic (the S30 shop's job
// later) and refreshes that coach's panel if it is online.
func (s *Session) gmCosmetic(args []string) error {
	if len(args) < 2 {
		return s.gmFeedback("usage: /COSMETIC <coach> <id 1-4: hair fire, frost, storm, gold>")
	}
	target, err := s.deps.Store.Coaches.GetByName(args[0])
	if err != nil || target == nil {
		return s.gmFeedback("no such coach")
	}
	id, err := strconv.Atoi(args[1])
	if err != nil || !isHairFx(int32(id)) {
		return s.gmFeedback("no such cosmetic")
	}
	if err := s.deps.Store.Coaches.GrantCosmetic(target.ID, int32(id)); err != nil {
		return s.gmFeedback("grant failed: " + err.Error())
	}
	if t := s.deps.sessionForCoach(target.ID); t != nil {
		_ = t.sendCosmetics(nil)
	}
	s.log.Info("GM gave cosmetic", "by", s.Coach.Name, "to", target.Name, "cosmetic", id)
	return s.gmFeedback(fmt.Sprintf("gave cosmetic %d to %s", id, target.Name))
}
