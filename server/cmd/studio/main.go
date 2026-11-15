// Command studio is the content studio: a cross-platform desktop GUI that
// browses the game's own content (server/content: spells, summonings, static
// effects, cards) as sortable tables and edits the cards' balance fields.
//
// It is a command inside the server module so it loads the content with the
// same code as the server (gamedata.LoadRulesContent / LoadCardContent). The
// web frontend lives under frontend/ and is built into frontend/dist, which is
// embedded below.
package main

import (
	"embed"

	"github.com/wailsapp/wails/v2"
	"github.com/wailsapp/wails/v2/pkg/options"
	"github.com/wailsapp/wails/v2/pkg/options/assetserver"
	"github.com/wailsapp/wails/v2/pkg/options/windows"
)

//go:embed all:frontend/dist
var assets embed.FS

func main() {
	app := NewApp()

	err := wails.Run(&options.App{
		Title:            "Pippop Arena Studio",
		Width:            1280,
		Height:           820,
		MinWidth:         960,
		MinHeight:        600,
		BackgroundColour: &options.RGBA{R: 15, G: 17, B: 23, A: 1},
		AssetServer: &assetserver.Options{
			Assets: assets,
		},
		OnStartup: app.startup,
		Bind: []interface{}{
			app,
		},
		Windows: &windows.Options{
			WebviewIsTransparent: false,
			WindowIsTranslucent:  false,
		},
	})
	if err != nil {
		panic(err)
	}
}
