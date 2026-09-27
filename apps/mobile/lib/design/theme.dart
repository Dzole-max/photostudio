import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'colors.dart';
import 'tokens.dart';
import 'typography.dart';

ThemeData buildMemoriaTheme(Brightness brightness) {
  final c = brightness == Brightness.light
      ? MemoriaColors.light
      : MemoriaColors.dark;
  final scheme = c.toColorScheme(brightness);
  final text = buildTextTheme(c.textPrimary, c.textBody, c.textSecondary);

  final inputBorder = OutlineInputBorder(
    borderRadius: Radii.inputAll,
    borderSide: BorderSide(color: c.border),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.background,
    canvasColor: c.background,
    dividerColor: c.divider,
    fontFamily: Fonts.onest,
    textTheme: text,
    splashFactory: InkSparkle.splashFactory,
    extensions: [c],
    appBarTheme: AppBarTheme(
      backgroundColor: c.background,
      foregroundColor: c.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
      systemOverlayStyle: brightness == Brightness.light
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.cardAll,
        side: BorderSide(color: c.border),
      ),
    ),
    dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        disabledBackgroundColor: c.surfaceTint,
        disabledForegroundColor: c.textSecondary,
        minimumSize: const Size(kMinTapTarget, 54),
        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
        shape: const StadiumBorder(),
        textStyle: text.labelLarge,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.textPrimary,
        minimumSize: const Size(kMinTapTarget, 52),
        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
        side: BorderSide(color: c.border, width: 1.5),
        backgroundColor: c.surface,
        shape: const StadiumBorder(),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.primary,
        minimumSize: const Size(kMinTapTarget, kMinTapTarget),
        textStyle: text.labelMedium,
        shape: const StadiumBorder(),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: c.textPrimary,
        minimumSize: const Size(44, 44),
        shape: const CircleBorder(),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: c.borderActive, width: 1.5),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: c.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.md,
      ),
      hintStyle: text.bodyLarge?.copyWith(color: c.textSecondary),
      labelStyle: text.bodyMedium?.copyWith(color: c.textSecondary),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surface,
      selectedColor: c.primary,
      labelStyle: text.labelMedium,
      secondaryLabelStyle: text.labelMedium?.copyWith(color: c.onPrimary),
      side: BorderSide(color: c.border),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 10),
      showCheckmark: false,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.background,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: c.background,
      shape: const RoundedRectangleBorder(borderRadius: Radii.sheetTop),
      showDragHandle: true,
      dragHandleColor: c.border,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: Radii.heroAll),
      titleTextStyle: text.headlineSmall,
      contentTextStyle: text.bodyMedium,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.background,
      surfaceTintColor: Colors.transparent,
      indicatorColor: c.surfaceTint,
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(text.labelSmall),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? c.primary
              : c.textSecondary,
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onPrimary : c.textPrimary,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: c.border)),
        minimumSize: const WidgetStatePropertyAll(Size(0, kMinTapTarget)),
        textStyle: WidgetStatePropertyAll(text.labelMedium),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.primary,
      linearTrackColor: c.surfaceTint,
      circularTrackColor: c.surfaceTint,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.onPrimary : c.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.primary : c.surfaceTint,
      ),
      trackOutlineColor: WidgetStatePropertyAll(c.border),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.textPrimary,
      contentTextStyle: text.bodyMedium?.copyWith(color: c.background),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: Radii.cardAll),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: c.textSecondary,
      textColor: c.textPrimary,
      minVerticalPadding: Space.sm,
      contentPadding: const EdgeInsetsDirectional.symmetric(
        horizontal: Space.md,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: c.primary,
      unselectedLabelColor: c.textSecondary,
      indicatorColor: c.primary,
      dividerColor: c.border,
      labelStyle: text.labelMedium,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
  );
}
