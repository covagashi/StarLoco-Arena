package gamedata

// Effect is the subset of a decoded Ht effect record (type 200) the server
// needs. actionId maps to a RunningEffect (e.g. 11=HP boost); containerType is
// the parent tag ("FIGHTER_CARD_EQUIP" / "FIGHTER_CARD_USE" / …) that decides
// whether the effect is passive (applied while equipped) or active (on use);
// params are the effect's f32 magnitudes (params[0] is the bonus amount for a
// CharacBuff).
type Effect struct {
	EffectID      int32 // field 1: the generic-effect id (the client's part-0 genericEffectId)
	ActionID      int32
	IsCritical    bool // field 11: this effect runs on a CRITICAL hit (vs the normal subset)
	ContainerType string
	AreaShape     int32 // field 5: zone shape ordinal (1 point, 2 circle, 3 cross, 4 T, 9 T-inv, 32767 all)
	Params        []float32
	AreaSize      []int32 // 5th post-params array (Tg/effect_area_size): zone radius/size params
	Duration      []int32 // 6th post-params array: buff duration in turns (empty/[0] for instant effects)
	Targets       []int64 // field 19: target-condition bitmasks (empty = no restriction)
}
