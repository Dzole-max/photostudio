import 'dart:math' as math;

import '../geo/geo_data.dart';
import '../model/album.dart';
import '../model/captions.dart';
import '../spec/book_format.dart';
import '../spec/book_strings.dart';
import '../text/font_registry.dart';
import '../theme/book_theme.dart';
import '../theme/theme_tinter.dart';
import 'chapters.dart';
import 'cover_composer.dart';
import 'page_composer.dart';
import 'smart_crop.dart';
import 'templates.dart';

/// Scoring weights (section 7.7 step 2).
abstract final class LayoutWeights {
  static const orientation = 3.0;
  static const quality = 3.0;
  static const faces = 4.0;
  static const pacing = 2.0;
  static const variety = 1.0;
  static const density = 2.0;
}

/// Effective resolution below which the engine tries a smaller frame.
const double kTargetMinDpi = 200;

/// Labels that mark a good travel cover (landmark / landscape).
const _travelCoverLabels = {
  'beach',
  'sea',
  'sky',
  'building',
  'ocean',
  'landscape',
  'water',
  'sand',
  'island',
};

class LayoutInput {
  LayoutInput({
    required this.albumId,
    required this.occasion,
    required this.theme,
    required this.format,
    required this.language,
    required this.photos,
    required this.plans,
    required this.captions,
    required this.story,
    required this.fonts,
    required this.now,
    this.geo,
    this.seed = 1,
    this.coverTemplateId,
    this.spineMm,
    this.brandMark = 'MEMORIA',
    this.coverSlots,
    this.createdAt,
    this.accentOverride,
  });

  final String albumId;
  final Occasion occasion;
  final BookTheme theme;
  final BookFormat format;
  final String language;
  final Map<String, PhotoRef> photos;
  final List<ChapterPlan> plans;
  final CaptionSet captions;
  final StoryAnswers story;
  final FontRegistry fonts;
  final GeoData? geo;
  final int seed;
  final DateTime now;
  final String? coverTemplateId;

  /// Spine width from the print provider; the placeholder formula otherwise.
  final double Function(int innerPages)? spineMm;
  final String brandMark;

  /// Keeps user-edited cover slots across re-layouts.
  final CoverSlots? coverSlots;
  final DateTime? createdAt;

  /// Accent chosen in the Cover Studio (wins over adaptive tinting).
  final String? accentOverride;
}

class _Placed {
  _Placed(this.content, {this.panoramaHalf = false});

  final PageContent content;
  final bool panoramaHalf;
  PageTemplate get template => PageTemplate.byId(content.templateId);
}

