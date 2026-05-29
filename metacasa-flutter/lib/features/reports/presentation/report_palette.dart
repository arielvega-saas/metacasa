import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Paleta de colores para los gráficos de Reportes (Midnight Sage).
///
/// El donut de categorías y los charts comparativos necesitan un ciclo de
/// colores legible sobre el fondo verdoso-negro. En vez de inventar hex sueltos,
/// derivamos el ciclo de los acentos de marca (`context.colors`) + algunas
/// variaciones de opacidad, así respeta el tema (light/dark) y la estética.
///
/// El orden está pensado para que dos tajadas contiguas del Pareto contrasten
/// bien (alterna sage / champagne / coral / variaciones).
abstract final class ReportPalette {
  const ReportPalette._();

  /// Color de la categoría en posición [index] del ciclo. Hace wrap con módulo,
  /// así soporta cualquier cantidad de categorías sin romperse.
  static Color categoryColor(MidnightSageColors c, int index) {
    final List<Color> cycle = <Color>[
      c.brandPrimary, // sage glow
      c.brandSecondary, // champagne
      c.brandDanger, // coral
      c.brandSuccess, // sage saturado
      c.brandPrimary.withValues(alpha: 0.6),
      c.brandSecondary.withValues(alpha: 0.6),
      c.brandDanger.withValues(alpha: 0.6),
      c.brandSuccess.withValues(alpha: 0.6),
    ];
    return cycle[index % cycle.length];
  }
}
