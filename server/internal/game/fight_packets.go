package game

import (
	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// buildCreateFight serializes CREATE_FIGHT (8000) per the 2.70 aat_2.ac layout.
//
// Layout (big-endian):
//
//	[i8 error=0]
//	[i16 coachCardBlobLen=0]
//	[i32 kind][i64 challengeId][i8 unread][i64 turnClockMs][i32 instanceId]
//	[i8 coachCount] { coach block (flag 34) + [i16 statsLen][stats] }
//	[i8 teamCount]  { team header + [i8 fighterCount]{[i8 kind]<fighter blob>[i64 ownerCoachId]} }
//	[i8 timelineCount]{i64 wireId}
//	[i8 eventCount]{i32 refId}
//	[i8 specialCellCount]{...}
//	[i16 fightModeShort]
//	[i32 statsFlag=0]
//	[i8 spectatorFlag=0]
//	[grid tail -- see gV().f, sent empty]
//
// deckCoach is the RECIPIENT coach: its equipped action-card deck is embedded in
// the coach-card blob so its "Cartes d'action" render + are castable in the fight
// (the client copies this blob to both coaches via aoe_2, so it must be built per
// recipient — see startFightWithTeams). nil deckCoach => empty deck.
func buildCreateFight(f *Fight, deckCoach *domain.Coach, spectator bool) ([]byte, error) {
	w := protocol.NewWriter()
	// The leading error byte IS required: the client decodes 8000 in two stages
	// -- aat_2.a(byte[]) reads [i8 error] and stashes the rest, then do_2 calls
	// aat_2.ac(rest) to parse the body. Do NOT remove this byte (verified by
	// tracing the dispatcher, July 2026).
	w.U8(0) // error = OK
	writeCoachActionDeck(w, f, deckCoach)

	// The fight KIND goes in the i32, not the i8. aat_2.ac reads
	//   [i32]->mv_1.cAq  [i64]->adu_0.cmF  [i8]->mv_1.byp  [i64]->mv_1.byv  [i32]->axw.aW
	// and every decision the client makes about what sort of fight this is reads
	// the FIRST one, through aKl(): `aKl() == 5` opens the challenge reward/XP
	// panel (WE case 8300), `aKl() == 6` selects the evolution result dialog and
	// also changes how the coach block is read during setup (aat_2 lines 194/214
	// take the evolution level instead of the strength), and `aKl() == 3` is the
	// tournament path. The i8 (byp/ZC()) has NO reader anywhere in the client.
	//
	// This used to write the kind into that unread i8 and leave the i32 at a
	// constant 1, so no challenge or evolution fight ever identified itself —
	// see BUGS.md B-095.
	w.I32(f.wireKind())

	// The challenge id the client resolves metadata with: ahy_1.axg().dC(asy()).
	// asy() is the FIRST i64; a wrong slot here just yields nil and silently
	// skips the panel.
	if f.ChallengeID != 0 && !f.Evolution {
		w.I64(int64(f.ChallengeID))
	} else {
		w.I64(0)
	}

	w.U8(0) // byp / ZC(): never read by the client

	// mv_1.byv, the client's turn-display budget in milliseconds. It is used as
	// Math.max(31000, byv), so anything at or below 31s is floored there; it is
	// sent honestly rather than zeroed so a ruleset that lengthens turns is
	// reflected in the client's own countdown.
	w.I64(f.turnClockFor().Milliseconds())

	w.I32(0) // axw.aW: fight instance id, unused by the client's own rendering

	// Coach loop. This list is INDEPENDENT of the team list: the client keys it
	// by coach id (`cp_2`) and later derives each coach's side from the team its
	// fighters landed in (`axw.a(team, side)`), so a 2v2 writes four entries
	// here against two teams below. It must therefore carry every MEMBER of
	// every side, not one coach per side.
	members := f.members()
	w.U8(uint8(len(members)))
	for _, m := range members {
		writeFightCoachBlock(w, m.Coach)
		w.U16(0) // stats report length = 0
	}

	// Team loop (fighters).
	w.U8(uint8(len(f.Teams)))
	for _, t := range f.Teams {
		writeTeamHeader(w, t)
		w.U8(uint8(len(t.Fighters)))
		for _, ff := range t.Fighters {
			w.U8(0) // fighterKind 0 = normal
			writeCombatFighterBlob(w, ff)
			w.I64(int64(ff.CoachID)) // owning coach id
		}
	}

	// Timeline (initiative-descending).
	w.U8(uint8(len(f.Timeline)))
	for _, ff := range f.Timeline {
		w.I64(ff.WireID)
	}

	// Events.
	w.U8(0)

	// Special cells: the map-authored tiles the client instantiates as live
	// EffectAreas. Sending 0 here (as we used to) leaves every tile inert
	// decoration — see B-048.
	writeSpecialCells(w, f.Arena())

	// Fight bud (adu_02.aI): the client loads fight/<bud>.jar!/<bud>.fmd for this
	// arena's team start-point highlights, so it must be the arena world id.
	w.U16(f.Arena().worldID)

	// Per-team stats tail: flag 0 = no rows.
	w.I32(0)

	// Spectator flag: 1 tells the client this recipient is a read-only viewer.
	if spectator {
		w.U8(1)
	} else {
		w.U8(0)
	}

	// gV().f fight-grid blob (aoq_0.f): a REAL walkable grid so the retail
	// client renders placement cells + fighters (an empty grid renders nothing).
	writeFightGrid(w, f.Arena())

	return protocol.EncodeS2C(protocol.OpCreateFight, w.Bytes())
}

// writeFightGrid emits the aoq_0.f fight-grid for the practice arena. Because the
// client renders on the last-STREAMED world (see startFightWithTeams, which sends
// EnterInstance for the arena world first), ayK/EN/EO/fb/fc just describe the
// arena tile; the per-cell altitude comes from the client's own topology.
//
// Layout (big-endian, matches aoq_0.f / aoq_0.getDataSize):
//
//	[i16 ayK][i16 bud][i32 EN][i32 EO][i32 fb][i32 fc]
//	[i16 cLw][i16 cLx][i16 cLs] cLs*[i16 cellFlags]
//	[i8 customTeams=0] [i8 cLE][i8 cLF]
func writeFightGrid(w *protocol.Writer, a *arena) {
	w.U16(a.worldID)                  // ayK (topology world = the streamed world)
	w.U16(a.worldID)                  // bud (map instance id)
	w.I32(0)                          // EN origin x
	w.I32(0)                          // EO origin y
	w.I32(a.width)                    // fb width
	w.I32(a.height)                   // fc height
	w.U16(uint16(a.centerX))          // cLw camera center x
	w.U16(uint16(a.centerY))          // cLx camera center y
	w.U16(uint16(a.width * a.height)) // cLs cell count
	for y := int32(0); y < a.height; y++ {
		for x := int32(0); x < a.width; x++ {
			w.U16(a.cellFlag(x, y)) // 0xFC00 floor / 0xFEFF void
		}
	}
	w.U8(0) // customTeams = 0 (client uses the .fmd / default split)
	w.U8(0) // cLE team-A default side
	w.U8(0) // cLF team-B default side
}

// coachActionDeckCapacity is the client's own capacity for the coach action deck:
// `aez_0.L` builds it as `new ajO(je_1.Wa(), 8)`. Anything past the 8th entry is
// refused by `ajv_2.a` and logged as a deserialisation failure, so never emit
// more.
const coachActionDeckCapacity = 8

// writeCoachActionDeck emits the coach's in-fight action deck as the 8000
// coach-card blob (byArray2 in aat_2.ac): [i16 4N][i32 id × N] — bare i32 ids,
// NO count/qty (the client's `ajv_2.d` reads to end). An empty deck writes
// [i16 0]. The client copies this blob onto each coach (aoe_2), which is why it
// is built per RECIPIENT (see startFightWithTeams).
//
// THE IDS ARE SPELL IDS, NOT CARD IDS. This used to emit `CoachCard.TemplateID`,
// which is the wrong namespace. The client deserialises the blob with
//
//	this.bMQ = new ajO(je_1.Wa(), 8);   // aez_0.L / Te.L
//
// and `je_1 extends azk`, whose `E(ByteBuffer)` reads an i32 and resolves it in
// its castable map. That map is filled ONLY by `apS` (its line 55 is the sole
// registration), which iterates the SPELL records (`co_1`, type 220) and
// registers one `yp_2` per spell under the spell id. Cards live in a different
// registry entirely — `eh_2` loads type-100 records into `la_0.XJ()` as `xj`.
//
// So a card id in this blob either misses — the client logs "impossible
// d'ajouter l'item" and drops it — or, worse, COLLIDES with an unrelated spell
// and renders it as a castable action card. 65 of the 325 cards with a usable
// action collide that way, so this was not theoretical.
//
// The deck is genuinely EMPTY today, and that is the correct output rather than a
// stub: nothing in the shipped data grants a coach an action spell. The rule that
// would (`np_1` type 27, "Ajouter un sort de coach") appears on no coach card —
// the 13 rule types that do appear are 1,2,3,4,5,10,11,17,19,20,24,29,31, and all
// of those are catalogue entries with no operands (see parameters.go). When the
// grant mechanism is found, it feeds coachActionDeckSpellIDs and nothing else
// here changes.
func writeCoachActionDeck(w *protocol.Writer, f *Fight, coach *domain.Coach) {
	deck := coachActionDeckSpellIDs(f, coach)
	w.U16(uint16(len(deck) * 4))
	for _, id := range deck {
		w.I32(id)
	}
}

// coachActionDeckSpellIDs returns the SPELL ids forming the coach's action deck,
// capped at the client's capacity and filtered so an id the client cannot resolve
// is never emitted.
//
// The filter is the important half: it makes it impossible to reintroduce the
// wrong-namespace bug by accident, because anything that is not a real spell is
// dropped here rather than shipped to a client that would either error or show an
// unrelated spell.
func coachActionDeckSpellIDs(f *Fight, coach *domain.Coach) []int32 {
	if coach == nil || f == nil || f.deps == nil {
		return nil
	}
	// Source of the coach's action spells. Empty until the grant mechanism is
	// identified — see writeCoachActionDeck. Everything downstream of here is
	// already correct, so filling this in is the whole remaining change.
	var candidates []int32
	return filterCoachDeckSpellIDs(f.deps.Spells, candidates)
}

// filterCoachDeckSpellIDs drops any id the client could not resolve, de-dupes,
// and caps at the client's deck capacity.
//
// Split out from coachActionDeckSpellIDs so this safety net is directly testable
// while the source list is still empty — it is the part that must not be wrong
// the day someone fills that list in.
func filterCoachDeckSpellIDs(spells *gamedata.Spells, candidates []int32) []int32 {
	if spells == nil || len(candidates) == 0 {
		return nil
	}
	out := make([]int32, 0, coachActionDeckCapacity)
	seen := make(map[int32]bool, coachActionDeckCapacity)
	for _, id := range candidates {
		if len(out) >= coachActionDeckCapacity {
			break
		}
		if id == 0 || seen[id] || spells.Get(id) == nil {
			continue // not in the client's castable registry: never emit it
		}
		seen[id] = true
		out = append(out, id)
	}
	return out
}

// writeFightCoachBlock emits the coach block as aez_0.b(bb, 34) reads it. The T
// reader consumes SKIN then HAIR then sex (by->skin palette, by2->hair palette),
// so skin must precede hair or the colors render swapped.
// [i64 id][u8 nameLen][name][i8 skin][i8 hair][i8 sex][i16 look]
// [i16 guildBlobLen=0][i16 linkageBlobLen=0].
func writeFightCoachBlock(w *protocol.Writer, c *domain.Coach) {
	w.I64(int64(c.ID))
	w.StringU8(c.Name)
	w.U8(c.Skin)
	w.U8(c.Hair)
	w.U8(c.Sex)
	w.U16(0) // look/scale
	w.U16(0) // guild blob length
	w.U16(0) // linkage blob length
}

// writeTeamHeader emits Te.f: [i8 side][u8 nameLen][name][i8 cardCount=0].
func writeTeamHeader(w *protocol.Writer, t *FightTeam) {
	w.U8(t.ID)
	w.StringU8("Team")
	w.U8(0) // team-level card count
}

// writeCombatFighterBlob emits the client's gn_0.b(ByteBuffer) fighter layout,
// verified byte-for-byte (audit July 2026). Field order after the name is the
// client's exact source order:
//
//	i64 id, u8 breed, str:u8 name,
//	u8 by2(sex/zv), u8 by3(ey color), u8 zu(look), u8 zt(look), u8 aRl(look),
//	u8 summoned, i32 xp,
//	i16 spellBlobLen + blob, i16 cardBlobLen + blob, i16 sphereBlobLen + blob,
//	i16 effectCount + i32*, i16 conditionCount + i16*,
//	i32 hpLost, i32 mpUsed, i32 apUsed
//
// The three look bytes (zu/zt/aRl) are cosmetic descriptor indices; we fill them
// from the coach look we have (skin/hair/eye). Byte count is exact so the client
// never underflows.
func writeCombatFighterBlob(w *protocol.Writer, ff *FightFighter) {
	f := ff.Fighter
	w.I64(ff.WireID)
	w.U8(f.BreedID)
	w.StringU8(f.Name)
	// Appearance, in the exact order gn_0.b reads it:
	//   zv(sex), ey(look version), zu(hair color), zt(skin color), aRl(eye color).
	// ey = -1 mirrors the roster et_2 blob (which renders correctly in the panel).
	w.U8(f.Sex)  // zv (sex)
	w.U8(0xFF)   // ey (look version = -1)
	w.U8(f.Hair) // zu (hair color)
	w.U8(f.Skin) // zt (skin color)
	w.U8(f.Eye)  // aRl (eye color)
	w.U8(0)      // NK flag (0 = normal, not summoned/leader)
	w.I32(0)     // xp/level

	// spell inventory blob: flat i32 spell ids
	spellBlob := protocol.NewWriter()
	for _, sp := range f.Spells {
		spellBlob.I32(sp.SpellID)
	}
	sb := spellBlob.Bytes()
	w.U16(uint16(len(sb)))
	w.Raw(sb)

	// card/equipment inventory blob: {i16 pos, i32 id}
	//
	// Filtered, because the receiving inventory cannot hold arbitrary positions:
	// `en_1.a` rejects anything outside [0,5) with "position en dehors des limites"
	// and then the whole item with "impossible d'ajouter l'item <id>". Sending a
	// fighter's full stored list produced 40 such rejections per fight — the
	// server believed in equipment the client had thrown away.
	cardBlob := protocol.NewWriter()
	for _, obj := range equipForWire(f.Objects) {
		cardBlob.U16(uint16(obj.Slot)).I32(obj.TemplateID)
	}
	cb := cardBlob.Bytes()
	w.U16(uint16(len(cb)))
	w.Raw(cb)

	// sphere board blob: the client's sphere reader (sH.b) ALWAYS reads a leading
	// u8 count, so an empty blob (len 0) underflows and makes the WHOLE fighter
	// fail to deserialize. Always send at least the count byte (0 spheres).
	w.U16(1)
	w.U8(0)

	// Effects list: [i16 count][i32 × count]. NOT buff icons — the client
	// resolves each id through `akp_1`, which `dq_1` fills from the SPHERE BOARD
	// content loader ("contentLoader.sphereBoard"), and then RE-APPLIES every
	// effect of the node it finds (gn_0.a(jg_0, vy_1, ib_2)). So this is the
	// fighter's unlocked sphere-board nodes, and it stays empty until that system
	// exists (types 900/901, 17 542 records). Putting buff ids here would not
	// draw an icon; it would look them up in the sphere registry and apply
	// whatever happened to share the id.
	w.U16(0)

	// Conditions list: [i16 count][i16 × count]. These ARE the persistent
	// fighter conditions (gamedata type 902 — wounds and blessings). The client
	// keys them into `gn_0.uk`, the same container the roster blob's evolution
	// tail fills via `et_2.uk`, and draws them on the fighter's portrait. Sending
	// them here is what makes an injured fighter still look injured after a
	// reconnect or to a spectator, both of which rebuild the fight from
	// CREATE_FIGHT.
	//
	// The client adds each id with a fixed level of 1 (`vy_1.b(id, (byte)1)`),
	// so the remaining-fights counter has no slot in this list; it travels in the
	// roster blob, which does have a duration byte.
	conds := ff.Fighter.Conditions
	if len(conds) > 255 {
		conds = conds[:255] // never let a corrupt row wrap the i16 count
	}
	w.U16(uint16(len(conds)))
	for _, c := range conds {
		w.U16(uint16(c.ConditionID))
	}

	// hp damage taken / mp used / ap used — the client derives current HP/AP/MP as
	// (max − delta). At a fresh fight start every fighter is full so all three are
	// 0; on a mid-fight RESUME (sendFightResync re-sends CREATE_FIGHT) these carry
	// the live damage/spend so the client rebuilds the fight at its current state.
	w.I32(maxI32(0, ff.MaxHP-ff.HP))
	// EFFECTIVE AP/MP (see effectiveAP/effectiveMP): a petrified fighter reads 0
	// of both and a rooted one reads 0 MP, so the gauges the client rebuilds on
	// a resume/spectate match what it would derive for itself.
	w.I32(maxI32(0, ff.MaxMP-ff.effectiveMP()))
	w.I32(maxI32(0, ff.MaxAP-ff.effectiveAP()))
}

// actorAppearEntry is one row of ACTOR_APPEAR (4102): a coach (real id) or a
// fighter (wire id) placed at a cell, facing a diagonal direction.
type actorAppearEntry struct {
	ID   int64
	X, Y int32
	Z    int16
	Dir  uint8
}

// diagonal Direction8 values — only these render fighter/coach sprites correctly
// in the iso client (cardinals render wrong). SE=(+x), NW=(-x), SW=(+y), NE=(-y).
const (
	dirSE uint8 = 1
	dirSW uint8 = 3
	dirNW uint8 = 5
	dirNE uint8 = 7
)

// diagonalFacing snaps the from->center vector to the nearest render-legal
// diagonal so an actor always looks toward the battlefield (matches the proven
// 2.04 server's coachFacingToward).
func diagonalFacing(from, center Pos) uint8 {
	dx, dy := center.X-from.X, center.Y-from.Y
	adx, ady := dx, dy
	if adx < 0 {
		adx = -adx
	}
	if ady < 0 {
		ady = -ady
	}
	if adx >= ady {
		if dx > 0 {
			return dirSE
		}
		if dx < 0 {
			return dirNW
		}
	} else {
		if dy > 0 {
			return dirSW
		}
		if dy < 0 {
			return dirNE
		}
	}
	return dirSE
}

// buildActorAppear serializes ACTOR_APPEAR (4102) — the ONLY message that inserts
// a fight actor into the client's iso render list (bd_1) and flips it visible
// (qg_2.g). Fighter avatars (vD) are created HIDDEN during the 8000 parse, so
// without a 4102 no sprite ever draws even though the fight/timeline/presentation
// all work. Layout: [u8 count]{ [i64 id][i32 x][i32 y][i16 z][u8 direction] }.
func buildActorAppear(entries []actorAppearEntry) ([]byte, error) {
	w := protocol.NewWriter().U8(uint8(len(entries)))
	for _, e := range entries {
		w.I64(e.ID).I32(e.X).I32(e.Y).U16(uint16(e.Z)).U8(e.Dir)
	}
	return protocol.EncodeS2C(protocol.OpActorAppear, w.Bytes())
}

// buildActorAppearForFight assembles the 4102 entity list: one entry per coach
// (REAL id, at its pedestal cell) plus one per fighter (wire id, at its start
// cell), all facing the arena centre. The client resolves each entry fighter-id
// first then coach id, so both coaches and fighters must be present to render.
func buildActorAppearForFight(f *Fight) ([]byte, error) {
	center := Pos{X: f.Arena().centerX, Y: f.Arena().centerY}
	var entries []actorAppearEntry
	// Every coach gets a pedestal, not just each side's representative: in a 2v2
	// all four stand at the arena edge. Pedestals are taken from the coach's OWN
	// side (pedestalsFor), so allies stand together and nobody is seated behind
	// the enemy line.
	//
	// An arena may populate no pedestals at all (15 of the 47 shipped ones do
	// not). Those coaches simply get no avatar rather than one flung to the
	// sentinel cell 2047 tiles off the map, which is what used to happen.
	for _, t := range f.Teams {
		if t == nil {
			continue
		}
		spots := f.Arena().pedestalsFor(t.ID)
		for i, mem := range t.Members {
			if mem.Coach == nil || i >= len(spots) {
				continue
			}
			cell := spots[i]
			entries = append(entries, actorAppearEntry{
				ID: int64(mem.Coach.ID), X: cell.X, Y: cell.Y, Z: cell.Z, Dir: diagonalFacing(cell, center),
			})
		}
	}
	for _, ff := range f.allFighters() {
		entries = append(entries, actorAppearEntry{
			ID: ff.WireID, X: ff.Pos.X, Y: ff.Pos.Y, Z: ff.Pos.Z, Dir: diagonalFacing(ff.Pos, center),
		})
	}
	return buildActorAppear(entries)
}

// --- empty fight-phase messages ---

func buildEmpty(opcode uint16) ([]byte, error) {
	return protocol.EncodeS2C(opcode, nil)
}

// buildReadyAck builds an ack carrying a coach id (8012 / 8024).
func buildReadyAck(opcode uint16, coachID uint) ([]byte, error) {
	return protocol.EncodeS2C(opcode, protocol.NewWriter().I64(int64(coachID)).Bytes())
}

// buildPlacementBroadcast builds MOVE_TO_FREE_PLACEMENT (8022):
// [i64 fighterId][i32 x][i32 y][i16 z].
func buildPlacementBroadcast(wireID int64, p Pos) ([]byte, error) {
	w := protocol.NewWriter().I64(wireID).I32(p.X).I32(p.Y).U16(uint16(p.Z))
	return protocol.EncodeS2C(protocol.OpMoveToFreePlacement, w.Bytes())
}

// buildNewTableTurn builds NEW_TABLE_TURN_BEGIN (8100):
// [i32 uid][i32 -1][i8 turnNum][i32 eventId].
//
// eventId is the round's EVENT CARD (events.go). The client looks it up in its
// own event table (cw_1.eO().w(id)) to display the card; 0 means "no card" (jg_1
// keeps null). The server owns both the draw and the effects.
func buildNewTableTurn(uid int32, turnNum uint8, eventID int32) ([]byte, error) {
	w := protocol.NewWriter().I32(uid).I32(-1).U8(turnNum).I32(eventID)
	return protocol.EncodeS2C(protocol.OpNewTableTurnBegin, w.Bytes())
}

// buildFighterTurnBegin builds FIGHTER_TURN_BEGIN (8104):
// [i32 uid][i32 -1][i64 fighterId].
func buildFighterTurnBegin(uid int32, wireID int64) ([]byte, error) {
	w := protocol.NewWriter().I32(uid).I32(-1).I64(wireID)
	return protocol.EncodeS2C(protocol.OpFighterTurnBegin, w.Bytes())
}

// buildFightCoachLooks is 60040 (S35c, Godot only): every coach in the fight
// with the cards it wears, in 5201's 0-based slots, so the client dresses
// the 3D coach figures. A coach with nothing on (or a synthetic one) is
// listed with none. S37: then the hair effect it shows (cosmetics.go).
// [u8 n]{[i64 coachId][u8 m]{[u8 slot][i32 cardId]}[i32 hairFx]}
func buildFightCoachLooks(f *Fight) ([]byte, error) {
	w := protocol.NewWriter()
	members := f.members()
	w.U8(uint8(len(members)))
	for _, m := range members {
		if m.Coach == nil {
			w.I64(0)
			w.U8(0)
			w.I32(0)
			continue
		}
		w.I64(int64(m.Coach.ID))
		worn := make([]domain.CoachCard, 0, 14)
		for _, c := range m.Coach.Inventory {
			if c.Pos > 0 && c.Pos <= 14 {
				worn = append(worn, c)
			}
		}
		w.U8(uint8(len(worn)))
		for _, c := range worn {
			w.U8(uint8(c.Pos - 1))
			w.I32(c.TemplateID)
		}
		w.I32(m.Coach.HairFx)
	}
	return protocol.EncodeS2C(protocol.OpFightCoachLooks, w.Bytes())
}

// sendFightCoachLooks sends 60040 to a Godot session (see Session.godot).
func sendFightCoachLooks(f *Fight, s *Session) {
	if s == nil || !s.godot.Load() {
		return
	}
	if looks, err := buildFightCoachLooks(f); err == nil {
		_ = s.Send(looks)
	}
}
