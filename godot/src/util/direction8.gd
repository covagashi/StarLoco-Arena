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
static func load_idle(spr, lib: String, wire_dir: int) -> bool:
	wire_dir &= 7
	if spr.load_action(lib, "%d_AnimStatique" % anm_dir(wire_dir)):
		spr.scale.x = -absf(spr.scale.x) if mirrored(wire_dir) else absf(spr.scale.x)
		return true
	return false


## First fallback that exists — camera-facing dirs first.
static func load_idle_any(spr, lib: String, order: Array = [2, 3, 1, 0, 4, 6, 7, 5]) -> bool:
	for d in order:
		if load_idle(spr, lib, int(d)):
			return true
	return false
