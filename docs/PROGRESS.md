# Progress

## Phase 0 — Foundation ✅

Works:
- Monorepo layout, Makefile, `.env.example` files, `.gitignore`, CI (Flutter job).
- Flutter 3.47.5 / Dart 3.13 app `apps/mobile`, bundle id `com.memoria.app`, Android
  `dev`/`prod` flavors (minSdk 26), iOS 15.5, permissions, privacy manifest.
- Design system (`lib/design/`): colour tokens as `ThemeExtension<MemoriaColors>` + M3
  `ColorScheme`, type scale, spacing/radii/shadows/motion, buttons, cards, chips, pills,
  sheets, progress, empty and error states, vector illustrations, app mark.
- Light and dark themes, runtime theme switch.
- 18 bundled static fonts (Latin + Cyrillic verified by test).
- Launcher icons and native splash generated from the vector mark.
- ARB localisation in EN/DE/ES/FR/IT/MK, runtime language switch without restart.
- go_router with onboarding redirect and a 3-tab shell (Home, Orders, Settings).
- Drift database (albums, photo analysis cache, geocode cache, orders).
- Riverpod (code-gen), settings persisted in shared_preferences.
- Service registry with fakes: analytics (PostHog/no-op), crash reporting (Sentry/no-op),
  photo permission, auth (fake), user data export/deletion.
- Onboarding: hero loop, "We arrange. You decide.", privacy + captions toggle, language,
  photo permission (limited access and denied handled).
- Settings: language, appearance, page-turn sound, captions toggle, account, export and
  delete data, about/licences (Natural Earth + OFL).

Tests: onboarding in all 6 languages, full onboarding walk-through, theme switching,
font Cyrillic coverage, screen goldens (EN, MK, light, dark). `flutter analyze` clean.

Not verified on this machine: device builds (no Android SDK or Xcode installed here);
CI covers analyze and tests.

## Phase 1 — Core album ✅ (verified on the Android emulator)

Import (gallery and sample sets), on-device analysis and curation with review sheet,
occasion detection, story interview, designing, editor (pages, photos, theme, cover,
format panels, crop, text), print check, 3D/flat/table preview.

## Owner brief — editions and wow moments

- 1 Edition picker ✅ — Classic Album (Most loved, opening book), Living Memories (3 drifting
  photos), Cartoon & Comic (before/after wipe); Editions button in the editor.
- 2 Cover Studio ✅ — 4 variants on 3D mockups, illustrated cover painted on device (fake
  CoverArtProvider), editable words, accent follows the chosen cover. Tests: `cover_studio_test`.
- 3 Home bookshelf ✅ — "Your books" + avatar button, 3D shelf (Book3D with spine, page block,
  material texture), ±6° scroll parallax, tap opens the cover into the preview, two printable
  sample books generated on first launch, create button + occasion chips + sample starts.
- 4 Living Memories ✅ — live on-device preview; MP4 encoded on device (verified on the
  emulator: 26.5 s, 720×1280 H.264 + AAC, plays in the app, saved to the gallery); 9:16 and
  1:1; three bundled CC0 tracks; share sheet; watermark; "Also print this as a book".
  Tests: `trailer_test`, `edition_routing_test`. iOS encoder written, not built here (no Xcode).
  HD encode on the render service: Phase 2.
- 5 Cartoon & Comic ✅ — five styles with live previews, character sheet with shared palette,
  whole book or cover + one page per chapter, consent, comic panels with lettered speech bubbles;
  generates a full illustrated album in fake mode (verified on the emulator: 37 photos redrawn,
  new book opens in the preview). Tests: `illustrated_edition_test`, comic goldens.
- 6 Wow moments ✅ — reveal after designing (verified on the emulator), 3D material picker with
  live linen/leather/matte/gloss and surcharges (verified), Enhance for print with before/after
  slider, handwritten dedication as vector ink (verified), series spines. Tests: `wow_moments_test`.
- 7 Onboarding and permissions ✅ — editions as animated tiles on screen 2 (verified on the
  emulator), limited access keeps "Select more photos", denied access makes "Try a sample book"
  the main action (widget test). All new strings are in EN/DE/ES/FR/IT/MK.

### Acceptance status

- Fresh install → onboarding → sample Zanzibar → Edition picker → Cover Studio (4 variants) →
  reveal → editor → 3D preview: every step checked on the emulator (in two runs: the emulator
  closed partway through the fresh-install run, after onboarding screen 3).
- Real-photo flow: import from the gallery works on device; it goes through the same screens.
- Living Memories makes a playable MP4 in fake mode (26.5 s, 720×1280, H.264 + AAC, saved to the gallery).
- Cartoon & Comic makes a full illustrated album in fake mode (37 photos redrawn on the emulator).
- `flutter analyze` clean; 133 tests pass. New tests cover cover-variant generation
  (`cover_studio_test`), edition routing (`edition_routing_test`), the trailer, the illustrated
  edition, the wow moments and the denied-permission onboarding.
- Only placeholder left: checkout (Phase 2).

### Not verified here
- iOS video encoder (AVAssetWriter in `AppDelegate.swift`): written, not built (no Xcode on this machine).
- HD encode without watermark: needs the render service (Phase 2).


## App redesign — Sky / Ocean ✅ (2026-09-28)

- New tokens, fonts (Unbounded + Onest), components and theme; Sky default, Ocean with system
  dark mode or Settings → Appearance (System / Sky / Ocean).
- Home rebuilt: wordmark header with Search and Profile, dark-blue hero with fanned covers and
  the explainer, 3 × 2 occasion grid, "Three ways to keep it" rail, "Your books" shelf with a
  dashed empty state, floating pill navigation (Home, Books, Orders, Settings). The sample
  cards, the open-book illustration and the old copy are gone.
- Occasion screen per tile (container transform from the tile, "How it goes", fixed action that
  starts the flow with the occasion pre-selected). Explainer, Books tab, Example books (Settings
  and onboarding). Onboarding restyled on the dark-blue hero.
- Verified on the emulator: Home in Sky and Ocean, tile → Occasion transition, Settings, Books,
  the four explainer scenes. Screens in `docs/screens/` (device captures `*_device.png`,
  rendered captures from the golden tests).
- `flutter analyze` clean; 141 tests pass (new goldens: Home Sky/Ocean, Occasion screen).
