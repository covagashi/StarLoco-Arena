package game

import "github.com/StarLoco/arena-2.70/internal/protocol"

// Teleporting within a world.
//
// A teleport used to be expressed as a full instance re-enter
// (sendEnterOverworld). That works, but it is a large hammer: the client
// discards and must be re-sent its roster and team presets on every 4600
// (B-124), it re-pushes interactive elements the client already holds (B-137),
// and - because Registry.UpdatePosition only records coordinates - other
// players' area-of-interest sets were only corrected by the re-seed, never
// incrementally.
//
// 4510 is the frame retail uses for exactly this: move an actor with no walk
// animation, recentring the camera for the local player. Combined with
// ApplyMove - which is agnostic about HOW the coach got to the new cell and
// already computes the enter/leave diff - a same-world teleport becomes an
// ordinary AoI update.
//
// Cross-world teleports still go through sendEnterOverworld: a different island
// is a different map, and the client genuinely does need the instance change.

// buildActorTeleport builds ActorTeleports (4510):
// [i64 actorId][i32 x][i32 y][i16 z]. Exactly 18 bytes - the client validates
// the length and drops a short frame silently.
func buildActorTeleport(coachID uint, x, y int32, z int16) ([]byte, error) {
	w := protocol.NewWriter().
		I64(int64(coachID)).
		I32(x).
		I32(y).
		U16(uint16(z))
	return protocol.EncodeS2C(protocol.OpActorTeleports, w.Bytes())
}

// teleportWithinWorld moves the coach to (x,y,z) on the world it is already on,
// maintaining every observer's AoI and telling them with 4510.
//
// Returns false if the caller must fall back to a full instance enter - which is
// the honest answer whenever this cannot do the job correctly.
func (s *Session) teleportWithinWorld(x, y int32, z int16) bool {
	if s.Coach == nil || s.deps == nil || s.deps.World == nil {
		return false
	}
	// A teleport is a discontinuity: a coach dragged out from under a sitting
	// animation would arrive still seated.
	s.standIfSitting()

	d := s.deps.World.ApplyMove(s.Coach.ID, x, y, z)

	// ApplyMove only diffs the ACTOR AoI — interactive elements have their own
	// per-session registry, which handleCoachMove keeps in step. A teleport must
	// do the same or the coach lands somewhere its client never spawned the
	// elements of (zone triggers included).
	s.refreshWorldElements(s.currentWorld, x, y)

	// Coaches that entered view: spawn them to the mover.
	if len(d.SpawnToMover) > 0 {
		if frame, err := buildActorSpawn(d.SpawnToMover); err == nil {
			_ = s.Send(frame)
		}
	}
	// Coaches that left view: despawn from the mover.
	if len(d.DespawnToMover) > 0 {
		if frame, err := buildActorDespawn(d.DespawnToMover); err == nil {
			_ = s.Send(frame)
		}
	}
	// Sessions that just gained sight: spawn the mover BEFORE the teleport, so
	// the actor exists when the 4510 naming it arrives. Sending them a 4510 for
	// an actor they have not spawned is what NPEs a retail handler (B-136).
	if len(d.SpawnMoverTo) > 0 {
		if frame, err := buildActorSpawn([]CoachView{d.MoverView}); err == nil {
			for _, other := range d.SpawnMoverTo {
				_ = other.Send(frame)
			}
		}
	}
	tp, err := buildActorTeleport(s.Coach.ID, x, y, z)
	if err != nil {
		return false
	}
	// Everyone who can already see the coach, plus the coach itself - the client
	// recentres its own camera from this frame.
	for _, other := range d.MoveViewers {
		_ = other.Send(tp)
	}
	_ = s.Send(tp)

	// Sessions that lost sight: despawn the mover from them.
	if len(d.DespawnMoverFrom) > 0 {
		if frame, err := buildActorDespawn([]uint{s.Coach.ID}); err == nil {
			for _, other := range d.DespawnMoverFrom {
				_ = other.Send(frame)
			}
		}
	}
	return true
}
