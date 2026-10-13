# Sprints

Seguimiento por sprint del trabajo en curso. Complementa, no sustituye:

| Documento | Responde |
|---|---|
| [`ROADMAP.md`](../ROADMAP.md) | *qué funciona* del servidor, feature por feature |
| [`server/docs/BUGS.md`](../server/docs/BUGS.md) | el log de bugs `B-NNN`, con causa raíz y verificación |
| [`pendiente/README.md`](../pendiente/README.md) | la cola de trabajo viva, sin plazos |
| **este directorio** | **qué se hizo en cada tanda y con qué evidencia** |

## Convención

- Un fichero por sprint: `SNN-slug.md`, con objetivo, alcance, tareas y
  **criterio de cierre**.
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
