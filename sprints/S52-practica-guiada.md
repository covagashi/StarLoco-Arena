# S52 — Práctica guiada de Nilo

**Planificado:** 2026-11-25 · **Hito:** M5 — Release · **Tamaño:** M · **Estado:** ✅ cerrado (2026-11-25)

## Decisión del dueño (2026-11-24/25)

«¿No hay pelea de práctica en la cual hay lo típico del blink indicando la
acción más un bocadillo de texto?» Hoy la práctica de Nilo (reto 46,
«Tutorial de Baan», contra el Lanudo) enseña sus 10 consejos todos seguidos
**antes** del combate, incluso «¡Genial, le has dado!» antes de dar, y dentro
del combate no hay guía.

El dueño eligió **paso a paso**: Nilo habla en un bocadillo en cada momento
y parpadea lo que hay que tocar; solo avanza cuando lo haces.

## Plan

Los textos ya existen (`npc.282`–`npc.294`, con voz propia desde S41),
incluidos los que el retail decía según lo que hacías: 290 (te moviste a
otra casilla), 291 (ya estás al lado: lanza «Presión»), 292 (fallaste el
blanco), 293 (le diste), 294 (PA y terminar turno).

| Paso | Momento | Nilo dice | Parpadea | Avanza cuando |
|---|---|---|---|---|
| 1 | Colocación | 282 + 283 + 284 | una casilla de colocación libre | mueves al luchador (o pulsas «Listo») |
| 2 | Colocación | 285 | «Listo» | pulsas «Listo» |
| 3 | Observación / inicio | 286 + 287 | la barra de turnos | sigues (botón del bocadillo) |
| 4 | Tu primer turno | 288 + 289 | la casilla delante del Lanudo | te mueves; si a otra: 290 |
| 5 | Al lado del Lanudo | 291 | «Presión» y luego el Lanudo | lanzas; si fallas: 292 |
| 6 | Le diste | 293 + 294 | el globo de PA y luego «Presión» o «Terminar turno» | lo matas o terminas el turno |

- Los consejos dejan de salir antes del combate.
- «Saltar práctica» en el bocadillo, para quien ya sabe jugar.
- Solo en este reto; el resto de combates no cambian.

## Hecho

- **Antes del combate, nada:** `main._launch_challenge` ya no pone los 10
  consejos (escenarios 200 + 201) antes de mandar el reto 46.
- **`src/fight/practice_guide.gd`:** la máquina de pasos de la tabla, sin
  escena ni red (`on_placement`, `on_placed`, `on_ready`, `on_turn`,
  `on_moved`, `on_cast`, `on_foe_died`, `on_turn_end`, `on_fight_end`,
  `next`, `skip`). Fuera de orden salta al paso que toca: «Listo» al colocar
  se salta el 2, un golpe que acierta desde el 3 o el 4 va al 6, un turno
  que empieza a tiro va al 5, un turno posterior del paso 4 dice solo 289,
  alejarse en el 5 vuelve al 4 con 290; el fin del combate y «Saltar
  práctica» lo cierran para todo el combate.
- **`src/fight/practice_overlay.gd`:** solo en el reto 46 jugado (no
  espectador ni repetición). El bocadillo: Nilo asomando por el borde de la
  pantalla, placa blanca con regla de tinta y sombra dura (estilo B), cinta
  «NILO», «PRÁCTICA · PASO n DE 6», «n / m», «Siguiente» / «Continuar» y el
  enlace «Saltar práctica». El parpadeo, como el anillo coral de la guía del
  lobby (S47): anillo en Listo / Pasar turno / la ranura del ataque / la
  barra de turnos, aro con flecha en el globo de PA, rombo coral con flecha
  que bota en una casilla. El bocadillo va a un lado y a la altura que no
  tape lo que parpadea ni al rival cuando es lo siguiente que hay que pulsar;
  se queda quieto mientras no estorbe.
- **`fight_view.gd`:** pasa los eventos reales (8020, 8022, Listo, 8028,
  8104, 4524, 8110 / 8112 / 8108, 4520, 8106, 8300) y no muestra reloj en un
  combate sin reloj (colocación y turnos).
