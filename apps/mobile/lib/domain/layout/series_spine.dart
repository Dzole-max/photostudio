import 'dart:math' as math;

import '../model/album.dart';
import '../model/geometry.dart';
import '../spec/book_format.dart';
import 'cover_composer.dart';
import 'type_kit.dart';

/// Book-cloth colours for series spines. A series always gets the same one,
/// so the books line up on a shelf as a set.
const kSeriesSpineColors = [
  '#2F3E46', // slate
  '#5B3A29', // tobacco
  '#1F3A5F', // navy
  '#6B2E3A', // burgundy
  '#3E5641', // forest
  '#8A6A3B', // ochre
];

const _spineInk = '#F3ECDF';

/// Stable across runs and platforms (unlike String.hashCode).
String seriesColor(String series) {
  var h = 0;
  for (final u in series.trim().toLowerCase().codeUnits) {
    h = (h * 31 + u) & 0x7fffffff;
  }
  return kSeriesSpineColors[h % kSeriesSpineColors.length];
}

/// The shared series spine: series colour, the series name at the head,
/// the book's title in the middle and its volume number at the foot.
CoverDesign applySeriesSpine(
  CoverDesign cover, {
  required String series,
  required int? volume,
  required String title,
  required double heightMm,
}) {
  final w = cover.spineMm;
  final h = heightMm;
  final texts = <TextBlock>[];
  final ornaments = <Ornament>[];
  if (w >= kMinSpineTextMm) {
    final size = math
        .min(9.0, mmToPt(w) * 0.45)
        .clamp(kMinTextPt, 9.0)
        .toDouble();
    TextBlock vertical(
      String id,
      String text,
      double cy,
      double len,
      double pt, {
      int weight = 600,
      String font = 'Manrope',
    }) => TextBlock(
      id: id,
      role: TextRole.title,
      text: text,
      fontFamily: font,
      sizePt: pt,
      weight: weight,
      color: _spineInk,
      align: TextAlignKind.center,
      vAlign: VerticalAlignKind.middle,
      rectMm: RectMm(x: w / 2 - len / 2, y: cy - w * 0.35, w: len, h: w * 0.7),
      uppercase: true,
      trackingPct: 16,
      lineHeight: 1.1,
      maxLines: 1,
      rotationDeg: 90,
    );
    texts
      ..add(
        vertical(
          'spine_series',
          series,
          h * 0.17,
          h * 0.26,
          math.max(kMinTextPt, size - 1),
          weight: 500,
        ),
      )
      ..add(vertical('spine', title, h * 0.52, h * 0.4, size));
    if (volume != null) {
      final r = math.min(w * 0.36, 5.5);
      final cy = h * 0.86;
      ornaments.add(
        Ornament(
          type: OrnamentType.circle,
          params: {'cx': w / 2, 'cy': cy, 'r': r},
          color: _spineInk,
          strokePt: 0.6,
        ),
      );
      texts.add(
        TextBlock(
          id: 'spine_volume',
          role: TextRole.label,
          text: '$volume',
          fontFamily: 'CormorantGaramond',
          sizePt: math.max(kMinTextPt, mmToPt(r) * 1.1),
          weight: 600,
          color: _spineInk,
          align: TextAlignKind.center,
          vAlign: VerticalAlignKind.middle,
          rectMm: RectMm(x: w / 2 - r, y: cy - r, w: 2 * r, h: 2 * r),
          maxLines: 1,
        ),
      );
    }
    // Two thin rules frame the title, like a bound set.
    for (final y in [h * 0.3, h * 0.74]) {
      ornaments.add(
        Ornament(
          type: OrnamentType.line,
          params: {'x1': w * 0.2, 'y1': y, 'x2': w * 0.8, 'y2': y},
          color: _spineInk,
          strokePt: 0.5,
        ),
      );
    }
  }
  return cover.copyWith(
    spine: cover.spine.copyWith(
      templateId: 'spine_series',
      texts: texts,
      ornaments: ornaments,
      background: PageBackground(color: seriesColor(series)),
    ),
  );
}

/// The album with its spine redrawn for its series (unchanged if none).
Album withSeriesSpine(Album a) {
  final series = a.series?.trim();
  if (series == null || series.isEmpty) return a;
  return a.copyWith(
    cover: applySeriesSpine(
      a.cover,
      series: series,
      volume: a.seriesVolume,
      title: a.cover.spineText ?? a.title,
      heightMm: BookFormat.byId(a.formatId).trimHMm,
    ),
  );
}
