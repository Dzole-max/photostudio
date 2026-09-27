import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../domain/model/album.dart';
import '../../domain/model/geometry.dart';
import '../../domain/spec/spec_data.dart';
import '../../domain/text/font_registry.dart';
import '../../domain/text/text_layout.dart';
import 'svg_path.dart';

Color hexColor(String hex, [double opacity = 1]) {
  final h = hex.replaceFirst('#', '');
  final v = int.parse(h.substring(0, 6), radix: 16);
  final a = h.length == 8 ? int.parse(h.substring(6, 8), radix: 16) / 255 : 1.0;
  return Color(0xFF000000 | v).withValues(alpha: (a * opacity).clamp(0, 1));
}

FontWeight fontWeightOf(int w) =>
    FontWeight.values[((w ~/ 100) - 1).clamp(0, 8)];

/// Soft proof (section 6.4): saturation −8 % (Rec. 709 luminance kept),
/// blacks lifted 3 % while white stays white.
const ColorFilter kSoftProofFilter = ColorFilter.matrix(<double>[
  0.9089,
  0.0555,
  0.0056,
  0,
  7.65,
  0.0165,
  0.9479,
  0.0056,
  0,
  7.65,
  0.0165,
  0.0555,
  0.898,
  0,
  7.65,
  0,
  0,
  0,
  1,
  0,
]);

/// Paints one page (or cover panel) of an album document. The render
/// service draws the same primitives the same way
/// (services/render/src/draw/page.ts).
class BookPagePainter extends CustomPainter {
  BookPagePainter({
    required this.page,
    required this.trimWMm,
    required this.trimHMm,
    required this.fonts,
    required this.images,
    this.includeBleed = false,
    this.clipToTrim = true,
    this.softProof = false,
    this.placeholder = const Color(0xFFE7DFD2),
    this.photos = const {},
    this.repaintKey = 0,
  });

  final BookPage page;
  final double trimWMm;
  final double trimHMm;
  final FontRegistry fonts;

  /// photoId → decoded image (any resolution; crops are normalised).
  final Map<String, ui.Image> images;
  final Map<String, PhotoRef> photos;
  final bool includeBleed;
  final bool clipToTrim;
  final bool softProof;
  final Color placeholder;
  final int repaintKey;

  static final Expando<TextLayoutResult> _layoutCache = Expando();

  @override
  void paint(Canvas canvas, Size size) {
    final boxW = includeBleed ? trimWMm + 2 * kBleedMm : trimWMm;
    final s = size.width / boxW;
    canvas.save();
    if (includeBleed) canvas.translate(kBleedMm * s, kBleedMm * s);
    final visible = includeBleed
        ? Rect.fromLTWH(
            -kBleedMm * s,
            -kBleedMm * s,
            (trimWMm + 2 * kBleedMm) * s,
            (trimHMm + 2 * kBleedMm) * s,
          )
        : Rect.fromLTWH(0, 0, trimWMm * s, trimHMm * s);
    if (clipToTrim || includeBleed) canvas.clipRect(visible);
    if (softProof) {
      canvas.saveLayer(visible, Paint()..colorFilter = kSoftProofFilter);
    }

    canvas.drawRect(
      visible,
      Paint()..color = hexColor(page.background?.color ?? '#FFFFFF'),
    );
    for (final f in page.frames) {
      _frame(canvas, f, s);
    }
    for (final o in page.ornaments) {
      _ornament(canvas, o, s);
    }
    for (final t in page.texts) {
      _text(canvas, t, s);
    }
    if (softProof) canvas.restore();
    canvas.restore();
  }

  Rect _r(RectMm r, double s) =>
      Rect.fromLTWH(r.x * s, r.y * s, r.w * s, r.h * s);

