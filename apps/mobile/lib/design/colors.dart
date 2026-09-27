import 'package:material_ui/material_ui.dart';

/// Brand colour tokens ("The quiet bookbinder"). Clay is the only loud colour:
/// use [primary] for one primary action per screen.
@immutable
class MemoriaColors extends ThemeExtension<MemoriaColors> {
  const MemoriaColors({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.textPrimary,
    required this.textSecondary,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.accent,
    required this.info,
    required this.warning,
    required this.error,
    required this.divider,
    required this.shadow,
  });

  static const light = MemoriaColors(
    background: Color(0xFFF7F3EC), // Paper
    surface: Color(0xFFEDE6DA), // Linen
    surfaceRaised: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1F1B17), // Ink
    textSecondary: Color(0xFF6B635A), // Stone
    primary: Color(0xFFB04E2B), // Clay
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF5E7160), // Sage
    accent: Color(0xFF8C6A2E), // Gold tone
    info: Color(0xFF2E3A52), // Dusk
    warning: Color(0xFFC98A1B), // Amber, icons only
    error: Color(0xFFA3322A), // Brick
    divider: Color(0xFFDDD4C6),
    shadow: Color(0xFF1F1B17),
  );

  static const dark = MemoriaColors(
    background: Color(0xFF15130F),
    surface: Color(0xFF221F1A),
    surfaceRaised: Color(0xFF2C2822),
    textPrimary: Color(0xFFF2ECE2),
    textSecondary: Color(0xFFA89E91),
    primary: Color(0xFFE0845F),
    onPrimary: Color(0xFF15130F),
    secondary: Color(0xFF9BB09C),
    accent: Color(0xFFD4B06A),
    info: Color(0xFF9FB2D6),
    warning: Color(0xFFE3A63A),
    error: Color(0xFFE57368),
    divider: Color(0xFF3A352D),
    shadow: Color(0xFF000000),
  );

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color textPrimary;
  final Color textSecondary;
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color accent;
  final Color info;
  final Color warning;
  final Color error;
  final Color divider;
  final Color shadow;

  static MemoriaColors of(BuildContext context) =>
      Theme.of(context).extension<MemoriaColors>() ?? light;

  @override
  MemoriaColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? textPrimary,
    Color? textSecondary,
    Color? primary,
    Color? onPrimary,
    Color? secondary,
    Color? accent,
    Color? info,
    Color? warning,
    Color? error,
    Color? divider,
    Color? shadow,
  }) {
    return MemoriaColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      secondary: secondary ?? this.secondary,
      accent: accent ?? this.accent,
      info: info ?? this.info,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      divider: divider ?? this.divider,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  MemoriaColors lerp(ThemeExtension<MemoriaColors>? other, double t) {
    if (other is! MemoriaColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return MemoriaColors(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceRaised: l(surfaceRaised, other.surfaceRaised),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      secondary: l(secondary, other.secondary),
      accent: l(accent, other.accent),
      info: l(info, other.info),
      warning: l(warning, other.warning),
      error: l(error, other.error),
      divider: l(divider, other.divider),
      shadow: l(shadow, other.shadow),
    );
  }

  ColorScheme toColorScheme(Brightness brightness) {
    return ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: brightness == Brightness.light ? onPrimary : background,
      tertiary: accent,
      onTertiary: brightness == Brightness.light ? onPrimary : background,
      error: error,
      onError: brightness == Brightness.light ? onPrimary : background,
      surface: background,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      surfaceContainerLowest: surfaceRaised,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: surface,
      surfaceContainerHighest: surface,
      outline: divider,
      outlineVariant: divider,
      shadow: shadow,
      inverseSurface: textPrimary,
      onInverseSurface: background,
      inversePrimary: primary,
      primaryContainer: surface,
      onPrimaryContainer: textPrimary,
      secondaryContainer: surface,
      onSecondaryContainer: textPrimary,
      surfaceTint: Colors.transparent,
    );
  }
}
