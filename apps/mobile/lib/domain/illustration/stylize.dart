import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../model/album.dart';

/// Offline illustration filters used by the fake StyleProvider (section 9.2):
/// believable enough to demo the Illustrated Edition end to end. The real
/// provider runs an image model on the server; both return an image of the
/// same size as the input.

/// A small palette shared by every page of one edition. Passing the palette
/// taken from a character sheet keeps skin, hair and clothes the same colours
/// throughout the book ("consistent characters" in fake mode).
class StylePalette {
  const StylePalette(this.colors);

  /// RGB triples packed as 0xRRGGBB.
  final List<int> colors;

  static StylePalette fromImage(img.Image source, {int k = 10, int seed = 3}) {
    final small = img.copyResize(
      source,
      width: 64,
      height: 64,
      interpolation: img.Interpolation.average,
    );
    final pixels = [
      for (final p in small) (p.r.toInt(), p.g.toInt(), p.b.toInt()),
    ];
    final rng = math.Random(seed);
    final centroids = [
      for (var i = 0; i < k; i++) pixels[rng.nextInt(pixels.length)],
    ];
    final assign = List<int>.filled(pixels.length, 0);
    for (var iter = 0; iter < 10; iter++) {
      for (var i = 0; i < pixels.length; i++) {
        var best = 0, bestD = 1 << 30;
        for (var c = 0; c < k; c++) {
          final d = _dist(pixels[i], centroids[c]);
          if (d < bestD) {
            bestD = d;
            best = c;
          }
        }
        assign[i] = best;
      }
      for (var c = 0; c < k; c++) {
        var r = 0, g = 0, b = 0, n = 0;
        for (var i = 0; i < pixels.length; i++) {
          if (assign[i] != c) continue;
          r += pixels[i].$1;
          g += pixels[i].$2;
          b += pixels[i].$3;
          n++;
        }
        if (n > 0) centroids[c] = (r ~/ n, g ~/ n, b ~/ n);
      }
    }
    return StylePalette([
      for (final c in centroids) (c.$1 << 16) | (c.$2 << 8) | c.$3,
    ]);
  }

  static int _dist((int, int, int) a, (int, int, int) b) {
    final dr = a.$1 - b.$1, dg = a.$2 - b.$2, db = a.$3 - b.$3;
    return dr * dr * 2 + dg * dg * 4 + db * db * 3;
  }

  (int, int, int) nearest(int r, int g, int b) {
    var best = colors.first, bestD = 1 << 30;
    for (final c in colors) {
      final d = _dist((r, g, b), ((c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF));
      if (d < bestD) {
        bestD = d;
        best = c;
      }
    }
    return ((best >> 16) & 0xFF, (best >> 8) & 0xFF, best & 0xFF);
  }
}

/// Applies [style] to [source]. [face] (normalised) guides the caricature
/// warp. Runs in an isolate; pure.
img.Image stylizeImage(
  img.Image source,
  IllustrationStyle style, {
  StylePalette? palette,
  FaceBox? face,
}) {
  final pal = palette ?? StylePalette.fromImage(source);
  return switch (style) {
    IllustrationStyle.watercolor => _watercolor(source, pal),
    IllustrationStyle.inkSketch => _ink(source),
    IllustrationStyle.comic => _comic(source, pal),
    IllustrationStyle.caricature => _caricature(source, pal, face),
    IllustrationStyle.animated3d => _animated(source),
  };
}

/// Encodes a stylized JPEG from encoded input bytes, resized so the long
/// side is [longSide] px (upscaled when needed so print stays ≥ 200 dpi).
Uint8List stylizeEncoded(
  Uint8List input,
  IllustrationStyle style, {
  int workSide = 1400,
  int longSide = 2400,
  List<int>? paletteColors,
  FaceBox? face,
}) {
  final decoded = img.bakeOrientation(img.decodeImage(input)!);
  final work = _fit(decoded, workSide);
  // The character palette keeps people consistent; the photo's own colours
  // keep its scene (sky, sea, walls) from being pulled toward skin tones.
  final palette = paletteColors == null
      ? null
      : StylePalette([
          ...paletteColors,
          ...StylePalette.fromImage(work, k: 8).colors,
        ]);
  final out = stylizeImage(work, style, palette: palette, face: face);
  final sized = _fit(out, longSide, interpolation: img.Interpolation.cubic);
  return img.encodeJpg(sized, quality: 90);
}

img.Image _fit(
  img.Image src,
  int longSide, {
  img.Interpolation interpolation = img.Interpolation.average,
}) {
  final landscape = src.width >= src.height;
  if ((landscape ? src.width : src.height) == longSide) return src;
  return img.copyResize(
    src,
    width: landscape ? longSide : null,
    height: landscape ? null : longSide,
    interpolation: interpolation,
  );
}

double _lum(num r, num g, num b) => (0.299 * r + 0.587 * g + 0.114 * b) / 255;

/// Edge strength 0..1 per pixel (Sobel on luminance).
Float32List _edges(img.Image src) {
  final w = src.width, h = src.height;
  final l = Float32List(w * h);
  var i = 0;
  for (final p in src) {
    l[i++] = _lum(p.r, p.g, p.b);
  }
  final e = Float32List(w * h);
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final k = y * w + x;
      final gx =
          l[k - w + 1] +
          2 * l[k + 1] +
          l[k + w + 1] -
          l[k - w - 1] -
          2 * l[k - 1] -
          l[k + w - 1];
      final gy =
          l[k + w - 1] +
          2 * l[k + w] +
          l[k + w + 1] -
          l[k - w - 1] -
          2 * l[k - w] -
          l[k - w + 1];
      e[k] = math.min(1, math.sqrt(gx * gx + gy * gy));
    }
  }
  return e;
}

