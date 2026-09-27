import 'dart:convert';
import 'dart:math' as math;

/// A closed ring as flattened [lng, lat, lng, lat, ...].
typedef Ring = List<double>;

class GeoBounds {
  const GeoBounds(this.minLng, this.minLat, this.maxLng, this.maxLat);

  factory GeoBounds.ofRing(Ring r) {
    var x0 = double.infinity, y0 = double.infinity;
    var x1 = -double.infinity, y1 = -double.infinity;
    for (var i = 0; i < r.length; i += 2) {
      x0 = math.min(x0, r[i]);
      x1 = math.max(x1, r[i]);
      y0 = math.min(y0, r[i + 1]);
      y1 = math.max(y1, r[i + 1]);
    }
    return GeoBounds(x0, y0, x1, y1);
  }

  final double minLng;
  final double minLat;
  final double maxLng;
  final double maxLat;

  double get spanLng => maxLng - minLng;
  double get spanLat => maxLat - minLat;
  double get centerLng => (minLng + maxLng) / 2;
  double get centerLat => (minLat + maxLat) / 2;

  bool contains(double lng, double lat) =>
      lng >= minLng && lng <= maxLng && lat >= minLat && lat <= maxLat;

  bool containsBounds(GeoBounds o) =>
      o.minLng >= minLng &&
      o.maxLng <= maxLng &&
      o.minLat >= minLat &&
      o.maxLat <= maxLat;

  bool intersects(GeoBounds o) =>
      minLng <= o.maxLng &&
      o.minLng <= maxLng &&
      minLat <= o.maxLat &&
      o.minLat <= maxLat;

  GeoBounds union(GeoBounds o) => GeoBounds(
    math.min(minLng, o.minLng),
    math.min(minLat, o.minLat),
    math.max(maxLng, o.maxLng),
    math.max(maxLat, o.maxLat),
  );
}

class GeoCountry {
  GeoCountry(this.iso, this.name, this.rings)
    : bounds = rings
          .map(GeoBounds.ofRing)
          .fold<GeoBounds?>(null, (a, b) => a == null ? b : a.union(b));

  final String iso;
  final String name;
  final List<Ring> rings;
  final GeoBounds? bounds;

  bool containsPoint(double lng, double lat) =>
      rings.any((r) => pointInRing(r, lng, lat));
}

class GeoIsland {
  GeoIsland(this.key, this.box, this.rings, {this.names = const {}});

  final String key;
  final GeoBounds box;
  final List<Ring> rings;
  final Map<String, String> names;

  String nameIn(String lang) => names[lang] ?? names['en'] ?? key;
}

class GeoPlace {
  const GeoPlace({
    required this.id,
    required this.lng,
    required this.lat,
    required this.country,
    required this.names,
  });

  final String id;
  final double lng;
  final double lat;
  final String country;
  final Map<String, String> names;

  String nameIn(String lang) => names[lang] ?? names['en']!;
}

/// Natural Earth outlines + curated islands + the 200-place gazetteer
/// (assets/geo, built by tools/geo/build_geo.py).
class GeoData {
  GeoData({
    required this.countries,
    required this.islands,
    required this.places,
  });

  factory GeoData.parse({
    required String worldJson,
    required String islandsJson,
    required String placesJson,
  }) {
    List<Ring> rings(Object? raw) => [
      for (final r in raw! as List<Object?>)
        [for (final v in r! as List<Object?>) (v! as num).toDouble()],
    ];
    final world = jsonDecode(worldJson) as Map<String, Object?>;
    final isl = jsonDecode(islandsJson) as Map<String, Object?>;
    final pl = jsonDecode(placesJson) as Map<String, Object?>;
    return GeoData(
      countries: [
        for (final c in world['countries']! as List<Object?>)
          if (c case {
            'iso': final String iso,
            'name': final String name,
            'rings': final Object r,
          })
            GeoCountry(iso, name, rings(r)),
      ],
      islands: [
        for (final i in isl['islands']! as List<Object?>)
          if (i case {
            'key': final String key,
            'names': final Map<String, Object?> names,
            'bbox': final List<Object?> b,
            'rings': final Object r,
          })
            GeoIsland(
              names: names.map((k, v) => MapEntry(k, v! as String)),
              key,
              GeoBounds(
                (b[0]! as num).toDouble(),
                (b[1]! as num).toDouble(),
                (b[2]! as num).toDouble(),
                (b[3]! as num).toDouble(),
              ),
              rings(r),
            ),
      ],
      places: [
        for (final p in pl['places']! as List<Object?>)
          if (p case {
            'id': final String id,
            'lng': final num lng,
            'lat': final num lat,
            'country': final String country,
            'names': final Map<String, Object?> names,
          })
            GeoPlace(
              id: id,
              lng: lng.toDouble(),
              lat: lat.toDouble(),
              country: country,
              names: names.map((k, v) => MapEntry(k, v! as String)),
            ),
      ],
    );
  }

  final List<GeoCountry> countries;
  final List<GeoIsland> islands;
  final List<GeoPlace> places;

  GeoCountry? countryAt(double lng, double lat) {
    for (final c in countries) {
      final b = c.bounds;
      if (b != null && b.contains(lng, lat) && c.containsPoint(lng, lat)) {
        return c;
      }
    }
    return null;
  }

  GeoIsland? islandAt(double lng, double lat) {
    for (final i in islands) {
      if (i.box.contains(lng, lat)) return i;
    }
    return null;
  }

  /// Nearest gazetteer place within [maxKm], used by the fake geocoder.
  GeoPlace? nearestPlace(double lat, double lng, {double maxKm = 60}) {
    GeoPlace? best;
    var bestKm = maxKm;
    for (final p in places) {
      final d = haversineKm(lat, lng, p.lat, p.lng);
      if (d < bestKm) {
        bestKm = d;
        best = p;
      }
    }
    return best;
  }

  /// Outline rings to draw for a map covering [view]. Uses 1:10m island
  /// detail where available and drops coarse country rings it replaces.
  List<Ring> ringsFor(GeoBounds view) {
    final detailed = islands.where((i) => i.box.intersects(view)).toList();
    final out = <Ring>[];
    for (final i in detailed) {
      out.addAll(i.rings.where((r) => GeoBounds.ofRing(r).intersects(view)));
    }
    for (final c in countries) {
      final b = c.bounds;
      if (b == null || !b.intersects(view)) continue;
      for (final r in c.rings) {
        final rb = GeoBounds.ofRing(r);
        if (!rb.intersects(view)) continue;
        if (detailed.any((i) => i.box.containsBounds(rb))) continue;
        out.add(r);
      }
    }
    return out;
  }
}

bool pointInRing(Ring r, double x, double y) {
  var inside = false;
  final n = r.length ~/ 2;
  for (var i = 0, j = n - 1; i < n; j = i++) {
    final xi = r[i * 2], yi = r[i * 2 + 1];
    final xj = r[j * 2], yj = r[j * 2 + 1];
    if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
      inside = !inside;
    }
  }
  return inside;
}

double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(a)));
}
