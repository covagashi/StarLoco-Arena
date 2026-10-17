# DofusArena 2.70 — Overworld (worlds, islands & NPCs)

Reverse-engineered from the **complete retail client** at
`E:\Projets\DofusArena2-06\client\compiled` (2015 build). This is the client whose
decompiled sources live in `client/`. The **incomplete** client under
the 2.04b client (`client/compiled/` on the **`v2.04`** branch) is a different build that ships **no** map env/tplg/gfx data
and therefore renders no NPCs — do not use it for this work.

> Purpose: understand the overworld so the Go server can drop a coach onto the
> correct starting island and reproduce the intro NPC ("Hey ! Toi là bas !").

## How the client loads a world (recap)

On `ENTER_WORLD_INSTANCE` (opcode **4600**) the server sends
`[f32 x][f32 y][i16 dir/alt][i16 worldId][u8 dynamic]`. The client uses the
**`worldId`** field (NOT the coach's map id) to stream three per-chunk layers
from disk:

| Layer | config key | path |
|---|---|---|
| graphics | `mapsGfxPath` | `contents/maps/gfx/<worldId>.jar` |
| topology (walk/altitude) | `mapsTopologyPath` | `contents/maps/tplg/<worldId>.jar` |
| environment (NPCs, sounds, particles) | `mapsEnvironmentPath` | `contents/maps/env/<worldId>.jar` |

Registered worlds come from `worldInfoFile` = `contents/maps/data.jar!/worlds.lib`.

- **`worlds.lib`** format: `i16 count` then `count × { i16 worldId, i32 field,
  i16 parentField }`, **little-endian**. Retail has **89** worlds. The `field`
  values (`0` or `0xFF000000`) and `parentField` (mostly `-1`) are flags/color,
  **not** a start-world hierarchy.
- Registered world ids: `5, 10, 12, 15, 21, 23–29, 35–113` (there is **no world
  0/1/2** in `worlds.lib` — the server currently sends `worldId 0`, which does
  not exist).

### Environment chunk file format (per `<world>.jar` entry `chunkX_chunkY`)

A chunk is 18×18 world cells; `chunk = floor(cell / 18)`. Big-endian.

```
byte  version = 0
i16   chunkX
i16   chunkY
byte  particleCount   ; particle records
byte  soundCount      ; sound records
byte  ambianceCount   ; i32×count ids, then byte(0 | 81) + 81-byte 2-bit bitmask
byte  interactiveCount; aEG records  <-- NPCs
byte  dynamicCount    ; dynamic-element records
```

**`aEG` (InteractiveElementDef):**
```
i64  instanceId
i16  type            ; 15 = NPCTalker (ni_0)
u8   viewCount
i32 × viewCount      ; view ids (sprite lookup via rb_0 views table)
i16  payloadLen
byte × payloadLen    ; aJj part-table payload (parts: amp_2, RU spawn+name, rv_0)
u8   bool
i16  (=-1 default)
```

The NPC **descriptor** is the `RU` part's u16-length-prefixed UTF-8 name, a
`;`-joined string parsed by `ni_0.gi()`:

```
field[0] = contentId    ; NPC name  → content.29.<id>  (and content.28.<id> = internal name)
field[1] = conditionSpell (-1 = none)
field[2] = dialogNodeIfConditionFalse
field[3] = dialogNodeIfConditionTrue
field[4] = guiStyle (string)
```
Descriptors can carry more than 5 fields for multi-dialog NPCs (e.g. Démon III's
challenge list). `type=15`, and a **non-empty viewCount is required** for the
NPC to have a sprite (view ids resolve to gfx via the interactive-elements
template `contentInteractiveElementsTemplateFile`).

## The intro cutscene — it is a Lua SCENARIO, not a static NPC

**Corrected finding.** The intro dialogues ("Aïe ! Aïe aïe !", "Y'a deux trois
choses…", "Hey ! Toi là bas !") are **Lua scenario scripts**, run on a **dynamic
instance** (the `dynamic=true` flag of opcode 4600), not static env NPCs. They
live in `contents/data.jar!/scripts/scenario/*.lua`:

| Scenario | Content | Screenshot |
|---|---|---|
| `scenario/0.lua` | **Adamaï capture cutscene** — `content.29.90–97` ("Aïe ! Aïe aïe !"). Spawns Adamaï via `Actor.createActor(10, 2500, 5,5,1, 4)`, camera pan, ends `Context.tutorialChangeInstance()`. | 1st screenshots |
| `scenario/1.lua` | **Adamaï lands in Hormonde** — `content.29.98` ("Y'a deux trois choses…") + 147–149. | 2nd screenshot |
| `scenario/99.lua` | **"Hey ! Toi là bas !"** — `BubbleText.prepareQuestion("content.29.308","SOUTH",0,150,"useRightClick","useLeftClick")`, opens the `bob_interface` character displayer; ends `Actor.runInteractiveElementSpecialAction(elementId)`. | video screenshot |

`content.29.308` is **not** in any static env descriptor (verified across all 114
env jars). It is emitted purely by scenario 99.

### How scenarios are triggered (`anr_0`)

`anr_0.a(scenarioId, eventId, long[] args, isReward)` runs the Lua function
`event_<scenarioId>_<eventId>` in `scenario/<scenarioId>.lua`
(`anr_0.java:49-62`). Two client triggers exist:

- **ZoneTrigger** (`oq`, interactive-element type, action `avr_0.dgp`): descriptor
  `scriptId;requiredAchievement;disablingAchievement`; runs the scenario when the
  coach **walks onto** the element (`oq.java:29-35, 60-70`).
- **DemonChallenge** (`pn_0`, element **type 7** via `asi.cRl` → `amt_0`):
  descriptor `name;scenarioId;…`; runs the scenario **on click**
  (`pn_0.java:33-37, 82-96`).

Both are interactive elements loaded from a world's env layer, whose descriptor's
`scenarioId` field points at a `scenario/*.lua`. **No static env descriptor
referencing scenario 99 was found** in the shipped worlds, so the intro element is
spawned dynamically (server-driven) on the tutorial's dynamic instance.

> Reproducing the intro therefore needs the server to: (a) put the coach on a
> **dynamic instance** (4600 `dynamic=true`), and (b) drive the scenario/zone
> triggers. That is a sizeable feature (dynamic instances + a scenario trigger
> message + achievement gating) — not yet implemented.

### Static demon NPC on world 79 (for reference)

World 79's env **does** contain **Démon I** (`content.29.261`, `content.28.261 =
"DEMON1_NAME"`, guiStyle `demon1`) at chunk `0_1`, world cell ≈ (15, 22),
descriptor `261;-1;65;65;demon1`. But dialog node 65 (`content.59.65`) is *"EH
TOI ! que fais-tu ici… va voir mes serviteurs les démons des minutes"* — a
**different** line, **not** content 308. So Démon I is a normal overworld NPC,
not the scripted intro.

## NPC census (all worlds with interactive elements)

Extracted from `contents/maps/env/<world>.jar`. `Name` is `content.29.<field0>`.

| World | Role | Chunk | Descriptor | NPC (content.29.field0) |
|---|---|---|---|---|
| **79** | **Demon island / START** | **0_1** | `261;-1;65;65;demon1` | **Démon I — the intro NPC** |
| 79 | " | 0_0 | `263;112;35;268` | Démon de la 52ème minute |
| 79 | " | 0_2 | `264;113;36;269` | Démon de la 46ème minute |
| 79 | " | 1_0 | `262;111;34;267` | Démon de la 58ème minute |
| 79 | " | 1_0 | `266;0;33;271;274` | Démon de la 12ème minute |
| 79 | " | 1_2 | `265;114;32;270` | Démon de la 25ème minute |
| 37 | Demon island (challenges) | 7_6 | `261;251;252;253;254;255` | Démon I (with 5 challenge dialogs) |
| 37 | " | 7_6 / 7_7 / 8_5 / 8_6 / 8_7 | 263/264/262/266/265 | the five minute-demons |
| 23 | Démon III island | -3_-5 | `144;117;13;16;14` | Démon III |
| 23 | " | 3_-8 | `145;146;3` | Tofu de SuperBidi |
| 23 | " | -4_-4 | `281;117;45;280` | Démon de la 37ème seconde |
| **35** | **Recruitment / tutorial island** | 6_7 | `144;152;153;167;169;168;273;29;30;31` | Démon III (recruit + 3 challenges) |
| 35 | breed masters | 3_6…6_9 | `170..181;…;154;…` | Pépitox, Guitel, Ed eraser, Dzee, Gus, Pataclop, Grüny, Stalad, Lithian, Ewon, Cicatrine, Rutger |
| 35 | tutorial hint NPCs | 3_7…9_10 | `100..109;0;…` | Adamaï-style tutorial lines (content 100–109) |
| 80 | Démone II's den (card exchangers) | -1_-1…-2_0 | `1;<cardListId>;<nameId>` (7×) | Card Masters (env type 1), not Zaaps: field 0 = 1 is the Démone II variant (`demonIIDialog`), field 2 a content.29 name — 309 "Démone II", 310–315 the six "Secondes" (client `ayF.gi`). Corrected 2026-10-17 (S05) |
| 85 | Gostof (ghost) island | 0_0…1_0 | `295..299;…;gost*` | Baan, Gostof Iop/Enutrof/Sramette/Sacrieur |

(49 NPCs total across worlds 23, 35, 37, 79, 80, 85.)

## Island map ("carte de l'île")

The bottom-toolbar **island-map** panel (i18n `showMap` = "Ouvrir/Fermer la carte
de l'île", toolbar button `art_0.cPP`, 2nd world-mode tool after `hideObstacle`)
is **100% client-local** and keyed off the raw `worldId` from opcode 4600 — there
is **no** server→client message and **no** C2S request for it (opening is local UI
event 20031 → `po_0` → `ju_1` → dialog `mapDialog` + `map.xml`; data model `nl_0`,
registered as UI context `miniMap`, reads `nl_0.bud = xx_1.Em()` = the current
worldId). The panel's fields, all client-local and keyed by that worldId:

| Field | Source |
|---|---|
| island **name** | i18n `content.61.<worldId>` (`texts_*.properties`) |
| island **picture** | GUI theme style `containerMap<worldId>` → `map<worldId>.dds` (`gui.jar`) |
| **Bonus Elite** `[#1]` | `afh_1.cn(worldId)` = `mw_0.YG()` — local record type **1600** in `contents/bdata/data.bdat` |
| **Bonus Evolution** `[#1]` | `asf_0.a(afh_1.co(worldId))` = `mw_0.tu()` effect list (same local storage) |
| "you are here" dot | `nl_0.aaR()` via config `fullMapPath` — **omitted** from 2.70 `config.properties`, so the dot is hidden on **every** world (client limitation, not server-fixable) |

A world renders as an island **only if it ships BOTH** a `content.61.<id>` name
**and** a `containerMap<id>` style:

- `content.61.<id>` names exist for: **23–28**, 86–109, 111, 112, 113 (note **85 and 110 absent**).
- `containerMap<id>` styles exist for: **23, 24, 25, 26, 27, 28**, 35, 37, 79, 80 only.
- **Intersection = worlds 23–28** — Maknala, Sturbia, Venivici, du Passage,
  Fourmagnet, Magmara — the only worlds whose island map fully renders.

World **85** (the old spawn) has **neither**, so its panel was blank with
`!content.61.85!`. The name/picture are shipped client assets, so there is **no**
server-side way to add them — the only fix is to **spawn on a world in 23–28**.

### Spawn-cell caveat (walkability)

Changing `startWorldID` also moves the walkable overworld, so the spawn cell must
be land. The per-chunk **topology** size in `contents/maps/tplg/<id>.jar` reveals
this cheaply: world **23**'s `0_0` chunk is only **187 B** (mostly ocean — its
island sits at far-negative chunks), whereas world **25**'s `0_0` is **~1.4 KB** (a
fully-populated 18×18 land chunk). The tplg jar's `coord` entry is the list of
valid chunk `[i16 x][i16 y]` pairs. `mw_0` (the bonus record) binary layout is
`[i16 worldId][u8 eliteBonus][u8 count]{akw_0}`.

## Zaap network (teleporters)

A Zaap is an **interactive element of env type 4** (client class `PY`) baked into
each island's env layer. Implementation lives in `internal/game/zaap.go`,
`handlers_zaap.go` and `instance.go`.

### Instance-entry contract — send all three, in this order

Every overworld entry (login, Zaap teleport, `/TP`, `/WORLD`, post-fight return)
must go through `Session.sendEnterOverworld`, which sends:

| # | Opcode | Why it is mandatory |
|---|---|---|
| 1 | **4600** `EnterInstance` | Renders the world + places the coach. **`alt` MUST equal the arrival cell's walkable ground altitude** (the tplg layer `wp`). |
| 2 | **4516** `InstanceReady` (empty) | Clears the client's movement lock `auv_0`. A Zaap request (**4512**) SETS that lock client-side and 4516 is the **only** thing that clears it — there is **no timeout**, so omitting it leaves the coach permanently unable to walk. Also fires walked-onto-element triggers. |
| 3 | **200** `InteractiveElementSpawn` | The client **clears its element manager on every 4600**, so all elements must be re-sent per entry. |

Two traps that cost real debugging time:

- **Altitude.** The client seeds its overworld A\* with the coach's cell **+ z** and
  requires a walkable layer at *exactly* that z (`qe_0.s()`). A wrong `alt` ⇒ no
  path ⇒ the client never sends `4501` ⇒ the coach is silently frozen. The env
  sprite's RU `z` (e.g. 30 on world 25) is **decoration height, not ground `wp`**.
- **Never drive world-entry work off the client's `4517` ack.** The client only
  emits 4517 while achievement 456 / criterion 229 is unset, and it sets 229 itself
  on first world entry — the ack then stops arriving forever.

### Movement is client-authoritative — do not echo 4500 to the mover

The client starts the walk locally as soon as it finds a path, *before* sending
`4501`. Its `4500` handler does not special-case the local coach: it recomputes a
path from the actor's **current mid-walk position** and restarts the animation, or
**hard-teleports** the actor if that recompute fails. So `4500` must be broadcast
to **other** coaches only.

Residual client-side throttles (not server-fixable, stock behaviour): the
pathfinder's node budget scales with idle time (`wp_2.avA = 0.05f`, so a click
<20 ms after the last move is dropped and long paths need ~1–2 s of idle), and
outgoing `4501`s are coalesced on a 1.5 s timer (`ans_0`).

