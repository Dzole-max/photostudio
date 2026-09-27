import 'package:material_ui/material_ui.dart';

/// App interface colour tokens: "Sky" (light, default) and "Ocean" (dark).
/// Printed book themes are separate (lib/domain/theme) and never use these.
@immutable
class MemoriaColors extends ThemeExtension<MemoriaColors> {
  const MemoriaColors({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceTint,
    required this.border,
    required this.borderActive,
    required this.heroFrom,
    required this.heroTo,
    required this.textPrimary,
    required this.textBody,
    required this.textSecondary,
    required this.textOnDark,
    required this.textOnDarkBody,
    required this.primary,
    required this.onPrimary,
    required this.primaryOnDark,
    required this.onPrimaryOnDark,
    required this.secondary,
    required this.accent,
    required this.info,
    required this.warning,
    required this.error,
    required this.divider,
    required this.shadow,
    required this.navBar,
  });

  /// Sky — the default.
  static const light = MemoriaColors(
    background: Color(0xFFEEF4FC),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceTint: Color(0xFFDCE8FA),
    border: Color(0xFFD6E2F5),
    borderActive: Color(0xFF1E5BD8),
    heroFrom: Color(0xFF1E4FA8),
    heroTo: Color(0xFF0D2B5E),
    textPrimary: Color(0xFF0B2350),
    textBody: Color(0xFF3D5580),
    textSecondary: Color(0xFF51698F),
    textOnDark: Color(0xFFF4F7FC),
    textOnDarkBody: Color(0xFFC9D8F2),
    primary: Color(0xFF1E5BD8),
    onPrimary: Color(0xFFFFFFFF),
    primaryOnDark: Color(0xFF6CB8FF),
    onPrimaryOnDark: Color(0xFF06101F),
    secondary: Color(0xFF137A5E), // success
    accent: Color(0xFF1E5BD8),
    info: Color(0xFF1E5BD8),
    warning: Color(0xFF8A6500),
    error: Color(0xFFC23A3A),
    divider: Color(0xFFD6E2F5),
    shadow: Color(0xFF0B2350),
    navBar: Color(0xF5FFFFFF), // white at 96 %
  );

  /// Ocean — follows system dark mode or the Settings choice.
  static const dark = MemoriaColors(
    background: Color(0xFF0B2350),
    surface: Color(0xFF123067),
    surfaceRaised: Color(0xFF1A3F80),
    surfaceTint: Color(0xFF1A3F80),
    border: Color(0xFF274886),
    borderActive: Color(0xFF6CB8FF),
    heroFrom: Color(0xFF1B4A9A),
    heroTo: Color(0xFF10306B),
    textPrimary: Color(0xFFF4F7FC),
    textBody: Color(0xFFC3D3EE),
    textSecondary: Color(0xFFA9BEE3),
    textOnDark: Color(0xFFF4F7FC),
    textOnDarkBody: Color(0xFFC9D8F2),
    primary: Color(0xFF6CB8FF),
    onPrimary: Color(0xFF0B2350),
    primaryOnDark: Color(0xFF6CB8FF),
    onPrimaryOnDark: Color(0xFF06101F),
    secondary: Color(0xFF7FE0C4),
    accent: Color(0xFF6CB8FF),
    info: Color(0xFF6CB8FF),
    warning: Color(0xFFF2D27A),
    error: Color(0xFFFF8A8A),
    divider: Color(0xFF274886),
    shadow: Color(0xFF020A1C),
    navBar: Color(0xF0123067), // #123067 at 94 %
  );

  final Color background;

  /// Cards, tiles, sheets.
  final Color surface;
  final Color surfaceRaised;

  /// Empty states, selected rows.
  final Color surfaceTint;

  /// 1 px card borders.
  final Color border;
  final Color borderActive;

  /// Hero card gradient (top → bottom).
  final Color heroFrom;
  final Color heroTo;

  /// Headlines and labels.
  final Color textPrimary;

  /// Body copy.
  final Color textBody;

  /// Hints and meta.
  final Color textSecondary;
  final Color textOnDark;
  final Color textOnDarkBody;
  final Color primary;
  final Color onPrimary;

  /// The main button inside the dark-blue hero.
  final Color primaryOnDark;
  final Color onPrimaryOnDark;

  /// Success (status, "Ordered", switches).
  final Color secondary;
  final Color accent;
  final Color info;
  final Color warning;
  final Color error;
  final Color divider;
  final Color shadow;

  /// The floating bottom navigation.
  final Color navBar;

  Color get success => secondary;

  static MemoriaColors of(BuildContext context) =>
      Theme.of(context).extension<MemoriaColors>() ?? light;

