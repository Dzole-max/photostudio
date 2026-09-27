import '../geo/geo_data.dart';
import '../model/album.dart';
import '../model/captions.dart';
import '../model/geometry.dart';
import '../spec/book_format.dart';
import '../spec/book_strings.dart';
import '../text/font_registry.dart';
import '../theme/book_theme.dart';
import '../theme/theme_tinter.dart';
import 'cover_composer.dart';
import 'dedication.dart';
import 'layout_engine.dart';
import 'page_composer.dart';
import 'series_spine.dart';
import 'templates.dart';

/// Pure editing operations on an album. Each returns a new, fully
/// recomposed album; the editor keeps the previous one for undo.
class AlbumOps {
  AlbumOps({
    required this.fonts,
    this.geo,
    this.brandMark = 'MEMORIA',
    this.spineMm = fakeSpineMm,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  final FontRegistry fonts;
  final GeoData? geo;
  final String brandMark;
  final double Function(int innerPages) spineMm;
  final DateTime Function() clock;

  ComposeEnv envFor(Album a) => ComposeEnv(
    format: BookFormat.byId(a.formatId),
    theme: BookTheme.byId(a.themeId),
    accent: a.accentColor,
    strings: BookStrings(a.language),
    fonts: fonts,
    photos: a.photos,
    chapters: a.chapters,
    geo: geo,
    seed: a.seed,
    year: a.createdAt.year,
  );

  /// Recomposes every page from its content (after reorders, theme or accent
  /// changes) and refreshes chapter starts, page numbers and the cover.
  Album recompose(Album a, {List<PageContent>? contents}) {
    final list = contents ?? [for (final p in a.pages) contentOf(p)];
    final ids = contents == null ? [for (final p in a.pages) p.id] : null;
    final starts = <String, int>{};
    for (var i = 0; i < list.length; i++) {
      final id = list[i].chapterId;
      if (id != null) starts.putIfAbsent(id, () => i);
    }
    final chapters = [
      for (final c in a.chapters)
        c.copyWith(startPageIndex: starts[c.id] ?? c.startPageIndex),
    ];
    final withChapters = a.copyWith(chapters: chapters);
    final env = envFor(withChapters);
    final used = <String>{};
    String idFor(int i) {
      var id = ids != null && i < ids.length ? ids[i] : 'p${i + 1}';
      while (used.contains(id)) {
        id = '${id}x';
      }
      used.add(id);
      return id;
    }

    final pages = [
      for (var i = 0; i < list.length; i++)
        composePage(list[i], i, env, id: idFor(i)),
    ];
    return withSeriesSpine(
      withChapters.copyWith(
        pages: pages,
        cover: _recomposeCover(withChapters, env, pages.length),
        updatedAt: clock(),
      ),
    );
  }

  CoverDesign _recomposeCover(Album a, ComposeEnv env, int innerPages) =>
      composeCover(
        templateId: a.cover.templateId,
        slots: a.cover.slots,
        env: env,
        spineMm: spineMm(innerPages),
        spineText: a.cover.spineText ?? a.title,
        backText: a.cover.backText,
        backMark: brandMark,
      );

  List<PageContent> _contents(Album a) => [
    for (final p in a.pages) contentOf(p),
  ];

  // -------------------------------------------------------------------------
  // Pages

  Album movePage(Album a, int from, int to) {
    final list = _contents(a);
    final ids = [for (final p in a.pages) p.id];
    final item = list.removeAt(from);
    final id = ids.removeAt(from);
    list.insert(to.clamp(0, list.length), item);
    ids.insert(to.clamp(0, ids.length), id);
    return _withIds(recompose(a, contents: list), ids);
  }

  Album _withIds(Album a, List<String> ids) => a.copyWith(
    pages: [
      for (var i = 0; i < a.pages.length; i++)
        a.pages[i].copyWith(
          id: i < ids.length ? ids[i] : a.pages[i].id,
          frames: [
            for (var f = 0; f < a.pages[i].frames.length; f++)
              a.pages[i].frames[f].copyWith(
                id: '${i < ids.length ? ids[i] : a.pages[i].id}_f$f',
              ),
          ],
        ),
    ],
  );

  /// Adds a page after [index]: a hero page with [photoId], or a note page.
  Album addPage(Album a, int index, {String? photoId}) {
    final list = _contents(a);
    final chapterId = index >= 0 && index < list.length
        ? list[index].chapterId
        : null;
    list.insert(
      (index + 1).clamp(0, list.length),
      photoId == null
          ? PageContent(templateId: 'blank_note', chapterId: chapterId)
          : PageContent(
              templateId: 'hero_centered',
              chapterId: chapterId,
              photoIds: [photoId],
            ),
    );
    return recompose(a, contents: list);
  }

  /// Removes a page; its photos go back to the unused tray.
  Album removePage(Album a, int index) {
    final list = _contents(a)..removeAt(index);
    return recompose(a, contents: list);
  }

  Album swapTemplate(
    Album a,
    int pageIndex,
    String templateId, {
    bool mirrored = false,
  }) {
    final list = _contents(a);
    final c = list[pageIndex];
    final t = PageTemplate.byId(templateId);
    final photos = c.photoIds.whereType<String>().toList();
    c.templateId = templateId;
    c.mirrored = mirrored;
    // Fill or trim slots to the template's capacity; extra photos return to
    // the tray.
    c.photoIds = photos.take(t.maxPhotos).toList();
    c.userCrops = {};
    c.captions.removeWhere((k, _) => k >= c.photoIds.length);
    return recompose(a, contents: list);
  }

  /// Puts [photoId] into a frame (replace / drop from tray).
  Album setPhoto(Album a, int pageIndex, int frameIndex, String photoId) {
    final list = _contents(a);
    final c = list[pageIndex];
    while (c.photoIds.length <= frameIndex) {
      c.photoIds.add(null);
    }
    c.photoIds[frameIndex] = photoId;
    c.userCrops.remove(frameIndex);
    return recompose(a, contents: list);
  }

  /// Swaps two frames' photos (possibly across pages).
  Album swapPhotos(Album a, (int, int) first, (int, int) second) {
    final list = _contents(a);
    final (p1, f1) = first;
    final (p2, f2) = second;
    final c1 = list[p1], c2 = list[p2];
    final tmp = c1.photoIds[f1];
    c1.photoIds[f1] = c2.photoIds[f2];
    c2.photoIds[f2] = tmp;
    final cap1 = c1.captions.remove(f1), cap2 = c2.captions.remove(f2);
    if (cap2 != null) c1.captions[f1] = cap2;
    if (cap1 != null) c2.captions[f2] = cap1;
    c1.userCrops.remove(f1);
    c2.userCrops.remove(f2);
    return recompose(a, contents: list);
  }

  /// Removes a photo from a page and picks a template for the rest.
  Album removePhoto(Album a, int pageIndex, int frameIndex) {
    final list = _contents(a);
    final c = list[pageIndex];
    final ids = [...c.photoIds]..removeAt(frameIndex);
    final remaining = ids.whereType<String>().toList();
    if (remaining.isEmpty &&
        PageTemplate.byId(c.templateId).kind == TemplateKind.photo) {
      list.removeAt(pageIndex);
      return recompose(a, contents: list);
    }
    final caps = <int, String>{};
    for (final e in c.captions.entries) {
      if (e.key < frameIndex) caps[e.key] = e.value;
      if (e.key > frameIndex) caps[e.key - 1] = e.value;
    }
    final template = PageTemplate.byId(c.templateId);
    c.photoIds = remaining;
    c.captions = caps;
    c.userCrops = {};
    if (!template.accepts(remaining.length) &&
        template.kind == TemplateKind.photo) {
      c.templateId = templateForCount(
        remaining.length,
        BookTheme.byId(a.themeId).playful,
      );
      c.mirrored = false;
    }
    return recompose(a, contents: list);
  }

  /// "Make hero": moves the photo to its own full page right after.
  Album makeHero(Album a, int pageIndex, int frameIndex) {
    final list = _contents(a);
    final c = list[pageIndex];
    final photoId = c.photoIds[frameIndex];
    if (photoId == null) return a;
    if (c.photoIds.whereType<String>().length == 1) {
      c.templateId = 'hero_bordered';
      return recompose(a, contents: list);
    }
    final caption = c.captions[frameIndex];
    final withoutHero = removePhoto(a, pageIndex, frameIndex);
    final list2 = _contents(withoutHero);
    list2.insert(
      pageIndex + 1,
      PageContent(
        templateId: 'hero_bordered',
        chapterId: c.chapterId,
        photoIds: [photoId],
        captions: {0: ?caption},
      ),
    );
    return recompose(withoutHero, contents: list2);
  }

  Album setCrop(Album a, int pageIndex, int frameIndex, CropRect crop) {
    final list = _contents(a);
    list[pageIndex].userCrops[frameIndex] = crop;
    return recompose(a, contents: list);
  }

  Album resetCrop(Album a, int pageIndex, int frameIndex) {
    final list = _contents(a);
    list[pageIndex].userCrops.remove(frameIndex);
    return recompose(a, contents: list);
  }

  /// Edits a text block's content (captions, titles, intros...).
  Album setText(Album a, int pageIndex, String textId, String text) {
    final list = _contents(a);
    final c = list[pageIndex];
    final block = a.pages[pageIndex].texts.firstWhere((t) => t.id == textId);
    if (textId.startsWith('cap_')) {
      final i = int.parse(textId.split('_').last);
      c.captions[i] = text;
    } else {
      switch (block.role) {
        case TextRole.title || TextRole.chapter:
          c.title = text;
          if (c.chapterId != null &&
              a.pages[pageIndex].templateId == 'chapter_opener') {
            a = a.copyWith(
              chapters: [
                for (final ch in a.chapters)
                  ch.id == c.chapterId ? ch.copyWith(title: text) : ch,
              ],
            );
          }
        case TextRole.subtitle:
          c.subtitle = text;
        case TextRole.body:
          c.body = text;
        case TextRole.date || TextRole.label:
          c.label = text;
        default:
          break;
      }
    }
    if (a.pages[pageIndex].templateId == 'title_page' &&
        block.role == TextRole.title) {
      a = a.copyWith(
        title: text,
        cover: a.cover.copyWith(
          slots: a.cover.slots.copyWith(title: text),
          spineText: text,
        ),
      );
    }
    return recompose(a, contents: list);
  }

  /// Adds a caption under a photo (or edits an existing one).
  Album setCaption(Album a, int pageIndex, int frameIndex, String text) {
    final list = _contents(a);
    if (text.trim().isEmpty) {
      list[pageIndex].captions.remove(frameIndex);
    } else {
      list[pageIndex].captions[frameIndex] = text.trim();
    }
    return recompose(a, contents: list);
  }

  Album styleText(
    Album a,
    int pageIndex,
    String textId, {
    required double sizePt,
    required TextAlignKind align,
  }) {
    final list = _contents(a);
    list[pageIndex].textOverrides[textId] = TextOverride(
      sizePt: sizePt,
      align: align,
    );
    return recompose(a, contents: list);
  }

  // -------------------------------------------------------------------------
  // Book-wide

  Album setTitle(Album a, String title) => recompose(
    a.copyWith(
      title: title,
      cover: a.cover.copyWith(
        slots: a.cover.slots.copyWith(title: title),
        spineText: title,
      ),
    ),
    contents: [
      for (final c in _contents(a))
        if (c.templateId == 'title_page') (c..title = title) else c,
    ],
  );

  Album changeTheme(Album a, String themeId) {
    final theme = BookTheme.byId(themeId);
    final hero = a.cover.slots.heroPhotoId == null
        ? null
        : a.photos[a.cover.slots.heroPhotoId];
    final accent = const ThemeTinter().tint(theme.accent, hero?.dominantHue);
    final contents = _contents(a);
    // Polaroids only suit playful themes.
    if (!theme.playful) {
      for (final c in contents) {
        if (c.templateId == 'polaroid_scatter') {
          c.templateId = templateForCount(
            c.photoIds.whereType<String>().length,
            false,
          );
        }
      }
    }
    return recompose(
      a.copyWith(
        themeId: themeId,
        accentColor: accent,
        cover: a.cover.copyWith(templateId: theme.defaultCover),
      ),
      contents: contents,
    );
  }

  Album setAccent(Album a, String hex) =>
      recompose(a.copyWith(accentColor: hex));

  Album changeCoverTemplate(Album a, String templateId) =>
      recompose(a.copyWith(cover: a.cover.copyWith(templateId: templateId)));

  Album updateCoverSlots(Album a, CoverSlots slots) {
    final title = slots.title ?? a.title;
    return recompose(
      a.copyWith(
        title: title,
        cover: a.cover.copyWith(slots: slots, spineText: title),
      ),
      contents: [
        for (final c in _contents(a))
          if (c.templateId == 'title_page') (c..title = title) else c,
      ],
    );
  }

  Album setCoverFinish(Album a, CoverFinish finish) =>
      a.copyWith(coverFinish: finish, updatedAt: clock());

  /// Full re-layout (format or language change, "Shuffle design").
  Album relayout(Album a, {String? formatId, String? language, int? seed}) {
    final format = BookFormat.byId(formatId ?? a.formatId);
    final lang = language ?? a.language;
    final captions = captionsOf(a);
    final input = LayoutInput(
      albumId: a.id,
      occasion: a.occasion,
      theme: BookTheme.byId(a.themeId),
      format: format,
      language: lang,
      photos: a.photos,
      plans: plansOf(a),
      captions: captions,
      story: a.story,
      fonts: fonts,
      geo: geo,
      seed: seed ?? a.seed,
      now: clock(),
      coverTemplateId: a.cover.templateId,
      spineMm: spineMm,
      brandMark: brandMark,
      coverSlots: language == null ? a.cover.slots : null,
      createdAt: a.createdAt,
      accentOverride: a.accentColor,
    );
    final laid = layoutAlbum(input);
    return keepDedication(
      a,
      withSeriesSpine(
        laid.copyWith(
          coverFinish: a.coverFinish,
          status: a.status,
          series: a.series,
          seriesVolume: a.seriesVolume,
          flags: laid.flags.copyWith(
            sample: a.flags.sample,
            edition: a.flags.edition,
            illustrationStyle: a.flags.illustrationStyle,
            videoPath: a.flags.videoPath,
          ),
        ),
      ),
    );
  }

  /// Puts the book in a series (null takes it out): the spine switches to
  /// the series design shared by every book in it.
  Album setSeries(Album a, String? series, int? volume) {
    final name = series?.trim();
    if (name == null || name.isEmpty) {
      final out = a.copyWith(
        series: null,
        seriesVolume: null,
        updatedAt: clock(),
      );
      return out.copyWith(
        cover: _recomposeCover(out, envFor(out), out.pages.length),
      );
    }
    return withSeriesSpine(
      a.copyWith(series: name, seriesVolume: volume, updatedAt: clock()),
    );
  }

  Album shuffle(Album a) => relayout(a, seed: a.seed + 1);

  /// Includes or excludes a photo from the book entirely (curation sheet
  /// after the book exists).
  Album setExcluded(Album a, String photoId, bool excluded) {
    final p = a.photos[photoId];
    if (p == null) return a;
    return a.copyWith(
      photos: {
        ...a.photos,
        photoId: p.copyWith(
          isExcluded: excluded,
          excludedReason: excluded ? ExclusionReason.user : null,
        ),
      },
    );
  }

  /// Photos in the album that are not placed on any page (the editor tray).
  static List<PhotoRef> unused(Album a) {
    final used = a.usedPhotoIds;
    return a.photos.values
        .where((p) => !used.contains(p.id) && !p.isExcluded && !p.artwork)
        .toList()
      ..sort(
        (x, y) => (x.takenAt ?? DateTime.utc(0)).compareTo(
          y.takenAt ?? DateTime.utc(0),
        ),
      );
  }

  static CaptionSet captions(Album a) => captionsOf(a);
}
