#!/usr/bin/env python3
"""Génère toutes les déclinaisons du logo de marque (site web + application).

Usage :
    python tools/generate_brand_assets.py --source chemin/logo.png

Le fichier source doit être une image carrée (PNG) du logo — fond blanc ou
transparent. Le script produit :

Site web Django (`PrestLocal/`)
    static/images/logo.png                 logo complet (fond transparent)
    static/images/logo-mark.png            emblème circulaire seul (en-têtes, favicon)
    static/pwa/icon-*.png                  icônes PWA (emblème, 48 → 512 px)
    static/icon/favicon.ico                favicon multi-résolutions
    static/apple-touch-icon.png            icône iOS (180 px)

Application Flutter (`presta_local_flutter/`)
    assets/images/logo.png                 logo complet (écrans de démarrage)
    assets/images/logo_mark.png            emblème circulaire seul (en-têtes, marque)
    android/.../drawable-*/splash_logo.png écrans de démarrage Android
    ios/.../LaunchImage*.png               écran de démarrage iOS
    android/.../mipmap-*/ic_launcher.png   icône de lancement Android
    ios/.../AppIcon.appiconset/*.png       icônes iOS (sans transparence)
    macos/.../AppIcon.appiconset/*.png     icônes macOS
    web/favicon.png, web/icons/*.png       PWA Flutter web
    windows/runner/resources/app_icon.ico  icône Windows
"""
from __future__ import annotations

import argparse
import os

from PIL import Image, ImageDraw

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEB = os.path.join(REPO, "PrestLocal")
APP = os.path.join(REPO, "presta_local_flutter")

MAGIC = (255, 0, 255)  # couleur sentinelle du flood fill