/// Builds a complete album: pages, chapters, cover. Deterministic for the
/// same input and seed.
Album layoutAlbum(LayoutInput input) {
  final strings = BookStrings(input.language);
  final rng = math.Random(input.seed);
  final format = input.format;
  final theme = input.theme;

  // Chapters and their photos (only included photos, capped to capacity).
  final captionMap = input.captions.captionByPhoto;
  final plans = [
    for (final p in input.plans)
      ChapterPlan(
        p.chapter,
        p.photoIds
            .where((id) => input.photos[id]?.isExcluded == false)
            .toList(),
      ),
  ]..removeWhere((p) => p.photoIds.isEmpty);
  final multiChapter = plans.length > 1;
  final stops = plans
      .where((p) => p.chapter.lat != null)
      .map((p) => p.chapter.placeName)
      .toSet();
  final withMap =
      input.occasion == Occasion.travel &&
      input.geo != null &&
      stops.length >= 2;

  final fixedPages = 2 + (withMap ? 1 : 0) + (multiChapter ? plans.length : 0);
  var photoCount = plans.fold<int>(0, (a, p) => a + p.photoIds.length);
  final capacity = ((format.maxPages - fixedPages) * 4.2).floor();
  if (photoCount > capacity) {
    _trimToCapacity(plans, input.photos, capacity);
    photoCount = capacity;
  }

  // Target number of photo pages: ~2.4 photos per page, inside the range.
  final idealTotal = fixedPages + (photoCount / 2.4).ceil();
  final targetTotal = format.fitPageCount(idealTotal);
  final photoPages = math.max(plans.length, targetTotal - fixedPages);

  // Top 15 % by quality are hero candidates.
  final ranked = [for (final p in plans) ...p.photoIds]
    ..sort(
      (a, b) => input.photos[b]!.quality.overall.compareTo(
        input.photos[a]!.quality.overall,
      ),
    );
  final topCount = math.max(1, (ranked.length * 0.15).ceil());
  final topIds = ranked.take(topCount).toSet();

  final chapters = <Chapter>[];
  final placed = <_Placed>[];

  // Title page.
  final title = input.captions.title.isNotEmpty
      ? input.captions.title
      : (input.story.title ?? '');
  final dateLabel = _dateLabel(input, strings, plans);
  placed.add(
    _Placed(
      PageContent(
        templateId: 'title_page',
        title: title,
        subtitle: input.captions.subtitle.isEmpty
            ? null
            : input.captions.subtitle,
        // Don't repeat the date when the subtitle already says it.
        label:
            dateLabel != null &&
                input.captions.subtitle.toLowerCase().contains(
                  dateLabel.toLowerCase(),
                )
            ? null
            : dateLabel,
      ),
    ),
  );
  if (withMap) {
    placed.add(_Placed(PageContent(templateId: 'map_page')));
  }

  var photoPagesLeft = photoPages;
  var photosLeft = photoCount;
  for (var ci = 0; ci < plans.length; ci++) {
    final plan = plans[ci];
    final text = input.captions.chapter(plan.chapter.id);
    final chapter = plan.chapter.copyWith(
      title: text?.title.isNotEmpty == true ? text!.title : plan.chapter.title,
      intro: text?.intro,
      startPageIndex: placed.length,
    );
    chapters.add(chapter);
    if (multiChapter) {
      placed.add(
        _Placed(
          PageContent(
            templateId: 'chapter_opener',
            chapterId: chapter.id,
            title: chapter.title,
            body: chapter.intro,
            label: _chapterLabel(input.occasion, chapter, strings, ci),
          ),
        ),
      );
    }
    // Page budget for this chapter, proportional to its photos.
    final isLast = ci == plans.length - 1;
    var budget = isLast
        ? photoPagesLeft
        : math.max(
            1,
            (photoPagesLeft * plan.photoIds.length / photosLeft).round(),
          );
    budget = math.min(budget, plan.photoIds.length);
    budget = math.max(
      1,
      math.min(budget, photoPagesLeft - (plans.length - ci - 1)),
    );
    photoPagesLeft -= budget;
    photosLeft -= plan.photoIds.length;

    final queue = [...plan.photoIds];
    var pagesLeft = budget;
    var firstInChapter = true;
    while (queue.isNotEmpty) {
      final ideal = queue.length / math.max(1, pagesLeft);
      final best = _choose(
        queue: queue,
        ideal: ideal,
        pagesLeft: pagesLeft,
        index: placed.length,
        placed: placed,
        input: input,
        topIds: topIds,
        captions: captionMap,
        rng: rng,
        firstInChapter: firstInChapter,
      );
      final ids = queue.sublist(0, best.count);
      queue.removeRange(0, best.count);
      final captions = <int, String>{
        for (var i = 0; i < ids.length; i++) i: ?captionMap[ids[i]],
      };
      if (best.template.panorama) {
        placed.add(
          _Placed(
            PageContent(
              templateId: 'spread_panorama',
              chapterId: chapter.id,
              photoIds: ids,
            ),
            panoramaHalf: true,
          ),
        );
        placed.add(
          _Placed(
            PageContent(
              templateId: 'spread_panorama',
              mirrored: true,
              chapterId: chapter.id,
              photoIds: ids,
            ),
            panoramaHalf: true,
          ),
        );
        pagesLeft -= 2;
      } else {
        placed.add(
          _Placed(
            PageContent(
              templateId: best.template.id,
              mirrored: best.mirrored,
              chapterId: chapter.id,
              photoIds: ids,
              captions: captions,
            ),
          ),
        );
        pagesLeft -= 1;
      }
      firstInChapter = false;
    }
  }

  // Colophon.
  // The user's favourite moment, in their own words.
  final moment = input.story.moment?.trim();
  if (moment != null && moment.isNotEmpty) {
    placed.add(
      _Placed(
        PageContent(
          templateId: 'quote_page',
          body: moment,
          label: input.story.names,
        ),
      ),
    );
  }

  placed.add(_Placed(PageContent(templateId: 'colophon')));

  // Fit page count to the format and make it even.
  final blankAdded = _fitPageCount(placed, input, topIds, captionMap, rng);

  // Accent tint from the cover photo, then compose everything.
  final coverTemplate = input.coverTemplateId ?? theme.defaultCover;
  final coverSlots =
      input.coverSlots ??
      _coverSlots(input, strings, coverTemplate, title, dateLabel, plans);
  final hero = coverSlots.heroPhotoId == null
      ? null
      : input.photos[coverSlots.heroPhotoId];
  final accent =
      input.accentOverride ??
      const ThemeTinter().tint(theme.accent, hero?.dominantHue);

  // Chapter start indexes after fitting.
  final starts = <String, int>{};
  for (var i = 0; i < placed.length; i++) {
    final id = placed[i].content.chapterId;
    if (id != null) starts.putIfAbsent(id, () => i);
  }
  final fixedChapters = [
    for (final c in chapters)
      c.copyWith(startPageIndex: starts[c.id] ?? c.startPageIndex),
  ];

  final env = ComposeEnv(
    format: format,
    theme: theme,
    accent: accent,
    strings: strings,
    fonts: input.fonts,
    photos: input.photos,
    chapters: fixedChapters,
    geo: input.geo,
    seed: input.seed,
    year: (input.createdAt ?? input.now).year,
  );
  final pages = [
    for (var i = 0; i < placed.length; i++)
      composePage(placed[i].content, i, env, id: 'p${i + 1}'),
  ];
  final spine = (input.spineMm ?? fakeSpineMm)(pages.length);
  final cover = composeCover(
    templateId: coverTemplate,
    slots: coverSlots,
    env: env,
    spineMm: spine,
    spineText: title,
    backText: input.captions.backCover.isEmpty
        ? null
        : input.captions.backCover,
    backMark: input.brandMark,
  );

  return Album(
    id: input.albumId,
    title: title,
    subtitle: input.captions.subtitle.isEmpty ? null : input.captions.subtitle,
    occasion: input.occasion,
    themeId: theme.id,
    formatId: format.id,
    language: strings.lang,
    createdAt: input.createdAt ?? input.now,
    updatedAt: input.now,
    seed: input.seed,
    accentColor: accent,
    cover: cover,
    pages: pages,
    chapters: fixedChapters,
    photos: input.photos,
    story: input.story,
    flags: AlbumFlags(blankPagesAdded: blankAdded),
  );
}

