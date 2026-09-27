import 'dart:typed_data';

/// Minimal TrueType reader: Unicode cmap, advance widths and vertical
/// metrics. Line breaking uses these advances (no kerning) in both the app
/// and the render service, so both produce the same lines from the same
/// font files. Mirrored in services/render/src/text/fontMetrics.ts.
class FontMetrics {
  FontMetrics._(
    this.unitsPerEm,
    this.ascender,
    this.descender,
    this.lineGap,
    this._glyphs,
    this._advances,
  );

  factory FontMetrics.parse(Uint8List bytes) {
    final d = ByteData.sublistView(bytes);
    final tables = <String, int>{};
    final numTables = d.getUint16(4);
    for (var i = 0; i < numTables; i++) {
      final rec = 12 + i * 16;
      tables[String.fromCharCodes(bytes.sublist(rec, rec + 4))] = d.getUint32(
        rec + 8,
      );
    }
    int table(String tag) =>
        tables[tag] ?? (throw FormatException('font has no $tag table'));

    final head = table('head');
    final hhea = table('hhea');
    final hmtx = table('hmtx');
    final maxp = table('maxp');
    final numGlyphs = d.getUint16(maxp + 4);
    final numHMetrics = d.getUint16(hhea + 34);
    final advances = Uint16List(numGlyphs);
    var last = 0;
    for (var g = 0; g < numGlyphs; g++) {
      if (g < numHMetrics) last = d.getUint16(hmtx + g * 4);
      advances[g] = last;
    }
    return FontMetrics._(
      d.getUint16(head + 18),
      d.getInt16(hhea + 4),
      d.getInt16(hhea + 6),
      d.getInt16(hhea + 8),
      _parseCmap(d, table('cmap')),
      advances,
    );
  }

  final int unitsPerEm;
  final int ascender;
  final int descender;
  final int lineGap;
  final Map<int, int> _glyphs;
  final Uint16List _advances;

  static Map<int, int> _parseCmap(ByteData d, int cmap) {
    final count = d.getUint16(cmap + 2);
    int? best;
    var bestRank = -1;
    for (var i = 0; i < count; i++) {
      final rec = cmap + 4 + i * 8;
      final platform = d.getUint16(rec);
      final encoding = d.getUint16(rec + 2);
      final offset = cmap + d.getUint32(rec + 4);
      final format = d.getUint16(offset);
      final rank = switch ((platform, encoding, format)) {
        (3, 10, 12) => 4,
        (0, 4 || 6, 12) => 3,
        (3, 1, 4) => 2,
        (0, _, 4) => 1,
        _ => -1,
      };
      if (rank > bestRank) {
        bestRank = rank;
        best = offset;
      }
    }
    if (best == null) {
      throw const FormatException('no supported Unicode cmap subtable');
    }
    final out = <int, int>{};
    if (d.getUint16(best) == 12) {
      final groups = d.getUint32(best + 12);
      for (var i = 0; i < groups; i++) {
        final g = best + 16 + i * 12;
        final start = d.getUint32(g);
        final end = d.getUint32(g + 4);
        final startGlyph = d.getUint32(g + 8);
        for (var c = start; c <= end; c++) {
          final glyph = startGlyph + (c - start);
          if (glyph != 0) out[c] = glyph;
        }
      }
      return out;
    }
    final segX2 = d.getUint16(best + 6);
    final endBase = best + 14;
    final startBase = endBase + segX2 + 2;
    final deltaBase = startBase + segX2;
    final rangeBase = deltaBase + segX2;
    for (var i = 0; i < segX2 ~/ 2; i++) {
      final end = d.getUint16(endBase + i * 2);
      final start = d.getUint16(startBase + i * 2);
      final delta = d.getUint16(deltaBase + i * 2);
      final rangeOffset = d.getUint16(rangeBase + i * 2);
      if (start == 0xFFFF) continue;
      for (var c = start; c <= end; c++) {
        int glyph;
        if (rangeOffset == 0) {
          glyph = (c + delta) & 0xFFFF;
        } else {
          final addr = rangeBase + i * 2 + rangeOffset + (c - start) * 2;
          glyph = d.getUint16(addr);
          if (glyph != 0) glyph = (glyph + delta) & 0xFFFF;
        }
        if (glyph != 0) out[c] = glyph;
      }
    }
    return out;
  }

  bool covers(int codePoint) => _glyphs.containsKey(codePoint);

  /// Characters in [text] this font cannot draw (whitespace ignored).
  Set<String> missing(String text) {
    final out = <String>{};
    for (final rune in text.runes) {
      if (rune <= 0x20 || rune == 0xA0 || rune == 0x200B) continue;
      if (!covers(rune)) out.add(String.fromCharCode(rune));
    }
    return out;
  }

  /// Advance of one code point in font units (missing glyphs use .notdef).
  int advanceUnits(int codePoint) => _advances[_glyphs[codePoint] ?? 0];

  /// Width in points of [text] at [sizePt], with [trackingPct] of the em
  /// added after every character (as Flutter's letterSpacing does).
  double widthPt(String text, double sizePt, {double trackingPct = 0}) {
    var units = 0;
    var chars = 0;
    for (final r in text.runes) {
      units += advanceUnits(r);
      chars++;
    }
    return units * sizePt / unitsPerEm + chars * sizePt * trackingPct / 100;
  }

  /// Distance from the line top to the baseline for a line of [sizePt] set
  /// with [lineHeight] (multiplier). Half the extra leading goes above.
  double baselineOffsetPt(double sizePt, double lineHeight) {
    final contentUnits = ascender - descender;
    final content = contentUnits * sizePt / unitsPerEm;
    final leading = sizePt * lineHeight - content;
    return leading / 2 + ascender * sizePt / unitsPerEm;
  }
}
