package gamedata

import (
	"os"
	"path/filepath"
	"testing"
)

// TestLoadFighterCardsReal decodes every fighter-card (type 250) from the real
// 2.70 store and locks the DATA-FORMAT §5/§3 parse against the shipped bytes by
// asserting the passive stat bonuses of a few known cards. Skips when the
// copyrighted data files are absent.
func TestLoadFighterCardsReal(t *testing.T) {
	if _, err := os.Stat(filepath.Join(clientBdataDir, "data.bdat")); err != nil {
		t.Skip("no client data")
	}
	st, err := Open(clientBdataDir)
	if err != nil {
		t.Fatal(err)
	}
	fc, err := st.LoadFighterCards()
	if err != nil {
		t.Fatal(err)
	}
	t.Logf("loaded %d fighter cards", fc.Len())
	if fc.Len() == 0 {
		t.Fatal("no fighter cards decoded")
	}

	// Known equip-time CharacBuff bonuses in the shipped 2.70 data (verified by
	// the (container,action,params) histogram: action 11=HP, 13=AP, 17=MP,
	// 76=init, magnitudes from params[0]).
	want := map[int32]FighterStatBonus{
		118: {HP: 40},        // big vitality card
		130: {HP: 20},        //
		163: {HP: 15},        //
		103: {HP: 10, AP: 1}, // HP + action-point card
		122: {MP: 2},         // movement card
		21:  {Init: 10},      // initiative card
	}
	for id, exp := range want {
		card := fc.Get(id)
		if card == nil {
			t.Errorf("card %d not decoded", id)
			continue
		}
		if card.Bonus != exp {
			t.Errorf("card %d bonus = %+v, want %+v", id, card.Bonus, exp)
		}
	}

	// Every decoded card must have a positive id and a sane bonus magnitude.
	withBonus := 0
	for id, c := range fc.All() {
		if c.ID != id || c.ID <= 0 {
			t.Fatalf("bad fighter-card id: key=%d rec=%d", id, c.ID)
		}
		if !c.Bonus.IsZero() {
			withBonus++
		}
		if c.Bonus.HP < 0 || c.Bonus.HP > 200 || c.Bonus.AP < 0 || c.Bonus.AP > 6 ||
			c.Bonus.MP < 0 || c.Bonus.MP > 6 || c.Bonus.Init < 0 || c.Bonus.Init > 200 {
			t.Errorf("card %d implausible bonus %+v", id, c.Bonus)
		}
	}
	t.Logf("%d/%d fighter cards grant a passive HP/AP/MP/Init bonus", withBonus, fc.Len())
}

// TestFighterCardUseEffectsReal locks the USE-time (weapon) half of the record:
// the container-type split, the AP cost, and above all the range field ORDER,
// which the record stores max-before-min.
func TestFighterCardUseEffectsReal(t *testing.T) {
	if _, err := os.Stat(filepath.Join(clientBdataDir, "data.bdat")); err != nil {
		t.Skip("no client data")
	}
	st, err := Open(clientBdataDir)
	if err != nil {
		t.Fatal(err)
	}
	fc, err := st.LoadFighterCards()
	if err != nil {
		t.Fatal(err)
	}

	usable := 0
	for id, c := range fc.All() {
		if !c.Usable() {
			continue
		}
		usable++
		// THE canary for the field order: reading the two i32s the other way
		// round makes min > max on every ranged weapon, which would silently
		// reject every legitimate attack.
		if c.RangeMin > c.RangeMax {
			t.Errorf("card %d: rangeMin %d > rangeMax %d — the range fields are swapped",
				id, c.RangeMin, c.RangeMax)
		}
		if c.RangeMin < 0 || c.RangeMax > 20 {
			t.Errorf("card %d: implausible range %d-%d", id, c.RangeMin, c.RangeMax)
		}
		if c.APCost <= 0 || c.APCost > 12 {
			t.Errorf("card %d: implausible AP cost %d", id, c.APCost)
		}
		// A usable card's active effects must all name an action.
		for i, ef := range c.UseEffects {
			if ef.ActionID == 0 {
				t.Errorf("card %d use-effect %d has no actionId", id, i)
			}
		}
	}
	if usable == 0 {
		t.Fatal("no card carries FIGHTER_CARD_USE effects — the container type is " +
			"space-padded in the data; it must be trimmed before comparing")
	}
	t.Logf("%d/%d fighter cards have an active (weapon) ability", usable, fc.Len())

	// Card 85 is a melee weapon: 4 AP, range 1-1, with a normal and a critical
	// damage variant. Its shape is what the use path is built against.
	if c := fc.Get(85); c == nil {
		t.Error("card 85 missing")
	} else {
		if c.APCost != 4 || c.RangeMin != 1 || c.RangeMax != 1 {
			t.Errorf("card 85 = %d AP range %d-%d, want 4 AP range 1-1",
				c.APCost, c.RangeMin, c.RangeMax)
		}
		var normal, crit int
		for _, ef := range c.UseEffects {
			if ef.IsCritical {
				crit++
			} else {
				normal++
			}
		}
		if normal == 0 || crit == 0 {
			t.Errorf("card 85 use-effects: %d normal / %d critical, want both", normal, crit)
		}
	}

	// Card 37 is the range-order proof: the record holds 5 then 2, so a decoder
	// reading (min,max) in file order would produce the impossible band 5-2.
	if c := fc.Get(37); c == nil {
		t.Error("card 37 missing")
	} else if c.RangeMin != 2 || c.RangeMax != 5 {
		t.Errorf("card 37 range = %d-%d, want 2-5", c.RangeMin, c.RangeMax)
	}
}
