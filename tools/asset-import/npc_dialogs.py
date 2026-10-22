#!/usr/bin/env python3
"""npc_dialogs.py — merge gamedata NPC dialog replies (record 1500 via
dumpnpcdialogs) with i18n texts into godot/assets/gamedata/npcdialogs.json.

Retail wiring (client ni_0/ao_2/TN): an NPC element's desc is
"nameId;criterionId;defaultGroup;altGroup;style". Opening picks altGroup when
criterionId != -1 and its value is > 0, else defaultGroup. A group shows speech
text content.59.<groupId> plus reply rows (content.60 labels) ordered by
`order`; clicking runs `act` (1 = 26330 challenge launch [id][challengeModes[id]],
2 = 22003 criterion) then navigates to `next` (0 = close).

The top-level tables are English. `locales` carries the same text tables for
es and fr (the retail jar ships all of them); the client reads the one that
matches its UI language and falls back to English per key.

Usage:
  go run ./server/cmd/dumpnpcdialogs server/data-dist /tmp/npcd_raw.json
  python3 tools/asset-import/npc_dialogs.py /tmp/npcd_raw.json \
      client/compiled/game/contents/i18n.jar godot/assets/gamedata/npcdialogs.json
"""

import json
import re
import sys
import zipfile


def table(texts: str, tbl: int) -> dict[int, str]:
    return {int(m.group(1)): m.group(2).strip()
            for m in re.finditer(r"^content\.%d\.(\d+)=(.*)$" % tbl, texts, re.M)}


# Client are_0.format: "{[cond]...?then:else}" blocks, resolved innermost
# first until none is left, then "[#n]" / "[£n]" (absolute value) arguments.
_COND = re.compile(r"\{((\[[^\[\]\{\}?:]*\])+)\?([^\{\}]*):([^\{\}]*)\}")
_TEST = re.compile(r"\[([^\[\]]*)([~*+\->!=])([^\[\]]*)\]")
_ARG = re.compile(r"\[([£#])([0-9]+)\]")


def _num(v):
    """are_0.h / are_0.i: a String argument compares as a number."""
    return float(v) if isinstance(v, str) else v


def retail_format(text: str, *args) -> str:
    def holds(m: re.Match) -> bool:
        ok = True
        for t in _TEST.finditer(m.group(1)):
            n2 = int(t.group(1)) if t.group(1) else 1
            n3 = int(t.group(3)) if t.group(3) else -1
            arg = args[n3 - 1] if 0 < n3 <= len(args) else None
            op = t.group(2)
            if op in ">=" and len(args) < n3:
                continue  # the retail skips the test, it does not fail it
            if op == ">":
                ok &= _num(arg) > n2
            elif op == "=":
                ok &= arg == n2 if not isinstance(arg, str) else arg == str(n2)
            elif op == "~":
                ok &= arg not in (None, 0, "")
            elif op == "!":
                ok &= arg in (None, 0, "")
            elif op == "+":
                ok &= arg is not None and _num(arg) > 0
            elif op == "-":
                ok &= arg is not None and not _num(arg) > 0
            else:  # "*": the speaker's sex, never set for these tables
                ok &= n2 == 0
        return ok

    while _COND.search(text):
        text = _COND.sub(lambda m: m.group(3) if holds(m) else m.group(4), text)

    def arg(m: re.Match) -> str:
        i = int(m.group(2)) - 1
        if i >= len(args) or args[i] is None:
            return m.group(0)
        return str(abs(args[i]) if m.group(1) == "£" else args[i])

    return _ARG.sub(arg, text)


def unescape(text: str) -> str:
    """java.util.Properties escapes ("\\n", "\\%"): the jar keeps them raw."""
    return re.sub(r"\\(.)", lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), text)


# The effect texts draw elements and the turn counter as inline images
# (gui/miscellaneous/elements/*.tga). The card's tooltip is plain text, so
# each becomes a word in the language of the table.
_ICON = re.compile(r'<image pixmap="[^"]*/([A-Z]+)\.tga"[^>]*></image>')
_ICON_WORDS = {
    "es": {"FIRE": "de daño de fuego", "EARTH": "de daño de tierra",
           "WATER": "de daño de agua", "WIND": "de daño de aire", "ALL": "de daño", "RESFIRE": "res. fuego",
           "RESEARTH": "res. tierra", "RESWATER": "res. agua",
           "RESWIND": "res. aire", "RESALL": "res. todos los elementos",
           "TURN": ("turno", "turnos")},
    "en": {"FIRE": "fire damage", "EARTH": "earth damage",
           "WATER": "water damage", "WIND": "air damage",
           "ALL": "damage", "RESFIRE": "fire res.", "RESEARTH": "earth res.",
           "RESWATER": "water res.", "RESWIND": "air res.",
           "RESALL": "all resistances", "TURN": ("turn", "turns")},
    "fr": {"FIRE": "dommages feu", "EARTH": "dommages terre",
           "WATER": "dommages eau", "WIND": "dommages air",
           "ALL": "dommages", "RESFIRE": "rés. feu", "RESEARTH": "rés. terre",
           "RESWATER": "rés. eau", "RESWIND": "rés. air",
           "RESALL": "rés. tous éléments", "TURN": ("tour", "tours")},
}


def plain(text: str, lang: str, count: int = 1) -> str:
    def word(m: re.Match) -> str:
        w = _ICON_WORDS[lang].get(m.group(1), "")
        if isinstance(w, tuple):
            w = w[count > 1]
        return w
    text = _ICON.sub(word, text)
    text = re.sub(r"</?b>", "", text)
    return re.sub(r"[ \t]+", " ", text)


