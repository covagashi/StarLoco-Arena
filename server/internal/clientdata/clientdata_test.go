package clientdata

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"

	"github.com/StarLoco/arena-2.70/content"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// clientDir is the tracked folder the client reads its tables from.
var clientDir = filepath.Join("..", "..", "..", "godot", "assets", "content")

// TestClientDataUpToDate: the client's tables are what the content builds.
// After changing server/content, run `go run ./cmd/exportclient` from server/.
func TestClientDataUpToDate(t *testing.T) {
	cards, err := gamedata.LoadCardContent(content.Cards)
	if err != nil {
		t.Fatal(err)
	}
	rules, err := gamedata.LoadRulesContent(content.Rules)
	if err != nil {
		t.Fatal(err)
	}
	files, err := Build(cards, rules)
	if err != nil {
		t.Fatal(err)
	}
	for name, want := range files {
		got, err := os.ReadFile(filepath.Join(clientDir, name))
		if err != nil {
			t.Errorf("%s: %v (run go run ./cmd/exportclient from server/)", name, err)
			continue
		}
		if !bytes.Equal(got, want) {
			t.Errorf("godot/assets/content/%s is out of date: run go run ./cmd/exportclient from server/", name)
		}
	}
}
