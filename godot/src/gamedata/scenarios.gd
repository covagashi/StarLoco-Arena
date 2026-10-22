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
##   "speaker" — "adamai" / "baan" (else the tutorial voice)
##
## 113 and 117 are not zone triggers: they are the intros the demon-challenge
## elements (kind 7) play before offering their challenge.
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
	# Demon-challenge intros (pn_0 desc field 1, played once before the
	# offer; the script ends in runInteractiveElementSpecialAction).
	113: {"pages": [231, 232, 233, 234]},
	117: {"pages": [277, 278, 279]},
	# S10: the intro cinematic (0) and the landing (1), Adamai speaking; the
	# island they led to is gone, so they play once on the first lobby entry.
	0: {"speaker": "adamai", "pages": [90, 91, 92, 93, 94, 95, 96, 97]},
	1: {"speaker": "adamai", "pages": [98, 147, 148, 149]},
	# Fired by achievements (zN 22000 -> scriptID, see ACHIEVEMENT_SCRIPTS).
	115: {"pages": [238, 239]},
	116: {"pages": [242, 243, 244, 245, 246]},
	118: {"pages": [300, 303, 302, 301]},
	119: {"pages": [307, 306, 305, 304]},
	# Baan's tutorial (challenge 46, record fields 200/201): placement, then
	# moving and casting. Retail ran them inside the fight on its own cues;
	# here they are the lesson before the fight (S10).
	200: {"speaker": "baan", "pages": [282, 283, 284, 285]},
	201: {"speaker": "baan", "pages": [286, 287, 288, 289, 293, 294]},
}

## Achievement -> the scenario it starts when it unlocks (type 800 scriptID,
## played by zN on the 22000 while the tutorial toasts are on).
const ACHIEVEMENT_SCRIPTS := {
	278: 115, 279: 116, 280: 105, 281: 106, 284: 107, 454: 118, 455: 119,
}

## The tutorial achievements in the order retail's help (tooltipTutoDialog,
## asA) offered them as "the next step".
const TUTORIAL_STEPS := [275, 276, 284, 278, 277, 279]


static func script(id: int) -> Dictionary:
	return SCRIPTS.get(id, {})
