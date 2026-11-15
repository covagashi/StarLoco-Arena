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
  `server/content/`) and this project's documentation.
- **Proprietary, all rights reserved — © 2026 Daviaan:** the Godot client
  under `godot/` (see `godot/LICENSE`) and the game data under
  `server/content/` (see its `LICENSE`). Not MIT-licensed. The data in
  `server/content/` (cards, spells and the other rules tables) started from
  the retail tables' ids and values, frozen as JSON in sprints S40 and S43,
  and is being redesigned from there.
- **Removed from the tree, still in git history** (© Ankama Games): until
  2026-11-15 this repository carried `server/data-dist/` (`data.bdat`,
  `indexes.bdat`, `maps/`), a small subset of the retail card, spell, arena
  and overworld-layout records the server read; sprint S43 removed it once the
  game read only its own data. Until 2026-10-25 it also carried decompiled client code with the
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
  - Art, audio and text tables converted from a retail client by the removed
    importer. They were git-ignored and never committed or released, and since
    S43 the client no longer reads them: its art, sounds and texts are the
    project's own (milestone M7).

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

This applies to the git history (including the removed `server/data-dist/`)
and every past release as much as to anything else here.

A server operator running this software publishes the same commitment at
`/legal` on their own portal, together with a contact address
(`web.contact_email`).
