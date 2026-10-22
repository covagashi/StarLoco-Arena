# S19 — Datos retail sin leer y opcodes pequeños

**Planificado:** 2026-10-21 (al cerrar S08, que se partió en dos) · **Hito:** M3 — Paridad de contenido · **Tamaño:** M · **Estado:** 🟡 abierto (2026-10-22)

## Objetivo

La otra mitad de la deuda de servidor: lo que el cliente trae en sus datos y
el servidor todavía no lee, y los opcodes pequeños que faltan. A diferencia de
S08 (bugs, docs y pruebas), aquí casi todo es leer el cliente descompilado
antes de escribir código.

## Heredado de S08

- [x] **Texto de 36 cartas de evento** (2026-10-22). El retail
      (`tO.getDescription` → `asf_0.a(id, flag, efectos, null, 27)`), para los
      eventos con el byte de descripción (`ama_1.iG`, 36 de 51), escribe cada
      efecto con `content.22.<acción>` y sus parámetros, le pega la duración
      (`cast.durationDescription`, ≥ 63 → `cast.infiniteDuration`), separa los
      críticos y lo envuelve en `cast.effectDescription`; luego añade
      `content.27` (vacío en esos 36, a mano en los otros 15). Como todo es
      estático, lo hace el exportador: `dumpnpcdialogs` saca los efectos de
      cada evento y `npc_dialogs.py` porta `are_0.format` (los bloques
      `{[cond]?sí:no}`, `[#n]`, `[£n]`) y `asf_0.a`. Los iconos en línea
      (elemento, turno) pasan a palabra en cada idioma, porque el tooltip es
      texto plano. De paso: el `\n` de `content.27` llegaba crudo al tooltip
      de los 15 escritos a mano; ahora se resuelven los escapes de
      `.properties`. Pruebas: `tools/asset-import/test_npc_dialogs.py` 16/16
      (con los casos que el propio `are_0.main()` trae); `fight_smoke` en
      vivo: la carta 14 dice "Efecto: Estabiliza al objetivo (…) (1 turno),
      está enraizado (1 turno), vuelve enraizado (1 turno)". Esas dos últimas
      son las traducciones del retail para los efectos 127/128 (en inglés
      "Impossible to carry / to transpose"); se dejan como vienen.

- [x] **Encontrado de paso: ~40 tests que nunca corrían** (2026-10-22).
      `internal/gamedata` leía los datos de `clientBdataDir`, una ruta de
      Windows del autor original (`E:\Projets\…`), así que 32 tests se
      saltaban en cualquier otra máquina; otros apuntaban a `server/data/`
      (git-ignorado), entre ellos 6 e2e de desafíos y el del studio. Todos
      leen ahora `data-dist/`, que trae los mismos registros, y **pasan sin
      tocar nada más**. `go test ./... -v` pasa de ~40 `SKIP` a 1 (el de
      dialecto, que solo corre con Postgres/MySQL configurado).

## Datos retail sin leer (`server/docs/DATA-COVERAGE.md`)

- [x] **Tipo 210 (trampas)** (2026-10-22): los 13 campos leídos y con nombre
      (`aeb_0` → `er_1`/`yl_1`/`ack_1`). Hecho:
      - **B-185**: la Bruma (153) y la Bruma mortal (427) no se iban nunca. El
        área retail muere con el efecto 66 que la puso (`ds_1.aK`), y esos
        dos llevan duración (3–4 turnos); el servidor solo miraba `maxExec`
        (63, ilimitado). Ahora caduca como un aura, en servidor y en Godot.
      - **10008** (moverse sin salir del área): cableado, por paso andado y por
        desplazamiento forzado, como el 10001. Solo lo llevan la Bruma y la
        Bruma mortal (la mortal hiere al moverse dentro).
      Descartado, con la razón:
      - Condición de aplicación (`yl_1.d`: una vez, una por equipo, una por
        objetivo), el campo 6 (`ack_1.ahJ`, que nadie lee) y el retardo de
        re-disparo (`yl_1.FH`): a cero / vacíos en las 16 plantillas.
        `TestStaticEffectsUnusedFieldsReal` falla si un cambio de datos los
        activa.
      - **10003 / 10006**: nada en el cliente los dispara y no se sabe qué
        significan. La 1016 (`mauvaisOeil`, solo 10003) tiene un único efecto,
        170 "sin efecto", así que no dispararla no cambia nada.
      - **10002** (salir: desaplicar): solo la Bruma lo lleva, y sus dos
        efectos, 57 (invisible) y 84 (revelar), caen sobre el mismo luchador
        en ese orden; el 84 deshace el 57 al instante (en el servidor y en el
        `aum` del cliente), así que al salir no queda nada que quitar.
        **Pregunta abierta**: la descripción del hechizo dice que oculta a los
        de dentro; con esos datos, ni aquí ni (al parecer) en el retail lo
        hace. Sin servidor retail no se puede comprobar.
      Pruebas: `go test ./internal/game -run 'Trap|Stay'` (dos nuevas) y
      `./internal/gamedata -run StaticEffects`; `fight_smoke` en vivo (la
      Bruma dibujada dura 2 rondas y se va en la 3.ª: `[2, 2, 1]`).
- [x] **Tipo 400** (2026-10-22): leído entero. `QB` es el logro enlazado (la
      lista de desafíos del retail solo enseña uno si está hecho:
      `afz_0` "achievementLinkedCompleted" en `challengeDialog.xml`), `QC` y
      `QD` la XP y su tope. **Solo los usa la cadena del Demonio III** (29, 30
      con el logro 280, 31 con el 281) y Bernabé (45): con `QC > 0` el cliente
      abre los diálogos de resultado de evolución/tutorial (`ajo_1`). Esos
      logros se hacen con los criterios 198–200 ("desafío N del demonio III
      en modo evolución superado"), que el servidor no marca; filtrar ahora
      la lista dejaría el 30 y el 31 inalcanzables. Es el tutorial: pasa
      entero a **S10**. `TestChallengeEvolutionBlockReal` fija los valores.
- [ ] Estadísticas: hay 98 contadores referenciados y el servidor mueve "un
      puñado".
- [ ] Bits de máscara de objetivo 55 y 58–61; código 66.

## Opcodes pequeños

4800 RunScript, 8250 (penalización por duración del turno), 4106
(recolocación en lote), 2307/2309 (variante con apuesta) y apuestas sobre la
victoria, 3212 (sin llamada). El faucet diario de fichas. Los sub-blobs de
estadísticas de evolución y puntos de torneo en 2052/4096.

## Criterio de cierre

Cada punto leído en el cliente y hecho con prueba, o descartado por escrito
con la clase que lo demuestra; el resumen de `OPCODE-INVENTORY.md` (que un test
recuenta) baja en lo que se haga.
