extends RefCounted

## qc_0 Direction8 wire index (0-7) -> authored anm dir + horizontal mirror.
## The anm sets only ship dirs {0,1,2,5,6}; 3/4/7 are mirrors of 1/0/5
## (gw_2.ao). fight_view.gd keeps its own copies as DIR_MAP/DIR_FLIP — keep
## both tables in sync if one ever changes.
const MAP := {0: 0, 1: 1, 2: 2, 3: 1, 4: 0, 5: 5, 6: 6, 7: 5}
const FLIP := {0: false, 1: false, 2: false, 3: true,
	4: true, 5: false, 6: false, 7: true}

## Wire indices: 0=E 1=SE 2=S 3=SW 4=W 5=NW 6=N 7=NE (qc_0 enum).
## Facing the camera (screen-down) is the SOUTH family — dir 2 is authored.
const FRONT := 2


static func anm_dir(wire_dir: int) -> int:
	return MAP.get(wire_dir & 7, 2)


static func mirrored(wire_dir: int) -> bool:
	return FLIP.get(wire_dir & 7, false)


## Load "<wire>_AnimStatique" for a wire direction, honoring the mirror table.
## Returns true when an action was loaded.
static func load_idle(spr, lib: String, wire_dir: int, action := "AnimStatique") -> bool:
	wire_dir &= 7
	if spr.load_action(lib, "%d_%s" % [anm_dir(wire_dir), action]):
		spr.scale.x = -absf(spr.scale.x) if mirrored(wire_dir) else absf(spr.scale.x)
		return true
	return false


## First fallback that exists — camera-facing dirs first.
static func load_idle_any(spr, lib: String, order: Array = [2, 3, 1, 0, 4, 6, 7, 5], action := "AnimStatique") -> bool:
	for d in order:
		if load_idle(spr, lib, int(d), action):
			return true
	return false


## S45: a menu gesture once ("AnimSalut" greet, "AnimPose"), then back to the
## menu stance ("AnimMenu"). False when the figure has no such clip.
static func gesture(spr, lib: String, wire_dir: int, action: String) -> bool:
	wire_dir &= 7
	if not spr.play_once(lib, "%d_%s" % [anm_dir(wire_dir), action]):
		return false
	spr.scale.x = -absf(spr.scale.x) if mirrored(wire_dir) else absf(spr.scale.x)
	var back := func(): load_idle(spr, lib, wire_dir, "AnimMenu")
	if not spr.action_finished.is_connected(back):
		spr.action_finished.connect(back, CONNECT_ONE_SHOT)
	return true
