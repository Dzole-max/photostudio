# Decisions

One line each: decision — reason.

## Phase 0

- Monorepo root is the workspace folder (`photostudio/`) rather than a nested `memoria/` folder — the brand name will change; a neutral root avoids a rename.
- Fonts are static instances cut from the Google Fonts variable files with fonttools (`tools/fonts/instance_fonts.py`) — Flutter and Skia resolve static weights identically; variable-axis handling differs between engines and would break print/preview parity.
- Font weights bundled: Inter 400/500/600, Cormorant Garamond 400/500/600/700 + Italic 500, Lora 400/600 + Italic 400, Manrope 400/600/700, Nunito 400/700/800, Great Vibes 400 — covers every weight named in the spec; all pass the Cyrillic cmap check, so no substitutions were needed.
- Cover slots are a typed `CoverSlots` object instead of `Map<String, dynamic>` — the spec forbids `dynamic` in domain code; every slot in section 5.2 is a named nullable field.
- The layout engine resolves covers and map pages into primitive elements (frames, text blocks, vector ornaments with mm paths) — both renderers then only draw primitives, which makes Flutter/Skia parity mechanical instead of duplicating template logic.
- Colours in the document are `#RRGGBB` strings plus a separate `opacity` — readable in fixtures, identical parsing in Dart and TS.
- Inner page index 0 is a recto (right-hand) page; even index = right page, odd = left page — matches a real book where the first inner page faces the endpaper; gutter is the left edge of right pages.
- pHash is stored as a 16-character hex string — JSON numbers cannot carry 64-bit integers safely in JavaScript.
- Album JSON timestamps are ISO-8601 UTC strings — portable across Dart, TS and Postgres jsonb.
- Material Symbols Rounded weight 300 is approximated with Flutter's built-in `Icons.*_rounded` / `*_outlined` set — bundling the Material Symbols variable font adds ~10 MB and a third-party package; swap later if the look needs it.
- iOS minimum is 15.5, not 15.0 — Google ML Kit pods require 15.5.
- UI imports `package:material_ui/material_ui.dart` instead of `package:flutter/material.dart` — Material was decoupled from the Flutter SDK and go_router 18 builds on `material_ui`; mixing both gives two separate `Theme` trees.
- `sqlite3_flutter_libs` removed — it is an empty end-of-life shim since sqlite3 3.x ships SQLite through build hooks.
- sentry_flutter 9.x instead of 8.x — resolves cleanly and is the maintained line.
- iOS flavors use entrypoints (`-t lib/main_dev.dart`) instead of Xcode schemes; Android uses `dev`/`prod` productFlavors — schemes can only be created reliably in Xcode, entrypoints give the same result without it.
- Golden tests use a comparator with 1.5 % pixel tolerance — goldens are recorded on Windows and checked on Linux CI, where text anti-aliasing differs slightly.
- Riverpod's automatic provider retry is disabled in tests — pending retry timers would fail widget tests; production keeps the default.
- Native language names ("Deutsch", "Македонски") are data in `AppLanguage`, not ARB strings — they are intentionally identical in every locale.
- Coordinates are always printed in decimal degrees — Manrope has no prime (′ ″) glyphs.

## Editions, Cover Studio, bookshelf (owner brief, sections 1–3)

