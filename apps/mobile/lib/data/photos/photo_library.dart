import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../../domain/model/album.dart';

/// Prefix of gallery asset ids and of bundled sample assets.
const kGalleryPrefix = 'pm:';
const kSamplePrefix = 'asset:';

/// Generated artwork and enhanced photos stored in the app's documents.
const kFilePrefix = 'file:';

/// A photo that can be picked, before analysis.
class SourcePhoto {
  const SourcePhoto({
    required this.assetId,
    required this.width,
    required this.height,
    this.takenAt,
    this.lat,
    this.lng,
    this.faces,
    this.labels,
  });

  final String assetId;
  final int width;
  final int height;
  final DateTime? takenAt;
  final double? lat;
  final double? lng;

  /// Present only for sample photos (stand-in for on-device ML).
  final List<FaceBox>? faces;
  final List<PhotoLabel>? labels;
}

class LibraryAlbum {
  const LibraryAlbum({
    required this.id,
    required this.name,
    required this.count,
  });

  final String id;
  final String name;
  final int count;
}

/// Read access to photos, from the gallery or from a bundled sample set.
abstract interface class PhotoLibrary {
  /// Newest first. [albumId] null = all photos.
  Future<List<SourcePhoto>> photos({
    String? albumId,
    DateTime? from,
    DateTime? to,
  });

  Future<List<LibraryAlbum>> albums();

  /// JPEG bytes no larger than [size] on the long side.
  Future<Uint8List?> thumbnailBytes(String assetId, int size);

  /// Full-resolution original bytes (for upload at checkout).
  Future<Uint8List?> originalBytes(String assetId);

  /// A path ML Kit can read, if the source has files.
  Future<String?> filePath(String assetId);

  ImageProvider imageProvider(String assetId, {int size = 512});
}

/// Wall-clock capture time as UTC (no time-zone shifting), see
/// docs/DECISIONS.md.
DateTime wallClock(DateTime local) => DateTime.utc(
  local.year,
  local.month,
  local.day,
  local.hour,
  local.minute,
  local.second,
);

class DevicePhotoLibrary implements PhotoLibrary {
  DevicePhotoLibrary();

  final Map<String, AssetEntity> _cache = {};

  Future<AssetEntity?> _entity(String assetId) async {
    final id = assetId.substring(kGalleryPrefix.length);
    return _cache[id] ??= (await AssetEntity.fromId(id))!;
  }

  @override
  Future<List<LibraryAlbum>> albums() async {
    final paths = await PhotoManager.getAssetPathList(type: RequestType.image);
    return [
      for (final p in paths)
        LibraryAlbum(id: p.id, name: p.name, count: await p.assetCountAsync),
    ];
  }

  @override
  Future<List<SourcePhoto>> photos({
    String? albumId,
    DateTime? from,
    DateTime? to,
  }) async {
    final filter = FilterOptionGroup(
      imageOption: const FilterOption(needTitle: false),
      orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
      createTimeCond: DateTimeCond(
        min: from ?? DateTime.fromMillisecondsSinceEpoch(0),
        max: to ?? DateTime.now().add(const Duration(days: 1)),
      ),
    );
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      filterOption: filter,
      onlyAll: albumId == null,
    );
    final path = albumId == null
        ? (paths.isEmpty ? null : paths.first)
        : paths.where((p) => p.id == albumId).firstOrNull;
    if (path == null) return const [];
    final count = await path.assetCountAsync;
    final entities = await path.getAssetListRange(start: 0, end: count);
    return [
      for (final e in entities)
        () {
          _cache[e.id] = e;
          return SourcePhoto(
            assetId: '$kGalleryPrefix${e.id}',
            width: e.orientatedWidth,
            height: e.orientatedHeight,
            takenAt: wallClock(e.createDateTime),
            lat: (e.latitude ?? 0) == 0 ? null : e.latitude,
            lng: (e.longitude ?? 0) == 0 ? null : e.longitude,
          );
        }(),
    ];
  }

  @override
  Future<Uint8List?> thumbnailBytes(String assetId, int size) async {
    final e = await _entity(assetId);
    return e?.thumbnailDataWithSize(ThumbnailSize.square(size), quality: 88);
  }

  @override
  Future<Uint8List?> originalBytes(String assetId) async =>
      (await _entity(assetId))?.originBytes;

  @override
  Future<String?> filePath(String assetId) async =>
      (await (await _entity(assetId))?.file)?.path;

  @override
  ImageProvider imageProvider(String assetId, {int size = 512}) {
    final id = assetId.substring(kGalleryPrefix.length);
    final entity =
        _cache[id] ??
        AssetEntity(id: id, typeInt: 1, width: size, height: size);
    return AssetEntityImageProvider(
      entity,
      isOriginal: false,
      thumbnailSize: ThumbnailSize.square(size),
    );
  }
}

