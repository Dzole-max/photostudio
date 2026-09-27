import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../colors.dart';

/// The app mark: two rounded pages leaning together like an open book seen
/// from above, with a thin gap as the spine. Single colour.
class AppMark extends StatelessWidget {
  const AppMark({this.size = 48, this.color, super.key});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: AppMarkPainter(color ?? MemoriaColors.of(context).textPrimary),
      ),
    );
  }
}

class AppMarkPainter extends CustomPainter {
  AppMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;
    final pageW = s * 0.36;
    final pageH = s * 0.64;
    final gap = s * 0.045;
    final cy = size.height / 2;
    final cx = size.width / 2;
    final r = Radius.circular(s * 0.07);
    for (final side in [-1.0, 1.0]) {
      canvas.save();
      // Pivot at the top of the spine; the bottoms swing outwards so the
      // pages lean together like an open book seen from above.
      canvas.translate(cx + side * gap / 2, cy - pageH / 2);
      canvas.rotate(-side * 0.08);
      final left = side < 0 ? -pageW : 0.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, 0, pageW, pageH), r),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(AppMarkPainter oldDelegate) => oldDelegate.color != color;
}

/// Open book line illustration used in empty states.
class OpenBookIllustration extends StatelessWidget {
  const OpenBookIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final c = MemoriaColors.of(context);
    return ExcludeSemantics(
      child: CustomPaint(
        painter: _OpenBookPainter(
          line: c.textPrimary,
          paper: c.surfaceRaised,
          accent: c.accent,
          shadow: c.shadow,
        ),
      ),
    );
  }
}

class _OpenBookPainter extends CustomPainter {
  _OpenBookPainter({
    required this.line,
    required this.paper,
    required this.accent,
    required this.shadow,
  });

  final Color line;
  final Color paper;
  final Color accent;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final spineX = w / 2;
    final top = h * 0.12;
    final bottom = h * 0.86;

    final shadowPaint = Paint()
      ..color = shadow.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(spineX, bottom + h * 0.04),
        width: w * 0.86,
        height: h * 0.1,
      ),
      shadowPaint,
    );

    Path page(double dir) {
      final outer = spineX + dir * w * 0.44;
      return Path()
        ..moveTo(spineX, top + h * 0.06)
        ..quadraticBezierTo(
          spineX + dir * w * 0.2,
          top - h * 0.04,
          outer,
          top + h * 0.02,
        )
        ..lineTo(outer, bottom - h * 0.02)
        ..quadraticBezierTo(
          spineX + dir * w * 0.2,
          bottom - h * 0.1,
          spineX,
          bottom,
        )
        ..close();
    }

    final fill = Paint()..color = paper;
    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;
    for (final dir in [-1.0, 1.0]) {
      final p = page(dir);
      canvas.drawPath(p, fill);
      canvas.drawPath(p, stroke);
    }
    canvas.drawLine(
      Offset(spineX, top + h * 0.06),
      Offset(spineX, bottom),
      stroke,
    );

    // A photo on the left page and text lines on the right page.
    final photo = Rect.fromLTWH(w * 0.14, h * 0.26, w * 0.26, h * 0.34);
    canvas.drawRect(photo, Paint()..color = accent.withValues(alpha: 0.28));
    final sun = Paint()..color = accent.withValues(alpha: 0.7);
    canvas.drawCircle(
      photo.topRight + Offset(-w * 0.06, h * 0.08),
      h * 0.04,
      sun,
    );
    final hill = Path()
      ..moveTo(photo.left, photo.bottom)
      ..quadraticBezierTo(
        photo.center.dx,
        photo.center.dy - h * 0.02,
        photo.right,
        photo.bottom - h * 0.06,
      )
      ..lineTo(photo.right, photo.bottom)
      ..close();
    canvas.drawPath(hill, Paint()..color = accent.withValues(alpha: 0.55));

    final textPaint = Paint()
      ..color = line.withValues(alpha: 0.35)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final y = h * 0.32 + i * h * 0.09;
      final len = i == 3 ? w * 0.14 : w * 0.24;
      canvas.drawLine(
        Offset(w * 0.58, y),
        Offset(w * 0.58 + len, y),
        textPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_OpenBookPainter oldDelegate) =>
      oldDelegate.line != line || oldDelegate.paper != paper;
}