// ---------------------------------------------------------------------------
// Template choice

class _Choice {
  _Choice(this.template, this.count, this.mirrored, this.score);

  final PageTemplate template;
  final int count;
  final bool mirrored;
  final double score;
}

_Choice _choose({
  required List<String> queue,
  required double ideal,
  required int pagesLeft,
  required int index,
  required List<_Placed> placed,
  required LayoutInput input,
  required Set<String> topIds,
  required Map<String, String> captions,
  required math.Random rng,
  required bool firstInChapter,
}) {
  final candidates = <_Choice>[];
  final templates = PageTemplate.photoTemplates(playful: input.theme.playful);
  // Panorama: a spread starting on a left page, one very wide top photo.
  final allowPanorama = index.isOdd && pagesLeft >= 2;
  final pool = [
    ...templates,
    if (allowPanorama) PageTemplate.byId('spread_panorama'),
  ];
  for (final t in pool) {
    for (var k = t.minPhotos; k <= t.maxPhotos && k <= queue.length; k++) {
      // Never leave more photos than pages can hold, nor starve later pages.
      final remainingAfter = queue.length - k;
      final pagesAfter = pagesLeft - (t.panorama ? 2 : 1);
      // The chapter's last page must take everything that's left, and no
      // later page may end up empty.
      if (pagesAfter <= 0 && remainingAfter > 0) continue;
      if (pagesAfter > 0 && remainingAfter < pagesAfter) continue;
      for (final mirrored in [false, true]) {
        if (mirrored && !_mirrorable(t)) continue;
        final ids = queue.sublist(0, k);
        final s = _score(
          template: t,
          ids: ids,
          ideal: ideal,
          index: index,
          mirrored: mirrored,
          placed: placed,
          input: input,
          topIds: topIds,
          captions: captions,
          firstInChapter: firstInChapter,
        );
        candidates.add(_Choice(t, k, mirrored, s + rng.nextDouble() * 0.6));
      }
    }
  }
  if (candidates.isEmpty) {
    // More photos than a single page holds on the chapter's last page:
    // fall back to the densest grid.
    return _Choice(
      PageTemplate.byId('six_grid'),
      math.min(6, queue.length),
      false,
      0,
    );
  }
  candidates.sort((a, b) => b.score.compareTo(a.score));
  return candidates.first;
}

