import 'dart:math' as math;

import '../model/geometry.dart';
import '../spec/book_format.dart';
import '../spec/spec_data.dart';

enum TemplateKind { photo, special }

enum CaptionMode { none, below, side }

/// Input for one photo slot: the photo's aspect and whether it has a caption.
class SlotInput {
  const SlotInput({required this.aspect, this.hasCaption = false});

  final double aspect;
  final bool hasCaption;
}

class SlotGeometry {
  const SlotGeometry(
    this.rect, {
    this.rotationDeg = 0,
    this.borderMm = 0,
    this.captionRect,
  });

  final RectMm rect;
  final double rotationDeg;
  final double borderMm;
  final RectMm? captionRect;
}

class TemplateGeometry {
  const TemplateGeometry({
    required this.slots,
    this.textArea,
    this.hidePageNumber = false,
  });

  final List<SlotGeometry> slots;

  /// Free text area (photo_with_text_*, chapter openers...).
  final RectMm? textArea;
  final bool hidePageNumber;
}

class TemplateContext {
  const TemplateContext({
    required this.format,
    required this.side,
    required this.mirrored,
    required this.slots,
    this.rotationSeed = 0,
  });

  final BookFormat format;
  final PageSide side;
  final bool mirrored;
  final List<SlotInput> slots;
  final int rotationSeed;

  double get w => format.trimWMm;
  double get h => format.trimHMm;

  /// Content box: the safe area for this page side.
  RectMm get content => format.safeArea(side);

  /// Gap between photos, scaled with the page (4 mm on Classic).
  double get gap => math.max(3, w * 0.02);

  /// Space reserved under a photo for a caption (3 mm gap + two lines of 9 pt).
  static const double captionBand = 12;
  static const double captionGap = 3;
}

typedef TemplateBuilder = TemplateGeometry Function(TemplateContext c);

class PageTemplate {
  const PageTemplate({
    required this.id,
    required this.kind,
    required this.minPhotos,
    required this.maxPhotos,
    required this.build,
    this.captionMode = CaptionMode.none,
    this.isHero = false,
    this.fullBleed = false,
    this.playfulOnly = false,
    this.panorama = false,
  });

  final String id;
  final TemplateKind kind;
  final int minPhotos;
  final int maxPhotos;
  final TemplateBuilder build;
  final CaptionMode captionMode;
  final bool isHero;
  final bool fullBleed;
  final bool playfulOnly;
  final bool panorama;

  /// Grid pages (≥ 4 photos) are paced: never more than two in a row.
  bool get isGrid => minPhotos >= 4;

  bool accepts(int n) => n >= minPhotos && n <= maxPhotos;

  static PageTemplate byId(String id) => kPageTemplates.firstWhere(
    (t) => t.id == id,
    orElse: () => kPageTemplates.first,
  );

  static List<PageTemplate> photoTemplates({required bool playful}) =>
      kPageTemplates
          .where(
            (t) =>
                t.kind == TemplateKind.photo &&
                !t.panorama &&
                (playful || !t.playfulOnly),
          )
          .toList();
}

// ---------------------------------------------------------------------------
// Geometry helpers

/// Largest rect of [aspect] (clamped to [minA]..[maxA]) inside [box],
/// positioned by [ax]/[ay] (0 = start, 0.5 = centre, 1 = end).
RectMm fitAspect(
  RectMm box,
  double aspect, {
  double minA = 0.2,
  double maxA = 5,
  double ax = 0.5,
  double ay = 0.5,
}) {
  final a = aspect.clamp(minA, maxA);
  double w = box.w, h = box.w / a;
  if (h > box.h) {
    h = box.h;
    w = h * a;
  }
  return RectMm(
    x: box.x + (box.w - w) * ax,
    y: box.y + (box.h - h) * ay,
    w: w,
    h: h,
  );
}

RectMm _mirror(TemplateContext c, RectMm r) {
  if (!c.mirrored) return r;
  // Mirror inside the content box so gutter margins stay correct.
  final box = c.content;
  return RectMm(x: box.x + box.right - r.right, y: r.y, w: r.w, h: r.h);
}

