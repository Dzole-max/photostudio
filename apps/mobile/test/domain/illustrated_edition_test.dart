import 'package:flutter_test/flutter_test.dart';
import 'package:memoria/domain/illustration/comic.dart';
import 'package:memoria/domain/illustration/illustrated_edition.dart';
import 'package:memoria/domain/model/album.dart';
import 'package:memoria/domain/preflight/preflight.dart';

import '../helpers/domain_fixtures.dart';
import '../helpers/sample_books.dart';

/// Stand-in for the StyleProvider: same pixels, new ids.
Map<String, PhotoRef> fakeArtwork(Album album, Set<String> ids, String style) =>
    {
      for (final id in ids)
        id: album.photos[id]!.copyWith(
          id: '$id~$style',
          artwork: true,
          sourceId: id,
        ),
    };

Album illustrate(
  Album album,
  IllustrationStyle style,
  IllustrationScope scope,
) {
  final pages = illustratedPages(album, scope);
  final ids = photosToIllustrate(album, pages);
  return buildIllustratedAlbum(
    album: album,
    newId: 'ill',
    artwork: fakeArtwork(album, ids, style.name),
    pages: pages,
    style: style,
    fonts: DomainFixtures.fonts,
    now: kTestNow,
  );
}

void main() {
  for (final set in ['wedding', 'travel']) {
    group(set, () {
      final book = buildSampleBook(set);

      test('whole book: every photo redrawn, new id, edition flags', () {
        final ill = illustrate(
          book,
          IllustrationStyle.watercolor,
          IllustrationScope.wholeBook,
        );
        expect(ill.id, 'ill');
        expect(ill.flags.edition, Edition.illustrated);
        expect(ill.flags.illustrationStyle, IllustrationStyle.watercolor);
        for (final p in [...ill.pages, ill.cover.front]) {
          for (final f in p.frames.where((f) => f.photoId != null)) {
            expect(f.photoId, endsWith('~watercolor'));
            expect(ill.photos[f.photoId]!.artwork, isFalse);
          }
        }
        expect(ill.pages.length, book.pages.length);
      });

      test('comic: photo pages become panels with lettered bubbles', () {
        final ill = illustrate(
          book,
          IllustrationStyle.comic,
          IllustrationScope.wholeBook,
        );
        final comic = ill.pages
            .where((p) => kComicTemplates.contains(p.templateId))
            .toList();
        expect(comic, isNotEmpty);
        for (final p in comic) {
          expect(p.frames.length, inInclusiveRange(1, 4));
          for (final f in p.frames) {
            expect(f.borderMm, greaterThan(0));
          }
        }
        final bubbles = comic.where(
          (p) => p.texts.any((t) => t.role == TextRole.caption),
        );
        expect(bubbles, isNotEmpty);
        // Lettering fits and stays in the safe area.
        final report = runPreflight(ill, DomainFixtures.fonts);
        final comicIdx = {
          for (var i = 0; i < ill.pages.length; i++)
            if (kComicTemplates.contains(ill.pages[i].templateId)) i,
        };
        final issues = report.issues.where(
          (i) =>
              i.pageIndex != null &&
              comicIdx.contains(i.pageIndex) &&
              i.severity != Severity.info,
        );
        expect(issues.map((i) => '${i.pageIndex}:${i.rule.id}'), isEmpty);
      });

      test('hybrid: cover and one page per chapter', () {
        final pages = illustratedPages(
          book,
          IllustrationScope.coverAndChapterPages,
        );
        final chapters = {for (final i in pages) book.pages[i].chapterId};
        expect(chapters.length, pages.length);
        expect(pages.length, lessThanOrEqualTo(book.chapters.length + 1));
        final ill = illustrate(
          book,
          IllustrationStyle.inkSketch,
          IllustrationScope.coverAndChapterPages,
        );
        final redrawnPages = [
          for (var i = 0; i < ill.pages.length; i++)
            if (ill.pages[i].frames.any(
              (f) => f.photoId?.endsWith('~inkSketch') ?? false,
            ))
              i,
        ];
        expect(redrawnPages.toSet(), pages);
        expect(
          ill.cover.front.frames
              .where((f) => f.photoId != null)
              .every((f) => f.photoId!.endsWith('~inkSketch')),
          isTrue,
        );
      });
    });
  }

  test('character sheet sources are portraits from the book', () {
    final book = buildSampleBook('wedding');
    final sources = characterSources(book);
    expect(sources, isNotEmpty);
    expect(sources.length, lessThanOrEqualTo(3));
    for (final s in sources) {
      expect(s.faces, isNotEmpty);
      expect(book.usedPhotoIds, contains(s.id));
    }
  });
}
