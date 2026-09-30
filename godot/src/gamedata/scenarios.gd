extends RefCounted

## Kanojedo tutorial scenarios (client `scripts/scenario/<id>.lua`, fired by
## ZoneTrigger env elements — kind 8 — via `anr_0.a(script, 0, [], false)` →
## `event_<id>_0`). The retail scripts are full Lua (UI locking, actor spawns,
## camera, widget particles); every one of them reduces to an ordered
## BubbleText monologue over `content.29` ids plus an optional
## `Context.updateAchievement` criterion report. This table keeps the page
## order verbatim; the world-view runner plays them as a paged dialog.
##
##   "ach"   — criterion sent on start (22003 {id,1,1})
##   "pages" — content.29 text ids, shown one per Next click
##   "zaap"  — follow-up page shown the next time the Zaap dialog opens
const SCRIPTS := {
	100: {"ach": 219, "pages": [256, 257, 258, 259, 182, 183, 184, 185,
		186, 187, 188]},
	101: {"pages": [189, 190, 191]},
	102: {"pages": [192, 193, 194]},
	103: {"pages": [195, 196, 197]},
	104: {"ach": 221, "pages": [198, 199]},
	105: {"pages": [200, 201]},
	106: {"pages": [202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212]},
	107: {"pages": [213, 214, 215, 216, 217, 218]},
	108: {"pages": [219], "zaap": 220},
	109: {"pages": [221, 222, 223]},
}


static func script(id: int) -> Dictionary:
	return SCRIPTS.get(id, {})
