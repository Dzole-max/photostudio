import '../geo/geo_data.dart';
import '../geo/projection.dart';
import '../model/album.dart';
import '../model/geometry.dart';
import '../spec/book_strings.dart';
import '../art/icon_pack.dart';
import '../text/font_registry.dart';

class MapStop {
  const MapStop(this.name, this.lat, this.lng);

  final String name;
  final double lat;
  final double lng;
}

class MapDrawing {
  const MapDrawing(this.ornaments, this.texts);

  final List<Ornament> ornaments;
  final List<TextBlock> texts;
}

/// Flights longer than this are drawn dashed.
const double kFlightKm = 300;

/// Stops in chronological order from chapters that have coordinates;
/// consecutive duplicates are merged.
List<MapStop> stopsFromChapters(List<Chapter> chapters) {
  final out = <MapStop>[];
  for (final c in chapters) {
    if (c.lat == null || c.lng == null) continue;
    final name = c.placeName ?? c.title;
    if (out.isNotEmpty && out.last.name == name) continue;
    out.add(MapStop(name, c.lat!, c.lng!));
  }
  return out;
}

/// Route map (section 7.6): land outline 0.5 pt in text colour at 70 %,
/// route 1 pt in accent (dashed for flights > 300 km), dots and Manrope caps
/// labels, and a north tick.
MapDrawing composeRouteMap({
  required RectMm rect,
  required List<MapStop> stops,
  required GeoData geo,
  required String textColor,
  required String accent,
  required BookStrings strings,
  required FontRegistry fonts,
  String idPrefix = 'map',
}) {
  if (stops.isEmpty) return const MapDrawing([], []);
  final proj = FittedProjection.fit(
    [for (final s in stops) (s.lng, s.lat)],
    rect,
    minSpanDeg: 0.4,
  );
  final ornaments = <Ornament>[
    ..._landOutlines(geo, proj, rect, textColor, 0.7, 0.5),
  ];

  // Route.
  for (var i = 0; i + 1 < stops.length; i++) {
    final a = stops[i], b = stops[i + 1];
    final (ax, ay) = proj.project(a.lng, a.lat);
    final (bx, by) = proj.project(b.lng, b.lat);
    final km = haversineKm(a.lat, a.lng, b.lat, b.lng);
    final runs = clipPolyline([(ax, ay), (bx, by)], rect);
    if (runs.isEmpty) continue;
    ornaments.add(
      Ornament(
        type: OrnamentType.path,
        path: pathOf(runs),
        color: accent,
        strokePt: 1,
        dashMm: km > kFlightKm ? const [1.6, 1.2] : null,
      ),
    );
  }

  // Dots and labels.
  final texts = <TextBlock>[];
  final placed = <RectMm>[];
  final metrics = fonts.metrics('Manrope', 600);
  const labelPt = 8.0;
  for (var i = 0; i < stops.length; i++) {
    final s = stops[i];
    final (x, y) = proj.project(s.lng, s.lat);
    ornaments.add(
      Ornament(
        type: OrnamentType.circle,
        params: {'cx': x, 'cy': y, 'r': 1.1},
        color: accent,
        fill: true,
      ),
    );
    final label = s.name.toUpperCase();
    final wMm = ptToMm(metrics.widthPt(label, labelPt, trackingPct: 12)) + 0.5;
    const hMm = 3.6;
    // Try right, left, below, above; keep the first that fits and is free.
    final candidates = [
      RectMm(x: x + 2.2, y: y - hMm / 2, w: wMm, h: hMm),
      RectMm(x: x - 2.2 - wMm, y: y - hMm / 2, w: wMm, h: hMm),
      RectMm(x: x - wMm / 2, y: y + 2, w: wMm, h: hMm),
      RectMm(x: x - wMm / 2, y: y - 2 - hMm, w: wMm, h: hMm),
    ];
    final chosen = candidates.firstWhere(
      (c) => rect.containsRect(c) && !placed.any((p) => p.overlaps(c)),
      orElse: () => candidates.firstWhere(
        rect.containsRect,
        orElse: () => candidates.first,
      ),
    );
    placed.add(chosen);
    texts.add(
      TextBlock(
        id: '${idPrefix}_label_$i',
        role: TextRole.label,
        text: label,
        fontFamily: 'Manrope',
        sizePt: labelPt,
        weight: 600,
        color: textColor,
        trackingPct: 12,
        rectMm: chosen,
        align: chosen.x < x ? TextAlignKind.right : TextAlignKind.left,
        vAlign: VerticalAlignKind.middle,
        lineHeight: 1.2,
        maxLines: 1,
      ),
    );
  }

  // North tick in the top-right corner.
  final nx = rect.right - 4, ny = rect.y + 3;
  ornaments.add(
    Ornament(
      type: OrnamentType.line,
      params: {'x1': nx, 'y1': ny + 7, 'x2': nx, 'y2': ny + 1.5},
      color: textColor,
      opacity: 0.7,
      strokePt: 0.6,
    ),
  );
  texts.add(
    TextBlock(
      id: '${idPrefix}_north',
      role: TextRole.label,
      text: strings.north,
      fontFamily: 'Manrope',
      sizePt: 8,
      weight: 600,
      color: textColor,
      opacity: 0.7,
      rectMm: RectMm(x: nx - 4, y: ny - 3.5, w: 8, h: 4),
      align: TextAlignKind.center,
      vAlign: VerticalAlignKind.bottom,
      lineHeight: 1.1,
    ),
  );
  return MapDrawing(ornaments, texts);
}

