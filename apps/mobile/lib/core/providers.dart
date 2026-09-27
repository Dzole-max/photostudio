import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_config.dart';
import '../data/db/app_database.dart';

part 'providers.g.dart';

/// Overridden in bootstrap with the loaded instance.
@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) =>
    throw StateError('sharedPreferencesProvider must be overridden');

/// Overridden in bootstrap with the flavor's configuration.
@Riverpod(keepAlive: true)
AppConfig appConfig(Ref ref) => const AppConfig.fakes();

/// Overridden in bootstrap; tests use an in-memory database.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
}
