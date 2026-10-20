# Devlog

El diario de Claude (el agente) en este repo. Una entrada por sesión:
`AAAA-MM-DD-slug.md`.

No sustituye a nada:

- **qué queda por hacer** → [`sprints/BACKLOG.md`](../sprints/BACKLOG.md)
- **qué se hizo en un sprint, con evidencia** → `sprints/SNN-*.md`
- **bugs** → [`server/docs/BUGS.md`](../server/docs/BUGS.md)

Aquí va lo que no cabe en esos sitios: qué se pidió en la sesión, qué se hizo,
qué se encontró por el camino, qué quedó sin verificar y por qué. Va escrito
para que la siguiente sesión arranque sin tener que redescubrirlo.

## Reglas

- Cada entrada separa lo **verificado** (con el comando que lo demuestra) de lo
  **no verificado**. Si algo no se pudo correr, se dice.
- Las entradas no se reescriben. Si una resulta estar mal, se corrige en una
  entrada nueva que enlaza a la vieja.
- Corta. Si una entrada pasa de una pantalla, lo que sobra seguramente es un
  sprint o un bug.

## Entradas

| Fecha | Entrada |
|---|---|
| 2026-10-16 | [Reorganización de docs: fuera el roadmap heredado, `pendiente/` → `sprints/`](./2026-10-16-docs-reorg.md) |
| 2026-10-16 | [Permisos del checkout + S02 (tooling del studio)](./2026-10-16-s02-studio-tooling.md) |
| 2026-10-16 | [Estado de los assets y estilo 1 bit para los mapas de pelea + hoja de ruta S03–S16](./2026-10-16-estilo-1bit.md) |
| 2026-10-16 | [S03 (base Linux) y S04 (combate en 1 bit), S17 abierto](./2026-10-16-s03-s04.md) |
| 2026-10-17 | [S17: HUD de combate estilo Krosmaster (cartas, medallión, banner)](./2026-10-17-s17-hud.md) |
| 2026-10-17 | [S05: el panel "Ciudad" (servicios del hall + Zaap) y tres bugs de la capa GUI](./2026-10-17-s05-ciudad.md) |
| 2026-10-17 | [S18 tanda 2: Card Master y buzón nativos, arte y muñeco en 1 bit](./2026-10-17-s18-tanda2.md) |
| 2026-10-18 | [S18 tanda 2: el altar de fusión nativo](./2026-10-18-s18-altar.md) |
| 2026-10-20 | [Puesta a punto del entorno en la ROG Ally (Go, Godot, baterías)](./2026-10-20-ally-setup.md) |
| 2026-10-20 | [S18: los caídos en el panel de Equipo (adiós al cementerio) y "Ciudad" → "Servicios"](./2026-10-20-s18-caidos.md) |
| 2026-10-20 | [S18: tirada fallida, banquillo lleno y sin scroll en "Caídos", probados](./2026-10-20-s18-caidos-bordes.md) |
| 2026-10-20 | [B-177: el servidor ya no gasta equipo como carta de resurrección](./2026-10-20-b177-resurreccion-equipo.md) |
| 2026-10-20 | [S18: las conversaciones en una ventana nativa y en español](./2026-10-20-s18-conversaciones.md) |
| 2026-10-20 | [S18: tótems al Calendario y al Clan, fuegos artificiales en el lobby](./2026-10-20-s18-totems-fuegos.md) |
| 2026-10-20 | [S18: informe de combate nativo y la vuelta del combate (B-178)](./2026-10-20-s18-informe-combate.md) |
