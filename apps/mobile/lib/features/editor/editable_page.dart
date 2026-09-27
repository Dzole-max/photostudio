import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../design/design.dart';
import '../../domain/model/album.dart';
import '../../domain/model/geometry.dart';
import '../../domain/spec/book_format.dart';
import '../../domain/spec/spec_data.dart';
import '../book/book_page_view.dart';
import 'editor_controller.dart';

/// Payloads for drag and drop inside the editor.
sealed class EditorDrag {
  const EditorDrag();
}

class PhotoDrag extends EditorDrag {
  const PhotoDrag(this.photoId);

  final String photoId;
}

class FrameDrag extends EditorDrag {
  const FrameDrag(this.pageIndex, this.frameIndex);

  final int pageIndex;
  final int frameIndex;
}

/// One page in the editor: the real render plus invisible hit targets for
/// frames and texts (taps, drag and drop, screen readers).
class EditablePage extends ConsumerWidget {
  const EditablePage({
    required this.albumId,
    required this.album,
    required this.pageIndex,
    required this.guides,
    this.selection,
    this.swapping = false,
    super.key,
  });

  final String albumId;
  final Album album;

  /// Inner page index, or -1 for the front cover.
  final int pageIndex;
  final bool guides;
  final EditorSelection? selection;
  final bool swapping;

  BookPage get page =>
      pageIndex < 0 ? album.cover.front : album.pages[pageIndex];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = MemoriaColors.of(context);
    final format = BookFormat.byId(album.formatId);
    final controller = ref.read(editorControllerProvider(albumId).notifier);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final bleed = guides ? kBleedMm : 0.0;
    final boxW = format.trimWMm + 2 * bleed;
    final label = pageIndex < 0 ? l.editorCover : l.editorPage(pageIndex + 1);

