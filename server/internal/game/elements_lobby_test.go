package game

import (
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// TestElementInstanceIDsAreUniqueAcrossWorlds pins what elementAnywhere relies
// on: an env instance id names one element in the whole game, not just in its
// world. If two worlds ever shared an id, the Godot lobby's 201 for one would
// open the other.
func TestElementInstanceIDsAreUniqueAcrossWorlds(t *testing.T) {
	seen := map[int64]int16{}
	for w, elems := range worldElements {
		for _, e := range elems {
			if prev, dup := seen[e.instanceID]; dup {
				t.Errorf("instance %d in world %d and world %d", e.instanceID, prev, w)
			}
			seen[e.instanceID] = w
		}
	}
	if len(seen) == 0 {
		t.Fatal("empty element table")
	}
}

// TestElementAnywhereFindsOtherWorlds: from any world, every element resolves to
// itself (same kind, same arg), and an unknown id resolves to nothing.
func TestElementAnywhereFindsOtherWorlds(t *testing.T) {
	for w, elems := range worldElements {
		for _, want := range elems {
			got, ok := elementAnywhere(want.instanceID)
			if !ok || got.kind != want.kind || got.arg != want.arg || got.cellX != want.cellX {
				t.Errorf("world %d instance %d: got %+v ok=%v", w, want.instanceID, got, ok)
			}
		}
	}
	if _, ok := elementAnywhere(-1); ok {
		t.Error("instance -1 resolved")
	}
}

// TestFusionLabRemembersTheOpenedAltar: once the coach opened an altar (its 201
// set fusionLabID), the fusion runs on THAT altar's tier even when the coach
// stands somewhere else — the Godot lobby opens altars from anywhere.
func TestFusionLabRemembersTheOpenedAltar(t *testing.T) {
	labs := gamedata.NewFusionLabs(
		&gamedata.FusionLab{ID: 2, Power: 1, Quality: 1, Slots: 2},
		&gamedata.FusionLab{ID: 5, Power: 30, Quality: 15, Slots: 5},
	)
	// Coach in world 25, far from any altar of lab 5.
	s := &Session{Coach: &domain.Coach{PosX: 40, PosY: -20}, deps: &Deps{FusionLabs: labs},
		currentWorld: 25}
	s.fusionLabID = 5
	if got := s.fusionLab(); got == nil || got.ID != 5 {
		t.Errorf("remembered altar 5, fusionLab = %v", got)
	}
	// An id the table doesn't know falls back to position, not to nil.
	s.fusionLabID = 999
	if got := s.fusionLab(); got == nil {
		t.Error("unknown remembered id: want the positional fallback, got nil")
	}
}
