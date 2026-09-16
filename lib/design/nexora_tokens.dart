import 'package:flutter/material.dart';

/// Paleta semántica expuesta desde el tema (resuelta por modo claro/oscuro).
@immutable
final class NexoraPalette extends ThemeExtension<NexoraPalette> {
  const NexoraPalette({
    required this.background,
    required this.surface,
    required this.elevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.textBody,
    required this.textMuted,
    required this.border,
    required this.hover,
    required this.active,
    required this.placeholderA,
    required this.placeholderB,
  });

  final Color background;
  final Color surface;
  final Color elevated;
  final Color textPrimary;
  final Color textSecondary;
  final Color textBody;
  final Color textMuted;
  final Color border;
  final Color hover;
  final Color active;
  final Color placeholderA;
  final Color placeholderB;

  static NexoraPalette of(BuildContext context) =>
      Theme.of(context).extension<NexoraPalette>() ?? NexoraPalette.dark;

  static const dark = NexoraPalette(
    background: NXColors.darkBg,
    surface: NXColors.darkSurface,
    elevated: NXColors.darkElevated,
    textPrimary: NXColors.textPrimary,
    textSecondary: NXColors.textSecondaryDark,
    textBody: NXColors.textBodyDark,
    textMuted: NXColors.textMutedDark,
    border: NXColors.borderDark,
    hover: NXColors.hoverDark,
    active: NXColors.activeDark,
    placeholderA: NXColors.placeholderA,
    placeholderB: NXColors.placeholderB,
  );

  static const light = NexoraPalette(
    background: NXColors.lightBg,
    surface: NXColors.lightSurface,
    elevated: NXColors.lightSurface,
    textPrimary: NXColors.textPrimaryLight,
    textSecondary: NXColors.textSecondaryLight,
    textBody: NXColors.textBodyLight,
    textMuted: NXColors.textMutedLight,
    border: NXColors.borderLight,
    hover: NXColors.hoverLight,
    active: NXColors.activeLight,
    placeholderA: NXColors.placeholderALight,
    placeholderB: NXColors.placeholderBLight,
  );

  @override
  NexoraPalette copyWith({
    Color? background,
    Color? surface,
    Color? elevated,
    Color? textPrimary,
    Color? textSecondary,
    Color? textBody,
    Color? textMuted,
    Color? border,
    Color? hover,
    Color? active,
    Color? placeholderA,
    Color? placeholderB,
  }) {
    return NexoraPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      elevated: elevated ?? this.elevated,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textBody: textBody ?? this.textBody,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      hover: hover ?? this.hover,
      active: active ?? this.active,
      placeholderA: placeholderA ?? this.placeholderA,
      placeholderB: placeholderB ?? this.placeholderB,
    );
  }

  @override
  NexoraPalette lerp(NexoraPalette? other, double t) {
    if (other == null) return this;
    return NexoraPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      elevated: Color.lerp(elevated, other.elevated, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textBody: Color.lerp(textBody, other.textBody, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      hover: Color.lerp(hover, other.hover, t)!,
      active: Color.lerp(active, other.active, t)!,
      placeholderA: Color.lerp(placeholderA, other.placeholderA, t)!,
      placeholderB: Color.lerp(placeholderB, other.placeholderB, t)!,
    );
  }
}

/// Sistema de diseño NEXORA — NPhotos.
///
/// Fuente de verdad única de colores, tipografía, espaciado, radios,
/// sombras y transiciones. No se usan valores sueltos fuera de este fichero.

abstract final class NXColors {
  // Marca
  static const primary = Color(0xFFE11F2F);
  static const primaryHover = Color(0xFFC41825);
  static const primaryActive = Color(0xFFA0121D);

  static const red10 = Color(0x1AE11F2F);
  static const red20 = Color(0x33E11F2F);

  // Neutros oscuros
  static const darkBg = Color(0xFF0A0A0C);
  static const darkSurface = Color(0xFF141417);
  static const darkElevated = Color(0xFF1C1C21);

  // Neutros claros
  static const lightBg = Color(0xFFF5F5F7);
  static const lightSurface = Color(0xFFFFFFFF);

  // Texto oscuro
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondaryDark = Color(0xFFD2D2D7);
  static const textBodyDark = Color(0xFFA1A1A6);
  static const textMutedDark = Color(0xFF6E6E73);