- **Servidor (`fightrules.go`):** en un combate sin reloj de turno (regla de
  +1 h: solo el reto 46) la colocación dura lo mismo que un turno; antes eran
  30 s y la colocación se cerraba sola mientras se leía (283 promete que en
  prácticas no hay cronómetro). Sin cambios de equilibrio.
- **Textos** (`content_{es,en,fr}.json`, `ui_*`: `practice.*`).

## Desviaciones de la tabla (y por qué)

- **No hay Lanudo, ni espadachín, ni «Presión».** El reto 46 enfrenta a tus
  titulares con tantos rivales de clase como luchadores lleves, y ninguna
  clase tiene ya «Presión» (S41/S46). Los textos 282, 284, 286, 287 y
  289–294 se reescribieron con huecos que se rellenan en el combate:
  `{foe}` (el rival vivo más cercano al luchador que juega, el mismo en el
  paso 6), `{spell}` (su ataque más barato que llega a la casilla de al
  lado: golpe, luego proyectil, luego zona; si no tiene, «Golpe de arma»),
  `{ap}`, `{ap_max}`, `{mp}`. Fuera también lo falso para nuestro cliente: el
  intercambio al colocar, el botón izquierdo / derecho, la barra de turnos
  «arriba a la izquierda» (está arriba, centrada), la observación de 10 s
  (el cliente la confirma al instante).
- **Paso 4:** parpadea la casilla junto al rival si los PM llegan; si no, la
  más lejana del camino que alcanzan (llegar a ella sin estar a tiro repite
  289 el turno siguiente). Sin PM parpadea «Pasar turno».
- **Paso 6:** 293 con el globo de PA; 294 con el ataque si quedan PA para
  otro, y si no con «Pasar turno».
- **Paso 3:** «Continuar» en el turno del rival lleva al paso 4; la casilla
  parpadea cuando empieza el tuyo.

## Verificado

- `run_tests.sh --headless`: 26 suites, 1670 comprobaciones, 0 fallos (antes
  25 / 1601); `practice_guide_test.gd`: la tabla en orden, fuera de orden,
  290 / 292, cierres, qué combates lo tienen, el ataque de cada clase (las
  12 tienen uno), los 13 textos en es/en/fr sin huecos ni nombres retail,
  dónde se pone el bocadillo.
- Go: `go test ./...` en verde; `TestPlacementClockFollowsNoClockRules`.
- `test/practice_smoke.gd` (nuevo), contra un servidor propio en
  `unshare -rn`: es **33/0** y fr **33/0** — sin páginas antes; colocación
  (3 páginas, casilla), Listo, barra de turnos (2 páginas), 288/289, un
  paso a otra casilla → 290, la marcha en varios turnos hasta el rival, el
  ataque y luego el rival al armarlo, el golpe → 293 (globo de PA) y 294
  («Pasar turno», sin PA), fin de turno → se cierra; rendición → nada. Cada
  paso comprueba la página, lo que parpadea y que el bocadillo no lo tape.
  en con `--skip-at=4`: **11/0** (desaparece y no vuelve en 15 s de turnos).
  292 en vivo no sale: los luchadores de la base de pruebas solo tienen el
  arma y el servidor rechaza un golpe de arma a una casilla vacía (queda en
  las unitarias).
- `tutorial_smoke` 10/0 (su paso 8 ahora espera el combate sin páginas),
  `guide_smoke` 6/0, `fight_smoke` OK.
- Capturas 1280×720 en `~/codigo/capturas/s52/`: `es-01`…`es-28`,
  `fr-01`…`fr-28`, `en-01`…`en-08`; miradas una a una (texto legible, el
  francés cabe, lo que parpadea a la vista y en su sitio).


## Muñeco 1 contra 1 (dueño, 2026-11-25)

Viendo las capturas (todo el equipo contra 3 rivales que atacan, el paso 4
en ~15 turnos, «un golpe más y caerá» no siempre cierto), el dueño eligió
«1 contra 1 con un muñeco». Esto sustituye la primera desviación de arriba.

### Hecho

