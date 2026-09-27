import 'package:material_ui/material_ui.dart';

/// Font family names as declared in pubspec.yaml. The render service registers
/// the same files under the same names.
abstract final class Fonts {
  static const String inter = 'Inter';
  static const String cormorant = 'CormorantGaramond';
  static const String lora = 'Lora';
  static const String manrope = 'Manrope';
  static const String nunito = 'Nunito';
  static const String greatVibes = 'GreatVibes';

  static const List<String> all = [
    inter,
    cormorant,
    lora,
    manrope,
    nunito,
    greatVibes,
  ];
}

/// App UI type scale: Inter for UI (12/14/16/20), Cormorant Garamond for
/// display (28/34/44).
TextTheme buildTextTheme(Color primary, Color secondary) {
  TextStyle inter(double size, FontWeight w, {Color? color, double? h}) =>
      TextStyle(
        fontFamily: Fonts.inter,
        fontSize: size,
        fontWeight: w,
        color: color ?? primary,
        height: h ?? 1.4,
        letterSpacing: 0,
      );
  TextStyle display(double size, FontWeight w) => TextStyle(
    fontFamily: Fonts.cormorant,
    fontSize: size,
    fontWeight: w,
    color: primary,
    height: 1.12,
    letterSpacing: -0.2,
  );

  return TextTheme(
    displayLarge: display(44, FontWeight.w600),
    displayMedium: display(34, FontWeight.w500),
    displaySmall: display(28, FontWeight.w500),
    headlineLarge: display(34, FontWeight.w600),
    headlineMedium: display(28, FontWeight.w600),
    headlineSmall: display(28, FontWeight.w500),
    titleLarge: inter(20, FontWeight.w600, h: 1.3),
    titleMedium: inter(16, FontWeight.w600),
    titleSmall: inter(14, FontWeight.w600),
    bodyLarge: inter(16, FontWeight.w400, h: 1.5),
    bodyMedium: inter(14, FontWeight.w400, h: 1.45),
    bodySmall: inter(12, FontWeight.w400, color: secondary),
    labelLarge: inter(16, FontWeight.w600, h: 1.2),
    labelMedium: inter(14, FontWeight.w500, h: 1.2),
    labelSmall: inter(12, FontWeight.w500, color: secondary, h: 1.2),
  );
}