  // Texto claro
  static const textPrimaryLight = Color(0xFF1D1D1F);
  static const textSecondaryLight = Color(0xFF55555A);
  static const textBodyLight = Color(0xFF6E6E73);
  static const textMutedLight = Color(0xFF98989D);

  // Superposiciones oscuras
  static const borderDark = Color(0x1AFFFFFF); // rgba(255,255,255,0.10)
  static const hoverDark = Color(0x0DFFFFFF); // rgba(255,255,255,0.05)
  static const activeDark = Color(0x14FFFFFF); // rgba(255,255,255,0.08)

  // Superposiciones claras
  static const borderLight = Color(0x14000000); // rgba(0,0,0,0.08)
  static const hoverLight = Color(0x0D000000); // rgba(0,0,0,0.05)
  static const activeLight = Color(0x14000000); // rgba(0,0,0,0.08)

  // Placeholder suave para tarjetas sin miniatura
  static const placeholderA = Color(0xFF232329);
  static const placeholderB = Color(0xFF2E2E35);
  static const placeholderALight = Color(0xFFE8E8ED);
  static const placeholderBLight = Color(0xFFD9D9E0);

  // Paleta de gradientes determinista para variedad visual en mock/portadas
  static const coverGradients = <List<Color>>[
    [Color(0xFFE11F2F), Color(0xFF7A0E19)],
    [Color(0xFF1F6FE1), Color(0xFF0E3D7A)],
    [Color(0xFF27AE60), Color(0xFF0F5C33)],
    [Color(0xFFE1A51F), Color(0xFF7A580E)],
    [Color(0xFF9B51E0), Color(0xFF4A247A)],
    [Color(0xFF2DB6C9), Color(0xFF145A63)],
    [Color(0xFFE14F6E), Color(0xFF7A1E33)],
    [Color(0xFF4A5568), Color(0xFF1A202C)],
  ];
}

/// Espaciado del sistema.
abstract final class NXSpace {
  static const s0 = 0.0;
  static const s2 = 2.0;
  static const s4 = 4.0;
  static const s6 = 6.0;
  static const s8 = 8.0;
  static const s10 = 10.0;
  static const s12 = 12.0;
  static const s14 = 14.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
  static const s28 = 28.0;
  static const s32 = 32.0;
  static const s48 = 48.0;
  static const s64 = 64.0;

  static const horizontalPadding = s24;
}

/// Radios del sistema.
abstract final class NXRadius {
  static const radius6 = 6.0;
  static const radius8 = 8.0;
  static const radius10 = 10.0;
  static const radius12 = 12.0;
  static const radius14 = 14.0;
  static const radius16 = 16.0;
  static const radius20 = 20.0;
  static const radius24 = 24.0;
}

/// Transiciones y curvas.
abstract final class NXTransition {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 180);
  static const Duration slow = Duration(milliseconds: 240);

  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve accent = Curves.easeInOutCubic;
}

/// Elevaciones sutiles (sin sombras exageradas).
abstract final class NXShadow {
  static List<BoxShadow> neutral(ThemeData theme) => [
    BoxShadow(
      color: Colors.black.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.28 : 0.10,
      ),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}

/// Jerarquía tipográfica NEXORA (Inter).
abstract final class NXText {
  static const String family = 'Inter';

  // NPhotos — 24–32 semibold
  static TextStyle display(BuildContext context) => _style(context)
      .displayLarge!
      .copyWith(fontSize: 30, fontWeight: FontWeight.w600, letterSpacing: -0.5);

  // Título de sección — 20–24 semibold
  static TextStyle sectionTitle(BuildContext context) => _style(context)
      .headlineSmall!
      .copyWith(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.3);

  // Subtítulo — 15–16 medium
  static TextStyle cardTitle(BuildContext context) =>
      _style(context).titleMedium!
          .copyWith(fontSize: 15, fontWeight: FontWeight.w500);

  // Nombre de álbum — 13–15 medium
  static TextStyle albumName(BuildContext context) =>
      _style(context).titleSmall!
          .copyWith(fontSize: 14, fontWeight: FontWeight.w500);

  // Metadata — 11–13 regular
  static TextStyle metadata(BuildContext context) =>
      _style(context).bodySmall!
          .copyWith(fontSize: 12, fontWeight: FontWeight.w400, height: 1.35);

  static TextStyle muted(BuildContext context) => _style(context).bodySmall!
      .copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        height: 1.3,
        letterSpacing: 0.1,
      );

  static TextTheme _style(BuildContext context) => Theme.of(context).textTheme;
}
