import 'spec_data.dart';

/// Text printed in the book, from packages/layout_spec/i18n/book_strings.json.
/// Both renderers use the same strings and the same formatting rules
/// (mirrored in services/render/src/spec/bookStrings.ts).
class BookStrings {
  BookStrings(String language)
    : lang = kBookStrings.containsKey(language) ? language : 'en',
      _m = kBookStrings[kBookStrings.containsKey(language) ? language : 'en']!;

  final String lang;
  final Map<String, Object> _m;

  static const supported = ['en', 'de', 'es', 'fr', 'it', 'mk'];

  String _s(String key) => _m[key]! as String;

  List<String> _l(String key) => (_m[key]! as List<Object>).cast<String>();

  String get ourWedding => _s('ourWedding');
  String get gettingReady => _s('gettingReady');
  String get ceremony => _s('ceremony');
  String get portraits => _s('portraits');
  String get party => _s('party');
  String get theRoute => _s('theRoute');
  String get notes => _s('notes');

  /// Letter for north on map pages ("N", Macedonian "С").
  String get north => _l('hemispheres')[0];

  String colophon(int year) => _s('colophon').replaceAll('{year}', '$year');

  String day(int n) => _s('day').replaceAll('{n}', '$n');

  String chapter(int n) => _s('chapter').replaceAll('{n}', '$n');

  String ourYear(int year) => _s('ourYear').replaceAll('{year}', '$year');

  String birthday(String name, int age) =>
      _s('birthday').replaceAll('{name}', name).replaceAll('{age}', '$age');

  String firstYear(String name) => _s('firstYear').replaceAll('{name}', name);

  /// "Stone Town, day two" / "Стоун Таун, втор ден". Falls back to digits
  /// beyond ten.
  String placeDay(String place, int n) {
    final words = _l('numberWords');
    final word = n >= 1 && n <= words.length ? words[n - 1] : '$n';
    return _s('placeDay').replaceAll('{place}', place).replaceAll('{n}', word);
  }

  String month(int month) => _l('months')[month - 1];

  /// "15 August 2026", "15. August 2026", "15 de agosto de 2026"...
  String dateLong(DateTime d) =>
      _s('dateLong')
          .replaceAll('{d}', '${d.day}')
          .replaceAll('{month}', month(d.month))
          .replaceAll('{y}', '${d.year}');

  String monthYear(DateTime d) =>
      _s('monthYear')
          .replaceAll('{month}', month(d.month))
          .replaceAll('{y}', '${d.year}');

  /// Capitalised month + year for titles ("July 2026", "Јули 2026").
  String monthYearTitle(DateTime d) {
    final s = monthYear(d);
    return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  }

  /// Decimal-degree coordinates: "6.1659° S, 39.2026° E".
  String coordinates(double lat, double lng) {
    final h = _l('hemispheres');
    final ns = lat >= 0 ? h[0] : h[1];
    final ew = lng >= 0 ? h[2] : h[3];
    return '${lat.abs().toStringAsFixed(4)}° $ns, '
        '${lng.abs().toStringAsFixed(4)}° $ew';
  }
}
