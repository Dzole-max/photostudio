import '../model/album.dart';

/// Destination art pack (fake mode): 20 small line-art icons as SVG path
/// data in a 0..100 box, drawn as vector ornaments so print and preview
/// match. The real CoverArtProvider generates one per place and caches it.
const Map<String, String> kIconPaths = {
  'door': 'M30 95 L30 40 Q50 12 70 40 L70 95 Z M50 30 L50 95 M36 50 L36 52 M64 50 L64 52 M36 64 L36 66 M64 64 L64 66 M36 78 L36 80 M64 78 L64 80 M22 95 L78 95',
  'dhow': 'M12 70 L88 70 L78 84 L22 84 Z M50 70 L50 14 M50 16 Q76 34 84 62 L50 62 M8 90 Q20 86 32 90 Q44 94 56 90 Q68 86 80 90 Q88 93 94 90',
  'palm': 'M50 95 Q46 70 52 40 M52 40 Q34 26 14 34 M52 40 Q40 18 24 14 M52 40 Q58 16 76 12 M52 40 Q72 28 90 36 M52 40 Q68 44 80 58 M52 40 Q36 46 26 60 M30 95 L72 95',
  'spice': 'M18 56 L82 56 L74 90 L26 90 Z M18 56 Q50 24 82 56 M34 42 L36 46 M50 34 L50 38 M64 40 L62 44 M26 70 L74 70',
  'heart': 'M50 86 Q14 58 18 34 Q24 14 42 20 Q48 23 50 30 Q52 23 58 20 Q76 14 82 34 Q86 58 50 86 Z',
  'church': 'M24 92 L24 52 L50 30 L76 52 L76 92 Z M50 30 L50 8 M42 16 L58 16 M42 92 L42 72 Q50 62 58 72 L58 92 M34 60 L34 66 M66 60 L66 66',
  'lighthouse': 'M40 92 L44 34 L56 34 L60 92 Z M40 34 L60 34 L58 24 L42 24 Z M50 24 L50 16 M44 52 L56 52 M42 70 L58 70 M22 22 L34 26 M78 22 L66 26 M30 92 L70 92',
  'mountain': 'M6 88 L36 34 L50 56 L64 30 L94 88 Z M30 44 L36 34 L42 46 M58 40 L64 30 L70 42',
  'sun': 'M50 34 A16 16 0 1 1 50 66 A16 16 0 1 1 50 34 Z M50 8 L50 20 M50 80 L50 92 M8 50 L20 50 M80 50 L92 50 M20 20 L28 28 M72 72 L80 80 M80 20 L72 28 M28 72 L20 80',
  'wave': 'M6 46 Q18 32 30 46 Q42 60 54 46 Q66 32 78 46 Q86 54 94 46 M6 66 Q18 52 30 66 Q42 80 54 66 Q66 52 78 66 Q86 74 94 66',
  'fish':
      'M14 50 Q40 20 70 50 Q40 80 14 50 Z M70 50 L90 32 L88 68 Z M28 46 L28 48',
  'turtle': 'M26 58 Q50 22 74 58 Z M20 58 L80 58 M74 56 Q86 50 90 58 Q86 64 78 62 M32 60 L26 72 M68 60 L74 72 M40 40 L50 52 L60 40',
  'compass': 'M50 14 A36 36 0 1 1 50 86 A36 36 0 1 1 50 14 Z M50 24 L58 50 L50 76 L42 50 Z M50 6 L50 14 M50 86 L50 94',
  'camera': 'M12 34 L32 34 L38 24 L62 24 L68 34 L88 34 L88 80 L12 80 Z M50 42 A14 14 0 1 1 50 70 A14 14 0 1 1 50 42 Z',
  'plane': 'M50 8 Q56 14 56 30 L56 42 L92 60 L92 68 L56 58 L56 76 L66 84 L66 90 L50 86 L34 90 L34 84 L44 76 L44 58 L8 68 L8 60 L44 42 L44 30 Q44 14 50 8 Z',
  'ring': 'M50 38 A24 24 0 1 1 50 86 A24 24 0 1 1 50 38 Z M50 46 A16 16 0 1 1 50 78 A16 16 0 1 1 50 46 Z M42 38 L50 22 L58 38 M50 22 L50 14',
  'cake': 'M20 90 L80 90 L80 62 L20 62 Z M26 62 L26 44 L74 44 L74 62 M20 74 Q35 68 50 74 Q65 80 80 74 M50 44 L50 30 M50 30 Q46 24 50 18 Q54 24 50 30',
  'tree': 'M50 94 L50 62 M50 62 Q20 64 22 44 Q16 24 38 22 Q44 6 62 12 Q82 12 80 32 Q92 50 74 60 Q62 66 50 62 Z M36 92 L64 92',
  'monkey': 'M50 30 A18 18 0 1 1 50 66 A18 18 0 1 1 50 30 Z M30 40 A8 8 0 1 1 30 56 M70 40 A8 8 0 1 0 70 56 M42 46 L42 48 M58 46 L58 48 M44 56 Q50 60 56 56 M60 66 Q80 76 76 94',
  'cup': 'M22 36 L70 36 L66 84 L26 84 Z M70 46 Q88 46 84 60 Q80 70 68 68 M38 26 Q34 18 40 12 M52 26 Q48 18 54 12 M16 90 L76 90',
};

