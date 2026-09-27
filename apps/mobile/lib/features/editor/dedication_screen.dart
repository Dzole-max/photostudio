import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../design/design.dart';
import '../../domain/layout/dedication.dart';
import '../../domain/spec/book_format.dart';
import '../book/book_page_view.dart';
import '../book/book_painter.dart' show hexColor;
import 'editor_controller.dart';

/// Handwritten dedication: write with a finger on the first page; the
/// strokes become vector ink printed with the book.
class DedicationScreen extends ConsumerStatefulWidget {
  const DedicationScreen({required this.albumId, super.key});

  final String albumId;

  @override
  ConsumerState<DedicationScreen> createState() => _DedicationScreenState();
}

class _DedicationScreenState extends ConsumerState<DedicationScreen> {
  final List<InkStroke> _strokes = [];

  void _add(Offset p, Size size, {bool start = false}) {
    final point = (
      (p.dx / size.width).clamp(0.0, 1.0),
      (p.dy / size.height).clamp(0.0, 1.0),
    );
    setState(() {
      if (start || _strokes.isEmpty) {
        _strokes.add([point]);
      } else {
        _strokes.last.add(point);
      }
    });
  }

  void _save() {
    HapticFeedback.lightImpact();
    ref
        .read(editorControllerProvider(widget.albumId).notifier)
        .apply((ops, a) => applyDedication(a, _strokes));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    final state = ref.watch(editorControllerProvider(widget.albumId)).value;
    if (state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final album = state.album;
    final format = BookFormat.byId(album.formatId);
    final area = dedicationArea(format);
    // The page without the old dedication, so you write on a clean page.
    final page = album.pages.first.copyWith(
      ornaments: album.pages.first.ornaments
          .where((o) => !isDedication(o))
          .toList(),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l.dedicationTitle),
        actions: [
          IconButton(
            tooltip: l.editorUndo,
            onPressed: _strokes.isEmpty
                ? null
                : () => setState(_strokes.removeLast),
            icon: const Icon(Icons.undo_rounded),
          ),
          TextButton(
            onPressed: _strokes.isEmpty ? null : () => setState(_strokes.clear),
            child: Text(l.dedicationClear),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.dedicationBody, style: t.bodyMedium),
              const SizedBox(height: Space.md),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: format.aspect,
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final s = box.maxWidth / format.trimWMm;
                        final pad = Rect.fromLTWH(
                          area.x * s,
                          area.y * s,
                          area.w * s,
                          area.h * s,
                        );
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  boxShadow: Shadows.soft(c),
                                ),
                                child: BookPageView(album: album, page: page),
                              ),
                            ),
                            Positioned.fromRect(
                              rect: pad,
                              child: Semantics(
                                label: l.dedicationArea,
                                child: GestureDetector(
                                  onPanStart: (d) => _add(
                                    d.localPosition,
                                    pad.size,
                                    start: true,
                                  ),
                                  onPanUpdate: (d) =>
                                      _add(d.localPosition, pad.size),
                                  child: CustomPaint(
                                    painter: _InkPainter(
                                      _strokes,
                                      hexColor(kDedicationInk),
                                      c.divider,
                                      // 1.1 pt at this page scale.
                                      kDedicationStrokePt * 0.3528 * s,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Space.md),
              PrimaryButton(
                label: _strokes.isEmpty && hasDedication(album)
                    ? l.dedicationRemove
                    : l.dedicationSave,
                icon: Icons.draw_outlined,
                onPressed: _strokes.isEmpty && !hasDedication(album)
                    ? null
                    : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InkPainter extends CustomPainter {
  _InkPainter(this.strokes, this.ink, this.guide, this.width);

  final List<InkStroke> strokes;
  final Color ink;
  final Color guide;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    // A dashed frame showing where the dedication will print.
    final dash = Paint()
      ..color = guide
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, 0), Offset(x + 4, 0), dash);
      canvas.drawLine(Offset(x, size.height), Offset(x + 4, size.height), dash);
    }
    final paint = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = width.clamp(1.5, 6)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final s in strokes) {
      if (s.isEmpty) continue;
      final path = Path()
        ..moveTo(s.first.$1 * size.width, s.first.$2 * size.height);
      for (final (x, y) in s.skip(1)) {
        path.lineTo(x * size.width, y * size.height);
      }
      if (s.length == 1) path.relativeLineTo(0.1, 0);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_InkPainter old) => true;
}
