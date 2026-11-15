# S41 — Textos propios

**Planificado:** 2026-10-25 · **Hito:** M7 — Arte propio · **Tamaño:** M · **Estado:** ✅ cerrado (2026-11-15)

## Decisión del dueño (2026-10-25)

El tercer paso, tras el arte y las cartas: ningún texto del retail.

## Alcance

- Los nombres y descripciones de cartas, hechizos, eventos, logros, retos y
  NPC que hoy salen de las tablas retail (`content.*`, `npcdialogs.json`),
  reescritos en es/en/fr. S23 ya revisó a mano los de los NPC y S26 renombró
  demonios: es la base.
- Ayuda, tutorial e historia del mundo (el Horamundo) con voz propia.
- Quitar `GameText` y los `gui/i18n_*.json` retail.

## Llega de S40 (2026-11-15)

Las descripciones de las cartas en el cliente son textos retail, no salen de
los datos: tras los topes de S40 algunas dicen lo que ya no es ("+50 % XP",
"100 % de resurrección"). Los textos nuevos deben salir de los efectos de
`server/content/` (o escribirse contra ellos).

## Criterio de cierre

Todo texto que ve el jugador sale de los ficheros i18n propios.

## Hecho

### Paso 1: lo que hace cada carta, escrito desde sus efectos (2026-11-15)

**Lo que encontré al mirarlo** (la nota de S40 era una sospecha): el cliente
no enseñaba **ningún** efecto de las cartas de coach. El detalle del
inventario mandaba `"description": ""` y `"coachCardEffects": []`; los
"+50 % XP" solo vivían en las plantillas retail (`content.47`), que el
cliente nativo ya no usa. Y al leer el servidor para escribir el texto
salieron dos fallos que lo habrían hecho mentir:

- **Los efectos propios de una carta puesta no hacían nada** después del
  combate: el servidor solo sumaba los de su **set** (`setBonusFor`). Una
  capa con "+4 % de XP" no daba nada si no completaba la colección. El
  cliente retail sí los sumaba (sj_1 junta los dos en una entrada por
  acción), y los topes de S40 (paso 2.2) se pensaron sobre ellos.
  Heurística: que cuenten. `coachBonusFor` = set + efectos propios de las
  cartas puestas (con el mismo filtro de nivel del coach); lo usan el
  post-combate, la resurrección y el botín (los efectos de botín de los sets
  tampoco contaban: ahora sí, como todo lo demás).
