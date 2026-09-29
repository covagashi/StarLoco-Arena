// dumpelements dumps every world's interactive elements (Zaaps, Card Masters,
// totems, …) from maps/env/<world>.jar into a JSON table the Godot client loads:
// {"<worldId>": [{"id","type","x","y","z","dir","flags","desc"}, ...]}.
//
// Usage: go run ./cmd/dumpelements <data-dir> <out.json>
// where <data-dir> is the directory containing maps/ (e.g. server/data-dist).
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

type rec struct {
	ID    int64  `json:"id"`
	Type  int16  `json:"type"`
	X     int32  `json:"x"`
	Y     int32  `json:"y"`
	Z     int16  `json:"z"`
	Dir   uint8  `json:"dir"`
	Flags int16  `json:"flags"`
	Desc  string `json:"desc"`
}

func main() {
	dir, out := os.Args[1], os.Args[2]
	envDir := filepath.Join(dir, "maps", "env")
	entries, err := os.ReadDir(envDir)
	if err != nil {
		panic(err)
	}
	worlds := map[string][]rec{}
	total := 0
	for _, e := range entries {
		name := e.Name()
		if !strings.HasSuffix(name, ".jar") {
			continue
		}
		wid, err := strconv.Atoi(strings.TrimSuffix(name, ".jar"))
		if err != nil {
			continue
		}
		elems, err := gamedata.LoadEnvWorld(dir, int16(wid))
		if err != nil {
			fmt.Fprintln(os.Stderr, "world", wid, "skipped:", err)
			continue
		}
		list := []rec{}
		for _, el := range elems {
			list = append(list, rec{el.InstanceID, el.Type,
				el.CellX, el.CellY, el.DecorAlt, el.Direction, el.Flags,
				el.Descriptor})
		}
		worlds[strconv.Itoa(wid)] = list
		total += len(list)
	}
	b, err := json.Marshal(worlds)
	if err != nil {
		panic(err)
	}
	if err := os.WriteFile(out, b, 0o644); err != nil {
		panic(err)
	}
	keys := make([]string, 0, len(worlds))
	for k := range worlds {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	fmt.Println("wrote", out, "worlds:", len(worlds), "elements:", total)
}
