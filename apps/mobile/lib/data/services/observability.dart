import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Product analytics events (section 16, phase 4).
enum AnalyticsEvent {
  importStarted('import_started'),
  curationDone('curation_done'),
  occasionConfirmed('occasion_confirmed'),
  bookGenerated('book_generated'),
  preflightPassed('preflight_passed'),
  checkoutStarted('checkout_started'),
  orderPaid('order_paid');

  const AnalyticsEvent(this.wireName);

  final String wireName;
}

abstract interface class Analytics {
  Future<void> track(AnalyticsEvent event, [Map<String, Object> props]);
}

/// Used when no PostHog key is configured.
class NoopAnalytics implements Analytics {
  NoopAnalytics();

  /// Events recorded in memory; handy in tests and the dev menu.
  final List<(AnalyticsEvent, Map<String, Object>)> recorded = [];

  @override
  Future<void> track(AnalyticsEvent event, [Map<String, Object>? props]) async {
    recorded.add((event, props ?? const {}));
  }
}

class PosthogAnalytics implements Analytics {
  PosthogAnalytics._();

  static Future<PosthogAnalytics> start(String key) async {
    final config = PostHogConfig(key)
      ..host = 'https://eu.i.posthog.com'
      ..captureApplicationLifecycleEvents = true;
    await Posthog().setup(config);
    return PosthogAnalytics._();
  }

  @override
  Future<void> track(AnalyticsEvent event, [Map<String, Object>? props]) =>
      Posthog().capture(eventName: event.wireName, properties: props);
}

abstract interface class CrashReporter {
  Future<void> report(Object error, StackTrace? stack);
}

class NoopCrashReporter implements CrashReporter {
  const NoopCrashReporter();

  @override
  Future<void> report(Object error, StackTrace? stack) async {
    debugPrint('error: $error\n$stack');
  }
}

class SentryCrashReporter implements CrashReporter {
  const SentryCrashReporter();

  @override
  Future<void> report(Object error, StackTrace? stack) async {
    await Sentry.captureException(error, stackTrace: stack);
  }
}
