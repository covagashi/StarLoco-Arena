# S41 — Textos propios

**Planificado:** 2026-10-25 · **Hito:** M7 — Arte propio · **Tamaño:** M · **Estado:** 🔵 en curso (pasos 1–2 hechos, 2026-11-15)

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

### Pendiente en S41

- Las **descripciones** de las cartas (`content.24`, lore) y de los sets
  (`content.26`): el cliente nativo no las enseña; se escriben si alguna
  pantalla las necesita.
- Eventos, logros, retos, NPC, ayuda, tutorial e historia, como dice el
  alcance. Después, quitar `GameText` (lo usan aún hechizos, S46, y los
  nombres de los demonios) y los `gui/i18n_*.json` retail.
