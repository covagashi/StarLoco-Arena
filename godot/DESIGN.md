# Lobby visual contract

The lobby extends login_screen.gd and creation_screen.gd. It is a fixed 1280×720 composition uniformly scaled and centered in the viewport. The existing art direction and requested composition are explicit; concept selection is not needed.

- Copperplate bold (`COPRGTB.TTF`), pale gold control text, olive stone surfaces, green training and gold ranked fight buttons.
- Inset stone frame with corner hardware, shaded button faces and soft shadows; title letters reuse `make_login_bg.word_tiles`.
- Coach alcove at (40,150,320,350); six central actions in two rows; chat at (50,524,630,134); nine illustrated menu controls at lower right.
- Every control has hover, pressed and keyboard focus feedback. Fight actions are disabled until ready and after disconnect. Emote/tool menus expose explicit empty states.
- The paper doll uses the creation screen animation loader and Palettes tint mapping. Chat stays a sibling under UI; XULOR2 dialogs remain on their own higher layer.

Regenerate from godot/: `python3 tools/make_lobby_bg.py`. This uses the same Pillow/font prerequisites as the existing generators. Runtime textures are loaded from files without an import-cache dependency.

## Current data limits

The existing localCoach producer supplies level 0 and an empty equipped-emote list; no coach-level State field exists yet. Tools are read from localCoach.tools or the retail top-level tools model. Registered item handlers receive a GWidget item context. Known emotes use the existing retail 4701 layout and incoming animation names display as bubbles. This checkout has no persisted emote-unequip handler or native retail tool executor; unavailable actions show an explicit message.

## Validation

`test/native_lobby.gd` runs the real windowed login, nine dialog toggles, chat focus, debug toggle, model refresh, shell remount, practice fight transition and return. Credentials are command-line arguments. Screenshots are written to `/private/tmp/native-lobby.png` and `/private/tmp/native-lobby-social.png`.

`test/window_skin.gd` checks missing app-skin border/title resources and custom-theme precedence. Existing XML dialog content layouts, including Social tabs, are retained.
