# S15 — Empaquetado del cliente

**Planificado:** 2026-10-16 · **Hito:** M5 — Release 1.0 · **Tamaño:** L · **Estado:** 🟡 abierto (2026-10-24, tras M6)

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

## Plan (2026-10-24)

El dueño: "sigue con los sprints". Orden por lo que desbloquea:

1. **Generador de assets en un comando** (`tools/make_assets.sh`): sin él,
   un jugador no puede montar el cliente. Lo verifica un agente contra los
   assets actuales, sin tocarlos.
2. **Presets de Linux y Windows**, con exportación real en Linux y prueba del
   ejecutable exportado contra el servidor local. Windows: el `.exe` se
   construye; ejecutarlo necesita una máquina Windows.
3. **Peso de `anims/`:** atlas por animación en vez de PNG sueltos. Es el
   cambio más grande (afecta a `AnmSprite`), así que va después.
4. **CI** que exporte: espera al dueño (S03, el GitHub del dueño tiene
   límites).
5. **Cliente en la release** junto al servidor: con S16.

## Decisiones

| Fecha | Decisión | Quién |
|---|---|---|
| 2026-10-24 | El ejecutable se llama **PippopArena** (`.x86_64`, `.exe`) y el producto, "Pippop Arena": es el nombre que el dueño quiere que vean los jugadores | delegada |
| 2026-10-24 | `assets/` sigue suelta junto al ejecutable, como en macOS: no son recursos de Godot | heredada |

## Resultado (en curso)

### Bloque B — exportar en Linux y Windows (2026-10-24)

- Presets **Linux** (`dist/linux/PippopArena.x86_64`) y **Windows**
  (`dist/windows/PippopArena.exe`) en `export_presets.cfg`, con las mismas
  reglas que macOS: `assets/` suelta junto al ejecutable, sin `test/` ni
  `tools/`, y el `.pck` aparte.
- Las plantillas 4.7.1 de Linux y Windows están instaladas en
  `~/.local/share/godot/export_templates/4.7.1.stable` (del `.tpz` oficial;
  la de macOS no se guardó).
- **El ejecutable de Linux, probado de verdad** (xvfb + `xdotool`, contra el
  servidor local, con `assets` enlazada junto al binario):
  - arranca en el login, con fuentes, fondo y textos;
  - entra con `test` y enseña el hub;
  - "Entrenamiento" abre un combate (arena 21, colocación).

  Capturas en `~/codigo/capturas/s15/` (`export_login`, `export_lobby`,
  `export_fight`).
- **Windows:** el `.exe` se construye (104 MB más el `.pck`). Probarlo
  necesita una máquina Windows; no hay wine en la Ally.
- **Fallo encontrado con la prueba (de S21):** "Entrenamiento" lanza el
  desafío 34, que S21 hizo primer combate del capítulo 2 de Historia. Sin
  haberlo ganado, un entrenamiento contaba como Historia: XP, heridas y
  muerte.
  - Arreglo: un marcador de lanzamiento solo de Godot, **98**, que nunca es
    Historia (`challengePractice`). El 99 del retail no cambia.
  - Evidencia: `TestPracticeLaunchIsNeverStory`; en vivo, `native_lobby`
    28 PASS y el log `challenge=34 … story=false`.

## Criterio de cierre

En una máquina limpia de cada plataforma: descargar la release, generar assets
desde un cliente retail, entrar y jugar un combate. Una captura por plataforma.
