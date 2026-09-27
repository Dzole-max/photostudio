import '../geo/geo_data.dart';
import '../layout/layout_engine.dart';
import '../model/album.dart';
import '../spec/book_strings.dart';
import '../theme/book_theme.dart';
import '../theme/theme_tinter.dart';

/// The four Cover Studio variants (section 2 of the product brief).
enum CoverVariantKind { photo, monogram, map, illustrated }

/// One cover option: template, accent and the art it needs.
class CoverVariant {
  const CoverVariant({
    required this.kind,
    required this.templateId,
    required this.accent,
    required this.heroId,
    this.artwork,
  });

  final CoverVariantKind kind;
  final String templateId;
  final String accent;

  /// Photo shown on the cover (the artwork for the illustrated variant).
  final String? heroId;

  /// Generated illustration for [CoverVariantKind.illustrated].
  final PhotoRef? artwork;

  CoverVariant withArtwork(PhotoRef art, String accent) => CoverVariant(
    kind: kind,
    templateId: templateId,
    accent: accent,
    heroId: art.id,
    artwork: art,
  );
}

/// Template per variant kind and occasion.
String coverTemplateFor(CoverVariantKind kind, Occasion o) => switch ((
  kind,
  o,
)) {
  (CoverVariantKind.photo, Occasion.wedding) => 'cover_wedding_fullbleed',
  (CoverVariantKind.photo, Occasion.baby) => 'cover_baby_cloud',
  (CoverVariantKind.photo, _) => 'cover_travel_coordinates',
  (CoverVariantKind.monogram, Occasion.wedding) => 'cover_wedding_monogram',
  (CoverVariantKind.monogram, Occasion.travel) => 'cover_travel_stamp',
  (CoverVariantKind.monogram, Occasion.birthday) => 'cover_birthday_confetti',
  (CoverVariantKind.monogram, _) => 'cover_year_grid',
  (CoverVariantKind.map, _) => 'cover_map',
  (CoverVariantKind.illustrated, _) => 'cover_illustrated',
};

/// Printed "gold" (section 6.2) — always called gold tone in the UI.
const String kGoldTone = '#B8955A';

/// The photo each variant is built around.
PhotoRef? variantSource(
  CoverVariantKind kind,
  List<PhotoRef> photos,
  Occasion o,
  double coverAspect,
  double coverWidthMm,
) {
  if (photos.isEmpty) return null;
  if (kind == CoverVariantKind.illustrated && o == Occasion.wedding) {
    // The couple: the best portrait with two faces.
    final couples = photos.where((p) => p.faces.length == 2).toList()
      ..sort((a, b) {
        double size(PhotoRef p) => p.faces.fold(0, (s, f) => s + f.w * f.h);
        return (size(b) + b.quality.overall).compareTo(
          size(a) + a.quality.overall,
        );
      });
    if (couples.isNotEmpty) return couples.first;
  }
  return pickCoverHero(
    photos,
    o,
    coverAspect: coverAspect,
    coverWidthMm: coverWidthMm,
  );
}

/// Variants for a book (Map only when photos are geotagged). The
/// illustrated variant starts without artwork; the CoverArtProvider fills
/// it in (in parallel with the others being shown).
List<CoverVariant> coverVariants({
  required Occasion occasion,
  required BookTheme theme,
  required List<PhotoRef> photos,
  required double coverAspect,
  required double coverWidthMm,
}) {
  final geotagged = photos.any((p) => p.lat != null && p.lng != null);
  final out = <CoverVariant>[];
  String? photoHero;
  for (final kind in CoverVariantKind.values) {
    if (kind == CoverVariantKind.map && !geotagged) continue;
    var hero = variantSource(kind, photos, occasion, coverAspect, coverWidthMm);
    if (kind == CoverVariantKind.photo) photoHero = hero?.id;
    if (kind == CoverVariantKind.illustrated && hero?.id == photoHero) {
      // A different photo than the Photo cover, so the two don't look alike.
      final others = photos.where((p) => p.id != photoHero).toList();
      hero =
          variantSource(kind, others, occasion, coverAspect, coverWidthMm) ??
          hero;
    }
    final accent = switch (kind) {
      CoverVariantKind.monogram when occasion == Occasion.wedding => kGoldTone,
      CoverVariantKind.monogram when occasion == Occasion.travel => '#B5522E',
      CoverVariantKind.map => theme.accent,
      _ => const ThemeTinter().tint(theme.accent, hero?.dominantHue),
    };
    out.add(
      CoverVariant(
        kind: kind,
        templateId: coverTemplateFor(kind, occasion),
        accent: accent,
        heroId: hero?.id,
      ),
    );
  }
  return out;
}

/// Shared, user-editable text on every variant.
CoverSlots studioSlots({
  required Occasion occasion,
  required StoryAnswers story,
  required List<PhotoRef> photos,
  required BookStrings strings,
  GeoData? geo,
  String? destination,
}) {
  final dates = photos.map((p) => p.takenAt).whereType<DateTime>().toList()
    ..sort();
  final start = story.eventDate ?? (dates.isEmpty ? null : dates.first);
  final geotagged = photos
      .where((p) => p.lat != null && p.lng != null)
      .toList();
  double? lat, lng;
  if (geotagged.isNotEmpty) {
    lat =
        geotagged.map((p) => p.lat!).reduce((a, b) => a + b) / geotagged.length;
    lng =
        geotagged.map((p) => p.lng!).reduce((a, b) => a + b) / geotagged.length;
  }
  final names = story.names?.trim();
  String? monogram;
  if (names != null && names.isNotEmpty) {
    final parts = names
        .split(
          RegExp(
            r'\s*[&+]\s*|\s+(?:and|und|y|et|e|и)\s+',
            caseSensitive: false,
          ),
        )
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      monogram =
          '${parts[0].trim().substring(0, 1).toUpperCase()} & ${parts[1].trim().substring(0, 1).toUpperCase()}';
    }
  }
  final title = switch (occasion) {
    Occasion.wedding => names?.isNotEmpty == true ? names! : strings.ourWedding,
    Occasion.travel => (story.title ?? destination ?? '').replaceAll(
      RegExp(r'\s*\d{4}$'),
      '',
    ),
    Occasion.family =>
      story.title ?? strings.ourYear(start?.year ?? DateTime.now().year),
    _ => story.title ?? names ?? destination ?? '',
  };
  final country = lat == null || geo == null
      ? null
      : geo.countryAt(lng!, lat)?.name;
  final best = [...photos]
    ..sort((a, b) => b.quality.overall.compareTo(a.quality.overall));
  return CoverSlots(
    title: title,
    names: names,
    monogram: monogram,
    date: start == null
        ? null
        : (occasion == Occasion.travel
              ? strings.monthYearTitle(start)
              : strings.dateLong(start)),
    location: story.place ?? destination,
    coordinates: lat == null ? null : strings.coordinates(lat, lng!),
    photoIds: best.take(9).map((p) => p.id).toList(),
    age: start == null ? null : '${start.year}',
    details: country,
    lat: lat,
    lng: lng,
  );
}