### Cards → destinations (12 routed)

Zaap cards are ordinary cards with **card-type 20**; the client sends
**4512 `[i32 cardTemplateId]`** and the server picks the destination. An island can
have several Zaaps, so each card maps to a specific `{world, instanceId}`.

| Card | Destination | World | Zaap inst |
|---|---|---|---|
| 202 | Maknala — place du marché | 23 | 35 |
| 553 | Maknala — village de la plage | 23 | 112 |
| 203 | Strubia | 24 | 36 |
| 204 | Veniviki | 25 | 37 |
| 208 | Île du Passage | 26 | 38 |
| 206 | Île du Quadraimant | 27 | 39 |
| 207 | Île de Magmara | 28 | 40 |
| 254 | Totem Arena — repaire du démon I | 37 | 70 |
| 255 | Totem Arena — route totémique | 37 | 138 |
| 256 | Totem Arena — îlot des tournois | 37 | 100 |
| 558 | Totem Arena — le platotémique | 37 | 109 |
| 870 | Totem Arena — île aux Rigines | 37 | 74 |

World 37 has no `content.61.37`, so its island-map panel shows `!content.61.37!`
(the picture still renders) — a client data gap, not fixable server-side.

**Never route to** worlds 110/113 (env present but **zero elements** — no Zaap to
leave by ⇒ permanent strand) or 111/112 (moderator / prison worlds). Only 33 worlds
ship a Zaap; a world having env/tplg jars is *not* evidence it is a valid
destination.

