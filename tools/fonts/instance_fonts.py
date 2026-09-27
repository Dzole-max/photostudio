"""Downloads the Google Fonts variable files and cuts the static weights that
the app and the render service bundle. Static instances render identically in
Flutter and Skia, which keeps print and preview in parity.

Usage: python tools/fonts/instance_fonts.py   (requires: pip install fonttools)
Output: apps/mobile/assets/fonts/*.ttf (the render service copies them at build time)
"""

import shutil
import tempfile
import urllib.request
from pathlib import Path

from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "apps" / "mobile" / "assets" / "fonts"
BASE = "https://raw.githubusercontent.com/google/fonts/main/ofl"

# (source path in google/fonts, output name, weights, extra axis pins)
JOBS = [
    ("inter/Inter%5Bopsz,wght%5D.ttf", "Inter", [400, 500, 600], {"opsz": 14}),
    ("cormorantgaramond/CormorantGaramond%5Bwght%5D.ttf", "CormorantGaramond", [400, 500, 600, 700], {}),
    ("cormorantgaramond/CormorantGaramond-Italic%5Bwght%5D.ttf", "CormorantGaramond-Italic", [500], {}),
    ("lora/Lora%5Bwght%5D.ttf", "Lora", [400, 600], {}),
    ("lora/Lora-Italic%5Bwght%5D.ttf", "Lora-Italic", [400], {}),
    ("manrope/Manrope%5Bwght%5D.ttf", "Manrope", [400, 600, 700], {}),
    ("nunito/Nunito%5Bwght%5D.ttf", "Nunito", [400, 700, 800], {}),
    # App interface (not printed): wordmark/headlines and UI text.
    ("unbounded/Unbounded%5Bwght%5D.ttf", "Unbounded", [600], {}),
    ("onest/Onest%5Bwght%5D.ttf", "Onest", [400, 500, 600, 700], {}),
]
STATIC = [("greatvibes/GreatVibes-Regular.ttf", "GreatVibes-400.ttf")]
WEIGHT_NAMES = {400: "Regular", 500: "Medium", 600: "SemiBold", 700: "Bold", 800: "ExtraBold"}
FAMILY_NAMES = {
    "Inter": "Inter",
    "CormorantGaramond": "Cormorant Garamond",
    "Lora": "Lora",
    "Manrope": "Manrope",
    "Nunito": "Nunito",
    "Unbounded": "Unbounded",
    "Onest": "Onest",
}
SAMPLE = "Александар & Елена · Охрид ЃѓЌќЉљЊњЏџЅѕЈј"


def fetch(path: str, dest: Path) -> None:
    with urllib.request.urlopen(f"{BASE}/{path}") as r, open(dest, "wb") as f:
        shutil.copyfileobj(r, f)


def set_names(font: TTFont, file_family: str, weight: int, italic: bool) -> None:
    """Gives each static instance its own names; shared PostScript names make
    some font managers treat different weights as one font."""
    family = FAMILY_NAMES[file_family]
    style = WEIGHT_NAMES[weight] + (" Italic" if italic else "")
    if style == "Regular Italic":
        style = "Italic"
    ps = f"{family.replace(' ', '')}-{style.replace(' ', '')}"
    name = font["name"]
    for rec in list(name.names):
        if rec.nameID in (1, 2, 3, 4, 6, 16, 17, 25) or rec.nameID >= 256:
            name.removeNames(nameID=rec.nameID)
    legacy_family = family if style in ("Regular", "Italic", "Bold", "Bold Italic") else f"{family} {WEIGHT_NAMES[weight]}"
    legacy_style = "Italic" if italic else "Regular"
    if style in ("Bold", "Bold Italic"):
        legacy_style = style
    name.setName(legacy_family, 1, 3, 1, 0x409)
    name.setName(legacy_style, 2, 3, 1, 0x409)
    name.setName(f"{ps};memoria", 3, 3, 1, 0x409)
    name.setName(f"{family} {style}", 4, 3, 1, 0x409)
    name.setName(ps, 6, 3, 1, 0x409)
    name.setName(family, 16, 3, 1, 0x409)
    name.setName(style, 17, 3, 1, 0x409)
    for tag in ("STAT", "fvar", "avar", "HVAR", "MVAR"):
        if tag in font:
            del font[tag]


def main() -> None:
    import sys

    only = set(sys.argv[1:])  # e.g. `Unbounded Onest` to add fonts without refetching all
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        tmpdir = Path(tmp)
        for src, name, weights, pins in JOBS:
            if only and name not in only:
                continue
            local = tmpdir / f"{name}.var.ttf"
            fetch(src, local)
            for w in weights:
                inst = instantiateVariableFont(
                    TTFont(local), {"wght": w, **pins}, updateFontNames=False
                )
                set_names(inst, name.split("-")[0], w, name.endswith("Italic"))
                inst.save(OUT / f"{name}-{w}.ttf")
        if not only:
            for src, out_name in STATIC:
                fetch(src, OUT / out_name)
            fetch("inter/OFL.txt", OUT / "OFL.txt")

    failed = False
    for font in sorted(OUT.glob("*.ttf")):
        cmap = TTFont(font).getBestCmap()
        missing = [c for c in SAMPLE if c != " " and ord(c) not in cmap]
        print(f"{font.name}: {'missing ' + ''.join(missing) if missing else 'ok'}")
        failed |= bool(missing)
    if failed:
        raise SystemExit("some fonts lack Cyrillic; substitute them and log it in docs/DECISIONS.md")


if __name__ == "__main__":
    main()
