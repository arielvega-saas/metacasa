import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

/// Estilo de presentación del monto. Espejo de `Money.Style` en iOS
/// (`Core/Money.swift`).
enum MoneyStyle {
  /// Sin decimales (estilo LatAm para montos grandes, UX limpia). `$ 1.234`
  compact,

  /// Con 2 decimales (exacto). `$ 1.234,56`
  precise,

  /// Auto: compact si el monto es entero, precise si tiene fracción.
  auto,

  /// Notación compacta con sufijos (K/M/B/T) según locale. `$4,4M` / `$15K`.
  /// Útil para celdas chicas (calendar, widgets, charts).
  abbreviated,
}

/// Formatter centralizado de dinero + parsing robusto.
///
/// Port del `enum Money` de iOS (`Core/Money.swift`). En lugar del
/// `Decimal.FormatStyle.Currency` de Swift usamos `NumberFormat` de `intl`
/// para el agrupamiento/decimales según locale, combinado con el símbolo
/// custom del [_symbols] (catálogo `CurrenciesCatalog.swift`).
///
/// Ejemplos:
///   Money.format(Decimal.parse('1234.56'), currencyCode: 'ARS', locale: 'es_AR')
///     → "$ 1.234"        (compact, 0 decimales)
///   Money.format(Decimal.parse('1234.56'), currencyCode: 'USD',
///                style: MoneyStyle.precise, locale: 'en_US')
///     → "U$S 1,234.56"
///   Money.format(Decimal.parse('1234.56'), currencyCode: 'EUR',
///                style: MoneyStyle.precise, locale: 'es_ES')
///     → "1.234,56 €"      (símbolo como sufijo)
class Money {
  const Money._();

  /// Símbolos custom por código ISO 4217 — port 1:1 de `CurrenciesCatalog.all`
  /// (`Core/CurrenciesCatalog.swift`). Difieren de los símbolos default de
  /// `intl` (ej. USD = `U$S`, no `$`).
  static const Map<String, String> _symbols = <String, String>{
    // América Latina
    'ARS': r'$',
    'BRL': r'R$',
    'CLP': r'CL$',
    'COP': r'CO$',
    'MXN': r'MX$',
    'PEN': 'S/.',
    'UYU': r'$U',
    'PYG': '₲',
    'BOB': 'Bs.',
    'VES': 'Bs.S',
    // Norte América
    'USD': r'U$S',
    'CAD': r'CA$',
    // Europa
    'EUR': '€',
    'GBP': '£',
    'CHF': 'Fr.',
    'SEK': 'kr',
    'NOK': 'kr',
    'DKK': 'kr',
    'PLN': 'zł',
    // Asia · Pacífico
    'JPY': '¥',
    'CNY': r'CN¥',
    'KRW': '₩',
    'INR': '₹',
    'AUD': r'A$',
    'NZD': r'NZ$',
    'SGD': r'S$',
    'HKD': r'HK$',
    // Medio Oriente · África
    'AED': 'د.إ',
    'ILS': '₪',
    'ZAR': 'R',
  };

  /// Monedas cuyo símbolo va como **sufijo** (`1.234,56 €`) en lugar de prefijo.
  /// El resto usa prefijo con espacio (`$ 1.234`), siguiendo la convención
  /// LatAm de la PWA/iOS.
  static const Set<String> _suffixCurrencies = <String>{
    'EUR',
    'SEK',
    'NOK',
    'DKK',
    'PLN',
    'CHF',
  };

  /// Símbolo custom para [code] (mayúsculas). Cae al propio código si no está
  /// en el catálogo.
  static String symbolFor(String code) =>
      _symbols[code.toUpperCase()] ?? code.toUpperCase();

  /// Formatea un monto como moneda según [locale] + código ISO 4217.
  ///
  /// - [style]: ver [MoneyStyle].
  /// - [showSign]: antepone `+` para montos positivos (ingresos/aportes).
  /// - [locale]: identificador ICU (`es_AR`, `en_US`, `pt_BR`, …).
  static String format(
    Decimal value, {
    required String currencyCode,
    MoneyStyle style = MoneyStyle.compact,
    bool showSign = false,
    String locale = 'es_AR',
  }) {
    final String symbol = symbolFor(currencyCode);
    final String body;

    if (style == MoneyStyle.abbreviated) {
      body = _abbreviated(value, locale: locale);
    } else {
      final int fractionDigits = switch (style) {
        MoneyStyle.compact => 0,
        MoneyStyle.precise => 2,
        MoneyStyle.auto => value.isInteger ? 0 : 2,
        MoneyStyle.abbreviated => 0, // inalcanzable
      };
      body = _grouped(value, fractionDigits: fractionDigits, locale: locale);
    }

    final String formatted = _withSymbol(body, symbol, currencyCode);

    // Signo '+' para positivos (no afecta a 0 ni a negativos).
    if (showSign && value > Decimal.zero) {
      return '+$formatted';
    }
    return formatted;
  }

