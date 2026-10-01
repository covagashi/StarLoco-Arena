# Pendiente — seguimiento local

Lista de pasos **no bloqueantes** tras cerrar el decoder `.xps` (364/364 `0x5001`) y el wiring Godot (B-167).  
Contexto: [`server/docs/BUGS.md`](../server/docs/BUGS.md) (B-167), [`server/docs/STATUS.md`](../server/docs/STATUS.md) (fila GODOT `.xps`).

**Hecho (referencia):** `xps_dump.py`, `test_xps.py`, `xps_fx.gd`, `_cast_fx` en `8110`, docs, commit `682e8ba5`.

---

## 1. Datos y pipeline (regenerar assets)

Los artefactos viven bajo `godot/assets/gamedata/` y `godot/assets/fx/` (gitignored). Tras cambiar importadores:

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

- [ ] **22 texturas sin PNG:** el dump reporta ~253/275; revisar ids faltantes en `sfx.jar` (`particles/<id>.tga` vs raíz) y si algún spell referencia esos ids.
- [ ] **`81.xps`:** único archivo con prefijo `XPS` + zlib en el jar (no magic `0x5001`). Opciones: reverse del payload post-zlib, comprobar si el retail lo carga aún, o dejar documentado como excluido en `test_xps.py`.

---

## 2. `spell_fx.json` — cobertura script ↔ spell

Hoy ~**100 spells** con filas FX; en scripts hay más referencias a `.xps` (~171 scripts con partículas — cifra de auditoría previa).

- [ ] Auditar gaps: spells con `Particle.addParticleSystem` / `addTweenParticleSystem` en Lua que no aparecen en `spell_fx.json` (`tools/asset-import/spell_sounds.py`, función `script_fx()`).
- [ ] **`addTweenParticleSystem`:** timing tween (duración, easing) no está en el JSON actual; extraer args del script y programar en Godot (no solo burst en `t_ms`).
- [ ] **Coordenadas world:** scripts que pasan `startX` / `destX` (o equivalentes) — anclar FX en celda objetivo, no solo caster/target en `_cast_fx`.
- [ ] Re-ejecutar smokes Godot tras regenerar `spell_fx.json`.

---

## 3. Godot — runtime y opcodes

- [ ] **`8108` (uso de carta):** spawn FX solo si el **script de la carta** (field `script` / Lua) dispara partículas; **no** usar card id como xps id.
- [ ] **Paridad visual (opcional, grande):** portar affectors del JSON (`LinearForce`, `ColorFader`, `Deformer`, sub-emitters, luces) a `xps_fx.gd` o nodos hijos; hoy solo primer emitter + CPUParticles2D aproximado.
- [ ] **Secuencias bitmap:** modelos tag `2` con curva `anim` — usar atlas/celdas UV en Godot si un FX depende de flipbook.

---

## 4. Validación

- [ ] **`displace_smoke`:** requiere servidor Go en `127.0.0.1:5555`; confirmar verde en CI/local.
- [ ] **Cliente retail / MCP:** [`server/docs/CLIENT-TESTING.md`](../server/docs/CLIENT-TESTING.md) — cast con partículas visibles vs Godot (misma spell id / xps id).
- [ ] Tras cada cambio de decoder o FX: `go test ./...` (desde `server/`), smokes `fight_smoke` + `carry_smoke`.

---

## 5. Docs al cerrar cada ítem

Por convención del repo (`AGENTS.md`):

- [ ] Actualizar [`server/docs/STATUS.md`](../server/docs/STATUS.md) (fila GODOT / B-167).
- [ ] Entrada en [`server/docs/DATA-COVERAGE.md`](../server/docs/DATA-COVERAGE.md) si cambia cobertura de datos.
- [ ] Ajustar [`server/docs/BUGS.md`](../server/docs/BUGS.md) (B-167) cuando algo pase de “parcial” a “hecho” o se acote un límite conocido.

---

## Orden sugerido

1. Regenerar assets + cerrar gaps `spell_fx.json` (impacto inmediato en combate).  
2. `8108` + tweens/coords (FX en cartas y proyectiles).  
3. `81.xps` + texturas faltantes (completitud del jar).  
4. Affectors / flipbooks (paridad retail, esfuerzo alto).
