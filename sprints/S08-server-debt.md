# S08 — Deuda de servidor

**Planificado:** 2026-10-16 · **Abierto:** 2026-10-21 · **Hito:** M3 — Paridad de contenido · **Tamaño:** L (probablemente se parta en dos) · **Estado:** 🟡 abierto

## Objetivo

Que el servidor no tenga huecos *conocidos*: bugs abiertos cerrados, datos
retail leídos y documentación que no se contradiga.

## Bugs y comportamientos abiertos

- [x] **Enraizado:** descartado, el servidor ya hace lo que el cliente. La
      acción 65 "Immobilisé" (`rc_0`) pone `avx_0.dex` y `gn_0.d` (línea 468)
      lee los PM como 0: no puede andar. Lo que solo impide *ser movido* es
      94 (empujar/atraer), 127 "S'enraciner" (transporte) y 128 (intercambio);
      el aviso en vivo seguramente era 127, que en francés suena a "enraizar".
      Anotado en `BUGS.md` (B-053 y la nota abierta de B-048).
- [x] Los iconos de buff al reconectar: ya estaban hechos (`09a2056c`, el
      8121 `rq_2` los adjunta sin ejecutarlos) y el espectador comparte el
      camino. Faltaba probarlo por el camino real: `TestResyncReattachesLiveBuffs`
      llama a `sendFightResync` y espera un 8121 por buff vivo, con la caducidad
      absoluta, y ninguno del muerto (falla si se quita `resyncBuffs`). Quitados
      los "LIMITATION" que quedaban en el código y en `BUGS.md`.
- [x] B-151: `TestShopBuyRefusesUnpricedCardOnTheWire` manda el 5450 al
      handler con una carta sin precio y otra con precio del mismo set: la
      primera no se entrega ni cobra, la segunda sí. Quitar la guarda del
      handler la hace fallar (antes no fallaba nada). No es un e2e por socket
      porque el arnés e2e no carga gamedata (punto de abajo).
- [ ] B-074: panel de fin de combate con el equipo perdedor vivo, sin verificar
      visualmente.
- [ ] Casillas especiales: confirmar en vivo que una se dispara.
- [ ] B-111: de dónde salen los rosters de 10 objetos.
- [x] `pvp_smoke` se paraba en el intercambio: lo cerró S18 (`5688fe2f`). No
      eran las cartas, era que el smoke esperaba el panel de depuración y se
      abría el diálogo XML retail; ahora usa el panel nativo y llega al final.
- [x] Nombres con acentos, las dos mitades:
      - el cliente retail: **encontrada la línea** que se buscaba desde B-068,
        `aez_0.setName` (línea 139) hace `new String(name.getBytes("UTF-8"))`
        con el charset de la plataforma: el salto de más. Defecto del cliente
        retail, que ya es legado. Godot lee bien esos mismos bytes:
        `test/unit/cp1252_names_test.gd` ("Loové", "Défi", "Maître d'élevage",
        "5€" desde los frames exactos del servidor; lane headless 249 checks).
      - las cadenas de gamedata: **ya estaban bien**. El cliente lee las de los
        registros como `[i32 len]` + `new String(bytes, "UTF-8")` (`IL`,
        `ng_2`, `vy_0`, `Yq`), que es lo que hace `gamedata.cur.str()`. Solo
        el cable es cp1252. Corregido `STATUS.md`, que decía lo contrario.
- [x] **Catálogos de 845 cartas**: los Card Masters de modo 1 ("démone II":
      `ku_2.X()` abre `demonIIDialog`) de los mundos 37 y 80 nombran las
      listas 17–24, que no son ningún set de los datos del cliente; lo que
      vendían vivía en el servidor de Ankama y no hay forma de saberlo.
      Arreglado lo que sí era un error: el fallback era "toda carta con mapa
      de precio", ceros incluidos (845, casi todas rechazadas al comprar); ahora
      son las que se pueden comprar (precio positivo): **143**. El mundo 80 ya
      no se ve (decisión del dueño, S05); el 37 sí, en el panel Ciudad.
      Prueba: `TestCardMasterStockIsItsCardSet` con una carta de precio cero.