  /// Combina cuerpo numérico + símbolo respetando prefijo/sufijo por moneda.
  static String _withSymbol(String body, String symbol, String code) {
    if (_suffixCurrencies.contains(code.toUpperCase())) {
      return '$body $symbol';
    }
    return '$symbol $body';
  }

  /// Cuerpo numérico agrupado según locale, con dígitos fraccionarios fijos.
  static String _grouped(
    Decimal value, {
    required int fractionDigits,
    required String locale,
  }) {
    final NumberFormat nf = NumberFormat.decimalPattern(locale)
      ..minimumFractionDigits = fractionDigits
      ..maximumFractionDigits = fractionDigits;
    // Redondeamos en Decimal y pasamos por double sólo para el agrupamiento
    // visual (la fuente de verdad sigue siendo Decimal).
    final Decimal rounded = value.round(scale: fractionDigits);
    return nf.format(rounded.toDouble());
  }

  /// Notación abreviada con sufijos K/M/B/T (universal, no depende del SO).
  /// Ej: 4_399_630 → "$4,4M"; 15_000 → "$15K"; 999 → "$999".
  /// Port de la rama `.abbreviated` de `Money.format` en iOS.
  static String _abbreviated(Decimal value, {required String locale}) {
    final double abs = value.toDouble().abs();
    final (Decimal divisor, String suffix) = switch (abs) {
      >= 1000000000000 => (Decimal.fromInt(1000000000000), 'T'),
      >= 1000000000 => (Decimal.fromInt(1000000000), 'B'),
      >= 1000000 => (Decimal.fromInt(1000000), 'M'),
      >= 1000 => (Decimal.fromInt(1000), 'K'),
      _ => (Decimal.one, ''),
    };
    final Decimal scaled =
        (value / divisor).toDecimal(scaleOnInfinitePrecision: 4);
    // 1 decimal si hay resto al dividir, 0 si es exacto (igual que iOS).
    final bool hasRemainder =
        suffix.isNotEmpty && abs % divisor.toDouble() != 0;
    final int fracDigits = hasRemainder ? 1 : 0;
    final String numberPart =
        _grouped(scaled, fractionDigits: fracDigits, locale: locale);
    return '$numberPart$suffix';
  }

  /// Parsea un string con formato de moneda local al `Decimal` correspondiente.
  /// Tolera símbolos ($, U$S, €, R$, ARS, USD…), separadores de miles y
  /// decimales en ambas convenciones (es-AR `1.234,56` y en-US `1,234.56`).
  ///
  /// Estrategia (port de `Money.parse` en iOS): heurística basada en el
  /// ÚLTIMO separador (`.` o `,`) = decimal; los anteriores = miles.
  static Decimal? parse(String input) {
    var stripped = input;
    for (final String token in const <String>[
      r'U$S',
      r'US$',
      r'R$',
      r'CL$',
      r'CO$',
      r'MX$',
      r'CA$',
      r'NZ$',
      r'HK$',
      r'S$',
      r'A$',
      r'CN¥',
      r'$U',
      r'$',
      '€',
      '£',
      '¥',
      '₲',
      '₩',
      '₹',
      '₪',
      'Bs.S',
      'Bs.',
      'Fr.',
      'S/.',
      'zł',
      'kr',
      'ARS',
      'USD',
      'EUR',
      'BRL',
      ' ', // NBSP
    ]) {
      stripped = stripped.replaceAll(token, '');
    }
    stripped = stripped.trim();
    if (stripped.isEmpty) return null;

    return _parseHeuristic(stripped) ?? Decimal.tryParse(stripped);
  }

  /// Heurística: el último separador es el decimal; el resto, miles.
  static Decimal? _parseHeuristic(String s) {
    final int lastDot = s.lastIndexOf('.');
    final int lastComma = s.lastIndexOf(',');
    final int decimalIndex = (lastDot < 0 && lastComma < 0)
        ? -1
        : (lastDot > lastComma ? lastDot : lastComma);

    final String normalized;
    if (decimalIndex >= 0) {
      final String intPart =
          s.substring(0, decimalIndex).replaceAll('.', '').replaceAll(',', '');
      final String fracPart = s.substring(decimalIndex + 1);
      normalized = '$intPart.$fracPart';
    } else {
      normalized = s.replaceAll('.', '').replaceAll(',', '');
    }
    return Decimal.tryParse(normalized);
  }
}
