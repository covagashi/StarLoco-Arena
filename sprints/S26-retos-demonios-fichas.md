# S26 — Retos, demonios y fichas

**Planificado, abierto y cerrado:** 2026-10-25 · **Hito:** M6 — Un juego de hoy · **Tamaño:** M · **Estado:** 🟢 cerrado (dos propuestas para hablar con el dueño, abajo)

## Objetivo

Lo que salió del repaso de S05 y S14 con el dueño (2026-10-25):

- "Hay que arreglar eso del torneo": la ayuda dice que los torneos dan fichas
  y el servidor no pagaba ninguna.
- "Lo mejor es poner todos los retos, aunque no tengan recompensa… pues que
  den ese dinero."
- Los retos de demonio con nombres precolombinos: **opción A**, los días
  mayas (los signos del tzolk'in).
- Demonio I: fuera del lobby, con un papel menor.

## Hecho

| Qué | Cómo | Evidencia |
|---|---|---|
| **Fichas por ganar un torneo** | `tournamentWinTokens` = 500, siempre, además de la carta si la definición la trae (solo 11 y 18). Van con el mismo cobro único (`ClaimTournamentPrize`) que la carta | `TestTournamentWinPaysTokens` (sin carta y con carta, y tres reclamaciones seguidas pagan una sola vez) |
| **Fichas por un reto sin carta** | La primera victoria de un reto que no nombra ninguna carta paga `challengeTokenReward` = 100 (dos victorias de Ranking). Repetirlo no paga. Entran los 12 de los maestros de clase y los de Historia sin carta | `TestCardlessChallengePaysTokensOnce` (38 paga una vez; 33, que paga cartas, no da fichas) |
| `creditTokens` | Una sola función para dar fichas y empujar el monedero (4001); `awardFightWin` la usa | `go test ./...` en verde |
| **Todos los retos en Historia** | De los 39 de los datos: 14 ya estaban, 12 son las pruebas de los maestros de clase y 1 es de pruebas de Ankama (12, "Limero"), descartado. Los **12 sin usar** pasan a dos capítulos nuevos: **4 · Pruebas de maestría** (6, 9, 11, 15) y **5 · Contrarreloj** (los ocho "Desafío de tiempo", 37–44). Cada uno con su equipo (`trialChallengeBreeds`), temático por el nombre y creciendo hasta el último (4 luchadores) | `TestTrialChallengesFieldTheirOwnTeams`, `TestStoryChallengesMatchClient`; `story_smoke` 4/4 ("26/26 rows") |
| **Los Señores del Tiempo** | Los seis demonios del tiempo, con nombres mayas en el orden en que se combaten: Imix (minuto 58), Ik' (52), Ak'bal (46), K'an (25), Chikchan (12, el jefe) y Kimi (segundo 37, Bernabé). Iguales en es/en/fr. El cliente los cambia en `npc_rename.gd` (nombres, títulos de los retos —"Desafío de Imix"…— y todas las frases que los nombran, con artículo: "el demonio del minuto 12" → "Chikchan"); el servidor, en el nombre del rival en combate. El capítulo 2 se llama ya "Los Señores del Tiempo" | `world_smoke` 43/43 (los seis con su nombre); un barrido de `npcdialogs.json` con la tabla nueva no deja ninguna forma vieja |
| **Demonio I, narrador del capítulo 2** | Fuera del panel de Servicios. Sus tres frases (251–253) van antes del primer combate contra Imix, y su felicitación (254) sale al volver al lobby tras ganar a Chikchan, que es cuando se vuelve a pedir la lista (60020). Ahí se informa también el criterio 218 ("haber hablado con el demonio I"). La 255 (la carta de zaap a las islas) se quita: no hay islas | `narrator_smoke` 5/5 (entrada, cierre con el 218, no se repite, el lobby pide la lista, 0 botones en Servicios) |

Suites: `go test ./...` en verde; `run_tests.sh --headless` (429 checks, 0
fallos); `native_panels` 138 PASS en xvfb; `world_smoke` 43/43;
`story_smoke` 4/4; `narrator_smoke` 5/5.

## Para hablar con el dueño

### Torneos sin conexión: que juegue la IA

Hoy un combate de torneo es **en vivo**: los dos coaches tienen que estar
conectados en el periodo de búsqueda (28611). Con poca gente, el cuadro se
queda parado o se resuelve con exenciones.

**Propuesta:** torneos sin conexión, sobre lo que ya hay de fantasmas
(S12–S14):

- Al inscribirte entregas un **equipo y sus reglas** (el editor de S13), como
  un fantasma.
- A la hora del torneo, el **servidor juega todo el cuadro** IA contra IA. Los
  combates de fantasmas ya son deterministas: semilla, arena y hash.
- Al entrar ves el cuadro resuelto y puedes **ver cada combate como replay**
  (S11), la final incluida.
- Premios, iguales: fichas y la carta, si la hay.

Ventajas: funciona con 2 jugadores, no hay que coincidir en hora, y no hay
que escribir nada nuevo de combate.

Por decidir: ¿todos los torneos sin conexión, o se deja algún torneo en vivo
(por ejemplo, la final)? Mi recomendación: **todos sin conexión**; uno en
vivo, solo como evento especial más adelante.

### Cartas: el juego era de pago para ganar

En el retail, las cartas buenas se compraban con dinero real, y por eso las
de los sets no tienen precio en fichas: solo se truecan. Aquí no puede haber
nada de pago que dé ventaja (S21).

**Propuesta:**

- **Las cartas se ganan jugando**, nunca con dinero real: combates, retos,
  torneos, fusión y trueque.
- **Fichas** (se ganan jugando) → compran **cartas** en los Card Master.
  Precio en fichas = el valor de trueque / 100, con un mínimo de 10. Con los
  datos actuales, una carta de set va de 10 a 490 fichas (de una a diez
  victorias). El trueque se queda como alternativa.
- **Pesetas** (premio de temporada, S25; en el futuro, quizá de pago) →
  **solo cosméticos**. Nunca compran cartas ni fichas.
- El Bazar de fichas sigue vendiendo lo que ya tenía precio.

Por decidir: la fórmula del precio (o una tabla por rareza), y si las fichas
deben poder comprar todas las cartas o solo las de los Card Master.
