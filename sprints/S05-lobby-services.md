# S05 — Lo que se perdió con el hall

**Planificado:** 2026-10-16 · **Hito:** M1 — Jugable de punta a punta · **Tamaño:** M · **Estado:** ⚪ esbozo

## Objetivo

Cuando se deprecó el hall caminable (`godot/deprecated_hall/`), el acceso a
varios servicios del juego se fue con él. En el retail se llega a ellos haciendo
clic en un elemento del mapa; en el cliente Godot ese camino era
`main._use_element()` (`src/main.gd`), y hoy solo lo llama `test/world_smoke.gd`.
Este sprint los devuelve al jugador.

## Lo que probablemente no se alcanza hoy (sin verificar uno a uno)

Card Master (tienda y trueque), buzón, cementerio, fusión, Zaap, tótem demoníaco
(afiliación), NPCs que hablan (árboles de diálogo), fuegos artificiales.

Siguen accesibles por chat: `/trade` (intercambio) y `/watch` (espectador).

## Decisión previa (dueño)

**¿Entradas en el lobby o revivir el hall?** Por defecto, entradas nativas en el
lobby (botones o un menú "Ciudad"), reutilizando los handlers que ya existen.
Revivir el hall devolvería también el paseo, los zaaps y los disparadores de zona
del tutorial, pero es mucho más trabajo (ver `deprecated_hall/README.md`).

## Tareas candidatas

- [ ] Auditoría: para cada servicio, ¿se llega desde la UI viva? Probarlo, no
      deducirlo.
- [ ] Una entrada nativa por servicio, con su panel.
- [ ] Zaap: hoy es un no-op explícito (`main.gd`). Destinos y viaje.
- [ ] Cartas especiales 21–23 (renombrar, fuegos artificiales…), hoy sin soporte.
- [ ] NPCs: árboles de `npcdialogs.gd` accesibles sin caminar.
- [ ] `test/world_smoke.gd` reescrito contra las entradas nuevas.

## Criterio de cierre

Cada servicio de la lista se usa de principio a fin contra un servidor real, con
captura o prueba que lo demuestre, o queda descartado por escrito.
