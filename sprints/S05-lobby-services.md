# S05 — Lo que se perdió con el hall

**Planificado:** 2026-10-16 · **Detallado:** 2026-10-17 · **Hito:** M1 — Jugable de punta a punta · **Tamaño:** M · **Estado:** 🟡 abierto

## Objetivo

Cuando se deprecó el hall caminable (`godot/deprecated_hall/`), el acceso a
varios servicios del juego se fue con él. En el retail se llega a ellos haciendo
clic en un elemento del mapa; en el cliente Godot ese camino era
`main._use_element()` (`src/main.gd`), y hoy solo lo llama `test/world_smoke.gd`.
Este sprint los devuelve al jugador.

## Decisión previa (dueño)

**¿Entradas en el lobby o revivir el hall?** Se trabaja con la opción por
defecto: **entradas nativas en el lobby**, reutilizando los handlers que ya
existen. Revivir el hall sigue siendo posible más adelante
(`deprecated_hall/README.md`); nada de este sprint lo impide.

## Lo que hay (auditoría de código, 2026-10-17)

Leído, no probado todavía. La prueba de punta a punta es la tarea 1.

- **Ningún servicio tiene un llamante vivo.** `_use_element()` (el despacho
  por tipo de elemento: Card Master, buzón, cementerio, fusión, retos,
  demonios, tótems, fuegos artificiales, NPCs) solo lo llama
  `test/world_smoke.gd`. El buzón también se abre desde `mailboxDialog`, pero
  nada de la UI viva abre ese diálogo.
- **El cliente ya sabe qué hay en cada mundo**: `assets/gamedata/elements.json`
  (`src/gamedata/elements.gd`) trae todos los elementos de cada mundo, con
  tipo, celda y descriptor. No hace falta el AoI ni caminar.
- **El servidor no comprueba distancia**: el 201 se resuelve contra el mundo
  actual del coach (`handlers_elements.go`), esté donde esté. Pero
  `_element_info()` lee solo `State.elements`, que el servidor llena por AoI
  (radio de 2 chunks, medido contra el cliente retail). Fuera de ese radio el
  cliente no tiene el descriptor y los diálogos salen vacíos.
- **Zaap**: el servidor lo tiene completo (4512 → 4600 + 4516 + 200, 12
  cartas enrutadas y la isla de clan). En el cliente es un no-op a propósito
  (`_on_use_special_card`, `_on_zaap_change_instance`, `_use_element` tipo 4).
- **Mundos con servicios** (`elements_data.go`): las seis islas 23–28 (Card
  Master ×2, buzón, cementerio, altar de fusión, Zaap; Maknala además retos,
  un reto de demonio y fuegos artificiales), Totem Arena 37 (24 tótems de
  demonio, Démon I, retos, tótem de torneos, 2 Card Masters), y cuatro que
  **ninguna carta Zaap alcanza**: 35 (isla de reclutamiento: 12 maestros de
  raza, Démon III), 79 (guarida de Démon I), 80 (centro de Card Masters, 7) y
  85 (Gostof / Baan, NPCs). Más las 24 islas de clan 86–109 (altar + Zaap).
- **Bug de paso**: los iconos del menú del lobby van desplazados uno. El atlas
  (`tools/make_lobby_bg.py`) tiene 9 iconos "en el orden del menú retail",
  con "Menú" en la posición 0; `lobby_screen.gd` quitó la entrada "Menú" y
  sigue usando `i * 32`. Equipo lleva el icono de Menú y Ayuda el de Social.

## Tareas

- [x] **Entrada "Ciudad" en el lobby**: novena casilla del menú, con su icono
      (casas; `tools/make_lobby_bg.py --icons` reescribe solo el atlas). Abre
      un panel nativo (`lobby_panels.gd` `_city`) con los servicios de
      **todas** las islas juntos (23–28 y 37), agrupados por tipo, sin decir
      dónde estaban. Un clic llama a `_use_element()`. Buzón, cementerio y
      fuegos artificiales salen una vez; cada Card Master con el nombre de su
      set y cada altar con su nivel. Los disparadores de zona (tipo 8) no
      salen.
- [x] **Sin islas ni Zaap** (dueño, 2026-10-17: lobby y ligas, no mundos).
      El servidor resuelve el 201 en cualquier mundo (`elementAnywhere`; los
      ids de elemento son únicos en todo el juego, lo fija un test) y el
      fusionado usa el altar del último 201 en vez del más cercano. Las
      cartas Zaap no hacen nada.
- [x] `_element_info()` cae a `Elements.for_world()` cuando el elemento no
      está en `State.elements`.
- [x] ~~Zaap: viaje con 4512 desde el panel~~. Se hizo y se quitó el mismo
      día: el juego no va de islas.