bool _mirrorable(PageTemplate t) => const {
  'photo_with_text_right',
  'two_offset',
  'three_one_big_two_small',
  'five_mosaic',
}.contains(t.id);

double _score({
  required PageTemplate template,
  required List<String> ids,
  required double ideal,
  required int index,
  required bool mirrored,
  required List<_Placed> placed,
  required LayoutInput input,
  required Set<String> topIds,
  required Map<String, String> captions,
  required bool firstInChapter,
}) {
  final photos = [for (final id in ids) input.photos[id]!];
  final k = ids.length;
  var score = 0.0;

  // Density: stay close to the photos-per-page this chapter needs.
  score -=
      LayoutWeights.density * math.pow(k - ideal, 2) / math.max(1.0, ideal);

  final side = BookFormat.sideOf(index);
  final geometry = template.build(
    TemplateContext(
      format: input.format,
      side: side,
      mirrored: mirrored,
      slots: [
        for (var i = 0; i < k; i++)
          SlotInput(
            aspect: photos[i].aspect,
            hasCaption:
                template.captionMode == CaptionMode.below &&
                captions.containsKey(ids[i]),
          ),
      ],
    ),
  );
  final pageArea = input.format.trimWMm * input.format.trimHMm;

  var orientationPenalty = 0.0;
  for (var i = 0; i < geometry.slots.length && i < k; i++) {
    final slot = geometry.slots[i];
    final photo = photos[i];
    final rect = slot.borderMm > 0
        ? slot.rect.deflate(slot.borderMm)
        : slot.rect;
    orientationPenalty += (math.log(rect.aspect / photo.aspect)).abs();

    final crop = smartCrop(photo, rect.aspect);
    if (!crop.facesSafe) score -= LayoutWeights.faces;
    if (template.fullBleed) {
      final gutter = template.panorama
          ? (side == PageSide.left ? input.format.trimWMm : 0.0)
          : input.format.gutterX(side);
      final shifted = avoidGutter(
        photo,
        crop.crop,
        rect,
        gutterX: gutter,
        minDistMm: template.panorama ? 20 : 12,
        centresOnly: template.panorama,
      );
      if (faceNearGutter(
        photo,
        shifted,
        rect,
        gutterX: gutter,
        minDistMm: template.panorama ? 20 : 12,
        centresOnly: template.panorama,
      )) {
        score -= LayoutWeights.faces * 2;
      }
    }
    final dpi = effectiveDpi(photo, crop.crop, rect);
    if (dpi < 150) {
      score -= 12;
    } else if (dpi < kTargetMinDpi) {
      score -= 3;
    }

    final areaShare = (rect.w * rect.h) / pageArea;
    final isTop = topIds.contains(photo.id);
    if (photo.userPinned && areaShare < 0.3) score -= 6;
    if (isTop && areaShare < 0.12) score -= 1;
  }
  score -= LayoutWeights.orientation * orientationPenalty / math.max(1, k);

  // Quality: heroes for the best photos only.
  if (template.isHero) {
    final best = topIds.contains(ids.first) || photos.first.userPinned;
    score += best
        ? LayoutWeights.quality
        : (template.fullBleed ? -LayoutWeights.quality * 0.6 : -0.3);
    if (template.panorama) score += photos.first.aspect >= 1.9 ? 2 : -20;
  }
  if (firstInChapter && k == 1) score += 0.5;

  // Pacing: at most two grid pages in a row; one full-bleed page per spread.
  final prev = placed.isNotEmpty ? placed.last.template : null;
  final prev2 = placed.length > 1 ? placed[placed.length - 2].template : null;
  if (template.isGrid &&
      prev != null &&
      prev.isGrid &&
      prev2 != null &&
      prev2.isGrid) {
    score -= 50 * LayoutWeights.pacing;
  }
  if (template.fullBleed &&
      !template.panorama &&
      side == PageSide.right &&
      prev != null &&
      prev.fullBleed) {
    score -= 50 * LayoutWeights.pacing;
  }
  if (template.panorama && prev != null && prev.fullBleed) {
    score -= 50 * LayoutWeights.pacing;
  }
  if (template.isGrid && prev != null && prev.isGrid) {
    score -= LayoutWeights.pacing * 0.5;
  }

  // Variety: avoid repeating a template within three pages.
  for (var i = placed.length - 1; i >= 0 && i >= placed.length - 3; i--) {
    if (placed[i].content.templateId == template.id) {
      score -= LayoutWeights.variety;
    }
  }

  // Captions: keep them where the template can show them.
  final captioned = ids.where(captions.containsKey).length;
  if (captioned > 0) {
    switch (template.captionMode) {
      case CaptionMode.none:
        score -= 0.8 * captioned;
      case CaptionMode.side:
        score += k == 1 ? 0.8 : 0;
      case CaptionMode.below:
        score += 0.2;
    }
  }

  if (template.captionMode == CaptionMode.side && captioned == 0) {
    // An empty text column looks unfinished.
    score -= 2.5;
  }

  // Theme preference.
  final w = input.theme.templateWeights[template.id];
  if (w != null) score += math.log(w) * 4;
  return score;
}

