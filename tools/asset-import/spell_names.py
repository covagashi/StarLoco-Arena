#!/usr/bin/env python3
"""spell_names.py — merge gamedata spells (data.bdat via dumpspells) with
i18n names (i18n.jar content.3.<id>) into godot/assets/gamedata/spells.json.

Usage:
  go run ./server/cmd/dumpspells server/data-dist /tmp/spells_raw.json
  python3 tools/asset-import/spell_names.py /tmp/spells_raw.json \
      client/compiled/game/contents/i18n.jar godot/assets/gamedata/spells.json

Output: {"<breed>": [{"id","name","ap","min","max","value"}]} — one record per
breed-legal spell, name in English (client content key 3.<id>).
"""

import json
import re
import sys
import zipfile


def main() -> None:
    raw_path, i18n_jar, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
    spells = json.load(open(raw_path))

    with zipfile.ZipFile(i18n_jar) as z:
        texts = z.read("i18n/texts_en.properties").decode("utf-8", "replace")
    names = {int(m.group(1)): m.group(2).strip()
             for m in re.finditer(r"^content\.3\.(\d+)=(.*)$", texts, re.M)}

    out = {}
    for breed, lst in spells.items():
        out[breed] = [
            {
                "id": s["id"],
                "name": names.get(s["id"], "Spell %d" % s["id"]),
                "ap": s["ap"],
                "min": s["min"],
                "max": s["max"],
                "value": s["value"],
            }
            for s in sorted(lst, key=lambda r: r["id"])
        ]
    with open(out_path, "w") as f:
        json.dump(out, f, indent=1)
    print("wrote", out_path, "breeds:", len(out),
          "total:", sum(len(v) for v in out.values()))


if __name__ == "__main__":
    main()
