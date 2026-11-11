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
  color, S35c): "poner vfx al pelo me parece bien". Efectos sobre el pelo
  del coach (por aclarar con el dueño: ¿brillo o partículas, quizá como
  cosmético de S30, o que el pelo se mueva?).

## Criterio de cierre

Cada hechizo de las 12 clases se ve con un efecto de la librería; `XpsFx`
retail ya no se usa.
