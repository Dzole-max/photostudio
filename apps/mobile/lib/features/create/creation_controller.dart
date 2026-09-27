import 'dart:async';
import 'dart:isolate';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../app_config.dart';
import '../../data/albums/album_repository.dart';
import '../../data/domain_kit.dart';
import '../../data/photos/photo_analyzer.dart';
import '../../data/photos/photo_library.dart';
import '../../data/services/observability.dart';
import '../../data/services/services.dart';
import '../../data/settings/settings.dart';
import '../../domain/captions/caption_request.dart';
import '../../domain/cover/cover_studio.dart';
import '../../domain/curation/curation.dart';
import '../../domain/theme/theme_tinter.dart';
import '../../domain/layout/chapters.dart';
import '../../domain/layout/cover_composer.dart';
import '../../domain/layout/layout_engine.dart';
import '../../domain/model/album.dart';
import '../../domain/occasion/occasion_rules.dart';
import '../../domain/spec/book_format.dart';
import '../../domain/spec/book_strings.dart';
import '../../domain/spec/spec_data.dart';
import '../../domain/theme/book_theme.dart';

part 'creation_controller.g.dart';

/// Minimum photos for a book.
const int kMinPhotosForBook = 8;

class CreationState {
  const CreationState({
    this.library,
    this.sampleSet,
    this.presetOccasion,
    this.selection = const [],
    this.progress,
    this.photos = const [],
    this.suggestion,
    this.occasion,
    this.themeId,
    this.story = const StoryAnswers(),
    this.generating = false,
    this.albumId,
    this.error,
    this.edition = Edition.album,
    this.coverVariants = const [],
    this.coverIndex = 0,
    this.coverSlots,
  });

  final PhotoLibrary? library;

  /// "wedding" / "travel" for the sample flow.
  final String? sampleSet;
  final Occasion? presetOccasion;
  final List<SourcePhoto> selection;
  final ImportProgress? progress;

  /// Curated photos (exclusions and pins editable in the review sheet).
  final List<PhotoRef> photos;
  final OccasionSuggestion? suggestion;
  final Occasion? occasion;
  final String? themeId;
  final StoryAnswers story;
  final bool generating;
  final String? albumId;
  final Object? error;

  /// Product chosen on the Edition picker; the album is always made.
  final Edition edition;

  /// Cover Studio: the variants, the chosen one and the shared text.
  final List<CoverVariant> coverVariants;
  final int coverIndex;
  final CoverSlots? coverSlots;

  CoverVariant? get chosenCover =>
      coverIndex < coverVariants.length ? coverVariants[coverIndex] : null;

  bool get analysing => progress != null && progress!.result == null;

  List<PhotoRef> get included => photos.where((p) => !p.isExcluded).toList();

  List<PhotoRef> get setAside => photos.where((p) => p.isExcluded).toList();

  CreationState copyWith({
    PhotoLibrary? library,
    String? sampleSet,
    Occasion? presetOccasion,
    List<SourcePhoto>? selection,
    ImportProgress? progress,
    List<PhotoRef>? photos,
    OccasionSuggestion? suggestion,
    Occasion? occasion,
    String? themeId,
    StoryAnswers? story,
    bool? generating,
    String? albumId,
    Object? error,
    bool clearError = false,
    Edition? edition,
    List<CoverVariant>? coverVariants,
    int? coverIndex,
    CoverSlots? coverSlots,
  }) {
    return CreationState(
      library: library ?? this.library,
      sampleSet: sampleSet ?? this.sampleSet,
      presetOccasion: presetOccasion ?? this.presetOccasion,
      selection: selection ?? this.selection,
      progress: progress ?? this.progress,
      photos: photos ?? this.photos,
      suggestion: suggestion ?? this.suggestion,
      occasion: occasion ?? this.occasion,
      themeId: themeId ?? this.themeId,
      story: story ?? this.story,
      generating: generating ?? this.generating,
      albumId: albumId ?? this.albumId,
      error: clearError ? null : (error ?? this.error),
      edition: edition ?? this.edition,
      coverVariants: coverVariants ?? this.coverVariants,
      coverIndex: coverIndex ?? this.coverIndex,
      coverSlots: coverSlots ?? this.coverSlots,
    );
  }
}

