# S11 — Replays y espectador

**Planificado:** 2026-10-16 · **Hito:** M3 — Paridad de contenido · **Tamaño:** M · **Estado:** ⚪ esbozo · **Alcance por decidir**

## Objetivo

El retail guarda replays (`replayDialog`, `replayIdentificationCertificate`, la
opción "guardar replay") y tiene un modo observador (`fightObservation`). En el
cliente Godot, `setSaveReplay` no hace nada; el espectador en vivo funciona
(`/watch`), aunque es de solo lectura.

## Decisión previa (dueño)

¿Replays completos como el retail (grabar y reproducir), o basta con el
espectador en vivo? Por defecto: grabar y reproducir los combates propios. Para
el marketing de S04 (clips de combates en 1 bit) los replays son muy útiles:
permiten volver a renderizar un combate con otro estilo.

## Para retomar (2026-10-23)

S10 se cerró en la sesión anterior y S11 quedó como siguiente, sin abrir. La
investigación previa (cómo grababa el retail sus replays, el modo observador
y si `fight_view.gd` se puede alimentar con un flujo grabado sin socket) se
cortó por el límite de uso. Lo único que llegó a ver: hay ficheros de replay
de ejemplo reales en el repo. Hay que empezar por ahí. Las decisiones se
toman por heurística y se anotan en el sprint (ver la memoria
"autonomous-sprints").

## Tareas candidatas

- [ ] Formato de replay: ¿el del retail (su carpeta `replays/`) o uno propio a
      partir del flujo de mensajes del combate?
- [ ] Grabar al jugar y reproducir desde un panel.
- [ ] Espectador: entrar desde la UI, no solo por chat.

## Criterio de cierre

Un combate grabado se reproduce entero en el cliente y coincide con lo que pasó.
