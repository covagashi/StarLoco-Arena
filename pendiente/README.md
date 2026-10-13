# Pendiente — seguimiento local

Estado al **2026-10-13**. El trabajo FX/`.xps` quedó cerrado (abajo, §5 — referencia).
El cliente Godot ya tiene **lobby + combate nativos, i18n y bug report in-game**
(commit `00b0e33e`, 7 oct). Lo activo ahora: **fidelidad GUI retail** y decidir si
se entra en **async PvP** (§4).

Servidor en producción: `140.238.172.196:3000` (Docker en VPS; el 5555 de OCI está bloqueado).
Cliente: `cd godot && /Applications/Godot.app/Contents/MacOS/Godot --path .`
Cuenta de prueba: `test1` / `dofus`. Log: `/tmp/arena_client.log`.

Rama `main-covaga`, 130 commits por delante de `v2.70`.
`cd server && go build ./...` limpio.
Pruebas del cliente: `cd godot && ./run_tests.sh` (ver
[`sprints/S01`](../sprints/S01-client-test-net.md) para los dos carriles y por
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

## 4. Async PvP — diseñado, sin implementar

**[`godot/ASYNC-PVP.md`](../godot/ASYNC-PVP.md)**: ghost teams + gambits tipo FFXII, combate
determinista, opcodes `60010`–`60014`, 5 fases. Nada implementado todavía; el doc es para
revisar antes de construir.

- [ ] **Fase 1 — determinismo** (único cambio estructural; el resto depende de él):
      sembrar `f.rng` desde un seed guardado en el registro de combate en lugar de
      `time.Now()` (`internal/game/spell_effects.go:37`), + hook de log por turno
      (turno, luchador, regla disparada / acción). Verificable con tests.
- [ ] Fase 2 — motor de gambits sobre `runAITurn`, con `classifyAI` como fallback.
- [ ] Fase 3 — tabla `ghost_teams` + opcodes, visible solo a admin al principio.
- [ ] Fase 4 — cliente: panel de gestión de ghosts (el editor de reglas es la parte dura
      de UX), entrada "Fight a ghost", pestaña de ladder.
- [ ] Fase 5 — ghosts de relleno en `data-dist/` + ladder offline, política de recompensas.

Preguntas abiertas del doc: recompensa por victoria contra ghost; si el Elo de ghost decae;
restricciones móviles del editor de reglas.

## 5. Ideas / para tu server Dofus

- [ ] **Exportador de islas** (`godot/tools/export_islands.gd` — por hacer; hoy `tools/` solo
      tiene los generadores de fondos `make_*_bg.py`): por cada isla (ids 23–109, 34 total)
      volcar JSON `{cells, layers, elements, zones}` + `mapNN.png` de overview. Materia prima
      para mapas de eventos. La topología ya está parseada en `src/maps/topology.gd`;
      los elementos llegan por 200/206 a `State.elements`.
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

- [ ] **Validación MCP vs cliente retail — sigue bloqueada en macOS arm64**
      (verificado 2026-10-03): `client/compiled` local carece de `lib/`+natives; el display
      exige JOGL 1.x (`GLCanvas`, sin natives arm64). Caminos: Windows real/VM ARM con el
      bundle win32, o shim `javax.media.opengl`→JogAmp 2.x (trabajo grande).
      Detalle en `server/docs/CLIENT-TESTING.md`.

## 7. Convención de limpieza

- Matar Godot tras probar: `pkill -f "Contents/MacOS/Godot --path \."` — el argv real no
  lleva la ruta.
- Solo `godot/` se toca para GUI; protocolo sagrado; XMLs retail no se editan (se arregla
  el intérprete).
