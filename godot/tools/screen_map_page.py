#!/usr/bin/env python3
"""S47 (owner, point 3): the screen map's page.

    python3 godot/tools/screen_map_page.py DIR

DIR holds the runs of test/screen_map.gd (DIR/nuevo, DIR/veterano: each a
folder of NN-name.png plus index.tsv) and, optionally, DIR/notas.html (the
flow diagram and what the map shows, written by hand). Writes DIR/index.html:
the notes, then every screen grouped by area, each with how it was reached
(all the ways, when several lead to it) and a thumbnail that opens the full
capture. Thumbnails go to DIR/thumbs.
"""
import html
import os
import sys

from PIL import Image

RUNS = [("nuevo", "cuenta nueva"), ("veterano", "cuenta con datos")]
# area -> screens (base names, as screen_map.gd names the files), in order
AREAS = [
    ("Entrada", ["login", "creation-body", "creation-hair", "creation-skin", "intro-first"]),
    ("Lobby y búsquedas", ["lobby", "tile-story-extra", "tile-ranked", "tile-tourn"]),
    ("Reclutar", ["fighterCreationDialog", "create-fighter-tab0", "create-fighter-tab1",
        "create-fighter-tab2"]),
    ("Equipo e Historia", ["teamManagementDialog", "teamManagementDialog-tab1",
        "teamManagementDialog-tab2", "storyDialog"]),
    ("Inventario", ["cardBookDialog", "cardBookDialog-tab1", "coachEquipDialog"]),
    ("Torneos", ["calendarDialog", "calendarDialog-tab1", "calendarDialog-tab2"]),
    ("Ranking y fantasmas", ["ladderInformationDialog", "ghostDialog", "ghostDialog-tab1",
        "ghostDialog-tab2", "ghostDialog-tab3"]),
    ("El jefe: logros, estadísticas, amigos, buzón", ["coachStatisticsDialog", "achievementDialog",
        "achievementDialog-tab1", "socialDialog", "socialDialog-tab1", "socialDialog-tab2",
        "mailboxDialog"]),
    ("Servicios", ["cityDialog", "city-group0", "npcTalkDialog", "city-group1", "cardMasterDialog",
        "city-group2", "city-group3", "fusionLabDialog", "city-group4"]),
    ("Ayuda", ["tooltipDialog", "tooltipDialog-tab1", "tooltipDialog-tab2", "tooltipDialog-tab3",
        "tooltipDialog-tab4"]),
    ("Menú", ["menuDialog", "optionsDialog", "replayDialog"]),
    ("Combate", ["fight", "fight-later"]),
]


def read_runs(root):
    """base name -> {file, run, title, hows[]} (the first capture wins, every
    way to reach it is kept); plus the loose facts (rows with no file)."""
    screens, facts = {}, []
    for run, run_label in RUNS:
        tsv = os.path.join(root, run, "index.tsv")
        if not os.path.exists(tsv):
            continue
        for line in open(tsv, encoding="utf-8"):
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 3:
                continue
            file, title, how = parts[:3]
            if file == "":
                facts.append(f"{title} ({run_label})")
                continue
            base = file.split("-", 1)[1].rsplit(".", 1)[0]
            s = screens.setdefault(base, {"file": f"{run}/{file}", "run": run_label,
                "title": title, "hows": []})
            if how and how not in s["hows"]:
                s["hows"].append(how)
    return screens, facts


def thumb(root, rel):
    out = os.path.join("thumbs", rel.replace("/", "_").rsplit(".", 1)[0] + ".jpg")
    path = os.path.join(root, out)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if not os.path.exists(path):
        im = Image.open(os.path.join(root, rel)).convert("RGB")
        im.thumbnail((640, 360))
        im.save(path, quality=82)
    return out


def main():
    root = sys.argv[1]
    screens, facts = read_runs(root)
    notes = ""
    if os.path.exists(os.path.join(root, "notas.html")):
        notes = open(os.path.join(root, "notas.html"), encoding="utf-8").read()
    placed = set()
    parts = []
    for area, names in AREAS:
        cards = []
        for n in names:
            s = screens.get(n)
            if s is None:
                continue
            placed.add(n)
            cards.append(card(root, s))
        if cards:
            parts.append(f'<h2>{html.escape(area)}</h2><div class="grid">{"".join(cards)}</div>')
    rest = [screens[n] for n in screens if n not in placed]
    if rest:
        parts.append('<h2>Otras</h2><div class="grid">%s</div>' % "".join(card(root, s) for s in rest))
    fact_list = "".join(f"<li>{html.escape(f)}</li>" for f in facts)
    page = TEMPLATE.format(notes=notes, gallery="".join(parts),
        facts=f"<ul>{fact_list}</ul>" if facts else "", count=len(screens))
    open(os.path.join(root, "index.html"), "w", encoding="utf-8").write(page)
    print(f"{len(screens)} screens -> {os.path.join(root, 'index.html')}")


