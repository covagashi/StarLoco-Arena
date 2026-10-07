# Lobby visual contract

The lobby extends login_screen.gd and creation_screen.gd. It is a fixed 1280×720 composition uniformly scaled and centered in the viewport. The existing art direction and requested composition are explicit; concept selection is not needed.

- Copperplate bold (`COPRGTB.TTF`), pale gold control text, olive stone surfaces, green training and gold ranked fight buttons.
- Inset stone frame with corner hardware, shaded button faces and soft shadows; title letters reuse `make_login_bg.word_tiles`.
- Coach alcove at (40,150,320,350); six central actions in two rows; chat at (50,524,630,134); nine illustrated menu controls at lower right.
- Every control has hover, pressed and keyboard focus feedback. Fight actions are disabled until ready and after disconnect. Emote/tool menus expose explicit empty states.
- The paper doll uses the creation screen animation loader and Palettes tint mapping. Chat stays a sibling under UI; native lobby panels use the existing higher GUI layer and model bus.

Regenerate from godot/: `python3 tools/make_lobby_bg.py`. This uses the same Pillow/font prerequisites as the existing generators. Runtime textures are loaded from files without an import-cache dependency.

## Current data limits

The existing localCoach producer supplies level 0 and an empty equipped-emote list; no coach-level State field exists yet. Tools are read from localCoach.tools or the retail top-level tools model. Registered item handlers receive a GWidget item context. Known emotes use the existing retail 4701 layout and incoming animation names display as bubbles. This checkout has no persisted emote-unequip handler or native retail tool executor; unavailable actions show an explicit message.

## Validation

`test/native_lobby.gd` runs the real windowed login, nine dialog toggles, chat focus, debug toggle, model refresh, shell remount, practice fight transition and return. Credentials are command-line arguments. Screenshots are written to `/private/tmp/native-lobby.png` and `/private/tmp/native-lobby-social.png`.

`test/window_skin.gd` checks missing app-skin border/title resources and custom-theme precedence. Legacy XML resources remain available outside the native lobby routes.


## Native lobby panels

`src/ui/lobby_panel.gd` is the common modal surface: olive/gold theme, Copperplate title, Tahoma controls, dimmed backdrop, bounded 1120×620 reference frame, and scrollable content. Containers own interior layout. Deferred layout resets prevent initial text minimum sizes from pushing the frame below the viewport. Close and Escape are shared, and Tab cycles inside the panel. Team combat actions stay in a fixed footer outside the scrolling roster/detail area.

`src/ui/lobby_panels.gd` provides native menu, team/evolution, statistics, inventory/collections, rankings, calendar, achievements, social, help, options, fighter creation with tinted preview, fighter equipment/spells, team creation, and clan creation/management/member statistics. These twenty logical dialog routes are registered in `main.gd`; runtime XML does not build them. The shared model still supplies content, and the existing handlers serialize all requests.

The dialog registry normalizes event names, prevents duplicate opens, supports nested native panels, and disconnects resize callbacks when legacy dialogs close. Plain `unloadDialog` from legacy templates also reaches the close router. Explicit close handlers take precedence so equipment and exchange cleanup keep their original behavior.

`test/native_panels.gd` exercises real mouse and Escape input on every route, duplicate opening, viewport bounds, a smaller window, tab switching, fighter preview, parent/child closing, menu-to-options navigation, and local populated fixtures. Fixture action spies prevent synthetic fighter IDs from reaching the server. Captures are written to `/private/tmp/panels-*.png`.

## Native combat HUD

`fight_view.tscn` now presents a native olive and gold combat HUD: arena and turn controls above the map, initiative chips at the upper right, chat at the lower left, and a horizontally scrolling spell and card bar at the lower right. Below 960 px wide, anchored chat and actions stack to keep both reachable. Turn controls, spell buttons and chat have a keyboard focus path. The result panel uses the same palette and Copperplate heading, with a fixed Continue action, scrolling card rewards, trapped focus and return to the prior focus on close. The old XULOR2 controls no longer mount over the map. `test/fight_ui_preview.tscn` renders combat and result captures to `/private/tmp/fight-ui.png` and `/private/tmp/fight-result-ui.png` for visual checks at multiple window sizes.

## Full UI review

`test/ui_review_preview.tscn` captures login, creation, lobby, representative panels and the bug form at 1280×720 and 800×600. It traverses all twenty native panel routes, checks frame bounds and initial focus, and checks that baked creation controls stay keyboard reachable. Login's submit overlay has a visible focus ring and explicit Tab path. The bug form uses the native olive/gold palette, scrolls in small windows and receives a screenshot captured before it covers the arena. Chat send and the post-fight debrief use the es/en/fr string tables. The fixed baked screen artwork still contains Spanish lettering; its localization requires separate art variants.
