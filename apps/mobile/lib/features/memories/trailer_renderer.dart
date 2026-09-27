import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../data/services/motion_provider.dart';
import '../../domain/memories/trailer.dart';
import '../../domain/model/album.dart';
import '../../domain/spec/book_format.dart';
import '../../domain/text/font_registry.dart';
import '../../data/photos/photo_library.dart';
import '../book/book_images.dart';
import '../book/book_painter.dart';

/// Everything a trailer needs, decoded and pre-rendered once.
class TrailerAssets {
  TrailerAssets({
    required this.album,
    required this.cover,
    required this.pages,
    required this.spreads,
    required this.heroes,
    required this.motions,
    required this.pageAspect,
  });

  final Album album;
  final ui.Image cover;

  /// Page index → rendered page.
  final Map<int, ui.Image> pages;

  /// Spread numbers shown, in order.
  final List<int> spreads;
  final List<ui.Image> heroes;
  final List<HeroMotion> motions;

  /// Page width / height.
  final double pageAspect;

  void dispose() {
    cover.dispose();
    for (final p in [...pages.values, ...heroes]) {
      p.dispose();
    }
  }
}

/// Renders one page of [album] to an image [widthPx] wide, using the
/// decoded photos in [images].
Future<ui.Image> renderPageImage({
  required Album album,
  required BookPage page,
  required FontRegistry fonts,
  required Map<String, ui.Image> images,
  required int widthPx,
}) async {
  final f = BookFormat.byId(album.formatId);
  final heightPx = (widthPx / f.aspect).round();
  final rec = ui.PictureRecorder();
  BookPagePainter(
    page: page,
    trimWMm: f.trimWMm,
    trimHMm: f.trimHMm,
    fonts: fonts,
    images: images,
    photos: album.photos,
  ).paint(Canvas(rec), Size(widthPx.toDouble(), heightPx.toDouble()));
  final pic = rec.endRecording();
  final out = await pic.toImage(widthPx, heightPx);
  pic.dispose();
  return out;
}

/// Loads photos and pre-renders the pages the trailer shows.
Future<TrailerAssets> prepareTrailer({
  required Album album,
  required FontRegistry fonts,
  required PhotoImages photoImages,
  required MotionProvider motion,
  int pageWidthPx = 560,
}) async {
  final spreads = pickTrailerSpreads(album);
  final pageIdx = <int>{
    0,
    for (final s in spreads) ...[s * 2 - 1, s * 2],
  }.where((i) => i >= 0 && i < album.pages.length).toSet();
  final heroes = pickHeroPhotos(album);
  final size = BookImageStore.bucket(pageWidthPx.toDouble());
  final photoIds = <String>{
    for (final page in [
      album.cover.front,
      for (final i in pageIdx) album.pages[i],
    ])
      for (final fr in page.frames)
        if (fr.photoId != null && album.photos.containsKey(fr.photoId))
          fr.photoId!,
  };
  // Decoded here rather than through the on-screen cache, which evicts.
  final images = <String, ui.Image>{};
  await Future.wait([
    for (final id in photoIds)
      decodePhoto(photoImages, album.photos[id]!, size).then((img) {
        if (img != null) images[id] = img;
      }),
  ]);
  final heroImages = await Future.wait([
    for (final h in heroes) decodePhoto(photoImages, h, 2048),
  ]);
  final motions = await Future.wait(heroes.map(motion.animate));

  Future<ui.Image> page(BookPage p) => renderPageImage(
    album: album,
    page: p,
    fonts: fonts,
    images: images,
    widthPx: pageWidthPx,
  );
  final pages = <int, ui.Image>{
    for (final i in pageIdx) i: await page(album.pages[i]),
  };
  final cover = await page(album.cover.front);
  for (final img in images.values) {
    img.dispose();
  }
  final kept = <ui.Image>[];
  final keptMotions = <HeroMotion>[];
  for (var i = 0; i < heroes.length; i++) {
    if (heroImages[i] case final img?) {
      kept.add(img);
      keptMotions.add(motions[i]);
    }
  }
  return TrailerAssets(
    album: album,
    cover: cover,
    pages: pages,
    spreads: spreads,
    heroes: kept,
    motions: keptMotions,
    pageAspect: BookFormat.byId(album.formatId).aspect,
  );
}