int _c(num v) => v.clamp(0, 255).toInt();

/// Soft paper grain, deterministic.
double _grain(int x, int y) {
  final n = math.sin(x * 12.9898 + y * 78.233) * 43758.5453;
  return (n - n.floorToDouble()) - 0.5;
}

img.Image _watercolor(img.Image src, StylePalette pal) {
  final blurred = img.gaussianBlur(
    src.clone(),
    radius: math.max(2, src.width ~/ 300),
  );
  final edges = _edges(blurred);
  final out = img.Image(width: src.width, height: src.height);
  final w = src.width;
  for (final p in blurred) {
    final (qr, qg, qb) = pal.nearest(p.r.toInt(), p.g.toInt(), p.b.toInt());
    // Wash: palette colour blended with the soft original, lightened.
    var r = qr * 0.55 + p.r * 0.45;
    var g = qg * 0.55 + p.g * 0.45;
    var b = qb * 0.55 + p.b * 0.45;
    r = r + (255 - r) * 0.18;
    g = g + (255 - g) * 0.18;
    b = b + (255 - b) * 0.16;
    // Pigment pools darker along edges.
    final e = edges[p.y * w + p.x];
    final pool = 1 - math.min(0.45, e * 0.9);
    final grain = 1 + _grain(p.x, p.y) * 0.06;
    out.setPixelRgb(
      p.x,
      p.y,
      _c(r * pool * grain),
      _c(g * pool * grain),
      _c(b * pool * grain * 0.99),
    );
  }
  return out;
}

img.Image _ink(img.Image src) {
  final soft = img.gaussianBlur(src.clone(), radius: 1);
  final edges = _edges(soft);
  final out = img.Image(width: src.width, height: src.height);
  final w = src.width;
  final step = math.max(5, src.width ~/ 180);
  for (final p in soft) {
    final l = _lum(p.r, p.g, p.b);
    var ink = edges[p.y * w + p.x] > 0.28 ? 1.0 : 0.0;
    // Cross-hatching by tone.
    if (l < 0.62 && (p.x + p.y) % step == 0) ink = math.max(ink, 0.7);
    if (l < 0.42 && (p.x - p.y).abs() % step == 0) ink = math.max(ink, 0.8);
    if (l < 0.22 && (p.x + 2 * p.y) % (step ~/ 2 + 1) == 0) ink = 1;
    final paper = 246 + _grain(p.x, p.y) * 8;
    final v = paper * (1 - ink) + 34 * ink;
    out.setPixelRgb(p.x, p.y, _c(v), _c(v - 3), _c(v - 10));
  }
  return out;
}

