# 2026-11-25 — S52: la práctica guiada de Nilo

El coordinador pidió implementar `sprints/S52-practica-guiada.md` (el dueño
eligió «paso a paso»). Detalle, desviaciones y cifras en el sprint.

## Qué se hizo

- **Cliente:** los consejos de Nilo dejan de salir antes del reto 46 y salen
  dentro del combate: `src/fight/practice_guide.gd` (los 6 pasos, fuera de
  orden incluido) y `src/fight/practice_overlay.gd` (bocadillo con su retrato,
  «Siguiente» / «Continuar» / «Saltar práctica», parpadeo coral en la casilla
  o el control que toca); `fight_view.gd` le pasa los eventos reales y no
  enseña reloj en un combate sin reloj.
- **Servidor:** en un combate sin reloj de turno (solo el reto 46) la
  colocación dura lo que un turno, no 30 s.
- **Textos:** 282, 284, 286, 287 y 289–294 en es/en/fr sin el Lanudo, el
  espadachín ni «Presión» (no existen en nuestro combate), con huecos para el
  rival, el ataque y los PA/PM del luchador que juega.
- **Pruebas:** `practice_guide_test.gd` (unitarias) y `practice_smoke.gd`
  (es y fr de principio a fin con capturas, en con «Saltar práctica»);
  `tutorial_smoke` ajustado (ya no hay páginas antes del combate).

## Encontrado por el camino

- El reto 46 no es «tu espadachín contra un Lanudo»: son tus titulares contra
  tantos rivales de clase como luchadores lleves, y los rivales atacan. La
  guía sigue al luchador tuyo que juega y a su rival más cercano.
- Dos smokes a la vez en `unshare -rn` se pisan el `xvfb-run -a` (los
  sockets abstractos de X van por espacio de red): uno tras otro.

## Sin verificar

- La página 292 (fallar el blanco) en vivo: los luchadores de la base de
  pruebas solo tienen el arma y el servidor no acepta un golpe de arma a una
  casilla vacía. Probada en las unitarias.

## Después: muñeco 1 contra 1

El dueño, viendo las capturas, eligió «1 contra 1 con un muñeco». El reto 46
es ahora tu primer titular contra un muñeco que no actúa, en la arena 15, a
un turno de distancia, que cae justo al segundo golpe (cada golpe le quita
la mitad). Figura: el saco de la Bloqueadora (look 8003); nombre `npc.316`.
Textos 282/284/289/291–293 ajustados. De paso: la franja oscura de las
cartas de evento (fallo de S24: las cartas antiguas guardaban el ancho del
efecto) y la muerte súbita, apagada en la práctica. 292 en vivo sigue sin
salir (el luchador de pruebas solo tiene el arma).
