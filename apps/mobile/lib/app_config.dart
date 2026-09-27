/// Single place for brand identity, flavor and environment.
///
/// The brand name will change: see docs/RENAME.md for every place to update.
/// Environment values come from `--dart-define-from-file=.env`; nothing here
/// is a secret (publishable keys only).
library;

enum Flavor { dev, prod }

/// How service fakes are chosen: `auto` = fake when the key is empty,
/// `always` = fake everything (tests, demos).
enum FakeMode { auto, always }

class AppConfig {
  const AppConfig({
    required this.flavor,
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
    this.stripePublishableKey = '',
    this.revenueCatIosKey = '',
    this.revenueCatAndroidKey = '',
    this.sentryDsn = '',
    this.posthogKey = '',
    this.featureGuestLens = false,
    this.featureLivingMemories = false,
    this.featureIllustrated = false,
    this.featureGiftMode = false,
    this.fakeMode = FakeMode.auto,
  });

  /// Reads everything from compile-time environment (`--dart-define`).
  factory AppConfig.fromEnvironment(Flavor flavor) {
    const useFakes = String.fromEnvironment('USE_FAKES', defaultValue: 'auto');
    return AppConfig(
      flavor: flavor,
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
      stripePublishableKey: const String.fromEnvironment(
        'STRIPE_PUBLISHABLE_KEY',
      ),
      revenueCatIosKey: const String.fromEnvironment('REVENUECAT_API_KEY_IOS'),
      revenueCatAndroidKey: const String.fromEnvironment(
        'REVENUECAT_API_KEY_ANDROID',
      ),
      sentryDsn: const String.fromEnvironment('SENTRY_DSN'),
      posthogKey: const String.fromEnvironment('POSTHOG_KEY'),
      featureGuestLens: const bool.fromEnvironment('FEATURE_GUEST_LENS'),
      // The two signature editions are on by default in dev builds.
      featureLivingMemories:
          const bool.hasEnvironment('FEATURE_LIVING_MEMORIES')
          ? const bool.fromEnvironment('FEATURE_LIVING_MEMORIES')
          : flavor == Flavor.dev,
      featureIllustrated: const bool.hasEnvironment('FEATURE_ILLUSTRATED')
          ? const bool.fromEnvironment('FEATURE_ILLUSTRATED')
          : flavor == Flavor.dev,
      featureGiftMode: const bool.fromEnvironment('FEATURE_GIFT_MODE'),
      fakeMode: useFakes.trim() == 'true' ? FakeMode.always : FakeMode.auto,
    );
  }

  /// Everything faked; used by tests and the widget catalogue.
  const AppConfig.fakes({
    this.flavor = Flavor.dev,
    this.featureLivingMemories = true,
    this.featureIllustrated = true,
  }) : supabaseUrl = '',
       supabaseAnonKey = '',
       stripePublishableKey = '',
       revenueCatIosKey = '',
       revenueCatAndroidKey = '',
       sentryDsn = '',
       posthogKey = '',
       featureGuestLens = false,
       featureGiftMode = false,
       fakeMode = FakeMode.always;

  static const String brandName = 'Memoria';
  static const String bundleId = 'com.memoria.app';
  static const String supportEmail = 'hello@memoria.app';
  static const String giftLinkHost = 'https://memoria.app/g';
  static const String guestLinkHost = 'https://memoria.app/guests';

  final Flavor flavor;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String stripePublishableKey;
  final String revenueCatIosKey;
  final String revenueCatAndroidKey;
  final String sentryDsn;
  final String posthogKey;
  final bool featureGuestLens;
  final bool featureLivingMemories;
  final bool featureIllustrated;
  final bool featureGiftMode;
  final FakeMode fakeMode;

  bool get isDev => flavor == Flavor.dev;

  bool _fake(List<String> keys) =>
      fakeMode == FakeMode.always || keys.any((k) => k.trim().isEmpty);

  /// Backend (auth, storage, edge functions: AI, geo, print).
  bool get useFakeBackend => _fake([supabaseUrl, supabaseAnonKey]);

  bool get useFakePayments => useFakeBackend || _fake([stripePublishableKey]);

  bool get useFakePurchases => _fake([revenueCatIosKey, revenueCatAndroidKey]);

  bool get sentryEnabled => sentryDsn.isNotEmpty;

  bool get analyticsEnabled => posthogKey.isNotEmpty;

  AppConfig copyWith({
    bool? featureGuestLens,
    bool? featureLivingMemories,
    bool? featureIllustrated,
    bool? featureGiftMode,
  }) {
    return AppConfig(
      flavor: flavor,
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      stripePublishableKey: stripePublishableKey,
      revenueCatIosKey: revenueCatIosKey,
      revenueCatAndroidKey: revenueCatAndroidKey,
      sentryDsn: sentryDsn,
      posthogKey: posthogKey,
      featureGuestLens: featureGuestLens ?? this.featureGuestLens,
      featureLivingMemories:
          featureLivingMemories ?? this.featureLivingMemories,
      featureIllustrated: featureIllustrated ?? this.featureIllustrated,
      featureGiftMode: featureGiftMode ?? this.featureGiftMode,
      fakeMode: fakeMode,
    );
  }
}
