# Native client surfaces

This Godot 4.7.1 client reimplements DofusArena 2.70. The lobby is the shell after coach creation/login and on return from fights. The walkable hall is deprecated. Lobby panels use native Godot controls and containers. XULOR2 remains available for legacy surfaces outside the lobby migration; existing protocol handlers remain authoritative.

The user explicitly pins the login/creation visual family: Pillow-baked stone surfaces, irregular gold letter tiles, Baybayin decoration, and real Godot controls. The authored viewport is 1280×720. Mount the shell inside the UI CanvasLayer; retain chat, keyboard focus, and a reachable debug strip.

Lobby actions follow retail order: training, ranked fight, random search, evolution, duo, team. Menus retain retail ordering and logical dialog names; native factories resolve those names. Every panel must close by mouse and Escape without requiring its menu button. Coach appearance and identity come from the shared localCoach model, populated from State. Display unavailable information honestly; never invent server data.
