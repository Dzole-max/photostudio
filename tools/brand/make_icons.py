"""Renders the Memoria app mark into the PNGs used for launcher icons and the
splash screen. Same geometry as AppMarkPainter in lib/design/components/illustrations.dart:
two rounded pages leaning together like an open book seen from above, with a
thin gap as the spine.

Usage: python tools/brand/make_icons.py   (requires Pillow)
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[2] / "apps" / "mobile" / "assets" / "brand"
INK = (31, 27, 23, 255)
PAPER = (247, 243, 236, 255)
CLAY = (176, 78, 43, 255)
SS = 4  # supersampling factor for smooth edges


def mark(size: int, color, background=None, scale: float = 1.0) -> Image.Image:
    big = size * SS
    img = Image.new("RGBA", (big, big), background or (0, 0, 0, 0))
    s = big * scale
    page_w, page_h = s * 0.36, s * 0.64
    gap = s * 0.045
    radius = s * 0.07
    cx, cy = big / 2, big / 2
    for side in (-1, 1):
        layer = Image.new("RGBA", (big, big), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        # Page drawn upright with its spine-top corner at the pivot; the
        # bottoms swing outwards so the pages lean together at the spine.
        pivot = (cx + side * gap / 2, cy - page_h / 2)
        left = pivot[0] - page_w if side < 0 else pivot[0]
        d.rounded_rectangle(
            [left, pivot[1], left + page_w, pivot[1] + page_h], radius=radius, fill=color
        )
        layer = layer.rotate(math.degrees(side * 0.08), center=pivot, resample=Image.BICUBIC)
        img.alpha_composite(layer)
    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    # App icon: Paper mark on Clay.
    mark(1024, PAPER, CLAY, 0.78).save(OUT / "app_icon.png")
    # Adaptive icon foreground (Android keeps the inner 66% safe).
    mark(1024, PAPER, None, 0.52).save(OUT / "app_icon_foreground.png")
    # Splash: Ink mark on transparent (background is Paper in config).
    mark(768, INK, None, 0.5).save(OUT / "splash_mark.png")
    mark(768, PAPER, None, 0.5).save(OUT / "splash_mark_dark.png")
    print("icons written to", OUT)


if __name__ == "__main__":
    main()
