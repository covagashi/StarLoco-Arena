# S15 — Empaquetado del cliente

**Planificado:** 2026-10-16 · **Hito:** M5 — Release 1.0 · **Tamaño:** L · **Estado:** ⚪ esbozo

## Objetivo

Que un jugador pueda instalar el cliente Godot en Linux, Windows o macOS y
generar sus assets sin saber qué es Python.

## Punto de partida

- `export_presets.cfg` solo tiene **macOS**. No hay presets de Windows ni de
  Linux, ni ningún job de CI que exporte.
- Los assets van como **carpeta suelta** junto al ejecutable (no van en el
  `.pck`; `asset_paths.gd` los busca ahí). El último build local de macOS pesa
  **5,8 GB de assets**, frente a 3,2 GB en `godot/assets/`.
- Los assets salen del cliente retail **del propio jugador** (no se
  redistribuyen). Generarlos hoy son unos 15 scripts Python más varios
  `server/cmd/dump*`, con instrucciones repartidas entre `godot/README.md` y
  `BACKLOG.md`.

## Tareas candidatas

- [ ] Presets de Linux y Windows; revisar el de macOS (firma, notarización).
- [ ] **Generador de assets para el jugador:** un solo comando (o un binario Go)
      que, dada la carpeta de su cliente retail, genere `assets/` completo. Esto
      sirve también para la regeneración en desarrollo.
- [ ] **Peso:** `anims/` son 312.121 PNG sueltos (2,9 GB). Empaquetar cada
      animación como spritesheet o atlas, como ya se hace en `mapgfx`.
- [ ] Averiguar por qué el build de macOS duplica el tamaño de los assets.
- [ ] Job de CI que exporte las tres plataformas (sin assets).
- [ ] El cliente en la release, junto al servidor (hoy GoReleaser solo publica
      el servidor).

## Criterio de cierre

En una máquina limpia de cada plataforma: descargar la release, generar assets
desde un cliente retail, entrar y jugar un combate. Una captura por plataforma.