### Not routed

- **Cards 547–552 ("Zaapis", set 80)** — unreleased placeholder content in this
  build: `content.26.80` says they "will **soon** give access to new islands", their
  destination text never names an island, no `content.61` world carries their names
  (Ledrob/Onskaï/Ripaï/Siska/Trubwak/Krokoboo), and every Zaap-bearing world is
  already accounted for. Deliberately not granted.
- **Card 859 "Île de clan"** — see below.

### Clan island Zaaps (for the future clan system)

Card **859** teleports to the coach's **own** clan island (worlds 86–109, one per
clan), so it needs a clan system before it can be routed. When clans land: map
`clanID -> worldId`, make the card's destination a dynamic lookup rather than the
static `zaapCardDest` map, and use the world's Zaap below. All payloads are the
standard 42-byte blob; the RU leading short is the worldId (`0056`=86 … `006D`=109).
Clan worlds have a `content.61` name but **no** `containerMap<id>` style, so their
island-map picture is blank.

| world | inst | cell | alt | world | inst | cell | alt |
|---|---|---|---|---|---|---|---|
| 86 | 144 | (78,114) | 4 | 98 | 157 | (21,24) | 28 |
| 87 | 145 | (77,74) | 0 | 99 | 158 | (79,70) | 0 |
| 88 | 146 | (48,77) | 0 | 100 | 159 | (34,34) | 0 |
| 89 | 147 | (55,69) | 0 | 101 | 160 | (66,63) | 0 |
| 90 | 148 | (51,49) | 3 | 102 | 161 | (60,62) | 0 |
| 91 | 149 | (61,51) | 0 | 102 | 162 | (51,57) | 2 |
| 92 | 150 | (53,56) | 1 | 103 | 163 | (55,68) | 53 |
| 93 | 151 | (41,51) | 2 | 104 | 164 | (67,54) | 0 |
| 94 | 152 | (46,54) | 3 | 105 | 165 | (54,49) | 1 |
| 95 | 153 | (49,59) | 0 | 106 | 166 | (48,63) | 0 |
| 96 | 155 | (51,38) | 1 | 107 | 167 | (32,60) | 0 |
| 97 | 156 | (59,39) | 1 | 108 | 168 | (58,63) | 0 |
|    |     |          |   | 109 | 169 | (101,93) | −34 |

## Overworld services (interactive elements)

Zaaps are one *kind* of interactive element; the same machinery drives the rest.
The table of every element the server spawns lives in `internal/game/elements.go`
(`worldElements`), and the click dispatcher in `handlers_elements.go`.