- [x] 509 sin la carta 214 "Pacte": **descartado**. En el retail la carta es
      lo único que abre `guildCreationDialog` (`aBC` caso 214 → 16431), pero
      en los datos no hay forma de conseguirla: no se vende (precio 0), no
      sale en el robo (`ObtainableInDraw` falso) y ningún desafío la da.
      Exigirla dejaría a todos sin clan. Godot ya crea el clan desde su botón
      nativo (Social → Crear clan). Queda como decisión del dueño en el
      README (repartirla, p. ej. a nivel 5 de coach, que es su `RequiredLevel`).

## Heredado de S07 (2026-10-21, acordado con el dueño)

- [ ] **Texto de 36 cartas de evento**: el retail lo genera a partir de los
      efectos de cada evento (`tO.getDescription` → `asf_0`); hoy enseñan su
      texto de ambiente. Generar la línea de efectos con los datos del evento.
- [x] **Nombres que manda el servidor en un solo idioma**: resuelto en Godot
      sin tocar el cable (`src/gamedata/ai_names.gd`, llamado desde
      `State.index_fighters`). Solo para los dos coaches IA del servidor
      (`sparringCoachID`, `challengeCoachID`): los demonios salen de la tabla
      del retail (`content.29.262–266` y `281`, los tres idiomas), el maestro
      de raza, "Démon", "Défi" y "Sparring" de claves propias (`ai.*`), y un
      luchador IA solo si su nombre es exactamente el de su raza en francés.
      Pruebas: `test/unit/ai_names_test.gd` (lo de un jugador no se toca;
      lane 257 checks) y `fight_smoke` en vivo, en español: "Demonio del
      minuto 58" contra "Yopuka" y "Sacrógrito", y la versus con ese nombre.
      `report_smoke` 7/7.
- [ ] **`pvp_smoke` no pulsa Listo**: su vista de combate no recibe el 8020
      (el arnés deja dos lobbies vivos) y la colocación acaba por tiempo.
      Hueco de la prueba, no del juego.

## Datos retail sin leer (`DATA-COVERAGE.md`)

- [ ] Tipo 210 (trampas): política de re-disparo, máscaras y temporizador; los
      disparadores 10002/10003/10006/10008 (la plantilla 1016 nunca se dispara).
- [ ] Tipo 400: logro enlazado, recompensa y tope de XP.
- [ ] Estadísticas: hay 98 contadores referenciados y el servidor mueve "un
      puñado".
- [ ] Bits de máscara de objetivo 55 y 58–61; código 66.

## Opcodes pequeños pendientes

4800 RunScript, 8250 (penalización por duración del turno), 4106
(recolocación en lote), 2307/2309 (variante con apuesta) y apuestas sobre la
victoria, 3212 (sin llamada). El faucet diario de fichas. Los sub-blobs de
estadísticas de evolución y puntos de torneo en 2052/4096.

## Documentación que se contradice

- [x] Recuentos de opcodes: había **cuatro** distintos (dos dentro del propio
      inventario). Ahora hay uno, el resumen de `OPCODE-INVENTORY.md`
      (347 filas: 111 H, 152 E, 6 I, 4 X, 74 sin hacer), y
      `TestOpcodeInventorySummaryMatchesTable` lo recuenta. `STATUS.md` y
      `COVERAGE.md` enlazan en vez de repetir. De paso: el ping estaba mal
      (107 iba como `both H+E` y 108 como sin hacer; la respuesta sale por 108).
- [x] `COVERAGE.md` decía ser "la fuente única" y lista 179 de 347 opcodes;
      ahora dice lo que es (auditoría y pruebas) y
      `TestCoverageAgreesWithInventory` exige que sus filas digan lo mismo que
      el inventario sobre si está hecho: 28612/28614 y la tanda 5101–5116
      (marcada con `V`) estaban mal.
- [x] 4523 es el binding Lua `Context.skipTutorial()` (`bv_0`, librería
      `uc_2` "Context"), no un comando de consola. 22093 es usar una carta de
      título (tipo 28 `aMK.dYC` "Titre": "Trainer", "No title"… 12 cartas), no
      una transferencia a otro juego. Sigue sin hacerse, ahora con el motivo
      bueno: nada en el cliente 2.70 enseña un título de coach. Corrige
      también la frase de S07.
