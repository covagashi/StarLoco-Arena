# Pendiente — seguimiento local

Estado al **2026-10-05**. El trabajo FX/`.xps` quedó cerrado (abajo, §4 — referencia).  
Lo activo ahora es el **cliente Godot: lobby + fidelidad GUI**.

Servidor en producción: `140.238.172.196:3000` (Docker en VPS; el 5555 de OCI está bloqueado).  
Cliente: `cd godot && /Applications/Godot.app/Contents/MacOS/Godot --path .`  
Cuenta de prueba: `test1` / `dofus`. Log: `/tmp/arena_client.log`.

---

## 1. Flujo actual (post-hall)

`login → creación de coach → lobby nativo + diálogos XML`.

- [x] Hall caminable deprecado — código en `godot/deprecated_hall/` (world_view intacto, `.gdignore`, pasos de revival en su README). Live code limpio de hooks (`ae138619`).
- [x] Lobby shell nativo `src/ui/lobby_screen.gd` (bajo `$UI`, inmune a cámara) — commit `4a837ac5`.
- [x] Chrome retail en diálogos XML — fallback appSkin `windowBorder`/`windowTitleBackground`/`BtnClose*` en `theme.gd`/`widget.gd` (`637f58ed`).
- [ ] **Validación visual en vivo** del lobby: abrir cada diálogo, comprobar marco/título/cierre, Escape cierra el último, chat funcional con Enter.
- [ ] Pasada de fidelidad del lobby vs retail: `lobby_bg.png`, cluster de acciones, iconos derechos; el prompt completo para agente externo está en el historial (Phase 2 = chrome — ya hecha).
- [ ] Warnings cosméticos de anchors en `login_screen.gd` (no rompen nada).

## 2. Pendientes GUI (fidelidad retail)

- [ ] Diálogos que sigan viéndose beige plano → auditar qué refs del theme no resuelven (script headless que liste `border`/`bg`/`font`/`color`/`texture` sin target) y mapear a `appSkin`/atlases.
- [ ] Estados de widget (hover/pressed/disabled) — comprobar que cambian la región del atlas.
- [ ] `teamManagementDialog` roster/presets — revisión visual.
- [ ] Fuentes: retail usaba DDS bitmap; hoy TTF fallback (`assets/gui/fonts/*.TTF`). Aceptable salvo que se quiera pixel-perfect.

## 3. Ideas / para tu server Dofus

- [ ] **Exportador de islas** (`godot/tools/export_islands.gd` — por hacer): por cada isla (ids 23–109, 34 total) volcar JSON `{cells, layers, elements, zones}` + `mapNN.png` de overview. Materia prima para mapas de eventos. La topología ya está parseada en `src/maps/topology.gd`; los elementos llegan por 200/206 a `State.elements`.
- [ ] Si se quiere navegación tipo retail sin caminar: `mapDialog` + pines clicables sobre el overview (zaap → destinos, card master → tienda). El modelo ya se empuja en `_push_map_model`.

## 4. Hecho — FX / pipeline `.xps` (referencia)

Cerrado 2026-10-03/04: decoder `.xps` 364/364 (`0x5001`), `spell_fx.json` 116 spells (mini-evaluador Lua), tweens balísticos, ids por dirección, multi-emitter, `Rebound`, keyframed (`Deformer`/`LinearForce`), `DirectionFollower`, auditoría de texturas (0 faltantes en spells), `81.xps` = dato muerto de retail. Commits `682e8ba5` y posteriores.

**Regenerar assets** tras tocar importadores (artefactos en `godot/assets/gamedata/` y `godot/assets/fx/`, gitignored):

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

- [ ] **Validación MCP vs cliente retail — sigue bloqueada en macOS arm64** (verificado 2026-10-03): `client/compiled` local carece de `lib/`+natives; el display exige JOGL 1.x (`GLCanvas`, sin natives arm64). Caminos: Windows real/VM ARM con el bundle win32, o shim `javax.media.opengl`→JogAmp 2.x (trabajo grande). Detalle en `server/docs/CLIENT-TESTING.md`.

## 5. Convención de limpieza

- Matar Godot tras probar: `pkill -f "Contents/MacOS/Godot --path \."` — el argv real no lleva la ruta.
- Solo `godot/` se toca para GUI; protocolo sagrado; XMLs retail no se editan (se arregla el intérprete).
