import '../model/album.dart';
import '../model/geometry.dart';
import 'font_metrics.dart';
import 'font_registry.dart';

/// One laid-out line: text plus its position in mm relative to the page.
class LaidLine {
  const LaidLine({
    required this.text,
    required this.xMm,
    required this.baselineMm,
    required this.widthMm,
  });

  final String text;
  final double xMm;
  final double baselineMm;
  final double widthMm;
}

class TextLayoutResult {
  const TextLayoutResult({
    required this.lines,
    required this.heightMm,
    required this.overflows,
    required this.truncated,
  });

  final List<LaidLine> lines;

  /// Height of all lines, before vertical alignment.
  final double heightMm;

  /// True when the text is taller than its rect or a word is wider than it.
  final bool overflows;

  /// True when maxLines cut text off.
  final bool truncated;
}

/// Greedy word wrap using the font's advance widths. The render service runs
/// the identical algorithm (services/render/src/text/layout.ts); fixtures in
/// packages/layout_spec/fixtures/text_wrap.json keep them in step.
List<String> wrapText(
  String text,
  FontMetrics m,
  double sizePt,
  double maxWidthPt, {
  double trackingPct = 0,
}) {
  final lines = <String>[];
  for (final paragraph in text.split('\n')) {
    final words = paragraph.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) {
      lines.add('');
      continue;
    }
    var current = '';
    for (final word in words) {
      final candidate = current.isEmpty ? word : '$current $word';
      if (m.widthPt(candidate, sizePt, trackingPct: trackingPct) <=
          maxWidthPt) {
        current = candidate;
        continue;
      }
      if (current.isNotEmpty) lines.add(current);
      // A single word wider than the line is broken by characters.
      if (m.widthPt(word, sizePt, trackingPct: trackingPct) > maxWidthPt) {
        var chunk = '';
        for (final ch in word.runes.map(String.fromCharCode)) {
          if (chunk.isNotEmpty &&
              m.widthPt(chunk + ch, sizePt, trackingPct: trackingPct) >
                  maxWidthPt) {
            lines.add(chunk);
            chunk = ch;
          } else {
            chunk += ch;
          }
        }
        current = chunk;
      } else {
        current = word;
      }
    }
    lines.add(current);
  }
  return lines;
}

String displayText(TextBlock b) => b.uppercase ? b.text.toUpperCase() : b.text;

/// Lays out a text block inside its rect: wrap, maxLines, alignment.
TextLayoutResult layoutTextBlock(TextBlock b, FontRegistry fonts) {
  final m = fonts.metrics(b.fontFamily, b.weight, italic: b.italic);
  final text = displayText(b);
  final maxWidthPt = mmToPt(b.rectMm.w);
  var lines = wrapText(
    text,
    m,
    b.sizePt,
    maxWidthPt,
    trackingPct: b.trackingPct,
  );
  var truncated = false;
  if (b.maxLines != null && lines.length > b.maxLines!) {
    lines = lines.sublist(0, b.maxLines);
    truncated = true;
  }
  final lineMm = ptToMm(b.sizePt * b.lineHeight);
  final heightMm = lines.length * lineMm;
  final baselineInLine = ptToMm(m.baselineOffsetPt(b.sizePt, b.lineHeight));
  final top = switch (b.vAlign) {
    VerticalAlignKind.top => b.rectMm.y,
    VerticalAlignKind.middle => b.rectMm.y + (b.rectMm.h - heightMm) / 2,
    VerticalAlignKind.bottom => b.rectMm.bottom - heightMm,
  };
  var tooWide = false;
  final laid = <LaidLine>[];
  for (var i = 0; i < lines.length; i++) {
    final w = ptToMm(m.widthPt(lines[i], b.sizePt, trackingPct: b.trackingPct));
    if (w > b.rectMm.w + 0.01) tooWide = true;
    final x = switch (b.align) {
      TextAlignKind.left => b.rectMm.x,
      TextAlignKind.center => b.rectMm.x + (b.rectMm.w - w) / 2,
      TextAlignKind.right => b.rectMm.right - w,
    };
    laid.add(
      LaidLine(
        text: lines[i],
        xMm: x,
        baselineMm: top + i * lineMm + baselineInLine,
        widthMm: w,
      ),
    );
  }
  return TextLayoutResult(
    lines: laid,
    heightMm: heightMm,
    overflows: tooWide || heightMm > b.rectMm.h + 0.01,
    truncated: truncated,
  );
}

/// Largest size in [minPt]..[maxPt] (0.5 pt steps) at which [b] fits its
/// rect within [maxLines] lines.
double fitSize(
  TextBlock b,
  FontRegistry fonts, {
  required double minPt,
  required double maxPt,
  int? maxLines,
}) {
  for (var s = maxPt; s >= minPt; s -= 0.5) {
    final trial = b.copyWith(sizePt: s, maxLines: null);
    final r = layoutTextBlock(trial, fonts);
    final lineCount = r.lines.length;
    if (!r.overflows && (maxLines == null || lineCount <= maxLines)) return s;
  }
  return minPt;
}
