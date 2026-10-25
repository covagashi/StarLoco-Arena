# S25 — Temporadas

**Planificado:** 2026-10-25 · **Abierto y cerrado:** 2026-10-25 · **Hito:** M6 — Un juego de hoy · **Tamaño:** M · **Estado:** 🟢 cerrado

## Objetivo

Dar un ciclo a los ladders: temporadas con principio y fin, un premio para el
top y un reinicio suave al empezar la siguiente. Cierra las dos decisiones que
S14 dejó abiertas (dueño, 2026-10-25).

## Decisiones del dueño

- Al cerrar una temporada, el top gana **pesetas**, una moneda **solo para
  cosméticos** (S28: nunca compran cartas ni fichas).
- El Elo no decae con el tiempo: **reinicio suave** al empezar cada temporada.
- Pesetas y fichas son **monedas distintas**.

## Decisiones (delegadas: "hazlo", 2026-10-25)

| Decisión | Tomada | Por qué |
|---|---|---|
| Duración | **mes natural**, en UTC; acaba el día 1. Si al abrir quedan menos de 14 días, dura hasta el día 1 del mes siguiente | un calendario que todos entienden; la primera temporada (abierta el 25 de octubre) no es de 6 días |
| Ladders | **los dos**: el Ranking 1 contra 1 (Strength) y el de fantasmas (Elo), cada uno con su premio | el hub los presenta juntos como "Ranking" (S20B), y el dueño hablaba del de fantasmas |
| Premios | **1.º 500 · 2.º–3.º 300 · 4.º–10.º 150 · 11.º–50.º 50** pesetas, por ladder | el top 50 es lo que ya muestra la clasificación (S14) |
| Reinicio | cada valoración, **a medio camino de la base**: Strength hacia 1000 (su mínimo), Elo hacia 1000. 1400 → 1200; un Elo de 800 sube a 900 | "reinicio suave"; nadie pierde el puesto relativo |
| Moneda | tipo **10** en la cartera (el retail usa 1, 2, 3 y 5) | no choca con nada retail; sin icono retail, se muestra "pesetas" |
| Aviso | 60031 al llegar al lobby (y en el momento si estás conectado al cierre): un toast y una línea en el registro por cada resultado; al enviarse, quedan vistos | |
| Atomicidad | el cierre (resultados, pagos, reinicio y marca de cerrada) va en **una transacción**; un cierre repetido no hace nada | que un fallo a medias no pague dos veces |

## Hecho

- **Servidor:** `domain/season.go` (temporada, resultado, premios, reinicio,
  límites del mes), migración 17 (`seasons`, `season_results`),
  `store/seasons.go` (abrir, cerrar en una transacción, resultados sin ver),
  `game/seasons.go` (el programador cada minuto desde `cmd/server`, el aviso
  60030/60031). Al cerrar, la Strength en memoria de los conectados también
  se reinicia; si no, su siguiente combate deshacía el reinicio. Borrar un
  coach borra sus resultados.
- **Cliente:** 60031 → el modelo `season` y los avisos; el Ranking (pestaña
  1 contra 1) y la clasificación de fantasmas dicen "Temporada N · termina en
  D días · el top 50 gana pesetas"; las pesetas se ven en la cartera.

## Evidencia

- `TestSeasonClosePaysResetsAndOpensTheNext`: abre la 1; no paga antes de
  tiempo; al pasar el fin paga los dos ladders (500 + 500 al que es 1.º en
  los dos), reinicia Strength y Elo (también la Strength en memoria de un
  conectado), abre la 2 y le manda el 60031 con sus dos resultados; un tick
  repetido no paga otra vez. Esta prueba encontró un fallo: el aviso salía
  antes de abrir la siguiente y decía "temporada 0". Arreglado.
- `TestSeasonPrize`, `TestSoftReset`, `TestSeasonBounds`.
- `go test ./...` en verde en SQLite; store y game también en **PostgreSQL 16
  y MariaDB 11** (podman, local).
- En vivo, con la base de pruebas: al arrancar se abre la temporada 1 (fin
  2026-12-01). Se fuerza el fin al pasado y se reinicia el servidor. Log:
  "season closed season=1 paid=3", "season opened season=2". En la base,
  `test2` cobra 1000 (1.º en los dos) y `test` 300 (2.º en Ranking);
  Strength 1150 → 1075 y Elo 940 → 970.
- `season_smoke` 2/2 antes del cierre ("Temporada 1 · termina en 37 días")
  y 4/4 después: temporada 2, el toast "Temporada 1 terminada: 2.º en
  Ranking · +300 pesetas", la cartera con 300 y, pedido otra vez, sin
  repetir el aviso.
- `run_tests.sh --headless` 429/0; `native_panels` 138 PASS.

## Pendiente

- Algo en que gastar las pesetas: la tienda de cosméticos (ver "compras
  dentro del juego", la propuesta al dueño del 2026-10-25).
