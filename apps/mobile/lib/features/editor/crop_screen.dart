import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../design/design.dart';
import '../../domain/layout/smart_crop.dart';
import '../../domain/model/album.dart';
import '../../domain/model/geometry.dart';
import '../../domain/preflight/preflight.dart';
import '../book/book_images.dart';
import 'editor_controller.dart';

/// Full-screen crop & zoom with a live print-resolution meter.
class CropScreen extends ConsumerStatefulWidget {
  const CropScreen({
    required this.albumId,
    required this.pageIndex,
    required this.frameIndex,
    super.key,
  });

  final String albumId;
  final int pageIndex;
  final int frameIndex;

  @override
  ConsumerState<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends ConsumerState<CropScreen> {
  CropRect? _crop;
  late CropRect _startCrop;
  late final BookImageStore _store;

  @override
  void initState() {
    super.initState();
    _store = ref.read(bookImageStoreProvider)..addListener(_changed);
  }

  @override
  void dispose() {
    _store.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// Largest crop of the frame aspect (zoom 1).
  CropRect _base(PhotoRef p, double aspect) =>
      smartCrop(p.copyWith(faces: const []), aspect).crop;

  CropRect _clamp(CropRect c, PhotoRef p, double aspect) {
    final base = _base(p, aspect);
    var w = c.w.clamp(base.w / 8, base.w).toDouble();
    var h = w * base.h / base.w;
    if (h > base.h) {
      h = base.h;
      w = h * base.w / base.h;
    }
    final x = c.x.clamp(0.0, 1 - w).toDouble();
    final y = c.y.clamp(0.0, 1 - h).toDouble();
    return CropRect(x: x, y: y, w: w, h: h);
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
    final frame = state.album.pages[widget.pageIndex].frames[widget.frameIndex];
    final photo = state.album.photos[frame.photoId]!;
    final inner = frame.borderMm > 0
        ? frame.rectMm.deflate(frame.borderMm)
        : frame.rectMm;
    final aspect = inner.aspect;
    final crop = _crop ??= frame.crop;
    _store.request(photo, 2048);
    final image = _store.get(photo, 2048);
    final dpi = effectiveDpi(photo, crop, inner);
    final (color, icon, label) = dpi < kBlockDpi
        ? (c.error, Icons.error_outline_rounded, l.cropTooSoft)
        : dpi < kWarnDpi
        ? (c.warning, Icons.warning_amber_rounded, l.cropSoft)
        : (c.secondary, Icons.check_circle_outline_rounded, l.cropSharp);

    return Scaffold(
      backgroundColor: const Color(0xFF06101F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF06101F),
        foregroundColor: const Color(0xFFF4F7FC),
        title: Text(l.photoCrop),
        actions: [
          TextButton(
            onPressed: () =>
                setState(() => _crop = smartCrop(photo, aspect).crop),
            child: Text(
              l.cropReset,
              style: const TextStyle(color: Color(0xFFF4F7FC)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(Space.lg),
                  child: AspectRatio(
                    aspectRatio: aspect,
                    child: LayoutBuilder(
                      builder: (context, box) => GestureDetector(
                        onScaleStart: (_) => _startCrop = crop,
                        onScaleUpdate: (d) {
                          final zoomed = _startCrop.w / d.scale;
                          final cx =
                              _startCrop.x +
                              _startCrop.w / 2 -
                              d.focalPointDelta.dx / box.maxWidth * crop.w;
                          final cy =
                              _startCrop.y +
                              _startCrop.h / 2 -
                              d.focalPointDelta.dy / box.maxHeight * crop.h;
                          final h = zoomed * _startCrop.h / _startCrop.w;
                          setState(() {
                            _startCrop = _clamp(
                              CropRect(
                                x: cx - zoomed / 2,
                                y: cy - h / 2,
                                w: zoomed,
                                h: h,
                              ),
                              photo,
                              aspect,
                            );
                            _crop = _startCrop;
                          });
                        },
                        child: Semantics(
                          label: '${l.photoCrop}. ${l.cropHint}',
                          image: true,
                          child: CustomPaint(
                            size: Size(box.maxWidth, box.maxHeight),
                            painter: _CropPainter(image, crop),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Text(
              l.cropHint,
              style: t.bodySmall?.copyWith(color: const Color(0xFFA9BEE3)),
            ),
            const SizedBox(height: Space.sm),
            Semantics(
              liveRegion: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: Space.xs),
                  Text(
                    '$label · ${l.cropDpi(dpi.round())}',
                    style: t.labelLarge?.copyWith(color: color),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: PrimaryButton(
                label: l.commonDone,
                onPressed: () {
                  ref
                      .read(editorControllerProvider(widget.albumId).notifier)
                      .apply(
                        (ops, a) => ops.setCrop(
                          a,
                          widget.pageIndex,
                          widget.frameIndex,
                          crop,
                        ),
                        keepSelection: true,
                      );
                  context.pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.image, this.crop);

  final ui.Image? image;
  final CropRect crop;

  @override
  void paint(Canvas canvas, Size size) {
    final dst = Offset.zero & size;
    final img = image;
    if (img == null) {
      canvas.drawRect(dst, Paint()..color = const Color(0xFF123067));
      return;
    }
    final src = Rect.fromLTWH(
      crop.x * img.width,
      crop.y * img.height,
      crop.w * img.width,
      crop.h * img.height,
    );
    canvas.drawImageRect(
      img,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
    // Rule-of-thirds guides.
    final guide = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (final f in [1 / 3, 2 / 3]) {
      canvas.drawLine(
        Offset(size.width * f, 0),
        Offset(size.width * f, size.height),
        guide,
      );
      canvas.drawLine(
        Offset(0, size.height * f),
        Offset(size.width, size.height * f),
        guide,
      );
    }
    canvas.drawRect(
      dst,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white.withValues(alpha: 0.8)
        ..strokeWidth = math.max(1, size.width / 400),
    );
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.crop != crop || old.image != image;
}
