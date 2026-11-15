// Package content embeds the game's own design data: the cards, card sets,
// fighter cards and event cards (S40) and the rest of the rules (S43: spells,
// summonings, challenges, achievements...) that replaced the retail data.bdat
// tables. The data files are proprietary (see LICENSE in this directory); this
// file, like the rest of the server, is MIT.
package content

import (
	"embed"
	"io/fs"
)

//go:embed cards rules
var embedded embed.FS

// Cards is the cards/ tree: coach/set_<id>.json (one file per card set),
// sets.json, fighter.json and events.json. gamedata.LoadCardContent decodes it.
var Cards = sub("cards")

// Rules is the rules/ tree (spells.json, summonings.json, challenges.json...).
// gamedata.LoadRulesContent decodes it.
var Rules = sub("rules")

func sub(dir string) fs.FS {
	f, err := fs.Sub(embedded, dir)
	if err != nil {
		panic(err) // the directory is embedded above, so this cannot happen
	}
	return f
}
