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
  final text = buildTextTheme(c.textPrimary, c.textSecondary);

  const inputBorder = OutlineInputBorder(
    borderRadius: Radii.inputAll,
    borderSide: BorderSide.none,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.background,
    canvasColor: c.background,
    dividerColor: c.divider,
    fontFamily: Fonts.inter,
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
      shape: const RoundedRectangleBorder(borderRadius: Radii.cardAll),
    ),
    dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        disabledBackgroundColor: c.divider,
        disabledForegroundColor: c.textSecondary,
        minimumSize: const Size(kMinTapTarget, 56),
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
        side: BorderSide(color: c.textPrimary.withValues(alpha: 0.28)),
        shape: const StadiumBorder(),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.info,
        minimumSize: const Size(kMinTapTarget, kMinTapTarget),
        textStyle: text.labelMedium,
        shape: const StadiumBorder(),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: c.textPrimary,
        minimumSize: const Size(kMinTapTarget, kMinTapTarget),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: c.info, width: 1.5),
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
      selectedColor: c.textPrimary,
      labelStyle: text.labelMedium,
      secondaryLabelStyle: text.labelMedium?.copyWith(color: c.background),
      side: BorderSide.none,
      shape: const RoundedRectangleBorder(borderRadius: Radii.inputAll),
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 10),
      showCheckmark: false,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.background,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: c.background,
      shape: const RoundedRectangleBorder(borderRadius: Radii.sheetTop),
      showDragHandle: true,
      dragHandleColor: c.divider,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: Radii.cardAll),
      titleTextStyle: text.headlineSmall,
      contentTextStyle: text.bodyMedium,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.background,
      surfaceTintColor: Colors.transparent,
      indicatorColor: c.surface,
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(text.labelSmall),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? c.textPrimary
              : c.textSecondary,
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.textPrimary : null,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? c.background : c.textPrimary,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: c.divider)),
        minimumSize: const WidgetStatePropertyAll(Size(0, kMinTapTarget)),
        textStyle: WidgetStatePropertyAll(text.labelMedium),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.primary,
      linearTrackColor: c.surface,
      circularTrackColor: c.surface,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.onPrimary : c.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.secondary : c.surface,
      ),
      trackOutlineColor: WidgetStatePropertyAll(c.divider),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.textPrimary,
      contentTextStyle: text.bodyMedium?.copyWith(color: c.background),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: Radii.inputAll),
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
      labelColor: c.textPrimary,
      unselectedLabelColor: c.textSecondary,
      indicatorColor: c.textPrimary,
      dividerColor: c.divider,
      labelStyle: text.labelMedium,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
  );
}
