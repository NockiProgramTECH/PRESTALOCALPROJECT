#!/usr/bin/env python3
"""Compose le logo complet LesProduFao à partir de l'emblème.

Structure produite (fond transparent) :

    [ emblème circulaire : artisans + monument de Ouagadougou ]
    [ bandeau orange : « LesProdu » (blanc) + « Fao » (jaune)    ]
    [ « La communauté qui connecte les talents locaux »          ]
    [ pastilles de métiers (outils)                              ]

Usage :
    python tools/compose_brand_logo.py --emblem tools/logo_source_emblem.png \
        --fonts-dir /chemin/vers/plus-jakarta-sans --out tools/logo_source.png
"""
from __future__ import annotations

import argparse
import os

from PIL import Image, ImageDraw, ImageFont

PRIMARY = (255, 138, 61)
PRESSED = (224, 114, 40)
YELLOW = (255, 201, 60)
WHITE = (255, 255, 255)

W, H = 1680, 1780
CIRCLE_D = 1180
CIRCLE_CX, CIRCLE_CY = W // 2, 60 + CIRCLE_D // 2   # 840, 650

BANNER = (60, 1150, 1620, 1770)
BANNER_RADIUS = 120

NAME_CENTER_Y = 1330
TAGLINE_LINES = ("La communauté qui connecte", "les talents locaux")
TAGLINE_Y = (1470, 1535)
CHIP_R = 54
CHIP_Y = 1640
CHIP_GAP = 168
# Glyphes Font Awesome 4.7 : clé à molette, ciseaux, éclair, couverts,
# engrenage, points de suspension.
CHIP_GLYPHS = ["\uf0ad", "\uf0c4", "\uf0e7", "\uf0f5", "\uf013", "\uf141"]

FA_FONT = "/home/user/.venv/lib/python3.11/site-packages/rest_framework/static/rest_framework/fonts/fontawesome-webfont.ttf"


def trim_white(img: Image.Image, threshold: int = 244) -> Image.Image:
    """Recadre l'image sur son contenu non blanc."""
    rgb = img.convert("RGB")
    gray = rgb.convert("L").point(lambda v: 255 if v < threshold else 0)
    bbox = gray.getbbox()
    return img.crop(bbox) if bbox else img


def gradient(size: tuple[int, int]) -> Image.Image:
    """Dégradé diagonal citrus -> orange pressé."""
    w, h = size
    img = Image.new("RGB", size, PRIMARY)
    draw = ImageDraw.Draw(img)
    for y in range(h):
        ratio = y / max(h - 1, 1)
        for_t = ratio
        color = tuple(
            int(PRIMARY[i] + (PRESSED[i] - PRIMARY[i]) * for_t) for i in range(3)
        )
        draw.line([(0, y), (w, y)], fill=color)
    return img


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255
    )
    return mask


