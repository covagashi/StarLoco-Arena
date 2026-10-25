# Disclaimer

## Non-affiliation

This project is an **independent, non-commercial** effort for the preservation,
study, and interoperability of **DofusArena 2**, a discontinued game. It is
**not affiliated with, authorized, endorsed by, or in any way officially
connected to Ankama Games** or any of its subsidiaries or affiliates.

**DofusArena**, **Dofus**, and all related names, logos, artwork, sounds, and
game data are trademarks or copyrighted works of **Ankama Games**. All other
trademarks are the property of their respective owners.

## What is original vs. third-party

- **Original work (MIT-licensed):** the Go server under `server/` (excluding
  the data described below) and this project's documentation.
- **Original work (proprietary, all rights reserved — © 2026 Daviaan):** the
  Godot client under `godot/` (excluding the git-ignored `godot/assets/`
  described below). Not MIT-licensed; see `godot/LICENSE`.
- **Third-party / copyrighted material reproduced here (NOT licensed by this
  project — © Ankama Games):**
  - `server/data-dist/` (`data.bdat`, `indexes.bdat`, `maps/` — the latter
    holding `fight/`, `tplg/` and `env/`) — the card, spell, arena and
    **overworld-layout records** the server's own logic needs to run a fight and
    place the interactive elements players click (no art, audio, or executable
    code: `env/` carries element ids, positions and descriptors, not the sprites
    they display). This is a small (~3 MB), deliberate subset the maintainer has
    chosen to include so the server runs without requiring every operator to
    separately source a client. It ships in every downloadable release and in
    `git clone`. The project's own cards are to replace it (sprint S40).
- **Removed from the tree, still in git history** (© Ankama Games): until
  2026-10-25 this repository also carried decompiled client code with the
  mappings and analysis derived from it (`client/decompiled/`,
  `client/deobf-lab/mappings/`, `client/analysis/`). Sprint S32 removed them
  together with the reverse-engineering tooling and the asset-extraction
  scripts (`tools/`). They are no longer in the current tree or in any future
  release, but past commits still contain them; a takedown request (below)
  covers history too.
- **Not distributed by this project** (© Ankama Games):
  - The retail game client. It is not in this repository, not in `git clone`,
    not in any release archive, and not linked from the README or the release
    notes.

    **`web.client_download_url` defaults to empty**, so the software as
    published links to no copy of the client anywhere. An individual operator
    may configure a link for their own deployment — that is their decision,
    published under their own name, and it is not inherited by anyone else who
    runs this software.

    This is deliberately narrower than it once was. The default used to be a
    maintainer-hosted mirror, printed in the release notes and the README as
    well, so every operator who unzipped a release and ran it republished that
    link from their own portal without ever choosing to. The link itself was a
    defensible individual choice; making it everyone's default was not.
  - `godot/assets/` (except `ui/` and `i18n/`) — art, audio and text tables
    converted from a retail client by the removed importer, on the machines
    that still have them. Git-ignored and never committed or released; the
    project's own art replaces it (milestone M7).
  - `server/data/` — a git-ignored scratch folder for pointing a local build
    at another copy of the game data instead of the bundled `server/data-dist/`.

See [`NOTICE`](./NOTICE) for third-party attributions and [`LICENSE`](./LICENSE)
for the scope of the MIT license.

## Purpose

The decompiled references that used to live here existed solely to study the
original client and validate that the from-scratch server was wire-compatible
with it. No attempt is made to circumvent any live commercial service — the
game and its official servers are discontinued.

## No warranty

Everything here is provided "as is", without warranty of any kind. Use it at
your own risk. The authors accept no liability for any damages arising from its
use.

## Takedown requests

If you are a rights holder and believe material in this repository should not be
distributed, please open a confidential report (see [`SECURITY.md`](./SECURITY.md))
or contact the maintainer, and the material in question will be removed promptly.
You do not need to involve a lawyer to get a response.

This applies to `server/data-dist/` and any release built from it as much as to
anything else here.

A server operator running this software publishes the same commitment at
`/legal` on their own portal, together with a contact address
(`web.contact_email`).
