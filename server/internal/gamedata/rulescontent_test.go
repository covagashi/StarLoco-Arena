package gamedata

import (
	"testing"

	"github.com/StarLoco/arena-2.70/content"
)

// TestRulesContentLoads: the embedded tree loads whole without client data,
// which is all the server runs on.
func TestRulesContentLoads(t *testing.T) {
	r, err := LoadRulesContent(content.Rules)
	if err != nil {
		t.Fatal(err)
	}
	if r.Spells.Len() == 0 || r.Challenges.Len() == 0 || r.Achievements.Len() == 0 ||
		r.SphereBoards.BoardCount() == 0 || len(r.Tournaments.Levels()) == 0 {
		t.Fatalf("rules content is missing tables: %d spells, %d challenges, %d achievements, "+
			"%d boards, %d tournament levels", r.Spells.Len(), r.Challenges.Len(),
			r.Achievements.Len(), r.SphereBoards.BoardCount(), len(r.Tournaments.Levels()))
	}
}