**Every element emits C2S `201` `[i64 instanceId][i16 actionOrdinal]` when clicked**
— what the server owes back depends on the kind:

| Kind | env type | Click behaviour | Server must send | Status |
|---|---|---|---|---|
| **Zaap** | 4 | Opens the Zaap-card page locally | nothing on click; `4512` → `4600` | ✅ working |
| **Card Master** | 1 | Opens **no UI** — arms its handler and waits | **`5401` catalogue** (this is what opens *and* fills the shop) | ✅ working |
| **Fusion altar** | 14 | Opens + fills the altar from **client-local** lab defs | nothing on click; `5490` → `5491` | ✅ working |
| **Mailbox** | 2 | Sends `15000`; the dialog opens only on the reply | **`15001`** (+ `15004`/`15006`/`15506`/`539`) | ✅ working |
| **Graveyard** | 10 | Sends `6031`; a loading modal blocks until answered | **`6006` then `6030`** | ✅ working |
| **Challenge** | 3 | Accept/refuse bubble, local; **no 201 on click** | accept sends `26330` → **`8000`** fight sequence | ✅ working |
| **Demon challenge** | 7 | as Challenge, or a local Lua scenario | accept sends `26330` → **`8000`** fight sequence | ✅ working |
| **Firework** | 12 | Firework dialog, filled from own inventory | `22095` → `22094` echo | ✅ working |

Each of the six main islands ships 1 Zaap (Maknala/Sturbia have extras), 1–3 Card
Masters, 1 Fusion altar, 1–3 mailboxes and 1 graveyard; Maknala also has the two
challenges, the demon challenge and four firework launchers, and Passage has a
fifth. `elements_test.go` asserts that, plus globally-unique instanceIds and that
every routed Zaap card resolves.

> **The graveyard MUST be answered.** Clicking it sends `6031` and opens a
> full-screen "loading" veil that **only** a `6030` reply dismisses — there is no
> timeout and the dialog can't be closed, so silence is a hard client soft-lock.

> **Never send an unsolicited `15001`** — it force-opens the mailbox dialog, and
> repeats leak the client's mail-store refcount.

### Card Master

**Opcode 5300 is NOT "shop open" — it is the client's debug-console opener** (its
only sender is the console command). Answering it with a catalogue made opening the
console pop the shop; `handleShopOpen` is now a no-op. The real flow is:

```
click → C2S 201 → server pushes 5401 → shop opens & populates
      → C2S 5400 (barter) / 5450 (token buy) → S2C 5403 + 5200 inventory
```

`5401` = `[u8 mode][i32 shopId]{[i32 cardTemplateId][i16 qty]}`.
- `mode` 0 = ordinary Card Master tab, 1 = the "démone II" variant. All twelve
  main-island Card Masters carry flag 0 in their descriptor.
- `shopId` is **opaque** to the client — it stores it and echoes it back on every
  purchase, so we stamp the clicking element's own catalogue id (descriptor field
  1, `cardListId`: 23→5,6; 24→7,8; 25→13,14; 26→9,10; 27→11,12; 28→15,16).
- `qty` is **stock, not price**. Prices are read client-side from the card
  templates in `data.bdat` and are never sent.
- A `cardTemplateId` the client can't resolve is logged and dropped, so only ship
  ids that exist in the game data.

**`cardListId` is a card SET id** (a "panoplie", named by `content.25.<id>`) — the
twelve main-island Card Masters map 1:1 onto the twelve lowest equipment sets, so
each sells exactly one panoplie:

| id | set | world | id | set | world |
|---:|---|---:|---:|---|---:|
| 5 | Boufcoul | 23 | 11 | Chaferombi | 27 |
| 6 | Justice | 23 | 12 | Brigandin | 27 |
| 7 | Wabbit | 24 | 13 | du Bouhroh | 25 |
| 8 | Barberare | 24 | 14 | Champepion | 25 |
| 9 | Barathin | 26 | 15 | Ecuyer | 28 |
| 10 | Kubokaraie | 26 | 16 | du Bouffon | 28 |

Set membership lives on the card (field 3 of the type-100 record), so the server
filters with `gamedata.Cards.CardsInSet` — there is no separate shop table. Prices
are **not** in the set either: both purchase paths read them from the card
template, so the catalogue message neither can nor need set them. Purchases are
validated against the echoed `shopId`'s stock, so a coach cannot buy from a Card
Master that doesn't stock the card. Note the tiers are not ordered by island (set 5
is starter-priced, sets 12–14 are the expensive ones) — that is retail's intent.

### Mailbox

Coach-to-coach letters with card attachments, capped at **20 mails**, **10
attachments** each, title ≤100 / body ≤800 characters (all client limits, mirrored
server-side in `domain`). Stored in `Mail` + `MailCard`; a mail row survives until
**both** sides delete it, so each side deletes independently.

```
C2S 15000 (empty)                 -> S2C 15001 [i16 n]{mail record}   *** opens the dialog ***
C2S 15004 [u8 n]{i64 mailId}      -> (no reply; the client removes it locally)
C2S 15006 [i64 mailId](+1 pad)    -> S2C 15007 [i64 mailId][i64 coachId][u8 n]{i32 cardId}
C2S 15506 [u8 len][utf8 name]     -> S2C 15507 [i64 coachId]   (0 = no such coach)
C2S 539   mail record             -> S2C 15003 [i64 result][mail record]  (>0 ok, -2 full)
S2C 15005 [u8 count]              (optional "you have new mail" toast)

mail record = [i64 id][i64 senderId][u8+utf8 senderName][i32 senderGame=2]
              [i64 receiverId][u8+utf8 receiverName][i32 extraLen][extra]
              [i64 dateMillis][u8 read][u8 delBySender][u8 delByReceiver][i32 state=0]
extra TLV   = {u16 1,i32 len,utf8 title} {u16 2,i32 len,utf8 body}
              {u16 3,u16 n,i32 cardId×n} {u16 4,i32 systemMsgId}
```

