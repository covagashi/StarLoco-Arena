# S16 — Release pública 1.0

**Planificado:** 2026-10-16 · **Hito:** M5 — Release 1.0 · **Tamaño:** M · **Estado:** ⚪ esbozo

## Objetivo

Publicar la 1.0: cliente y servidor en una release, una instancia pública
configurada de forma segura y documentación para jugadores y operadores.

## Pipeline

- [ ] `release.yml` solo se dispara con pushes a **`v2.70`**, y el trabajo vive en
      `main-covaga`. La última release es `v0.5.1` (2026-08-27): todo lo de después
      no se ha publicado. Decidir la rama de release.
- [ ] Publicar la imagen Docker (hoy compose la construye en local), con
      `seedaccount` dentro (el README de deploy ya la da por incluida y no lo está).
- [ ] El `.exe` de Windows sin firmar: decidir.

## Instancia pública

- [ ] `limits.auto_register: false` y `limits.first_account_is_admin: false`
      (por defecto están a `true`; con el segundo, gana la carrera quien conecte
      primero).
- [ ] Copias de seguridad de la base de datos y prueba de restauración.
- [ ] Alertas mínimas (hoy hay `/health`, `/status` y pprof, pero nada avisa).
- [ ] TLS en el proxy inverso. El protocolo del juego va en claro, contraseña
      incluida, y no se puede cambiar sin romper el cliente retail. Con el
      cliente Godot sí se podría: decidirlo.

## Documentación y legal

- [ ] Los documentos se contradicen sobre el mirror del cliente:
      `DISCLAIMER.md` y `AGENTS.md` dicen que no se enlaza (y un test fija la URL
      vacía por defecto), mientras que `README.md`, `CONTRIBUTING.md`,
      `docs/QUICKSTART.md` y la tabla de `AGENTS.md` lo describen.
- [ ] `SECURITY.md` de la raíz: rellenar el contacto y revisar la frase "not
      intended for production".
- [ ] `server/docs/WEB-PORTAL.md` desactualizado (faltan legal, borrado de
      cuenta, bug reports, webhook, i18n, sitemap).
- [ ] Guía de inicio para el **cliente Godot** (`QUICKSTART.md` solo cubre el
      retail).
- [ ] Decisiones del dueño: ¿JS en el portal? ¿Seguir publicando `data-dist/` y
      `client/decompiled/`?

## Criterio de cierre

Tag `v1.0.0` con cliente y servidor adjuntos; la instancia pública responde con
la configuración segura; un jugador externo entra siguiendo solo la guía.
