import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../model/album.dart';
import 'stylize.dart';

/// One main person: the photo to take them from and their face in it.
class CharacterSource {
  const CharacterSource(this.bytes, this.face);

  final Uint8List bytes;
  final FaceBox face;
}

class CharacterSheet {
  const CharacterSheet({required this.palette, required this.portraits});

  /// Colours every page of the edition is drawn with (0xRRGGBB), so skin,
  /// hair and clothes stay the same from page to page.
  final List<int> palette;

  /// Each main person redrawn in the chosen style (JPEG), for the sheet.
  final List<Uint8List> portraits;
}

/// Builds the character sheet: head-and-shoulders crops of the main people
/// give the shared palette, then each is drawn with it. Runs in an isolate.
CharacterSheet buildCharacterSheet(
  (List<CharacterSource>, IllustrationStyle) args,
) {
  final (sources, style) = args;
  const side = 320;
  final crops = <img.Image>[];
  for (final s in sources) {
    final decoded = img.bakeOrientation(img.decodeImage(s.bytes)!);
    final src = decoded.width > 1200
        ? img.copyResize(decoded, width: 1200)
        : decoded;
    final f = s.face;
    final size = math.max(f.w * src.width, f.h * src.height) * 2.2;
    final cx = (f.x + f.w / 2) * src.width;
    final cy = (f.y + f.h / 2) * src.height + size * 0.12;
    final x = (cx - size / 2).clamp(0, math.max(0, src.width - size)).round();
    final y = (cy - size / 2).clamp(0, math.max(0, src.height - size)).round();
    final w = math.min(size.round(), src.width - x);
    final h = math.min(size.round(), src.height - y);
    crops.add(
      img.copyResize(
        img.copyCrop(src, x: x, y: y, width: w, height: h),
        width: side,
        height: side,
      ),
    );
  }
  if (crops.isEmpty) return const CharacterSheet(palette: [], portraits: []);
  final grid = img.Image(width: side * crops.length, height: side);
  for (var i = 0; i < crops.length; i++) {
    img.compositeImage(grid, crops[i], dstX: i * side);
  }
  final palette = StylePalette.fromImage(grid, k: 12);
  return CharacterSheet(
    palette: palette.colors,
    portraits: [
      for (final c in crops)
        img.encodeJpg(stylizeImage(c, style, palette: palette), quality: 88),
    ],
  );
}

/// Small previews of every style for the picker, from one photo (decoded
/// once). Runs in an isolate.
List<Uint8List> stylePreviews((Uint8List, FaceBox?) args) {
  final (bytes, face) = args;
  final decoded = img.bakeOrientation(img.decodeImage(bytes)!);
  final small = decoded.width >= decoded.height
      ? img.copyResize(decoded, width: 420)
      : img.copyResize(decoded, height: 420);
  return [
    for (final style in IllustrationStyle.values)
      img.encodeJpg(stylizeImage(small, style, face: face), quality: 85),
  ];
}
