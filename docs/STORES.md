# Store release checklist

One Android build serves Google Play and the Samsung Galaxy Store; iOS ships to the App Store.

## Build

```sh
cd apps/mobile
# Android App Bundle (Play) and universal APK (Galaxy Store accepts both)
flutter build appbundle --flavor prod -t lib/main_prod.dart --dart-define-from-file=.env
flutter build apk --flavor prod -t lib/main_prod.dart --dart-define-from-file=.env
# iOS (on macOS)
flutter build ipa -t lib/main_prod.dart --dart-define-from-file=.env
```

iOS uses entrypoints instead of Xcode schemes for flavors (see DECISIONS.md), so the dev
build on iOS is `flutter run -t lib/main_dev.dart`.

## Before the first release

- Replace the debug signing config in `android/app/build.gradle.kts` with an upload key
  (keep the keystore out of git).
- Apple: App ID with Sign in with Apple and Apple Pay (merchant id for Stripe).
- Google Pay: enable in the Stripe dashboard; set `merchantCountryCode` in the payment config.
- Supabase Auth redirect URLs for magic links and OAuth: `com.memoria.app://login-callback`.
- Fill real keys in `.env` (never commit it).

## Policy notes

- Physical printed books are paid with Stripe on both stores (allowed for physical goods).
- Digital unlocks (HD video, Illustrated Edition) must go through in-app purchase
  (RevenueCat); they are feature-flagged stubs in this version.
- No Google-Play-only APIs are used in core flows (no Play Billing, no Play Integrity, no
  Firebase), so the same APK works on Galaxy Store devices.
- Privacy: the iOS privacy manifest is `ios/Runner/PrivacyInfo.xcprivacy`; declare photos,
  physical address, email and crash data as "App functionality", not tracking. On Google
  Play's Data safety form declare the same.
- Photo permissions: iOS `NSPhotoLibraryUsageDescription` and limited-library handling;
  Android `READ_MEDIA_IMAGES`, `READ_MEDIA_VISUAL_USER_SELECTED`, `ACCESS_MEDIA_LOCATION`.

## Samsung Galaxy Store

1. Create the app in Samsung Seller Portal with the same package name.
2. Upload the release APK or AAB (same signing key as Play is fine).
3. Content rating, screenshots (same as Play), privacy policy URL.
4. Test on a Galaxy device: photo picker partial access (Android 14+), Stripe Payment Sheet
   with card and Google Pay.

## Store assets

- Icon: `apps/mobile/assets/brand/app_icon.png` (1024 × 1024, no alpha for iOS).
- Screenshots: onboarding hero, a finished wedding spread, the travel map page, the 3D
  preview, checkout summary. Use the sample books.
- Short description: "Your moments, bound beautifully."