- [x] Iconos del menú desplazados: arreglado (`(i + 1) * 32`).
- [x] **Auditoría de punta a punta**: `test/world_smoke.gd` reescrito. Abre
      "Ciudad" con el botón real, pulsa cada servicio en el panel y comprueba
      su evidencia. Resultado abajo.
- [x] Encontrado al auditar: el **Card Master** salía sin cartas la primera
      vez y **congelaba el cliente 66 s** al reabrirlo con un catálogo grande.
      Arreglado en la capa GUI (ver Resultado).
- [x] Mundos 35, 79, 80 y 85: investigado en el cliente (veredictos en
      "Mundos sin Zaap", abajo). 35 es la isla del tutorial → S10.
      **79, 80 y 85 descartados por el dueño** (lobby y ligas, no mundos).
- [x] Cartas especiales: la carta 214 "Pacte" abre la creación de clan, como
      en el retail. Los tipos 22 y 23 son partes del emblema de clan y no hay
      ninguna carta de esos tipos en los datos: descartados. El resto, abajo.
- [ ] **Pantallas nativas para cada servicio** (dueño, 2026-10-17: "esas
      pantallas son legacy, hay que mejorarlas todas"). Hoy los servicios abren
      diálogos retail XML o el panel de depuración `ElementDlg`. Hay que
      sustituirlos por paneles nativos al estilo del lobby:
      - XML retail: Card Master (`cardMasterDialog`), buzón (`mailboxDialog`,
        `newMailDialog`), altar de fusión (`fusionLabDialog`), fuegos
        artificiales (`fireworkDialog`), ofrenda al demonio
        (`demonAffiliationDialog`), intercambio (`exchangeDialog`).
      - `ElementDlg`: cementerio, conversaciones (retos, demonios, maestros de
        raza, NPCs), tótem de demonio y tótem de torneos.
      Cada una con hoja de opciones para el dueño antes de cerrarla.
      → **Pasa a S18** (rediseño de todas las pantallas), junto con login,
      creación y paneles. Inventario con capturas en
      `codigo/capturas/s05/inventario/`.

## Resultado (parcial, 2026-10-17)

### Auditoría

`godot --headless --path godot -s test/world_smoke.gd` contra el servidor
local: **57 comprobaciones, 0 fallos, exit 0**, todas desde el lobby, sin que
el coach cambie de mundo:

| Servicio | Evidencia |
|---|---|
| 14 Card Masters (12 sets + 2 de Totem Arena) | `5401` + diálogo |
| Buzón | `15001` + diálogo |
| Cementerio | panel |
| 6 altares de fusión (2/3/4/5 cartas, poderes 1–30) | `fusionLabDialog` |
| Fuegos artificiales | `fireworkDialog` |
| Retos (Démon III, Tofu de SuperBidi) y 6 retos de demonio | panel |
| Démon I | panel |
| 24 tótems de demonio | `27511` + panel |
| Tótem de torneos | `17003` + `28602` |

Servidor: `go test ./...` verde, con los tests nuevos
`TestElementInstanceIDsAreUniqueAcrossWorlds`,
`TestElementAnywhereFindsOtherWorlds`, `TestFusionLabRemembersTheOpenedAltar`
y el e2e `TestShopOpenCatalogFromAnotherWorld` (falla sin el cambio:
comprobado).

(Antes de quitar las islas, la misma auditoría recorrió las 7 islas por Zaap
y los mundos 35/79/80/85 por GM: 110/110. Esos mundos están descartados.)

Lo que la prueba **no** hace: comprar, enviar cartas, fusionar, lanzar un
fuego, aceptar un reto o registrarse en un torneo. Abre cada servicio y
comprueba que responde. El `world_smoke` viejo sí hacía parte de eso (y
mucho más: chat, presets, colas, social, gremio, rankings, la pelea del
défi de Baan) y nada de ello está cubierto ahora por un smoke de Godot.
`COVERAGE.md` apunta 26330 y 28649 a sus e2e de Go, que sí los cubren.

### El Card Master y la capa GUI

Tres bugs en `src/gui/`, encontrados porque la auditoría tardaba 4 minutos
en el mundo 80:

1. **`model.gd`**: `set_value(nombre, dict)` solo avisaba a los widgets que
   vigilan el objeto entero, no a los que vigilan un campo. El catálogo del
   Card Master (`cardMasterTrade|cardMasterCardExchange`) salía **vacío** la
   primera vez y solo aparecía al reabrir. Ahora se avisa también a los
   campos.
2. **`widget.gd`**: al reabrir, la lista se construía antes de entrar en el
   árbol y luego `add_child` y el layout recorrían cada fila: **66 s** con
   845 cartas (8,4 s con 100). Ahora se construye al colocarse el diálogo.
3. **`layouts.gd`**: cada nivel se maquetaba dos veces (asignar `size`
   dispara `resized` → `apply`, y luego otro `apply` a mano), 2^profundidad.
   Ahora una sola vez (`_size_and_apply`).

Evidencia: `test/shop_perf.gd` (`N=100`): reabrir **8,4 s → 0,5 s**, y la
primera apertura pinta 243 filas en vez de 1. `test/layout_hash.gd`
(huella de la geometría de 7 diálogos, 1.648 widgets en el Card Master):
**idéntica** antes y después del cambio de `layouts.gd`. `./run_tests.sh`
exit 0; `native_lobby` 28 PASS, `native_panels` 123 PASS, 0 FAIL.

Queda: con el catálogo de 845 cartas la primera apertura tarda ~15 s (casi
todo en cargar 845 ilustraciones). Ese catálogo no es real: es el fallback
del servidor (apuntado en S08).

### Capturas

Samba `codigo/capturas/s05/`: `lobby.png` (la casilla "Ciudad"), `city.png`
(el panel sin islas) y `cardmaster.png` (la pantalla legacy que hay que
sustituir).
Se rehacen con `xvfb-run -a godot --path godot --accessibility disabled -s
test/world_smoke.gd -- --shot-dir=<dir>`.

### Mundos sin Zaap

Investigado leyendo el cliente decompilado y los `.lua` de escenario. Solo se
comprobó a mano un punto (`ayF.gi`, el del mundo 80); el resto viene de la
lectura del código, con las citas en el devlog.

- **35, isla de reclutamiento**: es la isla del tutorial retail. Sus
  disparadores lanzan los escenarios 100–108 (Baan recibe al coach nuevo) y
  el 108 enseña a usar el Zaap con la carta 254, que lleva a Totem Arena (37).
  Se llegaba desde la cinemática: `scenario/0.lua` llama a
  `tutorialChangeInstance()`, que envía 4517. Lo que hacía el servidor
  después (¿4600 al 35 + 4800 RunScript?) es una inferencia. Nuestro servidor
  no implementa ni 4800 ni 4523 (saltar tutorial), ni ese relevo del 4517.
  → **S10** (tutorial).
- **79, guarida de Démon I**: copia de los retos de demonio del 37 más un
  Démon I hablador. Ninguna referencia la alcanza. Ruta retail desconocida.
- **80**: no es un centro de teletransporte. Son la **Démone II** y sus seis
  "Secondes", Card Masters de modo 1 (`ayF.gi`: el tercer campo es un nombre
  de `content.29`, comprobado). Ruta retail desconocida. La fila de
  `OVERWORLD-MAP.md` que decía "Zaap; dests 309–315" estaba mal y se ha
  corregido. El panel los nombra ya ("Demon II", "31st Second"…).
- **85, Gostof**: isla de ayuda (Baan y los Gostof explican élite,
  evolución, 2v2 y torneos). Ruta retail desconocida.

**Decisión del dueño (2026-10-17): 79, 80 y 85 descartados.** "No hace falta
abrir mundos: quitamos los mapas para tener un lobby y ligas PvE/PvP." El
juego no va de islas: lo que el retail tenía en una isla se trae al lobby,
no se abre el mundo.

### Cartas especiales

| Tipo | Qué es (cliente `aMK`) | Estado |
|---|---|---|
| 20 Zaap | teletransporte | En el retail solo se viaja desde `zaapDialog`; aquí también desde el inventario, porque sin el hall no hay otro sitio |
| 21 | 214 "Pacte" (crear clan), 807 "Création de Tournoi", 808 "Ticket MasterCoach" | 214 hecho. 807 y 808 no se usan desde el inventario (los mira el flujo de torneos) → S09 |
| 22, 23 | fondo y logo del emblema de clan | no hay cartas de estos tipos → descartados |
| 28 título, 30 Dofus | envían 22093 y 22097 | sin conectar en Godot → S07 |
| 25 | fuegos artificiales | ya van por el lanzador del panel "Ciudad" |

El servidor acepta 509 (crear clan) sin comprobar que el coach tenga la carta
214 → S08.

### Visto por el camino

- El `cardMasterDialog` retail se ve roto (ventana beige) y los Card Masters
  de modo 1 deberían abrir `demonIIDialog` → S07.
- Nombres de NPCs y cartas en inglés junto a la UI en español → S07.
- `Cards.lab()` nunca encontraba nada (claves de texto en el JSON, búsqueda
  con entero): el altar de fusión del cliente nunca supo su nivel y usaba 3
  casillas siempre. Arreglado; el panel distingue ya los 6 altares.
- Nombres de set reales (`content.25`, es/en/fr) en
  `assets/gamedata/cardsets.json`, exportados por
  `tools/asset-import/card_names.py`. Los usan el panel y el inventario. Ese
  script además ya no reproducía `cards.json` (tiraba `reqLevel`, que usa la
  fórmula de fusión): ahora pasa todos los campos y lo reproduce idéntico.

## Criterio de cierre

Cada servicio de la lista se usa de principio a fin contra un servidor real, con
captura o prueba que lo demuestre, o queda descartado por escrito.
