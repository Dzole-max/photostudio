import 'dart:math' as math;

/// Pure colour maths on `#RRGGBB` strings (no Flutter dependency).
class Rgb {
  const Rgb(this.r, this.g, this.b);

  factory Rgb.hex(String hex) {
    final h = hex.replaceFirst('#', '');
    final v = int.parse(h.substring(0, 6), radix: 16);
    return Rgb((v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF);
  }

  final int r;
  final int g;
  final int b;

  String get hex =>
      '#${[r, g, b].map((c) => c.toRadixString(16).padLeft(2, '0')).join().toUpperCase()}';

  Hsl toHsl() {
    final rf = r / 255, gf = g / 255, bf = b / 255;
    final maxC = math.max(rf, math.max(gf, bf));
    final minC = math.min(rf, math.min(gf, bf));
    final l = (maxC + minC) / 2;
    if (maxC == minC) return Hsl(0, 0, l);
    final d = maxC - minC;
    final s = l > 0.5 ? d / (2 - maxC - minC) : d / (maxC + minC);
    double h;
    if (maxC == rf) {
      h = (gf - bf) / d + (gf < bf ? 6 : 0);
    } else if (maxC == gf) {
      h = (bf - rf) / d + 2;
    } else {
      h = (rf - gf) / d + 4;
    }
    return Hsl(h * 60, s, l);
  }
}

class Hsl {
  const Hsl(this.h, this.s, this.l);

  final double h;
  final double s;
  final double l;

  Rgb toRgb() {
    if (s == 0) {
      final v = (l * 255).round();
      return Rgb(v, v, v);
    }
    final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    final p = 2 * l - q;
    double channel(double t) {
      var tt = t;
      if (tt < 0) tt += 1;
      if (tt > 1) tt -= 1;
      if (tt < 1 / 6) return p + (q - p) * 6 * tt;
      if (tt < 1 / 2) return q;
      if (tt < 2 / 3) return p + (q - p) * (2 / 3 - tt) * 6;
      return p;
    }

    final hn = h / 360;
    int c(double v) => (v * 255).round().clamp(0, 255);
    return Rgb(c(channel(hn + 1 / 3)), c(channel(hn)), c(channel(hn - 1 / 3)));
  }

  Hsl withHue(double hue) => Hsl(normalizeHue(hue), s, l);
}

double normalizeHue(double h) {
  final m = h % 360;
  return m < 0 ? m + 360 : m;
}

/// Signed shortest angle from [from] to [to], in -180..180.
double hueDelta(double from, double to) {
  var d = normalizeHue(to) - normalizeHue(from);
  if (d > 180) d -= 360;
  if (d < -180) d += 360;
  return d;
}

/// Relative luminance (WCAG).
double luminance(Rgb c) {
  double ch(int v) {
    final s = v / 255;
    return s <= 0.03928
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}
