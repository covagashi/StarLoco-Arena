# S28 — Economía de cartas

**Planificado, abierto y cerrado:** 2026-10-25 · **Hito:** M6 — Un juego de hoy · **Tamaño:** S · **Estado:** 🟢 cerrado

## Objetivo

La propuesta de S26, aprobada por el dueño ("2 ok"). En el retail las cartas
buenas se compraban con dinero real, y por eso las de los 12 sets de los
Card Master no tienen precio en fichas: solo se truecan. Aquí nada que ayude
a ganar se paga:

- **Las cartas se ganan jugando:** combates, retos, torneos, fusión y trueque.
- **Fichas** (se ganan jugando) → compran **cartas** en los Card Master.
- **Pesetas** (premio de temporada, S25) → **solo cosméticos**. Nunca cartas
  ni fichas.

## Decisiones (delegadas: "hazlo", 2026-10-25)

| Decisión | Tomada | Por qué |
|---|---|---|
| Precio | `max(10, valor de trueque / 100)` fichas, solo para las cartas de los sets 5–16 que no traen precio y tienen valor | la propuesta aprobada. Con los datos: de 10 a 490 fichas, es decir, de 1 a 10 victorias de Ranking (50 cada una) |
| Una carta que ya tiene precio en los datos | lo conserva | no se pisa el dato retail |
| Valor 0 | sigue sin poder comprarse | la defensa de B-151 (nada gratis por el 5450) sigue igual |
| El Bazar de fichas | sigue con su catálogo de 143 cartas; las cartas de set se quedan en su Card Master | si no, el Bazar repetiría las 12 tiendas |
| Dónde vive la regla | en el código, en los dos lados (`gamedata/token_prices.go` y `cards.gd`), y no en los JSON exportados | los assets los genera cada jugador desde su retail (S15); un dato nuevo ahí obligaría a regenerarlos. `dumpcards` y el studio siguen viendo el dato crudo |
| El trueque | se queda como alternativa | |

## Hecho

- Servidor: `ApplyCardMasterPrices` al cargar el catálogo del juego
  (`LoadBundle`); `cardMasterStock` deja las cartas de set fuera del Bazar.
- Cliente: `Cards` aplica la misma regla al leer `cards.json`; el Card
  Master muestra el precio y activa "Comprar". `city.desc.1` vuelve a decir
  que se compra con fichas.

## Evidencia

- `TestDerivedTokenPrice`, `TestApplyCardMasterPrices`,
  `TestTokenPriceMatchesClient` (los cuatro números, iguales en `cards.gd`),
  `TestCardMasterSetCardBuysWithTokens` (5450 de punta a punta: 500 → 426
  por una carta de valor 7400; el Bazar no la vende). `TestCardMasterStockIsItsCardSet`
  se actualiza: el Bazar ya no repite las cartas de set.
- En vivo, `cardmaster_smoke` 7/7: "buy — Jalabotas 0 → 1". En el log del
  servidor, `cost=map[1:10]` (valor 79 → el mínimo), y el monedero de `test`
  baja de 1150 a 1140.
- `go test ./...` en verde; `run_tests.sh --headless` 429/0.
