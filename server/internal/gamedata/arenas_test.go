package gamedata

import (
	"reflect"
	"testing"
)

// TestOwnArenas: the prototype's six arenas are embedded, decode, and are the
// release set.
func TestOwnArenas(t *testing.T) {
	own, err := loadOwnArenas()
	if err != nil {
		t.Fatal(err)
	}
	want := []int32{5, 10, 12, 15, 21, 36}
	if len(own) != len(want) {
		t.Fatalf("%d own arenas, want %d", len(own), len(want))
	}
	for _, id := range want {
		if own[id] == nil {
			t.Errorf("world %d missing", id)
		}
	}
	maps := loadMaps(t)
	got := maps.Release()
	if len(got) != len(want) {
		t.Fatalf("release = %v, want %v", got, want)
	}
	for i := range want {
		if got[i] != want[i] || !reflect.DeepEqual(maps.Get(want[i]), own[want[i]]) {
			t.Errorf("release[%d] = %d, want world %d's own arena", i, got[i], want[i])
		}
	}
}

// TestOwnArenaReplacesRetail: arena 5 (world 21) is the owner's, not the
// retail test data: 8 start cells a side instead of 1 against 14, three
// pedestals a side, and the stray cell under the map (17,17) is gone.
func TestOwnArenaReplacesRetail(t *testing.T) {
	own := loadMaps(t).Get(21)
	if len(own.Team0) != 8 || len(own.Team1) != 8 {
		t.Errorf("start cells %d/%d, want 8/8", len(own.Team0), len(own.Team1))
	}
	if len(own.CoachCells) != 6 {
		t.Errorf("%d pedestals, want 6", len(own.CoachCells))
	}
	if c := own.At(17, 17); !c.Void {
		t.Errorf("(17,17) = %+v, want void", c)
	}
}

func TestDecodeArenaFileRejectsBadData(t *testing.T) {
	for name, src := range map[string]string{
		"no cells":        `{"world": 1, "team0": [[0,0,0]], "team1": [[0,0,0]], "cells": {}}`,
		"bad kind":        `{"world": 1, "team0": [[0,0,0]], "team1": [[0,0,0]], "cells": {"0,0": [0, "lava"]}}`,
		"no team":         `{"world": 1, "team0": [[0,0,0]], "team1": [], "cells": {"0,0": [0, "floor"]}}`,
		"start off floor": `{"world": 1, "team0": [[0,0,0]], "team1": [[1,0,0]], "cells": {"0,0": [0, "floor"], "1,0": [0, "obstacle"]}}`,
		"start wrong z":   `{"world": 1, "team0": [[0,0,0]], "team1": [[1,0,3]], "cells": {"0,0": [0, "floor"], "1,0": [0, "floor"]}}`,
	} {
		if _, err := decodeArenaFile([]byte(src)); err == nil {
			t.Errorf("%s: decoded", name)
		}
	}
}
