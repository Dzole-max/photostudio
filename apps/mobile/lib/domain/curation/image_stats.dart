import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../theme/color_math.dart';
import '../theme/theme_tinter.dart';

/// Pixel statistics computed on device for one photo (section 7.3 step 3).
/// Pure and isolate-safe.
class ImageStats {
  const ImageStats({
    required this.hash,
    required this.laplacian,
    required this.exposure,
    required this.focusX,
    required this.focusY,
    this.dominantHue,
  });

  /// 64-bit DCT perceptual hash as 16 hex characters.
  final String hash;

  /// Variance of the Laplacian on the 512 px grayscale image.
  final double laplacian;

  /// 1 = no clipped highlights/shadows, 0 = heavily clipped.
  final double exposure;

  /// Centre of the sharpest cell of a 3×3 grid (saliency fallback).
  final double focusX;
  final double focusY;
  final double? dominantHue;
}

/// Decodes [encoded] (JPEG/PNG/...) and computes its stats. Returns null
/// for undecodable input.
ImageStats? statsFromEncoded(Uint8List encoded) {
  final decoded = img.decodeImage(encoded);
  if (decoded == null) return null;
  return statsFromImage(decoded);
}

ImageStats statsFromImage(img.Image source) {
  final oriented = img.bakeOrientation(source);
  final longSide = math.max(oriented.width, oriented.height);
  final work = longSide > 512
      ? img.copyResize(
          oriented,
          width: oriented.width >= oriented.height ? 512 : null,
          height: oriented.height > oriented.width ? 512 : null,
          interpolation: img.Interpolation.average,
        )
      : oriented;
  final gray = _grayscale(work);
  final w = work.width, h = work.height;
  final lap = _laplacianStats(gray, w, h);
  return ImageStats(
    hash: perceptualHash(gray, w, h),
    laplacian: lap.variance,
    exposure: exposureScore(gray),
    focusX: lap.focusX,
    focusY: lap.focusY,
    dominantHue: _dominantHue(work),
  );
}

Float64List _grayscale(img.Image im) {
  final out = Float64List(im.width * im.height);
  var i = 0;
  for (final p in im) {
    out[i++] = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
  }
  return out;
}

/// DCT pHash: 32×32 grayscale → 2D DCT → top-left 8×8 → bits above the
/// median (DC term excluded from the median).
String perceptualHash(Float64List gray, int w, int h) {
  const n = 32;
  final small = Float64List(n * n);
  // Box-filter downsample to 32×32.
  for (var y = 0; y < n; y++) {
    final y0 = y * h ~/ n, y1 = math.max(y0 + 1, (y + 1) * h ~/ n);
    for (var x = 0; x < n; x++) {
      final x0 = x * w ~/ n, x1 = math.max(x0 + 1, (x + 1) * w ~/ n);
      var sum = 0.0;
      for (var yy = y0; yy < y1; yy++) {
        for (var xx = x0; xx < x1; xx++) {
          sum += gray[yy * w + xx];
        }
      }
      small[y * n + x] = sum / ((y1 - y0) * (x1 - x0));
    }
  }
  final cos = List.generate(
    8,
    (u) =>
        List.generate(n, (x) => math.cos((2 * x + 1) * u * math.pi / (2 * n))),
  );
  final coef = Float64List(64);
  for (var v = 0; v < 8; v++) {
    for (var u = 0; u < 8; u++) {
      var sum = 0.0;
      for (var y = 0; y < n; y++) {
        final cy = cos[v][y];
        for (var x = 0; x < n; x++) {
          sum += small[y * n + x] * cos[u][x] * cy;
        }
      }
      coef[v * 8 + u] = sum;
    }
  }
  final sorted = coef.sublist(1).toList()..sort();
  final median = (sorted[31] + sorted[32]) / 2;
  var bits = BigInt.zero;
  for (var i = 0; i < 64; i++) {
    if (coef[i] > median) bits |= BigInt.one << (63 - i);
  }
  return bits.toRadixString(16).padLeft(16, '0');
}

/// Hamming distance between two 16-hex-digit hashes.
int hammingDistance(String a, String b) {
  var diff = BigInt.parse(a, radix: 16) ^ BigInt.parse(b, radix: 16);
  var count = 0;
  while (diff > BigInt.zero) {
    if (diff & BigInt.one == BigInt.one) count++;
    diff >>= 1;
  }
  return count;
}

class _LapStats {
  const _LapStats(this.variance, this.focusX, this.focusY);

  final double variance;
  final double focusX;
  final double focusY;
}

_LapStats _laplacianStats(Float64List g, int w, int h) {
  if (w < 3 || h < 3) return const _LapStats(0, 0.5, 0.45);
  var sum = 0.0, sumSq = 0.0;
  var count = 0;
  final cellSum = Float64List(9),
      cellSq = Float64List(9),
      cellN = Float64List(9);
  for (var y = 1; y < h - 1; y++) {
    final int cy = math.min(2, y * 3 ~/ h);
    for (var x = 1; x < w - 1; x++) {
      final i = y * w + x;
      final v = 4 * g[i] - g[i - 1] - g[i + 1] - g[i - w] - g[i + w];
      sum += v;
      sumSq += v * v;
      count++;
      final int c = cy * 3 + math.min(2, x * 3 ~/ w);
      cellSum[c] += v;
      cellSq[c] += v * v;
      cellN[c] += 1;
    }
  }
  final mean = sum / count;
  final variance = sumSq / count - mean * mean;
  var best = 4;
  var bestVar = -1.0;
  for (var c = 0; c < 9; c++) {
    if (cellN[c] == 0) continue;
    final m = cellSum[c] / cellN[c];
    final v = cellSq[c] / cellN[c] - m * m;
    if (v > bestVar) {
      bestVar = v;
      best = c;
    }
  }
  return _LapStats(variance, (best % 3 + 0.5) / 3, (best ~/ 3 + 0.5) / 3);
}

/// Share of pixels clipped to (near) black or white, mapped to a 0..1 score.
double exposureScore(Float64List gray) {
  var clipped = 0;
  for (final v in gray) {
    if (v <= 4 || v >= 251) clipped++;
  }
  final share = clipped / gray.length;
  return (1 - share * 4).clamp(0.0, 1.0);
}

double? _dominantHue(img.Image work) {
  final thumb = img.copyResize(
    work,
    width: 64,
    height: 64,
    interpolation: img.Interpolation.average,
  );
  final pixels = [
    for (final p in thumb) Rgb(p.r.toInt(), p.g.toInt(), p.b.toInt()),
  ];
  return ThemeTinter.dominantHue(pixels);
}

/// Stats from raw RGBA pixels (decoded natively on the UI side, analysed in
/// an isolate).
ImageStats statsFromRgba(int width, int height, Uint8List rgba) =>
    statsFromImage(
      img.Image.fromBytes(
        width: width,
        height: height,
        bytes: rgba.buffer,
        numChannels: 4,
      ),
    );
