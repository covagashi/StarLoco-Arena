// Command exportcards turns the retail card tables of data.bdat (coach cards,
// card sets, fighter cards, event cards) into the game's own content tree
// (S40, path A): the same structs as JSON, the same ids.
//
//	go run ./cmd/exportcards [bdat dir] [content dir]
//
// The defaults are data-dist and content/cards, run from server/. It is the
// one-way bridge: once the content is redesigned it is the source, and this
// command goes with data-dist (S43).
package main

import (
	"fmt"
	"os"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

func main() {
	dir, out := "data-dist", "content/cards"
	if len(os.Args) > 1 {
		dir = os.Args[1]
	}
	if len(os.Args) > 2 {
		out = os.Args[2]
	}
	c, err := gamedata.LoadRetailCardContent(dir)
	if err != nil {
		fmt.Fprintln(os.Stderr, "exportcards:", err)
		os.Exit(1)
	}
	if err := gamedata.WriteCardContent(out, c); err != nil {
		fmt.Fprintln(os.Stderr, "exportcards:", err)
		os.Exit(1)
	}
	fmt.Printf("wrote %s: %d coach cards, %d sets, %d fighter cards, %d events\n",
		out, c.Cards.Len(), c.Sets.Len(), c.Fighters.Len(), c.Events.Len())
}
