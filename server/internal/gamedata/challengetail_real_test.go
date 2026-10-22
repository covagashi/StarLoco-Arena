package gamedata

import (
	"os"
	"path/filepath"
	"testing"
)

// TestChallengeTailReal locks the challenge record.
//
// ALL 39 records are now consumed EXACTLY. Challenges 29/30/31 used to stop
// short: each carries a type-12 parameter ("Lance un effet sur tous les
// combattants à la création du combat") whose trailing `Ht` effect is inline
// with no length prefix, so passing it needs a parser that consumes the effect
// exactly rather than one that relies on a length. `decodeEffectCursor` does
// that, so the record is whole.
func TestChallengeTailReal(t *testing.T) {
	if _, err := os.Stat(filepath.Join(clientBdataDir, "data.bdat")); err != nil {
		t.Skip("no client data")
	}
	st, err := Open(clientBdataDir)
	if err != nil {
		t.Fatal(err)
	}

	var total, exact int
	var withVictory, withBonuses, withInlineEffect int
	for _, e := range st.EntriesOf(TypeChallengeDef) {
		rec, err := st.ReadRecord(e.Position)
		if err != nil {
			continue
		}
		total++
		c := &cur{b: rec.Data}
		ch := decodeChallengeCursor(c)
		if ch == nil {
			t.Errorf("challenge at %d failed to decode", e.Position)
			continue
		}
		resid := len(rec.Data) - c.pos
		if c.err {
			t.Errorf("challenge %d: short read", ch.ID)
			continue
		}
		if resid != 0 {
			t.Errorf("challenge %d: %d byte(s) left over", ch.ID, resid)
			continue
		}
		exact++
		for _, p := range ch.Bonuses {
			if p.Type == ParamTypeVictoryCondition {
				withVictory++
			}
			if p.Effect != nil {
				withInlineEffect++
			}
		}
		if len(ch.Bonuses) > 0 {
			withBonuses++
		}
	}

	if total != 39 {
		t.Errorf("read %d challenges, want 39", total)
	}
	if exact != total {
		t.Errorf("%d/%d challenges consumed exactly, want all of them", exact, total)
	}

	// The three type-12 parameters that used to block the decode. Each carries an
	// inline, unlength-prefixed Ht that only a byte-exact effect parser can pass.
	if withInlineEffect != 3 {
		t.Errorf("%d parameters carry an inline effect, want 3 (challenges 29/30/31)", withInlineEffect)
	}

	// Lock what those effects ARE. This is the real evidence the inline parse is
	// byte-exact: the decoded values are all independently meaningful — container
	// "FIGHT_PARAMETER" (a rule applied at fight creation), action 122 (the
	// dodge-GAIN action from the same mh_2 table as the tackle stats), a sane
	// +40 magnitude, and the [63 0] infinite-duration marker used by the
	// FIGHTER_CONDITION rows. A misaligned read would not land on all four.
	chs, err := st.LoadChallenges()
	if err != nil {
		t.Fatal(err)
	}
	for _, id := range []int32{29, 30, 31} {
		ch := chs.Get(id)
		if ch == nil {
			t.Errorf("challenge %d missing", id)
			continue
		}
		var found bool
		for _, p := range ch.Bonuses {
			if p.Effect == nil {
				continue
			}
			found = true
			e := p.Effect
			if p.Type != 12 {
				t.Errorf("challenge %d: inline effect on np_1 type %d, want 12", id, p.Type)
			}
			if e.ContainerType != "FIGHT_PARAMETER" {
				t.Errorf("challenge %d: container %q, want FIGHT_PARAMETER", id, e.ContainerType)
			}
			if e.ActionID != 122 {
				t.Errorf("challenge %d: action %d, want 122 (dodge gain)", id, e.ActionID)
			}
			if len(e.Params) != 1 || e.Params[0] != 40 {
				t.Errorf("challenge %d: params %v, want [40]", id, e.Params)
			}
			if len(e.Duration) != 2 || e.Duration[0] != 63 {
				t.Errorf("challenge %d: duration %v, want the [63 0] infinite marker", id, e.Duration)
			}
		}
		if !found {
			t.Errorf("challenge %d carries no inline effect", id)
		}
	}

	// The type-14 "Condition de victoire" elements are the reason this record
	// needed a per-type layout at all: nine challenges carry one, and decoding
	// them with the generic np_1 layout desynchronised the whole tail.
	if withVictory != 9 {
		t.Errorf("%d victory-condition parameters, want 9", withVictory)
	}
	if withBonuses < withVictory {
		t.Errorf("bonus-bearing challenges (%d) < victory conditions (%d)", withBonuses, withVictory)
	}
}