/// Onboarding hero: a linen-bound book slowly opening on a linen table,
/// looping. Pure vector so it needs no bundled video.
class OpeningBookLoop extends StatefulWidget {
  const OpeningBookLoop({super.key});

  @override
  State<OpeningBookLoop> createState() => _OpeningBookLoopState();
}

class _OpeningBookLoopState extends State<OpeningBookLoop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _c
        ..stop()
        ..value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          // 0..0.4 opening, 0.4..0.75 open, 0.75..1 closing.
          final t = _c.value;
          double open;
          if (t < 0.4) {
            open = Curves.easeInOutCubic.transform(t / 0.4);
          } else if (t < 0.75) {
            open = 1;
          } else {
            open = 1 - Curves.easeInOutCubic.transform((t - 0.75) / 0.25);
          }
          return CustomPaint(
            painter: _LinenBookPainter(open),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _LinenBookPainter extends CustomPainter {
  _LinenBookPainter(this.open);

  final double open;

  static const _linen = Color(0xFFE9E1D3);
  static const _linenDark = Color(0xFFDCD2C1);
  static const _cover = Color(0xFF6E5A45);
  static const _paper = Color(0xFFFBF8F2);
  static const _gold = Color(0xFFB8955A);
  static const _ink = Color(0xFF2B2622);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = _linen);
    // Linen weave: faint cross-hatch.
    final weave = Paint()
      ..color = _linenDark.withValues(alpha: 0.35)
      ..strokeWidth = 0.6;
    for (double x = 0; x < size.width; x += 3) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), weave);
    }
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), weave);
    }

    final bookW = size.width * 0.34;
    final bookH = bookW * 1.0;
    final center = Offset(size.width / 2, size.height * 0.42);
    final spine = Offset(center.dx, center.dy);

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    final shadowW = bookW * (1 + open);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: spine + Offset((1 - open) * bookW / 2, 12),
          width: shadowW,
          height: bookH,
        ),
        const Radius.circular(6),
      ),
      shadow,
    );

    final right = Rect.fromLTWH(spine.dx, spine.dy - bookH / 2, bookW, bookH);
    // Right page block (always visible once opening begins).
    canvas.drawRect(right, Paint()..color = _paper);
    _photo(canvas, right.deflate(bookW * 0.1), 0);

    // Left page appears as the cover swings over.
    if (open > 0.5) {
      final f = (open - 0.5) / 0.5;
      final w = bookW * f;
      final left = Rect.fromLTWH(spine.dx - w, spine.dy - bookH / 2, w, bookH);
      canvas.drawRect(left, Paint()..color = _paper);
      if (f > 0.6) {
        _photo(canvas, left.deflate(bookW * 0.1), 1);
      }
      canvas.drawRect(
        Rect.fromLTWH(spine.dx - 6, left.top, 12, bookH),
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.black.withValues(alpha: 0),
              Colors.black.withValues(alpha: 0.10),
              Colors.black.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromLTWH(spine.dx - 6, left.top, 12, bookH)),
      );
    } else {
      // Cover still over the right side, foreshortened as it lifts.
      final f = 1 - open / 0.5;
      final w = bookW * f;
      final cover = Rect.fromLTWH(spine.dx, spine.dy - bookH / 2, w, bookH);
      canvas.drawRect(cover, Paint()..color = _cover);
      if (f > 0.5) {
        final ring = Paint()
          ..color = _gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        canvas.drawCircle(cover.center, bookW * 0.16 * f, ring);
        final gold = Paint()
          ..color = _gold
          ..strokeWidth = 1.2;
        canvas.drawLine(
          Offset(cover.center.dx - w * 0.2, cover.bottom - bookH * 0.2),
          Offset(cover.center.dx + w * 0.2, cover.bottom - bookH * 0.2),
          gold,
        );
      }
    }
  }

  void _photo(Canvas canvas, Rect r, int variant) {
    final sky = variant == 0
        ? const Color(0xFFBFD4D6)
        : const Color(0xFFE8C9B5);
    canvas.drawRect(r, Paint()..color = sky);
    final sea = Path()
      ..moveTo(r.left, r.top + r.height * 0.62)
      ..quadraticBezierTo(
        r.center.dx,
        r.top + r.height * (variant == 0 ? 0.55 : 0.7),
        r.right,
        r.top + r.height * 0.6,
      )
      ..lineTo(r.right, r.bottom)
      ..lineTo(r.left, r.bottom)
      ..close();
    canvas.drawPath(
      sea,
      Paint()..color = variant == 0 ? const Color(0xFF3F7F86) : _cover,
    );
    canvas.drawCircle(
      Offset(r.left + r.width * 0.7, r.top + r.height * 0.3),
      r.width * 0.08,
      Paint()..color = _paper.withValues(alpha: 0.9),
    );
    final line = Paint()
      ..color = _ink.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(r.left, r.bottom + 10),
      Offset(r.left + r.width * 0.5, r.bottom + 10),
      line,
    );
  }

  @override
  bool shouldRepaint(_LinenBookPainter oldDelegate) => oldDelegate.open != open;
}

