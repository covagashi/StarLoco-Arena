package e2e

import (
	"testing"
	"time"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/testclient"
)

const (
	opTeamPresetDelete  = 6023 // C2S: [i64 teamId][u16][u16]
	opTeamPresetDeleted = 6022 // S2C agH: [i8 status](+[i16 teamId] on success)
	opTeamPresetSave    = 6021 // C2S
	opTeamPresetSaved   = 6020 // S2C aic_0: [i8 status](+preset on success)
	opTeamPresetList    = 6030 // S2C
)

// TestDeletedTeamPresetIsAcknowledged: re-sending the preset list does NOT remove
// a deleted preset from the client.
//
// `dx_2` case 6030 calls `bs_0.IF().IG()`, which purges only the presets where
// `afK()` is false (`bMK.size() > 1` - the DUO ones) and KEEPS the normal ones,
// then merges the payload into a map keyed by preset id. A deleted preset is
// simply absent from that payload, so nothing ever removes it and it stays on
// screen until the player relogs. 6022 is what calls `bs_0.IF().as(id)`.
func TestDeletedTeamPresetIsAcknowledged(t *testing.T) {
	t.Parallel()
	st, addr := testServerWithStore(t)
	c, coachID := dialLogin(t, addr, "delp", "DelP")
	reachWorld(t, c)

	team := &domain.Team{CoachID: uint(coachID), Name: "Doomed", Type: -1, GameMode: 1}
	if err := st.Teams.Upsert(team); err != nil {
		t.Fatalf("create preset: %v", err)
	}
	c.DrainReceived(300 * time.Millisecond)

	_ = c.Send(2, opTeamPresetDelete,
		testclient.NewW().I64(int64(team.ID)).U16(0).U16(0).Bytes())

	f, _, err := c.WaitFor(opTeamPresetDeleted, testclient.DefaultTimeout)
	if err != nil {
		t.Fatalf("no 6022 after deleting a preset: the client keeps showing it: %v", err)
	}
	r := testclient.NewR(f.Payload)
	if status := r.U8(); status != 0 {
		t.Fatalf("6022 status = %d, want 0", status)
	}
	if got := r.U16(); got != uint16(team.ID) {
		t.Errorf("6022 preset id = %d, want %d - the client removes BY this id, so a "+
			"wrong one deletes the wrong row", got, team.ID)
	}
}

// TestDuplicateTeamNameIsRefused: retail refuses a preset name already in use -
// the client carries a dedicated status (25) and the string
// "error.teamManagement.teamNameExist" for exactly this. Without it the save
// silently succeeded and the team panel listed two identical names.
//
// The error frame is ONE byte: aic_0 reads the preset only inside
// `if (aV == 0)`, so anything appended would be left unread on a message the
// client considers complete.
func TestDuplicateTeamNameIsRefused(t *testing.T) {
	t.Parallel()
	st, addr := testServerWithStore(t)
	c, coachID := dialLogin(t, addr, "dupn", "DupN")
	reachWorld(t, c)

	existing := &domain.Team{CoachID: uint(coachID), Name: "Alpha", Type: -1, GameMode: 1}
	if err := st.Teams.Upsert(existing); err != nil {
		t.Fatalf("seed preset: %v", err)
	}
	c.DrainReceived(300 * time.Millisecond)

	_ = c.Send(2, opTeamPresetSave, teamPresetSaveBlob("Alpha"))

	f, _, err := c.WaitFor(opTeamPresetSaved, testclient.DefaultTimeout)
	if err != nil {
		t.Fatalf("no 6020 for a duplicate preset name: the save looks like it "+
			"worked and the panel shows two identical names: %v", err)
	}
	if n := len(f.Payload); n != 1 {
		t.Errorf("error frame = %d bytes, want 1 (aic_0 reads nothing after a "+
			"non-zero status)", n)
	}
	if got := testclient.NewR(f.Payload).U8(); got != 25 {
		t.Errorf("status = %d, want 25 (teamNameExist)", got)
	}

	// And it must NOT have been written.
	teams, err := st.Teams.ListByCoach(uint(coachID))
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if len(teams) != 1 {
		t.Errorf("coach has %d presets after a refused save, want 1", len(teams))
	}
}

// TestDistinctTeamNameStillSaves guards the over-correction: only a DIFFERENT
// preset with the same name is a clash.
func TestDistinctTeamNameStillSaves(t *testing.T) {
	t.Parallel()
	st, addr := testServerWithStore(t)
	c, coachID := dialLogin(t, addr, "okn", "OkN")
	reachWorld(t, c)
	existing := &domain.Team{CoachID: uint(coachID), Name: "Alpha", Type: -1, GameMode: 1}
	if err := st.Teams.Upsert(existing); err != nil {
		t.Fatalf("seed preset: %v", err)
	}
	c.DrainReceived(300 * time.Millisecond)

	_ = c.Send(2, opTeamPresetSave, teamPresetSaveBlob("Beta"))
	if _, _, err := c.WaitFor(opTeamPresetList, testclient.DefaultTimeout); err != nil {
		t.Fatalf("a distinct name was not saved: %v", err)
	}
	teams, _ := st.Teams.ListByCoach(uint(coachID))
	if len(teams) != 2 {
		t.Errorf("coach has %d presets, want 2", len(teams))
	}
}

