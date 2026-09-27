import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:memoria/domain/layout/chapters.dart';
import 'package:memoria/domain/layout/layout_engine.dart';
import 'package:memoria/domain/layout/smart_crop.dart';
import 'package:memoria/domain/layout/templates.dart';
import 'package:memoria/domain/model/album.dart';
import 'package:memoria/domain/model/captions.dart';
import 'package:memoria/domain/model/geometry.dart';
import 'package:memoria/domain/preflight/preflight.dart';
import 'package:memoria/domain/spec/book_format.dart';
import 'package:memoria/domain/spec/book_strings.dart';
import 'package:memoria/domain/theme/book_theme.dart';

import '../helpers/domain_fixtures.dart';
import '../helpers/sample_books.dart';

void main() {
  group('sample books', () {
    late Album wedding;
    late Album travel;

    setUpAll(() {
      wedding = buildSampleBook('wedding');
      travel = buildSampleBook('travel');
    });

    test('page count is in range and even', () {
      for (final a in [wedding, travel]) {
        final f = BookFormat.byId(a.formatId);
        expect(a.pages.length, inInclusiveRange(f.minPages, f.maxPages));
        expect(a.pages.length.isEven, isTrue);
        expect(a.pages.length, greaterThanOrEqualTo(30));
      }
    });

    test('title page first, colophon last, map after title for travel', () {
      expect(wedding.pages.first.templateId, 'title_page');
      expect(wedding.pages.last.templateId, 'colophon');
      expect(travel.pages[1].templateId, 'map_page');
      expect(wedding.pages.any((p) => p.templateId == 'map_page'), isFalse);
    });

    test('travel chapters follow the places in order', () {
      expect(travel.chapters.map((c) => c.title), [
        'Stone Town',
        'Nungwi',
        'Jozani Forest',
      ]);
      expect(travel.title, 'Zanzibar');
      expect(travel.subtitle, 'July 2026');
      for (final c in travel.chapters) {
        expect(travel.pages[c.startPageIndex].templateId, 'chapter_opener');
      }
    });

    test('wedding chapters are the parts of the day', () {
      expect(wedding.chapters.map((c) => c.title), [
        'Getting ready',
        'The ceremony',
        'Portraits',
        'The celebration',
      ]);
      expect(wedding.title, 'Aleksandar & Elena');
      expect(wedding.cover.templateId, 'cover_wedding_monogram');
      expect(wedding.cover.slots.monogram, 'A & E');
    });

    test('pacing: never more than two grid pages in a row', () {
      for (final a in [wedding, travel]) {
        var run = 0;
        for (final p in a.pages) {
          run = PageTemplate.byId(p.templateId).isGrid ? run + 1 : 0;
          expect(run, lessThanOrEqualTo(2));
        }
      }
    });

    test('at most one full-bleed page per spread', () {
      for (final a in [wedding, travel]) {
        for (var i = 1; i + 1 < a.pages.length; i += 2) {
          final left = PageTemplate.byId(a.pages[i].templateId);
          final right = PageTemplate.byId(a.pages[i + 1].templateId);
          if (left.panorama && right.panorama) continue;
          expect(
            left.fullBleed && right.fullBleed,
            isFalse,
            reason: 'spread $i',
          );
        }
      }
    });

    test('every placed photo appears once and crops keep faces whole', () {
      for (final a in [wedding, travel]) {
        final seen = <String>{};
        for (final p in a.pages) {
          if (p.templateId == 'spread_panorama' && p.mirrored) continue;
          for (final f in p.frames) {
            final id = f.photoId!;
            expect(seen.add(id), isTrue, reason: 'duplicate $id');
            final photo = a.photos[id]!;
            final inner = f.borderMm > 0
                ? f.rectMm.deflate(f.borderMm)
                : f.rectMm;
            // Crop aspect matches the frame aspect.
            final cropAspect =
                f.crop.w * photo.width / (f.crop.h * photo.height);
            expect(cropAspect, closeTo(inner.aspect, 0.02));
            final fits = smartCrop(photo, inner.aspect).facesSafe;
            if (fits) {
              expect(
                facesInside(photo, f.crop),
                isTrue,
                reason: '$id on ${p.id}',
              );
            }
          }
        }
        // Every included photo is used.
        final included = a.photos.values
            .where((p) => !p.isExcluded)
            .map((p) => p.id)
            .toSet();
        expect(seen, included);
      }
    });

    test('sample books pass preflight', () {
      for (final a in [wedding, travel]) {
        final report = runPreflight(a, DomainFixtures.fonts);
        expect(
          report.issues.map((i) => '${i.rule.id}@${i.pageIndex}'),
          isEmpty,
        );
      }
    });

    test('page numbers on outer bottom corners, hidden on full-bleed and special pages', () {
      final f = BookFormat.byId(travel.formatId);
      for (var i = 0; i < travel.pages.length; i++) {
        final page = travel.pages[i];
        final pn = page.texts
            .where((t) => t.role == TextRole.pageNumber)
            .toList();
        final t = PageTemplate.byId(page.templateId);
        if (t.fullBleed ||
            const {'title_page', 'colophon'}.contains(page.templateId)) {
          expect(pn, isEmpty);
          continue;
        }
        expect(pn, hasLength(1));
        final r = pn.single.rectMm;
        expect(r.bottom, closeTo(f.trimHMm - 8, 0.01));
        if (BookFormat.sideOf(i) == PageSide.right) {
          expect(r.right, closeTo(f.trimWMm - 8, 0.01));
        } else {
          expect(r.x, closeTo(8, 0.01));
        }
      }
    });

    test('captions sit 3 mm below their photo in body font, 9 pt, 80 %', () {
      for (final p in wedding.pages) {
        for (final t in p.texts.where((t) => t.id.startsWith('cap_'))) {
          final i = int.parse(t.id.split('_').last);
          if (p.templateId.startsWith('photo_with_text')) continue;
          expect(t.fontFamily, 'Lora');
          expect(t.sizePt, 9);
          expect(t.opacity, 0.8);
          expect(t.rectMm.y - p.frames[i].rectMm.bottom, closeTo(3, 0.01));
        }
      }
    });
  });

  test('deterministic: same input and seed give the same book', () {
    final a = jsonEncode(buildSampleBook('travel', seed: 7).toJson());
    final b = jsonEncode(buildSampleBook('travel', seed: 7).toJson());
    expect(a, b);
    final c = jsonEncode(buildSampleBook('travel', seed: 8).toJson());
    expect(c == a, isFalse, reason: 'shuffle changes the design');
  });

  test('localised book: Macedonian strings throughout', () {
    final mk = buildSampleBook('travel', language: 'mk');
    expect(mk.chapters.first.title, 'Стоун Таун');
    final colophon = mk.pages.last.texts.single;
    expect(colophon.text, startsWith('Изработено со Memoria'));
    expect(runPreflight(mk, DomainFixtures.fonts).canOrder, isTrue);
  });

  test('every format and theme produces a valid book', () {
    for (final f in BookFormat.visible) {
      for (final t in ['wedding_midnight', 'baby_cloud', 'minimal_gallery']) {
        final a = buildSampleBook('wedding', formatId: f.id, themeId: t);
        expect(a.pages.length, inInclusiveRange(f.minPages, f.maxPages));
        expect(a.pages.length.isEven, isTrue);
        final blockers = runPreflight(
          a,
          DomainFixtures.fonts,
        ).issues.where((i) => i.severity == Severity.blocker);
        expect(blockers, isEmpty, reason: '${f.id}/$t');
      }
    }
  });

  test('few photos: pads with note pages and reports it', () {
    final all = DomainFixtures.sample('wedding');
    final few = Map.fromEntries(all.entries.take(8));
    final a = buildSampleBook('wedding', photos: few);
    expect(a.pages.length, 30);
    expect(a.flags.blankPagesAdded, greaterThan(0));
    expect(
      a.pages.where((p) => p.templateId == 'blank_note'),
      hasLength(a.flags.blankPagesAdded),
    );
  });

  test('400 photos lay out in well under 1.5 s', () {
    final base = DomainFixtures.sample('travel').values
        .where((p) => !p.isExcluded)
        .toList();
    final rnd = math.Random(3);
    final photos = <String, PhotoRef>{};
    for (var i = 0; i < 400; i++) {
      final b = base[i % base.length];
      final day = i ~/ 40;
      photos['x$i'] = b.copyWith(
        id: 'x$i',
        takenAt: DateTime.utc(
          2026,
          7,
          3 + day,
          8 + (i % 40) ~/ 4,
          (i * 7) % 60,
        ),
        quality: b.quality.copyWith(overall: rnd.nextDouble()),
      );
    }
    final strings = BookStrings('en');
    final plans = planChapters(photos, Occasion.travel, strings);
    final sw = Stopwatch()..start();
    final a = layoutAlbum(
      LayoutInput(
        albumId: 'big',
        occasion: Occasion.travel,
        theme: BookTheme.byId('travel_lagoon'),
        format: BookFormat.byId('classic_20'),
        language: 'en',
        photos: photos,
        plans: plans,
        captions: const CaptionSet(title: 'Big trip'),
        story: const StoryAnswers(),
        fonts: DomainFixtures.fonts,
        geo: DomainFixtures.geo,
        now: kTestNow,
      ),
    );
    sw.stop();
    expect(sw.elapsedMilliseconds, lessThan(1500));
    expect(a.pages.length, inInclusiveRange(30, 100));
    expect(a.pages.length.isEven, isTrue);
    var run = 0;
    for (final p in a.pages) {
      run = PageTemplate.byId(p.templateId).isGrid ? run + 1 : 0;
      expect(run, lessThanOrEqualTo(2));
    }
  });

  group('smart crop', () {
    const face = FaceBox(x: 0.7, y: 0.3, w: 0.1, h: 0.15);
    const photo = PhotoRef(id: 'p', width: 3000, height: 2000, faces: [face]);

    test('centres on faces and keeps them inside', () {
      final r = smartCrop(photo, 0.8);
      expect(r.facesSafe, isTrue);
      expect(r.crop.h, closeTo(1, 1e-9));
      expect(r.crop.w, closeTo(0.8 / 1.5, 1e-9));
      expect(r.crop.x + r.crop.w, greaterThan(face.x + face.w));
    });

    test('effective dpi', () {
      const p = PhotoRef(id: 'p', width: 2362, height: 2362);
      final dpi = effectiveDpi(
        p,
        CropRect.full,
        const RectMm(x: 0, y: 0, w: 200, h: 200),
      );
      expect(dpi, closeTo(300, 0.5));
    });

    test('gutter avoidance moves faces away from the binding', () {
      const p = PhotoRef(
        id: 'p',
        width: 4000,
        height: 2000,
        faces: [FaceBox(x: 0.26, y: 0.3, w: 0.06, h: 0.1)],
      );
      const rect = RectMm(x: -4, y: -4, w: 208, h: 208);
      final crop = smartCrop(p, rect.aspect).crop.copyWith(x: 0.25);
      expect(faceNearGutter(p, crop, rect, gutterX: 0, minDistMm: 12), isTrue);
      final moved = avoidGutter(p, crop, rect, gutterX: 0, minDistMm: 12);
      expect(
        faceNearGutter(p, moved, rect, gutterX: 0, minDistMm: 12),
        isFalse,
      );
    });
  });
}
