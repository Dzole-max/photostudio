# Renaming the app

"Memoria" is a temporary name. Everything that carries the name or bundle id is listed here;
change them together.

## Name

1. `apps/mobile/lib/app_config.dart` — `AppConfig.brandName`, `supportEmail`, link hosts.
2. `apps/mobile/lib/l10n/app_*.arb` — `appTitle` in all six files, plus strings that
   mention the name: search the ARB files for `Memoria`.
3. `packages/layout_spec/i18n/book_strings.json` — `colophon` in every language.
4. `apps/mobile/android/app/build.gradle.kts` — `resValue("string", "app_name", ...)` for
   both flavors.
5. `apps/mobile/ios/Runner/Info.plist` — `CFBundleDisplayName`, `CFBundleName`, and the
   photo-library usage strings.
6. `services/render` — PDF metadata producer string (`src/pdf/assemble.ts`) and the video
   end card text.
7. Docs and `README.md`.

## Bundle / application id (`com.memoria.app`)

1. `apps/mobile/android/app/build.gradle.kts` — `val appId`.
2. Move `apps/mobile/android/app/src/main/kotlin/com/memoria/app/MainActivity.kt` to the new
   package path and update its `package` line.
3. `apps/mobile/ios/Runner.xcodeproj/project.pbxproj` — `PRODUCT_BUNDLE_IDENTIFIER`
   (Runner and RunnerTests).
4. `apps/mobile/lib/app_config.dart` — `AppConfig.bundleId`.
5. Supabase Auth redirect URLs and Apple/Google sign-in client configuration.
6. Stripe: Apple Pay merchant id and Google Pay settings.
7. Store listings (App Store Connect, Google Play, Samsung Galaxy Store).

## Dart package name

The Dart package is `memoria`. Renaming it is optional; if you do, update `name:` in
`apps/mobile/pubspec.yaml` and replace `package:memoria/` in `apps/mobile/test/`.

## Icons

Colours and geometry live in `tools/brand/make_icons.py`; run `make icons` after changes.
