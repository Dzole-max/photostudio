import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoria/app.dart';
import 'package:memoria/app_config.dart';
import 'package:memoria/core/providers.dart';
import 'package:memoria/data/db/app_database.dart';
import 'package:memoria/data/samples/sample_books.dart';
import 'package:memoria/data/services/photo_permission.dart';
import 'package:memoria/data/services/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds the full app on fakes with the given stored preferences.
Future<ProviderContainer> pumpMemoria(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      appConfigProvider.overrideWithValue(const AppConfig.fakes()),
      sharedPreferencesProvider.overrideWithValue(sp),
      appDatabaseProvider.overrideWithValue(db),
      photoPermissionProvider.overrideWithValue(FakePhotoPermissionService()),
      // Building the demo books analyses 79 photos; widget tests skip it.
      sampleBooksProvider.overrideWith((ref) async {}),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MemoriaApp()),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return container;
}