The sender is always taken from the session (never the client's own fields), the
recipient is re-resolved from its name, and attachments are consumed from the
sender's inventory on send and restored if the send is rejected. A `senderId < 0`
marks a system mail, for which the client renders `content.32/33/34.<tag4>` instead
of the carried strings.

### Graveyard / evolution mode

In **evolution** mode a fighter accrues XP, tires, and can die for good. Each
fighter carries a **state** byte (`domain.FighterState*`):

| State | Meaning | Cap |
|---:|---|---:|
| 0 | titular (starting line-up) | 6 |
| 1 | bench / reserve | 7 |
| 2 | dead, still occupying a team slot | — |
| **3** | **in the graveyard** | **5** |
| 4 / 5 | legendary titular / bench | 6 / 9 |

A fighter is serialized as a **type-2** `et_2` blob (classic is type 1) exactly
while its state is not *titular* — that type byte is what files it into the
client's evolution roster, and state 3 is what puts it in the graveyard list.
The type-2 tail is appended by `writeEvolutionTail`:

```
[i32 sphereBoardId][i32 xp][i32 totalXp][u8 tiredness][u8 morale][u8 STATE]
[i16 sphereX][i16 sphereY][i16 nSpheres]{i32}
[u8 nConditions]{[i16 id][u8 level]}[i16 nPassives]{i32}[i16 nPassiveSets]{i32}
```

⚠️ The client parses that tail inside a try/catch that **silently downgrades the
fighter to type 1** on any error — a short or malformed tail doesn't raise
anything, the fighter just vanishes from the evolution roster. Always emit every
trailing count, even when zero.

**Where the roster comes from.** The graveyard loader files evolution fighters
into its model from a `6006` received *while it is the active frame* — a login-time
`6006` does **not** reach it. So the graveyard is populated only by the reply to
its own `6031`, which is why `handleTeamPresetListRequest` sends **`6006` first,
then `6030`** (see the ordering note above).

**Player actions** (both applied optimistically client-side, consuming no reply —
the server must reproduce the transition and persist it, then push a fresh `6006`):

```
C2S 23000 (arch 2) [i64 fighterId][u8 legendaryToggle]   state transitions
        titular <-> bench (0<->1),  dead -> graveyard (2->3),  legendary (4<->5)
        the graveyard is a dead end: only a resurrection item gets you out
C2S 22099 (arch 3) [i64 fighterId][i32 cardTemplateId]   use a consumable
        graveyard (3) -> bench (1),  dead (2) -> titular (0)
```

**Resurrection is a gamble.** The dropped card must carry a real resurrection
effect (client effect **action 13**, `AI.aHI`) — the same gate the client applies
(only a resurrection effect may act on a dead/interred fighter) — and its decoded
`param[0]` is the success **percent**. The server rolls `rand(1..100) <= pct`
(mirroring the client's `nz_1`): the card is consumed **either way**, but the
fighter is revived only on success; on failure it stays dead and the client learns
from the unchanged roster (there is no "failed" message). A card with **no**
resurrection effect is refused and **not** consumed. The percents are decoded from
each card's effect array (`gamedata.CoachCard.ResurrectPercent`); verified values:
cards 305/316/317/318 = 100 %, 51 = 12 %, 53 = 10 %, 35 = 5 %, 137 = 1 %.

Capacities are enforced server-side so a coach can never reach a state its own UI
would refuse. **Not modelled yet:** sphere boards, conditions and passives (emitted
empty).

**Fight deaths now fill the graveyard from real play.** A fighter that falls to
0 HP in an **evolution** fight (the lethal mode, client `aKl()==6` — never ranked,
practice or PvE) is persisted as **dead (2)** and the refreshed roster is pushed
(6006); the player then buries it (23000, 2→3) or resurrects it (22099, 2→0), both
already handled. This is server-authoritative: the client sends no death report,
so the server computes the deaths and pushes the states. Rule: every fighter
downed to 0 HP dies — on *either* side (the retail per-fighter death *chance*,
modifiable by effect-7 cards, is not modelled); synthetic opponents (sparring
dummy, challenge demons) have no DB row and are skipped. See
`persistEvolutionDeaths`.

Evolution fights are otherwise only reachable via a 2-coach direct challenge with
the evolution flag, so **`/EVOFIGHT`** (GM) starts a solo evolution practice fight
(your titular team vs the sparring dummy); pair it with **`/ENDFIGHT lose`** to
send your fielded fighters to the graveyard. `/FSTATE <fighterNameOrId> <0-5>` is
still the direct way to set any state.

### Challenges — scripted PvE fights

Launching an overworld **challenge** (Challenge, DemonChallenge, and the
BreedMaster's "test this breed") reuses **opcode 26330** — the same one as the
"Tester" practice launch — sent with **arch byte 2**:

```
C2S 26330 [i32 challengeId][i16 99]      <- challenge launch
C2S 26330 [i32 fightType  ][i16 teamId]  <- "Tester" practice launch
```

The `99` is **not a teamId**: the client sets `bM((short)99)`, breed 99 = COACH.
`handleTeamTest` branches on it and hands off to `startChallengeFight`.

**The click itself sends nothing.** Unlike every other element, `pn_0` never
calls `do_1.a(...)`, so a DemonChallenge emits **no 201**. The bubble, the Lua
cutscene and the gating are all client-local; the first thing the server ever
hears is the 26330 from the accept button.

**The server owns the opponent team, completely.** The client's challenge table
(`data.bdat` type **400**, 39 records, ids 3–46) is decoded by `ahy_1.a` into
name/description/rewards only — it **discards** everything else and holds no
roster anywhere. So nothing the client renders can contradict the team we build.
`internal/gamedata/challenges.go` decodes what the server needs (id, the six
unnamed head fields, and the reward-card list, whose values all resolve in the
type-100 card table); `internal/game/challenge_fights.go` builds the team.

Opponents are **session-less**, which is what makes them work for free: the fight
engine already pre-marks a session-less team ready in every phase gate and hands
its fighters to the built-in AI (`Fight.isAIControlled` → `runAITurn`). Each one
is armed with a real breed-appropriate spell picked from the spell table
(`pickBreedSpell`: cheapest damaging spell of that breed, ties broken by id, so
it is deterministic) — leaving it at 0 would make every challenge a fight against
statues, since `classifyAI` reads exactly that one field.

Who fields what:

| Challenge ids | Element | Opponent |
|---|---|---|
| **17–28** | the twelve world-35 **BreedMasters** | one fighter of the breed that master teaches — read off the element descriptors (`nameId;?;154;breedId;challengeId`) |
| **32–36** | the five **minute demons** (worlds 37 + 79) | an authored 2–4 breed team; challenge 33, the client-gated 12th-minute boss, fields the largest |
| **45** | world 23's **Barnaby demon** | an authored pair |
| any other | — | mirrors the player's team size (fair by construction) |

**Legibility.** The opponent coach carries the demon's own name (recovered from
the DemonChallenge descriptors' `content.29` ids — e.g. *"Démon de la 58ème
minute"*), and each opponent fighter is named by its **breed** ("Iop", "Sacrieur")
rather than an anonymous "Démon 1/2/3". Difficulty is expressed purely through
**team size** — 2 for the early minute demons, 4 for the gated 12th-minute boss —
a deliberate, authored baseline rather than a fabricated stat multiplier (there is
no monster stat table in the client to draw real numbers from).

A challenge launch carries **no teamId**, so the server picks the player's roster:
the **titular** line-up (`titularRoster`, state 0 — excludes benched, dead and
interred fighters), capped at the arena's start cells. Using the preset lookup
here would ask for preset id 0, which never exists, and silently field a single
fighter against a whole demon team.

An id absent from the table is refused with **26310** rather than ignored — by the
time the client sends 26330 it has already armed its fight handlers, so silence
would leave it waiting forever.

**Verified live** (challenge 33): four `Démon` fighters created, all four taking
`ai=true` turns in initiative order with distinct wire ids, the player fielding
five titular fighters, the fight looping into round 2, and zero client-side
exceptions. Note the fight UI itself cannot be verified through the test harness —
the client only arms its 8000 handler (`do_2.Mm()`) when the accept button is
pressed, so a DEV-injected 26330 starts the fight server-side but renders no
combat UI. An ordinary "Tester" launch behaves identically under injection, which
is how that was confirmed to be a harness artefact and not a server bug. Seeing
the demons on screen needs a real mouse click on the element.

#### Reward cards

Winning a challenge grants the cards its type-400 record lists, straight into the
coach's inventory, followed by a **5200** inventory push so they appear without a
relog. Challenge 33 awards cards 186 + 189; the twelve breed masters award nothing
(that is the data, not a gap).

The 8000 CREATE_FIGHT frame also declares the fight as a challenge — **kind byte
5** plus the challenge id in the following i64 — because the client's end-of-fight
builder (`WE`, case 8300) only shows its `endFightChallenge` reward/XP panel when
`aKl() == 5`, and resolves the metadata as `ahy_1.axg().dC(<that id>)`. Without
both, the panel is silently skipped and a win looks unrewarded.

Three subtleties worth keeping:

- **The grant is gated on the coach being real, not on having a session.** A coach
  that wins while disconnected (the reconnect grace period) still gets paid — the
  session is only needed for the live push. Gating on `Session != nil` silently
  voids the reward, and gating on nothing at all would write inventory rows for
  the *synthetic* opponent coach when the demons win. Hence `isSyntheticCoach`.
- **Unknown reward cards are filtered.** The shipped data has a dangling
  reference: challenges **9 and 37 both award card 184**, which exists in neither
  the coach-card (type 100) nor fighter-card (type 250) table. Granting it would
  leave an inventory row the client cannot render, so it is skipped and logged —
  while the rest of that challenge's rewards still land.
- Rewards sit **outside** the `!Practice` guard in `checkFightEnd`: a challenge is
  unranked (no stats, no ladder movement) but the cards *are* the point of it.

Verified live: Loov's inventory went 22 → 24 rows with 186 and 189 at qty 1, card
184 absent, and no client exception on the mid-teardown inventory push.

**`/ENDFIGHT [win|lose]`** (GM) settles the caller's current fight by wiping one
side, which is the only way to force a decisive result on demand — the challenge
opponents are AI-driven. Same rationale as `/FSTATE` for the graveyard.

#### Completion tracking and criteria

Completion is **entirely server-owned**. The client has no challenge→criterion
mapping and never writes one: every `or_0.<C>.tI()` use was checked and none
writes 213–217, and the end-of-fight path (`WE`, case 8300) only *displays*
challenge data — it sends no 22003. If the server doesn't record a clear, nothing
does.

Rewards are paid on the **first clear only**; a repeat win re-asserts the criteria
(idempotent, and it self-heals a coach who cleared a challenge before this
tracking existed) but pays nothing.

Two id ranges, deliberately separate:

| Range | What | Sent to client? |
|---|---|---|
| `<= 1007` | real client criteria (the `or_0` enum) | **yes**, in the 2052 `0x200` blob |
| `2000 + challengeId` | the server's own per-challenge completion flags | **never** — filtered out |

The challenge→criterion mapping exists nowhere in the data files; it was recovered
by matching the `or_0` enum's French descriptions against each challenge's
`content.30.<id>` name:

| criterion | `or_0` description | challenge |
|---:|---|---:|
| 214 | "…le défi du **premier** démon des minutes" | 34 |
| 215 | "…**deuxième**…" | 35 |
| 216 | "…**troisième**…" | 36 |
| 217 | "…**quatrième**…" | 32 |
| 213 | "…**tous** les défis des démons des minutes" | all five (incl. boss 33) |
| 218 | "…parlé au démon I après les 5 défis" | *client-set* (`arw`), not ours |

Those four **are** the definition of achievement 278, which is what the client
checks before it will even offer the 12th-minute boss — so setting them is what
makes that boss reachable.

##### The 0x200 blob is a loaded gun

It is the **only** channel by which criteria reach the client (`4096 ActorSpawn`
uses flags 3179 and `8000 FightCreation` flags 34 — neither includes `0x200`), and
**22002 must never be sent**: its handler both opens the tutorial dialog *and*
does `this.Ir = <new set>`, wholesale-replacing the coach's criteria, so a partial
22002 destroys every criterion not in it. Consequence: a criterion set mid-session
becomes visible to the client only at the next coach load. That is fine here —
the sole consumer re-evaluates from its local set on each click.

`aez_0.O()` loops `while (n*4 < byteLen)` reading four bytes per iteration **with
no bounds check against the buffer**. If `byteLen` overstates the pairs that
follow, it reads on into the *next descriptor sections* — corrupting every later
field, or underflowing, which `aez_0.b()` swallows by returning `false`, and then
the coach never materialises at all (a silent hang at loading). So `byteLen` must
be **exactly 4×pairs**; `buildCriteriaBlob` owns both the count and the prefix so
no caller can desynchronise them, and `TestCriteriaBlobLengthIsExact` replays the
client's exact loop to prove it stops precisely at the end of the blob.

Also: `byteLen` is read **signed**, values are `i16` (a wrapped negative silently
fails every `>=` gate, so completion flags use 1), and unknown criterion ids are
inert — the client evaluates an achievement by looking up *its* required keys, and
never enumerates the coach's.

##### A latent bug this exposed

`CoachRepo.Get` was not preloading `Stats`, so **every criterion the client had
ever self-reported via 22003 was persisted and then never read back** — silently
lost on relog. Adding the preload fixes that too: criterion **229** (which the
client sets itself on world entry) now round-trips. That is safe only because
element spawning was earlier moved off the client's `4517` ack — the client stops
sending `4517` once 229 is set, so any work still hanging off it would have
silently died here. `4517` is now a verified no-op.

**Verified live:** beat challenge 34 → `criterion set … 214`; clear 33 → rewards;
clear 33 again → `challenge re-cleared; no repeat reward`; relog → coach, world and
HUD all materialise with the larger blob; persisted state exactly
`214=1, 229=1, 2033=1, 2034=1` with 213 correctly *unset* (35/36/32 unbeaten).

#### The "time challenge" flag — investigated, nothing to do

The type-400 record's `QE` field (client `GE.QE()`, decoded now as
`Challenge.TimeChallenge`) is what the client's end-of-fight builder gates its
"time challenge" reward/XP panel on. It was the last open follow-up, so it was
run to ground:

- **It is 0 for every challenge any element references** — all twelve breed
  masters, all four minute demons, and world 23's Barnaby demon. The
  "Nth-minute" names are **flavour**, not a mechanic. (`TestChallengeTimeFlagInactiveForSpawnedDemons` pins this and logs the whole-table picture.)
- The flag is non-zero only for the **contiguous block 37..44**, which **no
  element spawns** — unreachable content in this build.
- Even for those, the panel is **client-owned**: the client loads type-400 itself,
  so the server sends nothing for it. The server's only obligation for any
  challenge is the one it already meets — tag the fight **kind 5** with the
  challenge id so the client can locate the record.

So there is **no per-challenge time limit for the server to enforce**. The field
is decoded and test-pinned so the conclusion is guarded against a data change, but
implementing enforcement would be dead code against an all-zero, unreachable flag.

**Fireworks** (`cardUsingSwitch`) are self-contained: the dialog fills from the
coach's own cards, and launching sends **22095** `[i32 cardId][i32 x][i32 y][i64
elementId]`, which the server echoes as **22094** (same fields plus a z) to the
launcher and everyone in range so the effect is visible to others.

### Fusion altar

Spawn-only: the dialog opens and populates entirely from client-local lab
definitions, so the **only** networked part is `5490` → `5491`. The descriptor is
the lab-definition id (23→2, 24→6, 25→4, 26→3, 27→7, 28→5) and it drives that
altar's `slotCount` / `labPower` / `quality` client-side. `5490` carries **no** lab
or element id (and lists card ids **reversed**), so the server can only attribute a
fuse to an altar via the preceding `201`. Today the server applies one flat rule
(≥2 cards of a set, 60% success); mirroring the per-lab power/quality/slots from
the same `ajd_0` records would make `5490` authoritative.

### The other islands (35 / 37 / 79 / 80 / 85)

**World 37 "Totem Arena"** — reachable with five Zaap cards — now spawns its full
set of **40 elements**: the complete **24-totem demon ladder** (demon ids 1–24, one
per totem), **Demon I**, the **tournament totem**, the five minute-demon
challenges, two Card Masters and a zone trigger.

Worlds **35** (twelve breed masters + Demon III + tutorial zone triggers), **79**
(Demon I's den), **80** (seven "démone II" card exchangers + a tournament totem)
and **85** (Baan + the four Gostof NPCs) are also fully populated, each with its own
Zaap (35→inst 41 at (100,90) alt 0, 79→130 at (11,28) alt 24, 80→131 at (−29,9)
alt −40, 85→180 at (−2,20) alt 0). No Zaap *card* routes to them yet, so they are
reached with `/WORLD` — which now lands on that Zaap's known-walkable cell at the
right altitude, so movement works on arrival. `elements_test.go` asserts nobody can
be stranded: every world with elements has a Zaap to leave by.

Card Masters carry a **mode** flag in descriptor field 0: `0` is the ordinary
panoplie shop, `1` the "démone II" exchanger. World 80's seven and world 37's
inst 101 are mode 1, with `cardListId` 17–24 — outside the 5–16 panoplie range, so
they fall back to the full priced catalogue for now.

Verified: **no interactive element can hang or soft-lock the client** — clicks are
dispatched locally and the bubbles close on click.

| Element | env type | Server owes | Status |
|---|---:|---|---|
| **NPCTalker** | 15 | nothing — the dialog tree is client data. (Its UI events 17000/17001 are *local*; the 17002–17010 **opcodes** are the tournament family, unrelated.) | ✅ spawn-only |
| **ZoneTrigger** | 8 | nothing — walk-on runs a local Lua scenario; it never even sends `201` | ✅ spawn-only |
| **BreedMaster** | 5 | recruit works through our fighter creation; "test this breed" is the shared `26330` challenge path (ids 17–28, one per breed) | ✅ recruit + test fight |
| **Demon I / III** | 9 / 6 | nothing beyond the shared `26330` challenge path | ✅ spawn-only |
| **DemonTotem** | 11 | **`27511`** — sends `27510` on click and opens nothing itself | ✅ empty ladder |
| **TournamentTotem** | 13 | **`17003`**/**`28602`** calendar+list, **`28608`** register, **`28650`** bracket | ✅ live tournaments |

#### The demon totem (empty stub)

Guild/clan reputation is not modelled, so the demon ladder is answered with a
well-formed **empty** payload: the dialog opens, shows nothing and closes cleanly.
Its decoder reads the trailing per-message `i64` unconditionally and has **no length
guard**, so the byte count is exact — a short buffer is silently dropped inside the
client's frame decoder and the dialog never opens.

```
S2C 27511 demon ladder  [i16 demonId][i16 page][i32 startRank][i32 count]
                        count × {[i32 nameLen][name][i64][i64][i64]}
                        [i64 affiliation]          <- read even when count = 0
        empty form = 20 bytes; page MUST be 1 or the client leaves its rows alone
```

Live-verified: the ladder opens titled **"Démon VII"** for demon id 7 with cleared
rows. The demon totem also emits **`517`** (getGuild) on click, which we leave
unhandled — it is logged and harmless.

#### The tournament totem (live)

The tournament totem now serves real data (see `tournaments.go`). On open the client
fires **`17002`** (calendar) + **`28601`** (list); the server answers **`17003`** and
**`28602`** with a fixed set of **standing tournaments** that are always open for
registration. Clicking a row + **S'inscrire** sends **`4607`**, answered by **`28608`**
(accepted); the bracket button sends **`28649`**, answered by an empty **`28650`**
tree ("tree unavailable"). Each tournament references a **real client definition id**
(`data.bdat` type-1000 `aub`; the retail client ships 22, ids {1,4..24}) with
`referenceCardId == 0`, so registration needs no card and the client's
list/detail/register paths (which dereference that definition **unguarded**) never
NPE. Registration is tracked in-memory per coach (`TournamentManager`) and reflected
back as the row's `coachStatus`.

```
S2C 17003 calendar   [i16 count]{[i32 typeId=4][qr_0 event]}
        qr_0 = iz_0 base [i64 eventId][i64 OV][i64 endDate][i64 recur=0][i32 label]
             + th_2 [i64 extraDate] + [i64 tid][i8+utf8 name][i16+utf8 desc]
               [i8+utf8 short][i8 schedN]{i64,i64}[i8 regN>=1]{i64,i64}
        TRAP 1: regN MUST be >=1 (qr_0 reads reg pair [0] unguarded).
        TRAP 2: the "Tournois du jour" filter reads the two instants INVERTED —
                the startDate slot (OV) is the runs-until bound (>= now / end-of-
                today) and extraDate (bOF) is the already-started bound (<= now).
S2C 28602 list       [i32 count]{[i64 tid][u8 search][i8 status(-128 not reg)]
               [i16 defId][u8 regOpen][i32 fpN + i32[]][3×(i32+utf8)][u8 kind]}
        defId MUST be one of the 22 real aub ids or the client NPEs; kind 1
        (private) keeps it registerable without the search/bracket flows.
C2S 4607 register    [i64 tid][i64 coachId][i16 preset=-1][i32 card=0]  (arch 3)
S2C 28608 reply      [i64 tid][i8 err]        err 0 = accepted, 2 = full
S2C 28650 tree       [i32 treeSize=0][i32 count=0][i32 bib=0]   empty = safe
```

**Live-verified end to end:** the totem window "Tournois du jour" lists all three
tournaments with their real names, per-defId illustrations, schedules and
registration periods; clicking **S'inscrire** on "Tournoi des Champions" sent a real
`4607`, the server accepted it (`28608 code=0`), the client showed *"Inscription au
tournoi acceptée"* and the row flipped to the green ✓ (registered) — zero client
exceptions throughout.

**Deferred — the live-match layer.** Opponent search (`28609`/`28611`), scheduled
fights, bracket progression, forfeits/reports (`28617`) and rewards are not modelled:
they need many coaches and wall-clock scheduling. The standing tournaments therefore
accept registration and then wait; the admin create/destroy/period opcodes
(`28603`/`28605`/`28633`/`28635`, `17004`–`17010`) are likewise unimplemented.

## Server implications

1. **Done (island map):** opcode-4600 `EnterInstance` sends **`worldId = 25`**
   (Venivici / "Île de Veniviki") with `dynamic = 0`, placing the coach at cell
   **(8,8)** in chunk `0_0` (`startWorldID` / `startCellX/Y` in
   `internal/game/handlers_connection.go`); the coach's server-side position is
   aligned to the spawn so movement works. World 25 is one of the six worlds
   (23–28) whose **island map** fully renders (see "Island map" above).
   **Verified live**: coach on solid ground + panel shows the island name, the
   `map25.dds` picture, and real bonuses (`Bonus Elite : 2`,
   `Bonus Evolution : Concentration 20`) from world 25's `mw_0` record. The
   **return from a fight** (`encodeReturnToWorld` in `fight_combat_packets.go`) now
   also uses `startWorldID` instead of the non-existent world 0, so the island map
   keeps working after combat. (World 85 = the old Gostof spawn, blank island map;
   world 79 = Démon III arena; world 35 = recruitment island.)
2. No packet "creates" the static NPC — Démon I loads from `env/79.jar` when the
   client enters world 79 (interactive elements are client-local map data).
3. The **scripted intro** (Adamaï / "Hey ! Toi là bas !") is a separate,
   larger feature: it needs a **dynamic instance** (4600 `dynamic=true`) plus a
   scenario/zone-trigger message and achievement gating. Not implemented.
4. Live-testing: point `E:\Projets\DofusArena2-06\client\compiled\DofusArena.exe`
   (the COMPLETE retail build) at the local `server`. Change `startWorldID`
   to visit other islands (35 = recruitment, 23 = Démon III, 85 = Gostof, …).

## Open items

- **Scenario/dynamic-instance support** to reproduce the scripted intro (Adamaï
  cutscene + "Hey ! Toi là bas !"): implement the ENTER_WORLD_INSTANCE dynamic
  path plus the scenario-trigger / zone-trigger messages that call
  `anr_0.a(scenarioId, event, args)` client-side. Large feature.
- Enumerate each NPC's dialog tree from record type 1500
  (`contents/bdata/data.bdat` + `indexes.bdat`, storage format in
  `client/analysis/DATA-FORMAT.md`).
- Confirm the exact spawn cell / world the original first-login used (needs a
  packet capture; scenario 0 starts the coach on a cutscene instance, then
  `Context.tutorialChangeInstance()` hands off).