/// Small line icons for the three onboarding steps (pick, design, print).
class StepIllustration extends StatelessWidget {
  const StepIllustration({required this.step, this.size = 72, super.key});

  final int step;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = MemoriaColors.of(context);
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _StepPainter(step, c.textPrimary, c.primary, c.surface),
      ),
    );
  }
}

class _StepPainter extends CustomPainter {
  _StepPainter(this.step, this.ink, this.clay, this.fill);

  final int step;
  final Color ink;
  final Color clay;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.drawCircle(size.center(Offset.zero), s / 2, Paint()..color = fill);
    final p = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final accent = Paint()..color = clay;
    switch (step) {
      case 0:
        // A 2x2 photo grid with one tile selected.
        final cell = s * 0.18;
        final origin = Offset(s * 0.3, s * 0.3);
        for (var i = 0; i < 4; i++) {
          final r = Rect.fromLTWH(
            origin.dx + (i % 2) * (cell + s * 0.04),
            origin.dy + (i ~/ 2) * (cell + s * 0.04),
            cell,
            cell,
          );
          if (i == 1) canvas.drawRect(r, accent);
          canvas.drawRect(r, p);
        }
      case 1:
        // A page with a layout: big frame + two small frames + text line.
        final page = Rect.fromLTWH(s * 0.28, s * 0.24, s * 0.44, s * 0.52);
        canvas.drawRect(page, p);
        canvas.drawRect(
          Rect.fromLTWH(
            page.left + 5,
            page.top + 5,
            page.width - 10,
            page.height * 0.45,
          ),
          accent..color = clay.withValues(alpha: 0.85),
        );
        final y = page.top + page.height * 0.62;
        canvas.drawLine(Offset(page.left + 6, y), Offset(page.right - 6, y), p);
        canvas.drawLine(
          Offset(page.left + 6, y + 8),
          Offset(page.center.dx, y + 8),
          p,
        );
      default:
        // A closed book with a bookmark ribbon.
        final book = Rect.fromLTWH(s * 0.3, s * 0.24, s * 0.4, s * 0.52);
        canvas.drawRRect(
          RRect.fromRectAndRadius(book, const Radius.circular(3)),
          p,
        );
        canvas.drawLine(
          Offset(book.left + 6, book.top),
          Offset(book.left + 6, book.bottom),
          p,
        );
        final ribbon = Path()
          ..moveTo(book.right - 14, book.bottom - 2)
          ..lineTo(book.right - 14, book.bottom + 8)
          ..lineTo(book.right - 10, book.bottom + 4)
          ..lineTo(book.right - 6, book.bottom + 8)
          ..lineTo(book.right - 6, book.bottom - 2)
          ..close();
        canvas.drawPath(ribbon, accent);
        canvas.drawCircle(book.center, s * 0.07, p);
        canvas.drawArc(
          Rect.fromCircle(center: book.center, radius: s * 0.12),
          -math.pi * 0.9,
          math.pi * 0.8,
          false,
          p,
        );
    }
  }

  @override
  bool shouldRepaint(_StepPainter oldDelegate) =>
      oldDelegate.step != step || oldDelegate.ink != ink;
}
