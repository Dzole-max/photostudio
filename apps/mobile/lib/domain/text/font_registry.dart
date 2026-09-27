import 'dart:typed_data';

import 'font_metrics.dart';

/// One bundled font file. The same table exists in the render service
/// (services/render/src/text/fonts.ts).
class FontFace {
  const FontFace(this.family, this.weight, this.italic, this.file);

  final String family;
  final int weight;
  final bool italic;
  final String file;
}

const List<FontFace> kFontFaces = [
  FontFace('Inter', 400, false, 'Inter-400.ttf'),
  FontFace('Inter', 500, false, 'Inter-500.ttf'),
  FontFace('Inter', 600, false, 'Inter-600.ttf'),
  FontFace('CormorantGaramond', 400, false, 'CormorantGaramond-400.ttf'),
  FontFace('CormorantGaramond', 500, false, 'CormorantGaramond-500.ttf'),
  FontFace('CormorantGaramond', 600, false, 'CormorantGaramond-600.ttf'),
  FontFace('CormorantGaramond', 700, false, 'CormorantGaramond-700.ttf'),
  FontFace('CormorantGaramond', 500, true, 'CormorantGaramond-Italic-500.ttf'),
  FontFace('Lora', 400, false, 'Lora-400.ttf'),
  FontFace('Lora', 600, false, 'Lora-600.ttf'),
  FontFace('Lora', 400, true, 'Lora-Italic-400.ttf'),
  FontFace('Manrope', 400, false, 'Manrope-400.ttf'),
  FontFace('Manrope', 600, false, 'Manrope-600.ttf'),
  FontFace('Manrope', 700, false, 'Manrope-700.ttf'),
  FontFace('Nunito', 400, false, 'Nunito-400.ttf'),
  FontFace('Nunito', 700, false, 'Nunito-700.ttf'),
  FontFace('Nunito', 800, false, 'Nunito-800.ttf'),
  FontFace('GreatVibes', 400, false, 'GreatVibes-400.ttf'),
];

/// Picks the bundled face for a requested family/weight/style: exact style
/// first, then the nearest weight (ties go to the heavier face).
FontFace resolveFace(String family, int weight, {bool italic = false}) {
  final inFamily = kFontFaces.where((f) => f.family == family).toList();
  if (inFamily.isEmpty) {
    return resolveFace('Lora', weight, italic: italic);
  }
  final styled = inFamily.where((f) => f.italic == italic).toList();
  final pool = styled.isEmpty ? inFamily : styled;
  pool.sort((a, b) {
    final da = (a.weight - weight).abs();
    final db = (b.weight - weight).abs();
    if (da != db) return da.compareTo(db);
    return b.weight.compareTo(a.weight);
  });
  return pool.first;
}

/// Parsed metrics for every bundled face.
class FontRegistry {
  FontRegistry(Map<String, Uint8List> filesByName)
    : _metrics = {
        for (final face in kFontFaces)
          if (filesByName[face.file] case final bytes?)
            face.file: FontMetrics.parse(bytes),
      };

  final Map<String, FontMetrics> _metrics;

  FontMetrics metrics(String family, int weight, {bool italic = false}) {
    final face = resolveFace(family, weight, italic: italic);
    return _metrics[face.file] ??
        (throw StateError('font ${face.file} was not loaded'));
  }
}