def event_desc(ev: dict, eid: int, texts: str, lang: str) -> str:
    """Client tO.getDescription -> asf_0.a(id, flag, effects, null, 27)."""
    strings = {m.group(1): m.group(2).strip()
               for m in re.finditer(r"^(cast\.[A-Za-z]+)=(.*)$", texts, re.M)}
    effects = table(texts, 22)
    out = ""
    if ev.get("flag"):
        normal, critical = [], []
        for e in ev.get("effects") or []:
            params = [int(v) for v in (e.get("p") or [])]
            line = plain(retail_format(effects.get(e["a"], ""), *params), lang).strip()
            d = e.get("d") or []
            if d and d[0] >= 63:
                line += " " + plain(strings["cast.infiniteDuration"], lang)
            elif d and d[0] > 0:
                line += " " + plain(retail_format(strings["cast.durationDescription"], d[0]),
                                    lang, d[0])
            (critical if e.get("c") else normal).append(line)
        if normal:
            out += retail_format(strings["cast.effectDescription"], ", ".join(normal))
        if critical:
            out += retail_format(strings["cast.criticalEffectDescription"], ", ".join(critical))
    out += table(texts, 27).get(eid, "")
    return plain(unescape(out), lang).strip()


def build_groups(raw: dict, texts: str) -> dict:
    speech, labels = table(texts, 59), table(texts, 60)
    groups = {}
    for gid, g in raw["groups"].items():
        replies = []
        for r in g["replies"]:
            row = {"label": labels.get(r["text"], "…"), "next": r["next"]}
            if r["act"]:
                row["act"] = r["act"]
                row["params"] = r.get("params") or []
            replies.append(row)
        groups[gid] = {"text": speech.get(int(gid), ""), "replies": replies}
    return groups


def event_descs(raw: dict, texts: str, lang: str) -> dict:
    return {k: event_desc(ev, int(k), texts, lang)
            for k, ev in (raw.get("events") or {}).items()}


def localized(raw: dict, texts: str, lang: str) -> dict:
    """The text tables of one language; behaviour fields stay English-only."""
    return {
        "names": {str(k): v for k, v in table(texts, 29).items()},
        "challengeNames": {str(k): v for k, v in table(texts, 30).items()},
        "groups": build_groups(raw, texts),
        "achievementNames": {str(k): v for k, v in table(texts, 37).items()},
        "achievementDescs": {str(k): v for k, v in table(texts, 49).items()},
        "criterionNames": {str(k): v for k, v in table(texts, 48).items()},
        "summonNames": {str(k): v for k, v in table(texts, 10).items()},
        "eventNames": {str(k): v for k, v in table(texts, 8).items()},
        "eventDescs": event_descs(raw, texts, lang),
        "eventLore": {str(k): v for k, v in table(texts, 9).items()},
    }


def main() -> None:
    raw_path, i18n_jar, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
    raw = json.load(open(raw_path))

    with zipfile.ZipFile(i18n_jar) as z:
        jar = {lang: z.read("i18n/texts_%s.properties" % lang).decode("utf-8", "replace")
               for lang in ("en", "es", "fr")}
    texts = jar["en"]
    names = table(texts, 29)
    groups = build_groups(raw, texts)

    out = {
        # per-language text tables (same shapes as the English ones below)
        "locales": {lang: localized(raw, jar[lang], lang) for lang in ("es", "fr")},
        # content.29 doubles as the NPC/demon dialog TEXT table (names AND
        # speech bodies both index it); content.30 holds challenge names for
        # the défi picker lists on env 3/6 elements.
        "names": {str(k): v for k, v in names.items()},
        "challengeNames": {str(k): v for k, v in table(texts, 30).items()},
        "groups": groups,
        "challengeModes": raw.get("challengeModes") or {},
        # type-800 achievements: {id: {stats, cards, prev, super, cat, sub,
        # pts, hid}} — the demon elements' gate checks (aau_1.a) AND the
        # achievements pane's list filter (qy_2). Names/descriptions index
        # content.37 / content.49; condition rows name criteria via
        # content.48 (aea_1/ako).
        "achievements": raw.get("achievements") or {},
        "achievementNames": {str(k): v for k, v in table(texts, 37).items()},
        "achievementDescs": {str(k): v for k, v in table(texts, 49).items()},
        "criterionNames": {str(k): v for k, v in table(texts, 48).items()},
        # type-300 summon templates (jz_2 -> aJt): {id: {hp, ap, mp, look}} —
        # the running-effect spawn carries only the template id; the client
        # builds name/stats locally. Names index content.10 (aJt.getName).
        "summons": raw.get("summons") or {},
        "summonNames": {str(k): v for k, v in table(texts, 10).items()},
        # per-round event-card names index content.8 (tO title) — the 8100
        # tail carries the drawn eventId for display only.
        "eventNames": {str(k): v for k, v in table(texts, 8).items()},
        # and the card's description on hover (fightEventCards): for the 36
        # events with the description flag, the effect list the retail writes
        # out of the event's effects (tO.getDescription -> asf_0, ported in
        # event_desc), then content.27, the hand-written text the other 15
        # carry. content.9 is the flavour text.
        "eventDescs": event_descs(raw, texts, "en"),
        "eventLore": {str(k): v for k, v in table(texts, 9).items()},
    }
    json.dump(out, open(out_path, "w"), ensure_ascii=False)
    print("wrote", out_path, "groups:", len(groups), "names:", len(names),
          "achievements:", len(out["achievements"]),
          "summons:", len(out["summons"]))


if __name__ == "__main__":
    main()
