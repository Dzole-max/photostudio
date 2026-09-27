import '../../domain/geo/geo_data.dart';
import '../db/app_database.dart';

class GeoResult {
  const GeoResult({
    required this.placeName,
    required this.countryCode,
    required this.countryName,
    this.placeId,
  });

  final String placeName;
  final String? placeId;
  final String countryCode;
  final String countryName;
}

/// Reverse geocoding, behind the `geo-lookup` edge function in production.
abstract interface class ReverseGeocoder {
  Future<GeoResult?> lookup(double lat, double lng);
}

/// Offline: nearest place of the bundled 200-place gazetteer, else country.
class FakeGeocoder implements ReverseGeocoder {
  FakeGeocoder(this.geo);

  final GeoData geo;

  @override
  Future<GeoResult?> lookup(double lat, double lng) async {
    final place = geo.nearestPlace(lat, lng);
    final country = geo.countryAt(lng, lat);
    if (place != null) {
      return GeoResult(
        placeName: place.nameIn('en'),
        placeId: place.id,
        countryCode: place.country,
        countryName: country?.name ?? place.country,
      );
    }
    if (country != null) {
      return GeoResult(
        placeName: country.name,
        countryCode: country.iso,
        countryName: country.name,
      );
    }
    return null;
  }
}

/// Batches lookups by 0.01° cell and caches them in Drift (section 7.3 step 8).
class CachedGeocoder implements ReverseGeocoder {
  CachedGeocoder(this.inner, this.db);

  final ReverseGeocoder inner;
  final AppDatabase db;
  final Map<String, GeoResult?> _memory = {};

  static String cellKey(double lat, double lng) =>
      '${(lat * 100).round() / 100},${(lng * 100).round() / 100}';

  @override
  Future<GeoResult?> lookup(double lat, double lng) async {
    final key = cellKey(lat, lng);
    if (_memory.containsKey(key)) return _memory[key];
    final row = await (db.select(
      db.geocodeCache,
    )..where((c) => c.cellKey.equals(key))).getSingleOrNull();
    if (row != null) {
      // Stored as "name|placeId" when the place is in the gazetteer.
      final parts = row.placeName.split('|');
      return _memory[key] = GeoResult(
        placeName: parts.first,
        placeId: parts.length > 1 ? parts[1] : null,
        countryCode: row.countryCode,
        countryName: row.countryName,
      );
    }
    final result = await inner.lookup(
      (lat * 100).round() / 100,
      (lng * 100).round() / 100,
    );
    _memory[key] = result;
    if (result != null) {
      await db
          .into(db.geocodeCache)
          .insertOnConflictUpdate(
            GeocodeCacheCompanion.insert(
              cellKey: key,
              placeName: result.placeId == null
                  ? result.placeName
                  : '${result.placeName}|${result.placeId}',
              countryCode: result.countryCode,
              countryName: result.countryName,
            ),
          );
    }
    return result;
  }
}
