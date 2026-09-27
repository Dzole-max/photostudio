# Brand — Memoria

A polished streaming-app feel in dark blue and blue (never black): a light "Sky" interface by
default, a dark "Ocean" one with system dark mode or by choice. Photos and printed books are
the colour; the interface frames them like prints on a light table. Printed book themes are
separate and unchanged (books are printed on paper).

Code: `apps/mobile/lib/design/` (`MemoriaColors` ThemeExtension, `OccasionTone`,
`buildMemoriaTheme`, type scale, spacing/radii/shadows/motion tokens, components).
Screens: `docs/screens/`.

## Voice

- Short, human sentences. "Your book is ready to hold." — not "Album generation complete!"
- Celebrate the memory, not the tech. "We arranged your photos." Never "our AI algorithm".
- Honest about print: "This photo may print soft at full page."
- No exclamation marks, except celebration moments (order placed).
- Printed gold is an ink colour (`#B8955A`): always say "gold tone", never "foil".
- No emoji anywhere in the UI; status is shown with icons.

## Colour (app UI)

| Token | Sky (default) | Ocean |
|---|---|---|
| background | #EEF4FC | #0B2350 |
| surface | #FFFFFF | #123067 |
| surfaceTint (empty states, selected rows) | #DCE8FA | #1A3F80 |
| border (1 px) | #D6E2F5 | #274886 (active #6CB8FF) |
| hero gradient | #1E4FA8 → #0D2B5E | #1B4A9A → #10306B |
| textPrimary / body / muted | #0B2350 / #3D5580 / #51698F | #F4F7FC / #C3D3EE / #A9BEE3 |
| text on the hero | #F4F7FC / #C9D8F2 | same |
| primary (text on it) | #1E5BD8 (white) | #6CB8FF (#0B2350) |
| primary on the hero (text on it) | #6CB8FF (#06101F) | same |
| success · warning · error | #137A5E · #8A6500 · #C23A3A | #7FE0C4 · #F2D27A · #FF8A8A |

Status is always icon + text. Occasion tiles (icon background / icon), Sky · Ocean:
Wedding #EFE6FF/#7A4FC9 · #2A2140/#D9B8FF; Travel #E1F0FF/#1E5BD8 · #10304A/#7CC4FF;
Baby #FFF4D6/#8A6500 · #2E2A1A/#F2D27A; Birthday #FFE6EC/#C23A5C · #3A1D24/#FF9DB0;
Year #DFF7EF/#137A5E · #12312B/#7FE0C4; Family #E6EAFF/#3E4FC0 · #1E2440/#A9B8FF.

## Type

- **Unbounded 600**: the wordmark "memoria." (dot in primary) and large headlines only,
  28–32 sp, letter-spacing −2 %.
- **Onest 400/500/600/700**: all other UI text, 11–18 sp (dialog titles 20).
- Both are bundled static instances with Latin + Cyrillic (`tools/fonts/instance_fonts.py`).
- Cormorant Garamond, Lora, Manrope, Nunito, Inter and Great Vibes are printed-book fonts
  only; they appear in the app only where a book or cover is shown.

## Shape, spacing, motion

- Spacing: 4, 8, 12, 16, 24, 32, 48, 64.
- Radius: cards and tiles 20 · hero 28 · sheets 28 · inputs 14 · pills = height / 2.
  Primary buttons 52–56 high; icon buttons 44 × 44, round.
- Shadows: soft and blue-tinted, #0B2350 at 8–14 %, blur 24–40. No hard elevation.
- Motion: sections fade in and rise 12 px, 60 ms apart, 350 ms `easeOutCubic`; occasion
  tiles press to 0.96 with a light haptic and grow into their screen (container transform);
  hero covers float ±4 px over 6 s and lean ±6° with scroll; rails snap, centred card 1.0 vs
  0.94. Reduce motion: cross-fades only.
- Icons: rounded outline. No emoji. Tap targets ≥ 44 dp (48 where space allows).
- Navigation: a floating pill, 68 high, 16 from the edges, white at 96 % (Ocean #123067 at
  94 %): Home, Books, Orders, Settings.

## Mark

Two rounded pages leaning together like an open book seen from above, with a thin gap as the
spine. Single colour: Ink on Paper, Paper on Clay for the app icon. Source of truth:
`AppMarkPainter` (Flutter) and `tools/brand/make_icons.py` (PNG export for launcher icons
and splash). Regenerate with `make icons`.
