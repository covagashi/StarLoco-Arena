package game

import (
	"log/slog"
	"path/filepath"
	"sort"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/store/storetest"
)

// TestEvolutionCupFieldsOnlyHistoriaStarters (S48): state 0 is every
// fighter's default, so "the titulars" include the Elite ones; an Evolution
// (and graveyard) cup must field the Historia starters alone.
func TestEvolutionCupFieldsOnlyHistoriaStarters(t *testing.T) {
	st, err := storetest.Open(t, filepath.Join(t.TempDir(), "troster.db"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = st.Close() })
	acc, _ := st.Accounts.CreateAccount("troster", "pw", false)
	coach, _ := st.Coaches.Create(acc.ID, "TRoster", 0, 0, 0)
	var want []int64
	for i, evo := range []bool{false, true, false, true, false} {
		f := &domain.Fighter{CoachID: coach.ID, BreedID: uint8(1 + i), Name: "F", Evolution: evo}
		if err := st.DB().Create(f).Error; err != nil {
			t.Fatal(err)
		}
		if evo {
			want = append(want, int64(f.ID))
		}
	}
	d := &Deps{Store: st, Log: slog.Default()}
	for _, preset := range []uint16{evolutionTeamPreset, graveyardTeamPreset} {
		got := d.tournamentRoster(coach.ID, 0, preset, 6)
		sort.Slice(got, func(i, j int) bool { return got[i] < got[j] })
		if len(got) != len(want) || got[0] != want[0] || got[1] != want[1] {
			t.Errorf("preset %d fields %v, want the Historia starters %v", preset, got, want)
		}
	}
}
