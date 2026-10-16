# Backlog — cola de trabajo viva

Lo pendiente, sin plazos. Cada sección tiene ya un sprint que la recoge (tabla del
[`README.md`](./README.md)): §1–2 → S07, §4 → S12–S14, §5 (mapas) → S05/S07,
§6 (MCP retail) → fuera de la 1.0, §8 → S03/S16, §9 → S04. Lo que se hace en cada tanda va en su sprint
(`SNN-*.md`, índice en [`README.md`](./README.md)); esto es lo que queda por coger.

Estado al **2026-10-16**. El trabajo FX/`.xps` quedó cerrado (abajo, §6 — referencia).
El cliente Godot ya tiene **lobby + combate nativos, i18n y bug report in-game**
(commit `00b0e33e`, 7 oct). Lo activo ahora: **async PvP** (fases 1–2 hechas, §4) y
la **fidelidad GUI retail** (§1–2). En curso: **mapas de pelea en 1 bit**
([`S04`](./S04-fight-maps-1bit.md), §9).

**Entorno:** desde el 2026-10-16 se desarrolla en Linux x86_64 **sin pantalla**, no en
el Mac. `run_tests.sh` funciona en los dos ([`S03`](./S03-base-linux.md)); las capturas van
a `/tmp`.

Servidor en producción: `140.238.172.196:3000` (Docker en VPS; el 5555 de OCI está bloqueado).
Cliente: `cd godot && godot --path .` (Linux, Godot 4.7.1 en `~/.local/bin`; sin pantalla,
con `xvfb-run -a` delante). En el Mac: `/Applications/Godot.app/Contents/MacOS/Godot --path .`
Cuenta de prueba: `test1` / `dofus`. Log: `/tmp/arena_client.log`.

Rama `main-covaga`; `v2.70` es la base heredada del fork.
`cd server && go build ./...` limpio.
Pruebas del cliente: `cd godot && ./run_tests.sh` (ver
[`S01`](./S01-client-test-net.md) para los dos carriles y por
qué el visual no puede correr en CI).

---

## 1. Flujo actual (post-hall)

`login → creación de coach → lobby nativo + paneles nativos → combate nativo`.

- [x] Hall caminable deprecado — código en `godot/deprecated_hall/` (world_view intacto,
      `.gdignore`, pasos de revival en su README). Live code limpio de hooks (`ae138619`).
- [x] Lobby shell nativo `src/ui/lobby_screen.gd` (bajo `$UI`, inmune a cámara) — `4a837ac5`.
- [x] Chrome retail en diálogos XML — fallback appSkin `windowBorder`/`windowTitleBackground`/
      `BtnClose*` en `theme.gd`/`widget.gd` (`637f58ed`).
- [x] **HUD de combate nativo** — `fight_view.gd/.tscn` con el tema oliva/oro del lobby;
      los tres diálogos XULOR2 legacy ya no se montan (B-171). Los handlers de movimiento,
      lanzamiento, turno y acuse siguen siendo la vía de acción.
- [x] **i18n es/en/fr** — `src/i18n/i18n.gd` + `assets/i18n/ui_*.json` (720 líneas cada uno),
      consumido por los 9 scripts de UI y por el debrief de combate (B-172).
- [x] **Bug report in-game** — `src/ui/bug_report.gd` (con captura previa a abrir el diálogo),
      endpoint `internal/web/handlers_bugreport.go` + `webhook.go` con tests.
- [x] **Navegación por teclado** — foco visible en controles horneados, orden de tabulación en
      login, foco modal y restauración en combate (B-171/B-172).
- [x] **Validación visual** — escenas de QA en ventana: `test/ui_review_preview.tscn` cubre
      login, creación, lobby, las veinte rutas de panel nativo y el bug report;
      `test/fight_ui_preview.tscn` cubre un turno poblado y el resultado de victoria.
      Ambas a 1280×720 y 800×600, comprobando foco y límites de viewport.
- [ ] Pasada de fidelidad del lobby vs retail: `lobby_bg.png`, cluster de acciones, iconos
      derechos (Phase 2 = chrome, ya hecha).
- [ ] Warnings cosméticos de anchors — salen de `login_screen.gd:166` **y**
      `creation_screen.gd:241` (4 en total, no rompen nada). Son los que
      quedan visibles en el log ahora que los ~60 de `will not work on export`
      desaparecieron con B-173.

## 2. Pendientes GUI (fidelidad retail)

- [ ] Diálogos que sigan viéndose beige plano → auditar qué refs del theme no resuelven
      (script headless que liste `border`/`bg`/`font`/`color`/`texture` sin target) y
      mapear a `appSkin`/atlases.
