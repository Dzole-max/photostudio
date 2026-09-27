@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/harness.dart';

void main() {
  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('onboarding hero (en)', (tester) async {
    await phone(tester);
    await pumpMemoria(tester, prefs: {'language': 'en'});
    await tester.pump(const Duration(milliseconds: 2800));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/onboarding_hero_en.png'),
    );
  });

  testWidgets('onboarding hero (mk)', (tester) async {
    await phone(tester);
    await pumpMemoria(tester, prefs: {'language': 'mk'});
    await tester.pump(const Duration(milliseconds: 2800));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/onboarding_hero_mk.png'),
    );
  });

  for (final mode in ['light', 'dark']) {
    testWidgets('settings ($mode)', (tester) async {
      await phone(tester);
      await pumpMemoria(
        tester,
        prefs: {'language': 'en', 'onboardingDone': true, 'themeMode': mode},
      );
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/settings_$mode.png'),
      );
    });
  }

  for (final mode in ['light', 'dark']) {
    testWidgets('home ($mode)', (tester) async {
      await phone(tester);
      await pumpMemoria(
        tester,
        prefs: {'language': 'en', 'onboardingDone': true, 'themeMode': mode},
      );
      // Entry motion and the first frames of the cover float.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/home_$mode.png'),
      );
    });
  }

  testWidgets('occasion screen (wedding)', (tester) async {
    await phone(tester);
    await pumpMemoria(
      tester,
      prefs: {'language': 'en', 'onboardingDone': true, 'themeMode': 'light'},
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Wedding'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/occasion_wedding.png'),
    );
  });
}