def draw_centered(
    draw: ImageDraw.ImageDraw, text: str, font, center_y: int, fill, cx: int = W // 2
) -> None:
    """Écrit `text` centré horizontalement et verticalement autour de `center_y`."""
    left, top, right, bottom = draw.textbbox((0, 0), text, font=font)
    draw.text(
        (cx - (right - left) / 2 - left, center_y - (bottom - top) / 2 - top),
        text,
        font=font,
        fill=fill,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--emblem", default="tools/logo_source_emblem.png")
    parser.add_argument("--fonts-dir", required=True, help="dossier des .ttf Plus Jakarta Sans")
    parser.add_argument("--out", default="tools/logo_source.png")
    args = parser.parse_args()

    extra_bold = ImageFont.truetype(os.path.join(args.fonts_dir, "PlusJakartaSans_800ExtraBold.ttf"), 196)
    semibold = ImageFont.truetype(os.path.join(args.fonts_dir, "PlusJakartaSans_600SemiBold.ttf"), 54)
    fa = ImageFont.truetype(FA_FONT, 52)
    fa_dots = ImageFont.truetype(FA_FONT, 30)

    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    # ---- Emblème circulaire ----
    emblem = trim_white(Image.open(args.emblem))
    side = min(emblem.size)
    emblem = emblem.crop(
        ((emblem.width - side) // 2, (emblem.height - side) // 2,
         (emblem.width + side) // 2, (emblem.height + side) // 2)
    ).resize((CIRCLE_D, CIRCLE_D), Image.LANCZOS).convert("RGBA")

    # Détourage circulaire : ne garder que le médaillon (le fond blanc de
    # l'image source disparaît, seul le halo blanc dessiné ensuite subsiste).
    circle_mask = Image.new("L", (CIRCLE_D * 4, CIRCLE_D * 4), 0)
    ImageDraw.Draw(circle_mask).ellipse(
        (0, 0, CIRCLE_D * 4 - 1, CIRCLE_D * 4 - 1), fill=255
    )
    emblem.putalpha(circle_mask.resize((CIRCLE_D, CIRCLE_D), Image.LANCZOS))

    # Contour blanc autour de l'emblème (détache le badge du fond)
    halo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(halo).ellipse(
        (CIRCLE_CX - CIRCLE_D // 2 - 16, CIRCLE_CY - CIRCLE_D // 2 - 16,
         CIRCLE_CX + CIRCLE_D // 2 + 16, CIRCLE_CY + CIRCLE_D // 2 + 16),
        fill=WHITE + (255,),
    )
    canvas.alpha_composite(halo)
    canvas.alpha_composite(emblem, (CIRCLE_CX - CIRCLE_D // 2, CIRCLE_CY - CIRCLE_D // 2))

    # ---- Bandeau ----
    bw, bh = BANNER[2] - BANNER[0], BANNER[3] - BANNER[1]
    banner = gradient((bw, bh)).convert("RGBA")
    banner.putalpha(rounded_mask((bw, bh), BANNER_RADIUS))
    canvas.alpha_composite(banner, (BANNER[0], BANNER[1]))

    draw = ImageDraw.Draw(canvas)

    # ---- Nom de marque (« LesProdu » blanc + « Fao » jaune) ----
    part_white, part_yellow = "LesProdu", "Fao"
    w1 = draw.textlength(part_white, font=extra_bold)
    w2 = draw.textlength(part_yellow, font=extra_bold)
    total = w1 + w2
    x = W // 2 - total / 2
    left, top, right, bottom = draw.textbbox((0, 0), part_white + part_yellow, font=extra_bold)
    y = NAME_CENTER_Y - (bottom - top) / 2 - top
    draw.text((x, y), part_white, font=extra_bold, fill=WHITE + (255,))
    draw.text((x + w1, y), part_yellow, font=extra_bold, fill=YELLOW + (255,))

    # ---- Signature ----
    for line, line_y in zip(TAGLINE_LINES, TAGLINE_Y):
        draw_centered(draw, line, semibold, line_y, WHITE + (235,))

    # ---- Pastilles de métiers ----
    start = W // 2 - (len(CHIP_GLYPHS) - 1) * CHIP_GAP // 2
    for index, glyph in enumerate(CHIP_GLYPHS):
        cx = start + index * CHIP_GAP
        draw.ellipse(
            (cx - CHIP_R, CHIP_Y - CHIP_R, cx + CHIP_R, CHIP_Y + CHIP_R),
            fill=WHITE + (255,),
        )
        font = fa_dots if glyph == "\uf141" else fa
        left, top_g, right, bottom = draw.textbbox((0, 0), glyph, font=font)
        draw.text(
            (cx - (right - left) / 2 - left, CHIP_Y - (bottom - top_g) / 2 - top_g),
            glyph,
            font=font,
            fill=PRESSED + (255,),
        )

    canvas.save(args.out)
    print("Logo composé :", args.out, canvas.size)


if __name__ == "__main__":
    main()
