import 'package:material_ui/material_ui.dart';

/// Font family names as declared in pubspec.yaml. The render service registers
/// the book fonts under the same names.
abstract final class Fonts {
  /// App interface: wordmark and large headlines.
  static const String unbounded = 'Unbounded';

  /// App interface: everything else.
  static const String onest = 'Onest';

  // Printed-book fonts (never used for app UI text).
  static const String inter = 'Inter';
  static const String cormorant = 'CormorantGaramond';
  static const String lora = 'Lora';
  static const String manrope = 'Manrope';
  static const String nunito = 'Nunito';
  static const String greatVibes = 'GreatVibes';

  /// Fonts a printed book can use.
  static const List<String> all = [
    inter,
    cormorant,
    lora,
    manrope,
    nunito,
    greatVibes,
  ];
}

/// App UI type scale: Unbounded 600 for large headlines (28–32, −2 %
/// tracking), Onest 400–700 for everything else (11–18, dialogs 20).
TextTheme buildTextTheme(Color primary, Color body, Color muted) {
  TextStyle onest(double size, FontWeight w, {Color? color, double? h}) =>
      TextStyle(
        fontFamily: Fonts.onest,
        fontSize: size,
        fontWeight: w,
        color: color ?? primary,
        height: h ?? 1.4,
        letterSpacing: 0,
      );
  TextStyle display(double size) => TextStyle(
    fontFamily: Fonts.unbounded,
    fontSize: size,
    fontWeight: FontWeight.w600,
    color: primary,
    height: 1.15,
    letterSpacing: -0.02 * size,
  );

  return TextTheme(
    displayLarge: display(32),
    displayMedium: display(30),
    displaySmall: display(28),
    headlineLarge: onest(24, FontWeight.w700, h: 1.25),
    headlineMedium: onest(22, FontWeight.w700, h: 1.25),
    headlineSmall: onest(20, FontWeight.w700, h: 1.3),
    titleLarge: onest(18, FontWeight.w700, h: 1.3),
    titleMedium: onest(16, FontWeight.w600),
    titleSmall: onest(14, FontWeight.w600),
    bodyLarge: onest(16, FontWeight.w400, color: body, h: 1.5),
    bodyMedium: onest(14, FontWeight.w400, color: body, h: 1.45),
    bodySmall: onest(12, FontWeight.w400, color: muted),
    labelLarge: onest(16, FontWeight.w600, h: 1.2),
    labelMedium: onest(14, FontWeight.w500, h: 1.2),
    labelSmall: onest(11, FontWeight.w600, color: muted, h: 1.2),
  );
}
