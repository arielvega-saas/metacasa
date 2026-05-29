import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/widgets.dart';

/// Escala de espaciado de-facto del iOS (no había enum central; valores inline
/// muy consistentes). Padding de card H20/V16; hero 22; cards de feature 14;
/// márgenes de pantalla 16; gaps de sección 18.
abstract final class Insets {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 10;
  static const double xl = 12;
  static const double card = 14; // padding interno card de feature
  static const double screen = 16; // margen horizontal de pantalla
  static const double section = 18; // gap entre cards en scroll
  static const double cardLg = 20; // padding mcCard
  static const double hero = 22; // padding hero card
  static const double xxl = 32;

  // ── FAB del asistente (overlay bottomTrailing del shell) ──
  // En iOS: trailing 16, bottom ~100 (tab bar 49 + safe area 34 + extra). Acá la
  // NavigationBar mide 64 y `bottom` se cuenta desde el borde del Stack (que ya
  // está por encima de la bottomNavigationBar del Scaffold), así que basta un
  // gap chico para apoyar el FAB justo sobre la barra.
  static const double fabTrailing = 16;
  static const double fabBottom = 16;
}

/// Radios de esquina. TODO en el iOS usa esquinas continuous (squircle),
/// nunca circular. Usar [smooth] para construir el borde correcto.
abstract final class Radii {
  static const double pill = 14; // chips / inputs
  static const double input = 16;
  static const double card = 18; // el más usado
  static const double button = 20;
  static const double hero = 24; // hero card / mcCard grande
  static const double badge = 10;
  static const double progress = 8;

  /// Construye un `SmoothBorderRadius` (squircle estilo Apple) con el suavizado
  /// que mejor matchea el `.continuous` de SwiftUI.
  static SmoothBorderRadius smooth(double r, {double smoothing = 0.6}) =>
      SmoothBorderRadius(cornerRadius: r, cornerSmoothing: smoothing);
}

/// Sombras. El iOS es mayormente borderless (profundidad por stroke), con
/// glows de color en FAB/glow. Negras suaves y bajas para "glass".
abstract final class Shadows {
  static List<BoxShadow> glass = const [
    BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  /// Glow sage del FAB / elementos "positivos": sombra de color, no negra.
  static List<BoxShadow> sageGlow(Color sage) => [
        BoxShadow(
          color: sage.withValues(alpha: 0.35),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];
}
