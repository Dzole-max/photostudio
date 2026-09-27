# Brand — "The quiet bookbinder"

A small premium bindery: paper, ink, linen, a touch of gold. Photos are the colour;
the interface is neutral and warm. Warm, crafted, calm, quietly confident — never loud,
never childish by default.

Code: `apps/mobile/lib/design/` (`MemoriaColors` ThemeExtension, `buildMemoriaTheme`,
type scale, spacing/radii/shadows/motion tokens, components, illustrations).

## Voice

- Short, human sentences. "Your book is ready to hold." — not "Album generation complete!"
- Celebrate the memory, not the tech. "We arranged your photos." Never "our AI algorithm".
- Honest about print: "This photo may print soft at full page."
- No exclamation marks, except celebration moments (order placed).
- Printed gold is an ink colour (`#B8955A`): always say "gold tone", never "foil".
- No emoji anywhere in the UI; status is shown with icons.

## Colour (app UI)

| Token | Light | Dark | Use |
|---|---|---|---|
| background | `#F7F3EC` Paper | `#15130F` | app background |
| surface | `#EDE6DA` Linen | `#221F1A` | cards, sheets, inputs |
| surfaceRaised | `#FFFFFF` | `#2C2822` | page thumbnails, dialogs |
| textPrimary | `#1F1B17` Ink | `#F2ECE2` | headlines, body |
| textSecondary | `#6B635A` Stone | `#A89E91` | captions, hints |
| primary | `#B04E2B` Clay | `#E0845F` | the one main action per screen |
| onPrimary | `#FFFFFF` | `#15130F` | text on Clay |
| secondary | `#5E7160` Sage | `#9BB09C` | success, print-ready |
| accent | `#8C6A2E` Gold tone | `#D4B06A` | premium labels, wedding accents |
| info | `#2E3A52` Dusk | `#9FB2D6` | links, selection |
| warning | `#C98A1B` Amber | `#E3A63A` | warning icons only, never text |
| error | `#A3322A` Brick | `#E57368` | errors, destructive |
| divider | `#DDD4C6` | `#3A352D` | 1 px lines |

Clay is the only loud colour: one primary action per screen.

## Type

| Role | Font | Sizes / weights |
|---|---|---|
| UI | Inter | 12/14/16/20 sp · 400/500/600 |
| UI display | Cormorant Garamond | 28/34/44 sp · 500/600 |
| Book body | Lora | captions, chapter text |
| Book display | Cormorant Garamond | covers, chapter openers |
| Book script | Great Vibes | wedding names / monograms only |
| Book sans | Manrope | travel/minimal, dates, map labels, page numbers |
| Book playful | Nunito | baby, birthday, illustrated edition |

All fonts are bundled static instances (SIL OFL 1.1) in `apps/mobile/assets/fonts/`, cut
from the Google Fonts variable files by `tools/fonts/instance_fonts.py`. A test
(`test/domain/font_coverage_test.dart`) fails if any font cannot draw Latin or Macedonian
Cyrillic. Manrope has no prime marks (′ ″), so coordinates are always written in decimal
degrees (`6.1659° S, 39.2026° E`).

## Shape, spacing, motion

- Spacing: 4, 8, 12, 16, 24, 32, 48, 64.
- Radius: 8 inputs/chips · 14 cards · 24 sheets · 999 pills · 2 paper corners.
- Shadows: Ink at 6–10 % opacity, blur 16–24, y 4–8. No hard Material elevation.
- Motion: 300–400 ms `easeOutCubic`; page turns physical with a slight curl; reduce-motion
  swaps curls for cross-fades.
- Icons: rounded outline set. Haptics: light impact on page turn and on reorder drop.
- Tap targets ≥ 48 × 48 dp.

## Mark

Two rounded pages leaning together like an open book seen from above, with a thin gap as the
spine. Single colour: Ink on Paper, Paper on Clay for the app icon. Source of truth:
`AppMarkPainter` (Flutter) and `tools/brand/make_icons.py` (PNG export for launcher icons
and splash). Regenerate with `make icons`.
