import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/photos/photo_library.dart';
import '../../data/services/services.dart';
import '../../domain/model/album.dart';

part 'book_images.g.dart';

/// Decodes [photo] with its long side at about [size] px. The caller owns
/// (and disposes) the image.
Future<ui.Image?> decodePhoto(
  PhotoImages images,
  PhotoRef photo,
  int size,
) async {
  final assetId = photo.localAssetId;
  if (assetId == null) return null;
  final bytes = await images.libraryFor(assetId).thumbnailBytes(assetId, size);
  if (bytes == null) return null;
  final landscape = photo.width >= photo.height;
  final codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: landscape ? size : null,
    targetHeight: landscape ? null : size,
  );
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

/// Decoded photos for painting pages, bucketed by size and LRU-evicted.
/// Notifies listeners as images arrive so pages repaint progressively.
class BookImageStore extends ChangeNotifier {
  BookImageStore(this.images, {this.maxEntries = 120});

  final PhotoImages images;
  final int maxEntries;
  final LinkedHashMap<String, ui.Image> _cache = LinkedHashMap();
  final Map<String, Future<void>> _pending = {};

  static int bucket(double px) {
    for (final b in const [256, 512, 1024, 2048]) {
      if (px <= b) return b;
    }
    return 3072;
  }

  String _key(String photoId, int size) => '$photoId@$size';

  /// The image at [size] if loaded, else the largest other size loaded
  /// (so pages show something while the sharper version decodes).
  ui.Image? get(PhotoRef photo, int size) {
    final exact = _cache.remove(_key(photo.id, size));
    if (exact != null) {
      _cache[_key(photo.id, size)] = exact; // most recently used
      return exact;
    }
    for (final b in const [3072, 2048, 1024, 512, 256]) {
      final img = _cache[_key(photo.id, b)];
      if (img != null) return img;
    }
    return null;
  }

  bool has(PhotoRef photo, int size) =>
      _cache.containsKey(_key(photo.id, size));

  /// Starts loading [photo] at [size] if needed.
  void request(PhotoRef photo, int size) {
    final key = _key(photo.id, size);
    if (_cache.containsKey(key) || _pending.containsKey(key)) return;
    final assetId = photo.localAssetId;
    if (assetId == null) return;
    _pending[key] = _load(
      photo,
      assetId,
      size,
      key,
    ).whenComplete(() => _pending.remove(key));
  }

  Future<void> _load(
    PhotoRef photo,
    String assetId,
    int size,
    String key,
  ) async {
    try {
      final image = await decodePhoto(images, photo, size);
      if (image == null) return;
      _cache[key] = image;
      while (_cache.length > maxEntries) {
        final oldest = _cache.keys.first;
        _cache.remove(oldest)?.dispose();
      }
      notifyListeners();
    } on Object catch (e) {
      debugPrint('image load failed for $assetId: $e');
    }
  }

  /// Waits until every requested image has loaded (goldens, previews).
  Future<void> settle() async {
    while (_pending.isNotEmpty) {
      await Future.wait(_pending.values.toList());
    }
  }

  @override
  void dispose() {
    for (final img in _cache.values) {
      img.dispose();
    }
    _cache.clear();
    super.dispose();
  }
}

@Riverpod(keepAlive: true)
BookImageStore bookImageStore(Ref ref) {
  final store = BookImageStore(ref.watch(photoImagesProvider));
  ref.onDispose(store.dispose);
  return store;
}
