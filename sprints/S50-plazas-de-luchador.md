# S50 — Plazas de luchador

**Planificado:** 2026-11-20 · **Hito:** — · **Tamaño:** S · **Estado:** ✅ cerrado (2026-11-20; qué evento da cada plaza, pendiente del dueño)

## Decisión del dueño (2026-11-20)

«El coach no debería tener más de 5 luchadores; tener 64 es muy bestia; 4
slots, se pueden desbloquear con eventos o pagando.» En preguntas:

- Al principio, 4 de serie y 5 como máximo; con Historia y Élite **juntos**.
- Visto que así no caben un trío de cada modo (3 + 3 = 6): **un cupo común
  más alto, 8 de serie y 10 como máximo.**
- Pagar, cuando exista la tienda (S30); **ahora solo eventos**.
- Qué evento da cada plaza extra: **se decide más tarde.**

## Hecho

- **Servidor:** `fighterSlots(coach)` = 8 + las ganadas (como mucho 2,
  `coaches.extra_fighter_slots`, migración 23). Crear un luchador (6000)
  cuenta todos los del coach, muertos y retirados incluidos (ocupan su plaza
  hasta resucitar o borrarse), y por encima responde el estado 20 del retail.
  Un coach que ya tenía más (antes de S50) se los queda y no crea más.
  `grantFighterSlot` es el gancho para los eventos; mientras, el comando de
  GM `/FIGHTERSLOT <coach>`. El 60001 lleva `fighter_slots` y se reenvía al
  ganar una.
- El tope de 100 del retail se queda solo como cota del protocolo
  (`readReversedIDs`).
- **Cliente:** Equipo dice «Plazas 8/8»; «Crear luchador» (y los maestros de
  clase) avisan sin abrir la pantalla si no queda plaza; el rechazo del
  servidor (estado 20) se explica igual.
- **Pruebas:** `TestFighterSlots` (8, la 9.ª rechazada, dos ganadas, tope
  10); `slots_smoke` en vivo (8/8 avisa, `/FIGHTERSLOT`, 8/9 abre).
- `seeded_smoke.sh` deja a `test` (unos 80 en la base de pruebas) con los
  luchadores que citan las siembras, para que los smokes que reclutan
  tengan plaza.

**Verificado:** `go test ./...`, `run_tests.sh --headless` (24 suites,
1544), los 49 smokes con `seeded_smoke.sh` (48 en la pasada; `ghost_smoke`,
que pide titulares de Élite, aparte tras dejarle dos).

## Pendiente (dueño)

- Qué da cada plaza extra (temporada, Historia, logros…).
- La de pago, con la tienda (S30).

## Desplegado en oracle-2 (2026-11-21)

El dueño: «hazlo». Todo lo de S46–S50 (commit `8fcf8d7c`) en la demo:
**https://alfa-pippop.covaga.dev** (y https://140.238.172.196/).

- **Servidor:** binario estático compilado aquí, imagen
  `dofusarena-2.70:s50` (`~/arena-s50/build`, mismo Dockerfile y
  `config.oracle.yaml` que S44), contenedor `deploy-arena-1` con los mismos
  volúmenes, puertos y variables. Migración 23 aplicada
  (`coaches.extra_fighter_slots`); `/health` 200.
- **Web:** export y paquetes nuevos en `/srv/pippop-demo` (los zips viejos
  siguen ahí, con otro hash: no estorban).
- **Comprobado:** `fight_load_test.mjs` contra `wss://alfa-pippop.covaga.dev/ws`:
  cuenta demo, jefe, recluta y dos combates (arenas 5 y 12) sin errores del
  motor; las dos URLs sirven el mismo manifiesto y `index.pck` que el export.
- **Volver atrás:** base en `~/arena-s50/arena.db.bak-2026-11-21` (copiada
  con el servidor parado); el contenedor anterior, parado como
  `deploy-arena-1-s44` (imagen `:s44`); la web anterior en
  `~/arena-s50/web-prev-s44`. Parar y borrar `deploy-arena-1`, renombrar el
  `-s44`, arrancarlo, y copiar la web de vuelta. Con la base de antes si
  hace falta (la migración 23 solo añade una columna).
