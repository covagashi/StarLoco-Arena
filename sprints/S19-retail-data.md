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
- [x] **Estadísticas** (2026-10-22): de los 98 contadores que piden los
      logros, el cliente mueve 7 y el servidor movía 5; ahora mueve **80**.
      La semántica no se inventa: las clases de efecto del cliente aún llevan
      las llamadas que los alimentaban (`ig_1` daño y muertes, `sq_2` PM,
      `df_2` PA quitados, `va_1` muertes por trampa y por casilla asesina, la
      armadura en `NC` y familia; `l` suma, `m` guarda el máximo), y
      `content.48` describe cada criterio al jugador (p. ej. 35 = "puesto
      2500 − N"). Tres tandas:
      - Al acabar el combate (`coach_statistics.go`): rachas por modo, fuerza
        máxima, reputación, hueco de nivel al ganar, ganar con un solo
        luchador, rendiciones (y en 2v2 antes que el compañero), el luchador
        más caro de cada raza en una victoria por tramo de nivel, la XP más
        gastada, muertes y heridas (y graves) en evolución, puesto en la
        escalera, Hell's tofus, Limero sin hechizos.
      - Dentro del combate (`fight_statistics.go`): daño por turno y por
        combate al bando contrario, muertes y PM por turno, PM totales, PA
        quitados, muertes por trampa (al dueño), por casilla asesina (a la
        víctima), casillas bonus, armadura, golpes de Aniripsa. No cuenta en
        los combates de práctica.
      - Desde la sesión: objetos puestos, consumibles en evolución, borrar un
        luchador de evolución vivo.
      Faltan 11, cada uno en su sitio: 183/187/188/189 (partidas de torneo →
      **S09**), 198–200, 211, 226 (tutorial → **S10**), 147/222 (no existen
      las escaleras 2v2 ni de evolución). Pruebas: 13 nuevas en
      `internal/game` (todas por el camino real: `checkFightEnd`,
      `forfeitCoach`, `closeCombat`, `applyTurnStartSpecialCell`,
      `handleFighterDelete`, `useConsumableOnFighter`), `TestMaxAndAddStat`, y
      el e2e `TestFightStatisticsUnlockAchievements` (un abandono real anuncia
      el 22000 a los dos coaches).
- [x] **Bits de máscara 55 y 58–61** (2026-10-22): ya son decidibles. El 55
      es el estado `deC` que pone la 139 "redirección de daños" (`aOp`): el
      servidor solo la dibujaba y ahora deja el estado. Los 58–61 son
      `ig_1.a`, daño % del lanzador menos resistencia % del objetivo en un
      elemento (con los "a todo"), rechazado por debajo de −60: tierra, aire,
      agua y fuego, por el emparejamiento `Lr` del propio `ig_1`. De paso, los
      bits 53/54 ya miran también la resistencia ≥ 100 a perder PA/PM (el
      comentario decía que no estaba modelada, y sí lo está). Solo los bits
      62/63 siguen en la válvula de escape. Ningún comportamiento cambia con
      los datos: los 3 hechizos con máscara obligatoria no los usan (sí muchas
      máscaras no obligatorias). Pruebas: `TestRedirectedTargetBit`,
      `TestElementalResistBits`, el canario de siempre.
- [x] **Código 66** (`badCoachCardQuantity`): descartado aquí. Es el único
      código que no está en `je_2`, y su único disparador plausible es el
      17010 (torneos creados por jugadores), que es de **S09**.

## Opcodes pequeños

- [x] **8250, penalización por inactividad** (2026-10-22). El inventario lo
      daba por "decisión de política antitrampas", pero la política está en
      el cliente: el texto `cheat.turnDuration.decreased` dice qué la provoca
      ("ninguna acción de combate desde hace más de un minuto") y qué pasa
      ("se reducirá la duración de tus turnos"), y `adu_0.f` divide el reloj
      del turno entre `aez_0.eN`: la mitad el primer turno reducido, un sexto
      los siguientes (las invocaciones, mitad sin avanzar). El servidor
      (`turn_penalty.go`) suma el tiempo de turno propio que se agota sin
      acción; al pasar de un minuto emite 8250 `[coach][0]` y acorta su reloj
      igual que el cliente; con la primera acción (o pasar turno a mano)
      emite `[coach][1]` y lo devuelve. Godot avisa al jugador con el texto
      retail y acorta su contador. Pruebas: `TestIdleCoachGetsShorterTurns`
      (la secuencia y los dos 8250), `TestIdleTurnsThroughTheClock` (por el
      reloj real), `fight_smoke` en vivo (`[2, 2, 6, 1]`).

- [x] **3212** (2026-10-22): ahora es la respuesta al 22093 (usar una carta
      de título), la única acción del jugador que el servidor deja sin modelar
      a propósito y en la que el cliente no enseña nada propio: "Todavía no
      está operativo". El 22097 (enviar a otro juego) no, porque el cliente ya
      dice localmente que se ha enviado. Prueba:
      `TestTitleCardIsAnsweredNotYetImplemented`.
- [x] **Sub-blobs del 2052** (2026-10-22): **B-186**, el blob 0x8
      (`{u8 escalera, i16 fuerza}`, `aez_0.X`) iba siempre vacío, y es de
      donde el lobby retail saca nivel, rango y "Fuerza": todo coach salía sin
      clasificar hasta acabar un combate. Ahora lleva la fuerza 1v1; el
      decodificador de Godot leía solo el contador y ya lee las entradas. El
      0x100 son los puntos de torneo (S09) y la cartera, que ya llega por el
      4001. Pruebas: `TestCoachInformationsCarriesLadderStrength`,
      `coach_info_test.gd`, `login_smoke` y `fight_smoke` con el coach `test`
      (fuerza 1000).
- [x] Descartados, con la prueba:
      - **2307/2309 y las apuestas**: el 2307 no lleva apuesta, es la variante
        antigua de la confirmación de búsqueda (mismo texto que el 23110, que
        es el que se usa). Las apuestas existieron, pero la 2.70 las quitó: en
        `randomFightCreationDialog.xml` la casilla "Con apuesta aleatoria"
        está comentada bajo `<!--plus de pari-->`.
      - **4106** (recolocar varios actores del mundo): no hay mundo, el lobby
        sustituye a los mapas (decisión del dueño, S05).
      - **4800 RunScript**: dispara escenarios Lua del cliente; los usa el
        tutorial → **S10**, que ya lo lista.
      - **Faucet diario de fichas**: viene del ROADMAP heredado ("Daily login
        / other faucets ⬜") y el cliente no tiene ni texto ni pantalla para
        una recompensa diaria; sería un diseño nuevo, no paridad.

## Criterio de cierre

Cada punto leído en el cliente y hecho con prueba, o descartado por escrito
con la clase que lo demuestra; el resumen de `OPCODE-INVENTORY.md` (que un test
recuenta) baja en lo que se haga.