// teamPresetSaveBlob builds a minimal valid 6021 payload: a normal (non-special)
// preset with no fighters, which is all the duplicate-name check needs.
//
// Layout from decodeTeamPreset: [u16 type][u16 teamId][u16 gameMode][u8 len name]
// then, for special types only, 4 appearance bytes - type -1 is not special, so
// they are omitted - then [u8 fighterCount] and the fighter entries.
func teamPresetSaveBlob(name string) []byte {
	return testclient.NewW().
		U16(uint16(0xFFFF)). // type -1
		U16(0).              // teamId 0 = new
		U16(1).              // gameMode
		Str8(name).
		U8(0). // no fighters
		U8(0). // no coach list (the 2v2 tail; decodeTeamPreset requires the count)
		Bytes()
}

// TestTeamPresetRoundTrip saves a preset that names a real fighter, reopens the
// team panel (6031) and reads the preset back out of the 6030 field by field:
// the bench team first, then ours with its name, mode, fighter and owner. The
// other tests only check that a 6030 arrives (S08).
func TestTeamPresetRoundTrip(t *testing.T) {
	t.Parallel()
	st, addr := testServerWithStore(t)
	c, coachID := dialLogin(t, addr, "rtp", "RoundTrip")
	reachWorld(t, c)
	c.DrainReceived(150 * time.Millisecond)

	blob := buildFighterBlob("Ida", 5)
	req := testclient.NewW().U8(0).U16(0).U16(uint16(len(blob))).Raw(blob).Bytes()
	_ = c.Send(3, testclient.OpFighterCreate, req)
	if _, _, err := c.WaitFor(testclient.OpFighterCreateResult, testclient.DefaultTimeout); err != nil {
		t.Fatalf("no create result: %v", err)
	}
	fighters, _ := st.Fighters.ListByCoach(uint(coachID))
	if len(fighters) != 1 {
		t.Fatalf("setup: %d fighters, want 1", len(fighters))
	}
	fid := int64(fighters[0].ID)
	c.DrainReceived(200 * time.Millisecond)

	save := testclient.NewW().
		U16(uint16(0xFFFF)).U16(0).U16(1).Str8("Vuelta").
		U8(1).I64(fid).I64(coachID).
		U8(0).Bytes()
	_ = c.Send(2, opTeamPresetSave, save)
	if _, _, err := c.WaitFor(opTeamPresetList, testclient.DefaultTimeout); err != nil {
		t.Fatalf("preset not saved: %v", err)
	}
	c.DrainReceived(150 * time.Millisecond)

	_ = c.Send(3, testclient.OpTeamPresetListReq, nil)
	var list, roster *testclient.Frame
	deadline := time.Now().Add(testclient.DefaultTimeout)
	for time.Now().Before(deadline) && (list == nil || roster == nil) {
		f, err := c.Recv(time.Until(deadline))
		if err != nil {
			break
		}
		switch f.Opcode {
		case opTeamPresetList:
			list = f
		case testclient.OpFighterList:
			roster = f
		}
	}
	if list == nil || roster == nil {
		t.Fatalf("6031 answered list=%v roster=%v, want both", list != nil, roster != nil)
	}
	if n := fighterListCount(roster.Payload); n != 1 {
		t.Errorf("6006 roster = %d fighters, want 1", n)
	}

	r := testclient.NewR(list.Payload)
	if n := r.U8(); n != 2 {
		t.Fatalf("6030 count = %d, want 2 (bench + ours)", n)
	}
	// bench: [i16 -4][i16 0][i16 0][name ""][u8 0][u8 0]
	if typ := int16(r.U16()); typ != -4 {
		t.Errorf("first preset type = %d, want -4 (bench)", typ)
	}
	r.U16()
	r.U16()
	_ = r.Str8()
	if fc, cc := r.U8(), r.U8(); fc != 0 || cc != 0 {
		t.Errorf("bench lists %d fighters / %d coaches, want none", fc, cc)
	}

	if typ := int16(r.U16()); typ != -1 {
		t.Errorf("preset type = %d, want -1", typ)
	}
	teams, _ := st.Teams.ListByCoach(uint(coachID))
	if len(teams) != 1 {
		t.Fatalf("store has %d presets, want 1", len(teams))
	}
	if id := r.U16(); uint(id) != teams[0].ID {
		t.Errorf("preset id = %d, want the stored %d", id, teams[0].ID)
	}
	if gm := r.U16(); gm != 1 {
		t.Errorf("gameMode = %d, want 1", gm)
	}
	if name := r.Str8(); name != "Vuelta" {
		t.Errorf("name = %q, want Vuelta", name)
	}
	if fc := r.U8(); fc != 1 {
		t.Fatalf("preset lists %d fighters, want 1", fc)
	}
	if got := r.I64(); got != fid {
		t.Errorf("fighter id = %d, want %d", got, fid)
	}
	if owner := r.I64(); owner != coachID {
		t.Errorf("owner = %d, want the coach %d", owner, coachID)
	}
	if cc := r.U8(); cc != 0 {
		t.Errorf("solo preset carries %d coaches, want 0", cc)
	}
}
