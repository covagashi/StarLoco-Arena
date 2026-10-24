package game

import (
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
