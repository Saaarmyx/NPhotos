import 'package:flutter/material.dart';

import 'nexora_tokens.dart';

/// Construye el ThemeData de NEXORA para un [Brightness] dado.
ThemeData buildNexoraTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final palette = isDark ? NexoraPalette.dark : NexoraPalette.light;
  final base = ThemeData(
    brightness: brightness,
    useMaterial3: true,
  );

  final baseText = base.textTheme.apply(
    fontFamily: NXText.family,
    bodyColor: palette.textPrimary,
    displayColor: palette.textPrimary,
  );

  final textTheme = baseText.copyWith(
    displayLarge: baseText.displayLarge?.copyWith(
      fontSize: 30,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
      height: 1.15,
    ),
    headlineLarge: baseText.headlineLarge?.copyWith(
      fontSize: 26,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
    ),
    headlineMedium: baseText.headlineMedium?.copyWith(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
    ),
    headlineSmall: baseText.headlineSmall?.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
    ),
    titleLarge: baseText.titleLarge?.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: baseText.titleMedium?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
    ),
    titleSmall: baseText.titleSmall?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
    ),
    bodyLarge: baseText.bodyLarge?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: palette.textBody,
      height: 1.4,
    ),
    bodyMedium: baseText.bodyMedium?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: palette.textBody,
      height: 1.4,
    ),
    bodySmall: baseText.bodySmall?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: palette.textSecondary,
      height: 1.35,
    ),
    labelLarge: baseText.labelLarge?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
    labelMedium: baseText.labelMedium?.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
    ),
    labelSmall: baseText.labelSmall?.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w400,
      color: palette.textMuted,
      letterSpacing: 0.3,
    ),
  );

  final scheme = ColorScheme.fromSeed(
    seedColor: NXColors.primary,
    brightness: brightness,
    primary: NXColors.primary,
    onPrimary: NXColors.textPrimary,
    surface: palette.surface,
    onSurface: palette.textPrimary,
    onSurfaceVariant: palette.textSecondary,
    error: NXColors.primary,
  ).copyWith(surface: palette.surface);

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.background,
    canvasColor: palette.background,
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.standard,
    textTheme: textTheme,
    extensions: [palette],
    highlightColor: Colors.transparent,
    focusColor: Colors.transparent,
    dividerTheme: DividerThemeData(color: palette.border, thickness: 1, space: 1),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: palette.elevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NXRadius.radius16),
      ),
    ),
    snackBarTheme: base.snackBarTheme.copyWith(
      backgroundColor: palette.elevated,
      contentTextStyle: textTheme.bodyMedium,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NXRadius.radius12),
      ),
    ),
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        TargetPlatform.linux: const FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: const FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.android: const FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: const FadeForwardsPageTransitionsBuilder(),
      },
    ),
    tooltipTheme: base.tooltipTheme.copyWith(
      waitDuration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: palette.elevated,
        borderRadius: BorderRadius.circular(NXRadius.radius8),
        border: Border.all(color: palette.border),
      ),
      textStyle: textTheme.labelMedium,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: palette.elevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NXRadius.radius12),
        side: BorderSide(color: palette.border),
      ),
      textStyle: textTheme.bodyMedium,
    ),
    progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
      color: NXColors.primary,
      linearTrackColor: NXColors.primary.withValues(alpha: 0.15),
    ),
    cardTheme: base.cardTheme.copyWith(
      color: palette.elevated,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: palette.textPrimary,
        hoverColor: palette.hover,
        focusColor: palette.hover,
        highlightColor: palette.active,
        visualDensity: VisualDensity.compact,
      ),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: NXColors.primary,
      inactiveTrackColor: palette.active,
      thumbColor: NXColors.primary,
      overlayColor: NXColors.red10,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      hintStyle: textTheme.bodyMedium?.copyWith(color: palette.textMuted),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: NXSpace.s16,
        vertical: NXSpace.s8,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(NXRadius.radius10),
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(NXRadius.radius10),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(NXRadius.radius10),
        borderSide: BorderSide(color: NXColors.primary, width: 1.4),
      ),
    ),
  );
}