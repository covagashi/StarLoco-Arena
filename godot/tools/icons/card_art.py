#!/usr/bin/env python3
"""S38b: the art inside the card template (owner's option B of
card_template_options.py; the frame, the ribbon and the name are drawn by
src/ui/card_face.gd). Writes, into assets/ui/cards/:
  family/<family>.webp the family's white pictogram (160 px), for the art
                       window of the cards without a piece and the medallion
                       (hair.webp: the haircuts and hair colours, no family);
  coach/<card>.webp    a coach card's bare 3D piece (its icon without the
                       plate; a mark is its emblem on skin), 160 px;
  fighter/<card>.webp  the same for the fighter equipment cards;
  sub/<key>.webp       S47: a sub-family's pictogram (card_sub_glyphs.py), so
                       a pócima, a rune, a rocket or a gem each shows its own
                       object instead of the family's one icon; and
  ../../content/card_art.json  {card id: key}, which card_face.gd reads.
Run from godot/ after equip_icons.tscn (both tables) and garment_icons.tscn:
    python3 tools/icons/card_art.py            # everything
    python3 tools/icons/card_art.py --sub      # only sub/ and card_art.json
"""
import json
import os
import re
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, "tools/icons")
import badge_icon_options as opt   # noqa: E402  the Pen and the glyphs
import card_template_options as tpl   # noqa: E402  the family pictograms
import equip_icons                     # noqa: E402  the bare pieces
import card_sub_glyphs as sub          # noqa: E402  the sub-family pictograms

PX = 160
OUT = "assets/ui/cards"
FAMILIES = ["coach", "consumable", "combat", "cosmetic", "fusion", "dofus", "arena", "other", "fighter", "hair"]


def pictogram(fam):
    n = PX * opt.S
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    tpl.pictogram(ImageDraw.Draw(img), fam, (n * .14, n * .14, n * .72), opt.WHITE)
    return img.resize((PX, PX), Image.LANCZOS)


