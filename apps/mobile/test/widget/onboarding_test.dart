import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:memoria/data/services/photo_permission.dart';
import 'package:memoria/data/settings/settings.dart';
import 'package:memoria/design/design.dart';
import 'package:memoria/features/home/home_screen.dart';
import 'package:memoria/features/onboarding/onboarding_screen.dart';
import 'package:memoria/l10n/app_localizations.dart';

import '../helpers/harness.dart';

void main() {
  for (final lang in AppLanguage.values) {
    testWidgets('launches to onboarding in ${lang.name}', (tester) async {
      await pumpMemoria(tester, prefs: {'language': lang.name});
      expect(find.byType(OnboardingScreen), findsOneWidget);
      final l = lookupAppLocalizations(lang.locale);
      expect(find.text(l.onboardingHeroTitle), findsOneWidget);
      expect(find.text(l.onboardingGetStarted), findsOneWidget);
    });
  }

  testWidgets('walks through onboarding to home', (tester) async {
    final container = await pumpMemoria(tester, prefs: {'language': 'en'});
    final l = lookupAppLocalizations(const Locale('en'));

    await tester.tap(find.text(l.onboardingGetStarted));
    // The edition tiles loop, so this page never settles.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(l.onboardingEditionsTitle), findsOneWidget);
    expect(find.text(l.editionVideoName), findsOneWidget);
    expect(find.text(l.editionCartoonName), findsOneWidget);

    await tester.tap(find.text(l.commonContinue));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text(l.onboardingPrivacyTitle), findsOneWidget);

    // Captions toggle defaults to on and can be turned off.
    expect(
      container.read(settingsControllerProvider).usePhotosForCaptions,
      isTrue,
    );
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(
      container.read(settingsControllerProvider).usePhotosForCaptions,
      isFalse,
    );

    await tester.tap(find.text(l.commonContinue));
    await tester.pumpAndSettle();
    expect(find.text(l.onboardingLanguageTitle), findsOneWidget);

    // Switching language re-renders instantly, without a restart.
    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();
    final de = lookupAppLocalizations(const Locale('de'));
    expect(find.text(de.onboardingLanguageTitle), findsOneWidget);

    await tester.tap(find.text(de.commonContinue));
    await tester.pumpAndSettle();
    expect(find.text(de.permissionTitle), findsOneWidget);

    await tester.tap(find.text(de.permissionAllow));
    // Home's cover fan floats continuously, so pump fixed steps.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(container.read(settingsControllerProvider).onboardingDone, isTrue);
  });

  testWidgets('theme mode switches between light and dark', (tester) async {
    final container = await pumpMemoria(
      tester,
      prefs: {'language': 'en', 'onboardingDone': true, 'themeMode': 'light'},
    );
    BuildContext ctx() => tester.element(find.byType(HomeScreen));
    expect(Theme.of(ctx()).brightness, Brightness.light);
    expect(MemoriaColors.of(ctx()).background, MemoriaColors.light.background);

    await container
        .read(settingsControllerProvider.notifier)
        .setThemeMode(AppThemeMode.dark);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(Theme.of(ctx()).brightness, Brightness.dark);
    expect(MemoriaColors.of(ctx()).background, MemoriaColors.dark.background);
  });

  testWidgets('photo access denied: the sample book is the main action', (
    tester,
  ) async {
    await pumpMemoria(
      tester,
      prefs: {'language': 'en'},
      photoAccess: PhotoAccess.denied,
    );
    final l = lookupAppLocalizations(const Locale('en'));
    await tester.tap(find.text(l.onboardingGetStarted));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text(l.commonContinue));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text(l.commonContinue));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text(l.permissionAllow));
    await tester.pumpAndSettle();
    expect(find.text(l.permissionSampleBody), findsOneWidget);
    final sample = find.widgetWithText(PrimaryButton, l.homeTrySample);
    expect(sample, findsOneWidget);
    expect(find.text(l.permissionOpenSettings), findsOneWidget);
  });
}
