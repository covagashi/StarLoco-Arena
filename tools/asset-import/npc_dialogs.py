#!/usr/bin/env python3
"""npc_dialogs.py — merge gamedata NPC dialog replies (record 1500 via
dumpnpcdialogs) with i18n texts into godot/assets/gamedata/npcdialogs.json.

Retail wiring (client ni_0/ao_2/TN): an NPC element's desc is
"nameId;criterionId;defaultGroup;altGroup;style". Opening picks altGroup when
criterionId != -1 and its value is > 0, else defaultGroup. A group shows speech
text content.59.<groupId> plus reply rows (content.60 labels) ordered by
`order`; clicking runs `act` (1 = 26330 challenge launch [id][challengeModes[id]],
2 = 22003 criterion) then navigates to `next` (0 = close).

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


def main() -> None:
    raw_path, i18n_jar, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
    raw = json.load(open(raw_path))

    with zipfile.ZipFile(i18n_jar) as z:
        texts = z.read("i18n/texts_en.properties").decode("utf-8", "replace")
    names, speech, labels = table(texts, 29), table(texts, 59), table(texts, 60)

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

    out = {
        # content.29 doubles as the NPC/demon dialog TEXT table (names AND
        # speech bodies both index it); content.30 holds challenge names for
        # the défi picker lists on env 3/6 elements.
        "names": {str(k): v for k, v in names.items()},
        "challengeNames": {str(k): v for k, v in table(texts, 30).items()},
        "groups": groups,
        "challengeModes": raw.get("challengeModes") or {},
        # type-800 achievements: {id: {stats: {statId: thr}, cards: [id]}} —
        # the demon elements' gate checks (aau_1.a: every stat >= threshold
        # AND every card in the tome).
        "achievements": raw.get("achievements") or {},
    }
    json.dump(out, open(out_path, "w"), ensure_ascii=False)
    print("wrote", out_path, "groups:", len(groups), "names:", len(names))


if __name__ == "__main__":
    main()
