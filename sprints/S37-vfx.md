# S37 — Efectos (VFX)

**Planificado:** 2026-10-25 · **Hito:** M7 — Arte propio · **Tamaño:** M · **Estado:** ✅ cerrado 2026-11-12

## Alcance

- Una librería de efectos en tiempo real (partículas y shaders) por
  **elemento** y por **forma**: proyectil, impacto, área, aura/buff,
  invocación, trampa, curación, teletransporte. Variantes por color y escala.
- Cada hechizo se describe con datos (forma + elemento + intensidad), no con
  una animación propia: sustituye a los 182 efectos `.xps` de hoy y a los
  gestos por hechizo que no casaban de nombre (S31).
- Feedback del combate: números de daño, golpes, muerte, cámara (S24).

## Notas del dueño

- 2026-11-11, tras decidir que los peinados del coach no cambian (solo el
  color, S35c): "poner vfx al pelo me parece bien"; "lo que tú decidas".
  **Decidido:** un efecto sobre el pelo (brillo, chispas o llamas que suben
  del pelo, en el color del elemento), hecho con esta librería y vendido
  como cosmético de S30 (pelo de fuego, de escarcha…). La zona del pelo sale
  de la máscara de S35 (canal G de `coach_700X_mask.png`). Que el pelo se
  mueva queda fuera: va fundido en la malla de Meshy, y moverlo pediría el
  pelo como pieza aparte, lo que el dueño descartó en S35c.

## Desde S35c (2026-11-12)

Dueño, sobre el volumen de las prendas del coach: "ok hazlo como tú dices".
Lo sólido (cuernos, pinchos, pelo, burbujas grandes) va como pieza rígida en
S35c; aquí, solo unas pocas piezas especiales donde "estar vivo" es la
gracia, y barato (en la demo web cuentan los móviles de 2 GB):
- Pantalón de gelatina (carta 126): que tiemble al andar, con un shader de
  vértices en la propia prenda (sin piezas nuevas).
- Espinilleras del Superjefe (862): un brillo del oro.
- Aurea flamma (estandarte del coach): la llama.
Cualquier otra que salga al hacer las prendas se apunta aquí.

## Paso 1 — la librería (2026-11-12)

- Receta por hechizo, sacada de sus efectos (`server/cmd/dumpspells/vfx.go`,
  campo `fx` de `spells.json`): forma, elemento del primer efecto que daña,
  intensidad 1–3 por coste de PA y tamaño de zona. Los 120 hechizos de las
  12 clases: 35 aura, 24 proyectil, 14 zona, 10 golpe, 10 maldición,
  10 invocación, 8 curación, 7 teletransporte, 2 trampa.
  Decidido: "maldición" (partículas que se hunden) aparte del aura, para
  que un robo de PA no parezca un buff.
- `godot/src/fx/vfx.gd`: las 9 formas × 5 elementos (neutro, fuego, tierra,
  agua, aire), todo dibujado en código (CPUParticles2D + anillos con
  `_draw`), sin imágenes: corre en Compatibility y en la demo web.
  Fuego sube, tierra cae en trozos con polvo, agua gotea, aire gira.
- Hoja: `godot/tools/fx/vfx_sheet.sh` → `~/codigo/capturas/s37/v1.mp4`
  (rejilla en bucle) y `v1-<n>-<forma>.png` (una página por forma, una fila
  por elemento, siete momentos).
- `test/unit/vfx_test.gd`: cada forma × elemento se crea y se libera.

Dueño, 2026-11-12, sobre la hoja: "me gustan, confío en tu criterio".

## Paso 2 — en el combate (2026-11-12)

- `fight_view._cast_fx` dibuja la receta del hechizo sobre su zona real
  (`zn` + `Areas.footprint_cells`, la misma que la vista previa de AoE).
  Anillos, glifos y polvo van en `FxGround`, bajo las figuras; el resto,
  por encima de todas (z 4000).
- El golpe cuerpo a cuerpo (8112) lleva un `hit` neutro (intensidad 2 si
  es crítico).
