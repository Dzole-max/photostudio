import 'dart:math' as math;

import '../art/icon_pack.dart';
import '../model/album.dart';
import '../model/geometry.dart';
import '../spec/book_format.dart';

/// A handwritten dedication: finger strokes turned into vector ink on the
/// first inner page, so it prints as sharply as the type.

/// Ink colour: a deep blue-black, like fountain-pen ink.
const kDedicationInk = '#1E2A44';
const double kDedicationStrokePt = 1.1;

/// Marks the ornaments that belong to the dedication.
const _kTag = 'dedication';

/// Where the dedication goes: the lower part of the first page's safe area.
RectMm dedicationArea(BookFormat format) {
  final safe = format.safeArea(BookFormat.sideOf(0));
  final h = safe.h * 0.26;
  return RectMm(
    x: safe.x + safe.w * 0.12,
    y: safe.bottom - h,
    w: safe.w * 0.76,
    h: h,
  );
}

/// One stroke as points normalised to the dedication area (0..1).
typedef InkStroke = List<(double, double)>;

/// Smooth path through [points] (quadratic curves through midpoints), in mm.
String inkPath(List<(double, double)> points) {
  String n(double v) => v.toStringAsFixed(2);
  if (points.isEmpty) return '';
  final (x0, y0) = points.first;
  if (points.length == 1) {
    // A dot: a tiny line so round caps draw it.
    return 'M ${n(x0)} ${n(y0)} L ${n(x0 + 0.05)} ${n(y0)}';
  }
  final b = StringBuffer('M ${n(x0)} ${n(y0)}');
  for (var i = 1; i < points.length - 1; i++) {
    final (x, y) = points[i];
    final (nx, ny) = points[i + 1];
    b.write(' Q ${n(x)} ${n(y)} ${n((x + nx) / 2)} ${n((y + ny) / 2)}');
  }
  final (xl, yl) = points.last;
  b.write(' L ${n(xl)} ${n(yl)}');
  return b.toString();
}

/// Drops points closer than [minMm] to the previous one (finger jitter).
List<(double, double)> simplify(
  List<(double, double)> pts, {
  double minMm = 0.35,
}) {
  if (pts.length < 3) return pts;
  final out = [pts.first];
  for (final p in pts.skip(1)) {
    final (lx, ly) = out.last;
    final d = math.sqrt(math.pow(p.$1 - lx, 2) + math.pow(p.$2 - ly, 2));
    if (d >= minMm) out.add(p);
  }
  if (out.last != pts.last) out.add(pts.last);
  return out;
}

bool isDedication(Ornament o) => o.params[_kTag] == 1;

/// Replaces the dedication on the first page with [strokes] (empty removes
/// it).
Album applyDedication(Album album, List<InkStroke> strokes) {
  if (album.pages.isEmpty) return album;
  final area = dedicationArea(BookFormat.byId(album.formatId));
  final ink = [
    for (final s in strokes)
      if (s.isNotEmpty)
        Ornament(
          type: OrnamentType.path,
          params: const {_kTag: 1.0},
          path: inkPath(
            simplify([
              for (final (u, v) in s)
                (area.x + u * area.w, area.y + v * area.h),
            ]),
          ),
          color: kDedicationInk,
          strokePt: kDedicationStrokePt,
        ),
  ];
  final first = album.pages.first;
  return album.copyWith(
    pages: [
      first.copyWith(
        ornaments: [...first.ornaments.where((o) => !isDedication(o)), ...ink],
      ),
      ...album.pages.skip(1),
    ],
  );
}

bool hasDedication(Album album) =>
    album.pages.isNotEmpty && album.pages.first.ornaments.any(isDedication);

/// Carries the dedication of [before] over to [after] (re-layout, format
/// change), scaled into the new page's dedication area.
Album keepDedication(Album before, Album after) {
  if (!hasDedication(before) || after.pages.isEmpty) return after;
  final from = dedicationArea(BookFormat.byId(before.formatId));
  final to = dedicationArea(BookFormat.byId(after.formatId));
  final s = math.min(to.w / from.w, to.h / from.h);
  final dx = to.x + (to.w - from.w * s) / 2 - from.x * s;
  final dy = to.y + (to.h - from.h * s) / 2 - from.y * s;
  final ink = [
    for (final o in before.pages.first.ornaments.where(isDedication))
      o.copyWith(path: transformPath(o.path ?? '', s, dx, dy)),
  ];
  final first = after.pages.first;
  return after.copyWith(
    pages: [
      first.copyWith(
        ornaments: [...first.ornaments.where((o) => !isDedication(o)), ...ink],
      ),
      ...after.pages.skip(1),
    ],
  );
}