const _paper = Color(0xFFF7F2E8);
const _endpaper = Color(0xFFEFE7DA);

/// Paints frame [t] (seconds) of the trailer. Used for the live preview and
/// for every encoded frame, so both look the same.
class TrailerPainter {
  TrailerPainter(
    this.assets,
    this.aspect, {
    required this.madeWith,
    required this.brand,
    this.watermark = true,
  }) : timeline = TrailerTimeline(
         spreads: assets.spreads.length,
         heroes: assets.heroes.length,
       );

  final TrailerAssets assets;
  final TrailerAspect aspect;
  final bool watermark;
  final TrailerTimeline timeline;

  /// "Made with Memoria" in the book's language, and the brand name.
  final String madeWith;
  final String brand;

  Size get size => Size(aspect.width.toDouble(), aspect.height.toDouble());

  /// Page size on screen for the open book.
  Size get _page {
    final w = size.width * 0.46;
    var h = w / assets.pageAspect;
    final maxH = size.height * 0.62;
    if (h > maxH) h = maxH;
    return Size(h * assets.pageAspect, h);
  }

  Offset get _spine => Offset(size.width / 2, size.height * 0.47);

  void paint(Canvas canvas, double t) {
    final (scene, p) = timeline.at(t);
    _backdrop(canvas);
    switch (scene.kind) {
      case TrailerSceneKind.cover:
        // Close-up that settles: 1.45x → 1.0x, turning toward the viewer.
        final e = Curves.easeOut.transform(p);
        _closedBook(canvas, scale: 1.45 - 0.45 * e, yaw: 0.28 * (1 - e));
      case TrailerSceneKind.opening:
        _opening(canvas, Curves.easeInOut.transform(p));
      case TrailerSceneKind.spread:
        _spreadTurn(canvas, scene.index, p);
      case TrailerSceneKind.hero:
        _hero(canvas, scene.index, p);
      case TrailerSceneKind.closing:
        final e = Curves.easeInOut.transform(p);
        _closedBook(canvas, scale: 1.0 - 0.12 * e, yaw: -0.3 * e);
        // Fade out of the last hero.
        if (p < 0.25 && assets.heroes.isNotEmpty) {
          canvas.saveLayer(
            Offset.zero & size,
            Paint()..color = Color.fromRGBO(0, 0, 0, 1 - p / 0.25),
          );
          _hero(canvas, assets.heroes.length - 1, 1);
          canvas.restore();
        }
      case TrailerSceneKind.endCard:
        _endCard(canvas, p);
    }
    if (watermark && scene.kind != TrailerSceneKind.endCard) _watermark(canvas);
  }

