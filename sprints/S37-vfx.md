# S37 — Efectos (VFX)

**Planificado:** 2026-10-25 · **Hito:** M7 — Arte propio · **Tamaño:** M · **Estado:** 🟡 en curso (desde 2026-11-12)

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

Pendiente: la opinión del dueño sobre la hoja; luego, conectar la librería
al combate en lugar de `XpsFx` (zona real del hechizo, anillos detrás de
las figuras) y los efectos especiales de prendas y pelo.

## Criterio de cierre

Cada hechizo de las 12 clases se ve con un efecto de la librería; `XpsFx`
retail ya no se usa.