// ---------------------------------------------------------------------------
// Page count fitting (section 6.3)

int _fitPageCount(
  List<_Placed> placed,
  LayoutInput input,
  Set<String> topIds,
  Map<String, String> captions,
  math.Random rng,
) {
  final format = input.format;
  var blank = 0;

  bool split() {
    // Split the fullest non-special page into a hero + the rest.
    var bestIdx = -1, bestCount = 1;
    for (var i = 0; i < placed.length; i++) {
      final p = placed[i];
      if (p.panoramaHalf || p.template.kind != TemplateKind.photo) continue;
      final n = p.content.photoIds.length;
      if (n > bestCount) {
        bestCount = n;
        bestIdx = i;
      }
    }
    if (bestIdx < 0) return false;
    final old = placed[bestIdx].content;
    final ids = old.photoIds.whereType<String>().toList();
    // Promote the best photo of the page to its own hero page.
    ids.sort(
      (a, b) => input.photos[b]!.quality.overall.compareTo(
        input.photos[a]!.quality.overall,
      ),
    );
    final heroId = ids.first;
    final rest = old.photoIds
        .where((id) => id != heroId)
        .whereType<String>()
        .toList();
    final heroTemplate = topIds.contains(heroId)
        ? 'hero_bordered'
        : 'hero_centered';
    final heroPage = PageContent(
      templateId: heroTemplate,
      chapterId: old.chapterId,
      photoIds: [heroId],
      captions: {0: ?captions[heroId]},
    );
    final restPage = PageContent(
      templateId: templateForCount(rest.length, input.theme.playful),
      chapterId: old.chapterId,
      photoIds: rest,
      captions: {for (var i = 0; i < rest.length; i++) i: ?captions[rest[i]]},
    );
    final heroFirst = old.photoIds.indexOf(heroId) < old.photoIds.length / 2;
    placed.replaceRange(
      bestIdx,
      bestIdx + 1,
      heroFirst
          ? [_Placed(heroPage), _Placed(restPage)]
          : [_Placed(restPage), _Placed(heroPage)],
    );
    return true;
  }

  bool merge() {
    // Merge two adjacent small photo pages of the same chapter.
    for (var i = placed.length - 2; i >= 0; i--) {
      final a = placed[i], b = placed[i + 1];
      if (a.panoramaHalf || b.panoramaHalf) continue;
      if (a.template.kind != TemplateKind.photo ||
          b.template.kind != TemplateKind.photo) {
        continue;
      }
      if (a.content.chapterId != b.content.chapterId) continue;
      final ids = [
        ...a.content.photoIds,
        ...b.content.photoIds,
      ].whereType<String>().toList();
      if (ids.length > 5) continue;
      placed.replaceRange(i, i + 2, [
        _Placed(
          PageContent(
            templateId: templateForCount(ids.length, input.theme.playful),
            chapterId: a.content.chapterId,
            photoIds: ids,
            captions: {
              for (var j = 0; j < ids.length; j++) j: ?captions[ids[j]],
            },
          ),
        ),
      ]);
      return true;
    }
    return false;
  }

  void addBlank() {
    placed.insert(
      placed.length - 1,
      _Placed(PageContent(templateId: 'blank_note')),
    );
    blank++;
  }

  var guard = 0;
  while (placed.length < format.minPages && guard++ < 400) {
    if (!split()) addBlank();
  }
  guard = 0;
  while (placed.length > format.maxPages && guard++ < 400) {
    if (!merge()) {
      // Drop the lowest-quality photo page as a last resort.
      final idx = placed.lastIndexWhere(
        (p) => p.template.kind == TemplateKind.photo && !p.panoramaHalf,
      );
      if (idx < 0) break;
      placed.removeAt(idx);
    }
  }
  if (placed.length.isOdd) {
    if (placed.length < format.maxPages) {
      if (!split()) addBlank();
    } else if (!merge()) {
      final idx = placed.lastIndexWhere(
        (p) => p.template.kind == TemplateKind.photo && !p.panoramaHalf,
      );
      if (idx >= 0) placed.removeAt(idx);
    }
  }
  _repairPanoramas(placed);
  return blank;
}

