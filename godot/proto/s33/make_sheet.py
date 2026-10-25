#!/usr/bin/env python3
"""S33: compose capture.gd's PNGs into one labelled comparison sheet.

    python3 -I godot/proto/s33/make_sheet.py <capture_out_dir> <sheet.png>

Columns are the three techniques, rows the states; the footer carries the
measurements from measure.json.
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

FONT = "/usr/share/fonts/liberation-sans-fonts/LiberationSans-Regular.ttf"
BOLD = "/usr/share/fonts/liberation-sans-fonts/LiberationSans-Bold.ttf"
BG = (30, 31, 24)
INK = (240, 228, 196)
GOLD = (226, 189, 110)
MUTED = (168, 159, 134)

COLS = [
    ("A", "A — 3D en vivo", "modelo low-poly que Godot dibuja cada fotograma"),
    ("B", "B — 3D → sprites", "el mismo modelo horneado a PNG: 12 fps, resolución de juego"),
    ("C", "C — Recorte 2D", "piezas planas con pivotes: 2 vistas dibujadas + espejo"),
]
ROWS = [
    ("idle", "En juego (1x)"),
    ("idle_close", "Reposo (3x)"),
    ("walk_close", "Andar (3x)"),
    ("cast_close", "Lanzar, fuego (3x)"),
    ("hit", "Golpe recibido (1x)"),
    ("die_close", "Morir (3x)"),
    ("dirs", "Cuatro direcciones"),
]
W, H = 560, 330
LABEL_W = 170
PAD = 8


def main() -> None:
    src, dst = Path(sys.argv[1]), Path(sys.argv[2])
    m = json.loads((src / "measure.json").read_text())
    f = ImageFont.truetype(FONT, 17)
    fs = ImageFont.truetype(FONT, 15)
    fb = ImageFont.truetype(BOLD, 20)
    ft = ImageFont.truetype(BOLD, 30)
    head_h, col_h, foot_h = 70, 64, 330
    sheet = Image.new("RGB", (LABEL_W + 3 * (W + PAD), head_h + col_h + len(ROWS) * (H + PAD) + foot_h), BG)
    d = ImageDraw.Draw(sheet)
    d.text((PAD * 2, 18), "S33 — el mismo luchador con tres técnicas (arte de prueba, todo propio)", font=ft, fill=GOLD)
    for i, (_, title, sub) in enumerate(COLS):
        x = LABEL_W + i * (W + PAD)
        d.text((x + 6, head_h + 6), title, font=fb, fill=GOLD)
        d.text((x + 6, head_h + 34), sub, font=fs, fill=MUTED)
    y = head_h + col_h
    for state, label in ROWS:
        d.text((PAD * 2, y + H // 2 - 10), label, font=f, fill=INK)
        for i, (tech, _, _) in enumerate(COLS):
            im = Image.open(src / f"{tech}_{state}.png").convert("RGB")
            sheet.paste(im, (LABEL_W + i * (W + PAD), y))
        y += H + PAD
    # footer: element VFX + numbers
    el = Image.open(src / "elements.png").convert("RGB")
    sheet.paste(el, (LABEL_W, y + 10))
    d.text((PAD * 2, y + 20), "VFX por elemento", font=f, fill=INK)
    d.text((PAD * 2, y + 44), "(iguales para las", font=fs, fill=MUTED)
    d.text((PAD * 2, y + 62), "tres técnicas)", font=fs, fill=MUTED)
    d.text((LABEL_W + 10, y + 10 + H - 26), "fuego · agua · tierra · aire · neutro", font=fs, fill=INK)
    kb = m["bake_bytes_5anims_5dirs"] / 1024
    lines = [
        ("Animaciones", "las tres usan las MISMAS 5 poses procedurales (reposo, andar, lanzar, golpe, morir) para todas las clases"),
        ("Peso (medido B)", f"B: {kb:.0f} KB por clase con 5 anims × 5 direcciones ({m['bake_files']} PNG) → ~{kb * 2 / 1024:.1f} MB con 10 anims;"),
        ("", f"12 clases ≈ {kb * 2 * 12 / 1024:.0f} MB. Hoy, las animaciones retail ocupan 239 MB (4.245 PNG)."),
        ("Peso (estimado)", "A: un modelo glTF por clase, 0,1–0,3 MB. C: ~15 piezas PNG × 2 vistas, 0,2–0,5 MB por clase."),
        ("Coste por frame", f"12 luchadores andando, llvmpipe (CPU, solo comparativo): A {m['frame_ms_12_fighters_A']:.0f} ms, "
                            f"C {m['frame_ms_12_fighters_C']:.0f} ms. B real reproduce PNG: como C o menos."),
        ("", "A mejora mucho con la GPU de la Ally y con un solo viewport 3D para todos (el prototipo usa uno por luchador)."),
        ("Producción", "A: modelar + un rig común; 8 direcciones, zoom nítido y equipo sin redibujar."),
        ("", "B: lo mismo que A + horneado automático; aspecto pixel; cada cambio de ropa = rehornear."),
        ("", "C: dibujar las piezas de cada clase en 2 vistas; equipo = piezas nuevas; el más barato de mover."),
    ]
    x0 = LABEL_W + W + PAD + 10
    ly = y + 14
    for k, v in lines:
        d.text((x0, ly), k, font=f, fill=GOLD)
        d.text((x0 + 150, ly), v, font=fs, fill=INK)
        ly += 30
    sheet.save(dst)
    print(dst, sheet.size)


if __name__ == "__main__":
    main()