/// Outline of the destination (island or country) around a point, used on
/// the map-stamp cover.
List<Ornament> destinationOutline({
  required RectMm rect,
  required double lat,
  required double lng,
  required GeoData geo,
  required String color,
}) {
  List<Ring> rings;
  final island = geo.islandAt(lng, lat);
  if (island != null) {
    rings = island.rings;
  } else {
    final country = geo.countryAt(lng, lat);
    rings = country?.rings ?? const [];
  }
  if (rings.isEmpty) return const [];
  // Fit to the largest rings' bounds so tiny outliers don't shrink the shape.
  final sorted = [...rings]..sort((a, b) => b.length.compareTo(a.length));
  final main = sorted.take(3).toList();
  final pts = <(double, double)>[];
  for (final r in main) {
    final b = GeoBounds.ofRing(r);
    pts.add((b.minLng, b.minLat));
    pts.add((b.maxLng, b.maxLat));
  }
  final proj = FittedProjection.fit(pts, rect, padding: 0.06, minSpanDeg: 0.05);
  return [
    for (final r in rings)
      if (_projectRing(r, proj, rect) case final runs when runs.isNotEmpty)
        Ornament(
          type: OrnamentType.path,
          path: pathOf(runs),
          color: color,
          strokePt: 0.6,
        ),
  ];
}

List<Ornament> _landOutlines(
  GeoData geo,
  FittedProjection proj,
  RectMm rect,
  String color,
  double opacity,
  double strokePt,
) {
  final out = <Ornament>[];
  final buffer = StringBuffer();
  for (final ring in geo.ringsFor(proj.view)) {
    final runs = _projectRing(ring, proj, rect);
    if (runs.isEmpty) continue;
    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write(pathOf(runs));
  }
  if (buffer.isNotEmpty) {
    out.add(
      Ornament(
        type: OrnamentType.path,
        path: buffer.toString(),
        color: color,
        opacity: opacity,
        strokePt: strokePt,
      ),
    );
  }
  return out;
}

List<List<(double, double)>> _projectRing(
  Ring r,
  FittedProjection proj,
  RectMm rect,
) {
  final pts = <(double, double)>[
    for (var i = 0; i < r.length; i += 2) proj.project(r[i], r[i + 1]),
  ];
  if (pts.isNotEmpty) pts.add(pts.first);
  return clipPolyline(pts, rect);
}