img.Image _comic(img.Image src, StylePalette pal) {
  final smooth = img.gaussianBlur(
    src.clone(),
    radius: math.max(1, src.width ~/ 500),
  );
  final edges = _edges(smooth);
  final out = img.Image(width: src.width, height: src.height);
  final w = src.width;
  final cell = math.max(6, src.width ~/ 140);
  for (final p in smooth) {
    var (r, g, b) = pal.nearest(p.r.toInt(), p.g.toInt(), p.b.toInt());
    // Punchier inks.
    final m = (r + g + b) / 3;
    r = _c(m + (r - m) * 1.45);
    g = _c(m + (g - m) * 1.45);
    b = _c(m + (b - m) * 1.45);
    final l = _lum(p.r, p.g, p.b);
    // Halftone dots in the shadows.
    if (l < 0.5) {
      final cx = (p.x ~/ cell) * cell + cell / 2,
          cy = (p.y ~/ cell) * cell + cell / 2;
      final radius = cell * 0.5 * (0.5 - l) * 2;
      if ((p.x - cx) * (p.x - cx) + (p.y - cy) * (p.y - cy) < radius * radius) {
        r = _c(r * 0.45);
        g = _c(g * 0.45);
        b = _c(b * 0.45);
      }
    }
    final e = edges[p.y * w + p.x];
    if (e > 0.22) {
      r = 18;
      g = 16;
      b = 20;
    }
    out.setPixelRgb(p.x, p.y, r, g, b);
  }
  return out;
}

img.Image _caricature(img.Image src, StylePalette pal, FaceBox? face) {
  final w = src.width, h = src.height;
  final cx = face == null ? 0.5 * w : (face.x + face.w / 2) * w;
  final cy = face == null ? 0.4 * h : (face.y + face.h / 2) * h;
  final radius = face == null
      ? 0.3 * math.min(w, h)
      : math.max(face.w * w, face.h * h) * 1.4;
  // Gentle bulge: heads a little larger, never grotesque.
  final warped = img.Image(width: w, height: h);
  for (final p in warped) {
    final dx = p.x - cx, dy = p.y - cy;
    final d = math.sqrt(dx * dx + dy * dy);
    var sx = p.x.toDouble(), sy = p.y.toDouble();
    if (d < radius && d > 0) {
      final t = d / radius;
      final f = math.pow(t, 0.72) / t; // < 1: sample closer to the centre
      final k = 1 - (1 - f) * 0.9;
      sx = cx + dx * k;
      sy = cy + dy * k;
    }
    final s = src.getPixelInterpolate(sx, sy);
    p
      ..r = s.r
      ..g = s.g
      ..b = s.b;
  }
  final out = _comic(warped, pal);
  // Lighter lines than the comic style.
  return img.adjustColor(out, brightness: 1.06, saturation: 1.1);
}

img.Image _animated(img.Image src) {
  var smooth = img.gaussianBlur(
    src.clone(),
    radius: math.max(2, src.width ~/ 220),
  );
  smooth = img.gaussianBlur(smooth, radius: math.max(1, src.width ~/ 400));
  final out = img.Image(width: src.width, height: src.height);
  final w = src.width, h = src.height;
  for (final p in smooth) {
    // Soft posterise, rich saturation, a warm key light from the top left.
    double q(num v) => (v / 255 * 9).round() / 9 * 255;
    var r = q(p.r), g = q(p.g), b = q(p.b);
    final m = (r + g + b) / 3;
    r = m + (r - m) * 1.35;
    g = m + (g - m) * 1.35;
    b = m + (b - m) * 1.35;
    final light = 1.08 - (p.x / w + p.y / h) * 0.12;
    final rim = math.max(0, 1 - (p.y / h)) * 10;
    out.setPixelRgb(
      p.x,
      p.y,
      _c(r * light + rim),
      _c(g * light + rim * 0.8),
      _c(b * light),
    );
  }
  return out;
}
