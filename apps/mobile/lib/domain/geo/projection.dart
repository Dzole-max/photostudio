import 'dart:math' as math;

import '../model/geometry.dart';
import 'geo_data.dart';

/// Equirectangular projection fitted to a bounding box plus padding, into a
/// rectangle in mm. Same maths in services/render/src/geo/projection.ts,
/// checked against packages/layout_spec/fixtures/projection.json.
class FittedProjection {
  FittedProjection._(this.rect, this._lng0, this._lat0, this._scale, this._k);

  /// Fits [points] (lng, lat) into [rect] with [padding] (fraction of the
  /// span on each side) and a minimum span of [minSpanDeg] degrees.
  factory FittedProjection.fit(
    List<(double, double)> points,
    RectMm rect, {
    double padding = 0.2,
    double minSpanDeg = 0.25,
  }) {
    var x0 = double.infinity, y0 = double.infinity;
    var x1 = -double.infinity, y1 = -double.infinity;
    for (final (lng, lat) in points) {
      x0 = math.min(x0, lng);
      x1 = math.max(x1, lng);
      y0 = math.min(y0, lat);
      y1 = math.max(y1, lat);
    }
    final cLat = (y0 + y1) / 2;
    final k = math.cos(cLat * math.pi / 180);
    // Work in projected units (lng scaled by cos(lat0)).
    var spanX = math.max((x1 - x0) * k, minSpanDeg * k);
    var spanY = math.max(y1 - y0, minSpanDeg);
    spanX *= 1 + 2 * padding;
    spanY *= 1 + 2 * padding;
    // Match the rect aspect by growing the tighter axis.
    final aspect = rect.w / rect.h;
    if (spanX / spanY < aspect) {
      spanX = spanY * aspect;
    } else {
      spanY = spanX / aspect;
    }
    final cx = (x0 + x1) / 2;
    final scale = rect.w / spanX; // mm per projected degree
    final lng0 = cx - spanX / 2 / k;
    final lat0 = cLat + spanY / 2;
    return FittedProjection._(rect, lng0, lat0, scale, k);
  }

  final RectMm rect;
  final double _lng0;
  final double _lat0;
  final double _scale;
  final double _k;

  (double, double) project(double lng, double lat) =>
      (rect.x + (lng - _lng0) * _k * _scale, rect.y + (_lat0 - lat) * _scale);

  /// Geographic bounds visible in [rect].
  GeoBounds get view {
    final spanLng = rect.w / _scale / _k;
    final spanLat = rect.h / _scale;
    return GeoBounds(_lng0, _lat0 - spanLat, _lng0 + spanLng, _lat0);
  }
}

/// Cohen–Sutherland clip of a polyline to [r]; returns the visible runs.
List<List<(double, double)>> clipPolyline(
  List<(double, double)> pts,
  RectMm r,
) {
  int code(double x, double y) =>
      (x < r.x ? 1 : 0) |
      (x > r.right ? 2 : 0) |
      (y < r.y ? 4 : 0) |
      (y > r.bottom ? 8 : 0);

  final runs = <List<(double, double)>>[];
  List<(double, double)>? run;
  for (var i = 0; i + 1 < pts.length; i++) {
    var (ax, ay) = pts[i];
    var (bx, by) = pts[i + 1];
    var ca = code(ax, ay), cb = code(bx, by);
    var accept = false;
    var clippedStart = false;
    var clippedEnd = false;
    while (true) {
      if ((ca | cb) == 0) {
        accept = true;
        break;
      }
      if ((ca & cb) != 0) break;
      final out = ca != 0 ? ca : cb;
      double x, y;
      if (out & 8 != 0) {
        x = ax + (bx - ax) * (r.bottom - ay) / (by - ay);
        y = r.bottom;
      } else if (out & 4 != 0) {
        x = ax + (bx - ax) * (r.y - ay) / (by - ay);
        y = r.y;
      } else if (out & 2 != 0) {
        y = ay + (by - ay) * (r.right - ax) / (bx - ax);
        x = r.right;
      } else {
        y = ay + (by - ay) * (r.x - ax) / (bx - ax);
        x = r.x;
      }
      if (out == ca) {
        ax = x;
        ay = y;
        ca = code(ax, ay);
        clippedStart = true;
      } else {
        bx = x;
        by = y;
        cb = code(bx, by);
        clippedEnd = true;
      }
    }
    if (!accept) {
      if (run != null) runs.add(run);
      run = null;
      continue;
    }
    if (run == null || clippedStart) {
      if (run != null) runs.add(run);
      run = [(ax, ay)];
    }
    run.add((bx, by));
    if (clippedEnd) {
      runs.add(run);
      run = null;
    }
  }
  if (run != null) runs.add(run);
  return runs.where((r) => r.length >= 2).toList();
}

String _n(double v) => v.toStringAsFixed(2);

/// SVG path data ("M x y L x y ...") for polyline runs, in mm.
String pathOf(List<List<(double, double)>> runs, {bool close = false}) {
  final b = StringBuffer();
  for (final run in runs) {
    for (var i = 0; i < run.length; i++) {
      final (x, y) = run[i];
      b.write('${i == 0 ? 'M' : 'L'}${_n(x)} ${_n(y)} ');
    }
    if (close) b.write('Z ');
  }
  return b.toString().trim();
}