SlotGeometry _slot(
  TemplateContext c,
  RectMm r, {
  int index = 0,
  double rotation = 0,
  double border = 0,
}) {
  final hasCaption = index < c.slots.length && c.slots[index].hasCaption;
  final photo = hasCaption
      ? RectMm(x: r.x, y: r.y, w: r.w, h: r.h - TemplateContext.captionBand)
      : r;
  final rect = _mirror(c, photo);
  final caption = hasCaption
      ? _mirror(
          c,
          RectMm(
            x: r.x,
            y: photo.bottom + TemplateContext.captionGap,
            w: r.w,
            h: TemplateContext.captionBand - TemplateContext.captionGap,
          ),
        )
      : null;
  return SlotGeometry(
    rect,
    rotationDeg: rotation,
    borderMm: border,
    captionRect: caption,
  );
}

double _aspect(TemplateContext c, int i) =>
    i < c.slots.length ? c.slots[i].aspect : 1.5;

// ---------------------------------------------------------------------------
// Templates

final List<PageTemplate> kPageTemplates = [
  PageTemplate(
    id: 'full_bleed',
    kind: TemplateKind.photo,
    minPhotos: 1,
    maxPhotos: 1,
    isHero: true,
    fullBleed: true,
    build: (c) => TemplateGeometry(
      slots: [SlotGeometry(c.format.trim.inflate(kBleedMm))],
      hidePageNumber: true,
    ),
  ),
  PageTemplate(
    id: 'hero_bordered',
    kind: TemplateKind.photo,
    minPhotos: 1,
    maxPhotos: 1,
    isHero: true,
    captionMode: CaptionMode.below,
    build: (c) {
      final hasCap = c.slots.isNotEmpty && c.slots[0].hasCaption;
      final box = c.content;
      final avail = RectMm(
        x: box.x,
        y: box.y,
        w: box.w,
        h: box.h - (hasCap ? TemplateContext.captionBand : 0),
      );
      final r = fitAspect(avail, _aspect(c, 0), minA: 0.7, maxA: 1.6, ay: 0.4);
      final withCap = RectMm(
        x: r.x,
        y: r.y,
        w: r.w,
        h: r.h + (hasCap ? TemplateContext.captionBand : 0),
      );
      return TemplateGeometry(slots: [_slot(c, withCap)]);
    },
  ),
  PageTemplate(
    id: 'hero_centered',
    kind: TemplateKind.photo,
    minPhotos: 1,
    maxPhotos: 1,
    isHero: true,
    captionMode: CaptionMode.below,
    build: (c) {
      final box = c.content;
      final inset = math.min(box.w, box.h) * 0.14;
      final inner = box.deflate(inset);
      final hasCap = c.slots.isNotEmpty && c.slots[0].hasCaption;
      final avail = RectMm(
        x: inner.x,
        y: inner.y,
        w: inner.w,
        h: inner.h - (hasCap ? TemplateContext.captionBand : 0),
      );
      final r = fitAspect(
        avail,
        _aspect(c, 0),
        minA: 0.66,
        maxA: 1.6,
        ay: 0.42,
      );
      return TemplateGeometry(
        slots: [
          _slot(
            c,
            RectMm(
              x: r.x,
              y: r.y,
              w: r.w,
              h: r.h + (hasCap ? TemplateContext.captionBand : 0),
            ),
          ),
        ],
      );
    },
  ),
  PageTemplate(
    id: 'photo_with_text_right',
    kind: TemplateKind.photo,
    minPhotos: 1,
    maxPhotos: 1,
    captionMode: CaptionMode.side,
    build: (c) {
      final box = c.content;
      final photoBox = RectMm(x: box.x, y: box.y, w: box.w * 0.6, h: box.h);
      final r = fitAspect(
        photoBox,
        _aspect(c, 0),
        minA: 0.66,
        maxA: 1.1,
        ax: 0,
      );
      final textX = r.right + c.gap * 2;
      final text = RectMm(
        x: textX,
        y: box.y + box.h * 0.3,
        w: box.right - textX,
        h: box.h * 0.4,
      );
      return TemplateGeometry(
        slots: [SlotGeometry(_mirror(c, r))],
        textArea: _mirror(c, text),
      );
    },
  ),
  PageTemplate(
    id: 'photo_with_text_below',
    kind: TemplateKind.photo,
    minPhotos: 1,
    maxPhotos: 1,
    captionMode: CaptionMode.side,
    build: (c) {
      final box = c.content;
      final photoBox = RectMm(x: box.x, y: box.y, w: box.w, h: box.h * 0.72);
      final r = fitAspect(photoBox, _aspect(c, 0), minA: 1.0, maxA: 1.8, ay: 0);
      final text = RectMm(
        x: box.x,
        y: r.bottom + c.gap * 1.5,
        w: box.w * 0.72,
        h: box.bottom - r.bottom - c.gap * 1.5,
      );
      return TemplateGeometry(
        slots: [SlotGeometry(_mirror(c, r))],
        textArea: _mirror(c, text),
      );
    },
  ),
  PageTemplate(
    id: 'two_stacked',
    kind: TemplateKind.photo,
    minPhotos: 2,
    maxPhotos: 2,
    captionMode: CaptionMode.below,
    build: (c) {
      final box = c.content;
      final h = (box.h - c.gap) / 2;
      return TemplateGeometry(
        slots: [
          _slot(c, RectMm(x: box.x, y: box.y, w: box.w, h: h), index: 0),
          _slot(
            c,
            RectMm(x: box.x, y: box.y + h + c.gap, w: box.w, h: h),
            index: 1,
          ),
        ],
      );
    },
  ),
  PageTemplate(
    id: 'two_side_by_side',
    kind: TemplateKind.photo,
    minPhotos: 2,
    maxPhotos: 2,
    captionMode: CaptionMode.below,
    build: (c) {
      final box = c.content;
      final w = (box.w - c.gap) / 2;
      final anyCap = c.slots.any((s) => s.hasCaption);
      final h = math.min(
        box.h,
        w * 1.45 + (anyCap ? TemplateContext.captionBand : 0),
      );
      final y = box.y + (box.h - h) * 0.42;
      return TemplateGeometry(
        slots: [
          _slot(c, RectMm(x: box.x, y: y, w: w, h: h), index: 0),
          _slot(c, RectMm(x: box.x + w + c.gap, y: y, w: w, h: h), index: 1),
        ],
      );
    },
  ),
  PageTemplate(
    id: 'two_offset',
    kind: TemplateKind.photo,
    minPhotos: 2,
    maxPhotos: 2,
    build: (c) {
      final box = c.content;
      final a = RectMm(x: box.x, y: box.y, w: box.w * 0.68, h: box.h * 0.5);
      final bw = box.w * 0.42;
      final bh = box.h * 0.44;
      final b = RectMm(x: box.right - bw, y: box.bottom - bh, w: bw, h: bh);
      return TemplateGeometry(slots: [_slot(c, a), _slot(c, b, index: 1)]);
    },
  ),
  PageTemplate(
    id: 'two_portraits_framed',
    kind: TemplateKind.photo,
    minPhotos: 2,
    maxPhotos: 2,
    build: (c) {
      final box = c.content.deflate(math.min(c.content.w, c.content.h) * 0.06);
      final w = (box.w - c.gap * 1.5) / 2;
      final h = math.min(box.h, w * 1.33);
      final y = box.y + (box.h - h) / 2;
      return TemplateGeometry(
        slots: [
          _slot(c, RectMm(x: box.x, y: y, w: w, h: h), border: 0.8),
          _slot(
            c,
            RectMm(x: box.x + w + c.gap * 1.5, y: y, w: w, h: h),
            index: 1,
            border: 0.8,
          ),
        ],
      );
    },
  ),
  PageTemplate(
    id: 'three_one_big_two_small',
    kind: TemplateKind.photo,
    minPhotos: 3,
    maxPhotos: 3,
    build: (c) {
      final box = c.content;
      final bigW = (box.w - c.gap) * 0.6;
      final smallW = box.w - c.gap - bigW;
      final smallH = (box.h - c.gap) / 2;
      final sx = box.x + bigW + c.gap;
      return TemplateGeometry(
        slots: [
          _slot(c, RectMm(x: box.x, y: box.y, w: bigW, h: box.h)),
          _slot(c, RectMm(x: sx, y: box.y, w: smallW, h: smallH), index: 1),
          _slot(
            c,
            RectMm(x: sx, y: box.y + smallH + c.gap, w: smallW, h: smallH),
            index: 2,
          ),
        ],
      );
    },
  ),
  PageTemplate(
    id: 'three_columns',
    kind: TemplateKind.photo,
    minPhotos: 3,
    maxPhotos: 3,
    captionMode: CaptionMode.below,
    build: (c) {
      final box = c.content;
      final w = (box.w - 2 * c.gap) / 3;
      final anyCap = c.slots.any((s) => s.hasCaption);
      final h = math.min(
        box.h,
        w * 1.5 + (anyCap ? TemplateContext.captionBand : 0),
      );
      final y = box.y + (box.h - h) * 0.42;
      return TemplateGeometry(
        slots: [
          for (var i = 0; i < 3; i++)
            _slot(
              c,
              RectMm(x: box.x + i * (w + c.gap), y: y, w: w, h: h),
              index: i,
            ),
        ],
      );
    },
  ),
  PageTemplate(
    id: 'three_rows',
    kind: TemplateKind.photo,
    minPhotos: 3,
    maxPhotos: 3,
    build: (c) {
      final box = c.content;
      final h = (box.h - 2 * c.gap) / 3;
      return TemplateGeometry(
        slots: [
          for (var i = 0; i < 3; i++)
            _slot(
              c,
              RectMm(x: box.x, y: box.y + i * (h + c.gap), w: box.w, h: h),
              index: i,
            ),
        ],
      );
    },
  ),
  PageTemplate(
    id: 'four_grid',
    kind: TemplateKind.photo,
    minPhotos: 4,
    maxPhotos: 4,
    build: (c) {
      final box = c.content;
      final w = (box.w - c.gap) / 2;
      final h = (box.h - c.gap) / 2;
      return TemplateGeometry(
        slots: [
          for (var i = 0; i < 4; i++)
            _slot(
              c,
              RectMm(
                x: box.x + (i % 2) * (w + c.gap),
                y: box.y + (i ~/ 2) * (h + c.gap),
                w: w,
                h: h,
              ),
              index: i,
            ),
        ],
      );
    },
  ),
  PageTemplate(
    id: 'four_one_big_three_small',
    kind: TemplateKind.photo,
    minPhotos: 4,
    maxPhotos: 4,
    build: (c) {
      final box = c.content;
      final bigH = (box.h - c.gap) * 0.62;
      final smallH = box.h - c.gap - bigH;
      final smallW = (box.w - 2 * c.gap) / 3;
      final y = box.y + bigH + c.gap;
      return TemplateGeometry(
        slots: [
          _slot(c, RectMm(x: box.x, y: box.y, w: box.w, h: bigH)),
          for (var i = 0; i < 3; i++)
            _slot(
              c,
              RectMm(
                x: box.x + i * (smallW + c.gap),
                y: y,
                w: smallW,
                h: smallH,
              ),
              index: i + 1,
            ),
        ],
      );
    },
  ),
  PageTemplate(
    id: 'five_mosaic',
    kind: TemplateKind.photo,
    minPhotos: 5,
    maxPhotos: 5,
    build: (c) {
      final box = c.content;
      final bigW = (box.w - c.gap) / 2;
      final smallW = (bigW - c.gap) / 2;
      final smallH = (box.h - c.gap) / 2;
      final sx = box.x + bigW + c.gap;
      return TemplateGeometry(
        slots: [
          _slot(c, RectMm(x: box.x, y: box.y, w: bigW, h: box.h)),
          for (var i = 0; i < 4; i++)
            _slot(
              c,
              RectMm(
                x: sx + (i % 2) * (smallW + c.gap),
                y: box.y + (i ~/ 2) * (smallH + c.gap),
                w: smallW,
                h: smallH,
              ),
              index: i + 1,
            ),
        ],
      );
    },
  ),
  PageTemplate(
    id: 'six_grid',
    kind: TemplateKind.photo,
    minPhotos: 6,
    maxPhotos: 6,
    build: (c) {
      final box = c.content;
      final cols = c.format.aspect > 1.2 ? 3 : 2;
      final rows = 6 ~/ cols;
      final w = (box.w - (cols - 1) * c.gap) / cols;
      final h = (box.h - (rows - 1) * c.gap) / rows;
      return TemplateGeometry(
        slots: [
          for (var i = 0; i < 6; i++)
            _slot(
              c,
              RectMm(
                x: box.x + (i % cols) * (w + c.gap),
                y: box.y + (i ~/ cols) * (h + c.gap),
                w: w,
                h: h,
              ),
              index: i,
            ),
        ],
      );
    },
  ),
  PageTemplate(
    id: 'polaroid_scatter',
    kind: TemplateKind.photo,
    minPhotos: 2,
    maxPhotos: 4,
    playfulOnly: true,
    build: (c) {
      final box = c.content;
      final n = c.slots.length.clamp(2, 4);
      final rng = math.Random(c.rotationSeed);
      double rot() => (rng.nextDouble() * 8 - 4);
      final size = n == 2 ? box.w * 0.52 : box.w * 0.44;
      final positions = switch (n) {
        2 => [(0.02, 0.04), (0.44, 0.44)],
        3 => [(0.0, 0.02), (0.5, 0.12), (0.22, 0.5)],
        _ => [(0.0, 0.0), (0.52, 0.04), (0.04, 0.5), (0.54, 0.52)],
      };
      final slots = <SlotGeometry>[];
      for (var i = 0; i < n; i++) {
        final (fx, fy) = positions[i];
        final r = RectMm(
          x: box.x + box.w * fx,
          y: box.y + box.h * fy,
          w: size,
          h: math.min(size * 0.92, box.h * 0.48),
        );
        slots.add(_slot(c, r, index: i, rotation: rot(), border: 3.5));
      }
      return TemplateGeometry(slots: slots);
    },
  ),
  PageTemplate(
    id: 'spread_panorama',
    kind: TemplateKind.photo,
    minPhotos: 1,
    maxPhotos: 1,
    isHero: true,
    fullBleed: true,
    panorama: true,
    build: (c) {
      // The frame spans the whole spread; each page shows its half.
      final spreadW = c.w * 2;
      final x = c.side == PageSide.left ? -kBleedMm : -c.w;
      return TemplateGeometry(
        slots: [
          SlotGeometry(
            RectMm(
              x: x,
              y: -kBleedMm,
              w: spreadW + kBleedMm,
              h: c.h + 2 * kBleedMm,
            ),
          ),
        ],
        hidePageNumber: true,
      );
    },
  ),
  // Special pages (no photo sequencing).
  PageTemplate(
    id: 'title_page',
    kind: TemplateKind.special,
    minPhotos: 0,
    maxPhotos: 0,
    build: (c) => TemplateGeometry(
      slots: const [],
      textArea: c.content,
      hidePageNumber: true,
    ),
  ),
  PageTemplate(
    id: 'chapter_opener',
    kind: TemplateKind.special,
    minPhotos: 0,
    maxPhotos: 1,
    build: (c) {
      final box = c.content;
      if (c.slots.isEmpty) {
        return TemplateGeometry(slots: const [], textArea: box);
      }
      final photo = fitAspect(
        RectMm(
          x: box.x + box.w * 0.2,
          y: box.y + box.h * 0.06,
          w: box.w * 0.6,
          h: box.h * 0.44,
        ),
        _aspect(c, 0),
        minA: 0.8,
        maxA: 1.5,
        ay: 0,
      );
      return TemplateGeometry(
        slots: [SlotGeometry(photo)],
        textArea: RectMm(
          x: box.x,
          y: photo.bottom + c.gap * 2,
          w: box.w,
          h: box.bottom - photo.bottom - c.gap * 2,
        ),
      );
    },
  ),
  PageTemplate(
    id: 'map_page',
    kind: TemplateKind.special,
    minPhotos: 0,
    maxPhotos: 0,
    build: (c) => TemplateGeometry(slots: const [], textArea: c.content),
  ),
  PageTemplate(
    id: 'quote_page',
    kind: TemplateKind.special,
    minPhotos: 0,
    maxPhotos: 0,
    build: (c) => TemplateGeometry(
      slots: const [],
      textArea: c.content.deflate(c.content.w * 0.1),
    ),
  ),
  PageTemplate(
    id: 'blank_note',
    kind: TemplateKind.special,
    minPhotos: 0,
    maxPhotos: 0,
    build: (c) => TemplateGeometry(slots: const [], textArea: c.content),
  ),
  PageTemplate(
    id: 'colophon',
    kind: TemplateKind.special,
    minPhotos: 0,
    maxPhotos: 0,
    build: (c) => TemplateGeometry(
      slots: const [],
      textArea: c.content,
      hidePageNumber: true,
    ),
  ),
];

/// Default template for a photo count.
String templateForCount(int n, bool playful) => switch (n) {
  0 || 1 => 'hero_bordered',
  2 => 'two_side_by_side',
  3 => 'three_one_big_two_small',
  4 => playful ? 'polaroid_scatter' : 'four_grid',
  5 => 'five_mosaic',
  _ => 'six_grid',
};
