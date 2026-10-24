# Lobby visual contract

**Since 2026-10-24 the screens outside combat use the stone-and-gold UI**
(`src/ui/ui_style.gd`, the owner's call): it replaced the S18 1-bit system,
which the owner dropped together with the 1-bit fights. It is direction A of
the S18 sketches — the family of the retail-coloured fight HUD (S17): olive
stone plates with a worn gold rim, rounded corners, soft shadows, cream text,
gold titles and one gold primary button per screen (`UiStyle.primary`, the
fight's PASS). Card art and the paper doll are in colour. Full screens sit on
our own stonework backdrop, `assets/ui/ui_bg.png`, made by
`tools/make_ui_bg.py` (the outer frame of the old baked screens, without their
slots); without the file, an olive gradient.

The lobby is a fixed 1280×720 composition, uniformly scaled and centred. It
has a coach window at (40,150,320,350), six central actions in two rows with
Combate as the primary, chat in (40,512,650,182) and nine menu controls in
(720,512,510,182). The baked Pillow art (`lobby_bg.png`, `login_bg.png`,
`creation_bg.png`) is no longer drawn; `tools/make_lobby_bg.py --icons` still
makes the (light) menu icon atlas.

- Every control has hover, pressed and keyboard focus feedback (a gold ring
  3 px outside). Fight actions are disabled until ready and after disconnect.
- The paper doll uses the creation screen animation loader and Palettes tint
  mapping. Chat stays a sibling under UI and takes the compact theme
  (`UiStyle.theme(3)`).

## Current data limits

The localCoach producer derives the coach level from State.coach_standing (2052 at login plus each 8300's standing won) with the retail formula (State.coach_level, S07) and supplies an empty equipped-emote list. Tools are read from localCoach.tools or the retail top-level tools model. Registered item handlers receive a GWidget item context. Known emotes use the existing retail 4701 layout and incoming animation names display as bubbles. This checkout has no persisted emote-unequip handler or native retail tool executor; unavailable actions show an explicit message.

## Validation

`test/native_lobby.gd` runs the real windowed login, nine dialog toggles, chat focus, model refresh, shell remount, practice fight transition and return (the debug strip no longer exists). Credentials are command-line arguments. Screenshots are written to `/tmp/native-lobby.png` and `/tmp/native-lobby-social.png`.

`test/window_skin.gd` checks missing app-skin border/title resources and custom-theme precedence.

Live smokes against a local server cover every native window: `world_smoke`
(Services), `talk_smoke`, `cardmaster_smoke`, `mailbox_smoke`, `fusion_smoke`,
`revive_smoke` / `revive_edge_smoke`, `totems_smoke`, `report_smoke`,
`pvp_smoke` (duo, clan, trade, team pick, PvP, report), `ask_smoke` /
`ask2_smoke` (invitations), `screens_smoke` (Kanodo, coach equipment). Their
headers say how to seed and restore `server/arena.db`.


## Native lobby panels

`src/ui/lobby_panel.gd` is the common modal surface: the native theme (`UiStyle.theme()`), Copperplate title, Tahoma controls, a dark shade, bounded 1120×620 reference frame, and scrollable content. Containers own interior layout. Deferred layout resets prevent initial text minimum sizes from pushing the frame below the viewport. Close and Escape are shared, and Tab cycles inside the panel. Team combat actions stay in a fixed footer outside the scrolling roster/detail area.

`src/ui/lobby_panels.gd` provides native menu, team/evolution, statistics, inventory/collections, rankings, calendar, achievements, social, help, options, fighter creation with tinted preview, fighter equipment/spells, team creation, and clan creation/management/member statistics. These twenty logical dialog routes are registered in `main.gd`; runtime XML does not build them. The shared model still supplies content, and the existing handlers serialize all requests.

The dialog registry normalizes event names, prevents duplicate opens, supports nested native panels, and disconnects resize callbacks when legacy dialogs close. Plain `unloadDialog` from legacy templates also reaches the close router. Explicit close handlers take precedence so equipment and exchange cleanup keep their original behavior.

`test/native_panels.gd` exercises real mouse and Escape input on every route, duplicate opening, viewport bounds, a smaller window, tab switching, fighter preview, parent/child closing, menu-to-options navigation, and local populated fixtures. Fixture action spies prevent synthetic fighter IDs from reaching the server. Captures are written to `/tmp/panels-*.png`.

## Native service windows (S18)

Built on `lobby_panel.gd` (smaller ones set `frame_size`), each reading one
model key that `main.gd` pushes and answering with `native*` events, so the
wire stays in `main.gd`:

| Window | Script | Opened from |
|---|---|---|
| Card Master | `card_master_panel.gd` | Services |
| Mailbox | `mailbox_panel.gd` | Services |
| Fusion altar | `fusion_panel.gd` | Services |
| Conversation (`npcTalkDialog`, 860×500) | `talk_panel.gd` | Services (challenges, demons) |
| Firework launcher | `firework_panel.gd` | Services; the show is `firework_fx.gd` on the lobby sky |
| Demon offering | `demon_panel.gd` | Social → Clan (leader) |
| Kanodo (sphere board) | `kanodo_panel.gd` | Team → Evolution → a fighter → Spheres |
| Coach equipment | `coach_equip_panel.gd` | Inventory |
| Player trade | `exchange_panel.gd` | a trade invitation |
| Invitation prompt (`askDialog`, queued) | `ask_panel.gd` | challenge, match, clan, duo, trade invitations |
| Team pick | `team_pick_panel.gd` | an accepted challenge |
| Fight report | `report_panel.gd` | back in the lobby after a fight |

The fallen fighters (the retail graveyard) are a section of Team → Evolution;
tournaments (register, bracket, opponent search) are the Calendar's day
detail; matchmaking shows "Buscando rival…" with Cancelar under the lobby
actions. NPC texts follow the UI language (`npcdialogs.json` `locales`).

## Native combat HUD

`fight_view.tscn` now presents a native olive and gold combat HUD: arena and turn controls above the map, initiative chips at the upper right, chat at the lower left, and a horizontally scrolling spell and card bar at the lower right. Below 960 px wide, anchored chat and actions stack to keep both reachable. Turn controls, spell buttons and chat have a keyboard focus path. The result panel uses the same palette and Copperplate heading, with a fixed Continue action, scrolling card rewards, trapped focus and return to the prior focus on close. The old XULOR2 controls no longer mount over the map. `test/fight_ui_preview.tscn` renders combat and result captures to `/tmp/fight-ui.png` and `/tmp/fight-result-ui.png` for visual checks at multiple window sizes.

## Full UI review

`test/ui_review_preview.tscn` captures login, creation, lobby, representative panels and the bug form at 1280×720 and 800×600. It traverses all twenty native panel routes, checks frame bounds and initial focus, and checks that baked creation controls stay keyboard reachable. Login's submit overlay has a visible focus ring and explicit Tab path. The bug form uses the native theme (stone window, gold primary Send), scrolls in small windows and receives a screenshot captured before it covers the arena. Chat send and the post-fight debrief use the es/en/fr string tables. The fixed baked screen artwork still contains Spanish lettering; its localization requires separate art variants.
