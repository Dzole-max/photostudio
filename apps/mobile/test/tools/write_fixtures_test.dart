import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memoria/domain/geo/projection.dart';
import 'package:memoria/domain/model/geometry.dart';
import 'package:memoria/domain/text/text_layout.dart';

import '../helpers/domain_fixtures.dart';
import '../helpers/sample_books.dart';

/// Writes the shared parity fixtures in packages/layout_spec/fixtures from
/// the Dart implementation. Run on purpose after an intended change:
///   MEMORIA_WRITE_FIXTURES=1 flutter test test/tools/write_fixtures_test.dart
/// The Dart and TypeScript test suites both check against these files.
void main() {
  final write = Platform.environment['MEMORIA_WRITE_FIXTURES'] == '1';
  const out = '../../packages/layout_spec/fixtures';
  const encoder = JsonEncoder.withIndent('  ');

  test('write parity fixtures', () {
    final wrapCases = <Map<String, Object>>[];
    const samples = [
      (
        'Lora',
        400,
        9.0,
        120.0,
        0.0,
        'Stone Town, day two — the alleys were quieter than we expected',
      ),
      (
        'Lora',
        400,
        10.5,
        360.0,
        0.0,
        'Our days in Stone Town: old streets, sea and evening light.',
      ),
      (
        'CormorantGaramond',
        500,
        26.0,
        300.0,
        0.0,
        'Aleksandar & Elena said yes in Ohrid, by the lake',
      ),
      (
        'Manrope',
        600,
        8.5,
        140.0,
        20.0,
        '15 AUGUST 2026 · OHRID · NORTH MACEDONIA',
      ),
      ('Manrope', 700, 30.0, 200.0, 40.0, 'ZANZIBAR'),
      (
        'Lora',
        400,
        10.5,
        200.0,
        0.0,
        'Александар и Елена си рекоа „да“ во Охрид, покрај езерото.',
      ),
      (
        'Nunito',
        700,
        28.0,
        180.0,
        0.0,
        'Mia turns one\nand the cake was bigger than her',
      ),
      ('GreatVibes', 400, 44.0, 150.0, 0.0, 'A & E'),
      ('Lora', 400, 9.0, 60.0, 0.0, 'Unabhängigkeitserklärungsentwurf'),
    ];
    for (final (family, weight, size, width, tracking, text) in samples) {
      final m = DomainFixtures.fonts.metrics(family, weight);
      wrapCases.add({
        'family': family,
        'weight': weight,
        'sizePt': size,
        'maxWidthPt': width,
        'trackingPct': tracking,
        'text': text,
        'widthPt': double.parse(
          m
              .widthPt(text.split('\n').first, size, trackingPct: tracking)
              .toStringAsFixed(6),
        ),
        'lines': wrapText(text, m, size, width, trackingPct: tracking),
      });
    }

    final projCases = <Map<String, Object>>[];
    const projSamples = [
      (
        [10.0, 20.0, 180.0, 120.0],
        [(39.1921, -6.1622), (39.2988, -5.7264), (39.4169, -6.2656)],
      ),
      ([15.0, 22.0, 254.4, 171.2], [(20.8016, 41.1172), (21.4314, 41.9981)]),
      (
        [0.0, 0.0, 100.0, 100.0],
        [(2.3522, 48.8566), (12.4964, 41.9028), (2.1734, 41.3851)],
      ),
      ([5.0, 5.0, 50.0, 80.0], [(139.6503, 35.6762)]),
    ];
    for (final (r, pts) in projSamples) {
      final proj = FittedProjection.fit(
        pts,
        RectMm(x: r[0], y: r[1], w: r[2], h: r[3]),
      );
      projCases.add({
        'rect': r,
        'points': [
          for (final (a, b) in pts) [a, b],
        ],
        'projected': [
          for (final (a, b) in pts)
            [
              for (final v in [proj.project(a, b).$1, proj.project(a, b).$2])
                double.parse(v.toStringAsFixed(9)),
            ],
        ],
      });
    }

    final albums = {
      'album_wedding.json': buildSampleBook('wedding'),
      'album_travel.json': buildSampleBook('travel'),
      'album_travel_mk.json': buildSampleBook('travel', language: 'mk'),
    };

    if (!write) {
      markTestSkipped('set MEMORIA_WRITE_FIXTURES=1 to regenerate');
      return;
    }
    File('$out/text_wrap.json')
        .writeAsStringSync('${encoder.convert(wrapCases)}\n');
    File('$out/projection.json')
        .writeAsStringSync('${encoder.convert(projCases)}\n');
    for (final e in albums.entries) {
      File('$out/${e.key}')
          .writeAsStringSync('${encoder.convert(e.value.toServerJson())}\n');
    }
  });
}
