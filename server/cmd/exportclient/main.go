// Command exportclient writes the Godot client's data tables (spells, effects,
// areas, cards, fighter cards, sphere boards, NPC dialogs...) from the game's
// own content into godot/assets/content/ (S43). Run it from server/ after a
// change to server/content; TestClientDataUpToDate fails until you do.
//
//	go run ./cmd/exportclient [out dir]
package main

import (
	"fmt"
	"os"
	"sort"

	"github.com/StarLoco/arena-2.70/content"
	"github.com/StarLoco/arena-2.70/internal/clientdata"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

func main() {
	out := "../godot/assets/content"
	if len(os.Args) > 1 {
		out = os.Args[1]
	}
	cards, err := gamedata.LoadCardContent(content.Cards)
	if err != nil {
		fail(err)
	}
	rules, err := gamedata.LoadRulesContent(content.Rules)
	if err != nil {
		fail(err)
	}
	files, err := clientdata.Write(out, cards, rules)
	if err != nil {
		fail(err)
	}
	names := make([]string, 0, len(files))
	for n := range files {
		names = append(names, n)
	}
	sort.Strings(names)
	fmt.Println("wrote", out+":", names)
}

func fail(err error) {
	fmt.Fprintln(os.Stderr, "exportclient:", err)
	os.Exit(1)
}
