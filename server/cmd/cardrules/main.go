// Command cardrules applies the S40 card rules (internal/gamedata/cardrules.go:
// one cap per META effect whatever the rank, resurrection at 25 %, the
// re-priced fighter cards) to the content tree, in place.
//
//	go run ./cmd/cardrules [content dir]   (default: content/cards, from server/)
//
// It is idempotent, and it writes nothing else: the unchanged cards keep
// their bytes.
package main

import (
	"fmt"
	"os"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

func main() {
	dir := "content/cards"
	if len(os.Args) > 1 {
		dir = os.Args[1]
	}
	cc, err := gamedata.LoadCardContent(os.DirFS(dir))
	if err != nil {
		fmt.Fprintln(os.Stderr, "cardrules:", err)
		os.Exit(1)
	}
	before := len(gamedata.CardRuleViolations(cc))
	gamedata.ApplyCardRules(cc)
	if err := gamedata.WriteCardContent(dir, cc); err != nil {
		fmt.Fprintln(os.Stderr, "cardrules:", err)
		os.Exit(1)
	}
	fmt.Printf("%s: %d rule violations fixed, %d left\n", dir, before, len(gamedata.CardRuleViolations(cc)))
}
