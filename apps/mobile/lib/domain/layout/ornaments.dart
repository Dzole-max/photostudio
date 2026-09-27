import 'dart:math' as math;

import '../model/album.dart';
import '../model/geometry.dart';
import '../theme/book_theme.dart';

/// Vector ornaments shared by pages and covers. Everything is expressed with
/// the primitive ornament types so both renderers draw them identically.
abstract final class Ornaments {
  static const double hairlinePt = 0.4;

  static List<Ornament> keylines(
    double cx,
    double y1,
    double y2,
    double width,
    String color,
  ) => [
    Ornament(
      type: OrnamentType.line,
      params: {'x1': cx - width / 2, 'y1': y1, 'x2': cx + width / 2, 'y2': y1},
      color: color,
      strokePt: hairlinePt,
    ),
    Ornament(
      type: OrnamentType.line,
      params: {'x1': cx - width / 2, 'y1': y2, 'x2': cx + width / 2, 'y2': y2},
      color: color,
      strokePt: hairlinePt,
    ),
  ];

  static Ornament divider(
    double cx,
    double y,
    double width,
    String color, {
    double opacity = 1,
  }) => Ornament(
    type: OrnamentType.line,
    params: {'x1': cx - width / 2, 'y1': y, 'x2': cx + width / 2, 'y2': y},
    color: color,
    opacity: opacity,
    strokePt: hairlinePt,
  );

  /// A small sprig: a curved stem with four leaves, centred at (cx, cy).
  static List<Ornament> leafSprig(
    double cx,
    double cy,
    double size,
    String color,
  ) {
    final s = size / 20;
    String p(double x, double y) =>
        '${(cx + x * s).toStringAsFixed(2)} ${(cy + y * s).toStringAsFixed(2)}';
    final stem = 'M${p(-10, 0)} Q${p(0, -2)} ${p(10, 0)}';
    String leaf(double x, double dir) =>
        'M${p(x, -0.6 * dir.sign)} Q${p(x + 2.2, -4.2 * dir)} ${p(x + 4.6, -1.2 * dir)} '
        'Q${p(x + 2.4, -0.8 * dir)} ${p(x, -0.6 * dir.sign)} Z';
    return [
      Ornament(
        type: OrnamentType.path,
        path: stem,
        color: color,
        strokePt: 0.5,
      ),
      for (final (x, d) in [(-7.0, 1.0), (-3.0, -1.0), (1.0, 1.0), (5.0, -1.0)])
        Ornament(
          type: OrnamentType.path,
          path: leaf(x, d),
          color: color,
          fill: true,
          opacity: 0.85,
        ),
    ];
  }

  static Ornament frame(RectMm r, String color, {double strokePt = 0.5}) =>
      Ornament(
        type: OrnamentType.rect,
        params: {'x': r.x, 'y': r.y, 'w': r.w, 'h': r.h},
        color: color,
        strokePt: strokePt,
      );

  static List<Ornament> compass(double cx, double cy, double r, String color) =>
      [
        Ornament(
          type: OrnamentType.circle,
          params: {'cx': cx, 'cy': cy, 'r': r},
          color: color,
          strokePt: 0.4,
        ),
        Ornament(
          type: OrnamentType.line,
          params: {'x1': cx, 'y1': cy - r * 1.6, 'x2': cx, 'y2': cy - r * 0.4},
          color: color,
          strokePt: 0.6,
        ),
        Ornament(
          type: OrnamentType.line,
          params: {'x1': cx, 'y1': cy + r * 0.4, 'x2': cx, 'y2': cy + r * 1.3},
          color: color,
          strokePt: 0.3,
        ),
      ];

  static Ornament stamp(
    double cx,
    double cy,
    double r,
    String color, {
    double opacity = 0.9,
  }) => Ornament(
    type: OrnamentType.stamp,
    params: {'cx': cx, 'cy': cy, 'r': r, 'gap': r * 0.12},
    color: color,
    opacity: opacity,
    strokePt: 0.7,
  );