// TestVictoryConditionLayout pins the type-14 element against the client's own
// size functions: wi_0.nj() = 12 + mp_2.nj(), and mp_2.nj() = 7 + 4*len + 6.
func TestVictoryConditionLayout(t *testing.T) {
	w := []byte{1}
	put32 := func(v int32) { w = append(w, byte(v>>24), byte(v>>16), byte(v>>8), byte(v)) }
	put32(ParamTypeVictoryCondition)
	put32(355) // id
	put32(0)   // parent
	// mp_2: [i16 type][i32 id][u8 n][i32 x n][u8 flag][i32 value][u8 grade]
	w = append(w, 0x04, 0x00) // type 1024 — the value that used to be misread as an effect version
	put32(99)
	w = append(w, 1)
	put32(7)
	w = append(w, 1)
	put32(42)
	w = append(w, 3)

	c := &cur{b: w}
	got, ok := decodeParameters(c)
	if !ok {
		t.Fatal("decodeParameters failed on a victory-condition element")
	}
	if len(got) != 1 || got[0].Victory == nil {
		t.Fatalf("got %+v, want one element with a victory condition", got)
	}
	v := got[0].Victory
	if v.Type != 1024 || v.ID != 99 || len(v.Params) != 1 || v.Params[0] != 7 ||
		!v.IsNecessary || v.VictoryPoints != 42 || v.AffectedTeam != 3 {
		t.Errorf("victory condition = %+v", v)
	}
	// wi_0.nj() = 12 + mp_2.nj() = 12 + (7 + 4*1 + 6) = 29, after the count byte.
	if want := 1 + 12 + 7 + 4 + 6; c.pos != want {
		t.Errorf("consumed %d bytes, want %d (wi_0.nj() + count byte)", c.pos, want)
	}
	// And it must NOT be mistaken for an effect-bearing element.
	if got[0].HasEffect() {
		t.Error("a victory condition was read as carrying a trailing effect")
	}
}

// TestChallengeEvolutionBlockReal pins the GE.QA-QD block the client keeps in
// afz_0 (S19). Only the Demon III evolution chain (29-31) and Barnabé (45)
// carry XP, which is what opens the client's evolution result dialogs
// (ajo_1: QC() > 0); 30 and 31 are listed only once achievements 280 / 281 are
// done ("achievementLinkedCompleted"). The time challenges 37-44 carry an
// xpLimit but no xp.
func TestChallengeEvolutionBlockReal(t *testing.T) {
	st, err := Open(clientBdataDir)
	if err != nil {
		t.Skip("no data-dist")
	}
	chs, err := st.LoadChallenges()
	if err != nil {
		t.Fatal(err)
	}
	want := map[int32][3]int32{ // xp, xpLimit, linked achievement
		29: {1, 1, 0}, 30: {2, 10, 280}, 31: {3, 15, 281}, 45: {5, 300, 0},
	}
	withXP := 0
	for id, ch := range chs.byID {
		if ch.XP > 0 {
			withXP++
		}
		w, ok := want[id]
		if !ok {
			if ch.XP != 0 || ch.LinkedAchievement != 0 {
				t.Errorf("challenge %d: xp=%d ach=%d, want 0/0", id, ch.XP, ch.LinkedAchievement)
			}
			continue
		}
		if ch.XP != w[0] || ch.XPLimit != w[1] || int32(ch.LinkedAchievement) != w[2] {
			t.Errorf("challenge %d: xp=%d limit=%d ach=%d, want %v", id, ch.XP, ch.XPLimit, ch.LinkedAchievement, w)
		}
	}
	if withXP != len(want) {
		t.Errorf("%d challenges carry xp, want %d", withXP, len(want))
	}
	if c := chs.Get(41); c == nil || c.XPLimit != 860 || c.TimeChallenge != 1 || c.Field15 != 1 {
		t.Errorf("time challenge 41 = %+v, want xpLimit 860, time 1, field15 1", c)
	}
}