  void _frame(Canvas canvas, PhotoFrame f, double s) {
    final outer = _r(f.rectMm, s);
    canvas.save();
    if (f.rotationDeg != 0) {
      canvas.translate(outer.center.dx, outer.center.dy);
      canvas.rotate(f.rotationDeg * math.pi / 180);
      canvas.translate(-outer.center.dx, -outer.center.dy);
    }
    final radius = Radius.circular(f.cornerRadiusMm * s);
    if (f.borderMm > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(outer, radius),
        Paint()..color = hexColor(f.borderColor),
      );
    }
    final inner = f.borderMm > 0 ? outer.deflate(f.borderMm * s) : outer;
    final innerRadius = Radius.circular(
      math.max(0, f.cornerRadiusMm - f.borderMm) * s,
    );
    canvas.clipRRect(RRect.fromRectAndRadius(inner, innerRadius));
    final image = f.photoId == null ? null : images[f.photoId];
    if (image == null) {
      canvas.drawRect(inner, Paint()..color = placeholder);
    } else {
      final src = Rect.fromLTWH(
        f.crop.x * image.width,
        f.crop.y * image.height,
        f.crop.w * image.width,
        f.crop.h * image.height,
      );
      canvas.drawImageRect(
        image,
        src,
        inner,
        Paint()..filterQuality = FilterQuality.medium,
      );
    }
    canvas.restore();
  }

  void _ornament(Canvas canvas, Ornament o, double s) {
    final p = o.params;
    double v(String k) => (p[k] ?? 0) * s;
    final stroke = ptToMm(o.strokePt) * s;
    final paint = Paint()
      ..color = hexColor(o.color, o.opacity)
      ..isAntiAlias = true
      ..style = o.fill ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Path? path;
    switch (o.type) {
      case OrnamentType.line:
        path = Path()
          ..moveTo(v('x1'), v('y1'))
          ..lineTo(v('x2'), v('y2'));
      case OrnamentType.rect:
        final r = Rect.fromLTWH(v('x'), v('y'), v('w'), v('h'));
        path = Path()
          ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(v('r'))));
      case OrnamentType.circle || OrnamentType.monogramRing:
        path = Path()
          ..addOval(
            Rect.fromCircle(center: Offset(v('cx'), v('cy')), radius: v('r')),
          );
      case OrnamentType.stamp:
        final c = Offset(v('cx'), v('cy'));
        final gap = p.containsKey('gap') ? v('gap') : 1.5 * s;
        path = Path()
          ..addOval(Rect.fromCircle(center: c, radius: v('r')))
          ..addOval(Rect.fromCircle(center: c, radius: v('r') - gap));
      case OrnamentType.arc:
        path = Path()
          ..addArc(
            Rect.fromCircle(center: Offset(v('cx'), v('cy')), radius: v('r')),
            (p['start'] ?? 0) * math.pi / 180,
            (p['sweep'] ?? 0) * math.pi / 180,
          );
      case OrnamentType.path:
        path = parseSvgPath(o.path ?? '', s);
      case OrnamentType.gradient:
        final r = Rect.fromLTWH(v('x'), v('y'), v('w'), v('h'));
        final c0 = hexColor(o.color, p['o0'] ?? 0);
        final c1 = hexColor(o.color2 ?? o.color, p['o1'] ?? 1);
        canvas.drawRect(
          r,
          Paint()
            ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, [
              c0,
              c1,
            ]),
        );
        return;
    }
    final dash = o.dashMm;
    if (dash != null && dash.isNotEmpty && !o.fill) {
      path = dashPath(path, [for (final d in dash) d * s]);
    }
    canvas.drawPath(path, paint);
  }

  void _text(Canvas canvas, TextBlock t, double s) {
    if (t.text.isEmpty) return;
    final laid = _layoutCache[t] ??= layoutTextBlock(t, fonts);
    final face = resolveFace(t.fontFamily, t.weight, italic: t.italic);
    final sizePx = ptToMm(t.sizePt) * s;
    final style = TextStyle(
      fontFamily: face.family,
      fontSize: sizePx,
      fontWeight: fontWeightOf(face.weight),
      fontStyle: face.italic ? FontStyle.italic : FontStyle.normal,
      color: hexColor(t.color, t.opacity),
      letterSpacing: sizePx * t.trackingPct / 100,
      height: 1,
    );
    canvas.save();
    if (t.rotationDeg != 0) {
      final c = _r(t.rectMm, s).center;
      canvas.translate(c.dx, c.dy);
      canvas.rotate(t.rotationDeg * math.pi / 180);
      canvas.translate(-c.dx, -c.dy);
    }
    for (final line in laid.lines) {
      if (line.text.isEmpty) continue;
      final tp = TextPainter(
        text: TextSpan(text: line.text, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final baseline = tp.computeDistanceToActualBaseline(
        TextBaseline.alphabetic,
      );
      tp.paint(canvas, Offset(line.xMm * s, line.baselineMm * s - baseline));
      tp.dispose();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BookPagePainter old) =>
      old.page != page ||
      old.images.length != images.length ||
      old.repaintKey != repaintKey ||
      old.softProof != softProof ||
      old.trimWMm != trimWMm;
}
