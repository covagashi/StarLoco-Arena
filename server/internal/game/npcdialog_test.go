package game

import (
	"strconv"
	"strings"
	"testing"
)

// NPC dialog trees (ROADMAP item 27, record type 1500) are run ENTIRELY by the
// client. The server's whole obligation is to spawn the NPCTalker element; from
// there the client opens npcTalkDialog itself and walks the tree out of its own
// data. Evidence, all from the decompiled client:
//
//   - ao_2.a(fh_2,false) — registering the dialog frame OPENS "npcTalkDialog".
//     There is no request and no reply.
//   - The 17001/17002 it handles are NOT wire opcodes: they arrive as wm_0, which
//     extends sb_0 -> aed_2, whose encode() returns null, so they can never be
//     serialized. They are internal UI events (the same pattern as 22050/22051).
//   - A reply can do exactly two things, per the alj enum:
//     cEY(1,"Lancer un défi")  -> th_0 sends 26330 (challenge start), and
//     cEZ(2,"Donne un exploit") -> po_2 sends 22003 (a criterion).
//     Both are implemented and covered elsewhere.
//
// So there is no protocol to add. What CAN silently break the feature is the
// server no longer spawning the NPC, which is what this test guards.

// TestNPCTalkersAreSpawned: the NPCTalker elements must be present in their
// worlds' element lists, or their dialog trees become unreachable.
func TestNPCTalkersAreSpawned(t *testing.T) {
	found := map[int64]int16{} // instanceID -> world
	for world, elems := range worldElements {
		for _, e := range elems {
			if e.kind == kindNPC {
				found[e.instanceID] = world
			}
		}
	}
	if len(found) == 0 {
		t.Fatal("no NPCTalker elements are spawned: every NPC dialog tree in the " +
			"game is unreachable")
	}
	// The full retail placement. Pinned so a regeneration that drops one is loud.
	// Five sit on the Gostof / Baan island (85); the sixth is on 79.
	want := map[int64]int16{143: 85, 170: 85, 171: 85, 172: 85, 173: 85, 181: 79}
	for id, world := range want {
		got, ok := found[id]
		if !ok {
			t.Errorf("NPC %d is not spawned at all", id)
			continue
		}
		if got != world {
			t.Errorf("NPC %d is in world %d, want %d", id, got, world)
		}
	}
	if len(found) != len(want) {
		t.Errorf("spawned %d NPCs, want %d (%v)", len(found), len(want), found)
	}
}

// TestNPCDescriptorsCarryDialogGroups pins the real ni_0 descriptor layout:
//
//	nameTextId ; criterionId ; defaultGroup ; altGroup ; guiStyle
//
// All six NPCs carry a dialog group — the "only bob talks" belief came from
// misreading field 1 (the criterion gate) as the dialog id. The client opens
// altGroup when criterionId != -1 and the criterion's value is > 0, else
// defaultGroup. Only bob (143) is criterion-gated (228); the ghosts and the
// demon use -1, so they always open their default group.
func TestNPCDescriptorsCarryDialogGroups(t *testing.T) {
	// instanceID -> {criterionId, defaultGroup, altGroup}
	want := map[int64][3]int{
		143: {228, 7, 7},   // bob — Baan, the tutorial guide
		170: {-1, 56, 56},  // Sramette ghost
		171: {-1, 45, 45},  // Iop ghost
		172: {-1, 50, 50},  // Sacrieur ghost
		173: {-1, 60, 60},  // Enutrof ghost
		181: {-1, 65, 65},  // Demon I
	}
	got := map[int64][3]int{}
	for _, elems := range worldElements {
		for _, e := range elems {
			if e.kind != kindNPC {
				continue
			}
			desc := trailingDescriptor(e.payload)
			parts := strings.Split(desc, ";")
			if len(parts) < 5 {
				t.Errorf("NPC %d: descriptor %q has <5 fields", e.instanceID, desc)
				continue
			}
			var f [3]int
			for i := 0; i < 3; i++ {
				v, err := strconv.Atoi(parts[i+1])
				if err != nil {
					t.Errorf("NPC %d: field %d %q is not a number (descriptor %q)",
						e.instanceID, i+1, parts[i+1], desc)
				}
				f[i] = v
			}
			got[e.instanceID] = f
		}
	}
	if len(got) != len(want) {
		t.Fatalf("expected %d NPC descriptors, got %v", len(want), got)
	}
	for id, w := range want {
		if got[id] != w {
			t.Errorf("NPC %d descriptor = %v, want %v", id, got[id], w)
		}
	}
}

// trailingDescriptor extracts the ';'-separated ASCII descriptor at the end of an
// element payload (NUL-terminated in the env record).
func trailingDescriptor(payload []byte) string {
	end := len(payload)
	for end > 0 && payload[end-1] == 0 {
		end--
	}
	start := end
	for start > 0 {
		c := payload[start-1]
		printable := c >= 0x20 && c < 0x7f
		if !printable {
			break
		}
		start--
	}
	return string(payload[start:end])
}