- [x] `BUGS.md`: la capa meta (heridas, muerte y robo de cartas ya están),
      las condiciones 902 (ya modeladas) y el crítico/pifia base (`uh_0.eA`
      resultó ser el id del script del arma; la base ya es 0/0 en `breed.go`).
      Anotadas con "Update (S08)", sin reescribir la historia.
- [x] "Known gaps" del inventario: los cuatro puntos estaban cerrados;
      ahora lo dice y manda a `sprints/`.
- [x] X-vs-X (ítem 33): cerrado con el valor por defecto del dueño (muerto en
      el retail: 26313 solo existe como binding Lua de la librería `Test`).
      `STATUS.md` corregido, y también su punto 9 (torneos "aplazados", hechos
      en el ítem 32).

## Pruebas y bases de datos

- [x] El arnés e2e pasaba gamedata `nil`. La carga de datos salió de
      `cmd/server` a `gamedata.LoadBundle` + `Deps.UseGameData`, y el arnés
      tiene `testServerWithData`, que arranca con `data-dist` por el mismo
      camino. Dos e2e nuevos (`realdata_test.go`): B-151 por socket con cartas
      reales (set 147: la 70 sin precio se rechaza, la 72 se vende; quitar la
      guarda lo hace fallar) y un combate en las arenas reales hasta el primer
      turno.
- [x] 6006/6030: ya había e2e que veían llegar los dos, ninguno leía el
      contenido. `TestTeamPresetRoundTrip` guarda un equipo con un luchador y
      lo lee del 6030 campo a campo (banquillo −4 primero, luego id, modo,
      nombre, luchador y dueño), con el 6006 de un luchador.
- [x] Postgres en los tests: `storetest.Open(t, path)` (y `newTestStore` en el
      propio store) abre un esquema nuevo por test en el servidor que digan
      `ARENA_STORE_TEST_DRIVER`/`ARENA_STORE_TEST_DSN`; sin ellas, SQLite como
      siempre. Los 34 sitios de `game`, `web` y e2e pasan por ahí. Comando en
      `AGENTS.md`. Resultado: **B-181**, el ladder de clanes fallaba en
      Postgres (el de producción) por un `GROUP BY`. Arreglado; todo el suite
      pasa en Postgres 16 (dos pasadas seguidas) y en SQLite.
- [x] MySQL: corrido por primera vez, MariaDB 10.11, todo el suite en verde.
      La decisión de seguir con él sigue siendo del dueño (por defecto, sin
      cambios); ahora hay con qué probarlo.
- [x] De paso, **B-182**: el predicado de cartas únicas del correo y el
      registro de arenas eran globales del proceso; cada servidor que arrancaba
      pisaba los de los demás (los e2e con datos reales rompían al azar los
      demás). Ahora son de cada servidor. Los tests de arenas dejaron de
      saltarse: leen `data-dist` si no hay `data/`.
- [ ] `displace_smoke` (y `carry_smoke`, mismo fallo) se cuelgan según el
      mapa. **A medias (2026-10-21):** arreglado un falso positivo
      (`_swap_ok` subía al lanzar y la prueba se rendía antes de verificar:
      pasó con dos intercambios fallidos; ahora espera a `_pending == 0`) y
      el acercamiento (si la casilla útil queda más lejos que los PM, avanza
      lo que den en vez de pasar turno siempre). **Siguen agotando los 300 s**
      en la última pasada (displace llegó a SWAP OK; carry no llegó a cargar):
      falta ver qué turno se queda sin cerrar (en el log del servidor los
      turnos de mesa iban a 61 s, el reloj expirando).
- [x] Los `zz*` que dejan los smokes cortados: `test/smoke_sweep.gd`, al
      entrar al mundo pide 6031 y borra los presets y luchadores `zz*` antes
      de crear nada (summon, carry y displace). Probado sembrando uno: barrió
      ese y **26 presets reales** olvidados; displace barrió lo que dejó un
      carry cortado. Además el `_cleanup` espera 0,5 s antes de salir: el
      último 6003 se perdía y dejaba un luchador.

## Criterio de cierre

Cada punto de arriba arreglado con prueba, o descartado por escrito, y un solo
recuento de opcodes que coincida en las tres docs.