@Riverpod(keepAlive: true)
class CreationController extends _$CreationController {
  StreamSubscription<ImportProgress>? _sub;

  @override
  CreationState build() {
    ref.onDispose(() => _sub?.cancel());
    return const CreationState();
  }

  /// Starts a fresh book from the gallery, optionally for a known occasion.
  void startGallery({Occasion? occasion}) {
    _sub?.cancel();
    state = CreationState(
      library: ref.read(photoLibraryProvider),
      presetOccasion: occasion,
    );
  }

  /// "Try a sample book": selects every sample photo and starts analysing.
  Future<void> startSample(String set) async {
    await _sub?.cancel();
    final library = SamplePhotoLibrary(set);
    state = CreationState(library: library, sampleSet: set);
    final photos = await library.photos();
    state = state.copyWith(selection: photos);
    await analyse();
  }

  void setSelection(List<SourcePhoto> selection) =>
      state = state.copyWith(selection: selection);

  Future<void> analyse() async {
    final library = state.library;
    if (library == null || state.selection.isEmpty) return;
    await _sub?.cancel();
    unawaited(
      ref.read(analyticsProvider).track(AnalyticsEvent.importStarted, {
        'count': state.selection.length,
      }),
    );
    final analyser = await ref.read(photoAnalyzerProvider.future);
    final done = Completer<void>();
    _sub = analyser
        .analyze(state.selection, library)
        .listen(
          (p) {
            state = state.copyWith(
              progress: p,
              photos: p.result?.photos,
              clearError: true,
            );
            if (p.result != null) {
              unawaited(
                ref.read(analyticsProvider).track(AnalyticsEvent.curationDone, {
                  'total': p.result!.photos.length,
                  'setAside': p.result!.setAside.length,
                }),
              );
              _detect();
              if (!done.isCompleted) done.complete();
            }
          },
          onError: (Object e, StackTrace st) {
            state = state.copyWith(error: e);
            unawaited(ref.read(crashReporterProvider).report(e, st));
            if (!done.isCompleted) done.complete();
          },
        );
    await done.future;
  }

  /// Moves a photo between "In your book" and "Set aside".
  void toggleExcluded(String photoId) {
    state = state.copyWith(
      photos: [
        for (final p in state.photos)
          if (p.id == photoId)
            p.copyWith(
              isExcluded: !p.isExcluded,
              excludedReason: p.isExcluded ? null : ExclusionReason.user,
              userPinned: p.isExcluded && p.userPinned,
            )
          else
            p,
      ],
    );
  }

  /// Favourites are always included and get a large frame.
  void togglePinned(String photoId) {
    state = state.copyWith(
      photos: [
        for (final p in state.photos)
          if (p.id == photoId)
            p.copyWith(
              userPinned: !p.userPinned,
              isExcluded: false,
              excludedReason: null,
            )
          else
            p,
      ],
    );
  }

  Future<void> _detect() async {
    final kit = await ref.read(domainKitProvider.future);
    final lang = ref.read(settingsControllerProvider).language.name;
    var suggestion = detectOccasion(
      state.included,
      geo: kit.geo,
      language: lang,
    );
    if (!suggestion.fromRules) {
      final sample = [...state.included]
        ..sort((a, b) => b.quality.overall.compareTo(a.quality.overall));
      final guess = await ref
          .read(occasionAiServiceProvider)
          .guess(sample.take(12).toList());
      suggestion = OccasionSuggestion(
        occasion: guess,
        fromRules: false,
        destination: suggestion.destination,
        alternatives: suggestion.alternatives,
      );
    }
    final occasion = state.presetOccasion ?? suggestion.occasion;
    state = state.copyWith(
      suggestion: suggestion,
      occasion: occasion,
      themeId: BookTheme.forOccasion(occasion).first.id,
      story: _defaults(occasion, suggestion, lang),
    );
  }

