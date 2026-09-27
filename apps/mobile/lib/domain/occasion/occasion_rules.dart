import '../geo/geo_data.dart';
import '../model/album.dart';

const _weddingLabels = {
  'wedding',
  'bride',
  'veil',
  'bouquet',
  'suit',
  'gown',
  'cake',
  'ceremony',
};
const _formalLabels = {'suit', 'gown', 'dress', 'tuxedo'};
const _babyLabels = {'baby', 'infant', 'toddler', 'newborn'};
const _birthdayLabels = {'cake', 'candle', 'balloon', 'birthday'};

class OccasionSuggestion {
  const OccasionSuggestion({
    required this.occasion,
    required this.fromRules,
    this.destination,
    this.alternatives = const [],
  });

  final Occasion occasion;

  /// False when rules were inconclusive and the AI provider must decide.
  final bool fromRules;

  /// "Zanzibar" for "Looks like a trip to Zanzibar — right?".
  final String? destination;
  final List<Occasion> alternatives;
}

double _share(
  List<PhotoRef> photos,
  Set<String> labels, {
  double minConfidence = 0.6,
}) {
  if (photos.isEmpty) return 0;
  return photos
          .where((p) => p.hasLabel(labels, minConfidence: minConfidence))
          .length /
      photos.length;
}

DateTime _day(DateTime t) => DateTime.utc(t.year, t.month, t.day);

/// Rule-based occasion detection (section 7.4). [home] is the user's usual
/// location if known (e.g. from recent library photos).
OccasionSuggestion detectOccasion(
  List<PhotoRef> photos, {
  GeoData? geo,
  (double, double)? home,
  String language = 'en',
}) {
  final dated = photos.map((p) => p.takenAt).whereType<DateTime>().toList()
    ..sort();
  final days = dated.map(_day).toSet();
  final spanDays = dated.isEmpty
      ? 0
      : dated.last.difference(dated.first).inDays;
  final totalFaces = photos.fold<int>(0, (a, p) => a + p.faces.length);
  final geotagged = photos
      .where((p) => p.lat != null && p.lng != null)
      .toList();

  // Distinct gazetteer places among geotagged photos.
  final places = <String>{};
  for (final p in geotagged) {
    final id =
        p.placeId ?? geo?.nearestPlace(p.lat!, p.lng!)?.id ?? p.placeName;
    if (id != null) places.add(id);
  }

  final destination = _destination(geotagged, geo, language);
  List<Occasion> alts(Occasion o) => [
    for (final x in [
      Occasion.travel,
      Occasion.wedding,
      Occasion.family,
      Occasion.birthday,
      Occasion.baby,
      Occasion.other,
    ])
      if (x != o) x,
  ].take(3).toList();

  final weddingByLabels = _share(photos, _weddingLabels) >= 0.08;
  final weddingByFaces =
      days.length == 1 && totalFaces >= 30 && _share(photos, _formalLabels) > 0;
  if (weddingByLabels || weddingByFaces) {
    return OccasionSuggestion(
      occasion: Occasion.wedding,
      fromRules: true,
      destination: destination,
      alternatives: alts(Occasion.wedding),
    );
  }
  if (_share(photos, _babyLabels, minConfidence: 0.5) >= 0.15) {
    return OccasionSuggestion(
      occasion: Occasion.baby,
      fromRules: true,
      alternatives: alts(Occasion.baby),
    );
  }
  if (days.length <= 2 && _share(photos, _birthdayLabels) >= 0.08) {
    return OccasionSuggestion(
      occasion: Occasion.birthday,
      fromRules: true,
      alternatives: alts(Occasion.birthday),
    );
  }
  if (spanDays >= 180) {
    return OccasionSuggestion(
      occasion: Occasion.family,
      fromRules: true,
      alternatives: alts(Occasion.family),
    );
  }
  var travel = days.length >= 2 && places.length >= 2;
  if (!travel && home != null && geotagged.isNotEmpty) {
    final far = geotagged
        .where((p) => haversineKm(p.lat!, p.lng!, home.$1, home.$2) > 100)
        .length;
    travel = far / geotagged.length >= 0.6;
  }
  if (travel) {
    return OccasionSuggestion(
      occasion: Occasion.travel,
      fromRules: true,
      destination: destination,
      alternatives: alts(Occasion.travel),
    );
  }
  return OccasionSuggestion(
    occasion: Occasion.other,
    fromRules: false,
    destination: destination,
    alternatives: alts(Occasion.other),
  );
}

/// Island, else country, else the most common place among the photos.
String? _destination(List<PhotoRef> geotagged, GeoData? geo, String lang) {
  if (geotagged.isEmpty || geo == null) return null;
  final lat =
      geotagged.map((p) => p.lat!).reduce((a, b) => a + b) / geotagged.length;
  final lng =
      geotagged.map((p) => p.lng!).reduce((a, b) => a + b) / geotagged.length;
  final island = geo.islandAt(lng, lat);
  if (island != null) return island.nameIn(lang);
  final counts = <String, int>{};
  for (final p in geotagged) {
    final name = p.placeName;
    if (name != null) counts[name] = (counts[name] ?? 0) + 1;
  }
  if (counts.isNotEmpty) {
    final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    if (top.value >= geotagged.length * 0.6) return top.key;
  }
  return geo.countryAt(lng, lat)?.name;
}
