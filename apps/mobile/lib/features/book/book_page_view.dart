import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/domain_kit.dart';
import '../../design/design.dart';
import '../../domain/model/album.dart';
import '../../domain/spec/book_format.dart';
import 'book_images.dart';
import 'book_painter.dart';

/// Renders one page (or cover panel) of [album] at the widget's size.
/// Images load progressively at a resolution matching the display.
class BookPageView extends ConsumerStatefulWidget {
  const BookPageView({
    required this.album,
    required this.page,
    this.widthMm,
    this.heightMm,
    this.includeBleed = false,
    this.softProof = false,
    this.semanticLabel,
    this.foreground,
    super.key,
  });

  final Album album;
  final BookPage page;

  /// Panel size; defaults to the album's trim size (spine panels differ).
  final double? widthMm;
  final double? heightMm;
  final bool includeBleed;
  final bool softProof;
  final String? semanticLabel;

  /// Painted above the page (print guides, selection).
  final CustomPainter? foreground;

  @override
  ConsumerState<BookPageView> createState() => _BookPageViewState();
}

class _BookPageViewState extends ConsumerState<BookPageView> {
  late final BookImageStore _store = ref.read(bookImageStoreProvider);
  int _version = 0;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onImages);
  }

  @override
  void dispose() {
    _store.removeListener(_onImages);
    super.dispose();
  }

  void _onImages() {
    if (mounted) setState(() => _version++);
  }

  @override
  Widget build(BuildContext context) {
    final kit = ref.watch(domainKitProvider).value;
    final format = BookFormat.byId(widget.album.formatId);
    final w = widget.widthMm ?? format.trimWMm;
    final h = widget.heightMm ?? format.trimHMm;
    final boxW = widget.includeBleed ? w + 8 : w;
    final boxH = widget.includeBleed ? h + 8 : h;
    final colors = MemoriaColors.of(context);
    return Semantics(
      label: widget.semanticLabel,
      image: true,
      child: AspectRatio(
        aspectRatio: boxW / boxH,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (kit == null) {
              return ColoredBox(color: colors.surfaceRaised);
            }
            final dpr = MediaQuery.devicePixelRatioOf(context);
            final images = <String, ui.Image>{};
            for (final f in widget.page.frames) {
              final id = f.photoId;
              final photo = id == null ? null : widget.album.photos[id];
              if (photo == null) continue;
              final framePx = constraints.maxWidth * (f.rectMm.w / boxW) * dpr;
              final size = BookImageStore.bucket(framePx.clamp(64, 3072));
              _store.request(photo, size);
              final img = _store.get(photo, size);
              if (img != null) images[photo.id] = img;
            }
            return CustomPaint(
              size: Size(
                constraints.maxWidth,
                constraints.maxWidth * boxH / boxW,
              ),
              painter: BookPagePainter(
                page: widget.page,
                trimWMm: w,
                trimHMm: h,
                fonts: kit.fonts,
                images: images,
                photos: widget.album.photos,
                includeBleed: widget.includeBleed,
                softProof: widget.softProof,
                placeholder: colors.surface,
                repaintKey: _version,
              ),
              foregroundPainter: widget.foreground,
            );
          },
        ),
      ),
    );
  }
}
