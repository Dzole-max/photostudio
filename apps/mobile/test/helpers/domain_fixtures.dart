import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:memoria/domain/curation/curation.dart';
import 'package:memoria/domain/curation/image_stats.dart';
import 'package:memoria/domain/geo/geo_data.dart';
import 'package:memoria/domain/model/album.dart';
import 'package:memoria/domain/text/font_registry.dart';

/// Fonts, geo data and analysed sample photos, loaded once per test run.
class DomainFixtures {
  DomainFixtures._();

  static FontRegistry? _fonts;
  static GeoData? _geo;
  static final Map<String, Map<String, PhotoRef>> _samples = {};

  static FontRegistry get fonts => _fonts ??= FontRegistry({
    for (final f in Directory('assets/fonts').listSync().whereType<File>())
      if (f.path.endsWith('.ttf'))
        f.uri.pathSegments.last: Uint8List.fromList(f.readAsBytesSync()),
  });

  static GeoData get geo => _geo ??= GeoData.parse(
    worldJson: File('assets/geo/world.json').readAsStringSync(),
    islandsJson: File('assets/geo/islands.json').readAsStringSync(),
    placesJson: File('assets/geo/places.json').readAsStringSync(),
  );

  /// Sample set ("wedding" / "travel") analysed like the import pipeline
  /// does, then curated.
  static Map<String, PhotoRef> sample(String set) =>
      _samples.putIfAbsent(set, () {
        final manifest = jsonDecode(
          File('assets/samples/$set/manifest.json').readAsStringSync(),
        ) as Map<String, Object?>;
        final photos = <PhotoRef>[];
        for (final raw in manifest['photos']! as List<Object?>) {
          final m = raw! as Map<String, Object?>;
          final file = File((m['file']! as String));
          final stats = statsFromEncoded(file.readAsBytesSync())!;
          final lat = (m['lat'] as num?)?.toDouble();
          final lng = (m['lng'] as num?)?.toDouble();
          final place = lat == null || lng == null
              ? null
              : geo.nearestPlace(lat, lng);
          photos.add(
            PhotoRef(
              id: m['id']! as String,
              localAssetId: 'asset:${m['file']}',
              width: m['width']! as int,
              height: m['height']! as int,
              takenAt: DateTime.parse('${m['takenAt']}Z'),
              lat: lat,
              lng: lng,
              placeName: place?.nameIn('en'),
              placeId: place?.id,
              countryCode: place?.country,
              faces: [
                for (final f in m['faces']! as List<Object?>)
                  FaceBox.fromJson((f! as Map<String, Object?>)),
              ],
              labels: [
                for (final l in m['labels']! as List<Object?>)
                  PhotoLabel.fromJson((l! as Map<String, Object?>)),
              ],
              quality: QualityScore(
                exposure: stats.exposure,
                laplacian: stats.laplacian,
              ),
              hash: stats.hash,
              dominantHue: stats.dominantHue,
              focusX: stats.focusX,
              focusY: stats.focusY,
            ),
          );
        }
        return {for (final p in curate(photos).photos) p.id: p};
      });
}
