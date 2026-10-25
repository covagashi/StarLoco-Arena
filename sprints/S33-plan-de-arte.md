# S33 — Plan de arte: estilo, técnica y prototipo vertical

**Planificado:** 2026-10-25 · **Hito:** M7 — Arte propio · **Tamaño:** M · **Estado:** ⚪ esbozo

## Objetivo

Decidir **cómo** se hace el arte nuevo antes de hacerlo, y probarlo con una
porción mínima del juego: **un luchador, una arena, un hechizo** jugando un
combate real.

## Por qué no copiar el retail (dueño: "tantas animaciones me parecen demasiado")

El retail son sprites pintados fotograma a fotograma: 6.977 animaciones
(acción × dirección), de las que hoy se usan 1.567 (S31). En 2026 no hace
falta así:

| Técnica | Qué ahorra | Coste |
|---|---|---|
| **Personajes 3D low-poly con un rig común**, dibujados por Godot en la vista isométrica (o pre-renderizados a sprites) | las 8 direcciones salen gratis (es girar el modelo); una animación vale para las 12 clases si comparten esqueleto; la ropa y el equipo se cambian sin redibujar | modelado y rig; el estilo no es "pixel" |
| **2D por piezas (cutout) con `Skeleton2D` + IK** | 2–3 direcciones con espejo en vez de 8; una animación por esqueleto para todas las clases | dibujar cada pieza por clase y dirección |
| **VFX en tiempo real** (`GPUParticles2D/3D`, shaders, trails) en vez de animaciones por hechizo | **un solo gesto de lanzar** (o 3: corto, a distancia, potente) + un efecto por **elemento** (fuego, agua, tierra, aire, neutro) con variantes por color/escala | escribir los shaders y una librería de efectos |
| **Animación procedural** (squash & stretch, retroceso al golpe, rebote al morir, temblor de cámara) | sustituye golpe, muerte, KO y retroceso hechos a mano | ajuste fino |
| **Herramientas de IA** (conceptos, variaciones de color, texturas, ayuda en el retopo y en la captura de movimiento desde vídeo) | velocidad en conceptos y variantes | licencias y coherencia: el arte final, revisado a mano |

**Lista mínima de animaciones por personaje (propuesta):** reposo, andar,
golpe recibido, morir, lanzar (1–3 variantes), ataque cuerpo a cuerpo,
salto/teletransporte, celebrar, y llevar/lanzar solo para la clase que lo
usa. Unas **10 por esqueleto**, no por clase ni por dirección: frente a las
~1.500 de hoy.

## Tareas

- [ ] Hoja de estilo (art bible): paleta, proporciones, lectura en la vista
      isométrica, piedra y oro de la UI (S18) como punto de partida.
- [ ] Elegir técnica de personajes: 3D en Godot / 3D a sprites / cutout 2D.
      Probar las tres con el mismo luchador y decidir con capturas.
- [ ] Prototipo vertical: 1 luchador (rig + 10 animaciones), 1 arena, 1
      hechizo con VFX por elemento, en un combate real contra la IA.
- [ ] Medir: peso en disco, rendimiento en la Ally, tiempo de producción
      por personaje.
- [ ] Escribir el pipeline elegido (S34).

## Criterio de cierre

El dueño elige técnica y estilo sobre el prototipo jugando; queda escrito el
número de animaciones por personaje y la lista de VFX base.