/// Panorama halves must sit on a left page followed by its right page;
/// after insertions a broken pair becomes a single full-bleed page.
void _repairPanoramas(List<_Placed> placed) {
  for (var i = 0; i < placed.length; i++) {
    final p = placed[i];
    if (!p.panoramaHalf || p.content.mirrored) continue;
    final ok =
        i.isOdd &&
        i + 1 < placed.length &&
        placed[i + 1].panoramaHalf &&
        placed[i + 1].content.mirrored;
    if (!ok) {
      final ids = p.content.photoIds;
      placed[i] = _Placed(
        PageContent(
          templateId: 'full_bleed',
          chapterId: p.content.chapterId,
          photoIds: ids,
        ),
      );
      if (i + 1 < placed.length &&
          placed[i + 1].panoramaHalf &&
          placed[i + 1].content.mirrored) {
        placed[i + 1] = _Placed(
          PageContent(
            templateId: 'hero_centered',
            chapterId: p.content.chapterId,
            photoIds: ids,
          ),
        );
      }
    }
  }
}

void _trimToCapacity(
  List<ChapterPlan> plans,
  Map<String, PhotoRef> photos,
  int capacity,
) {
  final all = [for (final p in plans) ...p.photoIds]
    ..sort((a, b) {
      final pa = photos[a]!, pb = photos[b]!;
      if (pa.userPinned != pb.userPinned) return pa.userPinned ? -1 : 1;
      return pb.quality.overall.compareTo(pa.quality.overall);
    });
  final keep = all.take(capacity).toSet();
  for (final p in plans) {
    p.photoIds.retainWhere(keep.contains);
  }
  plans.removeWhere((p) => p.photoIds.isEmpty);
}

// ---------------------------------------------------------------------------
// Labels and cover

String? _dateLabel(
  LayoutInput input,
  BookStrings strings,
  List<ChapterPlan> plans,
) {
  final event = input.story.eventDate;
  if (event != null && input.occasion != Occasion.family) {
    return strings.dateLong(event);
  }
  final ranges = plans
      .map((p) => p.chapter.dateRange)
      .whereType<DateRange>()
      .toList();
  if (ranges.isEmpty) return null;
  final start = ranges.first.start;
  final end = ranges.last.end;
  if (input.occasion == Occasion.family) {
    return start.year == end.year
        ? '${start.year}'
        : '${start.year}–${end.year}';
  }
  if (start.year == end.year &&
      start.month == end.month &&
      start.day == end.day) {
    return strings.dateLong(start);
  }
  return strings.monthYearTitle(start);
}

