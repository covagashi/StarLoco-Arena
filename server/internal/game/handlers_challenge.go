package game

import "github.com/StarLoco/arena-2.70/internal/protocol"

// handlers_challenge.go implements the direct-challenge ("Proposer un
// entraînement" / training fight) handshake: coach A directly challenges coach B.
//
//	A → 26301 CHALLENGE [i64 targetCoachId][i8 evo]
//	server → 26300 INVITATION to B ("A invites you", incoming) and to A
//	         ("waiting for B", outgoing), both carrying the challenger's id as the
//	         handle plus the other coach's name.
//	B → 26305 ACCEPT  → server → 26302 ACCEPTED to both (both open the team panel)
//	  or 26307 DECLINE → server → 26304 CANCELLED to A
//	  (A can also 26307 to cancel its own outgoing invite → 26304 to B)
//	both → 26303 team confirm (handleFightReadyConfirm) → once both confirm, the
//	       fight starts via the normal startFightWithTeams path.
//
// Only the 1v1 training path is implemented; the evolution flag is carried
// through verbatim, and the X-vs-X-with-allies variant (26313/26314) is not.

func registerChallengeHandlers(r *Router, _ *Deps) {
	r.Register(protocol.OpChallengeInvite, handleChallengeInvite)
	r.Register(protocol.OpChallengeAccept, handleChallengeAccept)
	r.Register(protocol.OpChallengeDecline, handleChallengeDecline)
}

// handleChallengeInvite (26301) starts a direct challenge from the caller to the
// target coach. It is a silent no-op if the target is offline, is the caller
// itself, or either coach is already in a fight or another challenge.
func handleChallengeInvite(s *Session, f *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	r := protocol.NewReader(f.Payload)
	targetID, err := r.I64()
	if err != nil {
		return err
	}
	evo, _ := r.U8()
	tid := uint(targetID)
	if tid == s.Coach.ID {
		return nil // no self-challenge
	}
	if s.deps.busyForChallenge(s.Coach.ID) || s.deps.busyForChallenge(tid) {
		return nil
	}
	target := s.deps.World.Get(tid)
	if target == nil || target.Session == nil {
		return nil // target offline
	}
	c := s.deps.Challenges.Create(s, target.Session, evo != 0)
	if c == nil {
		return nil
	}
	// The target sees an incoming invite (name = challenger); the challenger sees
	// the outgoing "waiting" echo (name = target).
	if in, err := buildChallengeInvitation(c.id, false, c.evolution, s.Coach.Name); err == nil {
		_ = target.Session.Send(in)
	}
	if out, err := buildChallengeInvitation(c.id, true, c.evolution, target.Coach.Name); err == nil {
		_ = s.Send(out)
	}
	s.log.Info("challenge sent", "from", s.Coach.Name, "to", target.Coach.Name)
	return nil
}

// handleChallengeAccept (26305) is the target accepting. Both coaches then get
// ACCEPTED (26302) and open the team-management panel.
func handleChallengeAccept(s *Session, _ *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	c := s.deps.Challenges.Accept(s.Coach.ID)
	if c == nil {
		return nil // not the target of a pending challenge
	}
	frame, err := buildChallengeAccepted(c.id, c.evolution)
	if err != nil {
		return err
	}
	_ = c.challenger.Send(frame)
	_ = c.target.Send(frame)
	s.log.Info("challenge accepted", "coach", s.Coach.Name)
	return nil
}

// handleChallengeDecline (26307) is the target declining OR the challenger
// cancelling. The other side is told the challenge was cancelled (26304).
func handleChallengeDecline(s *Session, _ *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	c := s.deps.Challenges.Remove(s.Coach.ID)
	if c == nil {
		return nil
	}
	if other := c.other(s.Coach.ID); other != nil {
		if frame, err := buildChallengeCancelled(c.id); err == nil {
			_ = other.Send(frame)
		}
	}
	return nil
}

// startChallengeFight builds both coaches' confirmed teams and starts the fight
// via the same path a matchmade fight uses (non-practice, ranked).
func (d *Deps) startChallengeFight(c *challenge) error {
	rosterA := d.resolveTeamRoster(c.challenger.Coach.ID, uint(c.teamChallenger))
	rosterB := d.resolveTeamRoster(c.target.Coach.ID, uint(c.teamTarget))
	fightArena := pickArena()
	teamA, err := d.buildFightTeamFor(c.challenger, 0, fightArena.startCells(0), rosterA)
	if err != nil {
		return refuseFightError(err, c.challenger, c.target)
	}
	teamB, err := d.buildFightTeamFor(c.target, 1, fightArena.startCells(1), rosterB)
	if err != nil {
		return refuseFightError(err, c.challenger, c.target)
	}
	return d.startFightWithTeams(fightArena, teamA, teamB, false, 0, c.evolution)
}

// busyForChallenge reports whether a coach can't take part in a new challenge
// (already fighting or already in a challenge).
func (d *Deps) busyForChallenge(coachID uint) bool {
	return d.Fights.ByCoach(coachID) != nil || d.Challenges.Get(coachID) != nil
}

// --- wire builders ---

// buildChallengeInvitation builds INVITATION (26300):
// [i64 handle][i8 outgoing][i8 evolution][i8 nNames=1][i32 nameLen][name].
func buildChallengeInvitation(handle int64, outgoing, evolution bool, name string) ([]byte, error) {
	w := protocol.NewWriter().I64(handle).U8(boolU8(outgoing)).U8(boolU8(evolution)).U8(1)
	writeStringI32(w, name)
	return protocol.EncodeS2C(protocol.OpChallengeInvitation, w.Bytes())
}

// buildChallengeAccepted builds ACCEPTED (26302): [i64 handle][i8 evolution].
func buildChallengeAccepted(handle int64, evolution bool) ([]byte, error) {
	w := protocol.NewWriter().I64(handle).U8(boolU8(evolution))
	return protocol.EncodeS2C(protocol.OpChallengeAccepted, w.Bytes())
}

// buildChallengeCancelled builds CANCELLED (26304): [i64 handle].
func buildChallengeCancelled(handle int64) ([]byte, error) {
	w := protocol.NewWriter().I64(handle)
	return protocol.EncodeS2C(protocol.OpChallengeCancelled, w.Bytes())
}

func boolU8(b bool) uint8 {
	if b {
		return 1
	}
	return 0
}