- [ ] Estados de widget (hover/pressed/disabled) — comprobar que cambian la región del atlas.
- [ ] `teamManagementDialog` roster/presets — revisión visual.
- [ ] Fuentes: retail usaba DDS bitmap; hoy TTF fallback (`assets/gui/fonts/*.TTF`).
      Aceptable salvo que se quiera pixel-perfect.

## 3. Protocolo propio (Godot-only)

Patrón establecido: opcodes ≥60000 que el cliente retail nunca envía, así que nunca ve
las respuestas.

- [x] `60000`/`60001` client-config — `internal/game/handlers_clientconfig.go`,
      `internal/config/config.template.yaml`.
- [x] `4521`/`4522` facing en placement (B-170) — `direction_test.go`, `src/util/direction8.gd`.

## 4. Async PvP — fases 1–2 hechas

**[`godot/ASYNC-PVP.md`](../godot/ASYNC-PVP.md)**: ghost teams + gambits tipo FFXII, combate
determinista, opcodes `60010`–`60014`, 5 fases. El doc lleva el detalle de cada fase hecha.

- [x] **Fase 1 — determinismo** — seed por combate en el struct `Fight` (asignado en
      `FightManager.Create`) + log de decisiones por turno en los puntos de acción
      (`fightseed.go`, `fightlog.go`, `determinism_test.go`). De paso, B-176. `5bd7427a`.
      No cubre: `pickArenaSeating` (rand global), drops post-combate y `applyTiredness`
      (reloj) — la fase 3 tiene que guardar el id de arena junto al seed.
- [x] **Fase 2 — motor de gambits** sobre `runAITurn`, `classifyAI` como fallback,
      vocabulario v1 cerrado y versionado (`gambit.go`, `gambit_eval.go`, 15 tests). `8220cac4`.
- [ ] Fase 3 — tabla `ghost_teams` + opcodes, visible solo a admin al principio.
- [ ] Fase 4 — cliente: panel de gestión de ghosts (el editor de reglas es la parte dura
      de UX), entrada "Fight a ghost", pestaña de ladder.
- [ ] Fase 5 — ghosts de relleno en `data-dist/` + ladder offline, política de recompensas.

Preguntas abiertas del doc: recompensa por victoria contra ghost; si el Elo de ghost decae;
restricciones móviles del editor de reglas.

## 5. Ideas / para tu server Dofus

- [x] **Exportador de islas** — `godot/tools/export_islands.gd`, offline, desde los jars
      versionados de `server/data-dist/maps/`. 42 islas, 4,5 MB, salida idéntica entre
      corridas. Dos correcciones a lo que decía esta línea antes:
      - **No son 34 islas, son 42** (23–35, 37, 78–80, 85–109). Hay 114 jars de topología
        y nada en los datos dice cuáles son islas, así que el exportador clasifica: es isla
        si no trae mapa de combate y tiene al menos una celda con suelo. Quedan fuera 40
        arenas y 4 ids sin suelo, con el motivo anotado por id en `index.json`. Algunas de
        las 42 son muñones (la 29 tiene 29 celdas; 30–33 son salas sueltas), y el índice
        lleva los tamaños para filtrar. De dónde salía el 34 no se pudo reproducir.
      - **Los elementos NO necesitan servidor.** Están offline en
        `data-dist/maps/env/<id>.jar` y `server/cmd/genelements` ya los decodifica. Añadir
        la clave `elements` — y `zones`, que `topology.gd` no conoce y que casi seguro son
        los disparadores de tipo 8, o sea elementos — es un follow-up barato, no algo
        bloqueado.
- [x] Exportador completo salvo la imagen: `elements` y `zones` ya salen de
      `env/<id>.jar`, offline, con el decodificado cruzado contra `cmd/dumpelements`
      en las 42 islas (188 elementos, 0 discrepancias de campo). Las **zonas son los
      elementos de tipo 8**, confirmado — y tienen huella real: las 38 rutas de los
      datos retail pertenecen a los 9 disparadores de zona, y el decodificador Go las
      descarta. La del mundo 37 cubre 15 celdas.
- [ ] `mapNN.png` de overview — lo único que falta, y necesita `assets/mapgfx/`
      (gitignored, por eso no se emite en blanco; `index.json` lista `not_exported`).
- [ ] Si se quiere navegación tipo retail sin caminar: `mapDialog` + pines clicables sobre el
      overview (zaap → destinos, card master → tienda). El modelo ya se empuja en
      `_push_map_model`.

## 6. Hecho — FX / pipeline `.xps` (referencia)

Cerrado 2026-10-03/04: decoder `.xps` 364/364 (`0x5001`), `spell_fx.json` 116 spells
(mini-evaluador Lua), tweens balísticos, ids por dirección, multi-emitter, `Rebound`,
keyframed (`Deformer`/`LinearForce`), `DirectionFollower`, auditoría de texturas
(0 faltantes en spells), `81.xps` = dato muerto de retail. Commits `682e8ba5` y posteriores.

