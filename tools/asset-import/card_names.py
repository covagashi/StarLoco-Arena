#!/usr/bin/env python3
"""card_names.py — merge gamedata cards (data.bdat via dumpcards) with i18n
names (i18n.jar content.23.<id>) into godot/assets/gamedata/cards.json, and
write the card set names (content.25.<id>, per language) to cardsets.json
next to it.

Usage:
  go run ./server/cmd/dumpcards server/data-dist /tmp/cards_raw.json
  python3 tools/asset-import/card_names.py /tmp/cards_raw.json \
      client/compiled/game/contents/i18n.jar godot/assets/gamedata/cards.json
"""

import json
import os
import re
import sys
import zipfile


def main() -> None:
    raw_path, i18n_jar, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
    cards = json.load(open(raw_path))

    with zipfile.ZipFile(i18n_jar) as z:
        texts = z.read("i18n/texts_en.properties").decode("utf-8", "replace")
    names = {int(m.group(1)): m.group(2).strip()
             for m in re.finditer(r"^content\.23\.(\d+)=(.*)$", texts, re.M)}

    # Pass every dumpcards field through (reqLevel feeds the client's fusion
    # math; a fixed field list here once dropped it) and add the name.
    out = {}
    for cid, c in cards.items():
        out[cid] = dict(c, name=names.get(int(cid), "Card %s" % cid))
    json.dump(out, open(out_path, "w"))
    print("wrote", out_path, "cards:", len(out))

    # Set ("panoplie") names: a Card Master's catalogue is one set, and the
    # inventory groups by set. {lang: {setId: name}}.
    sets = {}
    with zipfile.ZipFile(i18n_jar) as z:
        for lang in ("en", "es", "fr"):
            t = z.read("i18n/texts_%s.properties" % lang).decode("utf-8", "replace")
            sets[lang] = {m.group(1): m.group(2).strip()
                          for m in re.finditer(r"^content\.25\.(\d+)=(.*)$", t, re.M)}
    sets_path = os.path.join(os.path.dirname(out_path), "cardsets.json")
    json.dump(sets, open(sets_path, "w", encoding="utf-8"), ensure_ascii=False)
    print("wrote", sets_path, "sets:", len(sets["en"]))


if __name__ == "__main__":
    main()
