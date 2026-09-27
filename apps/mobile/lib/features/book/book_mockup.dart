import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../domain/model/album.dart';
import '../../domain/spec/book_format.dart';
import 'book_page_view.dart';

/// A closed book: the real cover on a body with spine shading, a page
/// block and a soft shadow, turned by [yaw] (radians) around its spine.
class BookMockup extends StatelessWidget {
  const BookMockup({
    required this.album,
    this.width = 160,
    this.yaw = -0.28,
    this.pitch = 0.0,
    this.semanticLabel,
    super.key,
  });

  final Album album;
  final double width;
  final double yaw;
  final double pitch;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final f = BookFormat.byId(album.formatId);
    final h = width * f.trimHMm / f.trimWMm;
    final thickness = math.max(
      6.0,
      width * album.cover.spineMm / f.trimWMm * 1.6,
    );
    final light = (0.5 + math.sin(-yaw) * 0.6).clamp(0.0, 1.0);
    return Semantics(
      label: semanticLabel,
      image: true,
      child: SizedBox(
        width: width + thickness,
        height: h + 24,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Soft contact shadow.
            Positioned(
              left: width * 0.08,
              right: width * 0.02,
              bottom: 0,
              height: 22,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1F1B17).withValues(alpha: 0.22),
                      blurRadius: 18,
                      spreadRadius: -2,
                    ),
                  ],
                ),
              ),
            ),
            Transform(
              alignment: Alignment.centerLeft,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateX(pitch)
                ..rotateY(yaw),
              child: SizedBox(
                width: width,
                height: h,
                child: Stack(
                  children: [
                    // Page block peeking out on the fore-edge.
                    Positioned(
                      right: -thickness * 0.55,
                      top: 3,
                      bottom: 3,
                      width: thickness,
                      child: CustomPaint(painter: _PageBlockPainter()),
                    ),
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(3),
                        left: Radius.circular(1.5),
                      ),
                      child: BookPageView(
                        album: album,
                        page: album.cover.front,
                      ),
                    ),
                    // Hinge groove and spine shading.
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: width * 0.07,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.28),
                              Colors.white.withValues(alpha: 0.12),
                              Colors.black.withValues(alpha: 0.10),
                              Colors.transparent,
                            ],
                            stops: const [0, 0.25, 0.45, 1],
                          ),
                        ),
                      ),
                    ),
                    // Light falloff across the cover as it turns.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.10 * light),
                                Colors.black.withValues(
                                  alpha: 0.10 * (1 - light),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageBlockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF4EFE6),
    );
    final line = Paint()
      ..color = const Color(0xFFD9D0C1)
      ..strokeWidth = 0.6;
    for (double x = 1; x < size.width; x += 1.6) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
  }

  @override
  bool shouldRepaint(_PageBlockPainter oldDelegate) => false;
}