  /// Smart defaults for the story interview (prefilled from the photos).
  StoryAnswers _defaults(Occasion occasion, OccasionSuggestion s, String lang) {
    final dates =
        state.included.map((p) => p.takenAt).whereType<DateTime>().toList()
          ..sort();
    final first = dates.isEmpty ? null : dates.first;
    final sample = state.sampleSet;
    final place = s.destination ?? _commonPlace();
    return StoryAnswers(
      eventDate: occasion == Occasion.travel || occasion == Occasion.family
          ? null
          : first,
      place: occasion == Occasion.travel ? null : place,
      title: occasion == Occasion.travel && place != null && first != null
          ? '$place ${first.year}'
          : null,
      names: sample == 'wedding'
          ? 'Aleksandar & Elena'
          : (sample == 'travel' ? 'Mia & Luka' : null),
      moment: sample == 'wedding' ? _sampleMoment(lang) : null,
    );
  }

  String _sampleMoment(String lang) => switch (lang) {
    'de' => 'Die stille Minute auf dem Steg vor dem Fest',
    'es' => 'El minuto tranquilo en el muelle antes de la fiesta',
    'fr' => 'La minute tranquille sur le ponton avant la fête',
    'it' => 'Il minuto tranquillo sul pontile prima della festa',
    'mk' => 'Тивката минута на кејот пред веселбата',
    _ => 'The quiet minute on the pier before the party',
  };

