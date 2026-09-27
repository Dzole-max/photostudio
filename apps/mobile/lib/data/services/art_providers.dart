import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/illustration/stylize.dart';
import '../../domain/model/album.dart';
import '../photos/photo_library.dart';

/// Redraws a photo in an illustration style (section 9.2). Returns an
/// artwork PhotoRef (≥ 200 dpi at print size) linked to its source.
abstract interface class StyleProvider {
  Future<PhotoRef> stylize(
    PhotoRef photo,
    IllustrationStyle style, {
    List<int>? palette,
  });
}

/// "Enhance for print": upscales a small photo (section 6, AI photo rescue).
abstract interface class UpscaleProvider {
  Future<PhotoRef> enhance(PhotoRef photo);
}

/// Cover art for the Cover Studio's illustrated variant.
abstract interface class CoverArtProvider {
  Future<PhotoRef> illustratedCover(PhotoRef hero);
}

/// Output long side of generated artwork: 2400 px ≥ 200 dpi on a 280 mm
/// landscape cover (302 dpi on Classic).
const int kArtworkLongSide = 2400;

Future<Directory> _artDir() async {
  final dir = Directory(
    p.join((await getApplicationDocumentsDirectory()).path, 'artwork'),
  );
  if (!dir.existsSync()) dir.createSync(recursive: true);
  return dir;
}

Uint8List _stylizeJob((Uint8List, int, List<int>?, FaceBox?) a) =>
    stylizeEncoded(
      a.$1,
      IllustrationStyle.values[a.$2],
      longSide: kArtworkLongSide,
      paletteColors: a.$3,
      face: a.$4,
    );

Uint8List _upscaleJob(Uint8List bytes) {
  final src = img.bakeOrientation(img.decodeImage(bytes)!);
  final up = img.copyResize(
    src,
    width: src.width * 2,
    height: src.height * 2,
    interpolation: img.Interpolation.cubic,
  );
  // Unsharp-style sharpening to counter the softness of interpolation.
  final sharp = img.convolution(
    up,
    filter: const [0, -0.5, 0, -0.5, 3, -0.5, 0, -0.5, 0],
  );
  return img.encodeJpg(sharp, quality: 92);
}

/// Local filters instead of an image model (fake mode).
class FakeStyleProvider implements StyleProvider {
  FakeStyleProvider(this.images);

  final PhotoImages images;

  @override
  Future<PhotoRef> stylize(
    PhotoRef photo,
    IllustrationStyle style, {
    List<int>? palette,
  }) async {
    final id =
        '${photo.id}~${style.name}${palette == null ? '' : '_m${palette.first}'}';
    final file = File(p.join((await _artDir()).path, '$id.jpg'));
    if (!file.existsSync()) {
      final asset = photo.localAssetId!;
      final bytes = await images.libraryFor(asset).originalBytes(asset);
      final face = photo.faces.isEmpty ? null : photo.faces.first;
      final out = await compute(_stylizeJob, (
        bytes!,
        style.index,
        palette,
        face,
      ));
      await file.writeAsBytes(out, flush: true);
    }
    final landscape = photo.width >= photo.height;
    final w = landscape
        ? kArtworkLongSide
        : (kArtworkLongSide * photo.width / photo.height).round();
    final h = landscape
        ? (kArtworkLongSide * photo.height / photo.width).round()
        : kArtworkLongSide;
    return photo.copyWith(
      id: id,
      localAssetId: '$kFilePrefix${file.path}',
      remoteUrl: null,
      width: w,
      height: h,
      artwork: true,
      sourceId: photo.id,
      isExcluded: false,
      excludedReason: null,
    );
  }
}

class FakeUpscaleProvider implements UpscaleProvider {
  FakeUpscaleProvider(this.images);

  final PhotoImages images;

  @override
  Future<PhotoRef> enhance(PhotoRef photo) async {
    final id = '${photo.id}~enhanced';
    final file = File(p.join((await _artDir()).path, '$id.jpg'));
    if (!file.existsSync()) {
      final asset = photo.localAssetId!;
      final bytes = await images.libraryFor(asset).originalBytes(asset);
      await file.writeAsBytes(await compute(_upscaleJob, bytes!), flush: true);
    }
    return photo.copyWith(
      id: id,
      localAssetId: '$kFilePrefix${file.path}',
      width: photo.width * 2,
      height: photo.height * 2,
      artwork: true,
      sourceId: photo.id,
    );
  }
}

/// Watercolour illustration of the hero photo, painted on paper.
class FakeCoverArtProvider implements CoverArtProvider {
  FakeCoverArtProvider(this.styles);

  final StyleProvider styles;

  @override
  Future<PhotoRef> illustratedCover(PhotoRef hero) =>
      styles.stylize(hero, IllustrationStyle.watercolor);
}
