# S06 — Opciones, música y volúmenes

**Planificado:** 2026-10-16 · **Hito:** M1 — Jugable de punta a punta · **Tamaño:** S · **Estado:** ⚪ esbozo

## Objetivo

Que cada opción del panel haga lo que dice, y que el juego suene: hoy solo hay
efectos de combate.

## Punto de partida (de una lectura del código, sin probar)

- Handlers de opciones que no hacen nada (`main.gd`): ratón invertido, rango de
  movimiento, guardar replay, ocultar mundo, rejilla, partículas, shaders. Solo
  se aplican vsync, pantalla completa y resolución.
- **No hay música**: no se encontró reproducción de música en ningún sitio.
- `_apply_audio_prefs` solo lee los ajustes de música; el volumen de efectos se
  ignora.
- No hay `default_bus_layout.tres`: probablemente no existe el bus "Music" y el
  código cae al bus 0 (Master), así que el control de música movería el volumen
  general.

## Tareas candidatas

- [ ] Layout de buses de audio (Master / Music / SFX) y los dos volúmenes.
- [ ] Música: extraer `musics.jar` (importador nuevo) y reproducirla por
      pantalla (login, lobby, combate), como el retail.
- [ ] Cada opción del panel: implementarla o quitarla del panel, por escrito.
- [ ] Rejilla y partículas: encajan con el filtro de S04 (activar o desactivar
      capas).
- [ ] `playBark` / `playGroundSound` (scripts de animación que hoy se ignoran).

## Criterio de cierre

Ninguna opción visible es un no-op. Música y efectos tienen volumen propio y se
guardan entre sesiones.
