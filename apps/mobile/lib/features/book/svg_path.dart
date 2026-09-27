import 'dart:ui';

/// Parses the absolute SVG path subset used in album documents
/// (M, L, Q, C, A, Z; coordinates in mm) into a Flutter [Path] scaled by
/// [scale] px/mm. Mirrored in services/render/src/draw/path.ts.
Path parseSvgPath(String data, double scale) {
  final path = Path();
  final tokens = RegExp(r'[MLQCAZmlqcaz]|-?\d*\.?\d+(?:[eE][-+]?\d+)?')
      .allMatches(data)
      .map((m) => m.group(0)!)
      .toList();
  var i = 0;
  String? cmd;
  double n() => double.parse(tokens[i++]) * scale;
  while (i < tokens.length) {
    final t = tokens[i];
    if (RegExp('^[A-Za-z]').hasMatch(t)) {
      cmd = t.toUpperCase();
      i++;
      if (cmd == 'Z') {
        path.close();
        continue;
      }
    }
    switch (cmd) {
      case 'M':
        path.moveTo(n(), n());
        cmd = 'L'; // implicit lineto after the first pair
      case 'L':
        path.lineTo(n(), n());
      case 'Q':
        path.quadraticBezierTo(n(), n(), n(), n());
      case 'C':
        path.cubicTo(n(), n(), n(), n(), n(), n());
      case 'A':
        final rx = n(), ry = n();
        final rotation = double.parse(tokens[i++]);
        final large = double.parse(tokens[i++]) != 0;
        final sweep = double.parse(tokens[i++]) != 0;
        path.arcToPoint(
          Offset(n(), n()),
          radius: Radius.elliptical(rx, ry),
          rotation: rotation,
          largeArc: large,
          clockwise: sweep,
        );
      default:
        i++;
    }
  }
  return path;
}

/// Dashes [source] with on/off lengths in px.
Path dashPath(Path source, List<double> pattern) {
  final out = Path();
  for (final metric in source.computeMetrics()) {
    var d = 0.0;
    var k = 0;
    var draw = true;
    while (d < metric.length) {
      final len = pattern[k % pattern.length];
      if (draw) out.addPath(metric.extractPath(d, d + len), Offset.zero);
      d += len;
      draw = !draw;
      k++;
    }
  }
  return out;
}
