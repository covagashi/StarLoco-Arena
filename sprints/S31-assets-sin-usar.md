# S31 — Fuera los assets sin usar

**Planificado, abierto y cerrado:** 2026-10-25 · **Hito:** M5 — Release 1.0 · **Tamaño:** M · **Estado:** 🟢 cerrado

## Objetivo

Dueño, 2026-10-25: "quiero que quites todos los assets que no se utilizan", y
un recuento de los mapas, los muñecos y las animaciones que sí se usan.

## Cómo se decidió qué se usa

Tres auditorías del código (una por familia de assets), cruzando cada ruta
que el cliente puede pedir con lo que hay en disco. Las reglas quedan en
`tools/asset-import/prune_unused.py`, que dice en su cabecera qué código
copia cada una. Es también la nueva etapa **`prune`** de `make_assets.sh`, la
última: una regeneración ya no vuelve a traer lo quitado (`--skip prune`
para conservar la exportación entera).

- **Mapas:** solo la vista de combate dibuja un mapa (`map_gfx.gd` desde
  `fight_view.gd`), y el servidor solo sienta combates en las arenas: las
  47 de `data-dist/maps/fight` con un `.fmd` no vacío (la misma regla que
  `LoadFightMaps`). El lobby es una pantalla propia y no pinta su mundo.
- **Muñecos y animaciones:** lo que piden `fight_view`, el lobby, la
  creación, la subida de nivel y los retratos (`FACE_*`), probado como lo
  hace `_anim_probe`. Invocaciones: los aspectos de las plantillas 1–9, las
  únicas que invoca un hechizo de clase.
- **Interfaz:** ningún diálogo XML retail se abre ya (todos tienen panel
  propio); `GuiLayer` solo lee al arrancar `xml/theme/default.xml` y
  `misc/appSkin`. Imágenes: las ilustraciones de las cartas que existen en
  `cards.json`/`fightercards.json` y las carpetas que leen los paneles.
- **Efectos y sonidos:** los que alcanzan `spell_fx.json`, `spell_sfx.json`
  y los `meta.json` de las animaciones que quedan. Música: `island` y `fight`.

## Decisión: el arte de los hechizos se queda

Los gestos de lanzar hechizo (`AnimSort-*`, 828 carpetas, y los 13 conjuntos
`animsort_*`) **no se reproducen hoy**, pero por un fallo de nombres, no
porque sobren. El cliente busca la animación por el nombre del hechizo y el
arte lleva el nombre antiguo ("Bouclier" en vez de "BouclierFeca"), así que
280 de 480 lanzamientos de luchador no hacen gesto. Es arte que el juego
debería usar: se queda, y arreglar los nombres queda pendiente (abajo).

## Lo que queda (el recuento)

| | Usado | Había |
|---|---|---|
| **Mapas** | **47**, todos arenas de combate (5, 10, 12, 15, 21, 36, 38–42, 44–56, 58–61, 64–77, 81–84, 110), con 1.175 texturas | 114 mapas y 2.907 texturas |
| **Muñecos** | **38**: 24 luchadores (12 clases × 2 sexos), 9 invocaciones (8001–8007, 8009, 8010), 2 coaches (7000, 7001), 3 retratos (Nilo, Aldebrán, Demonio I) | 58 (más 3 NPC de prueba y 1 coach sin uso, entre otros) |
| **Animaciones** | **2.395** (una por acción y dirección): **1.567** que se reproducen hoy y **828** de lanzar hechizo (ver arriba), más los 13 conjuntos de efectos de hechizo por clase | 6.977 |

Por tipo: luchadores 1.928 (1.400 sin contar los hechizos), invocaciones 148,
coaches 16, retratos 3, efectos de hechizo por clase 300.

## Lo que se quitó

**435 MB y 15.797 ficheros** de 823 MB / 25.828: el árbol queda en **354 MB
y 9.906 ficheros**.

| Familia | Quitado | Queda |
|---|---|---|
| anims | 4.429 rutas (20 conjuntos enteros y las acciones que nadie pide: `AnimStatique03-Boucle/Fin/Fun`, emotes sin uso, KO, desencarnación, carrera, sentado, resurrección, piezas sueltas…), 263 MB | 239 MB |
| mapgfx | 67 mapas que no son arena y 1.732 texturas, 103 MB | 16 MB |
| gui | XML retail, cursores, fuentes y temas sin uso, el alemán, ilustraciones de hechizo, iconos de coach, mapas del viejo mapDialog…, 61 MB | 83 MB |
| fx, sounds, musics | 311 efectos, 266 sonidos y `loading.ogg`, 7 MB | 13 MB |

Lo quitado **no se borró**: está en `~/codigo/assets-sin-usar-2026-10-25/`,
con la misma estructura (y el `xps_index.json` de antes). Volver a ponerlo es
moverlo de vuelta, y todo se puede regenerar desde `client/compiled/`.

## Evidencia

- La poda sobre el árbol ya podado no encuentra nada (idempotente).
- Contra el servidor local, después de podar, sin un solo "missing":
  `fight_smoke` (dibuja mapa, luchadores, efectos y sonidos), `summon_smoke`,
  `carry_smoke`, `displace_smoke`, `world_smoke` 42/42, `story_smoke` 4/4,
  `cardmaster_smoke` 6/6, `native_panels` 138 PASS, `native_lobby` 28 PASS,
  `run_tests.sh --headless` 429/0.
- `fight_smoke` tenía tres comprobaciones atrasadas, ninguna de assets: el
  nombre del demonio (Imix desde S26), las etiquetas en inglés (ahora fija el
  inglés mientras corre y deja el idioma del jugador al acabar; lo mismo
  `tourn_offline_smoke`, que lo dejaba en español) y el letrero de la carta
  de evento ("nombre · efecto" desde S24).

## Pendiente

- **Arreglar los nombres de los gestos de hechizo** para que los 280
  lanzamientos sin gesto usen su arte (y los emotes: el servidor envía
  `AnimEmote-Effraye` y la carpeta es `-Effrayee`).
- Las pruebas viejas del motor XML (`gui_smoke`, `gui_lobby*`, `gui_result`,
  `gui_fight`, `gui_shots`, `evo_smoke`) cargan diálogos retail que ya no
  están: son de pantallas legacy y no corren en la batería.
- `make_assets.sh` compone las posturas de llevar en la clase 2 (Osamodas,
  que no lleva a nadie); la poda las quita, pero sobra la composición.
