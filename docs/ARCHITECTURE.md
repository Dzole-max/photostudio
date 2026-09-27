# Memoria — Architecture

Memoria turns phone photos into a print-ready photo book. The printed album is the
product; everything else (video, illustration, guest uploads, gift links) is a flagged stub.

## Repository layout

```
apps/mobile/            Flutter app (iOS, Android, Galaxy Store)
services/render/        Node 22 + TypeScript render/print service (fastify, @napi-rs/canvas, pdf-lib, sharp, zod)
supabase/migrations/    Postgres schema + RLS + storage buckets
supabase/functions/     Deno edge functions (AI proxy, geo, print quote/order, webhooks, data delete)
packages/layout_spec/   Shared contract: album.schema.json, fixtures, catalog, book_strings i18n, geo data
docs/                   PROGRESS, DECISIONS, ARCHITECTURE, PRINT_SPEC, BRAND, STORES, RENAME
.github/workflows/      CI
```

## The album document is the contract

`packages/layout_spec/album.schema.json` (schemaVersion 1) describes one album: pages,
frames (mm rects relative to trim, normalised crops), text blocks, ornaments (vector
primitives), cover design, chapters, photo refs. Both renderers consume only this JSON:

- Flutter paints it on screen (editor, preview, goldens) with `BookPagePainter`.
- The render service paints it with Skia (`@napi-rs/canvas`) at 300 dpi for print.

Shared behaviour that must match pixel-for-pixel is written twice from one spec and
tested against the same fixtures: greedy word wrap, crop math, ornament drawing,
equirectangular map projection, preflight rules. Fixtures live in
`packages/layout_spec/fixtures/` and are consumed by Dart tests and Node tests.

## Mobile app layers (`apps/mobile/lib/`)

```
app_config.dart        brand name, bundle ids, flavor, env (single rename point)
main_dev.dart / main_prod.dart / app.dart
design/                tokens (MemoriaColors ThemeExtension), typography, spacing, components
l10n/                  ARB files (en template, de, es, fr, it, mk) -> flutter gen-l10n
router/                go_router routes + shell with 3-tab bottom bar
data/                  drift database, repositories, service fakes + real adapters
domain/                pure Dart, no Flutter imports:
  model/               freezed entities (Album, Page, PhotoFrame, TextBlock, ...)
  curation/            pHash, sharpness, exposure, burst grouping, scoring, exclusion
  occasion/            rule-based occasion detection
  layout/              templates (12-col grid, mm), smart crop, greedy scored layout engine
  preflight/           pure check functions + fixes
  pricing/             price formula over catalogue data
  theme/               book themes, ThemeTinter (accent hue rotation)
  geo/                 projection + route building for map pages
  text/                greedy word wrap over a measure function
features/              one folder per screen: onboarding, home, import, create, editor,
                       preview, check, checkout, orders, settings, bonus
```

State: Riverpod (code-gen providers). Navigation: go_router. Persistence: Drift (albums as
JSON documents + photo analysis cache + geocode cache), shared_preferences for settings.

Heavy work (hashing, sharpness, layout of 400 photos) runs in isolates via `Isolate.run`
or a small worker pool (cores − 1). The UI thread only receives progress events.

## Services behind interfaces (fakes first)

Every external dependency is an abstract Dart class with a Fake and a real adapter,
selected in `data/services/service_locator.dart` from `AppConfig`:

| Interface          | Fake                                    | Real                          |
|--------------------|-----------------------------------------|-------------------------------|
| CaptionProvider    | localised templates, 6 languages        | `ai-captions` edge function   |
| OccasionAiProvider | returns `other`                         | `ai-occasion` edge function   |
| GeoProvider        | bundled list of ~200 places             | `geo-lookup` edge function    |
| PrintProvider      | catalog.json, simulated status timer    | `print-quote` / `print-order` |
| PaymentProvider    | instant success                         | Stripe Payment Sheet          |
| AuthProvider       | local anonymous user                    | Supabase auth                 |
| UploadProvider     | no-op with simulated progress           | Supabase storage              |
| Motion/Style/Guest/Gift | bundled samples / local filter     | stubs behind feature flags    |
| Analytics/Crash    | no-op                                   | PostHog / Sentry              |

`USE_FAKES=auto` means a service is fake when its key is empty; `true` forces fakes.
A fresh clone with no `.env` runs the full flow on fakes.

## Album creation pipeline

1. Import: custom `photo_manager` picker (or "Try a sample book" bundled photos).
2. Analyse (isolates): thumbnail → pHash, Laplacian sharpness, exposure; ML Kit faces
   and labels on device (fake analyser on desktop/tests).
3. Curate: burst grouping, near-duplicate removal, blur exclusion, overall score.
4. Occasion rules → suggestion card → user confirms theme.
5. Story interview → CaptionProvider → title, chapters, captions.
6. Layout engine (isolate, seeded RNG) → pages + cover → saved draft.
7. Editor with undo history (30 states) and debounced autosave; live preflight badge.
8. Preview (closed-book rotation, page-curl painter, reduce-motion fallback).
9. Checkout: format/finish/copies/address → quote → pay → order + upload.

## Backend

Supabase Postgres with RLS (`user_id = auth.uid()`), private buckets `originals`,
`renders`, `previews`. Edge functions proxy all AI and print calls; vendor and model names
come from env. `stripe-webhook` → `print-order` (idempotent by order id) → render service
`/render` → server preflight → print provider order → `order_events`.

## Render service

`POST /render`: validate album (zod) → fetch assets → rasterise each page at 300 dpi
(trim + 4 mm bleed) → JPEG q92 → pdf-lib assembly in provider order (cover spread,
endpaper, inner pages, endpaper) with TrimBox/BleedBox → server preflight → upload →
signed URL. `POST /preview` renders low-res JPEGs. `GET /health`.

## Testing strategy

- Dart unit tests for all domain modules (curation, occasion, layout determinism/pacing/
  face-safe crops/page parity, preflight rules, pricing, projection, wrapping, tinter).
- Widget tests for onboarding, import selection, editor template swap, checkout validation.
- Golden tests for covers and page templates in EN and MK.
- Node tests (vitest) for schema, wrap, projection, preflight, PDF structure.
- Shared fixtures guarantee Dart/TS parity; CI runs both plus a pixel parity check.

## Phases

0 Foundation → 1 Core album → 2 Print & pay → 3 Bonus stubs → 4 Polish.
Status per phase lives in `docs/PROGRESS.md`; every unforced choice goes in `docs/DECISIONS.md`.
