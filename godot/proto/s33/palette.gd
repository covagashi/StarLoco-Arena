extends RefCounted

## S33 prototype palette (draft art bible): warm, low-saturation bodies with
## one strong accent each, a dark brown outline instead of black, and the
## stone-and-gold of the UI (UiStyle) on the arena and the scarf.

const OUTLINE := Color("2a1d14")
const SKIN := Color("f1cfa6")
const SKIN_SH := Color("c99a77")
const TUNIC := Color("5b7f6e")
const TUNIC_SH := Color("3f5c50")
const HAT := Color("c8553d")
const HAT_SH := Color("8e3527")
const GOLD := Color("e2bd6e")
const GOLD_SH := Color("a8853f")
const LEATHER := Color("6b4a33")
const LEATHER_SH := Color("4a3222")
const WOOD := Color("8a5a32")
const EYE := Color("2a1d14")

const STONE := Color("8a8370")
const STONE_ALT := Color("7d7663")
const STONE_HI := Color("a39c86")
const STONE_LO := Color("5c5747")
const MORTAR := Color("3d392f")
const MOSS := Color("6f7d4f")

## Team is read from the ring under the feet, never from the fighter's
## clothes (owner: no fighter colours).
const TEAM := [Color(0.235, 0.47, 1.0), Color("d8473a")]

## One colour pair per element: [core, edge].
const ELEMENT := {
	"fuego": [Color("ffd27a"), Color("e8541e")],
	"agua": [Color("bff3ff"), Color("2f8fe0")],
	"tierra": [Color("d9b56b"), Color("6e8a35")],
	"aire": [Color("ffffff"), Color("8fe0d0")],
	"neutro": [Color("efe3ff"), Color("8a6fc9")],
}
