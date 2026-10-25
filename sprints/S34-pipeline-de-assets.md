# S34 — Pipeline de assets nuevo

**Planificado:** 2026-10-25 · **Hito:** M7 — Arte propio · **Tamaño:** M · **Estado:** ⚪ esbozo (tras S33)

## Objetivo

Del archivo fuente al juego en un comando, con el arte propio **dentro del
repo o en un repo de arte**, no generado desde nada ajeno.

## Tareas candidatas

- Estructura de fuentes (`art/`: `.blend` / `.kra` / `.aseprite` / `.tscn`)
  y de exportados (`godot/assets/`), con nombres fijos por clase, animación,
  arena y efecto.
- Exportación automática (Blender CLI o el exportador del editor elegido) y
  comprobaciones: nombres, pivotes, escala, presupuesto de polígonos o de
  textura, peso total.
- Git para el arte: ¿LFS? (hoy está prohibido, AGENTS.md) o repo aparte.
- Licencias: todo propio o con licencia compatible, con una lista de
  procedencias (`art/CREDITS.md`).
- La capa del cliente que lee el arte nuevo (sustituye a AnmSprite, MapGfx y
  XpsFx a medida que llegan S35–S37), con una opción para jugar con el
  arte viejo mientras convivan.
- La lista de capturas automáticas por asset, para revisarlo en hojas (como
  en `art-iteration-workflow`).

## Criterio de cierre

Un asset de prueba sale de su fuente, pasa las comprobaciones y se ve en el
juego con un solo comando; documentado en AGENTS.md.
