import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tipografía Midnight Sage — portada desde `DesignSystem.swift`.
///
/// El iOS mezcla **sans (SF system)** para toda la UI con **serif (New York)**
/// reservada para los montos hero ("editorial data display"). En Android:
/// - SF system  → **Inter** (intención declarada en los comentarios del iOS).
/// - New York   → **Newsreader** (serif transicional moderna, el match más fiel).
///
/// Los tamaños/pesos son exactos al iOS. `.black`→w900, `.bold`→w700,
/// `.semibold`→w600, `.medium`→w500, `.regular`→w400.
abstract final class AppText {
  // ───────── Sans (Inter) — UI / headings ─────────
  static TextStyle display(Color c) =>
      GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w900, color: c, height: 1.05);

  static TextStyle h1(Color c) =>
      GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: c, height: 1.1);

  static TextStyle h2(Color c) =>
      GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: c, height: 1.15);

  /// Monto en sans bold con dígitos monoespaciados (alternativa al serif).
  static TextStyle amount(Color c) => GoogleFonts.inter(
        fontSize: 26,
        fontWeight: FontWeight.w900,
        color: c,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Eyebrow / overline en smallCaps ("POR ASIGNAR", labels de campos).
  static TextStyle label(Color c) => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: c,
        letterSpacing: 0.5,
        fontFeatures: const [FontFeature.enable('smcp')],
      );

  static TextStyle body(Color c) =>
      GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: c, height: 1.35);

  static TextStyle caption(Color c) =>
      GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: c, height: 1.3);

  // ───────── Serif (Newsreader / New York) — montos hero ─────────
  static TextStyle serifHero(Color c) =>
      GoogleFonts.newsreader(fontSize: 52, fontWeight: FontWeight.w400, color: c, height: 1.0);

  static TextStyle serifTitle(Color c) =>
      GoogleFonts.newsreader(fontSize: 28, fontWeight: FontWeight.w400, color: c, height: 1.1);

  static TextStyle serifDisplay(Color c) =>
      GoogleFonts.newsreader(fontSize: 34, fontWeight: FontWeight.w400, color: c, height: 1.05);

  static TextStyle serifAmount(Color c) =>
      GoogleFonts.newsreader(fontSize: 22, fontWeight: FontWeight.w400, color: c);

  static TextStyle serifInline(Color c) =>
      GoogleFonts.newsreader(fontSize: 16, fontWeight: FontWeight.w400, color: c);
}
