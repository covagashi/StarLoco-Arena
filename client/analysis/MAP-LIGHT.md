# DofusArena 2.70 — map colour data (`maps/light/<id>.jar` and element tints)

How the retail client colours the map elements it draws. Two sources feed it:
a per-element tint stored with each element in `maps/gfx/<id>.jar`, and a
per-element light map in `maps/light/<id>.jar`. Neither is applied by our
Godot renderer today (`tools/asset-import/map_gfx.py` reads past both).

Read from the decompiled client on 2026-10-17 (sprints/S04). Everything in
§1–§3 is the byte layout and the arithmetic as the code does it; §4 lists
what still has to be checked against a live client.

Files are read through `acf`, **little-endian** like the `tplg` chunks.

## 1. `maps/light/<id>.jar`

One entry per map chunk, named `<cx>_<cy>` (chunk coordinates; a chunk is
18×18 cells). Loader: `uQ` (singleton, path from the `mapsLightPath`
preference) → `acd_0.b(acf)`.

```
i16  cx            chunk x  (first cell x = cx * 18)
i16  cy            chunk y
u16  n             record count
n × 21 bytes:
  i64  key         (x + 32768 & 0xFFFF) << 48 | (y + 32768 & 0xFFFF) << 32 | layer
  bool flag        bit-packed (acf.aqE): one byte here, bit 7 → 0x80 = true
  i32  base        colour, byte 0 = r, 1 = g, 2 = b (vP.dY/dX/dW), byte 3 = a
  i32  day         colour, same packing
  i32  night       colour, same packing
```

- `x`, `y` are absolute cell coordinates. **`layer` is the element's layer
  byte** (`ScreenElement.coF`, the 5th field of an element record — `_cof` in
  `map_gfx.py`), not its altitude. One record colours every element at
  (x, y, layer).
- `0xFF808080` (= `vP.atR`, grey 128) is the "unset" sentinel for `day` and
  `night`.

Per record the client builds an `adb_0`:

```
base' = base_rgb / 255 * 2          # 0x80 → ~1.0, so 1.0 is neutral, range 0..2
day'  = day_rgb / 255               # only if day  != sentinel
night'= night_rgb / 255 - 0.5       # only if night != sentinel (additive)
```

and recomputes it whenever the global light factor `f` (`ahn_0.dNR`, 1.0 after
a reset) moves by more than 0.05 (`adb_0.a(f)`):

```
f == 0      colour = base'
f  > 0      colour = clamp(base' * (day' * 2f + 1 - f), 0, 2)   (if day is set)
f  < 0      colour = base';  additive = night' * (-2f)          (if night is set)
```

At the default `f = 1` that is simply `base' * day' * 2`.

`ahn_0.aUi()` then gives every displayed element at (x, y, layer) that
colour as its material colour (`DisplayedScreenElement.e`). If the record's
`flag` is set, the dynamic light field (`dNT`, the scripted lights:
`lightId`, x/y/z, range, rgb) is combined on top (`ko_1.c`); with a night
term, `ko_1.d` adds it and each channel is capped at 2. An element with no
record gets the dynamic field alone.

### What the 47 arenas carry

Counted with a one-off script over the retail `contents/maps` (47 worlds whose
`fight/*.jar` holds a `.fmd`; the other 67 are overworld maps):

- 10,014 records; **all** have `flag` set, `base` = neutral grey, no `night`.
- `day` is always set: multiplier (`day' * 2`) median **0.86**, 5th
  percentile **0.38**, 95th 0.97, a few up to 1.24; 86 % grey, 14 % tinted.
- Some arenas have none at all (10, 36): their chunks are 6-byte headers with
  `n = 0`.

So in arenas the light jar is **baked shading** — shadows under trees and
walls, darker pits — not light *sources*. The dynamic light field is where
torches and similar would come from.

## 2. Per-element tint in `maps/gfx/<id>.jar`

Each element record (`ScreenElement.b(acf)`) is:

```
u8   type          bit mask, see below (read before the record)
i16  cto           altitude
i8   aba
i8   cts           intra-cell order
i32  bPM
i8   layer         coF — the light-map key above
i32  aoq
bool ctt           bit-packed
i32  elementId
then the colour bytes, by type bit (ScreenElement.a(float[], int, acf)):
  bit 0x01   3 × i8   c / 255 * 2 + 1
  bit 0x02   3 × i8   c / 255 + 0.5          ← the tint
  bit 0x04   3 × i8   c / 255
  bit 0x08   1 × i8   c / 255 + 0.5          alpha
  bit 0x10   gradient: a second 0x02 triple and 0x08 alpha (if those bits)
```

The bytes are signed, so the 0x02 tint spans 0..1 with **0.5 neutral** — an
element without the bit gets 0.5 (`ScreenElement.u`).
`ScreenElement.d` multiplies the vertex colour by that tint and the alpha.

In the 47 arenas 22,645 of 32,362 elements (70 %) carry the 0x02 tint and no
other colour bit. Mean raw value −13.7 (→ 0.45, a bit darker than neutral),
7 % grey; the most common triples are warm/dark shades such as (−46, −38, −50)
and (−74, −93, −110).

## 3. Putting it together

Per element, as far as the code shows:

```
vertex colour   = tint (0..1, 0.5 neutral) [* gradient] , alpha
material colour = light-map colour (0..2, 1.0 neutral) [+ dynamic lights]
```

The neutral points (0.5 and 1.0) suggest the usual "modulate 2×" convention:
on screen, texel × 2·tint × light. **That last step lives in the GL material /
shader and was not read**, so it is the part to confirm.

## 4. Open — to check against the live client

- The final blend (is it texel × 2·tint × light?). Compare a retail
  screenshot of an arena that has light records (e.g. 59 or 45) with a render
  that applies it. `client/arena-mcp` can take the retail screenshot.
- Matching the light keys to elements by (x, y, layer) on arenas 59/45/81
  hits a subset of elements, not all; the rest take the dynamic field only.
  Not yet checked that the subset is exactly the intended one.
- What `ko_1.c` does with the dynamic field (multiply or add), and where the
  scripted lights of an arena are defined.

## Use in this project

- **Retail fidelity** (sprints/S07): `map_gfx.py` could export a per-sprite
  colour (tint × light) and `map_gfx.gd` draw with it as `modulate`. Today
  every element is drawn at full brightness, so our arenas are flatter and
  lighter than retail.
- **1-bit style** (sprints/S04): the light map is a ready-made shadow mask
  per element — data for the soft ambient layer the owner allowed, instead of
  placing lights by hand.
