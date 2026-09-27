import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memoria/domain/text/font_metrics.dart';

/// Build-time check: every bundled font must draw both the Latin languages
/// and Macedonian Cyrillic, or print would silently fall back to tofu.
void main() {
  const samples = [
    'Александар & Елена · Охрид',
    'Aleksandar & Elena · Ohrid',
    'ЃѓЌќЅѕЉљЊњЏџЈј',
    'äöüß ÄÖÜ ñÑ éèêëÉ çÇ àâÀ ìíîÌ òóôÒ ùúûÙ ¿¡ « » – — ’',
    '0123456789 ° € · & ✓',
  ];

  final fontsDir = Directory('assets/fonts');
  final fonts =
      fontsDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.ttf'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('fonts are bundled', () {
    expect(fonts, hasLength(23));
  });

  for (final font in fonts) {
    final name = font.uri.pathSegments.last;
    test('$name covers Latin + Cyrillic samples', () {
      final coverage = FontMetrics.parse(font.readAsBytesSync());
      // The check mark is a UI glyph, not required in book fonts.
      final missing = {for (final s in samples) ...coverage.missing(s)}
        ..remove('✓');
      expect(missing, isEmpty, reason: '$name is missing $missing');
    });
  }

  test('detects missing glyphs', () {
    final coverage = FontMetrics.parse(
      File('assets/fonts/Manrope-400.ttf').readAsBytesSync(),
    );
    expect(coverage.missing('漢字'), {'漢', '字'});
    expect(coverage.covers('A'.codeUnitAt(0)), isTrue);
  });
}