  @override
  MemoriaColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceTint,
    Color? border,
    Color? borderActive,
    Color? heroFrom,
    Color? heroTo,
    Color? textPrimary,
    Color? textBody,
    Color? textSecondary,
    Color? textOnDark,
    Color? textOnDarkBody,
    Color? primary,
    Color? onPrimary,
    Color? primaryOnDark,
    Color? onPrimaryOnDark,
    Color? secondary,
    Color? accent,
    Color? info,
    Color? warning,
    Color? error,
    Color? divider,
    Color? shadow,
    Color? navBar,
  }) {
    return MemoriaColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceTint: surfaceTint ?? this.surfaceTint,
      border: border ?? this.border,
      borderActive: borderActive ?? this.borderActive,
      heroFrom: heroFrom ?? this.heroFrom,
      heroTo: heroTo ?? this.heroTo,
      textPrimary: textPrimary ?? this.textPrimary,
      textBody: textBody ?? this.textBody,
      textSecondary: textSecondary ?? this.textSecondary,
      textOnDark: textOnDark ?? this.textOnDark,
      textOnDarkBody: textOnDarkBody ?? this.textOnDarkBody,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryOnDark: primaryOnDark ?? this.primaryOnDark,
      onPrimaryOnDark: onPrimaryOnDark ?? this.onPrimaryOnDark,
      secondary: secondary ?? this.secondary,
      accent: accent ?? this.accent,
      info: info ?? this.info,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      divider: divider ?? this.divider,
      shadow: shadow ?? this.shadow,
      navBar: navBar ?? this.navBar,
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
      surfaceTint: l(surfaceTint, other.surfaceTint),
      border: l(border, other.border),
      borderActive: l(borderActive, other.borderActive),
      heroFrom: l(heroFrom, other.heroFrom),
      heroTo: l(heroTo, other.heroTo),
      textPrimary: l(textPrimary, other.textPrimary),
      textBody: l(textBody, other.textBody),
      textSecondary: l(textSecondary, other.textSecondary),
      textOnDark: l(textOnDark, other.textOnDark),
      textOnDarkBody: l(textOnDarkBody, other.textOnDarkBody),
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      primaryOnDark: l(primaryOnDark, other.primaryOnDark),
      onPrimaryOnDark: l(onPrimaryOnDark, other.onPrimaryOnDark),
      secondary: l(secondary, other.secondary),
      accent: l(accent, other.accent),
      info: l(info, other.info),
      warning: l(warning, other.warning),
      error: l(error, other.error),
      divider: l(divider, other.divider),
      shadow: l(shadow, other.shadow),
      navBar: l(navBar, other.navBar),
    );
  }

  ColorScheme toColorScheme(Brightness brightness) {
    return ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: onPrimary,
      tertiary: accent,
      onTertiary: onPrimary,
      error: error,
      onError: onPrimary,
      surface: background,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      surfaceContainerLowest: surfaceRaised,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: surface,
      surfaceContainerHighest: surfaceTint,
      outline: border,
      outlineVariant: border,
      shadow: shadow,
      inverseSurface: textPrimary,
      onInverseSurface: background,
      inversePrimary: primary,
      primaryContainer: surfaceTint,
      onPrimaryContainer: textPrimary,
      secondaryContainer: surfaceTint,
      onSecondaryContainer: textPrimary,
      surfaceTint: Colors.transparent,
    );
  }
}

/// The six occasion tiles and their colours (tile icon background / icon).
enum OccasionTone {
  wedding(
    Color(0xFFEFE6FF),
    Color(0xFF7A4FC9),
    Color(0xFF2A2140),
    Color(0xFFD9B8FF),
  ),
  travel(
    Color(0xFFE1F0FF),
    Color(0xFF1E5BD8),
    Color(0xFF10304A),
    Color(0xFF7CC4FF),
  ),
  baby(
    Color(0xFFFFF4D6),
    Color(0xFF8A6500),
    Color(0xFF2E2A1A),
    Color(0xFFF2D27A),
  ),
  birthday(
    Color(0xFFFFE6EC),
    Color(0xFFC23A5C),
    Color(0xFF3A1D24),
    Color(0xFFFF9DB0),
  ),
  year(
    Color(0xFFDFF7EF),
    Color(0xFF137A5E),
    Color(0xFF12312B),
    Color(0xFF7FE0C4),
  ),
  family(
    Color(0xFFE6EAFF),
    Color(0xFF3E4FC0),
    Color(0xFF1E2440),
    Color(0xFFA9B8FF),
  );

  const OccasionTone(this.skyBg, this.skyIcon, this.oceanBg, this.oceanIcon);

  final Color skyBg;
  final Color skyIcon;
  final Color oceanBg;
  final Color oceanIcon;

  Color background(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? oceanBg : skyBg;

  Color icon(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? oceanIcon : skyIcon;
}
