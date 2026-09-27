import 'package:flutter_test/flutter_test.dart';
import 'package:memoria/domain/layout/album_ops.dart';
import 'package:memoria/domain/layout/dedication.dart';
import 'package:memoria/domain/layout/series_spine.dart';
import 'package:memoria/domain/model/album.dart';
import 'package:memoria/domain/photos/replace_photo.dart';
import 'package:memoria/domain/preflight/preflight.dart';

import '../helpers/domain_fixtures.dart';
import '../helpers/sample_books.dart';

void main() {
  late Album book;
  late AlbumOps ops;

  setUpAll(() {
    book = buildSampleBook('wedding');
    ops = AlbumOps(
      fonts: DomainFixtures.fonts,
      geo: DomainFixtures.geo,
      clock: () => kTestNow,
    );
  });

  group('enhance for print', () {
    test('the enhanced photo replaces the original everywhere', () {
      final id = book.pages
          .expand((p) => p.frames)
          .firstWhere((f) => f.photoId != null)
          .photoId!;
      final original = book.photos[id]!;
      final enhanced = original.copyWith(
        id: '$id~enhanced',
        width: original.width * 2,
        height: original.height * 2,
        artwork: true,
      );
      final out = replacePhoto(book, id, enhanced);
      expect(out.photos.containsKey(id), isFalse);
      expect(out.photos['$id~enhanced']!.artwork, isFalse);
      expect(out.photos['$id~enhanced']!.sourceId, id);
      final frames = [
        ...out.pages.expand((p) => p.frames),
        ...out.cover.front.frames,
      ];
      expect(frames.where((f) => f.photoId == id), isEmpty);
      expect(frames.where((f) => f.photoId == '$id~enhanced'), isNotEmpty);
    });

    test('doubling the pixels clears a low-dpi warning', () {
      // Shrink one photo so it prints under 200 dpi, then enhance it.
      final frame = book.pages
          .expand((p) => p.frames)
          .firstWhere((f) => f.photoId != null);
      final id = frame.photoId!;
      final small = book.photos[id]!.copyWith(width: 700, height: 467);
      final low = book.copyWith(photos: {...book.photos, id: small});
      bool lowDpi(Album a) => runPreflight(a, DomainFixtures.fonts).issues.any(
        (i) => i.rule == PreflightRule.lowDpi && i.elementId == frame.id,
      );
      expect(lowDpi(low), isTrue);
      final fixed = replacePhoto(
        low,
        id,
        small.copyWith(id: '$id~enhanced', width: 1400 * 2, height: 934 * 2),
      );
      expect(lowDpi(fixed), isFalse);
    });
  });

  group('handwritten dedication', () {
    final strokes = <InkStroke>[
      [(0.1, 0.5), (0.2, 0.3), (0.3, 0.6), (0.4, 0.4)],
      [(0.6, 0.5)],
    ];

    test('strokes become ink paths inside the dedication area', () {
      final out = applyDedication(book, strokes);
      final ink = out.pages.first.ornaments.where(isDedication).toList();
      expect(ink, hasLength(2));
      expect(ink.first.path, startsWith('M '));
      expect(ink.first.path, contains(' Q '));
      expect(ink.first.color, kDedicationInk);
      expect(hasDedication(out), isTrue);
      expect(hasDedication(applyDedication(out, const [])), isFalse);
      // Replacing keeps one set, not two.
      final again = applyDedication(out, strokes);
      expect(again.pages.first.ornaments.where(isDedication), hasLength(2));
    });

    test('survives a re-layout to another format', () {
      final withInk = applyDedication(book, strokes);
      final other = ops.relayout(withInk, formatId: 'landscape_28');
      expect(other.pages.first.ornaments.where(isDedication), hasLength(2));
    });

    test('ink passes the print check', () {
      final out = applyDedication(book, strokes);
      final issues = runPreflight(
        out,
        DomainFixtures.fonts,
      ).issues.where((i) => i.pageIndex == 0 && i.severity != Severity.info);
      expect(issues, isEmpty);
    });
  });

  group('series spines', () {
    test('a series always gets the same colour', () {
      expect(seriesColor('Family'), seriesColor(' family '));
      expect(kSeriesSpineColors, contains(seriesColor('Summers')));
    });

    test('books in a series share the spine design', () {
      // Spine text needs at least 6 mm; thin books share the colour only.
      final thick = book.copyWith(cover: book.cover.copyWith(spineMm: 10));
      expect(ops.setSeries(book, 'Family', 1).cover.spine.texts, isEmpty);
      final a = ops.setSeries(thick, 'Family', 1);
      final b = ops.setSeries(buildSampleBook('travel'), 'Family', 2);
      expect(a.cover.spine.templateId, 'spine_series');
      expect(a.cover.spine.background!.color, b.cover.spine.background!.color);
      final volume = a.cover.spine.texts.firstWhere(
        (t) => t.id == 'spine_volume',
      );
      expect(volume.text, '1');
      expect(
        a.cover.spine.texts.map((t) => t.id),
        containsAll(['spine_series', 'spine']),
      );
    });

    test('kept on re-layout, removed when leaving the series', () {
      final a = ops.setSeries(book, 'Family', 3);
      final shuffled = ops.shuffle(a);
      expect(shuffled.series, 'Family');
      expect(shuffled.seriesVolume, 3);
      expect(shuffled.cover.spine.templateId, 'spine_series');
      final out = ops.setSeries(a, null, null);
      expect(out.series, isNull);
      expect(out.cover.spine.templateId, 'spine');
    });
  });

  test('re-layout keeps edition flags', () {
    final a = book.copyWith(
      flags: book.flags.copyWith(
        edition: Edition.livingMemories,
        sample: true,
        videoPath: '/v.mp4',
      ),
    );
    final out = ops.shuffle(a);
    expect(out.flags.edition, Edition.livingMemories);
    expect(out.flags.sample, isTrue);
    expect(out.flags.videoPath, '/v.mp4');
  });
}
