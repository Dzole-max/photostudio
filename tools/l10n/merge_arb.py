"""Merge a batch of translated strings into the app's ARB files.

Usage: python tools/l10n/merge_arb.py batch.json

batch.json maps each key to its translations and optional ARB metadata:

    {
      "photosSelected": {
        "en": "{count, plural, one{1 photo} other{{count} photos}}",
        "de": "...", "es": "...", "fr": "...", "it": "...", "mk": "...",
        "@": {"description": "Counter pill", "placeholders": {"count": {"type": "int"}}}
      }
    }

Every locale must be present for every key; existing keys are overwritten.
"""

import json
import sys
from pathlib import Path

LOCALES = ["en", "de", "es", "fr", "it", "mk"]
ARB_DIR = Path(__file__).resolve().parents[2] / "apps" / "mobile" / "lib" / "l10n"


def load(locale: str) -> dict:
    path = ARB_DIR / f"app_{locale}.arb"
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    return {"@@locale": locale}


def main() -> None:
    batch = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    arbs = {loc: load(loc) for loc in LOCALES}
    for key, entry in batch.items():
        missing = [loc for loc in LOCALES if loc not in entry]
        if missing:
            raise SystemExit(f"{key}: missing {missing}")
        for loc in LOCALES:
            arbs[loc][key] = entry[loc]
        if "@" in entry:
            arbs["en"][f"@{key}"] = entry["@"]
    ARB_DIR.mkdir(parents=True, exist_ok=True)
    for loc, data in arbs.items():
        path = ARB_DIR / f"app_{loc}.arb"
        path.write_text(
            json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
    print(f"merged {len(batch)} keys into {len(LOCALES)} ARB files")


if __name__ == "__main__":
    main()