String? _chapterLabel(
  Occasion occasion,
  Chapter c,
  BookStrings strings,
  int index,
) {
  final r = c.dateRange;
  if (occasion == Occasion.travel && r != null) {
    return strings.dateLong(r.start);
  }
  if (occasion == Occasion.wedding && r != null) {
    final t = r.start;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
  return strings.chapter(index + 1);
}

CoverSlots _coverSlots(
  LayoutInput input,
  BookStrings strings,
  String templateId,
  String title,
  String? dateLabel,
  List<ChapterPlan> plans,
) {
  final included = [
    for (final p in plans)
      for (final id in p.photoIds) input.photos[id]!,
  ];
  final hero = pickCoverHero(
    included,
    input.occasion,
    coverAspect: input.format.aspect,
    coverWidthMm: input.format.trimWMm,
  );
  final names = input.story.names;
  String? monogram;
  if (names != null && names.trim().isNotEmpty) {
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
          '${parts[0].trim().characters0} & ${parts[1].trim().characters0}';
    }
  }
  final geo = included.where((p) => p.lat != null && p.lng != null).toList();
  String? coordinates;
  if (geo.isNotEmpty) {
    final lat = geo.map((p) => p.lat!).reduce((a, b) => a + b) / geo.length;
    final lng = geo.map((p) => p.lng!).reduce((a, b) => a + b) / geo.length;
    coordinates = strings.coordinates(lat, lng);
  }
  final firstDate = included
      .map((p) => p.takenAt)
      .whereType<DateTime>()
      .fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
  final grid = [...included]
    ..sort((a, b) => b.quality.overall.compareTo(a.quality.overall));
  final gridIds =
      (grid.take(9).toList()..sort(
            (a, b) => (a.takenAt ?? DateTime.utc(0)).compareTo(
              b.takenAt ?? DateTime.utc(0),
            ),
          ))
          .map((p) => p.id)
          .toList();
  return CoverSlots(
    title: title,
    subtitle: input.captions.subtitle.isEmpty ? null : input.captions.subtitle,
    date: dateLabel,
    location:
        input.story.place ??
        plans
            .firstWhere(
              (p) => p.chapter.placeName != null,
              orElse: () => plans.first,
            )
            .chapter
            .placeName,
    names: names,
    monogram: monogram,
    coordinates: coordinates,
    heroPhotoId: hero?.id,
    photoIds: gridIds,
    age: templateId == 'cover_travel_mapstamp'
        ? (firstDate == null ? null : '${firstDate.year}')
        : null,
  );
}

/// Cover hero: best landscape photo with faces (wedding), best landmark or
/// landscape (travel), best landscape otherwise.
PhotoRef? pickCoverHero(
  List<PhotoRef> photos,
  Occasion occasion, {
  double coverAspect = 1,
  double coverWidthMm = 200,
}) {
  if (photos.isEmpty) return null;
  double score(PhotoRef p) {
    var s = p.quality.overall;
    // Prefer photos that fill the cover without heavy cropping or softness.
    s -= (math.log(p.aspect / coverAspect)).abs() * 0.35;
    final crop = smartCrop(p, coverAspect).crop;
    final dpi = p.width * crop.w / ((coverWidthMm + 8) / 25.4);
    if (dpi < 200) s -= 0.5;
    if (p.orientation == PhotoOrientation.landscape) s += 0.3;
    if (p.userPinned) s += 0.2;
    switch (occasion) {
      case Occasion.wedding || Occasion.baby || Occasion.birthday:
        if (p.faces.isNotEmpty) s += 0.4;
      case Occasion.travel:
        if (p.hasLabel(_travelCoverLabels, minConfidence: 0.5)) s += 0.4;
        if (p.faces.length > 2) s -= 0.2;
      case Occasion.family || Occasion.other:
        break;
    }
    return s;
  }

  final sorted = [...photos]
    ..sort((a, b) {
      final c = score(b).compareTo(score(a));
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  return sorted.first;
}

extension on String {
  /// First user-perceived character (good enough for initials).
  String get characters0 =>
      isEmpty ? '' : String.fromCharCode(runes.first).toUpperCase();
}

/// Reads the caption set back out of an album (for re-layouts).
CaptionSet captionsOf(Album album) {
  final caps = <PhotoCaption>[];
  for (final p in album.pages) {
    for (final t in p.texts) {
      if (!t.id.startsWith('cap_')) continue;
      final i = int.tryParse(t.id.split('_').last);
      if (i == null || i >= p.frames.length) continue;
      final pid = p.frames[i].photoId;
      if (pid != null) caps.add(PhotoCaption(photoId: pid, text: t.text));
    }
  }
  return CaptionSet(
    title: album.title,
    subtitle: album.subtitle ?? '',
    chapters: [
      for (final c in album.chapters)
        ChapterText(id: c.id, title: c.title, intro: c.intro ?? ''),
    ],
    captions: caps,
    backCover: album.cover.backText ?? '',
  );
}

/// Plans back from an existing album (chapters + their photos in order).
List<ChapterPlan> plansOf(Album album) {
  final byChapter = <String, List<String>>{};
  for (final p in album.pages) {
    final id = p.chapterId;
    if (id == null || p.templateId == 'chapter_opener') continue;
    for (final f in p.frames) {
      final pid = f.photoId;
      if (pid == null) continue;
      final list = byChapter.putIfAbsent(id, () => []);
      if (!list.contains(pid)) list.add(pid);
    }
  }
  return [
    for (final c in album.chapters) ChapterPlan(c, byChapter[c.id] ?? []),
  ];
}
