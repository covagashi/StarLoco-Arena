extends RefCounted
class_name Palettes

## Decompiled palette tables for gw_2's 10 tint channels (ju_2.CZ&0x3F).
## Retail builds each entry as float[4]{r*1.25, g*1.25, b*1.25, 1.0}
## (aek_0/ee_2 aaV) — apply ×1.25 here too, channel colors multiply the
## authored texture, they don't replace it.
##
## Channels in use: 1=skin, 2=hair, 8=pupil/eye (fighter eyeColorIndex),
## 6/7/9 clothing (authored on retargeted gesture anms — left untinted).

## apH — coach skin tones (aez_0.bh → channel 1). Fantasy range.
const SKIN := [
	Vector3(1.0, 0.83, 0.49), Vector3(1.0, 0.81, 0.55),
	Vector3(1.0, 0.89, 0.75), Vector3(0.1, 0.1, 0.2),
	Vector3(0.2, 0.1, 0.2), Vector3(0.3, 0.3, 0.1),
	Vector3(0.43, 0.36, 0.56), Vector3(0.5, 0.6, 0.5),
	Vector3(0.8, 0.9, 0.45), Vector3(0.74, 0.9, 1.0),
	Vector3(0.8, 0.8, 0.8),
]

## agl_0 — coach hair colors (aez_0.bg → channel 2).
const HAIR := [
	Vector3(0.7, 0.34, 0.0), Vector3(1.0, 0.47, 0.0),
	Vector3(1.0, 0.7, 0.4), Vector3(1.0, 0.73, 0.23),
	Vector3(1.0, 0.23, 0.35), Vector3(1.0, 0.2, 0.2),
	Vector3(0.35, 0.36, 0.0), Vector3(0.83, 0.87, 0.1),
	Vector3(0.5, 1.0, 0.5), Vector3(0.8, 0.8, 1.0),
	Vector3(0.47, 0.56, 1.0), Vector3(0.2, 0.2, 0.4),
	Vector3(0.29, 0.47, 0.41), Vector3(1.0, 1.0, 0.75),
]

## tn_0 — fighter skin/hair/eye colors (ee_2 P/Q/R → channels 1/2/8).
const NATURAL := [
	Vector3(0.21, 0.12, 0.03), Vector3(0.32, 0.8, 0.68),
	Vector3(1.0, 0.88, 0.3), Vector3(1.0, 0.47, 0.06),
	Vector3(0.83, 0.85, 0.14), Vector3(1.0, 0.9, 0.65),
	Vector3(0.74, 0.65, 0.51), Vector3(0.25, 0.23, 0.2),
	Vector3(1.0, 0.86, 0.78), Vector3(1.0, 0.8, 0.74),
	Vector3(1.0, 0.94, 0.73), Vector3(1.0, 0.87, 0.62),
	Vector3(1.0, 0.77, 0.55), Vector3(0.91, 0.66, 0.56),
	Vector3(0.91, 0.74, 0.07), Vector3(0.77, 0.62, 0.39),
	Vector3(0.69, 0.44, 0.28), Vector3(0.51, 0.3, 0.16),
	Vector3(0.34, 0.16, 0.04), Vector3(0.54, 0.52, 0.27),
	Vector3(0.49, 0.43, 0.26), Vector3(0.37, 0.31, 0.18),
	Vector3(0.27, 0.44, 0.56), Vector3(0.12, 0.16, 0.22),
	Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.59, 0.84),
	Vector3(0.5, 0.72, 0.78), Vector3(0.59, 0.84, 0.0),
	Vector3(0.92, 0.82, 0.07), Vector3(0.71, 0.51, 0.0),
	Vector3(0.39, 0.16, 0.0), Vector3(0.25, 0.14, 0.04),
	Vector3(0.69, 0.32, 1.0), Vector3(0.13, 0.79, 1.0),
	Vector3(0.0, 0.0, 0.0), Vector3(0.72, 0.07, 0.02),
	Vector3(1.0, 0.32, 0.58), Vector3(0.61, 0.94, 0.19),
	Vector3(0.74, 0.47, 0.1), Vector3(1.0, 1.0, 1.0),
	Vector3(1.0, 0.9, 0.48), Vector3(0.0, 0.05, 0.3),
	Vector3(1.0, 0.85, 0.88), Vector3(0.83, 1.0, 0.97),
	Vector3(0.81, 0.31, 1.0), Vector3(1.0, 0.75, 0.12),
	Vector3(1.0, 0.06, 0.0),
]


static func pick(table: Array, idx: int) -> Vector3:
	if table.is_empty():
		return Vector3.ONE
	return table[idx % table.size()]


## Channel-tint map for AnmSprite.load_action tints — coach paper-doll
## (aez_0): skin→apH, hair→agl_0.  Values ×1.25 like retail aaV.
static func coach_tints(skin: int, hair: int) -> Dictionary:
	var s := pick(SKIN, skin) * 1.25
	var h := pick(HAIR, hair) * 1.25
	return {1: s, 2: h}


## Fighter paper-doll (ee_2): skin/hair/eye all draw from tn_0.
static func fighter_tints(skin: int, hair: int, eye: int) -> Dictionary:
	var s := pick(NATURAL, skin) * 1.25
	var h := pick(NATURAL, hair) * 1.25
	var e := pick(NATURAL, eye) * 1.25
	return {1: s, 2: h, 8: e}
