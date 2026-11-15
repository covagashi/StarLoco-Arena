package gamedata

import (
	"sort"
	"testing"
)

// TestLoadTournamentsReal pins the type-1000/1001 decode. The record ends with
// five variable-length prize maps, so a field-order slip earlier in the record
// would almost certainly desync the tail and fail to parse — but it could also
// "succeed" with nonsense, which is what the plausibility assertions are for.
func TestLoadTournamentsReal(t *testing.T) {
	st, err := openContent(t)
	if err != nil {
		t.Fatal(err)
	}
	tr, err := st.LoadTournaments()
	if err != nil {
		t.Fatal(err)
	}
	// 22 records ship. Checking the exact count (not just "some") is what would
	// catch a record being silently rejected: decodeTournamentDef returns nil on
	// a bad parse, so a layout slip drops records rather than failing loudly.
	if tr.Len() != 22 {
		t.Fatalf("decoded %d tournament definitions, want 22", tr.Len())
	}

	ids := make([]int16, 0, tr.Len())
	for id := range tr.All() {
		ids = append(ids, id)
	}
	sort.Slice(ids, func(i, j int) bool { return ids[i] < ids[j] })

	cards, err := st.LoadCards()
	if err != nil {
		t.Fatal(err)
	}
	for _, id := range ids {
		d := tr.Get(id)
		prizes := 0
		for _, p := range d.Prizes {
			prizes += len(p)
		}
		t.Logf("tournament %d: teamType=%d inscriptionCard=%d rewardCard=%d rules=%d prizeEntries=%d flag=%v u=[%d %d %d %d %d]",
			d.ID, d.TeamType, d.InscriptionCard, d.RewardCard, len(d.Rules), prizes, d.Flag,
			d.Unknown1, d.Unknown2, d.Unknown3, d.Unknown4, d.Unknown5)

		// The team type must be one the client understands, or it would fall through
		// every branch of its tab selection.
		if d.TeamType > TournamentTeamLegendary {
			t.Errorf("tournament %d: teamType %d is outside aql_0 (0-4)", d.ID, d.TeamType)
		}
		// A card reference must resolve, or the client would render an empty slot
		// where the entry ticket / reward should be.
		if d.InscriptionCard != 0 && cards.Get(d.InscriptionCard) == nil {
			t.Errorf("tournament %d: inscriptionCard %d is not a real card", d.ID, d.InscriptionCard)
		}
		if d.RewardCard != 0 && cards.Get(d.RewardCard) == nil {
			t.Errorf("tournament %d: rewardCard %d is not a real card", d.ID, d.RewardCard)
		}
	}
	t.Logf("levels (type 1001): %v", tr.Levels())
}

// TestTournamentFeesAndRewardsAreScarce pins WHICH definitions charge and pay.
//
// This is the fact the prize handling rests on, and it is easy to assume wrongly
// in both directions. Only two of the 22 shipped tournaments advertise a prize
// and only two charge an entry ticket; the rest are free and pay nothing, so a
// reward path exercised only against the definitions the server currently
// offers (1, 4, 17 - all zero on both counts) would look correct while never
// once running.
func TestTournamentFeesAndRewardsAreScarce(t *testing.T) {
	st, err := openContent(t)
	if err != nil {
		t.Fatal(err)
	}
	tr, err := st.LoadTournaments()
	if err != nil {
		t.Fatal(err)
	}

	gotReward := map[int16]int32{}
	gotFee := map[int16]int32{}
	for id, d := range tr.All() {
		if d.RewardCard != 0 {
			gotReward[id] = d.RewardCard
		}
		if d.InscriptionCard != 0 {
			gotFee[id] = d.InscriptionCard
		}
	}

	wantReward := map[int16]int32{11: 26, 18: 544}
	wantFee := map[int16]int32{13: 16, 19: 808}
	if !sameTournamentCardMap(gotReward, wantReward) {
		t.Errorf("reward cards = %v, want %v", gotReward, wantReward)
	}
	if !sameTournamentCardMap(gotFee, wantFee) {
		t.Errorf("inscription cards = %v, want %v", gotFee, wantFee)
	}
}

func sameTournamentCardMap(a, b map[int16]int32) bool {
	if len(a) != len(b) {
		return false
	}
	for k, v := range a {
		if b[k] != v {
			return false
		}
	}
	return true
}