def card(root, s):
    hows = "".join(f"<li>{html.escape(h)}</li>" for h in s["hows"])
    warn = " warn" if any("SIN BOTÓN" in h for h in s["hows"]) else ""
    return (f'<figure class="card{warn}"><a href="{html.escape(s["file"])}" target="_blank">'
        f'<img loading="lazy" src="{html.escape(thumb(root, s["file"]))}" alt=""></a>'
        f'<figcaption><b>{html.escape(s["title"])}</b> <span class="run">{s["run"]}</span>'
        f'<ul>{hows}</ul></figcaption></figure>')


TEMPLATE = """<!doctype html>
<html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Mapa de pantallas</title>
<style>
:root {{ --bg:#f4f5f8; --ink:#1d2030; --faint:#6b7084; --coral:#ff5470; --line:#d6d9e2; --card:#fff; --warn:#fff1f3; }}
* {{ box-sizing:border-box; }}
body {{ margin:0; background:var(--bg); color:var(--ink); font:16px/1.5 system-ui, sans-serif; }}
main {{ max-width:1500px; margin:0 auto; padding:24px 16px 80px; }}
h1 {{ font-size:34px; margin:0 0 4px; }}
h2 {{ font-size:24px; margin:40px 0 12px; border-bottom:3px solid var(--ink); padding-bottom:4px; }}
h3 {{ font-size:19px; margin:24px 0 8px; }}
.sub {{ color:var(--faint); margin:0 0 20px; }}
.grid {{ display:grid; grid-template-columns:repeat(auto-fill, minmax(330px, 1fr)); gap:16px; }}
.card {{ margin:0; background:var(--card); border:1px solid var(--line); border-radius:6px; overflow:hidden; }}
.card.warn {{ background:var(--warn); border-color:var(--coral); }}
.card img {{ display:block; width:100%; aspect-ratio:16/9; object-fit:cover; border-bottom:1px solid var(--line); }}
figcaption {{ padding:8px 12px 10px; font-size:14px; }}
figcaption ul {{ margin:4px 0 0; padding-left:18px; color:var(--faint); }}
.run {{ font-size:12px; color:var(--faint); }}
.notes li {{ margin:4px 0; }}
.tree, .tree ul {{ list-style:none; margin:0; padding-left:22px; }}
.tree {{ padding-left:0; }}
.tree li {{ position:relative; padding:2px 0 2px 14px; }}
.tree li::before {{ content:""; position:absolute; left:0; top:0; bottom:0; border-left:2px solid var(--line); }}
.tree li::after {{ content:""; position:absolute; left:0; top:14px; width:10px; border-top:2px solid var(--line); }}
.tree li:last-child::before {{ bottom:auto; height:14px; }}
.node {{ display:inline-block; background:var(--card); border:1.5px solid var(--ink); border-radius:4px; padding:1px 8px; font-weight:600; font-size:14px; }}
.node.dup {{ border-color:#c58a00; background:#fff8e6; }}
.node.dead {{ border-color:var(--coral); background:var(--warn); }}
.how {{ color:var(--faint); font-size:13px; margin-left:6px; }}
.legend span {{ margin-right:14px; }}
@media (prefers-color-scheme: dark) {{
  :root:not([data-theme="light"]) {{ --bg:#14161f; --ink:#e7e9f2; --faint:#9aa0b5; --line:#33374a; --card:#1d2030; --warn:#3a1d25; }}
}}
:root[data-theme="dark"] {{ --bg:#14161f; --ink:#e7e9f2; --faint:#9aa0b5; --line:#33374a; --card:#1d2030; --warn:#3a1d25; }}
</style></head>
<body><main>
<h1>Mapa de pantallas · Pippop Arena</h1>
<p class="sub">S47, punto 3. {count} pantallas distintas, capturadas jugando con <code>test/screen_map.gd</code>
contra un servidor local (una cuenta nueva y una con datos), a 1280×720.
Pulsa una miniatura para verla entera.</p>
{notes}
{facts}
{gallery}
</main></body></html>
"""

if __name__ == "__main__":
    main()