- **Servidor (`game/practice_dummy.go`, solo el reto 46):** tu primer
  titular solo, en la arena 15 (la más pequeña, 101 casillas), contra un
  muñeco de entrenamiento que pasa su turno sin hacer nada (`Dummy`: sin PA
  ni PM, iniciativa −1, así que eliges tú y abres con +2 PM). Se pone a
  3 pasos de tu casilla de salida, fuera de las zonas de salida y lo más al
  centro: la casilla de al lado queda a 2, dentro de los PM de cualquier
  clase. **Cae justo al segundo golpe, sea cual sea:** cada golpe que lo
  daña le quita la mitad de su vida máxima (redondeando arriba), crítico
  incluido; su vida es el doble del daño base de tu ataque de la lección
  (el hechizo de daño más barato que llega a la casilla de al lado, si no el
  golpe sin arma, 5), mínimo 10, así que el número que salta se parece al de
  tu ataque. Sin muerte súbita en la práctica. El resto de retos, igual.
- **Su vida en el cliente:** el cliente toma la vida máxima de la clase; para
  el muñeco el `hpLost` del 8000 cuenta desde la de su clase y el cliente
  (`ai_names.gd`) la convierte en la suya (mismos bytes, dos lados a la vez).
- **Aspecto:** la figura y el retrato del saco relleno de la Bloqueadora
  (invocación, look 8003), sin arte nuevo. **Nombre:** `npc.316` «Muñeco de
  entrenamiento» / «Training dummy» / «Mannequin d'entraînement» (el 295 ya
  era «Nilo»).
- **Textos:** 282 y 284 hablan de *tu guerrero*; 289, 291 y 292 van a por
  *el muñeco* (sin `{foe}`); 293 vuelve a decir «Un golpe más de “{spell}” y
  caerá», cierto por construcción. Repasadas las 13 páginas contra el combate
  nuevo. La guía hace parpadear al colocar la casilla de salida más cercana
  al muñeco.
- **Franja oscura con «Dios Espadachín» (es-26 de antes):** fallo de S24, no
  de S52. Al pasar una carta de evento a «antigua» se le quitaba el texto del
  efecto pero se le dejaba el ancho reservado (hasta 520 px) y el recorte; la
  tira (640 px, centrada) se salía por la izquierda como una banda oscura.
  Ahora la carta antigua recupera su ancho, la nueva se ajusta al hueco que
  dejan las otras y lo que no cabe se va, la más antigua primero
  (`es-strip-eventos.png`: cuatro cartas dentro de la tira).
- **292 en vivo:** sigue solo en las unitarias. El primer titular de la base
  de pruebas solo tiene el arma (5 PA de 6: un golpe por turno, y el servidor
  no acepta un golpe de arma a una casilla vacía).

### Verificado

- `run_tests.sh --headless`: 26 suites, 1676 comprobaciones, 0 fallos (el
  nombre del muñeco y su vida desde `hpLost`, en `practice_guide_test.gd`).
- Go: `go vet ./...` y `go test ./...` en verde. Nuevas en
  `practice_dummy_test.go`: el lanzamiento es 1 contra 1 en la arena 15, sin
  muerte súbita, eliges tú, el muñeco a 3 pasos y fuera de las salidas; desde
  cualquier salida se llega en el primer turno; cae justo al segundo golpe
  (vidas 10/11/37/400 × golpes 1/5/7/60/5000); pasa su turno sin actuar; su
  vida sigue al ataque de las 12 clases; su `hpLost` en el cable.
- `practice_smoke`: es **19/0** y fr **19/0** — todo en el primer turno
  (colocación, Listo, barra, 288/289, 290, golpe, 293/294, fin de turno) y
  el segundo golpe del turno siguiente lo derriba («tenía 5 PV tras el
  primero») y gana el combate. en con `--skip-at=4`: **11/0**.
  `tutorial_smoke` 10/0, `guide_smoke` 6/0, `fight_smoke` OK.
- Capturas nuevas en `~/codigo/capturas/s52/` (borradas las anteriores):
  `es-01`…`es-15`, `fr-01`…`fr-15`, `en-01`…`en-08`, `es-strip-eventos`;
  miradas: el saco se lee como muñeco, el bocadillo no tapa lo que parpadea,
  el francés cabe.
