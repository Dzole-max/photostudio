import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers.dart';
import '../../domain/model/album.dart';
import '../db/app_database.dart' as db;

part 'album_repository.g.dart';

/// Lightweight row for lists (home carousel, orders).
class AlbumSummary {
  const AlbumSummary({
    required this.id,
    required this.title,
    required this.occasion,
    required this.status,
    required this.themeId,
    required this.formatId,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final Occasion occasion;
  final AlbumStatus status;
  final String themeId;
  final String formatId;
  final DateTime updatedAt;
}

/// Albums persisted as whole JSON documents in Drift.
class AlbumRepository {
  AlbumRepository(this._db);

  final db.AppDatabase _db;

  Future<void> save(Album album) async {
    await _db
        .into(_db.albums)
        .insertOnConflictUpdate(
          db.AlbumsCompanion.insert(
            id: album.id,
            title: album.title,
            occasion: album.occasion.name,
            status: album.status.name,
            themeId: album.themeId,
            formatId: album.formatId,
            doc: jsonEncode(album.toJson()),
            createdAt: album.createdAt,
            updatedAt: album.updatedAt,
          ),
        );
  }

  Future<Album?> load(String id) async {
    final row = await (_db.select(
      _db.albums,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return Album.fromJson(jsonDecode(row.doc) as Map<String, Object?>);
  }

  Stream<List<AlbumSummary>> watchAll() {
    final q = _db.select(_db.albums)
      ..orderBy([(a) => OrderingTerm.desc(a.updatedAt)]);
    return q.watch().map(
      (rows) => [
        for (final r in rows)
          AlbumSummary(
            id: r.id,
            title: r.title,
            occasion: Occasion.values.byName(r.occasion),
            status: AlbumStatus.values.byName(r.status),
            themeId: r.themeId,
            formatId: r.formatId,
            updatedAt: r.updatedAt,
          ),
      ],
    );
  }

  Future<void> delete(String id) =>
      (_db.delete(_db.albums)..where((a) => a.id.equals(id))).go();
}

@Riverpod(keepAlive: true)
AlbumRepository albumRepository(Ref ref) =>
    AlbumRepository(ref.watch(appDatabaseProvider));

@riverpod
Stream<List<AlbumSummary>> albumList(Ref ref) =>
    ref.watch(albumRepositoryProvider).watchAll();

@riverpod
Future<Album?> albumById(Ref ref, String id) =>
    ref.watch(albumRepositoryProvider).load(id);