- **Resurrección:** 4 cartas de equipo llevan "+25 % de resurrección". Con
  sus efectos contando, tres capas encima de una carta de resurrección del
  25 % la volvían segura otra vez. Heurística (la regla del dueño "ninguna
  resurrección segura"): lo que suma el equipo entero, como mucho **+25**
  (`ResurrectGearBonusCap`): 50 % como máximo.
- **Pociones con dos condiciones:** 54 consumibles de Historia llevan dos
  (una bendición y su precio, p. ej. "Pegajoso" + "Idiota"); el servidor
  solo aplicaba la primera. Ahora aplica todas.

**Servidor** (`go test ./...` en verde; las pruebas nuevas fallan sin el
cambio): `TestCoachBonusCountsTheCardsOwnEffects`,
`TestPostFightXPCountsTheEquippedCardsOwnEffect` (un combate de Historia
con una carta de +10 % da un 10 % más de XP), `TestResurrectChanceCapsTheGear`,
`TestConsumableAppliesEveryCondition`.

**Datos al cliente:** `cmd/dumpcards` exporta los efectos de cada carta
(`cards.json`, `fx`) y de cada set (`cardsetfx.json`, con el número de
cartas que pide), sacados de `server/content/`, y conserva los nombres que
ya tenía `cards.json`.

**Cliente:** `src/gamedata/card_text.gd` convierte cada efecto en una frase
con claves propias `cardfx.*` en es/en/fr (`assets/i18n/ui_*.json`). Una
carta puesta y una consumible leen distinto el mismo id (en una poción, 11
cura heridas leves y 15 aplica una condición), como en el servidor; una
acción sin texto no sale. Debajo, cuándo cuenta ("al acabar cada combate de
Historia", S21; reputación y botín, en todos) y el nivel de coach que pide.
En el Inventario, el detalle de la carta lo enseña bajo el nombre (el arte
baja de 200 a 160 de alto para que quepa sin desplazar en 1280×720), y la
pestaña Colecciones, los bonus del set ("Con 5 puestas: …"). El texto de
"para qué sirve" de las cartas de coach se reescribe (ya no dice que solo
los sets dan bonus).

**Pruebas del cliente:** `test/unit/card_text_test.gd` (las frases, que
cada acción de los datos tiene texto en los tres idiomas, que lo
desconocido no sale); `run_tests.sh --headless` 1614/0.
`test/inventory_smoke.gd` contra un servidor local con una copia de la base
y cartas sembradas (409, 137, 305, 123 y set 1): **7/7**, con capturas en
`~/codigo/capturas/s41/`.

### Paso 2: nombres propios de cartas, colecciones y condiciones (2026-11-15)

Pedido del dueño: "cambia los textos, usa haiku o tú mismo". Escritos por
agentes Haiku por lotes, con una guía de estilo (tono ligero, cortos, nada de
nombres propios ni juegos de palabras del retail; las palabras de
diccionario sí valen) y revisados uno a uno por mí:

- `godot/assets/i18n/content_<lang>.json` (es/en/fr, en git): `card.<id>`
  (las 907 cartas de coach), `fcard.<id>` (los 75 equipos de luchador),
  `set.<id>` (las 138 colecciones) y `cond.<id>` (las 111 condiciones).
  `src/gamedata/own_text.gd` los lee; `Cards.name_of`,
  `Cards.card_set_name`, `FighterCards.label` y el texto de las pociones ya
  no tocan `GameText` ni `cardsets.json`. `dumpcards` ya no escribe nombres.
- El equipo de coach sigue el patrón de su colección ("Capa de remiendo",
  "Botas de remiendo"); las pociones se llaman por su bendición ("Pócima
  pegajosa"); las reliquias (antes "objetos DOFUS") son curiosidades:
  gemas, esencias, rollos.
- **Cartas de regla que apuntan a un hechizo, una clase o un equipo de
  luchador (212 de 282):** no llevan copia del nombre, sino una referencia
  (`@spell:34`, `@breed:1`, `@fcard:7`) que el cliente resuelve. Heurística:
  cuando S46 renombre hechizos y clases, estas cartas lo siguen solas. El
  emparejamiento se hizo por el nombre retail (hechizos repetidos toman el
  primer id con ese nombre). Las 14 colecciones de hechizos de clase se
  llaman "Hechizos de clase 1…14" hasta entonces.
- Revisión mía: reglas de tiempo y turnos en claro ("10 s por turno",
  "+5 turnos"; los agentes las habían vuelto crípticas), elisiones
  francesas, "Gommette" (pegatina) → "Gomme", dos condiciones y dos
  traducciones inglesas.
- Interfaz: fuera "Dofus" de las etiquetas (la ranura y el tipo de carta
  pasan a "Reliquia(s)", "Clásico" en vez de "Clásico (Dofus)"). La pestaña
  Colecciones toma el nombre de la colección, no el prefijo de sus cartas
  (salían "Botas de", "10 s por").

**Pruebas:** `test/unit/own_text_test.gd` (las tres tablas con las mismas
claves, cuántas de cada tipo, ninguna vacía ni de más de 30 caracteres,
ninguna palabra propia del retail); `fighter_cards_test` con el nombre
nuevo. `run_tests.sh --headless` 1629/0. `inventory_smoke` contra servidor
local: **9/9** (nombre propio de la poción, una carta de regla con el
nombre de su clase y otra con el de su hechizo, colecciones). Capturas en
`~/codigo/capturas/s41/`.

### Paso 3: el resto de los textos, y fuera los retail (2026-11-15)

Pedido del dueño: "pues cambia el texto, te lo he dicho, así terminas el
S41". Agentes Haiku en dos pasadas y revisión mía; las decisiones que tomé
solo (heurística: ningún texto del retail, como pide el sprint):

- **Las clases y el mundo también.** Los eventos, logros y diálogos nombran
  clases, así que sin renombrarlas quedaban textos retail. Las 12 clases
  (`breed.N` en `ui_<lang>.json`): Bastión, Domador, Buscaoro, Sombra,
  Relojero, Tahúr, Curandero, Espadachín, Arquero, Jardinero, Furia y Panda
  (en/fr en sus tablas). El "Horamundo" pasa a ser **el Gran Reloj**. Los
  modelos 3D y sus carpetas (`feca_m`…) no cambian de nombre: no se ven.
  Si el dueño quiere otros nombres, son una línea por clase.
- **Hechizos:** los 139 que el cliente nombra (los 120 de las clases y 19
  de invocaciones o reglas) en `spell.<id>`. Los datos de los hechizos
  siguen siendo S46.
- **Diálogos, NPC, retos, logros, criterios, invocaciones y eventos** (1.282
  textos: `npc`, `dlg`/`dlgr`, `chal`, `ach`/`achd`, `crit`, `summon`,
  `event`/`eventd`/`eventl`). La primera pasada dejó un tercio de los textos
  casi iguales al original (los agentes parafraseaban poco): una segunda
  pasada los reescribió con un script que mide el parecido, hasta que ninguno
  pasó del 60 %.
- **Revisión mía:** los nodos de Nilo que se pueden abrir (7, 8, 10–12, 42,
  44, 66, 69, 74–84) los escribí yo donde el agente había inventado o traído
  datos falsos del retail (sobres comprados en la web, enviar objetos a
  otros juegos, un botón naranja que no existe); ahora explican el lobby,
  el botín con garantía y la elección de 1 carta de 3. Las descripciones de
  eventos (`eventd`) y los criterios que perdían datos son reglas, no prosa:
  salen del texto anterior con solo los nombres de clase cambiados (la
  reescritura libre había atribuido un bonus a la clase equivocada).
- **Fuera:** `GameText` (y su prueba), `npc_rename.gd` y `npc_text_fix.gd`
  (los arreglos de S23 quedan dentro de los textos nuevos). `NpcDialogs` solo
  toma de `npcdialogs.json` la estructura (respuestas, acciones, logros,
  invocaciones). La capa XML ya no carga `gui/i18n_<lang>.json`: todas las
  pantallas son nativas. En la interfaz, "Wakfu" → "Evolución" y "Kanodo" →
  "Constelación".

**Pruebas:** `own_text_test.gd` cuenta cada tipo de texto, comprueba las tres
lenguas y que ningún texto, ni de `content_` ni de `ui_`, lleve una palabra
del retail (clases, mundo, monstruos, marcas); `run_tests.sh --headless`
1520/0. En vivo contra un servidor local: `talk_smoke` 7/7,
`tutorial_smoke` 10/10 (cuenta nueva), `story_smoke` 4/4,
`achievements_smoke` 3/3, `inventory_smoke` 9/9. Capturas en
`~/codigo/capturas/s41/`.

## Cierre (2026-11-15)

Criterio cumplido: todo texto que ve el jugador sale de `ui_<lang>.json` y
`content_<lang>.json`, nuestros; el cliente no lee ninguna tabla de texto
retail. Lo que queda va a su sprint:
- **S43:** `dumpnpcdialogs` aún escribe los textos retail en el
  `npcdialogs.json` local (ya no se leen) y `gui/i18n_*.json` sigue en disco:
  se van con el borrado de `godot/assets/` retail.
- **S46:** al rediseñar hechizos, sus nombres ya son nuestros (`spell.<id>`);
  las cartas de regla que apuntan a un hechizo (`@spell:`) los siguen.
- Las descripciones de cartas y sets (lore) no se escribieron: ninguna
  pantalla las enseña.
