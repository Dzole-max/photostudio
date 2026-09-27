import 'dart:math' as math;

import 'color_math.dart';

/// Adaptive accent (section 5.1): rotates a theme's accent hue by up to ±15°
/// towards the dominant hue of the cover photo. Text colour never changes.
class ThemeTinter {
  const ThemeTinter({this.maxRotation = 15});

  final double maxRotation;

  /// [pixels] are RGB triples from a 64×64 thumbnail. Returns the dominant
  /// hue in degrees, or null if the image is essentially grey/white/black.
  static double? dominantHue(List<Rgb> pixels, {int k = 5, int seed = 7}) {
    // Skip near-white, near-black and near-grey pixels.
    final colourful = <Hsl>[];
    for (final p in pixels) {
      final hsl = p.toHsl();
      if (hsl.l > 0.92 || hsl.l < 0.08 || hsl.s < 0.12) continue;
      colourful.add(hsl);
    }
    if (colourful.length < pixels.length * 0.05 || colourful.isEmpty) {
      return null;
    }
    // k-means on hue (circular) weighted by saturation.
    final rng = math.Random(seed);
    final centroids = List<double>.generate(
      k,
      (_) => colourful[rng.nextInt(colourful.length)].h,
    );
    final assignment = List<int>.filled(colourful.length, 0);
    for (var iter = 0; iter < 12; iter++) {
      for (var i = 0; i < colourful.length; i++) {
        var best = 0;
        var bestD = double.infinity;
        for (var c = 0; c < k; c++) {
          final d = hueDelta(colourful[i].h, centroids[c]).abs();
          if (d < bestD) {
            bestD = d;
            best = c;
          }
        }
        assignment[i] = best;
      }
      for (var c = 0; c < k; c++) {
        var sx = 0.0, sy = 0.0;
        for (var i = 0; i < colourful.length; i++) {
          if (assignment[i] != c) continue;
          final rad = colourful[i].h * math.pi / 180;
          sx += math.cos(rad) * colourful[i].s;
          sy += math.sin(rad) * colourful[i].s;
        }
        if (sx != 0 || sy != 0) {
          centroids[c] = normalizeHue(math.atan2(sy, sx) * 180 / math.pi);
        }
      }
    }
    final weight = List<double>.filled(k, 0);
    for (var i = 0; i < colourful.length; i++) {
      weight[assignment[i]] += colourful[i].s;
    }
    var bestCluster = 0;
    for (var c = 1; c < k; c++) {
      if (weight[c] > weight[bestCluster]) bestCluster = c;
    }
    return centroids[bestCluster];
  }

  /// Rotates [accentHex] towards [targetHue] by at most [maxRotation]°.
  String tint(String accentHex, double? targetHue) {
    if (targetHue == null) return accentHex;
    final rgb = Rgb.hex(accentHex);
    final hsl = rgb.toHsl();
    if (hsl.s < 0.05) return accentHex; // neutral accents stay neutral
    final delta = hueDelta(hsl.h, targetHue).clamp(-maxRotation, maxRotation);
    return hsl.withHue(hsl.h + delta).toRgb().hex;
  }
}
