import 'package:flutter/material.dart';

/// Midnight Sage — paleta portada 1:1 desde el iOS `Core/DesignSystem.swift`.
///
/// Estética dark-first "zen/spa nocturno": fondos casi negros con tinte verdoso,
/// bordes finos luminosos (sage glow), acento champagne dorado.
///
/// - Las **superficies y textos** son dinámicos (cambian light/dark).
/// - Los **acentos de marca** son estáticos (mismo hex en ambos modos; afinados
///   para leerse bien en los dos).
///
/// Material `ColorScheme` no alcanza para expresar todos estos tokens, así que
/// viven en este `ThemeExtension`. Acceso ergonómico vía `context.colors`.
@immutable
class MidnightSageColors extends ThemeExtension<MidnightSageColors> {
  // Fondos (verde-tintados, cálidos)
  final Color appBackground;
  final Color appSurface;
  final Color appSurfaceInset;

  /// Borde/divisor — EL elemento firma. En dark es el sage al 12% → se lee como
  /// un borde luminoso, no como una línea gris.
  final Color appBorder;

  // Texto (cream cálido en dark)
  final Color textPrimary;
  final Color textMuted;
  final Color textDim;

  // Acentos de marca (estáticos en ambos modos)
  final Color brandPrimary; // sage glow — acento principal
  final Color brandSecondary; // champagne dorado — acento cálido
  final Color brandSuccess; // sage saturado — ingreso / positivo
  final Color brandDanger; // coral cálido (NO rojo frío) — gasto / negativo
  final Color brandWarning; // champagne — advertencias

  const MidnightSageColors({
    required this.appBackground,
    required this.appSurface,
    required this.appSurfaceInset,
    required this.appBorder,
    required this.textPrimary,
    required this.textMuted,
    required this.textDim,
    required this.brandPrimary,
    required this.brandSecondary,
    required this.brandSuccess,
    required this.brandDanger,
    required this.brandWarning,
  });

  static const light = MidnightSageColors(
    appBackground: Color(0xFFF5F7F4),
    appSurface: Color(0xFFFFFFFF),
    appSurfaceInset: Color(0xFFEEF0EC),
    appBorder: Color(0xFFE3E6E1), // sólido en light
    textPrimary: Color(0xFF0E1312),
    textMuted: Color(0xFF5A6560),
    textDim: Color(0xFFB8BDB6),
    brandPrimary: Color(0xFFB8D4C2),
    brandSecondary: Color(0xFFD4C19C),
    brandSuccess: Color(0xFF9FC4AD),
    brandDanger: Color(0xFFE8B4A6),
    brandWarning: Color(0xFFD4C19C),
  );

  static const dark = MidnightSageColors(
    appBackground: Color(0xFF0E1312), // Midnight Sage — casi negro verdoso
    appSurface: Color(0xFF151C1A),
    appSurfaceInset: Color(0xFF0B0F0E),
    appBorder: Color(0x1FB8D4C2), // #B8D4C2 @ ~12% → borde luminoso
    textPrimary: Color(0xFFE8E4DC),
    textMuted: Color(0xFF7A8782),
    textDim: Color(0xFF3E4844),
    brandPrimary: Color(0xFFB8D4C2),
    brandSecondary: Color(0xFFD4C19C),
    brandSuccess: Color(0xFF9FC4AD),
    brandDanger: Color(0xFFE8B4A6),
    brandWarning: Color(0xFFD4C19C),
  );

  /// Color de un monto según signo: gasto→coral, ingreso→sage, 0→neutro.
  Color amount(double value) => value < 0
      ? brandDanger
      : value > 0
          ? brandSuccess
          : textPrimary;

  /// Color de progreso de presupuesto (envelope) por % usado.
  /// >0.95 peligro, >0.80 advertencia, si no éxito. (Igual que iOS.)
  Color budgetThreshold(double percentUsed) => percentUsed > 0.95
      ? brandDanger
      : percentUsed > 0.80
          ? brandWarning
          : brandSuccess;

  @override
  MidnightSageColors copyWith({
    Color? appBackground,
    Color? appSurface,
    Color? appSurfaceInset,
    Color? appBorder,
    Color? textPrimary,
    Color? textMuted,
    Color? textDim,
    Color? brandPrimary,
    Color? brandSecondary,
    Color? brandSuccess,
    Color? brandDanger,
    Color? brandWarning,
  }) {
    return MidnightSageColors(
      appBackground: appBackground ?? this.appBackground,
      appSurface: appSurface ?? this.appSurface,
      appSurfaceInset: appSurfaceInset ?? this.appSurfaceInset,
      appBorder: appBorder ?? this.appBorder,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      textDim: textDim ?? this.textDim,
      brandPrimary: brandPrimary ?? this.brandPrimary,
      brandSecondary: brandSecondary ?? this.brandSecondary,
      brandSuccess: brandSuccess ?? this.brandSuccess,
      brandDanger: brandDanger ?? this.brandDanger,
      brandWarning: brandWarning ?? this.brandWarning,
    );
  }

  @override
  MidnightSageColors lerp(ThemeExtension<MidnightSageColors>? other, double t) {
    if (other is! MidnightSageColors) return this;
    return MidnightSageColors(
      appBackground: Color.lerp(appBackground, other.appBackground, t)!,
      appSurface: Color.lerp(appSurface, other.appSurface, t)!,
      appSurfaceInset: Color.lerp(appSurfaceInset, other.appSurfaceInset, t)!,
      appBorder: Color.lerp(appBorder, other.appBorder, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textDim: Color.lerp(textDim, other.textDim, t)!,
      brandPrimary: Color.lerp(brandPrimary, other.brandPrimary, t)!,
      brandSecondary: Color.lerp(brandSecondary, other.brandSecondary, t)!,
      brandSuccess: Color.lerp(brandSuccess, other.brandSuccess, t)!,
      brandDanger: Color.lerp(brandDanger, other.brandDanger, t)!,
      brandWarning: Color.lerp(brandWarning, other.brandWarning, t)!,
    );
  }
}

/// Acceso ergonómico: `context.colors.brandPrimary`.
extension MidnightSageColorsX on BuildContext {
  MidnightSageColors get colors =>
      Theme.of(this).extension<MidnightSageColors>()!;
}
