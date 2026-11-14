// Package content embeds the game's own design data (S40): the cards, card
// sets, fighter cards and event cards that replaced the retail data.bdat
// tables. The data files are proprietary (see LICENSE in this directory); this
// file, like the rest of the server, is MIT.
package content

import (
	"embed"
	"io/fs"
)

//go:embed cards
var embedded embed.FS

// Cards is the cards/ tree: coach/set_<id>.json (one file per card set),
// sets.json, fighter.json and events.json. gamedata.LoadCardContent decodes it.
var Cards = sub("cards")

func sub(dir string) fs.FS {
	f, err := fs.Sub(embedded, dir)
	if err != nil {
		panic(err) // the directory is embedded above, so this cannot happen
	}
	return f
}