- Android `dev`/`prod` productFlavors dropped with the regenerated `android/` project; flavors are entrypoints only (`-t lib/main_dev.dart`), like iOS. `flutter run -d emulator-5554` runs `main.dart` (dev, fakes).
- `FEATURE_LIVING_MEMORIES` and `FEATURE_ILLUSTRATED` default to on in the dev flavor and off in prod unless set by `--dart-define`.
- Lint `use_null_aware_elements` disabled — its automatic fix rewrote `if (x case final v?) v.id: v` map entries into invalid code.
- The edition is stored on the album (`flags.edition`); the album is always generated, whichever edition was picked.
- Cover Studio makes 4 variants: photo, monogram (travel: passport-stamp roundel), map (only when photos are geotagged), illustrated. The illustrated cover is painted from a different hero than the photo cover (weddings: the best two-face portrait) so the two never look alike.
- Generated artwork (illustrations, enhanced photos) is a `PhotoRef` with `artwork: true`, id `<source>~<style>`, stored as a JPEG under app documents with the `file:` prefix. Artwork never counts as a book photo in chapters or "unused".
- The chosen cover's accent overrides the tinted theme accent (`LayoutInput.accentOverride`); the wedding monogram accent is the gold tone `#B8955A`.
- Destination icon pack: 20 single-stroke vector icons in a 0–100 box, picked by keyword from place names and photo labels; SVG paths gained the `A` (arc) command in Dart and the spec.
- Sample books ("Wedding in Ohrid", "Trip to Zanzibar") are built once on first launch through the real pipeline (analysis, captions, cover, layout) and saved as normal albums with `flags.sample`; they are printable and cannot be deleted by long-press. Deleted-by-reset samples are not recreated (flag `sampleBooksMade`).
- The shelf's drawn spine is thicker than the real one (min 16 px) so it reads at phone size; the real spine panel is stretched to fit.
- Living Memories is rendered on device: the trailer painter draws each frame from pre-rendered page images (same `BookPagePainter` as the book) so the live preview and the encoded video match; frames are encoded to H.264 + AAC MP4 by a platform channel (`memoria/video`: Android MediaCodec/MediaMuxer, iOS AVAssetWriter + AVAssetExportSession). No FFmpeg in the app.
- Free export is 720p (720×1280 or 720×720), 24 fps, with a small brand watermark. The HD, unwatermarked encode (FFmpeg on the render service, same timeline) comes with the render service in Phase 2.
- Trailer: cover close-up 2.5 s → opening 1.6 s → up to 7 spreads × 1.6 s → up to 3 heroes × 2.3 s → closing 2 s → end card 2.2 s (≈ 20–30 s for a normal book).
- The fake MotionProvider brings heroes to life with a two-layer parallax around the face/focus crop; a real provider may return a motion clip (`HeroMotion.clipPath`), which the renderer will prefer once one exists.
- Music: three original tracks synthesised by `tools/music/make_music.py` (CC0, see `assets/music/LICENSE.md`) — no third-party audio to license. 16-bit mono WAV in the bundle (~1.9 MB each); the encoder trims, fades and converts to AAC.
- Trailer photos are decoded directly (`decodePhoto`), not through the on-screen `BookImageStore`: its LRU eviction and shared pending loads made waiting on it unreliable while the editor was open underneath.
- The editor saves on dispose only if a debounced save is still pending, using the album recorded via `listenSelf` — Riverpod 3 forbids reading `state` in `onDispose`.
- The Cartoon & Comic Edition is a new album (own id, `flags.edition = illustrated`, `flags.illustrationStyle`), built from the original: redrawn photos replace the originals on the chosen pages and the cover. Redrawn photos are ordinary book photos in the new album (`artwork: false`, `sourceId` = original) so re-layout and "unused photos" keep working; originals stay only where a page that was not redrawn still shows them.
- Comic templates: `comic_splash`, `comic_2_panels`, `comic_3_panels`, plus `comic_4_panels` (2×2) so four-photo pages are not cut down. Pages with more than four photos keep their four most-peopled photos. Panels have 0.9 mm ink borders and 4 mm gutters inside the safe area; the page caption is lettered into a speech bubble (Nunito 800, 10–16 pt fitted, ≤ 5 lines) in the corner away from the faces, with a short tail toward the nearest face. Special pages (title, chapter openers, maps) are unchanged.
- Character sheet (fake mode): head-and-shoulders crops of up to three main people (largest faces in the book) give a shared palette; every page is drawn with that palette merged with the photo's own colours, so people keep their colours while skies and seas keep theirs. A real provider receives the sheet as its reference images.
- Hybrid scope: the cover plus, per chapter, the page with the most people.
- Consent is required before redrawing (checkbox); the style list never names a studio ("3D animated look").
- Artwork is generated at 2400 px on the long side (≥ 200 dpi on every format), three photos at a time in isolates; on the emulator a 37-photo book takes about two minutes.
- Reveal: a 2.4 s route (`/album/:id/reveal`, no page transition) between "Designing your book…" and the chosen edition; tap anywhere skips; light haptic when the book lands, medium when it opens; gold-tone light band for weddings, white otherwise; reduced motion shows the open book for 0.7 s.
- Material picker: Linen, Leather-look, Matte, Gloss on a slowly turning `Book3D` (drag to turn) in the Format panel; each option shows its surcharge from the catalog; linen and leather-look are hardcover-only, and changing to a size that can't take the chosen finish falls back to matte.
- "Enhance for print" appears on low-resolution issues in the print check (not on photos already enhanced); the enhanced photo replaces the original everywhere (`replacePhoto`) and is a normal book photo linked by `sourceId`. The before/after compares a 2.2× zoom of the centre, where the difference shows.
- Handwritten dedication: finger strokes are stored as vector path ornaments (quadratic smoothing through midpoints, 0.35 mm jitter filter) tagged `params.dedication = 1` on the first page, in fountain-pen blue-black (#1E2A44, 1.1 pt). It is kept (rescaled) through re-layout and format changes.
- Series spines: `Album.series` + `Album.seriesVolume`. Every book in a series gets the same book-cloth spine colour (stable hash of the series name over six colours), the series name at the head, the title in the middle and the volume number at the foot; spines under 6 mm carry the colour only (no text), as with regular spines. Volumes are numbered in the order books join the series.
- Re-layout now keeps album flags (edition, sample, video, illustration style), the series and the dedication; before this, a format change reset them.
- Onboarding screen 2 shows the three editions as looping tiles made from the bundled Zanzibar sample photos (no photo permission is needed yet); the Living Memories and Cartoon tiles reuse the Edition picker's previews.
- Photo access denied (onboarding or import): "Try a sample book" is the main action and opens the Zanzibar sample flow; "Open settings" is secondary. Limited access (Android 14+ "selected photos", iOS limited library) keeps the "Select more photos" action, which calls the system picker through photo_manager.
- Known limit: re-laying out a Cartoon & Comic album (format change, shuffle) rebuilds pages with the regular templates, so comic panels become regular layouts with the redrawn photos. Comic re-layout is left for later.

## App redesign — Sky / Ocean (owner brief, 2026-09-28)

- The app interface moved from the warm "paper" theme to Sky (light, default) and Ocean (dark). `MemoriaColors` kept its field names so every screen picked up the new palette; new tokens were added (surfaceTint, border, hero gradient, on-dark text, primaryOnDark, navBar). Printed book themes are untouched.
- Fonts: Unbounded 600 (wordmark, 28–32 sp headlines) and Onest 400–700 (all other UI) are bundled as static instances with Cyrillic, made by `tools/fonts/instance_fonts.py Unbounded Onest`. Cormorant Garamond left the app UI; it stays a book font (and is used where a cover is depicted).
- Appearance setting: System (default, so Sky in light mode and Ocean in dark mode) / Sky / Ocean. The enum values stay `system/light/dark` to keep stored preferences valid; only the labels changed.
- Home order: header (wordmark, Search, Profile) → hero card (three fanned covers, "Stories worth holding.", Create a book, See how it works) → "What is it about?" 3 × 2 occasion grid → "Three ways to keep it" rail → "Your books" shelf. Search filters the user's books by title; Profile opens Settings.
- Occasion tiles: Wedding, Travel, Baby, Birthday, Year, Family (`BookKind`). "Year" maps to the domain's whole-year occasion (`Occasion.family`) and "Family" to the open occasion (`Occasion.other`), so no domain or print-spec change was needed.
- Container transform is a `Hero` with a custom flight: the tile's white card morphs into the occasion header gradient (radius 20 → bottom corners 32) while the rest of the screen cross-fades (`CustomTransitionPage`, 420 ms). Reduced motion turns the Hero off.
- The hero shows the user's three latest books; with fewer, designed demo covers fill in (gold-tone monogram, summer sea, "Your story").
- "See how it works" is a 20-second, four-scene explainer (story-style progress, tap to skip) drawn in the app from bundled sample photos, so it needs no video file.
- Example books are no longer made on first launch or shown on the shelf; they are built on demand (`exampleBookProvider`) from onboarding ("See an example book") and Settings → Example books. Books with the example ids are filtered from Home and Books.
- A fourth tab, Books, lists all the user's books (grid of 3D covers). `AlbumStatus` gained `delivered` for the "Delivered" chip.
- Tab screens use a large Unbounded title (`TabHeader`) and leave room for the floating navigation; a status-bar scrim keeps scrolled content from running under the clock.
- 33 strings no longer used by any screen were removed from all six ARB files.
