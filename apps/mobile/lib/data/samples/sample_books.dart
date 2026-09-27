import 'dart:isolate';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../app_config.dart';
import '../../domain/captions/caption_request.dart';
import '../../domain/cover/cover_studio.dart';
import '../../domain/layout/chapters.dart';
import '../../domain/layout/cover_composer.dart';
import '../../domain/layout/layout_engine.dart';
import '../../domain/model/album.dart';
import '../../domain/occasion/occasion_rules.dart';
import '../../domain/spec/book_format.dart';
import '../../domain/spec/book_strings.dart';
import '../../domain/spec/spec_data.dart';
import '../../domain/theme/book_theme.dart';
import '../albums/album_repository.dart';
import '../domain_kit.dart';
import '../photos/photo_library.dart';
import '../services/services.dart';
import '../settings/settings.dart';

part 'sample_books.g.dart';

/// Ids of the two demo books on the shelf.
const kSampleBookIds = {'wedding': 'sample_wedding', 'travel': 'sample_travel'};

String _moment(String lang) => switch (lang) {
  'de' => 'Die stille Minute auf dem Steg vor dem Fest',
  'es' => 'El minuto tranquilo en el muelle antes de la fiesta',
  'fr' => 'La minute tranquille sur le ponton avant la fête',
  'it' => 'Il minuto tranquillo sul pontile prima della festa',
  'mk' => 'Тивката минута на кејот пред веселбата',
  _ => 'The quiet minute on the pier before the party',
};

/// Builds a complete, printable sample book from the bundled photos, through
/// the same steps as a user's book.
Future<Album> buildSampleAlbum(Ref ref, String set, String lang) async {
  final kit = await ref.read(domainKitProvider.future);
  final library = SamplePhotoLibrary(set);
  final analyser = await ref.read(photoAnalyzerProvider.future);
  final result = await analyser
      .analyze(await library.photos(), library)
      .firstWhere((p) => p.result != null);
  final photos = {for (final p in result.result!.photos) p.id: p};
  final included = photos.values.where((p) => !p.isExcluded).toList();
  final suggestion = detectOccasion(included, geo: kit.geo, language: lang);
  final occasion = suggestion.occasion;
  final strings = BookStrings(lang);
  final wedding = set == 'wedding';
  final story = wedding
      ? StoryAnswers(
          names: lang == 'mk' ? 'Александар и Елена' : 'Aleksandar & Elena',
          eventDate: DateTime.utc(2026, 8, 15),
          place: lang == 'mk' ? 'Охрид' : 'Ohrid',
          moment: _moment(lang),
        )
      : StoryAnswers(
          names: 'Mia & Luka',
          title: '${suggestion.destination ?? 'Zanzibar'} 2026',
        );
  final plans = planChapters(photos, occasion, strings);
  final captions = await (await ref.read(captionProviderProvider.future)).write(
    CaptionRequest(
      occasion: occasion,
      language: lang,
      story: story,
      chapters: plans,
      photos: photos,
      destination: suggestion.destination,
    ),
  );
  final theme = BookTheme.forOccasion(occasion).first;
  final format = BookFormat.byId(
    occasion == Occasion.travel ? kTravelDefaultFormatId : kDefaultFormatId,
  );
  // Wedding: the gold-tone monogram; trip: the full-bleed photo cover.
  final variants = coverVariants(
    occasion: occasion,
    theme: theme,
    photos: included,
    coverAspect: format.aspect,
    coverWidthMm: format.trimWMm,
  );
  final cover = variants.firstWhere(
    (v) =>
        v.kind ==
        (wedding ? CoverVariantKind.monogram : CoverVariantKind.photo),
    orElse: () => variants.first,
  );
  final slots = studioSlots(
    occasion: occasion,
    story: story,
    photos: included,
    strings: strings,
    geo: kit.geo,
    destination: suggestion.destination,
  ).copyWith(heroPhotoId: cover.heroId);
  final input = LayoutInput(
    albumId: kSampleBookIds[set]!,
    occasion: occasion,
    theme: theme,
    format: format,
    language: lang,
    photos: photos,
    plans: plans,
    captions: captions.copyWith(title: slots.title ?? captions.title),
    story: story,
    fonts: kit.fonts,
    geo: kit.geo,
    now: DateTime.now().toUtc(),
    spineMm: fakeSpineMm,
    brandMark: AppConfig.brandName.toUpperCase(),
    coverTemplateId: cover.templateId,
    coverSlots: slots,
    accentOverride: cover.accent,
  );
  final album = await Isolate.run(() => layoutAlbum(input));
  return album.copyWith(
    coverFinish: wedding ? CoverFinish.linen : CoverFinish.matte,
    flags: album.flags.copyWith(sample: true),
  );
}

/// An example book ("wedding" or "travel"), built the first time it is
/// asked for through the real pipeline and kept in the album store. Returns
/// its album id. Example books appear in onboarding and Settings, never on
/// the user's shelf.
@Riverpod(keepAlive: true)
Future<String> exampleBook(Ref ref, String set) async {
  final id = kSampleBookIds[set]!;
  final repo = ref.read(albumRepositoryProvider);
  if (await repo.load(id) != null) return id;
  final lang = ref.read(settingsControllerProvider).language.name;
  await repo.save(await buildSampleAlbum(ref, set, lang));
  return id;
}