  /// Topographic contour lines in a corner of the page.
  static List<Ornament> contours(
    double w,
    double h,
    String color, {
    bool topRight = true,
  }) {
    final out = <Ornament>[];
    final ox = topRight ? w : 0.0;
    for (var i = 1; i <= 5; i++) {
      final r = 14.0 * i;
      final pts = <String>[];
      for (var a = 0; a <= 18; a++) {
        final t = (topRight ? math.pi / 2 : 0) + a / 18 * math.pi / 2;
        final wobble = 1 + 0.06 * math.sin(a * 1.7 + i);
        final x = ox + math.cos(t) * r * wobble * (topRight ? 1 : 1);
        final y = math.sin(t) * r * wobble;
        pts.add(
          '${a == 0 ? 'M' : 'L'}${x.toStringAsFixed(2)} ${y.toStringAsFixed(2)}',
        );
      }
      out.add(
        Ornament(
          type: OrnamentType.path,
          path: pts.join(' '),
          color: color,
          opacity: 0.35,
          strokePt: 0.35,
        ),
      );
    }
    return out;
  }

  static List<Ornament> confetti(
    RectMm area,
    int seed,
    List<String> colors, {
    int count = 22,
  }) {
    final rng = math.Random(seed);
    return [
      for (var i = 0; i < count; i++)
        Ornament(
          type: OrnamentType.circle,
          params: {
            'cx': area.x + rng.nextDouble() * area.w,
            'cy': area.y + rng.nextDouble() * area.h,
            'r': 0.6 + rng.nextDouble() * 1.4,
          },
          color: colors[i % colors.length],
          fill: true,
          opacity: 0.8,
        ),
    ];
  }

  /// Photo corners (heirloom albums) for a frame rect.
  static List<Ornament> deckleCorners(RectMm r, String color) {
    const s = 5.0;
    String tri(double x, double y, double dx, double dy) =>
        'M${x.toStringAsFixed(2)} ${y.toStringAsFixed(2)} '
        'L${(x + dx).toStringAsFixed(2)} ${y.toStringAsFixed(2)} '
        'L${x.toStringAsFixed(2)} ${(y + dy).toStringAsFixed(2)} Z';
    return [
      for (final (x, y, dx, dy) in [
        (r.x - 1, r.y - 1, s, s),
        (r.right + 1, r.y - 1, -s, s),
        (r.x - 1, r.bottom + 1, s, -s),
        (r.right + 1, r.bottom + 1, -s, -s),
      ])
        Ornament(
          type: OrnamentType.path,
          path: tri(x, y, dx, dy),
          color: color,
          fill: true,
          opacity: 0.85,
        ),
    ];
  }

  /// Decoration for title and chapter pages, per theme.
  static List<Ornament> forHeading(
    BookTheme theme,
    String accent,
    double w,
    double h,
    double cx,
    double y, {
    int seed = 0,
  }) {
    return switch (theme.ornament) {
      OrnamentStyle.goldKeylines => [divider(cx, y, 24, accent)],
      OrnamentStyle.leafSprig => leafSprig(cx, y, 22, accent),
      OrnamentStyle.goldFrame => [
        frame(RectMm(x: 8, y: 8, w: w - 16, h: h - 16), accent),
        frame(
          RectMm(x: 10, y: 10, w: w - 20, h: h - 20),
          accent,
          strokePt: 0.3,
        ),
      ],
      OrnamentStyle.compassTick => compass(cx, y, 2.2, accent),
      OrnamentStyle.passportStamp => [divider(cx, y, 16, accent)],
      OrnamentStyle.contourLines => contours(w, h, accent),
      OrnamentStyle.softRoundFrames => [
        Ornament(
          type: OrnamentType.circle,
          params: {'cx': cx, 'cy': y, 'r': 1.6},
          color: accent,
          fill: true,
        ),
      ],
      OrnamentStyle.confettiDots => confetti(
        RectMm(x: 12, y: 12, w: w - 24, h: h * 0.3),
        seed,
        [accent, '#F2B84B', '#6FA8A0', '#E8A0B4'],
      ),
      OrnamentStyle.deckleCorners => [divider(cx, y, 30, accent, opacity: 0.8)],
      OrnamentStyle.none => const [],
    };
  }
}
