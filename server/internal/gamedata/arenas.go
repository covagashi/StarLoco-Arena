package gamedata

import (
	"embed"
	"encoding/json"
	"fmt"
	"sort"
	"strconv"
	"strings"
)

// The prototype's own arenas (S36 phase D): the fight shape of each arena the
// owner built in the map editor, exported from its layout by the Godot client
// (godot/src/maps/arena_layout.gd, fight_shape / fight_json; the editor writes
// them on every save). They carry the owner's cell roles and heights, so the
// server plays the arena the client draws. One file per world:
//
//	{"world": 21, "arena": 5,
//	 "team0": [[x, y, z], ...], "team1": [...], "coach": [[x, y, z], ...],
//	 "specials": [[x, y, z, template], ...],
//	 "cells": {"x,y": [alt, "floor" | "obstacle"], ...}}
//
// A cell that is not listed is void. These replace the retail .jar data for
// their worlds, and they are the only arenas new fights are drawn on.
//
//go:embed arenas/*.json
var ownArenas embed.FS

type arenaFile struct {
	World    int32             `json:"world"`
	Arena    int               `json:"arena"`
	Team0    [][3]int32        `json:"team0"`
	Team1    [][3]int32        `json:"team1"`
	Coach    [][3]int32        `json:"coach"`
	Specials [][4]int32        `json:"specials"`
	Cells    map[string][2]any `json:"cells"`
}

// loadOwnArenas decodes every embedded arena, keyed by world id.
func loadOwnArenas() (map[int32]*FightMap, error) {
	entries, err := ownArenas.ReadDir("arenas")
	if err != nil {
		return nil, err
	}
	out := make(map[int32]*FightMap, len(entries))
	for _, e := range entries {
		b, err := ownArenas.ReadFile("arenas/" + e.Name())
		if err != nil {
			return nil, err
		}
		m, err := decodeArenaFile(b)
		if err != nil {
			return nil, fmt.Errorf("arena %s: %w", e.Name(), err)
		}
		out[m.ID] = m
	}
	return out, nil
}

func decodeArenaFile(b []byte) (*FightMap, error) {
	var f arenaFile
	if err := json.Unmarshal(b, &f); err != nil {
		return nil, err
	}
	type parsed struct {
		x, y  int32
		alt   int16
		floor bool
	}
	cells := make([]parsed, 0, len(f.Cells))
	minX, minY := int32(1<<30), int32(1<<30)
	maxX, maxY := int32(-(1 << 30)), int32(-(1 << 30))
	for key, v := range f.Cells {
		xs, ys, ok := strings.Cut(key, ",")
		x, errX := strconv.Atoi(xs)
		y, errY := strconv.Atoi(ys)
		alt, okAlt := v[0].(float64)
		kind, okKind := v[1].(string)
		if !ok || errX != nil || errY != nil || !okAlt || !okKind ||
			(kind != "floor" && kind != "obstacle") {
			return nil, fmt.Errorf("bad cell %q", key)
		}
		c := parsed{x: int32(x), y: int32(y), alt: int16(alt), floor: kind == "floor"}
		cells = append(cells, c)
		if c.x < minX {
			minX = c.x
		}
		if c.y < minY {
			minY = c.y
		}
		if c.x > maxX {
			maxX = c.x
		}
		if c.y > maxY {
			maxY = c.y
		}
	}
	if len(cells) == 0 {
		return nil, fmt.Errorf("no cells")
	}
	m := &FightMap{ID: f.World, MinX: minX, MinY: minY,
		Width: maxX - minX + 1, Height: maxY - minY + 1}
	m.cells = make([]MapCell, m.Width*m.Height)
	for i := range m.cells {
		m.cells[i] = MapCell{Alt: voidAltitude, Void: true}
	}
	for _, c := range cells {
		m.cells[(c.y-minY)*m.Width+(c.x-minX)] = MapCell{Alt: c.alt, Ground: c.floor}
	}
	pos := func(src [][3]int32) []MapPos {
		out := make([]MapPos, 0, len(src))
		for _, p := range src {
			out = append(out, MapPos{X: p[0], Y: p[1], Z: int16(p[2])})
		}
		return out
	}
	m.Team0, m.Team1 = pos(f.Team0), pos(f.Team1)
	m.CoachCells = pos(f.Coach)
	for _, s := range f.Specials {
		m.Specials = append(m.Specials, MapSpecial{X: s[0], Y: s[1], Z: int16(s[2]), Template: s[3]})
	}
	if len(m.Team0) == 0 || len(m.Team1) == 0 {
		return nil, fmt.Errorf("a team has no start cell")
	}
	for _, p := range append(append([]MapPos{}, m.Team0...), m.Team1...) {
		if c := m.At(p.X, p.Y); !c.Ground || c.Alt != p.Z {
			return nil, fmt.Errorf("start cell %d,%d is not floor at %d", p.X, p.Y, p.Z)
		}
	}
	return m, nil
}

// applyOwnArenas puts the embedded arenas over the retail ones and makes them
// the release set.
func (f *FightMaps) applyOwnArenas(own map[int32]*FightMap) {
	for id, m := range own {
		f.byID[id] = m
		f.release = append(f.release, id)
	}
	sort.Slice(f.release, func(i, j int) bool { return f.release[i] < f.release[j] })
}

// Release returns the world ids new fights are drawn on: the prototype's own
// arenas. Empty means every loaded arena.
func (f *FightMaps) Release() []int32 { return f.release }
