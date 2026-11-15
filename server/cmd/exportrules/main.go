// Command exportrules turns the rest of the retail rules tables of data.bdat
// (spells, summonings, static effects, challenges, achievements, conditions,
// fusion labs, map bonuses, tournaments, sphere boards, equipment pools, NPC
// dialog replies) into
// the game's own content tree (S43), as S40's exportcards did for the cards.
//
//	go run ./cmd/exportrules [bdat dir] [content dir]
//
// The defaults are data-dist and content/rules, run from server/. Like
// exportcards, it goes with data-dist.
package main

import (
	"fmt"
	"os"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

func main() {
	dir, out := "data-dist", "content/rules"
	if len(os.Args) > 1 {
		dir = os.Args[1]
	}
	if len(os.Args) > 2 {
		out = os.Args[2]
	}
	r, err := gamedata.LoadRetailRulesContent(dir)
	if err != nil {
		fmt.Fprintln(os.Stderr, "exportrules:", err)
		os.Exit(1)
	}
	if err := gamedata.WriteRulesContent(out, r); err != nil {
		fmt.Fprintln(os.Stderr, "exportrules:", err)
		os.Exit(1)
	}
	fmt.Printf("wrote %s: %d spells, %d summonings, %d static effects, %d challenges, "+
		"%d achievements, %d conditions, %d fusion labs, %d map bonuses, %d tournaments, "+
		"%d sphere boards, %d equipment pools, %d NPC dialog replies\n", out,
		r.Spells.Len(), r.Summonings.Len(), r.StaticEffects.Len(), r.Challenges.Len(),
		r.Achievements.Len(), r.Conditions.Len(), r.FusionLabs.Len(), r.MapBonuses.Len(),
		r.Tournaments.Len(), r.SphereBoards.BoardCount(), r.EquipmentPools.Len(), r.NpcDialogs.Len())
}
