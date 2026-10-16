# Sprints

El roadmap del proyecto: qué queda por hacer y qué se hizo en cada tanda.

| Documento | Responde |
|---|---|
| [`BACKLOG.md`](./BACKLOG.md) | la cola de trabajo viva, sin plazos — lo que queda por coger |
| `SNN-slug.md` (índice abajo) | **qué se hizo en cada tanda y con qué evidencia** |
| [`server/docs/BUGS.md`](../server/docs/BUGS.md) | el log de bugs `B-NNN`, con causa raíz y verificación |
| [`devlog/`](../devlog/README.md) | el diario del agente: qué hizo en cada sesión y qué encontró |

Los comentarios de código que citan "ROADMAP item N" o "ROADMAP §N" apuntan al
`ROADMAP.md` heredado de la base del fork, retirado el 2026-10-16 para no
confundirlo con este directorio. Sigue legible: `git show v2.70:ROADMAP.md`.

## Convención

- Un fichero por sprint: `SNN-slug.md`, con objetivo, alcance, tareas y
  **criterio de cierre**.
- Un sprint se abre cogiendo ítems de `BACKLOG.md`; al cerrarlo, se marcan
  allí como hechos con el enlace al sprint.
- Al cerrar, el mismo fichero se completa con la sección *Resultado* — qué se
  hizo, qué no, y los comandos que lo demuestran. No se abre un fichero de
  informe aparte.
- Nada se marca `[x]` sin evidencia reproducible: código de salida de una
  prueba, salida de comando, o entrada `B-NNN` en el log de bugs.

Esa última regla existe por una razón concreta: buena parte del trabajo del
cliente la generó un agente, y los mensajes de commit afirmaban verificaciones
que nadie había vuelto a correr. Resultaron ciertas, pero se comprobaron **a
posteriori**. El criterio ahora es que la evidencia vaya en el sprint.

## Índice

| Sprint | Estado | Tema |
|---|---|---|
| [S01](./S01-client-test-net.md) | 🟢 cerrado | Red de pruebas del cliente + raíz de assets (B-173, B-174, B-175) |
| [S02](./S02-studio-tooling.md) | 🟢 cerrado | Tooling del stack en el studio: pnpm, oxlint, oxfmt, knip, lane de CI |
