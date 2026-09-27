import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memoria/domain/captions/caption_request.dart';
import 'package:memoria/domain/captions/fake_caption_writer.dart';
import 'package:memoria/domain/geo/projection.dart';
import 'package:memoria/domain/layout/chapters.dart';
import 'package:memoria/domain/model/album.dart';
import 'package:memoria/domain/model/geometry.dart';
import 'package:memoria/domain/occasion/occasion_rules.dart';
import 'package:memoria/domain/pricing/pricing.dart';
import 'package:memoria/domain/spec/book_format.dart';
import 'package:memoria/domain/spec/book_strings.dart';
import 'package:memoria/domain/spec/spec_data.dart';
import 'package:memoria/domain/text/text_layout.dart';
import 'package:memoria/domain/theme/color_math.dart';
import 'package:memoria/domain/theme/theme_tinter.dart';

import '../helpers/domain_fixtures.dart';

const _spec = '../../packages/layout_spec';

void main() {
  group('pricing', () {
    final catalog = Catalog.fromJson(
      File('$_spec/fixtures/catalog.json').readAsStringSync(),
    );
    final eu = catalog
        .shippingFor('DE')
        .firstWhere((s) => s.id == 'eu_standard');

    test('base price at the included page count', () {
      final p = priceBook(
        catalog: catalog,
        formatId: 'classic_20',
        innerPages: 30,
        finish: CoverFinish.matte,
        shipping: eu,
      );
      expect(p.bookCents, 3900);
      expect(p.shippingCents, 690);
      expect(p.totalCents, 4590);
    });

    test('extra pages, gloss, copies', () {
      final p = priceBook(
        catalog: catalog,
        formatId: 'classic_20',
        innerPages: 36,
        finish: CoverFinish.gloss,
        copies: 3,
        shipping: eu,
      );
      expect(p.extraPages, 6);
      expect(p.extraPagesCents, 540);
      expect(p.finishCents, 0);
      // (copies − 1) × base × 0.75 = 2 × 39 × 0.75 = 58.50
      expect(p.extraCopiesCents, 5850);
      expect(p.totalCents, 3900 + 540 + 5850 + 690);
    });

    test('formats and shipping regions', () {
      expect(
        priceBook(
          catalog: catalog,
          formatId: 'mini_14',
          innerPages: 30,
          finish: CoverFinish.matte,
        ).totalCents,
        1900,
      );
      expect(
        priceBook(
          catalog: catalog,
          formatId: 'landscape_28',
          innerPages: 40,
          finish: CoverFinish.matte,
        ).totalCents,
        4900 + 900,
      );
      expect(catalog.shippingFor('US').single.id, 'world_standard');
      expect(
        () => priceBook(
          catalog: catalog,
          formatId: 'classic_20',
          innerPages: 30,
          finish: CoverFinish.matte,
          copies: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('projection', () {
    test('fits points inside the rect with padding and keeps aspect', () {
      const rect = RectMm(x: 10, y: 20, w: 180, h: 120);
      final pts = [(39.19, -6.16), (39.30, -5.73), (39.42, -6.27)];
      final proj = FittedProjection.fit(pts, rect);
      for (final (lng, lat) in pts) {
        final (x, y) = proj.project(lng, lat);
        expect(x, inInclusiveRange(rect.x, rect.right));
        expect(y, inInclusiveRange(rect.y, rect.bottom));
      }
      // North is up.
      expect(
        proj.project(39.3, -5.73).$2,
        lessThan(proj.project(39.3, -6.27).$2),
      );
    });

    test('matches the shared fixture (same maths as the render service)', () {
      final fixture = jsonDecode(
        File('$_spec/fixtures/projection.json').readAsStringSync(),
      ) as List<Object?>;
      for (final raw in fixture) {
        final c = raw! as Map<String, Object?>;
        final r = (c['rect']! as List<Object?>).cast<num>();
        final pts = [
          for (final p in c['points']! as List<Object?>)
            if ((p! as List<Object?>).cast<num>() case final xy)
              (xy[0].toDouble(), xy[1].toDouble()),
        ];
        final proj = FittedProjection.fit(
          pts,
          RectMm(
            x: r[0].toDouble(),
            y: r[1].toDouble(),
            w: r[2].toDouble(),
            h: r[3].toDouble(),
          ),
        );
        final expected = c['projected']! as List<Object?>;
        final points = c['points']! as List<Object?>;
        for (var i = 0; i < points.length; i++) {
          final p = (points[i]! as List<Object?>).cast<num>();
          final e = (expected[i]! as List<Object?>).cast<num>();
          final (x, y) = proj.project(p[0].toDouble(), p[1].toDouble());
          expect(x, closeTo(e[0], 1e-6));
          expect(y, closeTo(e[1], 1e-6));
        }
      }
    });

    test('clips polylines to the rect', () {
      const r = RectMm(x: 0, y: 0, w: 10, h: 10);
      final runs = clipPolyline([(-5, 5), (5, 5), (15, 5)], r);
      expect(runs, hasLength(1));
      expect(runs.single.first, (0.0, 5.0));
      expect(runs.single.last, (10.0, 5.0));
    });
  });

  group('text wrap', () {
    test('greedy wrap never exceeds the width', () {
      final m = DomainFixtures.fonts.metrics('Lora', 400);
      const text =
          'The morning in Ohrid, before everything began and the lake was still';
      final lines = wrapText(text, m, 10.5, 120);
      expect(lines.length, greaterThan(1));
      for (final l in lines) {
        expect(m.widthPt(l, 10.5), lessThanOrEqualTo(120));
      }
      expect(lines.join(' '), text);
    });

    test(
      'matches the shared fixture (same algorithm as the render service)',
      () {
        final cases = jsonDecode(
          File('$_spec/fixtures/text_wrap.json').readAsStringSync(),
        ) as List<Object?>;
        for (final raw in cases) {
          final c = raw! as Map<String, Object?>;
          final m = DomainFixtures.fonts.metrics(
            c['family']! as String,
            c['weight']! as int,
          );
          final lines = wrapText(
            c['text']! as String,
            m,
            (c['sizePt']! as num).toDouble(),
            (c['maxWidthPt']! as num).toDouble(),
            trackingPct: (c['trackingPct']! as num).toDouble(),
          );
          expect(
            lines,
            (c['lines']! as List<Object?>).cast<String>(),
            reason: c['text'] as String,
          );
        }
      },
    );

    test('long words break by character', () {
      final m = DomainFixtures.fonts.metrics('Manrope', 600);
      final lines = wrapText('Supercalifragilisticexpialidocious', m, 20, 60);
      expect(lines.length, greaterThan(1));
      expect(lines.join(), 'Supercalifragilisticexpialidocious');
    });
  });

  group('theme tinter', () {
    test('rotates accent at most 15° towards the photo hue', () {
      const tinter = ThemeTinter();
      final accent = Rgb.hex('#1F8A8A').toHsl();
      final tinted = Rgb.hex(tinter.tint('#1F8A8A', 60)).toHsl();
      expect(hueDelta(accent.h, tinted.h).abs(), closeTo(15, 1.5));
      final near = Rgb.hex(tinter.tint('#1F8A8A', accent.h + 5)).toHsl();
      expect(hueDelta(accent.h, near.h).abs(), closeTo(5, 1.5));
      expect(
        tinter.tint('#111111', 60),
        '#111111',
        reason: 'neutral accents stay neutral',
      );
      expect(tinter.tint('#1F8A8A', null), '#1F8A8A');
    });

    test('dominant hue ignores near-white and near-black', () {
      final pixels = [
        for (var i = 0; i < 200; i++) const Rgb(250, 250, 250),
        for (var i = 0; i < 200; i++) const Rgb(5, 5, 5),
        for (var i = 0; i < 100; i++) const Rgb(30, 140, 200),
      ];
      final hue = ThemeTinter.dominantHue(pixels)!;
      expect(hue, closeTo(const Rgb(30, 140, 200).toHsl().h, 3));
      expect(
        ThemeTinter.dominantHue(List.filled(50, const Rgb(128, 128, 128))),
        isNull,
      );
    });
  });

  group('occasion', () {
    test('sample sets are detected', () {
      final w = detectOccasion(
        DomainFixtures.sample('wedding').values.toList(),
        geo: DomainFixtures.geo,
      );
      expect(w.occasion, Occasion.wedding);
      final t = detectOccasion(
        DomainFixtures.sample('travel').values.toList(),
        geo: DomainFixtures.geo,
      );
      expect(t.occasion, Occasion.travel);
      expect(t.destination, 'Zanzibar');
      expect(
        detectOccasion(
          DomainFixtures.sample('travel').values.toList(),
          geo: DomainFixtures.geo,
          language: 'mk',
        ).destination,
        'Занзибар',
      );
    });

    PhotoRef p(
      String id,
      DateTime t, {
      List<PhotoLabel> labels = const [],
      double? lat,
      double? lng,
    }) => PhotoRef(
      id: id,
      width: 10,
      height: 10,
      takenAt: t,
      labels: labels,
      lat: lat,
      lng: lng,
    );

    test('year books, birthdays, babies and far-from-home trips', () {
      final year = [
        for (var i = 0; i < 12; i++) p('y$i', DateTime.utc(2026, i + 1, 3)),
      ];
      expect(detectOccasion(year).occasion, Occasion.family);

      final party = [
        for (var i = 0; i < 20; i++)
          p(
            'b$i',
            DateTime.utc(2026, 5, 3, 15, i),
            labels: i < 4
                ? const [PhotoLabel(text: 'balloon', confidence: 0.9)]
                : const [],
          ),
      ];
      expect(detectOccasion(party).occasion, Occasion.birthday);

      final baby = [
        for (var i = 0; i < 10; i++)
          p(
            'i$i',
            DateTime.utc(2026, 5, 3 + i),
            labels: i < 3
                ? const [PhotoLabel(text: 'baby', confidence: 0.8)]
                : const [],
          ),
      ];
      expect(detectOccasion(baby).occasion, Occasion.baby);

      final away = [
        for (var i = 0; i < 5; i++)
          p('a$i', DateTime.utc(2026, 5, 3, 10 + i), lat: 48.85, lng: 2.35),
      ];
      expect(
        detectOccasion(away, home: (41.99, 21.43)).occasion,
        Occasion.travel,
      );
      final unknown = detectOccasion([
        for (var i = 0; i < 5; i++) p('u$i', DateTime.utc(2026, 5, 3, 10 + i)),
      ]);
      expect(unknown.occasion, Occasion.other);
      expect(
        unknown.fromRules,
        isFalse,
        reason: 'falls back to the AI provider',
      );
    });
  });

  group('fake captions', () {
    for (final lang in BookStrings.supported) {
      test('believable, short and localised in $lang', () {
        final photos = DomainFixtures.sample('travel');
        final plans = planChapters(photos, Occasion.travel, BookStrings(lang));
        final set = FakeCaptionWriter(geo: DomainFixtures.geo).write(
          CaptionRequest(
            occasion: Occasion.travel,
            language: lang,
            story: const StoryAnswers(title: 'Zanzibar 2026'),
            chapters: plans,
            photos: photos,
          ),
        );
        expect(set.title, 'Zanzibar');
        expect(set.chapters, hasLength(3));
        final included = photos.values.where((p) => !p.isExcluded).length;
        expect(set.captions.length, closeTo(included * 0.3, 3));
        for (final c in set.captions) {
          expect(captionWithinLimits(c.text), isTrue, reason: c.text);
          for (final cliche in kClicheList) {
            expect(c.text.toLowerCase(), isNot(contains(cliche)));
          }
        }
        for (final ch in set.chapters) {
          expect(introWithinLimits(ch.intro), isTrue);
        }
        if (lang == 'mk') {
          expect(set.chapters.first.title, 'Стоун Таун');
          expect(
            set.captions.map((c) => c.text),
            contains(startsWith('Стоун Таун')),
          );
        }
      });
    }

    test('"Stone Town, day two" style labels', () {
      expect(
        BookStrings('en').placeDay('Stone Town', 2),
        'Stone Town, day two',
      );
      expect(
        BookStrings('mk').placeDay('Стоун Таун', 2),
        'Стоун Таун, втор ден',
      );
      expect(
        BookStrings('de').dateLong(DateTime.utc(2026, 8, 15)),
        '15. August 2026',
      );
      expect(
        BookStrings('en').coordinates(-6.1659, 39.2026),
        '6.1659° S, 39.2026° E',
      );
      expect(
        BookStrings('mk').coordinates(-6.1659, 39.2026),
        '6.1659° Ј, 39.2026° И',
      );
    });
  });

  group('spec sync', () {
    test('Dart spec data matches packages/layout_spec', () {
      final formats = jsonDecode(
        File('$_spec/formats.json').readAsStringSync(),
      ) as Map<String, Object?>;
      expect(kBleedMm, formats['bleedMm']);
      expect(kSafeGutterMm, formats['safeGutterMm']);
      final list = formats['formats']! as List<Object?>;
      expect(kBookFormats.length, list.length);
      for (var i = 0; i < list.length; i++) {
        final f = list[i]! as Map<String, Object?>;
        expect(kBookFormats[i].id, f['id']);
        expect(kBookFormats[i].trimWMm, f['trimWMm']);
        expect(kBookFormats[i].minPages, f['minPages']);
        expect(kBookFormats[i].maxPages, f['maxPages']);
      }
      final strings = jsonDecode(
        File('$_spec/i18n/book_strings.json').readAsStringSync(),
      ) as Map<String, Object?>;
      expect(kBookStrings.keys.toSet(), strings.keys.toSet());
      for (final lang in strings.keys) {
        final m = strings[lang]! as Map<String, Object?>;
        for (final k in m.keys) {
          expect(
            jsonEncode(kBookStrings[lang]![k]),
            jsonEncode(m[k]),
            reason: '$lang.$k — run tools/spec/sync_spec.py',
          );
        }
      }
    });

    test('app geo assets match the shared copies', () {
      for (final f in ['world.json', 'islands.json', 'places.json']) {
        expect(
          File('assets/geo/$f').readAsStringSync(),
          File('$_spec/geo/$f').readAsStringSync(),
        );
      }
    });

    test('formats: safe area and sides', () {
      final f = BookFormat.byId('classic_20');
      expect(BookFormat.sideOf(0), PageSide.right);
      expect(f.safeArea(PageSide.right).x, 15);
      expect(f.safeArea(PageSide.left).right, 185);
      expect(f.fitPageCount(31), 32);
      expect(f.fitPageCount(101), 100);
      expect(f.fitPageCount(3), 30);
    });
  });
}