def fitted(p):
    f = PX * 0.94 / max(p.size)
    p = p.resize((max(1, int(p.width * f)), max(1, int(p.height * f))), Image.LANCZOS)
    out = Image.new("RGBA", (PX, PX), (0, 0, 0, 0))
    out.alpha_composite(p, ((PX - p.width) // 2, (PX - p.height) // 2))
    return out


# --- S47: the sub-family each card's art shows ------------------------------
# The Spanish names (assets/i18n/content_es.json "card.<id>") are the
# reference; the set's name ("set.<id>") breaks ties the name cannot (the
# arena rules). RULES are tried in order and the first that matches a card
# gives its pictogram:
#   (card types, pattern, base, variant, mods)
#   pattern  a regex on the lower-cased name ("set:<regex>" on its set's name);
#   base     a card_sub_glyphs BASES name, or "\1" for the pattern's first
#            group through ALIAS ("códice" → "codice");
#   variant  None, "=<name>" fixed, "\1" the first group, or a table below:
#            the longest of its keys found in the name (the set's name for a
#            "set:" rule) as a whole word wins.
#            A table value is a VARIANTS mark ("ígnea": "fuego") or
#            (name, rgb) for a colour accent ("rubí": ("rubi", (232, 40, 74)));
#   mods     card_sub_glyphs mods: "small", "ban", "badge:<mark>".
# The key (file name) is base_variant_mods. A card no rule takes keeps the
# family's pictogram (the haircuts keep hair.webp in card_face.gd).
CONS, DOFUS, FIREWORK, COLOUR, TITLE, EMOTE, FUSION, ARENA, RULE, PAPER = (
    {24}, {30}, {25}, {29}, {28}, {1}, {27}, {20}, {26}, {21})
POTION = {   # what a pócima does → the mark on its flask
    "alada": "ala", "acuática": "agua", "ígnea": "fuego", "pétrea": "tierra", "ráfaga": "aire",
    "brasas": "fuego", "sísmica": "tierra", "escarcha": "escarcha", "chispa": "rayo", "tormenta": "rayo",
    "ágil": "rapido", "esquiva": "rapido", "veloz": "rapido",
    "vista": "ojo", "vidente": "ojo", "clarividente": "ojo", "certero": "diana", "penetrante": "diana",
    "serena": "luna", "calma": "luna", "respiro": "luna", "reposo": "luna",
    "blindada": "escudo", "resguardada": "escudo", "invencible": "escudo", "cautelosa": "escudo",
    "incansable": "corazon", "aliento": "corazon", "alivio": "corazon", "consuelo": "corazon",
    "colosal": "fuerza", "estallido": "fuerza", "poderosa": "fuerza", "hierro": "fuerza",
    "alentadora": "coraje", "ánimo": "coraje", "coraje": "coraje", "valor": "coraje", "bravura": "coraje",
    "brío": "coraje", "arrojo": "coraje", "osadía": "coraje",
    "prospectora": "moneda", "rebusca": "moneda", "pegajosa": "pegajosa", "halo": "halo", "eco": "eco",
    "aprendiz": "estrella", "discípulo": "estrella", "experiencia": "estrella", "maestría": "estrella",
    "revivir": "cruz", "revivificante": "cruz",
}
RUNE = {"pegajosa": "pegajosa", "escurridiza": "escurridiza", "corpulenta": "corpulenta", "rápida": "rapida",
        "robusta": "robusta", "resistente": "resistente", "campeona": "campeona"}
STAT = {k: (k.replace("í", "i"), v) for k, v in sub.STAT.items()}
FLAVOUR = {"nata": (250, 240, 214), "plátano": (250, 220, 90), "cacao": (130, 82, 50), "melón": (170, 220, 110),
           "almendra": (214, 176, 128), "guinda": (178, 30, 60), "añil": (72, 70, 200), "coco": (236, 232, 222),
           "fresa": (240, 70, 100), "cítrico": (250, 170, 40), "naranja": (255, 140, 30), "pera": (190, 214, 80),
           "manzana": (120, 200, 70), "vainilla": (250, 232, 170), "reineta": (200, 180, 60),
           "ciruela": (130, 50, 140), "praliné": (170, 110, 60)}
ELEMENT = {"tierra": "tierra", "fuego": "fuego", "agua": "agua", "aire": "aire", "trueno": "rayo",
           "escarcha": "escarcha", "brasa": "fuego", "marea": "agua", "savia": "savia"}
TOOL = {"yunque": "yunque", "cayado": "cayado", "colmillo": "colmillo", "arado": "arado", "leñador": "hacha",
        "varita": "varita", "hoja": "hoja", "arco": "arco"}
WAND = {"desvelo": "ojo", "cardo": "hoja", "chispa": "rayo", "luna": "luna"}
CASE = {"campeón": "copa", "bufón": "rombo"}
FAIRY = {"verde": (60, 190, 90), "roja": (232, 56, 64), "amarilla": (250, 206, 40), "azul": (50, 120, 240)}
GEM = {"alba": (255, 176, 200), "ocaso": (255, 132, 60), "mediodía": (255, 222, 70), "eclipse": (60, 54, 86),
       "cénit": (184, 226, 255), "solsticio": (255, 190, 40), "equinoccio": (170, 140, 255),
       "plenilunio": (220, 226, 240), "meteoro": (255, 84, 72), "amanecer": (255, 200, 150),
       "zafiro": (40, 100, 240), "rubí": (232, 40, 74), "ópalo": (200, 240, 232), "turquesa": (40, 206, 196),
       "topacio": (240, 164, 40)}
GEMSTONE = {"zafiro": GEM["zafiro"], "rubí": GEM["rubí"]}
FIRE_COL = {"fuego": sub.FIRE, "agua": sub.WATER, "tierra": sub.EARTH, "aire": sub.AIR,
            "amarill[oa]": (255, 210, 50), "naranja": (255, 146, 40), "blanc[oa]": (226, 230, 242),
            "cian": (40, 214, 230), "índigo": (72, 74, 214), "violeta": (156, 80, 226)}
HAIR = {"negro carbón": (40, 40, 52), "azul noche": (40, 58, 130), "blanco nieve": (232, 236, 246),
        "rubio trigo": (232, 198, 106), "dorado sol": (242, 182, 48), "rosa chicle": (255, 120, 184),
        "cobrizo": (200, 100, 46), "gris plata": (170, 178, 192), "verde musgo": (110, 154, 58),
        "violeta": (156, 80, 226)}
SKIN = {"nácar": (246, 238, 230), "azul hielo": (168, 216, 240), "rosa pálido": (248, 200, 200),
        "ébano": (90, 58, 42), "bronce": (176, 122, 64), "melocotón": (255, 190, 148),
        "terracota": (192, 96, 60), "gris ceniza": (154, 160, 168), "verde oliva": (138, 154, 74),
        "lila": (200, 168, 232)}
EYES = {"ámbar": (240, 160, 32), "carmesí": (208, 32, 60), "plata": (184, 192, 204)}
ISLE = {"acertijos": "interrogacion", "mareas": "ola", "aurora": "sol", "eco": "eco", "musgo": "hoja",
        "estrellas": "estrella"}
PRICE = {"hechizo": "destello", "guerreros": "espadas", "clase": "figura"}
MATERIAL = {"piedra": "roca", "madera": "tronco", "cristal": "gema"}
GRAN = ["badge:destello"]
ALIAS = {"códice": "codice", "hoja": "hoja_papel", "cinturón": "cinturon", "máscara": "mascara",
         "tocar": "laud", "señalar": "senalar", "mirador": "faro", "ciénaga": "cienaga", "volcán": "volcan",
         "jardín": "jardin", "bastión": "bastion", "callejón": "callejon", "estrella": "estrella_fuego"}
RULES = [
    # consumables: the container is the sub-family, "gran" its sparkle
    (CONS, r"^media pócima", "media_pocima", "=cruz", []),
    (CONS, r"^pócima sagrada", "pocima", "=cruz", ["badge:halo"]),
    (CONS, r"^gran pócima", "pocima", POTION, GRAN),
    (CONS, r"^pócima", "pocima", POTION, []),
    (CONS, r"^gran (pomada|elixir|ritual|bandera)", r"\1", None, GRAN),
    (CONS, r"^gran conjuro", "conjuro", "=estrella", GRAN),
    (CONS, r"^conjuro", "conjuro", "=estrella", []),
    (CONS, r"^(pomada|elixir|ritual|bandera|estandarte|polvo)", r"\1", None, []),
    (CONS, r"^runa menor", "runa", RUNE, ["small"]),
    (CONS, r"^runa suprema", "runa", RUNE, ["badge:corona"]),
    (CONS, r"^runa", "runa", RUNE, []),
    # the DOFUS objects
    (DOFUS, r"^canica", "canica", None, []),
    (DOFUS, r"^(caramelo|gominola) de", r"\1", FLAVOUR, []),
    (DOFUS, r"^(hoja|rollo|tomo|códice|fajo) de", r"\1", STAT, []),
    (DOFUS, r"^gorrión", "gorrion", None, []),
    (DOFUS, r"^conjuro", "conjuro", WAND, []),
    (DOFUS, r"^huevo", "huevo", ELEMENT, []),
    (DOFUS, r"^sello", "sello", TOOL, []),
    (DOFUS, r"^hadita", "hadita", FAIRY, []),
    (DOFUS, r"^estuche", "estuche", CASE, []),
    (DOFUS, r"^gema", "gema", GEM, []),
    (DOFUS, r"^esencia", "esencia", ELEMENT, []),
    (DOFUS, r"^(amuleto|anillo|botas|capa|cinturón|máscara) nocturn", r"\1", None, ["badge:luna"]),
    # cosmetics
    (FIREWORK, r"^(cohete|estrella|fuente)", r"\1", FIRE_COL, []),
    (COLOUR, r"^(pelo|piel)", r"\1", None, []),      # the colour: below, by the table of its kind
    (COLOUR, r"^ojos", "ojos", EYES, []),
    (TITLE, r"", "titulo", None, []),
    (EMOTE, r"^(aplaudir|leer|declarar|enfadarse|tocar|señalar|troncharse|asustarse|llorar|negar)", r"\1", None, []),
    # fusion
    (FUSION, r"^pócima", "pocima", "=gema", []),
    (FUSION, r"^(fragmento|brillo)", r"\1", GEMSTONE, []),
    (FUSION, r"en bruto$", "bruto", GEMSTONE, []),
    # arenas
    (ARENA, r"^islote", "islote", ISLE, []),
    (ARENA, r"^(mirador|torre|bosque|ciénaga|volcán|vado|cueva|sendero|ensenada|dunas|jardín|bastión|callejón)",
     r"\1", None, []),
    # combat rules (the ones that name a spell, an item or a class draw its
    # art in card_face.gd; these keys are their fallback)
    (RULE, r"^@spell:", "hechizo", None, []),
    (RULE, r"^@fcard:", "espadas", None, []),
    (RULE, r"^@breed:", "figura", None, []),
    (RULE, r"^hechizo vetado", "hechizo", None, ["ban"]),
    (RULE, r"^clase vetada", "figura", None, ["ban"]),
    (RULE, r"^martillo vetado", "martillo", None, ["ban"]),
    (RULE, r"^capa .*vetada", "capa", None, ["ban"]),
    (RULE, r"^equipamiento vetado", "jersey", None, ["ban"]),
    (RULE, r"^precio de?l? ", "etiqueta", PRICE, []),
    (RULE, r"^(inflación|subida de precios)", "precio_sube", None, []),
    (RULE, r"por los suelos", "precio_baja", None, []),
    (RULE, r"^rebajas", "rebaja", None, []),
    (RULE, r"^caja de guerra", "cofre", None, []),
    (RULE, r"^premio gordo", "bolsa", None, []),
    (RULE, r"^quiebra", "quiebra", None, []),
    (RULE, r"^(\d+) s por turno", "reloj", r"\1", []),
    (RULE, r"^\+\d+ turnos", "turnos", None, ["badge:mas"]),
    (RULE, r"^[−-]\d+ turnos", "turnos", None, ["badge:menos"]),
    (RULE, r"^partida corta", "reloj_arena", None, []),
    (RULE, r"^muerte súbita", "calavera", None, []),
    (RULE, r"^equipo más grande", "equipo", None, ["badge:mas"]),
    (RULE, r"^equipo reducido", "equipo", None, ["badge:menos"]),
    (RULE, r"^un solo luchador", "figura", None, []),
    (RULE, r"^dos luchadores", "dos", None, []),
    (RULE, r"^clase oculta", "clase_oculta", None, ["badge:interrogacion"]),
    (RULE, r"^stats ocultas", "ojo_tachado", None, []),
    (RULE, r"^arena a elegir", "mapa", "=interrogacion", []),
    (RULE, r"set:^arenas de", "mapa", MATERIAL, []),
    (RULE, r"set:^hechizos de clase", "hechizo", None, []),
    # the rest: the pets' parts by slot, the clan and tournament papers
    ({15}, r"", "mascota_nucleo", None, []),
    ({16}, r"", "mascota_patas", None, []),
    ({17}, r"", "mascota_cabeza", None, []),
    ({18}, r"", "mascota_cuerpo", None, []),
    ({19}, r"", "mascota_juguete", None, []),
    (PAPER, r"clan", "clan", None, []),
    (PAPER, r"torneo privado", "pase", None, ["badge:candado"]),
    (PAPER, r"torneo", "torneo", None, []),
]
COLOUR_OF = {"pelo": HAIR, "piel": SKIN}


def ascii_key(t):
    t = t.lower()
    for a, b in zip("áéíóúüñ", "aeiouun"):
        t = t.replace(a, b)
    return re.sub(r"[^a-z0-9]+", "_", t).strip("_")


def lookup(table, name):
    """The variant of the longest key of `table` found in `name` as a word:
    (variant, colour)."""
    for k in sorted(table, key=len, reverse=True):
        m = re.search(r"(?<!\w)" + k + r"(?!\w)", name)
        if m:
            v = table[k]
            if isinstance(v, str):
                return v, None
            if len(v) == 2 and not isinstance(v[0], int):     # (name, rgb)
                return v[0] or ascii_key(m.group(0)), tuple(v[1])
            return ascii_key(m.group(0)), tuple(v)
    return None, None


def classify(ctype, name, set_name):
    """(base, variant, colour, mods) for a card, or None."""
    name = name.lower().strip()
    for types, pat, base, var, mods in RULES:
        if ctype not in types:
            continue
        on = set_name.lower() if pat.startswith("set:") else name
        m = re.search(pat[4:] if pat.startswith("set:") else pat, on)
        if not m:
            continue
        if base == r"\1":
            base = ALIAS.get(m.group(1), m.group(1))
        colour = None
        if var is None:
            variant = None
            if base in COLOUR_OF:
                variant, colour = lookup(COLOUR_OF[base], name)
        elif isinstance(var, dict):
            variant, colour = lookup(var, on)
        elif var == r"\1":
            variant = m.group(1)
        else:
            variant = var[1:]
        return base, variant, colour, list(mods)
    return None


def key_of(spec):
    base, variant, _, mods = spec
    parts = [base] + ([variant] if variant else [])
    for m in mods:
        parts.append({"ban": "veto", "small": "menor"}.get(m, m[6:] if m.startswith("badge:") else m))
    return "_".join(parts)


def sub_art():
    """Classify every card, draw each sub-family pictogram once, write the
    map. Returns (keys drawn, cards mapped, ids left on the family icon)."""
    cards = json.load(open("assets/content/cards.json"))
    es = json.load(open("assets/i18n/content_es.json"))
    specs, art, bare = {}, {}, []
    for cid in sorted(cards, key=int):
        ctype = int(cards[cid].get("type", -1))
        name = str(es.get(f"card.{cid}", ""))
        spec = classify(ctype, name, str(es.get(f"set.{cards[cid].get('set', 0)}", "")))
        if spec is None:
            if not 2 <= ctype <= 13:      # coach gear shows its piece (haircuts: hair.webp)
                bare.append(cid)
            continue
        k = key_of(spec)
        if k in specs and specs[k] != spec:
            raise SystemExit(f"card {cid}: key {k} means two pictograms: {specs[k]} / {spec}")
        specs[k] = spec
        art[cid] = k
    os.makedirs(f"{OUT}/sub", exist_ok=True)
    for f in os.listdir(f"{OUT}/sub"):     # pictograms no card uses any more
        if f.split(".")[0] not in specs:
            os.remove(f"{OUT}/sub/{f}")
    for k, spec in sorted(specs.items()):
        sub.draw(spec, PX).save(f"{OUT}/sub/{k}.webp", quality=90, method=5)   # (6: 100x slower here, same bytes)
    with open("assets/content/card_art.json", "w") as f:
        json.dump(art, f, ensure_ascii=False, separators=(",", ":"), sort_keys=False)
        f.write("\n")
    return specs, art, bare


def main():
    specs, art, bare = sub_art()
    print(f"{len(specs)} sub-family pictograms for {len(art)} cards in {OUT}/sub; on the family's: {bare}")
    if "--sub" in sys.argv:
        return
    os.makedirs(f"{OUT}/family", exist_ok=True)
    for fam in FAMILIES:
        pictogram(fam).save(f"{OUT}/family/{fam}.webp", quality=90, method=6)
    pieces = json.load(open("art/equipment/pieces.json"))
    made = {}
    for table, src_dir in [("coach", "art/ui/out/equip_coach"), ("fighter", "art/ui/out/equip")]:
        os.makedirs(f"{OUT}/{table}", exist_ok=True)
        gj = os.path.join(src_dir, "garments.json")
        garments = set(json.load(open(gj))) if os.path.exists(gj) else set()
        n = 0
        for cid, piece in pieces[table].items():
            src = os.path.join(src_dir, f"{cid}.png")
            if not os.path.exists(src):
                continue
            if str(piece).startswith("mark_"):
                p = equip_icons.mark(str(piece)[5:])
            else:
                p = equip_icons.piece(src, cid in garments)
            if p is None:
                continue
            fitted(p).save(f"{OUT}/{table}/{cid}.webp", quality=88, method=6)
            n += 1
        made[table] = n
    print(f"{len(FAMILIES)} pictograms, {made['coach']} coach and {made['fighter']} fighter pieces in {OUT}")


if __name__ == "__main__":
    main()
