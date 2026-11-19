package gamedata

import (
	"testing"

	"github.com/StarLoco/arena-2.70/content"
)

// TestNoVisibleUnreachableAchievement (S48): criteria 147 (the 2vs2 ladder
// position) and 222 (the evolution ladder position) are kept by nobody — the
// 2vs2 is hidden and there is no evolution ladder (Historia has none, the
// ghost ladder is Elite only) — so an achievement asking either can never
// unlock and must stay out of the list.
func TestNoVisibleUnreachableAchievement(t *testing.T) {
	r, err := LoadRulesContent(content.Rules)
	if err != nil {
		t.Fatal(err)
	}
	unreachable := map[int16]bool{147: true, 222: true}
	for _, id := range r.Achievements.IDs() {
		a := r.Achievements.Get(id)
		for _, c := range a.Conditions {
			if unreachable[c.StatID] && !a.Hidden {
				t.Errorf("achievement %d asks criterion %d, which nothing keeps, and is visible", id, c.StatID)
			}
		}
	}
}