/// Keywords (place names, photo labels, ids) → icon.
const Map<String, String> _keywordIcons = {
  'stone_town': 'door',
  'stone town': 'door',
  'door': 'door',
  'building': 'door',
  'street': 'door',
  'nungwi': 'dhow',
  'boat': 'dhow',
  'harbour': 'dhow',
  'paje': 'sun',
  'jozani': 'monkey',
  'monkey': 'monkey',
  'animal': 'monkey',
  'forest': 'tree',
  'tree': 'tree',
  'beach': 'palm',
  'island': 'palm',
  'sand': 'palm',
  'market': 'spice',
  'food': 'spice',
  'spice': 'spice',
  'sea': 'wave',
  'water': 'wave',
  'lake': 'wave',
  'fish': 'fish',
  'turtle': 'turtle',
  'ohrid': 'church',
  'ceremony': 'church',
  'church': 'church',
  'lighthouse': 'lighthouse',
  'mountain': 'mountain',
  'hvar': 'lighthouse',
  'sky': 'sun',
  'wedding': 'ring',
  'jewelry': 'ring',
  'cake': 'cake',
  'drink': 'cup',
  'coffee': 'cup',
  'plane': 'plane',
  'window': 'plane',
};

/// Picks an icon for a chapter: place first, then its photos' labels.
String iconForPlace(String? placeId, String? placeName, List<PhotoRef> photos) {
  for (final key in [placeId, placeName?.toLowerCase()]) {
    if (key != null && _keywordIcons.containsKey(key)) {
      return _keywordIcons[key]!;
    }
  }
  final scores = <String, double>{};
  for (final p in photos) {
    for (final l in p.labels) {
      final icon = _keywordIcons[l.text.toLowerCase()];
      if (icon != null) scores[icon] = (scores[icon] ?? 0) + l.confidence;
    }
  }
  if (scores.isEmpty) return 'compass';
  return scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

/// Places [icon] at (cx, cy) with [size] mm as an ornament.
Ornament iconOrnament(
  String icon,
  double cx,
  double cy,
  double size,
  String color, {
  double strokePt = 0.6,
}) {
  final path = kIconPaths[icon] ?? kIconPaths['compass']!;
  return Ornament(
    type: OrnamentType.path,
    path: transformPath(path, size / 100, cx - size / 2, cy - size / 2),
    color: color,
    strokePt: strokePt,
  );
}

/// Scales and translates an absolute path (M/L/Q/C/A/Z). Arc radii scale;
/// arc flags stay as they are.
String transformPath(String path, double scale, double dx, double dy) {
  final tokens = RegExp(r'[A-Za-z]|-?\d*\.?\d+')
      .allMatches(path)
      .map((m) => m.group(0)!)
      .toList();
  final out = StringBuffer();
  String cmd = 'M';
  var i = 0;
  String f(double v) => v.toStringAsFixed(2);
  while (i < tokens.length) {
    final t = tokens[i];
    if (RegExp('^[A-Za-z]').hasMatch(t)) {
      cmd = t.toUpperCase();
      out.write('$cmd ');
      i++;
      continue;
    }
    if (cmd == 'A') {
      // rx ry rotation large sweep x y
      final rx = double.parse(tokens[i]), ry = double.parse(tokens[i + 1]);
      out.write(
        '${f(rx * scale)} ${f(ry * scale)} ${tokens[i + 2]} ${tokens[i + 3]} ${tokens[i + 4]} ',
      );
      out.write(
        '${f(double.parse(tokens[i + 5]) * scale + dx)} ${f(double.parse(tokens[i + 6]) * scale + dy)} ',
      );
      i += 7;
    } else {
      out.write(
        '${f(double.parse(tokens[i]) * scale + dx)} ${f(double.parse(tokens[i + 1]) * scale + dy)} ',
      );
      i += 2;
    }
  }
  return out.toString().trim();
}
