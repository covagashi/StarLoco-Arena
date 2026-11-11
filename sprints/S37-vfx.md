# S37 — Efectos (VFX)

**Planificado:** 2026-10-25 · **Hito:** M7 — Arte propio · **Tamaño:** M · **Estado:** ⚪ esbozo

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

## Criterio de cierre

Cada hechizo de las 12 clases se ve con un efecto de la librería; `XpsFx`
retail ya no se usa.
