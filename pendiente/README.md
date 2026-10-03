# Pendiente — seguimiento local

Lista de pasos **no bloqueantes** tras cerrar el decoder `.xps` (364/364 `0x5001`) y el wiring Godot (B-167).  
Contexto: [`server/docs/BUGS.md`](../server/docs/BUGS.md) (B-167), [`server/docs/STATUS.md`](../server/docs/STATUS.md) (fila GODOT `.xps`).

**Hecho (referencia):** `xps_dump.py`, `test_xps.py`, `xps_fx.gd`, `_cast_fx` en `8110`, docs, commit `682e8ba5`.  
**Hecho (2026-10-03):** `spell_sounds.py` reescrito como mini-evaluador Lua → `spell_fx.json` pasa de 100 a **116 spells**; tweens balísticos `avw_0`, ids por dirección, eventos `tw#i+k` post-impacto; auditoría de texturas cerrada (0 faltantes en spells).

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

- [x] **Texturas sin PNG — resuelto (2026-10-03):** el dump exporta 253/275, pero auditado por `textureId` **los 21 sistemas sin PNG referencian texturas que no existen en `sfx.jar`** (ids `71000xxx`, `11110`/`11111`, `13002`/`13004`, `20003`, `10105`, `7000005` — TGA ausente, no fallo del extractor). **Cero texturas faltantes entre los 182 sistemas referenciados por spells.** Ojo: el PNG se nombra por *texture id*, no por system id (10905 usa `10936.png`, 1009201 usa `1009202.png`).
- [x] **`81.xps` — resuelto (2026-10-03):** es un resto muerto de retail. Wrapper `"XPS\x08" + u32 + zlib` (399 B de un serializado pre-`0x5001`); **ningún script referencia el sistema 81**, hay copia idéntica en `gui.jar` (`gui/theme/particles/81.xps`), y el único loader (`alo_2.a` → `acf.T` bytes crudos → check de magic `20481`) lo rechazaría igualmente — nada descomprime el wrapper en el cliente. Documentado en `xps_dump.py`/`test_xps.py` como exclusión intencional.

---

## 2. `spell_fx.json` — cobertura script ↔ spell

~~Hoy ~**100 spells**~~ → **116 spells** con filas FX (2026-10-03) tras reescribir `spell_sounds.py` como mini-evaluador Lua con scope (era regex).

- [x] Auditar gaps: las 7 spells perdidas (`22, 25, 42, 61, 73, 137, 162`) llamaban `displayEffect()` directo (no vía `invoke`); además `invoke (` con espacio, ids por variable, ramas `startMobileDirection` y `invoke(time+k,…)` no parseaban. Los 107 scripts ligados a spell quedan cubiertos; 3 filas falsas (código comentado) eliminadas.
- [x] **`addTweenParticleSystem`:** extraído `angleDeg` + `timeCoef` → filas `[t,id,"tw",a,c]`; `xps_fx.gd` `spawn_projectile` porta la balística `avw_0` (v0=√(g·d/sin2θ), ms=2·v0·sinθ/g·1000/coef; 0.654s en tiro de 5 celdas ≈ retail 0.6537s). `invoke(time+k)` → filas `["tw#i+k",id,anchor]` disparadas por la señal `arrived`.
- [x] **Coordenadas world / ids por dirección:** tweens vuelan caster→celda apuntada en coords de mundo; ids variables → mapas `{"1":…,"3":…,"5":…,"7":…,"_"}` resueltos por `pick_id` con el Direction8 del caster.
- [x] Re-ejecutar smokes Godot tras regenerar `spell_fx.json` — `fight_smoke` + `carry_smoke` + `displace_smoke` verdes, 0 errores de script (tras `godot --headless --import` para las texturas `assets/fx`).

---

## 3. Godot — runtime y opcodes

- [x] **`8108` (uso de carta):** verificado — los 6 scripts de cartas arma (8001–8007) no llaman a `Particle.*`, así que no hay FX que cablear; el JSON nunca usará card id como xps id.
- [~] **Paridad visual — parcial (2026-10-03):** portados los 3 affectors calientes con la matemática real de los `ua_0` descompilados — `LinearForceEx` (vel += F·33·dt → `gravity` proyectada, los 208 del corpus son `geocentric`), `FrictionalForce` (vel·= 1−(33−f)·dt → `damping`) y `ColorFader` (c += (tgt−c)·speed·dt con ventanas `TimeCondition` → `color_ramp` simulando la cadena exponencial por intervalos). **Multi-emitter hecho:** un `CPUParticles2D` por emitter (los sistemas apilan 1–14 capas; 154/182 de los referenciados por spells tienen >1), cada uno con su ventana `startSpawnTime`/`endSpawnTime` vía `_schedule_emit` (p.ej. `10110` escalona 6 emitters entre 0.6s y 3.0s); en proyectil (`flying`) la estela sigue emitiendo hasta `arrived`. Pendiente: `Rebound` (52 refs — en realidad es fuerza orbital, no rebote), `DirectionFollower` (10), keyframed (`Deformer`/`Curve`/`RotationInterpolation`), sub-emitters y luces.
- [x] **Secuencias bitmap — resuelto (2026-10-03):** auditados los 182 sistemas referenciados por spells — **ninguno usa modelos tag `2` con curva `anim`**; no hay flipbook que portar.

---

## 4. Validación

- [x] **`displace_smoke`:** verde contra servidor Go local — `tp=true push=true swap=true`.
- [ ] **Cliente retail / MCP:** [`server/docs/CLIENT-TESTING.md`](../server/docs/CLIENT-TESTING.md) — cast con partículas visibles vs Godot (misma spell id / xps id).
- [x] Tras cada cambio de decoder o FX: `go test ./...` (desde `server/`, todo verde), smokes `fight_smoke` + `carry_smoke` + `displace_smoke` (0 errores script).

---

## 5. Docs al cerrar cada ítem

Por convención del repo (`AGENTS.md`):

- [x] Actualizar [`server/docs/STATUS.md`](../server/docs/STATUS.md) (fila GODOT / B-167).
- [x] Entrada en [`server/docs/DATA-COVERAGE.md`](../server/docs/DATA-COVERAGE.md) — fila 2026-10-03 (mini-evaluador Lua, 116 spells, filas tween/dir-map).
- [x] Ajustar [`server/docs/BUGS.md`](../server/docs/BUGS.md) (B-167) — causa raíz de los gaps + fix del evaluador.

---

## Orden sugerido

1. ~~Regenerar assets + cerrar gaps `spell_fx.json`~~ ✓  
2. ~~`8108` + tweens/coords (FX en cartas y proyectiles)~~ ✓  
3. ~~`81.xps` + texturas faltantes~~ ✓ (dato muerto / TGAs ausentes del jar).  
4. Affectors / flipbooks (paridad retail, esfuerzo alto).  
5. Validación live vs cliente retail vía MCP.
