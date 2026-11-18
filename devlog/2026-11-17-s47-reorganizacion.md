# 2026-11-17 — S47: reorganización 1 (reclutar, torneos, iconos)

El dueño, a las tres preguntas tras el mapa: "sí a las tres, hazlo".
Detalle en `sprints/S47-feedback-alfa.md` (Reorganización 1).

## Qué se hizo

- **Reclutar**, pantalla propia (`src/ui/recruit_screen.gd`) en lugar del
  modal: 12 clases con retrato, sexo y modo explicados, figura grande,
  dificultad, roles, descripción propia y los 10 ataques. Las losetas y el
  Entrenamiento sin luchadores llevan directo aquí. Espera la respuesta del
  servidor (error en pantalla, éxito cierra y avisa). Aspecto pulido por un
  agente Fable (peana con nombre y botón, retratos con aro, medallones).
- **Torneos** en un solo sitio: el Calendario es ahora Torneos con Mis
  torneos, Calendario y Clasificación. Equipo y Clasificación pierden sus
  pestañas de torneos; el torneo clásico juega con el equipo de Élite.
- **Iconos**: Estadísticas pasa a pestaña de Logros; el hueco es Amigos
  (icono nuevo en el atlas); el bocadillo abre el Buzón, que sale de
  Servicios.

## Verificado

- `test/s47_smoke.gd` 19/19 en vivo (reclutar Historia y Élite con nombre
  vacío, rechazado y bueno; Torneos; Logros; iconos).
- `run_tests.sh --headless` 1492/0 y `--visual`; smokes `modes`, `colours`,
  `coach_turn`, `mailbox`, `story`, `tournaments` (sembrado) en verde.

## No verificado / encontrado

- `totems_smoke` falla 4/4 también antes de estos cambios: smoke viejo,
  BACKLOG §8.
- La línea de error de Reclutar se vio en vivo (texto), su aspecto final
  solo por maquetación.

## Más tarde: punto 16 ("sigue")

"Equipo del luchador" → **Hechizos y cartas** (en español "equipo" es
también el plantel). El valor se explica y desglosa (600 de clase + cartas),
se mueve en vivo al probar cartas, y el 6000 deja de parecer un tope por
luchador: es del equipo (o el de la liga en Ranking). Columna Valor en
Equipo. Un label con ajuste tardío ensanchaba el panel a 1807 px: arreglado.
`s47_smoke` 22/22, `loadout_smoke` 7/7, unidad 1492/0.

## Más tarde: punto 1, los ojos teñidos

El blanco de los ojos de la coach entraba en la máscara de pelo
(`coach_masks.py`: claro + por encima del cuello). Ahora el ojo (iris
saturado) y su blanco quedan fuera; el pelo, igual que antes. Comprobado con
`test/coach_face_preview.gd` (caras de cerca, pelo verde y rojo). Falta la
parte de arte del punto 1 (mallas a ~40k triángulos).

## 2026-11-18: coach de 40k, prueba de carga web, guía e inventario

- Coach hombre a 40k desde el original nuevo de Meshy (610k, pose en A):
  pipeline con `--lower_arms` y `--weld_normals`; +0,9 MB de primera carga,
  misma memoria. No adoptado aún (dueño).
- `tools/web/load_test.mjs` y la marca web `window.__pippop`. Tiempos
  absolutos inválidos: la Ally estaba cargada por otras sesiones.
- Punto 4: la guía del lobby (`guide_smoke` 6/6, nuevo y `test`).
- Punto 12: inventario como pantalla propia con álbum de colecciones
  (`inventory_smoke` 6/6).
- Para seguir: «Dónde retomar» al final de `sprints/S47-feedback-alfa.md`.
