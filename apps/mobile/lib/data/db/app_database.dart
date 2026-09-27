import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Albums are stored as whole JSON documents (the shared album contract);
/// the extra columns exist for listing without decoding every document.
class Albums extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get occasion => text()();
  TextColumn get status => text()();
  TextColumn get themeId => text()();
  TextColumn get formatId => text()();
  TextColumn get doc => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Cached on-device analysis per gallery asset (hash, sharpness, faces...).
class PhotoAnalyses extends Table {
  TextColumn get assetId => text()();
  TextColumn get json => text()();
  DateTimeColumn get analyzedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {assetId};
}

/// Reverse-geocoding cache keyed by coordinates rounded to 0.01°.
class GeocodeCache extends Table {
  TextColumn get cellKey => text()();
  TextColumn get placeName => text()();
  TextColumn get countryCode => text()();
  TextColumn get countryName => text()();

  @override
  Set<Column<Object>> get primaryKey => {cellKey};
}

class Orders extends Table {
  TextColumn get id => text()();
  TextColumn get albumId => text()();
  TextColumn get status => text()();
  TextColumn get json => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Albums, PhotoAnalyses, GeocodeCache, Orders])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.open() : super(driftDatabase(name: 'memoria'));

  @override
  int get schemaVersion => 1;
}
