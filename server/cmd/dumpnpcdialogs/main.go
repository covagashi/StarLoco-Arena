// dumpnpcdialogs dumps the NPC dialog reply table (record type 1500, client
// `atF`) into JSON for the Godot client's NPC talk dialog.
//
// Retail model: each record is ONE reply row. Field order (atF.a v1):
//
//	[i16 textId]   content.60 reply label
//	[i16 groupId]  the reply group ("node") this row belongs to; the node's own
//	               speech text is content.59.<groupId>
//	[i16 nextId]   group to open on click (0 = close the dialog)
//	[i16 order]    row ordering within the group (ana_2.cIp, sorted by bq_0)
//	[i16 action]   action enum (alj): 1 = launch challenge, 2 = set criterion
//	[u8 n][i32×n]  action params (challenge id / criterion id)
//
// Clicking a reply runs its action then navigates to nextId (ao_2 case 17001).
//
// The merger (tools/asset-import/npc_dialogs.py) resolves text ids against
// i18n tables 29/59/60 into the shipped npcdialogs.json.
//
// Usage: go run ./cmd/dumpnpcdialogs <data-dir> <out.json>
package main

import (
	"encoding/binary"
	"encoding/json"
	"fmt"
	"os"
	"sort"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

type reply struct {
	Text   int32   `json:"text"`
	Next   int32   `json:"next"`
	Order  int32   `json:"order"`
	Act    int32   `json:"act"`
	Params []int32 `json:"params,omitempty"`
}

func main() {
	dir, out := os.Args[1], os.Args[2]
	st, err := gamedata.Open(dir)
	if err != nil {
		panic(err)
	}

	groups := map[int32][]reply{}
	// Challenge ids referenced by "launch challenge" replies, with each
	// challenge's mode field (afz_0.Qu() = Fields[1]) pre-resolved: NPC dialog
	// launches send 26330 [challengeId][mode], NOT the breedmaster's literal 99.
	challengeModes := map[int32]int32{}
	challengeDefs, _ := st.LoadChallenges()

	for _, e := range st.EntriesOf(1500) {
		rec, err := st.ReadRecord(e.Position)
		if err != nil {
			panic(err)
		}
		d := rec.Data
		if len(d) < 11 {
			fmt.Fprintf(os.Stderr, "record %d: short data %dB, skipped\n", rec.ID, len(d))
			continue
		}
		f := make([]int32, 5)
		for i := range f {
			f[i] = int32(int16(binary.BigEndian.Uint16(d[i*2:])))
		}
		n := int(d[10])
		if len(d) < 11+4*n {
			fmt.Fprintf(os.Stderr, "record %d: %d params over data %dB, skipped\n", rec.ID, n, len(d))
			continue
		}
		params := make([]int32, n)
		for i := 0; i < n; i++ {
			params[i] = int32(binary.BigEndian.Uint32(d[11+i*4:]))
		}
		groups[f[1]] = append(groups[f[1]], reply{
			Text: f[0], Next: f[2], Order: f[3], Act: f[4], Params: params,
		})
		if f[4] == 1 && n > 0 && challengeDefs != nil {
			if ch := challengeDefs.Get(params[0]); ch != nil {
				challengeModes[params[0]] = ch.Fields[1]
			}
		}
	}
	for _, rs := range groups {
		sort.Slice(rs, func(i, j int) bool { return rs[i].Order < rs[j].Order })
	}

	jsonGroups := map[string]any{}
	for id, rs := range groups {
		jsonGroups[fmt.Sprint(id)] = map[string]any{"replies": rs}
	}
	modes := map[string]int32{}
	for id, m := range challengeModes {
		modes[fmt.Sprint(id)] = m
	}

	// Achievements (type 800) gate the named-demon elements (env 6/9/7): the
	// client evaluates "achievement done" locally as every stat condition met
	// AND every required card in the tome (aau_1.a / sj_1.c). The dialog code
	// needs the whole table — ids 275..284 drive the demon pages.
	achievements := map[string]any{}
	if ach, err := st.LoadAchievements(); err == nil && ach != nil {
		for _, id := range ach.IDs() {
			a := ach.Get(id)
			if a == nil {
				continue
			}
			stats := map[string]int16{}
			for _, c := range a.Conditions {
				stats[fmt.Sprint(c.StatID)] = c.Threshold
			}
			achievements[fmt.Sprint(a.ID)] = map[string]any{
				"stats": stats,
				"cards": a.Cards,
			}
		}
	}

	blob := map[string]any{
		"groups":         jsonGroups,
		"challengeModes": modes,
		"achievements":   achievements,
	}

	buf, err := json.MarshalIndent(blob, "", "  ")
	if err != nil {
		panic(err)
	}
	if err := os.WriteFile(out, buf, 0o644); err != nil {
		panic(err)
	}
	fmt.Println("wrote", out, "groups:", len(groups), "challenge modes:", len(modes))
}