  void _backdrop(Canvas canvas) {
    final r = Offset.zero & size;
    canvas.drawRect(
      r,
      Paint()
        ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, const [
          Color(0xFFEFE7DA),
          Color(0xFFDCCFBB),
        ]),
    );
  }

  void _shadow(Canvas canvas, Rect r) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        r.shift(const Offset(0, 14)),
        const Radius.circular(8),
      ),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
  }

  void _image(Canvas canvas, ui.Image img, Rect dst, {bool flip = false}) {
    final src = Rect.fromLTWH(
      0,
      0,
      img.width.toDouble(),
      img.height.toDouble(),
    );
    final paint = Paint()..filterQuality = FilterQuality.medium;
    if (!flip) {
      canvas.drawImageRect(img, src, dst, paint);
      return;
    }
    canvas.save();
    canvas.translate(dst.center.dx, 0);
    canvas.scale(-1, 1);
    canvas.translate(-dst.center.dx, 0);
    canvas.drawImageRect(img, src, dst, paint);
    canvas.restore();
  }

  /// Rotation around the vertical line x = [x] with perspective.
  Float64List _hinge(double x, double angle) {
    final m = Matrix4.identity()
      ..translateByDouble(x, _spine.dy, 0, 1)
      ..multiply(Matrix4.identity()..setEntry(3, 2, 0.0011))
      ..rotateY(angle)
      ..translateByDouble(-x, -_spine.dy, 0, 1);
    return m.storage;
  }

  Rect get _right => Rect.fromLTWH(
    _spine.dx,
    _spine.dy - _page.height / 2,
    _page.width,
    _page.height,
  );

  Rect get _left => _right.shift(Offset(-_page.width, 0));

  void _closedBook(
    Canvas canvas, {
    required double scale,
    required double yaw,
  }) {
    final r = _right.shift(Offset(-_page.width / 2, 0));
    canvas.save();
    canvas.translate(r.center.dx, r.center.dy);
    canvas.scale(scale);
    canvas.translate(-r.center.dx, -r.center.dy);
    _shadow(canvas, r);
    // Page block peeking out on the fore edge.
    canvas.drawRect(
      Rect.fromLTRB(r.right - 4, r.top + 3, r.right + 3, r.bottom - 3),
      Paint()..color = _paper,
    );
    canvas.save();
    canvas.transform(_hinge(r.left, yaw));
    _image(canvas, assets.cover, r);
    _sheen(canvas, r, 0.5 + yaw);
    canvas.restore();
    canvas.restore();
  }

  void _sheen(Canvas canvas, Rect r, double at) {
    final x = r.left + r.width * (at * 1.6 - 0.3);
    canvas.drawRect(
      r,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.linear(
          Offset(x - r.width * 0.4, r.top),
          Offset(x + r.width * 0.4, r.bottom),
          const [Color(0x00FFFFFF), Color(0x22FFFFFF), Color(0x00FFFFFF)],
          const [0, 0.5, 1],
        ),
    );
  }

  void _opening(Canvas canvas, double e) {
    // The book slides so the spine ends up centred as the cover swings open.
    final dx = -_page.width / 2 * (1 - e);
    canvas.save();
    canvas.translate(dx, 0);
    final spread = Rect.fromLTRB(
      e > 0.5 ? _left.left : _right.left,
      _right.top,
      _right.right,
      _right.bottom,
    );
    _shadow(canvas, spread);
    if (assets.pages[0] case final title?) _image(canvas, title, _right);
    if (e > 0.5) canvas.drawRect(_left, Paint()..color = _endpaper);
    final angle = -math.pi * e;
    canvas.save();
    canvas.transform(_hinge(_spine.dx, angle));
    if (e <= 0.5) {
      _image(canvas, assets.cover, _right);
      canvas.drawRect(
        _right,
        Paint()..color = Color.fromRGBO(0, 0, 0, 0.25 * math.sin(e * math.pi)),
      );
    } else {
      canvas.drawRect(_right, Paint()..color = _endpaper);
    }
    canvas.restore();
    _gutter(canvas);
    canvas.restore();
  }

  ({ui.Image? left, ui.Image? right}) _spreadPages(int spread) {
    if (spread <= 0) return (left: null, right: assets.pages[0]);
    return (
      left: assets.pages[spread * 2 - 1],
      right: assets.pages[spread * 2],
    );
  }

  void _pageOrPaper(
    Canvas canvas,
    ui.Image? img,
    Rect r, {
    Color paper = _paper,
    bool flip = false,
  }) {
    if (img == null) {
      canvas.drawRect(r, Paint()..color = paper);
    } else {
      _image(canvas, img, r, flip: flip);
    }
  }

  void _gutter(Canvas canvas) {
    final g = Rect.fromCenter(
      center: Offset(_spine.dx, _spine.dy),
      width: _page.width * 0.12,
      height: _page.height,
    );
    canvas.drawRect(
      g,
      Paint()
        ..shader = ui.Gradient.linear(
          g.centerLeft,
          g.centerRight,
          const [Color(0x00000000), Color(0x30000000), Color(0x00000000)],
          const [0, 0.5, 1],
        ),
    );
  }

  void _spreadTurn(Canvas canvas, int i, double p) {
    final from = _spreadPages(i == 0 ? 0 : assets.spreads[i - 1]);
    final to = _spreadPages(assets.spreads[i]);
    // Turn in the first 55 %, then hold with a slow push-in.
    final turn = Curves.easeInOut.transform((p / 0.55).clamp(0.0, 1.0));
    final push = 1 + 0.03 * p;
    canvas.save();
    canvas.translate(_spine.dx, _spine.dy);
    canvas.scale(push);
    canvas.translate(-_spine.dx, -_spine.dy);
    _shadow(
      canvas,
      Rect.fromLTRB(_left.left, _left.top, _right.right, _right.bottom),
    );
    _pageOrPaper(canvas, from.left, _left, paper: _endpaper);
    _pageOrPaper(canvas, to.right, _right);
    if (turn < 1) {
      final angle = -math.pi * turn;
      // Shadow the turning leaf casts on the page below.
      final shade = 0.22 * math.sin(turn * math.pi);
      canvas.drawRect(
        turn < 0.5 ? _right : _left,
        Paint()..color = Color.fromRGBO(0, 0, 0, shade),
      );
      canvas.save();
      canvas.transform(_hinge(_spine.dx, angle));
      if (turn <= 0.5) {
        _pageOrPaper(canvas, from.right, _right);
      } else {
        // The back is drawn mirrored so it reads correctly once turned.
        _pageOrPaper(canvas, to.left, _right, paper: _endpaper, flip: true);
      }
      canvas.drawRect(
        _right,
        Paint()
          ..color = Color.fromRGBO(0, 0, 0, 0.18 * math.sin(turn * math.pi)),
      );
      canvas.restore();
    } else {
      _pageOrPaper(canvas, to.left, _left, paper: _endpaper);
    }
    _gutter(canvas);
    canvas.restore();
  }

  void _hero(Canvas canvas, int i, double p) {
    if (i >= assets.heroes.length) return;
    final img = assets.heroes[i];
    final m = assets.motions[i];
    final r = Offset.zero & size;
    final iw = img.width.toDouble(), ih = img.height.toDouble();
    // Cover-fit the photo, centred on the focus.
    final fx = (m.focusX + m.focusW / 2) * iw,
        fy = (m.focusY + m.focusH / 2) * ih;
    final e = Curves.easeInOut.transform(p);
    Rect crop(double zoom, Offset drift) {
      final s = math.max(size.width / iw, size.height / ih) * zoom;
      final cw = size.width / s, ch = size.height / s;
      final cx = (fx + drift.dx * cw).clamp(cw / 2, iw - cw / 2);
      final cy = (fy + drift.dy * ch).clamp(ch / 2, ih - ch / 2);
      return Rect.fromCenter(center: Offset(cx, cy), width: cw, height: ch);
    }

    final paint = Paint()..filterQuality = FilterQuality.medium;
    // Background layer drifts one way...
    final bg = crop(1.08 + 0.05 * e, Offset(0.03 - 0.06 * e, 0));
    canvas.drawImageRect(img, bg, r, paint);
    // ...the subject, cut out with a soft mask, drifts the other way and
    // comes closer: the parallax that makes the photo feel alive.
    final fg = crop(1.08 + 0.12 * e, Offset(-0.02 + 0.04 * e, -0.01 * e));
    final subject = Rect.fromLTWH(
      (m.focusX * iw - fg.left) / fg.width * size.width,
      (m.focusY * ih - fg.top) / fg.height * size.height,
      m.focusW * iw / fg.width * size.width,
      m.focusH * ih / fg.height * size.height,
    ).inflate(size.width * 0.06);
    canvas.saveLayer(r, Paint());
    canvas.drawImageRect(img, fg, r, paint);
    canvas.drawRect(
      r,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.radial(
          subject.center,
          math.max(subject.width, subject.height) * 0.62,
          const [Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
          const [0, 0.6, 1],
          TileMode.clamp,
          (Matrix4.identity()
                ..translateByDouble(subject.center.dx, subject.center.dy, 0, 1)
                ..scaleByDouble(
                  1,
                  subject.height / math.max(1, subject.width),
                  1,
                  1,
                )
                ..translateByDouble(
                  -subject.center.dx,
                  -subject.center.dy,
                  0,
                  1,
                ))
              .storage,
        ),
    );
    canvas.restore();
    // Warm light that slowly passes over.
    canvas.drawRect(
      r,
      Paint()
        ..blendMode = BlendMode.softLight
        ..shader = ui.Gradient.radial(
          Offset(size.width * (0.2 + 0.6 * e), size.height * 0.2),
          size.width,
          const [Color(0x55FFE3B0), Color(0x00FFE3B0)],
        ),
    );
    // Fade in from the book.
    if (p < 0.14) {
      canvas.drawRect(
        r,
        Paint()
          ..color = const Color(0xFFE6DCCB).withValues(alpha: 1 - p / 0.14),
      );
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset center,
    double fontSize, {
    String family = 'CormorantGaramond',
    Color color = const Color(0xFF2B2622),
    FontWeight weight = FontWeight.w400,
    double letterSpacing = 0,
    double opacity = 1,
  }) {
    final b =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: TextAlign.center,
              fontFamily: family,
              fontSize: fontSize,
              maxLines: 3,
            ),
          )
          ..pushStyle(
            ui.TextStyle(
              color: color.withValues(alpha: color.a * opacity),
              fontWeight: weight,
              letterSpacing: letterSpacing,
              fontFamily: family,
            ),
          )
          ..addText(text);
    final para = b.build()
      ..layout(ui.ParagraphConstraints(width: size.width * 0.84));
    canvas.drawParagraph(
      para,
      Offset(center.dx - size.width * 0.42, center.dy - para.height / 2),
    );
  }

  void _endCard(Canvas canvas, double p) {
    final r = Offset.zero & size;
    canvas.drawRect(r, Paint()..color = _paper);
    final a = Curves.easeOut.transform((p / 0.35).clamp(0.0, 1.0));
    final cy = size.height / 2;
    _text(
      canvas,
      assets.album.title,
      Offset(size.width / 2, cy - 40),
      size.width * 0.075,
      opacity: a,
    );
    canvas.drawLine(
      Offset(size.width / 2 - 28 * a, cy + 8),
      Offset(size.width / 2 + 28 * a, cy + 8),
      Paint()
        ..color = const Color(0xFFB8955A)
        ..strokeWidth = 1.5,
    );
    _text(
      canvas,
      madeWith,
      Offset(size.width / 2, cy + 48),
      size.width * 0.036,
      family: 'Inter',
      color: const Color(0xFF6B625A),
      letterSpacing: 1.2,
      opacity: a,
    );
  }

  void _watermark(Canvas canvas) {
    final b =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(fontFamily: 'CormorantGaramond', fontSize: 26),
          )
          ..pushStyle(
            ui.TextStyle(
              color: const Color(0x99FFFFFF),
              shadows: const [Shadow(color: Color(0x66000000), blurRadius: 6)],
            ),
          )
          ..addText(brand);
    final para = b.build()..layout(const ui.ParagraphConstraints(width: 200));
    canvas.drawParagraph(
      para,
      Offset(
        size.width - para.maxIntrinsicWidth - 24,
        size.height - para.height - 22,
      ),
    );
  }

  /// One frame as raw RGBA bytes for the encoder.
  Future<ByteData> frameRgba(double t) async {
    final rec = ui.PictureRecorder();
    paint(Canvas(rec), t);
    final pic = rec.endRecording();
    final img = await pic.toImage(aspect.width, aspect.height);
    pic.dispose();
    final bytes = await img.toByteData();
    img.dispose();
    return bytes!;
  }
}
