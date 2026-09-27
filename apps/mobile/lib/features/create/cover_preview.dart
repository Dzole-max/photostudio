import '../../app_config.dart';
import '../../data/domain_kit.dart';
import '../../domain/cover/cover_studio.dart';
import '../../domain/layout/chapters.dart';
import '../../domain/layout/cover_composer.dart';
import '../../domain/layout/layout_engine.dart';
import '../../domain/layout/page_composer.dart';
import '../../domain/model/album.dart';
import '../../domain/spec/book_format.dart';
import '../../domain/spec/book_strings.dart';
import '../../domain/spec/spec_data.dart';
import '../../domain/theme/book_theme.dart';
import '../../domain/theme/theme_tinter.dart';
import 'creation_controller.dart';

/// A cover-only album used for the theme cards on the occasion screen:
/// the real cover template filled with the user's own photos.
Album previewAlbum(
  CreationState state,
  DomainKit kit,
  String themeId,
  String language,
) {
  final occasion = state.occasion ?? Occasion.other;
  final theme = BookTheme.byId(themeId);
  final format = BookFormat.byId(
    occasion == Occasion.travel ? kTravelDefaultFormatId : kDefaultFormatId,
  );
  final strings = BookStrings(language);
  final photos = {for (final p in state.photos) p.id: p};
  final included = state.included;
  final hero = pickCoverHero(
    included,
    occasion,
    coverAspect: format.aspect,
    coverWidthMm: format.trimWMm,
  );
  final story = state.story;
  final dates = included.map((p) => p.takenAt).whereType<DateTime>().toList()
    ..sort();
  final start = story.eventDate ?? (dates.isEmpty ? null : dates.first);
  final title = switch (occasion) {
    Occasion.wedding => story.names ?? strings.ourWedding,
    Occasion.travel =>
      (story.title ?? state.suggestion?.destination ?? '').replaceAll(
        RegExp(r'\s*\d{4}$'),
        '',
      ),
    Occasion.family => strings.ourYear(start?.year ?? DateTime.now().year),
    _ => story.names ?? story.title ?? '',
  };
  final names = story.names;
  String? monogram;
  if (names != null) {
    final parts = names
        .split(RegExp(r'\s*[&+]\s*|\s+(?:and|und|y|et|e|и)\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      monogram = '${parts[0][0].toUpperCase()} & ${parts[1][0].toUpperCase()}';
    }
  }
  final best = [...included]
    ..sort((a, b) => b.quality.overall.compareTo(a.quality.overall));
  final slots = CoverSlots(
    title: title,
    names: names,
    monogram: monogram,
    date: start == null
        ? null
        : (occasion == Occasion.travel
              ? strings.monthYearTitle(start)
              : strings.dateLong(start)),
    location: story.place ?? state.suggestion?.destination,
    heroPhotoId: hero?.id,
    photoIds: best.take(9).map((p) => p.id).toList(),
    age: start == null ? null : '${start.year}',
  );
  final accent = const ThemeTinter().tint(theme.accent, hero?.dominantHue);
  final plans = planChapters(photos, occasion, strings);
  final env = ComposeEnv(
    format: format,
    theme: theme,
    accent: accent,
    strings: strings,
    fonts: kit.fonts,
    photos: photos,
    chapters: [for (final p in plans) p.chapter],
    geo: kit.geo,
  );
  final cover = composeCover(
    templateId: theme.defaultCover,
    slots: slots,
    env: env,
    spineMm: fakeSpineMm(30),
    backMark: AppConfig.brandName.toUpperCase(),
  );
  final now = DateTime.now().toUtc();
  return Album(
    id: 'preview_$themeId',
    title: title,
    occasion: occasion,
    themeId: themeId,
    formatId: format.id,
    language: language,
    createdAt: now,
    updatedAt: now,
    accentColor: accent,
    cover: cover,
    photos: photos,
  );
}

/// A cover-only album for one Cover Studio variant.
Album variantAlbum(
  CreationState state,
  DomainKit kit,
  CoverVariant variant,
  CoverSlots slots,
  String language,
) {
  final occasion = state.occasion ?? Occasion.other;
  final theme = BookTheme.byId(
    state.themeId ?? BookTheme.forOccasion(occasion).first.id,
  );
  final format = BookFormat.byId(
    occasion == Occasion.travel ? kTravelDefaultFormatId : kDefaultFormatId,
  );
  final strings = BookStrings(language);
  final photos = {
    for (final p in state.photos) p.id: p,
    if (variant.artwork case final art?) art.id: art,
  };
  final plans = planChapters(photos, occasion, strings);
  final env = ComposeEnv(
    format: format,
    theme: theme,
    accent: variant.accent,
    strings: strings,
    fonts: kit.fonts,
    photos: photos,
    chapters: [for (final p in plans) p.chapter],
    geo: kit.geo,
  );
  final cover = composeCover(
    templateId: variant.templateId,
    slots: slots.copyWith(heroPhotoId: variant.heroId),
    env: env,
    spineMm: fakeSpineMm(30),
    spineText: slots.title,
    backMark: AppConfig.brandName.toUpperCase(),
  );
  final now = DateTime.now().toUtc();
  return Album(
    id: 'variant_${variant.kind.name}',
    title: slots.title ?? '',
    occasion: occasion,
    themeId: theme.id,
    formatId: format.id,
    language: language,
    createdAt: now,
    updatedAt: now,
    accentColor: variant.accent,
    cover: cover,
    photos: photos,
  );
}
