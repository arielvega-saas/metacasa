import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

/// Formato de montos para el asistente IA: SIEMPRE con el código ISO 4217
/// explícito como prefijo (ej. "ARS 6,000", "USD 100").
///
/// Port de `AIToolHandler.fmt(_:cur:)` de iOS. La clave es que tanto el
/// `FinancialContext` como los results de las tools usen ISO-prefix en vez del
/// símbolo "$": así el modelo NUNCA interpreta "$" como dólares (sesgo del
/// training) y respeta la moneda real del hogar. El system prompt instruye al
/// modelo a NO repetir el ISO verbatim al usuario (usa "pesos"/"dólares"/…).
abstract final class AiMoney {
  const AiMoney._();

  /// `<ISO> <monto agrupado>`. 0 decimales si el monto es entero; hasta 2 si
  /// tiene fracción. Agrupamiento con coma de miles (en-US POSIX), igual que iOS.
  static String iso(Decimal amount, String currencyCode) {
    final String code = currencyCode.toUpperCase();
    final bool isInteger = amount.isInteger;
    final NumberFormat nf = NumberFormat.decimalPattern('en_US')
      ..minimumFractionDigits = 0
      ..maximumFractionDigits = isInteger ? 0 : 2;
    final String body = nf.format(amount.toDouble());
    return '$code $body';
  }
}
