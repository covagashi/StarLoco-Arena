package game

import (
	"github.com/StarLoco/arena-2.70/internal/handshake"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// handlers_reconnect.go implements mid-fight RESUME. When a coach who dropped its
// connection during a fight reconnects, the fight is still alive (kept by the
// B-034 disconnect grace with the team flagged Absent + detached). enterWorld
// pushes the reconnect QUESTION (26333) while the coach is in the lobby; the
// client shows a Yes/No dialog and answers with 26334. This file handles the
// answer: accept re-attaches the session to its team and replays the fight so the
// client rebuilds it; decline (or an unanswered grace timeout) forfeits.

func registerReconnectHandlers(r *Router, _ *Deps) {
	r.Register(protocol.OpReconnectFightAnswer, handleReconnectFightAnswer)
}

// buildReconnectFightQuestion builds the empty RECONNECT_FIGHT_QUESTION (26333),
// the server push that makes the lobby client ask "resume your fight?".
func buildReconnectFightQuestion() ([]byte, error) {
	return protocol.EncodeS2C(protocol.OpReconnectFightQuestion, nil)
}

// handleReconnectFightAnswer processes the client's reply to 26333: a single byte,
// 1 = resume, 0 = decline. It runs on the fight actor so all fight-state access is
// serialized. Resume re-attaches this session to its (Absent) team, cancels the
// grace timer, removes the coach from the overworld again, and replays the fight
// presentation to the returning client. Decline forfeits the fight.
func handleReconnectFightAnswer(s *Session, frame *protocol.C2SFrame) error {
	if s.Coach == nil {
		return nil
	}
	accept := len(frame.Payload) > 0 && frame.Payload[0] != 0
	f := s.deps.Fights.ByCoach(s.Coach.ID)
	if f == nil {
		return nil // fight already gone (grace expired / opponent already won)
	}
	cid := s.Coach.ID
	deps := s.deps
	sess := s
	f.Post(func(f *Fight) {
		m := f.memberOfCoach(cid)
		if m == nil || !m.Absent {
			return // not resumable (already re-attached, or never absent)
		}
		if !accept {
			deps.forfeitCoach(f, cid)
			return
		}
		// Re-attach the returning coach to its side and cancel the reconnect grace.
		m.Session = sess
		m.Absent = false
		f.stopGrace()
		// Remove the coach from the overworld again (enterWorld re-added it on
		// reconnect) and despawn it from anyone who saw it in the lobby.
		if viewers := deps.World.SetInFight(cid, true); len(viewers) > 0 {
			if dsp, err := buildActorDespawn([]uint{cid}); err == nil {
				for _, v := range viewers {
					_ = v.Send(dsp)
				}
			}
		}
		deps.sendFightResync(sess, f, false)
		deps.Log.Info("coach resumed fight", "id", f.ID, "coach", cid)
	})
	return nil
}

// sendFightResync replays the fight-presentation sequence to a single session so
// its client (re)builds the ongoing fight from scratch — used both to RESUME a
// reconnecting coach and to attach a SPECTATOR. It mirrors the fresh-start order
// in startFightWithTeams, but sources CURRENT state: the CREATE_FIGHT fighter
// blobs carry live HP/AP/MP deltas (writeCombatFighterBlob), ACTOR_APPEAR uses
// current cells, dead fighters are re-marked dead, and the phase cues fast-forward
// the client's fight state machine to the live phase + turn. A spectator gets the
// blob with the spectator flag set and an empty action deck (it cannot act). Must
// run on the fight actor. Live buffs come back through 8121 (resyncBuffs),
// since CREATE_FIGHT has no slot for them.
func (d *Deps) sendFightResync(sess *Session, f *Fight, spectator bool) {
	if sess == nil || sess.Coach == nil {
		return
	}
	// 1. Stream the arena world (dynamic instance) — camera on the battlefield
	// centre — so the client switches from the lobby to the fight layer.
	if enter, err := handshake.EncodeEnterInstance(
		float32(f.Arena().centerX), float32(f.Arena().centerY), 0,
		int16(f.Arena().worldID), true); err == nil {
		_ = sess.Send(enter)
	}
	// 2. The full snapshot with live HP/AP/MP + the current timeline. A resuming
	// coach embeds its own action deck; a spectator gets an empty deck + the
	// spectator flag (it is a read-only viewer).
	deckCoach := sess.Coach
	if spectator {
		deckCoach = nil
	}
	if create, err := buildCreateFight(f, deckCoach, spectator); err == nil {
		_ = sess.Send(create)
	}
	// 3. Insert + show every actor at its CURRENT cell.
	if appear, err := buildActorAppearForFight(f); err == nil {
		_ = sess.Send(appear)
	}
	// 4. Re-mark the fallen: replay FIGHTER_DIES for every dead fighter so the
	// client greys them (CREATE_FIGHT re-created them at full presence).
	for _, ff := range f.allFighters() {
		if ff.HP <= 0 {
			if dies, err := buildFighterDies(f.nextActionUID(), ff.WireID); err == nil {
				_ = sess.Send(dies)
			}
		}
	}
	// 4b. Re-attach every live buff so its icon comes back. CREATE_FIGHT carries
	// the persistent conditions (type 902) but has no slot for timed spell buffs,
	// so without this a reconnecting player - or a joining spectator - sees a
	// fighter with none of the buffs it is actually carrying.
	d.resyncBuffs(sess, f)

	// 5. Drive the client's fight state machine to the live phase, replaying the
	// exact cue chain the advanceTo* transitions emit.
	phase := f.Phase()
	cue := func(op uint16) {
		if fr, err := buildEmpty(op); err == nil {
			_ = sess.Send(fr)
		}
	}
	cue(protocol.OpStartPresentation)
	if phase >= PhasePlacement {
		cue(protocol.OpEndPresentation)
		cue(protocol.OpStartPlacement)
	}
	if phase >= PhaseObservation {
		cue(protocol.OpEndPlacement)
		cue(protocol.OpStartObservation)
	}
	if phase >= PhaseAction {
		cue(protocol.OpEndObservation)
		cue(protocol.OpStartAction)
		// 6. Current table turn + active fighter, so the timeline highlight (and,
		// if it's the resumer's turn, the action buttons) come back. This does NOT
		// refill the active fighter (it is mid-turn) — it only tells the client
		// whose turn it is.
		// It carries the round's CURRENT event card (not a fresh draw), so the
		// resumed client redisplays the card already in play without the server
		// re-applying its effects.
		if table, err := buildNewTableTurn(f.nextActionUID(), uint8(f.tableTurn), f.tableEvent); err == nil {
			_ = sess.Send(table)
		}
		if cur := f.currentFighter(); cur != nil {
			if turn, err := buildFighterTurnBegin(f.nextActionUID(), cur.WireID); err == nil {
				_ = sess.Send(turn)
			}
		}
	}
}
