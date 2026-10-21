# S07 — Fidelidad GUI retail

**Planificado:** 2026-10-16 · **Hito:** M2 — Identidad visual · **Tamaño:** M · **Estado:** 🟡 siguiente (esbozo revisado el 2026-10-21)

## Objetivo

Cerrar las secciones §1–2 de `BACKLOG.md` y cubrir los diálogos retail que hoy
no tienen equivalente nativo.

## Revisión al cerrar S06 (2026-10-21)

S18 sustituyó todos los diálogos retail que el jugador veía fuera del combate
por paneles nativos, y el dueño decidió que los diálogos XML del retail son
legado. Eso deja sin objeto la parte de "fidelidad" del esbozo: el theme sin
destino, los estados del atlas, `teamManagementDialog` y las fuentes DDS
(abajo, tachadas). Lo que queda es **cubrir con paneles nativos lo que el
retail tenía y aquí falta** (la lista de diálogos sin referencia sigue sin
ninguna en `src/`, comprobado), el color de los mapas y los restos de
"También". Se detalla al abrirlo.

## Del backlog

- ~~Pasada de fidelidad del lobby frente al retail: `lobby_bg.png`, el grupo de
      acciones y los iconos de la derecha.~~ (lobby nuevo en S18)
- ~~Diálogos que se ven beige plano: script headless que liste las referencias
      del theme sin destino y mapearlas a `appSkin`/atlases.~~ (sin objeto tras S18)
- ~~Estados hover/pressed/disabled: que cambien la región del atlas.~~ (sin objeto tras S18)
- ~~`teamManagementDialog` (roster y presets): revisión visual.~~ (panel nativo de S18)
- [ ] Los 4 warnings de anchors (`login_screen.gd`, `creation_screen.gd`).
- ~~Fuentes: hoy TTF en lugar de las DDS bitmap del retail. Decidir si vale la
      pena el pixel-perfect.~~ (sin objeto tras S18)

## Diálogos retail sin referencia en `src/`

Encontrados buscando su nombre como texto. Algunos pueden tener ya un sustituto
nativo con otro nombre, así que lo primero es confirmarlo.

- Combate: `fightPresentation`, `fightPlacement`, `fightEventCards`,
  `fightObservation`, `fighterInformations`.
- Progreso: `coachLevelUp`, `unlockedColors`.
- Otros: `chatFilter`, `teamLoad`/`teamList`, `progressDialog`,
  `splitCardMasterTrade`/`splitDemonAffiliationTrade`.
- Los de torneos van en S09; los de replays, en S11; los tutoriales, en S10.

## También

- [ ] **Color de los mapas** (visto 2026-10-17, S04): el retail tiñe cada
      elemento del mapa (tinte por elemento en `gfx/*.jar`, 70 % de los
      elementos de arena, y sombreado horneado en `light/*.jar`) y nuestro
      `map_gfx` lo ignora, así que las arenas salen más planas y claras.
      Formato en [`client/analysis/MAP-LIGHT.md`](../client/analysis/MAP-LIGHT.md);
      falta confirmar la mezcla final (¿texel × 2·tinte × luz?) contra una
      captura del cliente retail y exportar el color por sprite.

- [ ] El arte de las pantallas lleva letras en español horneadas: hacen falta
      variantes en/fr (`godot/DESIGN.md`).
- [ ] El nivel de coach siempre sale 0 (`DESIGN.md`, "Current data limits").
- [ ] `fight_view.gd`: `_mount_fight_hud` es código muerto.
- [ ] **Card Master** (visto en S05, 2026-10-17): el `cardMasterDialog` retail
      sale como una ventana beige a pantalla completa con las categorías del
      tomo a la derecha. Ya era así antes de S05; hasta S05 además salía sin
      cartas (bug del modelo, arreglado). Captura en el Samba:
      `codigo/capturas/s05/cardmaster-25.png`.
- [ ] Card Masters de **modo 1** (variante "démone II": Totem Arena 101 y los
      del mundo 80): el cliente abre siempre `cardMasterDialog`; el retail
      tiene `demonIIDialog` para ese modo.
- [ ] `useSpecialCard` para cartas de título (tipo 28 → 22093) y Dofus
      (tipo 30 → 22097): sin conectar (visto en S05).
- [ ] Nombres de gamedata en inglés mezclados con la UI en español (NPCs,
      cartas Zaap, demonios del panel "Ciudad" de S05): los JSON se exportan
      en un solo idioma.

## Criterio de cierre

`BACKLOG.md` §1–2 vacías; cada diálogo de la lista cubierto o descartado por
escrito; capturas de antes y después en el *Resultado*.