**Regenerar assets** tras tocar importadores (artefactos en `godot/assets/gamedata/` y
`godot/assets/fx/`, gitignored):

```bash
cd server && go run ./cmd/dumpspells ../server/data-dist /tmp/spells_raw.json
cd ..
python3 tools/asset-import/xps_dump.py \
  client/compiled/game/contents/sfx.jar \
  godot/assets/gamedata/xps godot/assets/fx \
  godot/assets/gamedata/xps_index.json
python3 tools/asset-import/spell_sounds.py /tmp/spells_raw.json \
  client/compiled/game/contents/data.jar client/compiled/game/contents/sounds.jar \
  godot/assets/gamedata/spell_sfx.json godot/assets/sounds \
  godot/assets/gamedata/anm_scripts.json godot/assets/gamedata/spell_fx.json
python3 tools/asset-import/test_xps.py   # esperado: 364/364 full, 1 legacy
```

- [ ] **Validación MCP vs cliente retail — estaba bloqueada en macOS arm64**
      (verificado 2026-10-03): `client/compiled` local carece de `lib/`+natives; el display
      exige JOGL 1.x (`GLCanvas`, sin natives arm64). Caminos: Windows real/VM ARM con el
      bundle win32, o shim `javax.media.opengl`→JogAmp 2.x (trabajo grande).
      Detalle en `server/docs/CLIENT-TESTING.md`.
      **En Linux x86_64 deja de estar bloqueada en principio**: JOGL 1.x sí tiene natives
      para esta plataforma. Falta traer `compiled/lib/` (con natives Linux) y el JRE; aquí
      solo está `compiled/game/`. Sin probar.

## 7. Convención de limpieza

- Matar Godot tras probar: `pkill -f "Contents/MacOS/Godot --path \."` — el argv real no
  lleva la ruta. Para los dos sistemas: `pkill -f "^[^ ]*[Gg]odot[^ /]* --path \."`, el mismo patrón
  que usa `run_tests.sh`, anclado al inicio para no matar a una shell cuyo texto lo contenga.
- Solo `godot/` se toca para GUI; protocolo sagrado; XMLs retail no se editan (se arregla
  el intérprete).

## 8. Tooling y CI

- [ ] **Hacer que la CI se dispare con los pushes** — bloqueante. Solo hay una
      ejecución en todo el repo, lanzada a mano; ningún push lanza `ci.yml`. Mirar
      *Actions* → habilitar workflows en el fork (detalle en [`S02`](./S02-studio-tooling.md)).
- [x] Studio frontend con pnpm + oxlint + oxfmt + knip + lane de CI — [`S02`](./S02-studio-tooling.md).
- [ ] **Decidir: ¿JS en el portal web?** HTMX en el panel de bug reports exige
      `script-src 'self'` y romper el invariante que fija `security_headers_test.go`
      (sin scripts → XSS almacenado inexplotable). Alternativa sin JS: mejorar el
      panel con formularios y GET normales.
- [ ] Studio: `GetMapGfx` / `GetMapSprites` / `GetMapRender` (Go) no tienen
      consumidor en el frontend desde que knip borró sus envoltorios TS (S02).
      Conectarlos a una vista o borrarlos.
- [ ] (Opcional) `tools/proto-gen/gen_messages.py` es un generador de código, no
      una tarea de datos: según la regla "CLI = Go" iría en `server/cmd/`.
- [ ] (Pregunta) ¿Seguir soportando MySQL y Postgres o quedarse solo con SQLite?
      Hoy hay tres drivers, tres configs y tres compose en `server/deploy/`.

## 9. Estilo visual

- [ ] **Mapas de pelea en 1 bit** (dithering Bayer 8×8 + capas de luz, sobre el arte
      retail) — [`S04`](./S04-fight-maps-1bit.md). Dirección artística del dueño.
- [ ] Decodificar `contents/maps/light/<id>.jar` (datos de luz del retail, 114 jars, sin
      estudiar). Lo necesita S04 para la capa de luces; sirve también al estilo normal.
- Ideas aparcadas (2026-10-16), sin compromiso:
  - **Modo ASCII opcional** (glifos por celda según brillo, con color; variante con
    bordes `/ \ | -`). Como estilo principal se descartó por demasiado de nicho; como
    modo cosmético y material para redes tiene sentido. Mismo enfoque de shader que S04.
  - **N bits** (paleta de 4–16 colores) como variante del shader de S04.
  - **Arte propio en 1 bit** para no depender de Ankama: sería un rebrand, otro proyecto.
  - ASCILINE (https://github.com/YusufB5/ASCILINE) mirado y descartado: es un motor de
    vídeo a ASCII, no de juego.
