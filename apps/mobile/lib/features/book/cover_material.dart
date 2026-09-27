import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../domain/model/album.dart';

/// Renders the cover material over a cover panel: linen weave, leather-look
/// grain, flat matte, or a gloss highlight whose position follows [sheen]
/// (0..1, driven by the book's angle so the light moves as it turns).
class CoverMaterialOverlay extends StatelessWidget {
  const CoverMaterialOverlay({
    required this.finish,
    required this.child,
    this.sheen = 0.5,
    super.key,
  });

  final CoverFinish finish;
  final Widget child;
  final double sheen;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        IgnorePointer(
          child: CustomPaint(
            painter: _MaterialPainter(finish, sheen.clamp(0.0, 1.0)),
          ),
        ),
      ],
    );
  }
}

class _MaterialPainter extends CustomPainter {
  _MaterialPainter(this.finish, this.sheen);

  final CoverFinish finish;
  final double sheen;

  static final Map<CoverFinish, ui.Picture> _textures = {};

  static ui.Picture _texture(CoverFinish f) => _textures.putIfAbsent(f, () {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final rng = math.Random(f.index + 5);
    switch (f) {
      case CoverFinish.linen:
        final a = Paint()
          ..color = Colors.black.withValues(alpha: 0.06)
          ..strokeWidth = 0.6;
        final b = Paint()
          ..color = Colors.white.withValues(alpha: 0.08)
          ..strokeWidth = 0.6;
        for (double x = 0; x < 256; x += 2.2) {
          canvas.drawLine(
            Offset(x, 0),
            Offset(x + rng.nextDouble(), 256),
            rng.nextBool() ? a : b,
          );
        }
        for (double y = 0; y < 256; y += 2.2) {
          canvas.drawLine(
            Offset(0, y),
            Offset(256, y + rng.nextDouble()),
            rng.nextBool() ? a : b,
          );
        }
      case CoverFinish.leather:
        for (var i = 0; i < 900; i++) {
          final c = Offset(rng.nextDouble() * 256, rng.nextDouble() * 256);
          canvas.drawOval(
            Rect.fromCenter(
              center: c,
              width: 2 + rng.nextDouble() * 4,
              height: 1.5 + rng.nextDouble() * 3,
            ),
            Paint()
              ..color = (rng.nextBool() ? Colors.black : Colors.white)
                  .withValues(alpha: 0.07),
          );
        }
      case CoverFinish.matte || CoverFinish.gloss:
        break;
    }
    return rec.endRecording();
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    switch (finish) {
      case CoverFinish.linen || CoverFinish.leather:
        canvas.save();
        canvas.clipRect(rect);
        final tex = _texture(finish);
        for (double y = 0; y < size.height; y += 256) {
          for (double x = 0; x < size.width; x += 256) {
            canvas.save();
            canvas.translate(x, y);
            canvas.drawPicture(tex);
            canvas.restore();
          }
        }
        canvas.restore();
        if (finish == CoverFinish.leather) {
          // Leather absorbs light: slightly deeper, warmer tone.
          canvas.drawRect(
            rect,
            Paint()..color = const Color(0xFF3A2414).withValues(alpha: 0.10),
          );
        }
      case CoverFinish.matte:
        canvas.drawRect(
          rect,
          Paint()..color = Colors.white.withValues(alpha: 0.03),
        );
      case CoverFinish.gloss:
        final cx = size.width * (sheen * 1.4 - 0.2);
        canvas.drawRect(
          rect,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(cx - size.width * 0.35, 0),
              Offset(cx + size.width * 0.35, size.height),
              [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: 0.28),
                Colors.white.withValues(alpha: 0),
              ],
              const [0, 0.5, 1],
            ),
        );
    }
  }

  @override
  bool shouldRepaint(_MaterialPainter old) =>
      old.finish != finish || old.sheen != sheen;
}
