import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../domain/curation/curation.dart';
import '../../domain/curation/image_stats.dart';
import '../../domain/model/album.dart';
import '../db/app_database.dart';
import 'geocoder.dart';
import 'photo_library.dart';
import 'vision.dart';

class ImportProgress {
  const ImportProgress({
    required this.done,
    required this.total,
    this.latest = const [],
    this.result,
  });

  final int done;
  final int total;

  /// Asset ids of the most recently analysed photos (for the flowing
  /// thumbnails).
  final List<String> latest;

  /// Set on the final event.
  final CurationResult? result;
}

/// Stable, readable photo id for an asset.
String photoIdFor(String assetId) {
  if (assetId.startsWith(kSamplePrefix)) {
    return assetId.split('/').last.split('.').first;
  }
  return 'g_${assetId.substring(kGalleryPrefix.length).replaceAll(RegExp('[^A-Za-z0-9]'), '_')}';
}

/// Import pipeline (section 7.3): thumbnails decoded natively, pixel stats
/// in a pool of isolates, on-device vision, cached reverse geocoding, then
/// curation. Never blocks the UI thread.
class PhotoAnalyzer {
  PhotoAnalyzer({
    required this.vision,
    required this.geocoder,
    required this.db,
    int? workers,
  }) : workers = workers ?? math.max(1, Platform.numberOfProcessors - 1);

  final Vision vision;
  final ReverseGeocoder geocoder;
  final AppDatabase db;
  final int workers;

  static const int thumbnailSize = 512;

  Stream<ImportProgress> analyze(
    List<SourcePhoto> photos,
    PhotoLibrary library,
  ) async* {
    final total = photos.length;
    final results = List<PhotoRef?>.filled(total, null);
    final latest = <String>[];
    var done = 0;
    var next = 0;
    final events = StreamController<ImportProgress>();

    Future<void> worker() async {
      while (true) {
        final i = next++;
        if (i >= total) return;
        final src = photos[i];
        results[i] = await _analyzeOne(src, library);
        done++;
        latest.add(src.assetId);
        if (latest.length > 12) latest.removeAt(0);
        events.add(
          ImportProgress(done: done, total: total, latest: List.of(latest)),
        );
      }
    }

    final all = Future.wait([for (var w = 0; w < workers; w++) worker()])
        .then((_) => events.close());
    yield ImportProgress(done: 0, total: total);
    yield* events.stream;
    await all;

    final analysed = results.whereType<PhotoRef>().toList();
    final geocoded = await _geocode(analysed);
    yield ImportProgress(
      done: total,
      total: total,
      latest: List.of(latest),
      result: curate(geocoded),
    );
  }

  Future<PhotoRef> _analyzeOne(SourcePhoto src, PhotoLibrary library) async {
    final id = photoIdFor(src.assetId);
    final cached = await (db.select(
      db.photoAnalyses,
    )..where((a) => a.assetId.equals(src.assetId))).getSingleOrNull();
    if (cached != null) {
      return PhotoRef.fromJson(jsonDecode(cached.json) as Map<String, Object?>);
    }

    ImageStats? stats;
    final bytes = await library.thumbnailBytes(src.assetId, thumbnailSize);
    if (bytes != null) {
      final raw = await _decode(bytes, src.width, src.height);
      if (raw != null) {
        final (w, h, rgba) = raw;
        final transferable = TransferableTypedData.fromList([rgba]);
        stats = await Isolate.run(
          () => statsFromRgba(w, h, transferable.materialize().asUint8List()),
        );
      }
    }

    var faces = src.faces;
    var labels = src.labels;
    if (faces == null || labels == null) {
      final path = await library.filePath(src.assetId);
      final result = path == null
          ? const VisionResult()
          : await vision
                .analyze(path, src.width, src.height)
                .catchError((Object _) => const VisionResult());
      faces ??= result.faces;
      labels ??= result.labels;
    }

    final photo = PhotoRef(
      id: id,
      localAssetId: src.assetId,
      width: src.width,
      height: src.height,
      takenAt: src.takenAt,
      lat: src.lat,
      lng: src.lng,
      faces: faces,
      labels: labels,
      quality: QualityScore(
        exposure: stats?.exposure ?? 0.5,
        laplacian: stats?.laplacian ?? 0,
      ),
      hash: stats?.hash ?? '0000000000000000',
      dominantHue: stats?.dominantHue,
      focusX: stats?.focusX ?? 0.5,
      focusY: stats?.focusY ?? 0.45,
    );
    await db
        .into(db.photoAnalyses)
        .insertOnConflictUpdate(
          PhotoAnalysesCompanion.insert(
            assetId: src.assetId,
            json: jsonEncode(photo.toJson()),
            analyzedAt: DateTime.now(),
          ),
        );
    return photo;
  }

  /// Decodes to at most [thumbnailSize] px on the long side, natively.
  Future<(int, int, Uint8List)?> _decode(
    Uint8List bytes,
    int srcW,
    int srcH,
  ) async {
    try {
      final landscape = srcW >= srcH;
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: landscape ? thumbnailSize : null,
        targetHeight: landscape ? null : thumbnailSize,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final result = (image.width, image.height, data!.buffer.asUint8List());
      image.dispose();
      codec.dispose();
      return result;
    } on Object catch (e) {
      debugPrint('decode failed: $e');
      return null;
    }
  }

  Future<List<PhotoRef>> _geocode(List<PhotoRef> photos) async {
    final out = <PhotoRef>[];
    for (final p in photos) {
      if (p.lat == null || p.lng == null || p.placeName != null) {
        out.add(p);
        continue;
      }
      final r = await geocoder.lookup(p.lat!, p.lng!);
      out.add(
        r == null
            ? p
            : p.copyWith(
                placeName: r.placeName,
                placeId: r.placeId,
                countryCode: r.countryCode,
              ),
      );
    }
    return out;
  }
}
