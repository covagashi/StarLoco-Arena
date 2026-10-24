package game

import (
	"sort"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// Historia (S21, owner 2026-10-24: "evolución: este es el modo historia").
// The campaign is the PvE challenges the lobby already offers, in their
// story order. The FIRST win of each counts like an evolution fight (XP,
// fatigue, morale, wounds, death: Fight.Story); after that it is practice,
// so an easy early chapter cannot be farmed for XP.
//
// The chapter layout the player sees lives in the Godot client
// (godot/src/gamedata/story.gd); TestStoryChallengesMatchClient keeps the
// two lists equal.
var storyChapters = [][]int32{
	{46, 29, 30, 31},     // Aprendizaje: Nilo's lesson, the Demon III's three
	{34, 35, 36, 32, 33}, // the minute demons, 58 → 12
	{45, 3, 13, 16, 14},  // Bernabé, the Hell's Tofus, the Demon III's tricks
}

func isStoryChallenge(id int32) bool {
	for _, ch := range storyChapters {
		for _, c := range ch {
			if c == id {
				return true
			}
		}
	}
	return false
}

func registerStoryHandlers(r *Router, d *Deps) {
	r.Register(protocol.OpStoryRequest, handleStoryRequest)
	r.Register(protocol.OpFighterEquipRequest, handleFighterEquipRequest)
}

// handleFighterEquipRequest (60022 → 60023, S22) lists the fighter cards one
// of the caller's fighters may wear: everything for an Elite fighter (only
// the budget limits it), what its bought spheres unlocked for a Historia one
// — the same rule entitledEquip enforces on save, so the Godot editor offers
// exactly what will stick.
func handleFighterEquipRequest(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil || s.deps.Store == nil || s.deps.FighterCards == nil {
		return nil
	}
	fid, err := protocol.NewReader(f.Payload).I64()
	if err != nil {
		return err
	}
	fr, err := s.deps.Store.Fighters.Get(uint(fid))
	if err != nil || fr == nil || fr.CoachID != s.Coach.ID {
		return nil
	}
	ids := s.deps.wearableCards(fr)
	w := protocol.NewWriter().I64(fid).U16(uint16(len(ids)))
	for _, id := range ids {
		w.I32(id)
	}
	frame, err := protocol.EncodeS2C(protocol.OpFighterEquip, w.Bytes())
	if err != nil {
		return err
	}
	return s.Send(frame)
}

// handleStoryRequest (60020) answers 60021 with the campaign challenges this
// coach has won: [u16 n]{[i32 challengeId]}. The "won" flags are the
// server's own bookkeeping (statChallengeDoneBase + id), which the login
// criteria blob deliberately does not carry.
func handleStoryRequest(s *Session, _ *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	var won []int32
	if s.deps.Store != nil {
		for _, ch := range storyChapters {
			for _, id := range ch {
				if s.deps.challengeAlreadyDone(s.Coach.ID, id) {
					won = append(won, id)
				}
			}
		}
	}
	w := protocol.NewWriter().U16(uint16(len(won)))
	for _, id := range won {
		w.I32(id)
	}
	frame, err := protocol.EncodeS2C(protocol.OpStory, w.Bytes())
	if err != nil {
		return err
	}
	return s.Send(frame)
}


// wearableCards is entitledEquip's rule as a list: every fighter card for an
// Elite fighter, the sphere-unlocked pools for a Historia one.
func (d *Deps) wearableCards(fr *domain.Fighter) []int32 {
	if d.FighterCards == nil || fr == nil {
		return nil
	}
	var unlocked []int32
	limited := fr.IsEvolution() && d.EquipmentPools != nil && d.SphereBoards != nil
	if limited {
		unlocked = sphereEquipmentPools(fr, d.SphereBoards)
	}
	ids := make([]int32, 0, len(d.FighterCards.All()))
	for id := range d.FighterCards.All() {
		if limited && !d.EquipmentPools.Grants(unlocked, id) {
			continue
		}
		ids = append(ids, id)
	}
	sort.Slice(ids, func(i, j int) bool { return ids[i] < ids[j] })
	return ids
}
