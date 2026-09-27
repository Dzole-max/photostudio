import 'package:material_ui/material_ui.dart';

import 'colors.dart';

/// Spacing scale: 4, 8, 12, 16, 24, 32, 48, 64.
abstract final class Space {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
}

abstract final class Radii {
  static const double input = 14;
  static const double chip = 12;
  static const double card = 20;
  static const double hero = 28;
  static const double sheet = 28;
  static const double pill = 999;
  static const double paper = 2;

  static const BorderRadius inputAll = BorderRadius.all(Radius.circular(input));
  static const BorderRadius cardAll = BorderRadius.all(Radius.circular(card));
  static const BorderRadius heroAll = BorderRadius.all(Radius.circular(hero));
  static const BorderRadius paperAll = BorderRadius.all(Radius.circular(paper));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
}

/// Soft, blue-tinted shadows (navy at 8–14 %, blur 24–40). No hard
/// Material elevation.
abstract final class Shadows {
  static List<BoxShadow> soft(MemoriaColors c) => [
    BoxShadow(
      color: c.shadow.withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> raised(MemoriaColors c) => [
    BoxShadow(
      color: c.shadow.withValues(alpha: 0.14),
      blurRadius: 40,
      offset: const Offset(0, 14),
    ),
  ];
}

abstract final class Motion {
  static const Duration short = Duration(milliseconds: 300);

  /// Section entry: fade in and rise 12 px, 60 ms apart.
  static const Duration entry = Duration(milliseconds: 350);
  static const Duration stagger = Duration(milliseconds: 60);
  static const Duration medium = Duration(milliseconds: 360);
  static const Duration long = Duration(milliseconds: 400);
  static const Curve curve = Curves.easeOutCubic;

  /// True when the platform asks for reduced motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Minimum tappable size (accessibility).
const double kMinTapTarget = 48;
