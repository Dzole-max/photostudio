import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'app_config.dart';
import 'core/providers.dart';
import 'data/services/observability.dart';
import 'data/services/services.dart';

/// Shared startup for every flavor.
Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment(flavor);
  final prefs = await SharedPreferences.getInstance();

  final Analytics analytics = config.analyticsEnabled
      ? await PosthogAnalytics.start(config.posthogKey)
      : NoopAnalytics();

  Widget app() => ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(config),
      sharedPreferencesProvider.overrideWithValue(prefs),
      analyticsProvider.overrideWithValue(analytics),
    ],
    child: const MemoriaApp(),
  );

  if (config.sentryEnabled) {
    await SentryFlutter.init((options) {
      options
        ..dsn = config.sentryDsn
        ..environment = flavor.name
        ..tracesSampleRate = kReleaseMode ? 0.2 : 1.0
        ..sendDefaultPii = false;
    }, appRunner: () => runApp(app()));
  } else {
    runApp(app());
  }
}
