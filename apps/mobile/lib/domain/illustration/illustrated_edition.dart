import '../model/album.dart';
import '../spec/book_format.dart';
import '../text/font_registry.dart';
import 'comic.dart';

/// How much of the book is redrawn.
enum IllustrationScope {
  /// Every photo in the book.
  wholeBook,

  /// The cover and one page per chapter; the rest stays photographic.
  coverAndChapterPages,
}

/// Indices of the pages that get illustrated.
Set<int> illustratedPages(Album album, IllustrationScope scope) {
  final photoPages = <int>[
    for (var i = 0; i < album.pages.length; i++)
      if (album.pages[i].frames.any((f) => f.photoId != null)) i,
  ];
  if (scope == IllustrationScope.wholeBook) return photoPages.toSet();
  // One page per chapter: the one with the most people on it.
  final best = <String?, int>{};
  int people(int i) => album.pages[i].frames
      .map((f) => album.photos[f.photoId]?.faces.length ?? 0)
      .fold(0, (a, b) => a + b);
  for (final i in photoPages) {
    final ch = album.pages[i].chapterId;
    final current = best[ch];
    if (current == null || people(i) > people(current)) best[ch] = i;
  }
  return best.values.toSet();
}

/// Photo ids to redraw: those on [pages] plus the cover's photos.
Set<String> photosToIllustrate(Album album, Set<int> pages) => {
  for (final i in pages)
    for (final f in album.pages[i].frames)
      if (f.photoId != null && album.photos.containsKey(f.photoId)) f.photoId!,
  for (final f in album.cover.front.frames)
    if (f.photoId != null && album.photos.containsKey(f.photoId)) f.photoId!,
};

/// Main characters for the character sheet: the people in the book's best
/// portraits (largest faces first), at most [max] photos.
List<PhotoRef> characterSources(Album album, {int max = 3}) {
  final used = album.usedPhotoIds;
  double faceArea(PhotoRef p) =>
      p.faces.map((f) => f.w * f.h).fold(0.0, (a, b) => a > b ? a : b);
  final withFaces =
      album.photos.values
          .where((p) => used.contains(p.id) && p.faces.isNotEmpty && !p.artwork)
          .toList()
        ..sort((a, b) => faceArea(b).compareTo(faceArea(a)));
  return withFaces.take(max).toList();
}

/// Builds the illustrated edition from [album]: redrawn photos replace the
/// originals on the chosen pages and on the cover; with the comic style
/// those pages become comic panels with speech bubbles.
///
/// [artwork] maps an original photo id to its redrawn version. The new
/// album gets its own id and is a book in its own right.
Album buildIllustratedAlbum({
  required Album album,
  required String newId,
  required Map<String, PhotoRef> artwork,
  required Set<int> pages,
  required IllustrationStyle style,
  required FontRegistry fonts,
  required DateTime now,
}) {
  // Redrawn photos are the book's photos now (not cover art), so re-layout
  // and "unused photos" treat them like any other photo.
  final redrawn = {
    for (final e in artwork.entries)
      e.key: e.value.copyWith(artwork: false, sourceId: e.key),
  };
  PhotoFrame swap(PhotoFrame f) {
    final art = redrawn[f.photoId];
    return art == null ? f : f.copyWith(photoId: art.id);
  }

  // Originals stay only where a page that is not redrawn still shows them.
  final stillShown = <String>{
    for (var i = 0; i < album.pages.length; i++)
      if (!pages.contains(i))
        for (final f in album.pages[i].frames)
          if (f.photoId != null) f.photoId!,
    for (final f in album.cover.back.frames)
      if (f.photoId != null) f.photoId!,
  };
  final photos = <String, PhotoRef>{
    for (final p in album.photos.values)
      if (redrawn.containsKey(p.id)
          ? stillShown.contains(p.id)
          : (!p.artwork || album.usedPhotoIds.contains(p.id)))
        p.id: p,
    for (final art in redrawn.values) art.id: art,
  };
  final format = BookFormat.byId(album.formatId);
  final newPages = <BookPage>[
    for (var i = 0; i < album.pages.length; i++)
      if (!pages.contains(i))
        album.pages[i]
      else if (style == IllustrationStyle.comic)
        comicPage(
          page: album.pages[i].copyWith(
            frames: [for (final f in album.pages[i].frames) swap(f)],
          ),
          pageIndex: i,
          format: format,
          photos: photos,
          fonts: fonts,
        )
      else
        album.pages[i].copyWith(
          frames: [for (final f in album.pages[i].frames) swap(f)],
        ),
  ];
  final front = album.cover.front;
  return album.copyWith(
    id: newId,
    photos: photos,
    pages: newPages,
    cover: album.cover.copyWith(
      front: front.copyWith(frames: [for (final f in front.frames) swap(f)]),
      slots: album.cover.slots.copyWith(
        heroPhotoId:
            redrawn[album.cover.slots.heroPhotoId]?.id ??
            album.cover.slots.heroPhotoId,
      ),
    ),
    status: AlbumStatus.draft,
    createdAt: now,
    updatedAt: now,
    flags: album.flags.copyWith(
      edition: Edition.illustrated,
      illustrationStyle: style,
      sample: false,
      videoPath: null,
    ),
  );
}