# ---------------------------------------------------------------------------
# Traitement du logo
# ---------------------------------------------------------------------------
def remove_outer_white(img: Image.Image, tolerance: int = 60) -> Image.Image:
    """Rend transparent le blanc extérieur (celui qui touche les bords)."""
    rgb = img.convert("RGB")
    w, h = rgb.size
    seeds = [
        (0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1),
        (w // 2, 0), (w // 2, h - 1), (0, h // 2), (w - 1, h // 2),
    ]
    for seed in seeds:
        try:
            ImageDraw.floodfill(rgb, seed, MAGIC, thresh=tolerance)
        except Exception:  # pixel déjà converti, etc.
            pass

    rgba = rgb.convert("RGBA")
    pixels = rgba.load()
    for y in range(h):
        for x in range(w):
            r, g, b, _ = pixels[x, y]
            if (r, g, b) == MAGIC:
                pixels[x, y] = (0, 0, 0, 0)
    return rgba


def trim_and_pad(img: Image.Image, pad_ratio: float = 0.01) -> Image.Image:
    """Recadre sur le contenu puis ajoute une marge transparente régulière."""
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    size = max(img.size)
    pad = int(size * pad_ratio)
    side = size + 2 * pad
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.alpha_composite(img, ((side - img.width) // 2, (side - img.height) // 2))
    return canvas


def fit(img: Image.Image, size: int, fill: float, background) -> Image.Image:
    """Place le logo centré dans un carré de `size` px."""
    canvas = Image.new("RGBA", (size, size), background)
    target = max(1, int(size * fill))
    ratio = min(target / img.width, target / img.height)
    resized = img.resize(
        (max(1, int(img.width * ratio)), max(1, int(img.height * ratio))),
        Image.LANCZOS,
    )
    canvas.alpha_composite(resized, ((size - resized.width) // 2, (size - resized.height) // 2))
    return canvas


def flatten(img: Image.Image, background=(255, 255, 255)) -> Image.Image:
    """Aplatit la transparence (iOS refuse les icônes avec canal alpha)."""
    canvas = Image.new("RGBA", img.size, background + (255,))
    canvas.alpha_composite(img)
    return canvas.convert("RGB")


def make_mark(logo: Image.Image, top_ratio: float = 0.58) -> Image.Image:
    """Emblème circulaire (partie haute du logo), détouré en cercle.

    Sert aux en-têtes/petites tailles où le texte du logo serait illisible.
    """
    size = logo.width
    top = logo.crop((0, 0, size, int(size * top_ratio)))
    bbox = top.getbbox()
    if bbox:
        top = top.crop(bbox)
    side = max(top.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.alpha_composite(top, ((side - top.width) // 2, (side - top.height) // 2))

    mask = Image.new("L", (side * 4, side * 4), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, side * 4 - 1, side * 4 - 1), fill=255)
    mask = mask.resize((side, side), Image.LANCZOS)
    square.putalpha(
        Image.composite(square.getchannel("A"), Image.new("L", (side, side), 0), mask)
    )
    return square


# ---------------------------------------------------------------------------
# Écriture des fichiers
# ---------------------------------------------------------------------------
def save(img: Image.Image, path: str, max_side: int | None = None) -> None:
    """Écrit le PNG (redimensionné si `max_side` est fourni) puis affiche son poids."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if max_side and max(img.size) > max_side:
        ratio = max_side / max(img.size)
        img = img.resize(
            (max(1, int(img.width * ratio)), max(1, int(img.height * ratio))),
            Image.LANCZOS,
        )
    if path.lower().endswith(".png"):
        img.save(path, optimize=True, compress_level=9)
    else:
        img.save(path)
    size_kb = os.path.getsize(path) / 1024
    print(f"  ✔ {os.path.relpath(path, REPO)}  ({img.width}×{img.height}, {size_kb:.0f} Ko)")


def build_web(logo: Image.Image, mark: Image.Image) -> None:
    print("Site web (Django) :")
    save(logo, os.path.join(WEB, "static/images/logo.png"), max_side=640)
    save(mark, os.path.join(WEB, "static/images/logo-mark.png"), max_side=192)

    # Icônes PWA — fond blanc opaque (maskable = logo dans la zone sûre de 80 %).
    for name, size, maskable in [
        ("icon-48x48.png", 48, False),
        ("icon-72x72.png", 72, True),
        ("icon-96x96.png", 96, False),
        ("icon-144x144.png", 144, False),
        ("icon-152x152.png", 152, False),
        ("icon-192x192.png", 192, True),
        ("icon-384x384.png", 384, False),
        ("icon-512x512.png", 512, True),
    ]:
        fill = 0.74 if maskable else 0.86
        icon = fit(mark, size, fill, (255, 255, 255, 255))
        save(icon, os.path.join(WEB, f"static/pwa/{name}"))

    # Favicon + icône iOS
    sizes = [(16, 16), (32, 32), (48, 48)]
    icons = [fit(mark, s, 0.92, (255, 255, 255, 255)).convert("RGB") for s, _ in sizes]
    icons[-1].save(
        os.path.join(WEB, "static/icon/favicon.ico"),
        format="ICO",
        sizes=sizes,
    )
    print("  ✔ PrestLocal/static/icon/favicon.ico")
    save(fit(mark, 180, 0.86, (255, 255, 255, 255)), os.path.join(WEB, "static/apple-touch-icon.png"))


def build_app(logo: Image.Image, mark: Image.Image) -> None:
    print("Application Flutter :")
    save(logo, os.path.join(APP, "assets/images/logo.png"), max_side=900)
    save(mark, os.path.join(APP, "assets/images/logo_mark.png"), max_side=512)

    # Android
    for folder, size in [
        ("mipmap-mdpi", 48),
        ("mipmap-hdpi", 72),
        ("mipmap-xhdpi", 96),
        ("mipmap-xxhdpi", 144),
        ("mipmap-xxxhdpi", 192),
    ]:
        icon = fit(mark, size, 0.82, (255, 255, 255, 255))
        save(icon, os.path.join(APP, f"android/app/src/main/res/{folder}/ic_launcher.png"))

    # iOS (sans transparence)
    ios_dir = os.path.join(APP, "ios/Runner/Assets.xcassets/AppIcon.appiconset")
    for name in sorted(os.listdir(ios_dir)):
        if not name.endswith(".png"):
            continue
        side = float(name.split("Icon-App-")[1].split("x")[0].split("@")[0])
        scale = int(name.split("@")[1].split("x")[0])
        icon = flatten(fit(mark, int(round(side * scale)), 0.84, (255, 255, 255, 255)))
        icon.save(os.path.join(ios_dir, name))
        print("  ✔", os.path.relpath(os.path.join(ios_dir, name), REPO))

    # macOS
    macos_dir = os.path.join(APP, "macos/Runner/Assets.xcassets/AppIcon.appiconset")
    for name in sorted(os.listdir(macos_dir)):
        if not name.startswith("app_icon_") or not name.endswith(".png"):
            continue
        side = int(name.replace("app_icon_", "").replace(".png", ""))
        icon = fit(mark, side, 0.84, (255, 255, 255, 255))
        save(icon, os.path.join(macos_dir, name))

    # Web (Flutter)
    save(fit(mark, 48, 0.92, (255, 255, 255, 255)), os.path.join(APP, "web/favicon.png"))
    save(fit(mark, 192, 0.86, (255, 255, 255, 255)), os.path.join(APP, "web/icons/Icon-192.png"))
    save(fit(mark, 512, 0.86, (255, 255, 255, 255)), os.path.join(APP, "web/icons/Icon-512.png"))
    save(fit(mark, 192, 0.74, (255, 255, 255, 255)), os.path.join(APP, "web/icons/Icon-maskable-192.png"))
    save(fit(mark, 512, 0.74, (255, 255, 255, 255)), os.path.join(APP, "web/icons/Icon-maskable-512.png"))

    # Écrans de démarrage natifs (logo complet)
    for folder, width in [
        ("drawable-mdpi", 200),
        ("drawable-hdpi", 300),
        ("drawable-xhdpi", 400),
        ("drawable-xxhdpi", 560),
        ("drawable-xxxhdpi", 720),
    ]:
        splash = logo.resize(
            (width, int(logo.height * width / logo.width)), Image.LANCZOS
        )
        save(splash, os.path.join(APP, f"android/app/src/main/res/{folder}/splash_logo.png"))

    # iOS LaunchImage (1x / 2x / 3x)
    launch_dir = os.path.join(APP, "ios/Runner/Assets.xcassets/LaunchImage.imageset")
    for name, width in [("LaunchImage.png", 200), ("LaunchImage@2x.png", 400), ("LaunchImage@3x.png", 600)]:
        splash = logo.resize((width, int(logo.height * width / logo.width)), Image.LANCZOS)
        save(splash, os.path.join(launch_dir, name))

    # Windows
    ico_sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    icons = [fit(mark, s, 0.86, (255, 255, 255, 255)).convert("RGB") for s, _ in ico_sizes]
    ico_path = os.path.join(APP, "windows/runner/resources/app_icon.ico")
    os.makedirs(os.path.dirname(ico_path), exist_ok=True)
    icons[-1].save(ico_path, format="ICO", sizes=ico_sizes)
    print("  ✔", os.path.relpath(ico_path, REPO))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, help="image source du logo (PNG carré)")
    parser.add_argument("--keep-background", action="store_true",
                        help="ne pas détourer le fond blanc extérieur")
    parser.add_argument("--mark-ratio", type=float, default=0.58,
                        help="hauteur de l'emblème (partie haute du logo) à détourer")
    parser.add_argument("--mark-source", default=None,
                        help="image du médaillon seul (sinon : recadrage du logo)")
    args = parser.parse_args()

    source = Image.open(args.source).convert("RGBA")
    print(f"Source : {args.source} — {source.size[0]}×{source.size[1]} px")

    if args.keep_background:
        logo = source
    else:
        logo = trim_and_pad(remove_outer_white(source))
        print(f"Logo détouré : {logo.size[0]}×{logo.size[1]} px")

    if args.mark_source:
        mark_src = Image.open(args.mark_source).convert("RGBA")
        mark = trim_and_pad(remove_outer_white(mark_src))
        # Détourage circulaire du médaillon
        side = mark.width
        mask = Image.new("L", (side * 4, side * 4), 0)
        ImageDraw.Draw(mask).ellipse((0, 0, side * 4 - 1, side * 4 - 1), fill=255)
        mark.putalpha(
            Image.composite(mark.getchannel("A"), Image.new("L", (side, side), 0),
                            mask.resize((side, side), Image.LANCZOS))
        )
    else:
        mark = make_mark(logo, args.mark_ratio)
    build_web(logo, mark)
    build_app(logo, mark)
    print("\nTerminé.")


if __name__ == "__main__":
    main()