    return LayoutBuilder(
      builder: (context, box) {
        final s = box.maxWidth / boxW;
        Rect px(RectMm r) => Rect.fromLTWH(
          (r.x + bleed) * s,
          (r.y + bleed) * s,
          r.w * s,
          r.h * s,
        );
        final sel = selection;
        return Semantics(
          label: label,
          container: true,
          explicitChildNodes: true,
          child: Stack(
            children: [
              GestureDetector(
                onTap: pageIndex < 0
                    ? null
                    : () => controller.select(PageSelection(pageIndex)),
                child: BookPageView(
                  album: album,
                  page: page,
                  includeBleed: guides,
                  foreground: guides
                      ? GuidesPainter(
                          format: format,
                          side: pageIndex < 0
                              ? null
                              : BookFormat.sideOf(pageIndex),
                          scale: s,
                        )
                      : null,
                ),
              ),
              for (var i = 0; i < page.frames.length; i++)
                _frameTarget(
                  context,
                  ref,
                  i,
                  px(_clip(page.frames[i].rectMm, format)),
                  c,
                  l,
                  locale,
                ),
              for (final t in page.texts)
                if (t.role != TextRole.pageNumber && t.text.isNotEmpty)
                  Positioned.fromRect(
                    rect: px(t.rectMm),
                    child: Semantics(
                      button: true,
                      label: t.text,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => controller.select(
                          EditorTextSelection(pageIndex, t.id),
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border:
                                sel is EditorTextSelection &&
                                    sel.pageIndex == pageIndex &&
                                    sel.textId == t.id
                                ? Border.all(color: c.info, width: 2)
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  /// Hit area of a frame, clipped to the visible page.
  RectMm _clip(RectMm r, BookFormat f) {
    final b = guides ? kBleedMm : 0.0;
    final x0 = r.x.clamp(-b, f.trimWMm + b), y0 = r.y.clamp(-b, f.trimHMm + b);
    final x1 = r.right.clamp(-b, f.trimWMm + b),
        y1 = r.bottom.clamp(-b, f.trimHMm + b);
    return RectMm(
      x: x0,
      y: y0,
      w: (x1 - x0).clamp(0, 10000),
      h: (y1 - y0).clamp(0, 10000),
    );
  }

  Widget _frameTarget(
    BuildContext context,
    WidgetRef ref,
    int i,
    Rect rect,
    MemoriaColors c,
    AppLocalizations l,
    String locale,
  ) {
    final frame = page.frames[i];
    final controller = ref.read(editorControllerProvider(albumId).notifier);
    final photo = frame.photoId == null ? null : album.photos[frame.photoId];
    final sel = selection;
    final selected =
        sel is FrameSelection &&
        sel.pageIndex == pageIndex &&
        sel.frameIndex == i;
    final semantics = [
      if (photo?.takenAt != null)
        l.photoSemantics(DateFormat.yMMMMd(locale).format(photo!.takenAt!)),
      ?photo?.placeName,
      if (photo != null && photo.faces.isNotEmpty)
        l.photoPeople(photo.faces.length),
    ].join(', ');

    Widget target = DragTarget<EditorDrag>(
      onWillAcceptWithDetails: (_) => pageIndex >= 0,
      onAcceptWithDetails: (d) {
        HapticFeedback.lightImpact();
        final data = d.data;
        switch (data) {
          case PhotoDrag(:final photoId):
            controller.apply(
              (ops, a) => ops.setPhoto(a, pageIndex, i, photoId),
            );
          case FrameDrag(pageIndex: final p, frameIndex: final f):
            if (p != pageIndex || f != i) {
              controller.apply(
                (ops, a) => ops.swapPhotos(a, (p, f), (pageIndex, i)),
              );
            }
        }
      },
      builder: (context, candidates, _) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => controller.select(FrameSelection(pageIndex, i)),
        child: AnimatedContainer(
          duration: Motion.short,
          decoration: BoxDecoration(
            border: selected || candidates.isNotEmpty
                ? Border.all(
                    color: candidates.isNotEmpty ? c.primary : c.info,
                    width: 2.5,
                  )
                : (swapping
                      ? Border.all(
                          color: c.info.withValues(alpha: 0.5),
                          width: 1,
                        )
                      : null),
            color: candidates.isNotEmpty
                ? c.primary.withValues(alpha: 0.12)
                : null,
          ),
        ),
      ),
    );
    if (pageIndex >= 0 && photo != null) {
      target = LongPressDraggable<EditorDrag>(
        data: FrameDrag(pageIndex, i),
        hapticFeedbackOnStart: true,
        feedback: Material(
          color: Colors.transparent,
          child: Opacity(
            opacity: 0.85,
            child: SizedBox(
              width: rect.width.clamp(48, 140),
              height: rect.height.clamp(48, 140),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.surfaceRaised,
                  boxShadow: Shadows.raised(c),
                  borderRadius: Radii.inputAll,
                ),
                child: Icon(Icons.photo_outlined, color: c.textSecondary),
              ),
            ),
          ),
        ),
        child: target,
      );
    }
    return Positioned.fromRect(
      rect: rect,
      child: Semantics(
        button: true,
        selected: selected,
        label: semantics.isEmpty ? l.tabPhotos : semantics,
        child: target,
      ),
    );
  }
}

/// Print guides (section 8.6): trim hairline, bleed band tinted red at
/// 10 %, safe area dashed. Drawn over a page rendered with its bleed.
class GuidesPainter extends CustomPainter {
  GuidesPainter({
    required this.format,
    required this.side,
    required this.scale,
  });

  final BookFormat format;

  /// Null for the cover (uniform 10 mm safe area).
  final PageSide? side;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final s = scale;
    final b = kBleedMm * s;
    final trim = Rect.fromLTWH(b, b, format.trimWMm * s, format.trimHMm * s);
    final full = Offset.zero & size;
    final band = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(full)
      ..addRect(trim);
    canvas.drawPath(
      band,
      Paint()..color = const Color(0xFFD64541).withValues(alpha: 0.10),
    );
    canvas.drawRect(
      trim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0xFF1F1B17).withValues(alpha: 0.7),
    );
    final safeMm = side == null
        ? format.trim.deflate(kSafeOuterMm)
        : format.safeArea(side!);
    final safe = Rect.fromLTWH(
      b + safeMm.x * s,
      b + safeMm.y * s,
      safeMm.w * s,
      safeMm.h * s,
    );
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF2E3A52).withValues(alpha: 0.6);
    void dashed(Offset a, Offset z) {
      final len = (z - a).distance;
      final dir = (z - a) / len;
      for (double d = 0; d < len; d += 8) {
        canvas.drawLine(a + dir * d, a + dir * (d + 4).clamp(0, len), dash);
      }
    }

    dashed(safe.topLeft, safe.topRight);
    dashed(safe.topRight, safe.bottomRight);
    dashed(safe.bottomRight, safe.bottomLeft);
    dashed(safe.bottomLeft, safe.topLeft);
  }

  @override
  bool shouldRepaint(GuidesPainter old) =>
      old.scale != scale || old.side != side || old.format != format;
}