/// A bundled sample set ("Try a sample book"): photos plus a manifest that
/// stands in for EXIF data and on-device ML.
class SamplePhotoLibrary implements PhotoLibrary {
  SamplePhotoLibrary(this.set, {AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final String set;
  final AssetBundle _bundle;
  List<SourcePhoto>? _photos;

  @override
  Future<List<LibraryAlbum>> albums() async => [
    LibraryAlbum(id: set, name: set, count: (await photos()).length),
  ];

  @override
  Future<List<SourcePhoto>> photos({
    String? albumId,
    DateTime? from,
    DateTime? to,
  }) async {
    final all = _photos ??= await _load();
    return all
        .where(
          (p) =>
              (from == null || !p.takenAt!.isBefore(from)) &&
              (to == null || !p.takenAt!.isAfter(to)),
        )
        .toList();
  }

  Future<List<SourcePhoto>> _load() async {
    final json = jsonDecode(
      await _bundle.loadString('assets/samples/$set/manifest.json'),
    ) as Map<String, Object?>;
    final list = [
      for (final raw in json['photos']! as List<Object?>)
        if (raw case final Map<String, Object?> m)
          SourcePhoto(
            assetId: '$kSamplePrefix${m['file']}',
            width: m['width']! as int,
            height: m['height']! as int,
            takenAt: DateTime.parse('${m['takenAt']}Z'),
            lat: (m['lat'] as num?)?.toDouble(),
            lng: (m['lng'] as num?)?.toDouble(),
            faces: [
              for (final f in m['faces']! as List<Object?>)
                FaceBox.fromJson(f! as Map<String, Object?>),
            ],
            labels: [
              for (final l in m['labels']! as List<Object?>)
                PhotoLabel.fromJson(l! as Map<String, Object?>),
            ],
          ),
    ]..sort((a, b) => b.takenAt!.compareTo(a.takenAt!));
    return list;
  }

  String _path(String assetId) => assetId.substring(kSamplePrefix.length);

  @override
  Future<Uint8List?> thumbnailBytes(String assetId, int size) async {
    final data = await _bundle.load(_path(assetId));
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  @override
  Future<Uint8List?> originalBytes(String assetId) =>
      thumbnailBytes(assetId, 0);

  @override
  Future<String?> filePath(String assetId) async => null;

  @override
  ImageProvider imageProvider(String assetId, {int size = 512}) => ResizeImage(
    AssetImage(_path(assetId)),
    width: size,
    policy: ResizeImagePolicy.fit,
  );
}

/// Files the app generated (illustrations, enhanced photos).
class FilePhotoLibrary implements PhotoLibrary {
  const FilePhotoLibrary();

  String _path(String assetId) => assetId.substring(kFilePrefix.length);

  @override
  Future<List<LibraryAlbum>> albums() async => const [];

  @override
  Future<List<SourcePhoto>> photos({
    String? albumId,
    DateTime? from,
    DateTime? to,
  }) async => const [];

  @override
  Future<Uint8List?> thumbnailBytes(String assetId, int size) async {
    final f = File(_path(assetId));
    return f.existsSync() ? f.readAsBytes() : null;
  }

  @override
  Future<Uint8List?> originalBytes(String assetId) =>
      thumbnailBytes(assetId, 0);

  @override
  Future<String?> filePath(String assetId) async => _path(assetId);

  @override
  ImageProvider imageProvider(String assetId, {int size = 512}) => ResizeImage(
    FileImage(File(_path(assetId))),
    width: size,
    policy: ResizeImagePolicy.fit,
  );
}

/// Resolves any asset id (gallery or sample) to an image provider.
class PhotoImages {
  PhotoImages(this.gallery);

  final PhotoLibrary gallery;
  final Map<String, SamplePhotoLibrary> _samples = {};

  PhotoLibrary libraryFor(String assetId) {
    if (assetId.startsWith(kFilePrefix)) return const FilePhotoLibrary();
    if (assetId.startsWith(kSamplePrefix)) {
      final set = assetId.split('/').elementAt(2);
      return _samples.putIfAbsent(set, () => SamplePhotoLibrary(set));
    }
    return gallery;
  }

  ImageProvider provider(PhotoRef photo, {int size = 512}) =>
      libraryFor(photo.localAssetId ?? '')
          .imageProvider(photo.localAssetId ?? '', size: size);
}