- `XpsFx` (`src/anims/xps_fx.gd`) y la lectura de `spell_fx.json` borrados:
  ningún efecto retail queda en el combate.
- `fight_smoke -- --fx-shots=<dir>` fotografía cada hechizo y golpe.
- Visto en un combate real IA contra IA (arena 36, nieve) renderizado con
  `make_reel.sh` → `~/codigo/capturas/s37/combate.mp4`. **Decidido** tras
  verlo: sobre la nieve los efectos aditivos se perdían; las partículas
  pasan a mezcla normal con colores saturados (solo destellos y el brillo
  del proyectil suman luz) y los anillos llevan un borde oscuro debajo.
  `vfx_sheet.sh --floor=snow` (hoja `v2-nieve`) lo comprueba; `v2` en piedra.
- `make_reel.sh` y `vfx_sheet.sh` usan gamescope headless (la GPU del Ally)
  si está; xvfb con llvmpipe iba a ~3 s por fotograma en la arena 3D.

## Paso 3 — prendas vivas (2026-11-12)

En el shader toon (`toon.gdshaderinc` + `live.gdshaderinc`, también en el
contorno), parámetros a 0 salvo en las piezas de `Fighter3D.LIVE`:
- Gelatina (pantalón 126, y también torso, botas y gorro de gelatina —
  **decidido**: mismo set, mismo temblor): tiembla solo hacia fuera; hacia
  dentro dejaba asomar la piel por la prenda.
- Superjefe (862): una franja de brillo recorre los texeles dorados.
- Aurea flamma (53): el emblema de la llama parpadea y brilla, y diez
  chispas 3D suben del banderín.
Visto con `anim_sheet.gd` a varios zooms.

## Paso 4 — efectos de pelo, cosmético (2026-11-12)

Dueño: "ok haz eso del S37". La tienda de S30 no existe todavía, así que el
cosmético se hace entero salvo la venta:
- Servidor (`game/cosmetics.go`): cuatro efectos (1 fuego, 2 escarcha,
  3 tormenta, 4 dorado). Lo que tiene cada coach en `coach_cosmetics`; el
  que lleva, en `coaches.hair_fx` (migración 19). 60042 lo cambia (solo uno
  que tenga, o 0), 60043 lo cuenta (va con cada 60001); el 60040 del combate
  lleva el de cada coach. `/COSMETIC <coach> <id>` lo da mientras no hay
  tienda.
- Cliente: `Fighter3D.HAIR_FX` / `hair_fx()`: el pelo (canal G de la
  máscara) toma el color del efecto y brilla un poco, y unas partículas
  salen de la cabeza (llamas que suben, copos, chispas, destellos).
  **Decidido**: teñir y no solo sumar luz, porque un pelo blanco no puede
  brillar más; tormenta en azul eléctrico para que no se confunda con el
  dorado.
- Panel "Equipo del coach": al elegir la casilla Pelo salen los efectos que
  tiene (y "Ninguno"); un clic lo pone al momento, sin pasar por "Llevar
  puesto". Solo se ve si tiene alguno.
- Hoja: `~/codigo/capturas/s37/pelo.png`; panel: `capturas/s37/panel/coach-hair.png`.

Probado: `go test ./...` (cosmetics_test: equipar sin tenerlo, dar dos
veces, guardar, quitar, 60043 solo al cliente Godot, `/COSMETIC`; 60040
con el efecto); `run_tests.sh --headless` 1463/0. Contra el servidor local
con dos efectos dados en la base (borrados después): `hub_smoke` (el coach
del lobby lo muestra), `fight_smoke` (`COACH HAIR FX test want=1 shown=1`)
y `screens_smoke` (el panel cambia de fuego a escarcha y vuelve; 12/0).
Encontrado por el camino: `_push_local_coach` rehacía `localCoach` y perdía
el efecto; ahora va en el modelo.

Dueño, 2026-11-12, sobre la hoja y el panel: "el pelo ok".

Pendiente en S30: venderlos (precio en pesetas, la tienda).

## Criterio de cierre

Cada hechizo de las 12 clases se ve con un efecto de la librería; `XpsFx`
retail ya no se usa.
