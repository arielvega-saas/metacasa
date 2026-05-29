import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Construye el `ThemeData` Midnight Sage para un brillo dado.
/// Dark es el default de la app (igual que iOS).
ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final c = isDark ? MidnightSageColors.dark : MidnightSageColors.light;

  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: c.brandPrimary,
    onPrimary: const Color(0xFF0E1312), // texto oscuro sobre sage
    secondary: c.brandSecondary,
    onSecondary: const Color(0xFF0E1312),
    error: c.brandDanger,
    onError: const Color(0xFF0E1312),
    surface: c.appSurface,
    onSurface: c.textPrimary,
    surfaceContainerHighest: c.appSurfaceInset,
    outline: c.appBorder,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: c.appBackground,
    splashFactory: InkSparkle.splashFactory,
    extensions: [c],
  );

  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: c.textPrimary,
      displayColor: c.textPrimary,
    ),
    dividerTheme: DividerThemeData(color: c.appBorder, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: c.appBackground,
      foregroundColor: c.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
  );
}

class AppTheme {
  // Cacheado en `static final`: construir el ThemeData + el textTheme de
  // GoogleFonts es caro y antes corría en cada rebuild de MaterialApp (eran
  // getters). Ahora se computa una sola vez por brillo.
  static final ThemeData light = buildAppTheme(Brightness.light);
  static final ThemeData dark = buildAppTheme(Brightness.dark);
}
