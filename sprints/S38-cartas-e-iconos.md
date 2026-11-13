# S38 — Cartas, iconos e interfaz

**Planificado:** 2026-10-25 · **Hito:** M7 — Arte propio · **Tamaño:** L · **Estado:** 🔵 en curso (retratos hechos, 2026-11-13)

## Alcance

- Ilustraciones de carta: hoy ~960 (equipo del coach y del luchador). No se
  pueden dibujar una a una: plantilla de carta (marco por tipo y rareza) +
  ilustración por **familia** o por set, iconos por slot, y solo arte propio
  para las especiales.
- Iconos de hechizo (167), de equipo de luchador (151), de logros, de fichas
  y pesetas, de clases (timeline y retratos).
- **Retratos del combate desde la figura 3D** (dueño, 2026-11-11: "en el
  círculo del pj actual aún sale el retail, y en las cartitas de los turnos
  también"): el medallón del luchador activo y las cartas de la línea de
  turnos, renderizados del modelo 3D de cada clase/sexo e invocación (cabeza
  y hombros, con la luz del juego), no los PNG retail
  (`gui/images/...`).
- Retratos de NPC (Nilo, Aldebrán, Demonio I) y de los Señores del Tiempo.
- Fuentes propias o libres (hoy Copperplate y Tahoma retail).
- Lo que queda de imágenes retail en los paneles nativos.

## Criterio de cierre

Ningún panel muestra una imagen retail; `gui/` retail se puede borrar.

## Desde S45 (2026-11-12)

Las fuentes y el material de la interfaz van en S45 (Lilita One + Nunito,
tinta, cintas, papel). Aquí, las cartas y los iconos se dibujan ya con ese
estilo: borde de tinta y sombra dura.

## Progreso

### Retratos del combate ✅ (2026-11-13)

`tools/portraits/portraits.tscn` renderiza cada figura 3D (24 luchadores, los
2 coaches y las 9 invocaciones) sobre fondo transparente, busca su contorno
y corta un cuadrado: cabeza y hombros en los humanoides, el cuerpo entero en
las invocaciones. Salen 35 PNG de 160 px (1,1 MB) en
`godot/assets/ui/portraits/`, con su fila en `art/CREDITS.md`.
`FighterCard.portrait_for()` los lee antes que el arte retail, así que el
medallón del luchador activo y la línea de turnos ya no enseñan el retail
(lo que pidió el dueño el 2026-11-11). Un coach en combate (raza 7000/7001)
también tiene el suyo.
Evidencia: `fight_ui_preview` a 1280×720 con los retratos nuevos;
`run_tests.sh --headless` 1525/0; `tools/art/check.py` 0 fallos.

Siguiente: los iconos de hechizo (167) en el estilo B, y después los de equipo
del luchador, logros y fichas; luego la plantilla de carta por familia.