  String? _commonPlace() {
    final counts = <String, int>{};
    for (final p in state.included) {
      if (p.placeName != null) {
        counts[p.placeName!] = (counts[p.placeName!] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  void confirmOccasion(Occasion occasion, {String? themeId}) {
    final changed = occasion != state.occasion;
    final lang = ref.read(settingsControllerProvider).language.name;
    state = state.copyWith(
      occasion: occasion,
      themeId:
          themeId ??
          (changed ? BookTheme.forOccasion(occasion).first.id : state.themeId),
      story: changed && state.suggestion != null
          ? _defaults(occasion, state.suggestion!, lang)
          : state.story,
    );
    unawaited(
      ref.read(analyticsProvider).track(AnalyticsEvent.occasionConfirmed, {
        'occasion': occasion.name,
      }),
    );
  }

  void setTheme(String themeId) => state = state.copyWith(themeId: themeId);

  void setEdition(Edition edition) => state = state.copyWith(edition: edition);

  /// Builds the Cover Studio variants. Photo, monogram and map covers are
  /// ready at once; the illustrated one is painted in the background.
  Future<void> prepareCoverStudio() async {
    final occasion = state.occasion;
    if (occasion == null) return;
    final kit = await ref.read(domainKitProvider.future);
    final lang = ref.read(settingsControllerProvider).language.name;
    final theme = BookTheme.byId(
      state.themeId ?? BookTheme.forOccasion(occasion).first.id,
    );
    final format = BookFormat.byId(
      occasion == Occasion.travel ? kTravelDefaultFormatId : kDefaultFormatId,
    );
    final included = state.included;
    final variants = coverVariants(
      occasion: occasion,
      theme: theme,
      photos: included,
      coverAspect: format.aspect,
      coverWidthMm: format.trimWMm,
    );
    state = state.copyWith(
      coverVariants: variants,
      coverIndex: 0,
      coverSlots: studioSlots(
        occasion: occasion,
        story: state.story,
        photos: included,
        strings: BookStrings(lang),
        geo: kit.geo,
        destination: state.suggestion?.destination,
      ),
    );
    final i = variants.indexWhere(
      (v) => v.kind == CoverVariantKind.illustrated,
    );
    if (i < 0) return;
    final source = variants[i].heroId == null
        ? null
        : state.photos.where((p) => p.id == variants[i].heroId).firstOrNull;
    if (source == null) return;
    try {
      final art = await ref
          .read(coverArtProviderProvider)
          .illustratedCover(source);
      final updated = [...state.coverVariants];
      final idx = updated.indexWhere(
        (v) => v.kind == CoverVariantKind.illustrated,
      );
      if (idx < 0) return;
      updated[idx] = updated[idx].withArtwork(
        art,
        const ThemeTinter().tint(theme.accent, art.dominantHue),
      );
      state = state.copyWith(coverVariants: updated);
    } on Object catch (e, st) {
      await ref.read(crashReporterProvider).report(e, st);
    }
  }

  void selectCover(int index) => state = state.copyWith(coverIndex: index);

  void updateCoverSlots(CoverSlots slots) =>
      state = state.copyWith(coverSlots: slots);

  void updateStory(StoryAnswers story) => state = state.copyWith(story: story);

  /// Writes captions and lays out the book; returns the new album id.
  Future<String?> generate() async {
    final occasion = state.occasion;
    if (occasion == null || state.generating) return state.albumId;
    state = state.copyWith(generating: true, clearError: true);
    try {
      final kit = await ref.read(domainKitProvider.future);
      final lang = ref.read(settingsControllerProvider).language.name;
      final chosen = state.chosenCover;
      final photos = {
        for (final p in state.photos) p.id: p,
        if (chosen?.artwork case final art?) art.id: art,
      };
      final plans = planChapters(photos, occasion, BookStrings(lang));
      final captionProvider = await ref.read(captionProviderProvider.future);
      final written = await captionProvider.write(
        CaptionRequest(
          occasion: occasion,
          language: lang,
          story: state.story,
          chapters: plans,
          photos: photos,
          destination: state.suggestion?.destination,
        ),
      );
      // The title chosen in the Cover Studio is the book's title.
      final studioTitle = state.coverSlots?.title?.trim();
      final captions = studioTitle == null || studioTitle.isEmpty
          ? written
          : written.copyWith(title: studioTitle);
      final theme = BookTheme.byId(
        state.themeId ?? BookTheme.forOccasion(occasion).first.id,
      );
      final format = BookFormat.byId(
        occasion == Occasion.travel ? kTravelDefaultFormatId : kDefaultFormatId,
      );
      final now = DateTime.now().toUtc();
      final input = LayoutInput(
        albumId: const Uuid().v4(),
        occasion: occasion,
        theme: theme,
        format: format,
        language: lang,
        photos: photos,
        plans: plans,
        captions: captions,
        story: state.story,
        fonts: kit.fonts,
        geo: kit.geo,
        now: now,
        spineMm: fakeSpineMm,
        coverTemplateId: chosen?.templateId,
        coverSlots: chosen == null || state.coverSlots == null
            ? null
            : state.coverSlots!.copyWith(heroPhotoId: chosen.heroId),
        accentOverride: chosen?.accent,
        brandMark: AppConfig.brandName.toUpperCase(),
      );
      final laidOut = await Isolate.run(() => layoutAlbum(input));
      final album = laidOut.copyWith(
        flags: laidOut.flags.copyWith(edition: state.edition),
      );
      await ref.read(albumRepositoryProvider).save(album);
      unawaited(
        ref.read(analyticsProvider).track(AnalyticsEvent.bookGenerated, {
          'occasion': occasion.name,
          'pages': album.pages.length,
          'photos': album.usedPhotoIds.length,
        }),
      );
      state = state.copyWith(generating: false, albumId: album.id);
      return album.id;
    } on Object catch (e, st) {
      await ref.read(crashReporterProvider).report(e, st);
      state = state.copyWith(generating: false, error: e);
      return null;
    }
  }

  CurationResult get curation => CurationResult(state.photos);
}
