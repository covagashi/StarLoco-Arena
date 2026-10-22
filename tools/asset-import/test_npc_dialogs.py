#!/usr/bin/env python3
"""Checks npc_dialogs.py's port of the client's text formatter (are_0.format)
and of the event-card description (asf_0.a).

The formatter cases are the ones the retail class carries in its own main()
(client/decompiled/core/are_0.java). Needs nothing git-ignored.

  python3 tools/asset-import/test_npc_dialogs.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from npc_dialogs import event_desc, retail_format, unescape  # noqa: E402

FORMAT_CASES = [
    (("coucou", 1, 2, 3), "coucou"),
    (("c'est [#1] chats [#2]", 2, "bleus"), "c'est 2 chats bleus"),
    (("c'est [#2] [#1]{[>2]?s:}", "chat", 1), "c'est 1 chat"),
    (("c'est [#2] [#1]{[>2]?s:}", "chat", 2), "c'est 2 chats"),
    (("{[~1]?[#1] a verrouillé le combat : :}Le combat est maintenant verrouillé", "chat"),
     "chat a verrouillé le combat : Le combat est maintenant verrouillé"),
    (("{[~1]? [#1] année{[>1]?s:}:}{[~1][~2]? et :}{[~2]?[#2] mois:}{[~1]?:{[~2][~3]? et :}"
      "{[~3]?[#3] jour{[>3]?s:}:}{[~2]?:{[~3][~4]? et :}{[~4]?[#4] heure{[>4]?s:}:}"
      "{[~3]?:{[~4][~5]? et :}{[~5]?[#5] minute{[>5]?s:}:}{[~4]?:{[~5][~6]? et :}"
      "{[~6]?[#6] seconde{[>6]?s:}:}}}}}", 0, 0, 0, 0, 45, 12),
     "45 minutes et 12 secondes"),
    # content.22 shapes the event cards use
    (("{[+1]?-[#1] PA :Pierde todos sus PA}", 2), "-2 PA "),
    (("{[+1]?-[#1] PA :Pierde todos sus PA}", 0), "Pierde todos sus PA"),
    (("+[#1] invocaci{[>1]?ones:ón}", 1), "+1 invocación"),
    (("+[#1] invocaci{[>1]?ones:ón}", 2), "+2 invocaciones"),
    (("[£1] PdV", -7), "7 PdV"),
    (("[#2] missing", 1), "[#2] missing"),
]

TEXTS = "\n".join([
    "content.22.13=+[#1] PA",
    "content.22.82=+[#1]% <image pixmap=\"jar:file:contents/gui.jar!/gui/miscellaneous/elements/ALL.tga\" align=\"west\"></image>",
    "content.22.120=+[#1]% al Placaje",
    "content.27.1=Efectos: a\\nDuración: 1 turno",
    "content.27.2=",
    "cast.effectDescription=<b>Efecto{[~2]?s:}:</b> [#1]\\n",
    "cast.criticalEffectDescription=<b>Crítico{[~2]?s:}: </b>[#1]\\n",
    "cast.durationDescription=([#1] <image pixmap=\"jar:file:contents/gui.jar!/gui/miscellaneous/elements/TURN.tga\" align=\"west\"></image>)",
    "cast.infiniteDuration=(Infinita)",
])

EVENT_CASES = [
    # flag off: only the hand-written content.27, escapes resolved
    ({"flag": False, "effects": [{"a": 13, "p": [1], "d": [1, 0]}]}, 1,
     "Efectos: a\nDuración: 1 turno"),
    # flag on: the effect list, durations, the turn icon as a word
    ({"flag": True, "effects": [{"a": 82, "p": [50], "d": [2, 0]},
                                {"a": 120, "p": [100], "d": None}]}, 2,
     "Efecto: +50% de daño (2 turnos), +100% al Placaje"),
    ({"flag": True, "effects": [{"a": 13, "p": [1], "d": [63, 0]},
                                {"a": 13, "p": [2], "d": [1, 0], "c": True}]}, 2,
     "Efecto: +1 PA (Infinita)\nCrítico: +2 PA (1 turno)"),
]


def main() -> int:
    bad = 0
    for args, want in FORMAT_CASES:
        got = retail_format(*args)
        if got != want:
            print("FAIL format%r\n  want %r\n  got  %r" % (args, want, got))
            bad += 1
    if unescape("a\\nb\\%c") != "a\nb%c":
        print("FAIL unescape")
        bad += 1
    for ev, eid, want in EVENT_CASES:
        got = event_desc(ev, eid, TEXTS, "es")
        if got != want:
            print("FAIL event %d\n  want %r\n  got  %r" % (eid, want, got))
            bad += 1
    total = len(FORMAT_CASES) + 1 + len(EVENT_CASES)
    print("%d/%d ok" % (total - bad, total))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
