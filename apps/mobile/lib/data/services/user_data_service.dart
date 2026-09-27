import 'dart:convert';

import '../db/app_database.dart';

/// Server side of "delete my data" (the `data-delete` edge function).
abstract interface class RemoteDataDeletion {
  Future<void> deleteEverything();
}

class FakeRemoteDataDeletion implements RemoteDataDeletion {
  const FakeRemoteDataDeletion();

  @override
  Future<void> deleteEverything() async {}
}

/// GDPR export and deletion of everything this device knows about the user.
class UserDataService {
  UserDataService({required this.db, required this.remote});

  final AppDatabase db;
  final RemoteDataDeletion remote;

  /// Albums and orders as one JSON document (local asset ids included, as
  /// they only have meaning on this phone).
  Future<String> exportJson() async {
    final albums = await db.select(db.albums).get();
    final orders = await db.select(db.orders).get();
    final out = <String, Object>{
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'albums': [for (final a in albums) jsonDecode(a.doc) as Object],
      'orders': [for (final o in orders) jsonDecode(o.json) as Object],
    };
    return const JsonEncoder.withIndent('  ').convert(out);
  }

  Future<void> deleteEverything() async {
    await remote.deleteEverything();
    await db.transaction(() async {
      for (final table in db.allTables) {
        await db.delete(table).go();
      }
    });
  }
}