/// Cover map (Cover Studio "Map" variant): the destination's outline fitted
/// to [rect], the route through [stops] with a line-art icon at each place,
/// or — with a single place — a heart marker (weddings).
MapDrawing composeCoverMap({
  required RectMm rect,
  required double lat,
  required double lng,
  required List<MapStop> stops,
  required GeoData geo,
  required String lineColor,
  required String accent,
  required FontRegistry fonts,
  List<String> icons = const [],
  bool heart = false,
}) {
  List<Ring> rings;
  final island = geo.islandAt(lng, lat);
  if (island != null) {
    rings = island.rings;
  } else {
    rings = geo.countryAt(lng, lat)?.rings ?? const [];
  }
  // Fit to the land the route is on (not every island in the archipelago).
  final near = stops.isEmpty
      ? rings
      : rings.where((r) {
          final b = GeoBounds.ofRing(r);
          final grown = GeoBounds(
            b.minLng - 0.08,
            b.minLat - 0.08,
            b.maxLng + 0.08,
            b.maxLat + 0.08,
          );
          return stops.any((s) => grown.contains(s.lng, s.lat));
        }).toList();
  final fitRings = near.isEmpty ? rings : near;
  final sorted = [...fitRings]..sort((a, b) => b.length.compareTo(a.length));
  final pts = <(double, double)>[
    for (final r in sorted.take(3)) ...[
      (GeoBounds.ofRing(r).minLng, GeoBounds.ofRing(r).minLat),
      (GeoBounds.ofRing(r).maxLng, GeoBounds.ofRing(r).maxLat),
    ],
    for (final s in stops) (s.lng, s.lat),
    if (stops.isEmpty) (lng, lat),
  ];
  final proj = FittedProjection.fit(pts, rect, padding: 0.08, minSpanDeg: 0.05);
  final ornaments = <Ornament>[
    for (final r in rings)
      if (_projectRing(r, proj, rect) case final runs when runs.isNotEmpty)
        Ornament(
          type: OrnamentType.path,
          path: pathOf(runs),
          color: lineColor,
          strokePt: 0.7,
        ),
  ];
  final texts = <TextBlock>[];
  final metrics = fonts.metrics('Manrope', 600);
  if (heart || stops.isEmpty) {
    final (x, y) = proj.project(lng, lat);
    ornaments.add(
      iconOrnament(
        'heart',
        x,
        y - 3,
        7,
        accent,
        strokePt: 0.9,
      ).copyWith(fill: true, opacity: 0.9),
    );
    return MapDrawing(ornaments, texts);
  }
  for (var i = 0; i + 1 < stops.length; i++) {
    final (ax, ay) = proj.project(stops[i].lng, stops[i].lat);
    final (bx, by) = proj.project(stops[i + 1].lng, stops[i + 1].lat);
    // A gentle arc reads as a hand-drawn route.
    final mx = (ax + bx) / 2 - (by - ay) * 0.18,
        my = (ay + by) / 2 + (bx - ax) * 0.18;
    ornaments.add(
      Ornament(
        type: OrnamentType.path,
        path:
            'M${ax.toStringAsFixed(2)} ${ay.toStringAsFixed(2)} Q${mx.toStringAsFixed(2)} ${my.toStringAsFixed(2)} ${bx.toStringAsFixed(2)} ${by.toStringAsFixed(2)}',
        color: accent,
        strokePt: 1,
        dashMm: const [1.8, 1.2],
      ),
    );
  }
  for (var i = 0; i < stops.length; i++) {
    final s = stops[i];
    final (x, y) = proj.project(s.lng, s.lat);
    ornaments.add(
      Ornament(
        type: OrnamentType.circle,
        params: {'cx': x, 'cy': y, 'r': 1.2},
        color: accent,
        fill: true,
      ),
    );
    final icon = i < icons.length ? icons[i] : 'compass';
    final leftSide = x > rect.cx;
    final iconX = (leftSide ? x - 9 : x + 9)
        .clamp(rect.x + 5, rect.right - 5)
        .toDouble();
    ornaments.add(iconOrnament(icon, iconX, y - 7, 9, lineColor));
    final label = s.name.toUpperCase();
    final wMm = ptToMm(metrics.widthPt(label, 8, trackingPct: 12)) + 0.5;
    final lx = (leftSide ? x - 2.5 - wMm : x + 2.5)
        .clamp(rect.x, rect.right - wMm)
        .toDouble();
    texts.add(
      TextBlock(
        id: 'cover_map_label_$i',
        role: TextRole.label,
        text: label,
        fontFamily: 'Manrope',
        sizePt: 8,
        weight: 600,
        color: lineColor,
        trackingPct: 12,
        rectMm: RectMm(x: lx, y: y + 1.5, w: wMm, h: 3.6),
        align: leftSide ? TextAlignKind.right : TextAlignKind.left,
        lineHeight: 1.2,
        maxLines: 1,
      ),
    );
  }
  return MapDrawing(ornaments, texts);
}
