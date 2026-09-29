#!/usr/bin/env python3
"""card_names.py — merge gamedata cards (data.bdat via dumpcards) with i18n
names (i18n.jar content.23.<id>) into godot/assets/gamedata/cards.json.

Usage:
  go run ./server/cmd/dumpcards server/data-dist /tmp/cards_raw.json
  python3 tools/asset-import/card_names.py /tmp/cards_raw.json \
      client/compiled/game/contents/i18n.jar godot/assets/gamedata/cards.json
"""

import json
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

    out = {}
    for cid, c in cards.items():
        out[cid] = {
            "name": names.get(int(cid), "Card %s" % cid),
            "type": c["type"],
            "set": c["set"],
            "value": c["value"],
            "price": c.get("price") or {},
            "unique": c.get("unique", False),
            "tradable": c.get("tradable", True),
        }
    json.dump(out, open(out_path, "w"))
    print("wrote", out_path, "cards:", len(out))


if __name__ == "__main__":
    main()
